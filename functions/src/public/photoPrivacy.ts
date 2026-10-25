import {Jimp} from "jimp";

/**
 * Turns a citizen's report photo into the copy that may be shown publicly
 * in the feed. Pure image work — the Vision call and Storage I/O live in
 * `publishPhoto.ts` — so the blur is testable on a fixture
 * (`npm run verify:photo`).
 *
 * What the public copy guarantees:
 *  - every detected **face** and **number plate** is heavily blurred, with
 *    padding, because a detector's box is tight and a half-blurred face is
 *    still a face;
 *  - it is **re-encoded from pixels**, so EXIF — including the GPS point
 *    the phone stamped on it — does not survive;
 *  - it is at most [PUBLIC_MAX_PX] on its long side.
 */

export const ANALYSE_MAX_PX = 1600;
export const PUBLIC_MAX_PX = 1080;
const PAD = 0.15;

export interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}

type Vertex = {x?: number | null; y?: number | null};

/** Pixel-space box around a polygon, padded and clamped to the image. */
export function boxFromVertices(
  vertices: Vertex[],
  width: number,
  height: number,
  normalised = false,
): Box | null {
  const xs = vertices.map((v) => (v.x ?? 0) * (normalised ? width : 1));
  const ys = vertices.map((v) => (v.y ?? 0) * (normalised ? height : 1));
  if (!xs.length) return null;
  let x0 = Math.min(...xs);
  let y0 = Math.min(...ys);
  let x1 = Math.max(...xs);
  let y1 = Math.max(...ys);
  const padX = (x1 - x0) * PAD;
  const padY = (y1 - y0) * PAD;
  x0 = Math.max(0, Math.floor(x0 - padX));
  y0 = Math.max(0, Math.floor(y0 - padY));
  x1 = Math.min(width, Math.ceil(x1 + padX));
  y1 = Math.min(height, Math.ceil(y1 + padY));
  if (x1 - x0 < 2 || y1 - y0 < 2) return null;
  return {x: x0, y: y0, w: x1 - x0, h: y1 - y0};
}

/** The subset of a Vision `annotateImage` response this module reads. */
export interface VisionResult {
  faceAnnotations?: Array<{boundingPoly?: {vertices?: Vertex[] | null} | null}> | null;
  localizedObjectAnnotations?: Array<{
    name?: string | null;
    boundingPoly?: {normalizedVertices?: Vertex[] | null} | null;
  }> | null;
  safeSearchAnnotation?: {
    adult?: string | number | null;
    violence?: string | number | null;
    racy?: string | number | null;
  } | null;
}

const UNSAFE = new Set(["LIKELY", "VERY_LIKELY", 4, 5]);

/** True when Vision thinks the photo is unfit for a public feed. */
export function isUnsafe(result: VisionResult): boolean {
  const s = result.safeSearchAnnotation;
  if (!s) return false;
  return [s.adult, s.violence, s.racy].some((v) => v != null && UNSAFE.has(v));
}

export function sensitiveBoxes(
  result: VisionResult,
  width: number,
  height: number,
): {faces: Box[]; plates: Box[]} {
  const faces = (result.faceAnnotations ?? [])
    .map((f) => boxFromVertices(f.boundingPoly?.vertices ?? [], width, height))
    .filter((b): b is Box => b != null);
  const plates = (result.localizedObjectAnnotations ?? [])
    .filter((o) => /licen[cs]e plate/i.test(o.name ?? ""))
    .map((o) => boxFromVertices(o.boundingPoly?.normalizedVertices ?? [], width, height, true))
    .filter((b): b is Box => b != null);
  return {faces, plates};
}

type JimpImage = Awaited<ReturnType<typeof Jimp.read>>;

/** Blurs each box in place — strong enough that a face can't be
 * recognised, scaled with the box so a large close-up is not just softened. */
export function blurRegions(img: JimpImage, boxes: Box[]): void {
  for (const b of boxes) {
    const radius = Math.max(12, Math.round(Math.min(b.w, b.h) / 4));
    const piece = img.clone().crop({x: b.x, y: b.y, w: b.w, h: b.h});
    // Two passes: jimp's blur is a box blur, and one pass leaves edges.
    piece.blur(radius).blur(radius);
    img.composite(piece, b.x, b.y);
  }
}

/** Decodes any input photo, downsized for analysis. */
export async function loadForAnalysis(input: Buffer): Promise<JimpImage> {
  const img = await Jimp.read(input);
  if (Math.max(img.bitmap.width, img.bitmap.height) > ANALYSE_MAX_PX) {
    img.scaleToFit({w: ANALYSE_MAX_PX, h: ANALYSE_MAX_PX});
  }
  return img;
}

export async function toJpeg(img: JimpImage, quality = 82): Promise<Buffer> {
  return img.getBuffer("image/jpeg", {quality});
}

/** Blur, shrink and re-encode: the public copy. */
export async function renderPublicCopy(
  img: JimpImage,
  boxes: Box[],
): Promise<{buffer: Buffer; width: number; height: number}> {
  blurRegions(img, boxes);
  if (Math.max(img.bitmap.width, img.bitmap.height) > PUBLIC_MAX_PX) {
    img.scaleToFit({w: PUBLIC_MAX_PX, h: PUBLIC_MAX_PX});
  }
  const buffer = await toJpeg(img);
  return {buffer, width: img.bitmap.width, height: img.bitmap.height};
}
