import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { canAccessPatient } from '@/lib/households/access';
import { AppError, handleError } from '@/lib/middleware/error-handler';
import { recordAuditEvent } from '@/lib/services/audit.service';
import { toMedication } from '@/lib/services/medication.service';

const medicationSchema = z.object({
  patientId: z.string().uuid('Patient ID is required'),
  name: z.string().min(1, 'Medication name is required'),
  dosage: z.string().min(1, 'Dosage is required'),
  frequency: z.string().min(1, 'Frequency is required'),
  route: z.string().min(1, 'Route is required'),
  startDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
  endDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  instructions: z.string().optional(),
  prescribedBy: z.string().optional(),
  source: z.string().optional(),
  isActive: z.boolean().optional(),
  tags: z.array(z.string()).optional(),
});

async function currentUser() {
  const user = await getCurrentUser();
  if (!user) throw new AppError('Unauthorized', 401);
  return user;
}

export async function GET(request: NextRequest) {
  try {
    const user = await currentUser();
    const patientId = request.nextUrl.searchParams.get('patientId');
    const isActiveParam = request.nextUrl.searchParams.get('isActive');

    if (!patientId || !z.string().uuid().safeParse(patientId).success) {
      throw new AppError('A valid patient ID is required', 400);
    }
    if (isActiveParam !== null && isActiveParam !== 'true' && isActiveParam !== 'false') {
      throw new AppError('isActive must be true or false', 400);
    }
    if (!(await canAccessPatient(user.id, patientId))) throw new AppError('Patient not found', 404);

    const isActive = isActiveParam === null ? null : isActiveParam === 'true';
    const medications = await sql`
      SELECT *
      FROM medications
      WHERE patient_id = ${patientId}::uuid
        AND (${isActive}::boolean IS NULL OR is_active = ${isActive}::boolean)
      ORDER BY start_date DESC, created_at DESC
    `;
    return NextResponse.json(medications.map(toMedication));
  } catch (error) {
    return handleError(error);
  }
}

export async function POST(request: NextRequest) {
  try {
    const user = await currentUser();
    const parsed = medicationSchema.safeParse(await request.json());
    if (!parsed.success) throw new AppError(parsed.error.issues[0].message, 400, 'VALIDATION_ERROR');
    const data = parsed.data;
    if (!(await canAccessPatient(user.id, data.patientId))) throw new AppError('Patient not found', 404);

    const [medication] = await sql`
      INSERT INTO medications (
        patient_id, name, dosage, frequency, route, start_date, end_date,
        instructions, prescribed_by, source, is_active, tags
      ) VALUES (
        ${data.patientId}::uuid, ${data.name}, ${data.dosage}, ${data.frequency}, ${data.route},
        ${data.startDate}::date, ${data.endDate || null}::date, ${data.instructions || null},
        ${data.prescribedBy || null}, ${data.source || null}, ${data.isActive ?? true}, ${data.tags || []}
      )
      RETURNING *
    `;
    await recordAuditEvent({
      actorId: user.id,
      patientId: data.patientId,
      eventType: 'created',
      entityType: 'medication',
      entityId: medication.id,
    });
    return NextResponse.json(toMedication(medication), { status: 201 });
  } catch (error) {
    return handleError(error);
  }
}
