import { sql } from '@/lib/db/neon';

export type DashboardHome = {
  householdId: string | null;
  households: Array<{
    id: string;
    name: string;
    createdBy: string;
    createdAt: string;
    updatedAt: string;
  }>;
  pending: Array<{
    id: string;
    token: string;
    householdName?: string;
    invitedByName?: string;
  }>;
  patients: Array<{
    id: string;
    firstName: string;
    lastName?: string;
  }>;
  records: Array<{
    id: string;
    patientId: string;
    recordType: string;
    source: string;
    documentDate?: string;
    createdAt: string;
  }>;
};

export async function loadDashboardHome(userId: string, email: string): Promise<DashboardHome> {
  const normalizedEmail = email.toLowerCase();

  const [householdRows, inviteRows, preferenceRows] = await Promise.all([
    sql`
      SELECT h.id, h.name, h.created_by, h.created_at, h.updated_at, hm.joined_at
      FROM households h
      INNER JOIN household_members hm ON hm.household_id = h.id
      WHERE hm.user_id = ${userId}
      ORDER BY h.name ASC
    `,
    sql`
      SELECT i.id, i.token, h.name AS household_name,
        CONCAT_WS(' ', p.first_name, p.last_name) AS invited_by_name
      FROM household_invites i
      INNER JOIN households h ON h.id = i.household_id
      LEFT JOIN profiles p ON p.user_id = i.invited_by
      WHERE LOWER(i.email) = ${normalizedEmail}
        AND i.status = 'pending'
        AND i.expires_at >= NOW()
      ORDER BY i.created_at DESC
    `,
    sql`
      SELECT preferences->>'activeHouseholdId' AS active_household_id
      FROM profiles
      WHERE user_id = ${userId}
      LIMIT 1
    `,
  ]);

  const households = householdRows.map((row) => ({
    id: String(row.id),
    name: String(row.name || ''),
    createdBy: String(row.created_by || ''),
    createdAt: String(row.created_at || ''),
    updatedAt: String(row.updated_at || ''),
  }));
  const pending = inviteRows.map((row) => ({
    id: String(row.id),
    token: String(row.token),
    householdName: row.household_name ? String(row.household_name) : undefined,
    invitedByName: row.invited_by_name ? String(row.invited_by_name) : undefined,
  }));
  const preferredId = preferenceRows[0]?.active_household_id ? String(preferenceRows[0].active_household_id) : '';
  const fallbackId = [...householdRows]
    .sort((a, b) => new Date(String(a.joined_at)).getTime() - new Date(String(b.joined_at)).getTime())[0];
  const householdId = households.some((household) => household.id === preferredId)
    ? preferredId
    : fallbackId
      ? String(fallbackId.id)
      : null;

  if (!householdId) {
    return { householdId: null, households, pending, patients: [], records: [] };
  }

  const [patientRows, recordRows] = await Promise.all([
    sql`
      SELECT p.id, p.first_name, p.last_name
      FROM patients p
      INNER JOIN household_patients hp ON hp.patient_id = p.id
      WHERE hp.household_id = ${householdId}::uuid
      ORDER BY p.created_at DESC
    `,
    sql`
      SELECT id, patient_id, record_type, source, document_date, created_at
      FROM (
        SELECT
          hr.id,
          hr.patient_id,
          hr.record_type,
          hr.source,
          hr.document_date,
          hr.created_at,
          ROW_NUMBER() OVER (
            PARTITION BY hr.patient_id
            ORDER BY COALESCE(hr.document_date, hr.created_at::date) DESC, hr.created_at DESC
          ) AS rn
        FROM health_records hr
        INNER JOIN household_patients hp ON hp.patient_id = hr.patient_id
        WHERE hp.household_id = ${householdId}::uuid
      ) ranked
      WHERE rn <= 3
    `,
  ]);

  return {
    householdId,
    households,
    pending,
    patients: patientRows.map((row) => ({
      id: String(row.id),
      firstName: String(row.first_name || ''),
      lastName: row.last_name ? String(row.last_name) : undefined,
    })),
    records: recordRows.map((row) => ({
      id: String(row.id),
      patientId: String(row.patient_id),
      recordType: String(row.record_type || ''),
      source: String(row.source || ''),
      documentDate: row.document_date ? String(row.document_date) : undefined,
      createdAt: String(row.created_at),
    })),
  };
}
