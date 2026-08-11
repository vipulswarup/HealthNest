import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth/session';
import { getDocumentById, updateDocumentStatus } from '@/lib/services/document.service';
import { extractTextFromImage } from '@/lib/services/ocr.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';

export async function POST(request: NextRequest) {
    try {
        const user = await getCurrentUser();
        if (!user) {
            throw new AppError('Unauthorized', 401);
        }

        const { documentId } = await request.json();

        if (!documentId) {
            throw new AppError('Document ID is required', 400);
        }

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
            const text = await extractTextFromImage(document.r2Key, true);

            await updateDocumentStatus(documentId, {
                ocrStatus: 'COMPLETED',
                ocrText: text
            });

            return NextResponse.json({ text });
        } catch (error) {
            await updateDocumentStatus(documentId, { ocrStatus: 'FAILED' });
            throw error;
        }
    } catch (error) {
        return handleError(error);
    }
}
