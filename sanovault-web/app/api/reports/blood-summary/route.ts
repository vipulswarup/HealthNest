import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { AppError, handleError } from '@/lib/middleware/error-handler';
import {
  buildBloodReportSummary,
  hasManualLabOverride,
  readManualLabResults,
} from '@/lib/reports/blood-summary';

const LOOKBACK_DAYS = 90;

export async function GET(request: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);

    const patientId = new URL(request.url).searchParams.get('patientId');
    if (!patientId || !z.string().uuid().safeParse(patientId).success) {
      throw new AppError('A valid patient ID is required', 400);
    }

    const [patient] = await sql`
      SELECT id, first_name, last_name
      FROM patients
      WHERE id = ${patientId}::uuid AND owner_id = ${user.id}
      LIMIT 1
    `;
    if (!patient) throw new AppError('Patient not found', 404);

    const periodEnd = new Date();
    const periodStart = new Date(periodEnd);
    periodStart.setDate(periodStart.getDate() - LOOKBACK_DAYS);
    const periodStartIso = periodStart.toISOString().slice(0, 10);
    const periodEndIso = periodEnd.toISOString().slice(0, 10);

    const records = await sql`
      SELECT
        hr.id,
        hr.source,
        hr.record_type,
        hr.tags,
        hr.data,
        hr.ocr_text,
        hr.document_id,
        hr.document_date,
        hr.created_at,
        COALESCE(hr.document_date, hr.created_at::date) AS effective_date
      FROM health_records hr
      WHERE hr.patient_id = ${patientId}::uuid
        AND COALESCE(hr.document_date, hr.created_at::date) BETWEEN ${periodStartIso}::date AND ${periodEndIso}::date
        AND (
          hr.record_type IN ('LAB_REPORT', 'PATHOLOGY_TEST', 'HEMATOLOGY_REPORT', 'BIOCHEMISTRY_REPORT')
          OR EXISTS (
            SELECT 1
            FROM unnest(hr.tags) AS tag
            WHERE tag ~* '(blood|lab|pathology|haemat|hemat|cbc|lipid|thyroid|kidney|liver|iron|urine|diabetes|glucose)'
          )
          OR hr.ocr_text ~* '(hemoglobin|haemoglobin|creatinine|hba1c|triglyceride|cholesterol|tsh|platelet|ferritin)'
          OR (hr.data ? 'labResultsManual' AND (hr.data->>'labResultsManual') = 'true')
        )
      ORDER BY effective_date DESC, hr.created_at DESC
    `;

    const summary = buildBloodReportSummary(
      records.map((record) => {
        const data = record.data || {};
        const useManualResults = hasManualLabOverride(data);
        return {
          id: String(record.id),
          date: new Date(record.effective_date || record.document_date || record.created_at),
          source: String(record.source || 'Unknown source'),
          documentPath: record.document_id
            ? `/health-records/${record.id}/document`
            : `/health-records/${record.id}`,
          ocrText: record.ocr_text ? String(record.ocr_text) : undefined,
          useManualResults,
          manualResults: useManualResults ? readManualLabResults(data) : undefined,
        };
      }),
    );

    return NextResponse.json({
      patient: {
        id: String(patient.id),
        firstName: String(patient.first_name || ''),
        lastName: String(patient.last_name || ''),
      },
      periodStart,
      periodEnd,
      lookbackDays: LOOKBACK_DAYS,
      candidateReportCount: records.length,
      ...summary,
    });
  } catch (error) {
    return handleError(error);
  }
}
