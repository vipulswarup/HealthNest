export type VerifiedUpload = {
  extension: 'pdf' | 'jpg' | 'png' | 'heic';
  mimeType: 'application/pdf' | 'image/jpeg' | 'image/png' | 'image/heic' | 'image/heif';
};

const PNG_SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const HEIF_BRANDS = new Set(['heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'hevm', 'hevs']);

function hasPrefix(buffer: Buffer, prefix: Buffer): boolean {
  return buffer.length >= prefix.length && buffer.subarray(0, prefix.length).equals(prefix);
}

function isHeif(buffer: Buffer): boolean {
  if (buffer.length < 16 || buffer.subarray(4, 8).toString('ascii') !== 'ftyp') return false;

  for (let offset = 8; offset + 4 <= buffer.length; offset += 4) {
    if (HEIF_BRANDS.has(buffer.subarray(offset, offset + 4).toString('ascii').toLowerCase())) {
      return true;
    }
  }
  return false;
}

/**
 * Identifies only the formats the service accepts. Browser-supplied MIME types
 * and file extensions are metadata, not proof of a file's actual content.
 */
export function verifyUploadSignature(buffer: Buffer, declaredMimeType: string): VerifiedUpload | null {
  if (hasPrefix(buffer, Buffer.from('%PDF-'))) {
    return declaredMimeType === 'application/pdf'
      ? { mimeType: 'application/pdf', extension: 'pdf' }
      : null;
  }

  if (hasPrefix(buffer, Buffer.from([0xff, 0xd8, 0xff]))) {
    return declaredMimeType === 'image/jpeg' || declaredMimeType === 'image/jpg'
      ? { mimeType: 'image/jpeg', extension: 'jpg' }
      : null;
  }

  if (hasPrefix(buffer, PNG_SIGNATURE)) {
    return declaredMimeType === 'image/png'
      ? { mimeType: 'image/png', extension: 'png' }
      : null;
  }

  if (isHeif(buffer)) {
    return declaredMimeType === 'image/heic' || declaredMimeType === 'image/heif'
      ? { mimeType: declaredMimeType, extension: 'heic' }
      : null;
  }

  return null;
}
