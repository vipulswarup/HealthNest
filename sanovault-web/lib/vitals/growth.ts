export type GrowthMeasurement = {
  id: string;
  patientId: string;
  measuredAt: string;
  heightCm: number | null;
  weightKg: number | null;
  headCircumCm: number | null;
  notes: string;
  calendarDate: string;
};

export function formatCalendarDate(date: string) {
  const [year, month, day] = date.split('-').map(Number);
  if (!year || !month || !day) return date;
  return new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }).format(
    new Date(year, month - 1, day),
  );
}

export function calendarDateFromInstant(at: Date): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(at);
  const year = parts.find((part) => part.type === 'year')?.value;
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;
  return `${year}-${month}-${day}`;
}

export function ageAtDate(dateOfBirth: string | Date | null | undefined, at: Date): string | null {
  if (!dateOfBirth) return null;
  const birth = new Date(dateOfBirth);
  if (Number.isNaN(birth.getTime())) return null;
  let years = at.getFullYear() - birth.getFullYear();
  let months = at.getMonth() - birth.getMonth();
  if (at.getDate() < birth.getDate()) months -= 1;
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years < 0) return null;
  if (years === 0) return months <= 1 ? `${Math.max(0, months)} mo` : `${months} mo`;
  if (months === 0) return `${years}y`;
  return `${years}y ${months}m`;
}

export function bmi(heightCm: number | null, weightKg: number | null): number | null {
  if (!heightCm || !weightKg || heightCm <= 0) return null;
  const meters = heightCm / 100;
  const value = weightKg / (meters * meters);
  return Number.isFinite(value) ? Math.round(value * 10) / 10 : null;
}

export function measurementLine(
  measurement: GrowthMeasurement,
  dateOfBirth?: string | Date | null,
) {
  const when = formatCalendarDate(measurement.calendarDate);
  const parts: string[] = [];
  if (measurement.heightCm !== null) parts.push(`${measurement.heightCm} cm`);
  if (measurement.weightKg !== null) parts.push(`${measurement.weightKg} kg`);
  if (measurement.headCircumCm !== null) parts.push(`head ${measurement.headCircumCm} cm`);
  const age = dateOfBirth ? ageAtDate(dateOfBirth, new Date(measurement.measuredAt)) : null;
  const bmiValue = bmi(measurement.heightCm, measurement.weightKg);
  const suffix = [
    age ? `age ${age}` : '',
    bmiValue ? `BMI ${bmiValue}` : '',
  ].filter(Boolean).join(' · ');
  const body = parts.length ? parts.join(' · ') : 'Measurement recorded';
  return suffix ? `${when} · ${body} · ${suffix}` : `${when} · ${body}`;
}

export function packetGrowthLines(
  measurements: GrowthMeasurement[],
  dateOfBirth?: string | Date | null,
  limit = 6,
) {
  return measurements.slice(0, limit).map((measurement) => measurementLine(measurement, dateOfBirth));
}

export function toGrowthMeasurement(row: Record<string, unknown>): GrowthMeasurement {
  const measuredAt = new Date(String(row.measured_at));
  return {
    id: String(row.id),
    patientId: String(row.patient_id),
    measuredAt: measuredAt.toISOString(),
    heightCm: row.height_cm === null || row.height_cm === undefined ? null : Number(row.height_cm),
    weightKg: row.weight_kg === null || row.weight_kg === undefined ? null : Number(row.weight_kg),
    headCircumCm: row.head_circum_cm === null || row.head_circum_cm === undefined ? null : Number(row.head_circum_cm),
    notes: String(row.notes || ''),
    calendarDate: calendarDateFromInstant(measuredAt),
  };
}
