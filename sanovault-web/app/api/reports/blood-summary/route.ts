import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { sql } from '@/lib/db/neon';
import { getAccessiblePatient } from '@/lib/households/access';
import { AppError, handleError } from '@/lib/middleware/error-handler';
import {
  buildBloodReportSummary,
  hasManualLabOverride,
  LAB_METRIC_OPTIONS,
  LabAliasMapping,
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

    const patient = await getAccessiblePatient(user.id, patientId);
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

    const confirmedMappingRows = await sql`
      SELECT source, data
      FROM health_records
      WHERE patient_id = ${patientId}::uuid
        AND data ? 'labResultsManual'
        AND (data->>'labResultsManual') = 'true'
    `;
    const canonicalMetrics = new Set(LAB_METRIC_OPTIONS.map((option) => option.metric));
    const mappingsBySource = new Map<string, Map<string, LabAliasMapping>>();
    for (const row of confirmedMappingRows) {
      const source = String(row.source || 'Unknown source').trim().toLowerCase();
      const sourceMappings = mappingsBySource.get(source) || new Map<string, LabAliasMapping>();
      for (const result of readManualLabResults(row.data || {})) {
        if (!result.rawLabel || !canonicalMetrics.has(result.metric)) continue;
        sourceMappings.set(result.rawLabel.trim().toLowerCase(), {
          rawLabel: result.rawLabel,
          metric: result.metric,
        });
      }
      mappingsBySource.set(source, sourceMappings);
    }

    const summary = buildBloodReportSummary(
      records.map((record) => {
        const data = record.data || {};
        const useManualResults = hasManualLabOverride(data);
        const source = String(record.source || 'Unknown source');
        return {
          id: String(record.id),
          date: new Date(record.effective_date || record.document_date || record.created_at),
          source,
          documentPath: record.document_id
            ? `/health-records/${record.id}/document`
            : `/health-records/${record.id}`,
          ocrText: record.ocr_text ? String(record.ocr_text) : undefined,
          useManualResults,
          manualResults: useManualResults ? readManualLabResults(data) : undefined,
          aliasMappings: [...(mappingsBySource.get(source.trim().toLowerCase())?.values() || [])],
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
