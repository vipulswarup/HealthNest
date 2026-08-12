import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth/session';
import { getDocumentById, updateDocumentStatus } from '@/lib/services/document.service';
import { extractTextFromImage, OcrMode } from '@/lib/services/ocr.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';
import { enforceHourlyRateLimit } from '@/lib/security/rate-limit';

export const runtime = 'nodejs';
/** Intake OCR is first-page / text-layer only. Full multi-page OCR should use a dedicated job later. */
export const maxDuration = 60;

export async function POST(request: NextRequest) {
    try {
        const user = await getCurrentUser();
        if (!user) {
            throw new AppError('Unauthorized', 401);
        }

        const body = await request.json();
        const { documentId } = body;
        const mode: OcrMode = body.mode === 'full' ? 'full' : 'intake';

        if (!documentId) {
            throw new AppError('Document ID is required', 400);
        }
        await enforceHourlyRateLimit(user.id, mode === 'full' ? 'ocr-full' : 'ocr-intake');

        const document = await getDocumentById(documentId);
        if (!document) {
            throw new AppError('Document not found', 404);
        }

        if (document.userId !== user.id) {
            throw new AppError('Forbidden', 403);
        }

        await updateDocumentStatus(documentId, { ocrStatus: 'PROCESSING' });

        try {
            if (!document.r2Key) throw new AppError('Document storage key is missing', 409);
            const text = await extractTextFromImage(document.r2Key, true, { mode });

            await updateDocumentStatus(documentId, {
                ocrStatus: 'COMPLETED',
                ocrText: text,
                extractedData: {
                    ...(document.extractedData || {}),
                    ocrMode: mode,
                },
            });

            return NextResponse.json({ text, mode });
        } catch (error) {
            await updateDocumentStatus(documentId, { ocrStatus: 'FAILED' });
            throw error;
        }
    } catch (error) {
        return handleError(error);
    }
}
