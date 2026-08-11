import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { getR2SignedUrl } from '@/lib/r2';
import { getDocumentById } from '@/lib/services/document.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';

export async function POST(request: NextRequest) {
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);
    const { documentId } = await request.json();
    if (!z.string().uuid().safeParse(documentId).success) throw new AppError('A valid document ID is required', 400);
    const document = await getDocumentById(documentId);
    if (!document) throw new AppError('Document not found', 404);
    if (document.userId !== user.id) throw new AppError('Forbidden', 403);
    if (!document.r2Key) throw new AppError('This document is not stored in Cloudflare R2', 409);

    const url = await getR2SignedUrl(document.r2Key, 3600);
    return NextResponse.json({ url, fileName: document.fileName, fileType: document.fileType });
  } catch (error) {
    return handleError(error);
  }
}
