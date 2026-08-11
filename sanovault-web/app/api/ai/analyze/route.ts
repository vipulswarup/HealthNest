import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth/session';
import { getDocumentById, updateDocumentStatus } from '@/lib/services/document.service';
import { analyzeDocument } from '@/lib/services/ai.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';
import { sql } from '@/lib/db/neon';

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
            
            // DEBUG LOGGING - Input to AI
            console.log('\n--- AI ANALYSIS INPUT ---');
            console.log('Document ID:', documentId);
            console.log('OCR Text Length:', document.ocrText.length);
            console.log('Limited Text Length:', limitedText.length);
            console.log('First 200 chars of OCR:', document.ocrText.substring(0, 200));
            console.log('-----------------------\n');
            
            const result = await analyzeDocument(limitedText);

            // DEBUG LOGGING - After AI Analysis
            console.log('\n--- AI ANALYSIS OUTPUT ---');
            console.log('Result:', JSON.stringify(result, null, 2));
            console.log('Document Date from AI:', result.documentDate);
            console.log('Document Date type:', typeof result.documentDate);
            console.log('-----------------------\n');

            // Normalize doctor name if provided
            let normalizedDoctorName = result.doctorName || null;
            if (normalizedDoctorName) {
                try {
                    const [matchedDoctor] = await sql`SELECT preferred_name FROM doctors WHERE preferred_name ILIKE ${normalizedDoctorName} OR ${normalizedDoctorName} ILIKE ANY(aliases) LIMIT 1`;
                    if (matchedDoctor) {
                        normalizedDoctorName = matchedDoctor.preferred_name;
                    }
                } catch (err) {
                    console.warn('Failed to normalize doctor name:', err);
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
