import { sql } from '@/lib/db/neon';

type MedicationRow = Record<string, unknown>;

export function toMedication(row: MedicationRow) {
  return {
    id: String(row.id),
    patientId: String(row.patient_id),
    name: String(row.name),
    dosage: String(row.dosage),
    frequency: String(row.frequency),
    route: String(row.route),
    startDate: row.start_date,
    endDate: row.end_date || null,
    instructions: row.instructions || '',
    prescribedBy: row.prescribed_by || '',
    source: row.source || '',
    isActive: Boolean(row.is_active),
    tags: Array.isArray(row.tags) ? row.tags : [],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function getAccessibleMedication(userId: string, medicationId: string): Promise<MedicationRow | null> {
  const [medication] = await sql`
    SELECT m.*
    FROM medications m
    INNER JOIN patients p ON p.id = m.patient_id
    WHERE m.id = ${medicationId}::uuid
      AND EXISTS (
        SELECT 1
        FROM household_patients hp
        INNER JOIN household_members hm
          ON hm.household_id = hp.household_id AND hm.user_id = ${userId}
        WHERE hp.patient_id = p.id
      )
    LIMIT 1
  `;
  return medication || null;
}
