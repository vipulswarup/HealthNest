import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth/session';
import { getDocumentById, updateDocumentStatus } from '@/lib/services/document.service';
import { analyzeDocument } from '@/lib/services/ai.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';
import { sql } from '@/lib/db/neon';
import { enforceHourlyRateLimit } from '@/lib/security/rate-limit';

function limitToFirstNWords(text: string, maxWords: number): string {
    if (!text || text.trim().length === 0) {
        return text;
    }
    
    const words = text.trim().split(/\s+/);
    if (words.length <= maxWords) {
        return text;
    }
    
    return words.slice(0, maxWords).join(' ');
}

export async function POST(request: NextRequest) {
    try {
        const user = await getCurrentUser();
        if (!user) {
            throw new AppError('Unauthorized', 401);
        }
        await enforceHourlyRateLimit(user.id, 'ai');

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

        if (!document.ocrText) {
            throw new AppError('Document has no extracted text. Run OCR first.', 400);
        }

        await updateDocumentStatus(documentId, { aiStatus: 'PROCESSING' });

        try {
            // Limit to first 1000 words to save AI costs
            const limitedText = limitToFirstNWords(document.ocrText, 1000);
            
            const result = await analyzeDocument(limitedText);

            // Normalize doctor name if provided
            let normalizedDoctorName = result.doctorName || null;
            if (normalizedDoctorName) {
                try {
                    const [matchedDoctor] = await sql`SELECT preferred_name FROM doctors WHERE preferred_name ILIKE ${normalizedDoctorName} OR ${normalizedDoctorName} ILIKE ANY(aliases) LIMIT 1`;
                    if (matchedDoctor) {
                        normalizedDoctorName = matchedDoctor.preferred_name;
                    }
                } catch {
                    // A failed normalization must not expose document-derived data in logs.
                }
            }

            await updateDocumentStatus(documentId, {
                aiStatus: 'COMPLETED',
                classification: result.classification,
                confidenceScore: result.confidence,
                suggestedTags: result.tags,
                approvedTags: result.tags.length > 0 ? result.tags : undefined,
                extractedData: { 
                    ...(document.extractedData || {}), 
                    source: result.source,
                    doctorName: normalizedDoctorName,
                    documentDate: result.documentDate
                }
            });

            return NextResponse.json({
                ...result,
                doctorName: normalizedDoctorName
            });
        } catch (error) {
            await updateDocumentStatus(documentId, { aiStatus: 'FAILED' });
            throw error;
        }
    } catch (error) {
        return handleError(error);
    }
}
