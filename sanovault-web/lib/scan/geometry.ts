export type Point = { x: number; y: number };

export type Quad = {
  tl: Point;
  tr: Point;
  br: Point;
  bl: Point;
};

export function dist(a: Point, b: Point): number {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

export function quadPoints(quad: Quad): Point[] {
  return [quad.tl, quad.tr, quad.br, quad.bl];
}

export function scaleQuad(quad: Quad, scaleX: number, scaleY: number): Quad {
  const scale = (point: Point): Point => ({ x: point.x * scaleX, y: point.y * scaleY });
  return { tl: scale(quad.tl), tr: scale(quad.tr), br: scale(quad.br), bl: scale(quad.bl) };
}

export function insetQuad(quad: Quad, amount: number): Quad {
  const cx = (quad.tl.x + quad.tr.x + quad.br.x + quad.bl.x) / 4;
  const cy = (quad.tl.y + quad.tr.y + quad.br.y + quad.bl.y) / 4;
  const pull = (point: Point): Point => ({
    x: point.x + (cx - point.x) * amount,
    y: point.y + (cy - point.y) * amount,
  });
  return { tl: pull(quad.tl), tr: pull(quad.tr), br: pull(quad.br), bl: pull(quad.bl) };
}

export function shoelace(points: Point[]): number {
  let area = 0;
  for (let i = 0; i < points.length; i += 1) {
    const a = points[i];
    const b = points[(i + 1) % points.length];
    area += a.x * b.y - b.x * a.y;
  }
  return Math.abs(area) / 2;
}

export function convexHull(points: Point[]): Point[] {
  if (points.length < 3) return points.slice();
  const sorted = [...points].sort((a, b) => a.x - b.x || a.y - b.y);
  const cross = (origin: Point, a: Point, b: Point) =>
    (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x);
  const lower: Point[] = [];
  for (const point of sorted) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
      lower.pop();
    }
    lower.push(point);
  }
  const upper: Point[] = [];
  for (let i = sorted.length - 1; i >= 0; i -= 1) {
    const point = sorted[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
      upper.pop();
    }
    upper.push(point);
  }
  lower.pop();
  upper.pop();
  return lower.concat(upper);
}

export function extremaQuad(points: Point[]): Quad {
  let tl = points[0];
  let tr = points[0];
  let br = points[0];
  let bl = points[0];
  for (const point of points) {
    if (point.x + point.y < tl.x + tl.y) tl = point;
    if (-point.x + point.y < -tr.x + tr.y) tr = point;
    if (point.x + point.y > br.x + br.y) br = point;
    if (-point.x + point.y > -bl.x + bl.y) bl = point;
  }
  return { tl, tr, br, bl };
}

export function orderQuad(points: Point[]): Quad {
  if (points.length !== 4) return extremaQuad(points);
  const sorted = [...points].sort((a, b) => a.y - b.y || a.x - b.x);
  const top = [sorted[0], sorted[1]].sort((a, b) => a.x - b.x);
  const bottom = [sorted[2], sorted[3]].sort((a, b) => a.x - b.x);
  return { tl: top[0], tr: top[1], bl: bottom[0], br: bottom[1] };
}

function pointLineDistance(point: Point, a: Point, b: Point): number {
  const length = dist(a, b);
  if (length < 1e-6) return dist(point, a);
  return Math.abs((point.y - a.y) * (b.x - a.x) - (point.x - a.x) * (b.y - a.y)) / length;
}

export function approxPolyDP(points: Point[], epsilon: number): Point[] {
  if (points.length < 3) return points.slice();
  const first = points[0];
  const last = points[points.length - 1];
  let maxDistance = 0;
  let index = 0;
  for (let i = 1; i < points.length - 1; i += 1) {
    const distance = pointLineDistance(points[i], first, last);
    if (distance > maxDistance) {
      maxDistance = distance;
      index = i;
    }
  }
  if (maxDistance > epsilon) {
    const left = approxPolyDP(points.slice(0, index + 1), epsilon);
    const right = approxPolyDP(points.slice(index), epsilon);
    return left.slice(0, -1).concat(right);
  }
  return [first, last];
}

export function perimeter(points: Point[]): number {
  let length = 0;
  for (let i = 0; i < points.length; i += 1) {
    length += dist(points[i], points[(i + 1) % points.length]);
  }
  return length;
}

export function quadLooksLikePage(quad: Quad, width: number, height: number): boolean {
  const points = quadPoints(quad);
  const area = shoelace(points);
  const frame = width * height;
  if (area < frame * 0.08 || area > frame * 0.995) return false;
  const top = dist(quad.tl, quad.tr);
  const bottom = dist(quad.bl, quad.br);
  const left = dist(quad.tl, quad.bl);
  const right = dist(quad.tr, quad.br);
  const minSide = Math.min(top, bottom, left, right);
  if (minSide < Math.min(width, height) * 0.08) return false;
  const widthSide = (top + bottom) / 2;
  const heightSide = (left + right) / 2;
  const aspect = widthSide / Math.max(1, heightSide);
  return aspect > 0.28 && aspect < 3.6;
}
