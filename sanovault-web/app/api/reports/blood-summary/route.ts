import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { ObjectId } from 'mongodb';
import { authOptions } from '@/lib/auth/config';
import { getDatabase } from '@/lib/mongodb';
import { AppError, handleError } from '@/lib/middleware/error-handler';
import { buildBloodReportSummary } from '@/lib/reports/blood-summary';

const BLOOD_RECORD_TYPES = ['PATHOLOGY_TEST', 'HEMATOLOGY_REPORT', 'BIOCHEMISTRY_REPORT', 'MICROBIOLOGY_REPORT', 'lab_report'];

export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) throw new AppError('Unauthorized', 401);

    const patientId = new URL(request.url).searchParams.get('patientId');
    if (!patientId || !ObjectId.isValid(patientId)) throw new AppError('A valid patient ID is required', 400);

    const db = await getDatabase();
    const patient = await db.collection('patients').findOne({ _id: new ObjectId(patientId), userId: session.user.id });
    if (!patient) throw new AppError('Patient not found', 404);

    const periodEnd = new Date();
    const periodStart = new Date(periodEnd);
    periodStart.setDate(periodStart.getDate() - 90);

    const records = await db.collection('health_records').find({
      patientId,
      $and: [
        { $or: [
          { recordType: { $in: BLOOD_RECORD_TYPES } },
          { tags: { $elemMatch: { $regex: /(blood|lab|pathology|hematology|biochemistry)/i } } },
        ] },
        { $or: [
          { documentDate: { $gte: periodStart, $lte: periodEnd } },
          { documentDate: { $exists: false }, createdAt: { $gte: periodStart, $lte: periodEnd } },
          { documentDate: null, createdAt: { $gte: periodStart, $lte: periodEnd } },
        ] },
      ],
    }).toArray();

    const summary = buildBloodReportSummary(records.map((record) => ({
      id: record._id.toString(),
      date: record.documentDate instanceof Date && !Number.isNaN(record.documentDate.getTime()) ? record.documentDate : record.createdAt,
      source: record.source || 'Unknown source',
      documentPath: record.documentPath,
      ocrText: record.ocrText,
    })));

    return NextResponse.json({
      patient: { id: patient._id.toString(), firstName: patient.firstName, lastName: patient.lastName || '' },
      periodStart,
      periodEnd,
      candidateReportCount: records.length,
      ...summary,
    });
  } catch (error) {
    return handleError(error);
  }
}
