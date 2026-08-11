import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { toHealthRecord } from '@/lib/db/records';
import { AppError, handleError } from '@/lib/middleware/error-handler';

const updateSchema = z.object({
  recordType: z.string().min(1).optional(), data: z.record(z.string(), z.any()).optional(), tags: z.array(z.string()).optional(), source: z.string().min(1).optional(),
  doctorName: z.string().optional(), documentDate: z.string().datetime().or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)).optional(),
  ocrText: z.string().optional(), hospitalSystemName: z.string().optional(), hospitalIdentifierType: z.string().optional(), hospitalIdentifierValue: z.string().optional(),
});

async function context(params: Promise<{ id: string }>) {
  const user = await getCurrentUser();
  if (!user) throw new AppError('Unauthorized', 401);
  const id = (await params).id;
  if (!z.string().uuid().safeParse(id).success) throw new AppError('Invalid health record ID', 400);
  return { user, id };
}

export async function GET(_: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { user, id } = await context(params);
    const [record] = await sql`SELECT hr.* FROM health_records hr JOIN patients p ON p.id = hr.patient_id WHERE hr.id = ${id}::uuid AND p.owner_id = ${user.id}`;
    if (!record) throw new AppError('Health record not found', 404);
    return NextResponse.json(toHealthRecord(record));
  } catch (error) { return handleError(error); }
}

export async function PUT(request: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { user, id } = await context(params);
    const parsed = updateSchema.safeParse(await request.json());
    if (!parsed.success) throw new AppError(parsed.error.issues[0].message, 400, 'VALIDATION_ERROR');
    const data = parsed.data;
    const [record] = await sql`
      UPDATE health_records hr SET
        record_type = COALESCE(${data.recordType ?? null}, hr.record_type), data = COALESCE(${data.data === undefined ? null : JSON.stringify(data.data)}::jsonb, hr.data),
        tags = COALESCE(${data.tags ?? null}, hr.tags), source = COALESCE(${data.source ?? null}, hr.source), doctor_name = COALESCE(${data.doctorName ?? null}, hr.doctor_name),
        document_date = COALESCE(${data.documentDate ?? null}::date, hr.document_date), ocr_text = COALESCE(${data.ocrText ?? null}, hr.ocr_text),
        hospital_system_name = COALESCE(${data.hospitalSystemName ?? null}, hr.hospital_system_name), hospital_identifier_type = COALESCE(${data.hospitalIdentifierType ?? null}, hr.hospital_identifier_type),
        hospital_identifier_value = COALESCE(${data.hospitalIdentifierValue ?? null}, hr.hospital_identifier_value), updated_at = NOW()
      FROM patients p WHERE hr.patient_id = p.id AND hr.id = ${id}::uuid AND p.owner_id = ${user.id} RETURNING hr.*
    `;
    if (!record) throw new AppError('Health record not found', 404);
    return NextResponse.json(toHealthRecord(record));
  } catch (error) { return handleError(error); }
}

export async function DELETE(_: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { user, id } = await context(params);
    const [record] = await sql`DELETE FROM health_records hr USING patients p WHERE hr.patient_id = p.id AND hr.id = ${id}::uuid AND p.owner_id = ${user.id} RETURNING hr.id`;
    if (!record) throw new AppError('Health record not found', 404);
    return NextResponse.json({ message: 'Health record deleted successfully' });
  } catch (error) { return handleError(error); }
}
