import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getCurrentUser } from '@/lib/auth/session';
import { deleteFromR2 } from '@/lib/r2';
import { deleteDocument, getDocumentById } from '@/lib/services/document.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';

async function documentForCurrentUser(params: Promise<{ id: string }>) {
  const user = await getCurrentUser();
  if (!user) throw new AppError('Unauthorized', 401);
  const id = (await params).id;
  if (!z.string().uuid().safeParse(id).success) throw new AppError('Invalid document ID', 400);
  const document = await getDocumentById(id);
  if (!document) throw new AppError('Document not found', 404);
  if (document.userId !== user.id) throw new AppError('Forbidden', 403);
  return { id, document };
}

export async function GET(_: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { document } = await documentForCurrentUser(params);
    return NextResponse.json(document);
  } catch (error) {
    return handleError(error);
  }
}

export async function DELETE(_: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id, document } = await documentForCurrentUser(params);
    if (document.r2Key) await deleteFromR2(document.r2Key);
    await deleteDocument(id);
    return NextResponse.json({ success: true });
  } catch (error) {
    return handleError(error);
  }
}
