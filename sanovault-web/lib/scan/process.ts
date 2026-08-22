import { detectDocumentQuad } from '@/lib/scan/detect';
import { applyScanFilter, type ScanFilter } from '@/lib/scan/enhance';
import { insetQuad, scaleQuad } from '@/lib/scan/geometry';
import { outputSizeForQuad, warpQuad } from '@/lib/scan/warp';

export type { ScanFilter };

export type ScanResult = {
  file: File;
  warpedBlob: Blob;
  previewUrl: string;
  detected: boolean;
};

const DETECT_MAX_EDGE = 480;
const OUTPUT_MAX_EDGE = 2000;

async function decodeToCanvas(blob: Blob): Promise<HTMLCanvasElement> {
  let bitmap: ImageBitmap;
  try {
    bitmap = await createImageBitmap(blob, { imageOrientation: 'from-image' });
  } catch {
    bitmap = await createImageBitmap(blob);
  }
  const canvas = document.createElement('canvas');
  canvas.width = bitmap.width;
  canvas.height = bitmap.height;
  const context = canvas.getContext('2d');
  if (!context) {
    bitmap.close();
    throw new Error('Could not read this photo');
  }
  context.drawImage(bitmap, 0, 0);
  bitmap.close();
  return canvas;
}

function canvasImageData(canvas: HTMLCanvasElement): ImageData {
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Could not read this photo');
  return context.getImageData(0, 0, canvas.width, canvas.height);
}

function putImage(image: ImageData): HTMLCanvasElement {
  const canvas = document.createElement('canvas');
  canvas.width = image.width;
  canvas.height = image.height;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Could not write this scan');
  context.putImageData(image, 0, 0);
  return canvas;
}

function canvasToBlob(canvas: HTMLCanvasElement, quality: number): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error('Could not save this scan'))),
      'image/jpeg',
      quality,
    );
  });
}

async function fileFromCanvas(canvas: HTMLCanvasElement, quality: number, name: string): Promise<File> {
  const blob = await canvasToBlob(canvas, quality);
  return new File([blob], name, { type: 'image/jpeg' });
}

function detectOn(image: ImageData) {
  const edge = Math.max(image.width, image.height);
  const scale = edge > DETECT_MAX_EDGE ? DETECT_MAX_EDGE / edge : 1;
  if (scale === 1) return detectDocumentQuad(image);
  const width = Math.max(1, Math.round(image.width * scale));
  const height = Math.max(1, Math.round(image.height * scale));
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext('2d');
  if (!context) return detectDocumentQuad(image);
  const source = putImage(image);
  context.drawImage(source, 0, 0, width, height);
  const quad = detectDocumentQuad(context.getImageData(0, 0, width, height));
  if (!quad) return null;
  return scaleQuad(quad, image.width / width, image.height / height);
}

async function scanSource(source: ImageData, filter: ScanFilter, fileName: string, crop: boolean): Promise<ScanResult> {
  const detected = crop ? detectOn(source) : null;
  let warped = source;
  if (detected) {
    const quad = insetQuad(detected, 0.012);
    const size = outputSizeForQuad(quad, OUTPUT_MAX_EDGE);
    warped = warpQuad(source, quad, size.width, size.height);
  } else {
    const edge = Math.max(source.width, source.height);
    if (edge > OUTPUT_MAX_EDGE) {
      const scale = OUTPUT_MAX_EDGE / edge;
      const canvas = putImage(source);
      const resized = document.createElement('canvas');
      resized.width = Math.max(1, Math.round(source.width * scale));
      resized.height = Math.max(1, Math.round(source.height * scale));
      const context = resized.getContext('2d');
      if (context) {
        context.drawImage(canvas, 0, 0, resized.width, resized.height);
        warped = context.getImageData(0, 0, resized.width, resized.height);
      }
    }
  }

  const warpedCanvas = putImage(warped);
  const warpedBlob = await canvasToBlob(warpedCanvas, 0.92);
  const filtered = applyScanFilter(warped, filter);
  const file = await fileFromCanvas(putImage(filtered), filter === 'photo' ? 0.84 : 0.88, fileName);
  return {
    file,
    warpedBlob,
    previewUrl: URL.createObjectURL(file),
    detected: Boolean(detected),
  };
}

export async function scanPhoto(
  blob: Blob,
  filter: ScanFilter,
  fileName = 'scan.jpg',
  options: { crop?: boolean } = {},
): Promise<ScanResult> {
  const sourceCanvas = await decodeToCanvas(blob);
  return scanSource(canvasImageData(sourceCanvas), filter, fileName, options.crop !== false);
}

export async function rescanWithFilter(warpedBlob: Blob, filter: ScanFilter, fileName = 'scan.jpg'): Promise<File> {
  const canvas = await decodeToCanvas(warpedBlob);
  const filtered = applyScanFilter(canvasImageData(canvas), filter);
  return fileFromCanvas(putImage(filtered), filter === 'photo' ? 0.84 : 0.88, fileName);
}

export async function scanCanvas(
  canvas: HTMLCanvasElement,
  filter: ScanFilter,
  fileName = 'scan.jpg',
  options: { crop?: boolean } = {},
): Promise<ScanResult> {
  return scanSource(canvasImageData(canvas), filter, fileName, options.crop !== false);
}
