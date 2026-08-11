import { randomUUID } from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { getCurrentUser } from '@/lib/auth/session';
import { deleteFromR2, uploadToR2 } from '@/lib/r2';
import { createDocument } from '@/lib/services/document.service';
import { handleError, AppError } from '@/lib/middleware/error-handler';

const ALLOWED_TYPES = new Set([
  'application/pdf', 'image/jpeg', 'image/jpg', 'image/png', 'image/heic', 'image/heif',
]);
const MAX_FILE_SIZE = 50 * 1024 * 1024;

export async function POST(request: NextRequest) {
  let r2Key: string | undefined;
  try {
    const user = await getCurrentUser();
    if (!user) throw new AppError('Unauthorized', 401);

    const formData = await request.formData();
    const file = formData.get('file');
    if (!(file instanceof File)) throw new AppError('No file provided', 400);
    if (!ALLOWED_TYPES.has(file.type)) {
      throw new AppError('Invalid file type. Allowed: PDF, JPEG, PNG, HEIC, HEIF', 400);
    }
    if (file.size > MAX_FILE_SIZE) throw new AppError('File size exceeds 50MB limit', 400);

    const extension = file.name.split('.').pop()?.toLowerCase() || 'bin';
    r2Key = `${user.id}/${randomUUID()}.${extension}`;
    await uploadToR2(r2Key, Buffer.from(await file.arrayBuffer()), file.type);

    const document = await createDocument({
      userId: user.id,
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      r2Key,
    });
    return NextResponse.json(document, { status: 201 });
  } catch (error: any) {
    if (r2Key) await deleteFromR2(r2Key).catch(() => undefined);
    if (error?.name === 'AccessDenied' || error?.Code === 'AccessDenied') {
      return handleError(new AppError('Access denied to file storage. Check the R2 credentials and bucket permissions.', 403));
    }
    return handleError(error);
  }
}
