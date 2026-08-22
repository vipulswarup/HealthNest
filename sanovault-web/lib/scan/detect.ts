import {
  approxPolyDP,
  convexHull,
  extremaQuad,
  orderQuad,
  perimeter,
  quadLooksLikePage,
  type Point,
  type Quad,
} from '@/lib/scan/geometry';

function toGray(pixels: Uint8ClampedArray, width: number, height: number): Uint8Array {
  const gray = new Uint8Array(width * height);
  for (let i = 0; i < gray.length; i += 1) {
    const offset = i * 4;
    gray[i] = 0.299 * pixels[offset] + 0.587 * pixels[offset + 1] + 0.114 * pixels[offset + 2];
  }
  return gray;
}

function blur3(gray: Uint8Array, width: number, height: number): Uint8Array {
  const out = new Uint8Array(gray.length);
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      let sum = 0;
      let count = 0;
      for (let dy = -1; dy <= 1; dy += 1) {
        const yy = y + dy;
        if (yy < 0 || yy >= height) continue;
        for (let dx = -1; dx <= 1; dx += 1) {
          const xx = x + dx;
          if (xx < 0 || xx >= width) continue;
          sum += gray[yy * width + xx];
          count += 1;
        }
      }
      out[y * width + x] = sum / count;
    }
  }
  return out;
}

function otsu(gray: Uint8Array): number {
  const hist = new Float64Array(256);
  for (let i = 0; i < gray.length; i += 1) hist[gray[i]] += 1;
  const total = gray.length;
  let sum = 0;
  for (let i = 0; i < 256; i += 1) sum += i * hist[i];
  let sumB = 0;
  let wB = 0;
  let max = 0;
  let thresh = 127;
  for (let t = 0; t < 256; t += 1) {
    wB += hist[t];
    if (!wB) continue;
    const wF = total - wB;
    if (!wF) break;
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const between = wB * wF * (mB - mF) * (mB - mF);
    if (between > max) {
      max = between;
      thresh = t;
    }
  }
  return thresh;
}

function threshold(gray: Uint8Array, cutoff: number, invert: boolean): Uint8Array {
  const out = new Uint8Array(gray.length);
  for (let i = 0; i < gray.length; i += 1) {
    const white = gray[i] >= cutoff;
    out[i] = (invert ? !white : white) ? 1 : 0;
  }
  return out;
}

function sobelEdges(gray: Uint8Array, width: number, height: number): Uint8Array {
  const out = new Uint8Array(gray.length);
  for (let y = 1; y < height - 1; y += 1) {
    for (let x = 1; x < width - 1; x += 1) {
      const i = y * width + x;
      const gx =
        -gray[i - width - 1] + gray[i - width + 1]
        - 2 * gray[i - 1] + 2 * gray[i + 1]
        - gray[i + width - 1] + gray[i + width + 1];
      const gy =
        -gray[i - width - 1] - 2 * gray[i - width] - gray[i - width + 1]
        + gray[i + width - 1] + 2 * gray[i + width] + gray[i + width + 1];
      out[i] = Math.hypot(gx, gy) > 90 ? 1 : 0;
    }
  }
  return out;
}

function dilate(binary: Uint8Array, width: number, height: number): Uint8Array {
  const out = new Uint8Array(binary.length);
  for (let y = 1; y < height - 1; y += 1) {
    for (let x = 1; x < width - 1; x += 1) {
      let on = 0;
      for (let dy = -1; dy <= 1 && !on; dy += 1) {
        for (let dx = -1; dx <= 1; dx += 1) {
          if (binary[(y + dy) * width + (x + dx)]) {
            on = 1;
            break;
          }
        }
      }
      out[y * width + x] = on;
    }
  }
  return out;
}

function blobBoundary(binary: Uint8Array, width: number, height: number): Point[] {
  const seen = new Uint8Array(binary.length);
  const qx = new Int32Array(binary.length);
  const qy = new Int32Array(binary.length);
  let best: Point[] = [];

  const isOn = (x: number, y: number) => x >= 0 && y >= 0 && x < width && y < height && binary[y * width + x];

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const start = y * width + x;
      if (!binary[start] || seen[start]) continue;
      let head = 0;
      let tail = 0;
      qx[0] = x;
      qy[0] = y;
      seen[start] = 1;
      tail = 1;
      const border: Point[] = [];
      while (head < tail) {
        const cx = qx[head];
        const cy = qy[head];
        head += 1;
        const edge = !isOn(cx - 1, cy) || !isOn(cx + 1, cy) || !isOn(cx, cy - 1) || !isOn(cx, cy + 1);
        if (edge) border.push({ x: cx, y: cy });
        const neighbors = [cx + 1, cy, cx - 1, cy, cx, cy + 1, cx, cy - 1];
        for (let n = 0; n < 8; n += 2) {
          const nx = neighbors[n];
          const ny = neighbors[n + 1];
          if (!isOn(nx, ny)) continue;
          const index = ny * width + nx;
          if (seen[index]) continue;
          seen[index] = 1;
          qx[tail] = nx;
          qy[tail] = ny;
          tail += 1;
        }
      }
      if (border.length > best.length) best = border;
    }
  }
  return best;
}

function quadFromPoints(points: Point[]): Quad | null {
  if (points.length < 20) return null;
  const hull = convexHull(points);
  if (hull.length < 4) return null;
  const closed = hull.concat([hull[0]]);
  const simplified = approxPolyDP(closed, Math.max(3, 0.02 * perimeter(hull)));
  const unique = simplified.slice(0, -1);
  if (unique.length === 4) return orderQuad(unique);
  return extremaQuad(hull);
}

function candidateFromBinary(binary: Uint8Array, width: number, height: number): Quad | null {
  const points = blobBoundary(binary, width, height);
  const quad = quadFromPoints(points);
  if (!quad) return null;
  return quadLooksLikePage(quad, width, height) ? quad : null;
}

export function detectDocumentQuad(image: ImageData): Quad | null {
  const { width, height, data } = image;
  if (width < 24 || height < 24) return null;
  const gray = blur3(toGray(data, width, height), width, height);
  const cutoff = otsu(gray);
  const paper = candidateFromBinary(threshold(gray, cutoff, false), width, height);
  if (paper) return paper;
  const inverted = candidateFromBinary(threshold(gray, cutoff, true), width, height);
  if (inverted) return inverted;
  const edges = candidateFromBinary(dilate(sobelEdges(gray, width, height), width, height), width, height);
  return edges;
}

export function drawQuadOverlay(canvas: HTMLCanvasElement, quad: Quad | null, sourceWidth: number, sourceHeight: number) {
  const context = canvas.getContext('2d');
  if (!context) return;
  context.clearRect(0, 0, canvas.width, canvas.height);
  if (!quad) return;
  const sx = canvas.width / sourceWidth;
  const sy = canvas.height / sourceHeight;
  context.strokeStyle = '#34d399';
  context.lineWidth = Math.max(3, canvas.width / 180);
  context.beginPath();
  context.moveTo(quad.tl.x * sx, quad.tl.y * sy);
  context.lineTo(quad.tr.x * sx, quad.tr.y * sy);
  context.lineTo(quad.br.x * sx, quad.br.y * sy);
  context.lineTo(quad.bl.x * sx, quad.bl.y * sy);
  context.closePath();
  context.stroke();
}
