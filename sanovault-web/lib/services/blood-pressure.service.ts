import { sql } from '@/lib/db/neon';
import { getAccessiblePatient } from '@/lib/households/access';
import {
  groupReadingsByDay,
  packetBpLines,
  toBloodPressureReading,
  type BloodPressureReading,
  type BpDaySlot,
  type BpPeriod,
} from '@/lib/vitals/blood-pressure';

export async function listBloodPressureWeek(userId: string, patientId: string): Promise<{
  readings: BloodPressureReading[];
  days: BpDaySlot[];
  lines: string[];
} | null> {
  const patient = await getAccessiblePatient(userId, patientId);
  if (!patient) return null;

  const rows = await sql`
    SELECT id, patient_id, recorded_at, period, systolic, diastolic, pulse
    FROM blood_pressure_readings
    WHERE patient_id = ${patientId}::uuid
      AND recorded_at >= (NOW() - INTERVAL '8 days')
    ORDER BY recorded_at DESC
  `;
  const readings = rows.map(toBloodPressureReading);
  const days = groupReadingsByDay(readings);
  return { readings, days, lines: packetBpLines(days) };
}

export async function createBloodPressureReading(options: {
  userId: string;
  patientId: string;
  period: BpPeriod;
  systolic: number;
  diastolic: number;
  pulse: number | null;
  recordedAt?: Date;
}): Promise<BloodPressureReading | null> {
  const patient = await getAccessiblePatient(options.userId, options.patientId);
  if (!patient) return null;

  const recordedAt = options.recordedAt || new Date();
  const [row] = await sql`
    INSERT INTO blood_pressure_readings (
      patient_id, recorded_by, recorded_at, period, systolic, diastolic, pulse
    )
    VALUES (
      ${options.patientId}::uuid,
      ${options.userId},
      ${recordedAt.toISOString()}::timestamptz,
      ${options.period},
      ${options.systolic},
      ${options.diastolic},
      ${options.pulse}
    )
    RETURNING id, patient_id, recorded_at, period, systolic, diastolic, pulse
  `;
  return row ? toBloodPressureReading(row) : null;
}
