import { AppError } from '@/lib/middleware/error-handler';
import path from 'path';
import { PNG } from 'pngjs';
import { extractImages, extractText, getDocumentProxy } from 'unpdf';
import { getR2Object, getR2SignedUrl } from '../r2';

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
/** Llama 4 Scout was shut down 2026-07-17; qwen3.6 still accepts image inputs on Groq. */
const GROQ_VISION_MODEL = process.env.GROQ_VISION_MODEL || 'qwen/qwen3.6-27b';
const MIN_USEFUL_TEXT_CHARS = 80;
const MAX_VISION_PAGES = 3;
const MAX_VISION_IMAGE_EDGE = 1600;

type ImagePayload = { mime: string; dataUrl: string };

function mimeFromExtension(ext: string): string {
  switch (ext.toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.heic':
      return 'image/heic';
    case '.heif':
      return 'image/heif';
    case '.pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

async function readInputBuffer(input: string, isR2Key: boolean): Promise<Buffer> {
  if (isR2Key) {
    const body = await getR2Object(input);
    if (!body) throw new Error('Empty body from R2');
    const bytes = await body.transformToByteArray();
    return Buffer.from(bytes);
  }

  const response = await fetch(input);
  if (!response.ok) throw new Error(`Failed to download file: ${response.statusText}`);
  return Buffer.from(await response.arrayBuffer());
}

function toRgba(
  image: { data: Uint8ClampedArray; width: number; height: number; channels: 1 | 3 | 4 },
): { data: Buffer; width: number; height: number } {
  const { width, height, channels, data: src } = image;
  const rgba = Buffer.alloc(width * height * 4);
  if (channels === 4) {
    rgba.set(src);
  } else if (channels === 3) {
    for (let i = 0, j = 0; i < src.length; i += 3, j += 4) {
      rgba[j] = src[i];
      rgba[j + 1] = src[i + 1];
      rgba[j + 2] = src[i + 2];
      rgba[j + 3] = 255;
    }
  } else {
    for (let i = 0, j = 0; i < src.length; i += 1, j += 4) {
      rgba[j] = src[i];
      rgba[j + 1] = src[i];
      rgba[j + 2] = src[i];
      rgba[j + 3] = 255;
    }
  }
  return { data: rgba, width, height };
}

function downscaleRgba(
  rgba: Buffer,
  width: number,
  height: number,
  maxEdge: number,
): { data: Buffer; width: number; height: number } {
  const edge = Math.max(width, height);
  if (edge <= maxEdge) return { data: rgba, width, height };

  const scale = maxEdge / edge;
  const nextWidth = Math.max(2, Math.round(width * scale));
  const nextHeight = Math.max(2, Math.round(height * scale));
  const next = Buffer.alloc(nextWidth * nextHeight * 4);

  for (let y = 0; y < nextHeight; y += 1) {
    const srcY = Math.min(height - 1, Math.floor(y / scale));
    for (let x = 0; x < nextWidth; x += 1) {
      const srcX = Math.min(width - 1, Math.floor(x / scale));
      const srcIdx = (srcY * width + srcX) * 4;
      const dstIdx = (y * nextWidth + x) * 4;
      next[dstIdx] = rgba[srcIdx];
      next[dstIdx + 1] = rgba[srcIdx + 1];
      next[dstIdx + 2] = rgba[srcIdx + 2];
      next[dstIdx + 3] = rgba[srcIdx + 3];
    }
  }

  return { data: next, width: nextWidth, height: nextHeight };
}

function encodeRawImageToPngDataUrl(image: {
  data: Uint8ClampedArray;
  width: number;
  height: number;
  channels: 1 | 3 | 4;
}): string {
  const rgba = toRgba(image);
  const scaled = downscaleRgba(rgba.data, rgba.width, rgba.height, MAX_VISION_IMAGE_EDGE);
  const png = new PNG({ width: scaled.width, height: scaled.height });
  png.data = Buffer.from(scaled.data);
  const encoded = PNG.sync.write(png);
  return `data:image/png;base64,${encoded.toString('base64')}`;
}

function stripModelThinking(text: string): string {
  return text
    .replace(/<think>[\s\S]*?<\/think>/gi, '')
    .replace(/^\s*thinking[\s\S]*?(?=\n[A-Z0-9])/i, '')
    .trim();
}

async function extractPdfText(buffer: Buffer): Promise<string> {
  const pdf = await getDocumentProxy(new Uint8Array(buffer));
  const { text } = await extractText(pdf, { mergePages: true });
  return String(text ?? '').trim();
}

async function extractPdfImagesForVision(buffer: Buffer): Promise<ImagePayload[]> {
  const pdf = await getDocumentProxy(new Uint8Array(buffer));
  const pageCount = Math.min(pdf.numPages || 1, MAX_VISION_PAGES);
  const images: ImagePayload[] = [];

  for (let page = 1; page <= pageCount; page += 1) {
    const pageImages = await extractImages(pdf, page);
    for (const image of pageImages) {
      images.push({
        mime: 'image/png',
        dataUrl: encodeRawImageToPngDataUrl(image),
      });
      if (images.length >= 5) return images;
    }
  }

  return images;
}

async function extractViaExternalService(
  buffer: Buffer,
  fileName: string,
  contentType: string,
): Promise<string | null> {
  const base = process.env.OCR_SERVICE_URL?.replace(/\/$/, '');
  if (!base) return null;
  if (process.env.VERCEL && /localhost|127\.0\.0\.1/.test(base)) {
    console.warn('Skipping OCR_SERVICE_URL on Vercel because it points at localhost');
    return null;
  }

  const form = new FormData();
  form.append('file', new Blob([new Uint8Array(buffer)], { type: contentType }), fileName);

  const endpoints = [`${base}/ocr`, base];
  for (const endpoint of endpoints) {
    try {
      const response = await fetch(endpoint, { method: 'POST', body: form });
      if (!response.ok) continue;
      const data = await response.json().catch(() => ({}));
      const text = typeof data.text === 'string' ? data.text.trim() : '';
      if (text) return text;
    } catch (error) {
      console.warn(`External OCR endpoint failed (${endpoint}):`, error);
    }
  }

  return null;
}

async function extractViaGroqVision(images: ImagePayload[]): Promise<string> {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) {
    throw new Error('GROQ_API_KEY is required for vision OCR on serverless');
  }
  if (images.length === 0) {
    throw new Error('No images available for vision OCR');
  }

  const content: Array<Record<string, unknown>> = [
    {
      type: 'text',
      text:
        'Extract all readable text from these medical document page images. ' +
        'Preserve labels, values, dates, doctor names, facility/hospital names, and table structure. ' +
        'Return plain text only, with line breaks.',
    },
    ...images.slice(0, 5).map((image) => ({
      type: 'image_url',
      image_url: { url: image.dataUrl },
    })),
  ];

  console.log('Groq vision model:', GROQ_VISION_MODEL, 'images:', images.length);
  const response = await fetch(GROQ_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: GROQ_VISION_MODEL,
      messages: [{ role: 'user', content }],
      temperature: 0.1,
      max_completion_tokens: 4096,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Groq vision OCR failed: ${response.status} - ${errorText}`);
  }

  const data = await response.json();
  const text = stripModelThinking(String(data.choices?.[0]?.message?.content || ''));
  if (!text) throw new Error('Groq vision OCR returned empty text');
  return text;
}

async function extractFromImageBuffer(buffer: Buffer, mime: string, r2Key?: string): Promise<string> {
  if (mime === 'image/heic' || mime === 'image/heif') {
    throw new Error('HEIC/HEIF OCR is not supported in production. Please upload PDF, JPG, or PNG.');
  }

  // Prefer a signed URL when available so request payloads stay smaller.
  if (r2Key) {
    try {
      const url = await getR2SignedUrl(r2Key, 600);
      return extractViaGroqVision([{ mime, dataUrl: url }]);
    } catch (error) {
      console.warn('Signed URL vision OCR failed, falling back to base64:', error);
    }
  }

  return extractViaGroqVision([
    { mime, dataUrl: `data:${mime};base64,${buffer.toString('base64')}` },
  ]);
}

export async function extractTextFromImage(input: string, isR2Key: boolean = false): Promise<string> {
  const extension = path.extname(input) || '.jpg';
  const mime = mimeFromExtension(extension);
  const fileName = path.basename(input) || `document${extension}`;

  try {
    console.log('\n--- OCR REQUEST ---');
    console.log('Input:', input);
    console.log('Extension:', extension);
    console.log('Runtime:', process.env.VERCEL ? 'vercel' : 'local');
    console.log('-------------------\n');

    const buffer = await readInputBuffer(input, isR2Key);

    const externalText = await extractViaExternalService(buffer, fileName, mime);
    if (externalText && externalText.length >= MIN_USEFUL_TEXT_CHARS) {
      console.log('OCR source: external service');
      return externalText;
    }

    if (mime === 'application/pdf' || extension.toLowerCase() === '.pdf') {
      const pdfText = await extractPdfText(buffer);
      if (pdfText.length >= MIN_USEFUL_TEXT_CHARS) {
        console.log('OCR source: PDF text layer', { chars: pdfText.length });
        return pdfText;
      }

      console.log('PDF text layer insufficient; trying embedded images + Groq vision');
      const images = await extractPdfImagesForVision(buffer);
      if (images.length > 0) {
        const visionText = await extractViaGroqVision(images);
        console.log('OCR source: Groq vision from PDF images', { chars: visionText.length });
        return visionText;
      }

      if (externalText) return externalText;
      throw new Error(
        'This PDF has no extractable text or embedded images. Export pages as JPG/PNG, or configure OCR_SERVICE_URL.',
      );
    }

    const imageText = await extractFromImageBuffer(buffer, mime, isR2Key ? input : undefined);
    console.log('OCR source: Groq vision image', { chars: imageText.length });
    return imageText;
  } catch (error: any) {
    console.error('OCR Processing Error:', error);
    throw new AppError(`Failed to process document with OCR: ${error.message}`, 502);
  }
}
