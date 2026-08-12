import { sql } from '@/lib/db/neon';

export type ActiveHouseholdId = string | null;

/** Personal: owner + no household. Household: member of patient's household. */
export async function canAccessPatient(userId: string, patientId: string): Promise<boolean> {
  const [row] = await sql`
    SELECT 1
    FROM patients p
    WHERE p.id = ${patientId}::uuid
      AND (
        (p.household_id IS NULL AND p.owner_id = ${userId})
        OR (
          p.household_id IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM household_members hm
            WHERE hm.household_id = p.household_id AND hm.user_id = ${userId}
          )
        )
      )
    LIMIT 1
  `;
  return Boolean(row);
}

export async function getAccessiblePatient(
  userId: string,
  patientId: string
): Promise<Record<string, any> | null> {
  const [row] = await sql`
    SELECT p.*
    FROM patients p
    WHERE p.id = ${patientId}::uuid
      AND (
        (p.household_id IS NULL AND p.owner_id = ${userId})
        OR (
          p.household_id IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM household_members hm
            WHERE hm.household_id = p.household_id AND hm.user_id = ${userId}
          )
        )
      )
    LIMIT 1
  `;
  return row || null;
}

export async function isHouseholdMember(userId: string, householdId: string): Promise<boolean> {
  const [row] = await sql`
    SELECT 1 FROM household_members
    WHERE household_id = ${householdId}::uuid AND user_id = ${userId}
    LIMIT 1
  `;
  return Boolean(row);
}

export async function getActiveHouseholdId(userId: string): Promise<ActiveHouseholdId> {
  const [row] = await sql`
    SELECT preferences->>'activeHouseholdId' AS active_household_id
    FROM profiles WHERE user_id = ${userId}
  `;
  const raw = row?.active_household_id;
  if (!raw || raw === 'null' || raw === '') return null;
  return String(raw);
}

export async function setActiveHouseholdId(
  userId: string,
  householdId: ActiveHouseholdId
): Promise<void> {
  if (householdId) {
    const member = await isHouseholdMember(userId, householdId);
    if (!member) throw new Error('NOT_HOUSEHOLD_MEMBER');
  }
  await sql`
    UPDATE profiles
    SET
      preferences = jsonb_set(
        COALESCE(preferences, '{}'::jsonb),
        '{activeHouseholdId}',
        ${householdId === null ? 'null' : JSON.stringify(householdId)}::jsonb,
        true
      ),
      updated_at = NOW()
    WHERE user_id = ${userId}
  `;
}

/** List patients scoped to Personal (null) or a specific household. */
export async function listPatientsForContext(
  userId: string,
  activeHouseholdId: ActiveHouseholdId
): Promise<Record<string, any>[]> {
  if (activeHouseholdId) {
    const member = await isHouseholdMember(userId, activeHouseholdId);
    if (!member) return [];
    return sql`
      SELECT * FROM patients
      WHERE household_id = ${activeHouseholdId}::uuid
      ORDER BY created_at DESC
    `;
  }
  return sql`
    SELECT * FROM patients
    WHERE owner_id = ${userId} AND household_id IS NULL
    ORDER BY created_at DESC
  `;
}

export async function listPersonalPatients(userId: string): Promise<Record<string, any>[]> {
  return sql`
    SELECT * FROM patients
    WHERE owner_id = ${userId} AND household_id IS NULL
    ORDER BY created_at DESC
  `;
}

/** SQL fragment helper: patient accessible to user (for JOINs). Use with neon tagged templates carefully. */
export async function canAccessDocument(userId: string, documentId: string): Promise<boolean> {
  const [row] = await sql`
    SELECT 1
    FROM documents d
    LEFT JOIN patients p ON p.id = d.patient_id
    WHERE d.id = ${documentId}::uuid
      AND (
        d.owner_id = ${userId}
        OR (
          p.id IS NOT NULL AND (
            (p.household_id IS NULL AND p.owner_id = ${userId})
            OR (
              p.household_id IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM household_members hm
                WHERE hm.household_id = p.household_id AND hm.user_id = ${userId}
              )
            )
          )
        )
      )
    LIMIT 1
  `;
  return Boolean(row);
}

export async function getAccessibleDocument(
  userId: string,
  documentId: string
): Promise<Record<string, any> | null> {
  const [row] = await sql`
    SELECT d.*
    FROM documents d
    LEFT JOIN patients p ON p.id = d.patient_id
    WHERE d.id = ${documentId}::uuid
      AND (
        d.owner_id = ${userId}
        OR (
          p.id IS NOT NULL AND (
            (p.household_id IS NULL AND p.owner_id = ${userId})
            OR (
              p.household_id IS NOT NULL
              AND EXISTS (
                SELECT 1 FROM household_members hm
                WHERE hm.household_id = p.household_id AND hm.user_id = ${userId}
              )
            )
          )
        )
      )
    LIMIT 1
  `;
  return row || null;
}

export async function listAccessibleDocuments(
  userId: string,
  activeHouseholdId: ActiveHouseholdId
): Promise<Record<string, any>[]> {
  if (activeHouseholdId) {
    const member = await isHouseholdMember(userId, activeHouseholdId);
    if (!member) return [];
    return sql`
      SELECT d.*
      FROM documents d
      INNER JOIN patients p ON p.id = d.patient_id
      WHERE p.household_id = ${activeHouseholdId}::uuid
      ORDER BY d.uploaded_at DESC
    `;
  }
  return sql`
    SELECT d.*
    FROM documents d
    LEFT JOIN patients p ON p.id = d.patient_id
    WHERE d.owner_id = ${userId}
      AND (d.patient_id IS NULL OR (p.household_id IS NULL AND p.owner_id = ${userId}))
    ORDER BY d.uploaded_at DESC
  `;
}

export async function dissolveHouseholdIfEmpty(
  householdId: string,
  reclaimUserId: string
): Promise<boolean> {
  const members = await sql`
    SELECT user_id FROM household_members WHERE household_id = ${householdId}::uuid
  `;
  if (members.length > 0) return false;

  await sql`
    UPDATE patients
    SET household_id = NULL, owner_id = ${reclaimUserId}, updated_at = NOW()
    WHERE household_id = ${householdId}::uuid
  `;
  await sql`DELETE FROM household_invites WHERE household_id = ${householdId}::uuid`;
  await sql`DELETE FROM households WHERE id = ${householdId}::uuid`;
  return true;
}
