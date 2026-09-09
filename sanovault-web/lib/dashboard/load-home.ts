import { sql } from '@/lib/db/neon';
import { toPatient } from '@/lib/db/mappers';
import { toHousehold, toHouseholdInvite } from '@/lib/households/helpers';

export type DashboardHome = {
  householdId: string | null;
  households: ReturnType<typeof toHousehold>[];
  pending: ReturnType<typeof toHouseholdInvite>[];
  patients: ReturnType<typeof toPatient>[];
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
      SELECT h.*, hm.joined_at
      FROM households h
      INNER JOIN household_members hm ON hm.household_id = h.id
      WHERE hm.user_id = ${userId}
      ORDER BY h.name ASC
    `,
    sql`
      SELECT i.*, h.name AS household_name,
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

  const households = householdRows.map(toHousehold);
  const pending = inviteRows.map(toHouseholdInvite);
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
      SELECT p.*
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
    patients: patientRows.map(toPatient),
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
