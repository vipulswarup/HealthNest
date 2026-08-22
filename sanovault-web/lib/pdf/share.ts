import { canvasToJpeg, getPdfPageCount, renderPdfPage } from '@/lib/pdf/inspect';
import { fileToJpegBytes } from '@/lib/pdf/images';
import {
  addWatermark,
  createCoverPdf,
  encryptPdf,
  imagesToPdf,
  isPdfHeader,
  mergePdfBytes,
  pdfFile,
} from '@/lib/pdf/ops';

export type ShareRedaction = {
  pageIndex: number;
  left: number;
  top: number;
  width: number;
  height: number;
};

export type ShareDocument = {
  bytes: Uint8Array;
  fileName: string;
  mimeType: string;
};

export type CoverSpec = {
  title: string;
  identityLine: string;
  sections: Array<{ heading: string; lines: string[] }>;
};

export async function documentsToPdf(documents: ShareDocument[]): Promise<Uint8Array> {
  const parts: Uint8Array[] = [];
  for (const document of documents) {
    if (document.mimeType === 'application/pdf' || isPdfHeader(document.bytes) || /\.pdf$/i.test(document.fileName)) {
      parts.push(document.bytes);
      continue;
    }
    const jpeg = await fileToJpegBytes(new Blob([document.bytes as BlobPart], { type: document.mimeType || 'image/jpeg' }));
    parts.push(await imagesToPdf([{ bytes: jpeg, mime: 'image/jpeg' }]));
  }
  if (parts.length === 0) throw new Error('No documents to share');
  return parts.length === 1 ? parts[0] : mergePdfBytes(parts);
}

export async function assembleSharePdf(options: {
  documents: ShareDocument[];
  cover?: CoverSpec;
}): Promise<Uint8Array> {
  const cover = options.cover
    ? await createCoverPdf(options.cover.title, options.cover.identityLine, options.cover.sections)
    : null;
  const body = options.documents.length > 0 ? await documentsToPdf(options.documents) : null;
  if (cover && body) return mergePdfBytes([cover, body]);
  if (cover) return cover;
  if (body) return body;
  throw new Error('No documents to share');
}

export async function burnRedactions(
  bytes: Uint8Array,
  redactions: ShareRedaction[],
  watermark?: string,
): Promise<Uint8Array> {
  const pageCount = await getPdfPageCount(bytes);
  const images: Array<{ bytes: Uint8Array; mime: 'image/jpeg' }> = [];
  for (let pageIndex = 0; pageIndex < pageCount; pageIndex += 1) {
    const canvas = await renderPdfPage(bytes, pageIndex + 1, { scale: 1.35 });
    const context = canvas.getContext('2d');
    if (!context) throw new Error('Could not prepare this page for sharing');
    for (const rect of redactions) {
      if (rect.pageIndex !== pageIndex || rect.width <= 0 || rect.height <= 0) continue;
      context.fillStyle = '#000000';
      context.fillRect(
        rect.left * canvas.width,
        rect.top * canvas.height,
        rect.width * canvas.width,
        rect.height * canvas.height,
      );
    }
    if (watermark) {
      context.save();
      context.translate(canvas.width / 2, canvas.height / 2);
      context.rotate(-0.55);
      context.fillStyle = 'rgba(70,70,70,0.22)';
      context.font = `600 ${Math.max(18, Math.floor(canvas.width / 16))}px sans-serif`;
      context.textAlign = 'center';
      context.fillText(watermark.slice(0, 80), 0, 0);
      context.restore();
    }
    images.push({ bytes: await canvasToJpeg(canvas, 0.72), mime: 'image/jpeg' });
  }
  return imagesToPdf(images);
}

export async function buildShareCopy(options: {
  documents: ShareDocument[];
  cover?: CoverSpec;
  redactions: ShareRedaction[];
  watermark?: string;
  password?: string;
  fileName: string;
}): Promise<File> {
  let bytes = await assembleSharePdf({ documents: options.documents, cover: options.cover });
  if (options.redactions.length > 0) {
    bytes = await burnRedactions(bytes, options.redactions, options.watermark);
  } else if (options.watermark) {
    bytes = await addWatermark(bytes, options.watermark);
  }
  if (options.password?.trim()) {
    bytes = await encryptPdf(bytes, options.password.trim());
  }
  return pdfFile(bytes, options.fileName);
}
