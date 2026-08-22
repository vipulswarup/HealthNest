import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { toPatient } from '@/lib/db/mappers';
import { getAccessiblePatient } from '@/lib/households/access';
import { AppError, handleError } from '@/lib/middleware/error-handler';
import { humanizeLabel } from '@/lib/constants/labels';
import { loadBloodSummaryForPatient } from '@/lib/reports/load-blood-summary';
import {
  ageFromDateOfBirth,
  conditionLines,
  medicationLine,
  pickLabHighlights,
} from '@/lib/reports/doctor-packet';
import { listAccessibleMedications, toMedication } from '@/lib/services/medication.service';

export async function GET(request: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);

    const patientId = request.nextUrl.searchParams.get('patientId');
    if (!patientId || !z.string().uuid().safeParse(patientId).success) {
      throw new AppError('A valid patient ID is required', 400);
    }

    const row = await getAccessiblePatient(user.id, patientId);
    if (!row) throw new AppError('Patient not found', 404);
    const patient = toPatient(row);

    const [medicationRows, summary, documentRows] = await Promise.all([
      listAccessibleMedications(user.id, patientId, true),
      loadBloodSummaryForPatient(patientId),
      sql`
        SELECT id, record_type, source, document_id, document_date, created_at
        FROM health_records
        WHERE patient_id = ${patientId}::uuid
          AND document_id IS NOT NULL
        ORDER BY COALESCE(document_date, created_at::date) DESC, created_at DESC
        LIMIT 5
      `,
    ]);

    const medications = medicationRows.map(toMedication);
    const highlights = pickLabHighlights(summary.keyFindings);
    const preferences = (patient.preferences && typeof patient.preferences === 'object')
      ? patient.preferences as Record<string, unknown>
      : {};
    const pleaseAsk = typeof preferences.pleaseAsk === 'string' ? preferences.pleaseAsk : '';

    return NextResponse.json({
      patient: {
        id: String(patient.id),
        firstName: String(patient.firstName || ''),
        lastName: patient.lastName ? String(patient.lastName) : '',
        dateOfBirth: patient.dateOfBirth || null,
        age: ageFromDateOfBirth(patient.dateOfBirth as string | Date | undefined),
        gender: patient.gender ? String(patient.gender) : '',
        bloodGroup: patient.bloodGroup ? String(patient.bloodGroup) : '',
      },
      conditions: conditionLines(medications),
      medicines: medications.map((medication) => ({
        id: medication.id,
        line: medicationLine(medication),
      })),
      labHighlights: highlights.map((finding) => finding.text),
      bloodPressure: { available: false },
      pleaseAsk,
      documents: documentRows.map((record) => {
        const date = record.document_date || record.created_at;
        const when = date
          ? new Intl.DateTimeFormat('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(String(date)))
          : '';
        return {
          id: String(record.id),
          documentId: record.document_id ? String(record.document_id) : null,
          label: `${humanizeLabel(String(record.record_type || 'Report'))}${when ? ` · ${when}` : ''}`,
          href: `/health-records/${record.id}/document`,
        };
      }),
    });
  } catch (error) {
    return handleError(error);
  }
}
