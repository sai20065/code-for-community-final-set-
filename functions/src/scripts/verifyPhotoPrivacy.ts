/**
 * Checks the public-photo pipeline on a synthetic image — no Vision call,
 * no Storage.  npm run verify:photo
 *
 *  - pixels inside a "face" box change; pixels well outside don't;
 *  - the output carries no EXIF (so no GPS point);
 *  - the output is at most PUBLIC_MAX_PX on its long side;
 *  - Vision boxes (pixel and normalised) map to padded image boxes, and
 *    only "License plate" objects count as plates;
 *  - SafeSearch LIKELY / VERY_LIKELY rejects the photo.
 */
import {Jimp} from "jimp";
import {
  PUBLIC_MAX_PX,
  isUnsafe,
  loadForAnalysis,
  renderPublicCopy,
  sensitiveBoxes,
} from "../public/photoPrivacy";

/** A minimal JPEG APP1 Exif segment carrying a GPS IFD marker. */
function withFakeExif(jpeg: Buffer): Buffer {
  const exif = Buffer.concat([
    Buffer.from([0xff, 0xe1, 0x00, 0x16]),
    Buffer.from("Exif\0\0GPSLatitude12", "latin1"),
  ]);
  return Buffer.concat([jpeg.subarray(0, 2), exif, jpeg.subarray(2)]);
}

async function main(): Promise<void> {
  const checks: Array<[string, boolean]> = [];

  // 2000x1500 with a sharp checkerboard, so blurring is measurable.
  const src = new Jimp({width: 2000, height: 1500, color: 0xffffffff});
  src.scan(0, 0, 2000, 1500, (x, y, idx) => {
    const on = (Math.floor(x / 8) + Math.floor(y / 8)) % 2 === 0;
    src.bitmap.data[idx] = src.bitmap.data[idx + 1] = src.bitmap.data[idx + 2] = on ? 0 : 255;
  });
  const input = withFakeExif(await src.getBuffer("image/jpeg", {quality: 95}));
  checks.push(["fixture really carries an Exif segment", input.includes(Buffer.from("Exif\0\0"))]);

  const img = await loadForAnalysis(input);
  const w = img.bitmap.width;
  const h = img.bitmap.height;
  const vision = {
    faceAnnotations: [{boundingPoly: {vertices: [{x: 400, y: 300}, {x: 600, y: 300}, {x: 600, y: 520}, {x: 400, y: 520}]}}],
    localizedObjectAnnotations: [
      {name: "License plate", boundingPoly: {normalizedVertices: [{x: 0.7, y: 0.8}, {x: 0.8, y: 0.8}, {x: 0.8, y: 0.85}, {x: 0.7, y: 0.85}]}},
      {name: "Car", boundingPoly: {normalizedVertices: [{x: 0.1, y: 0.1}, {x: 0.3, y: 0.1}, {x: 0.3, y: 0.3}, {x: 0.1, y: 0.3}]}},
    ],
  };
  const {faces, plates} = sensitiveBoxes(vision, w, h);
  checks.push(["one face, one plate (cars are not plates)", faces.length === 1 && plates.length === 1]);
  checks.push(["face box is padded beyond the detector box", faces[0].x < 400 && faces[0].x + faces[0].w > 600]);

  const before = img.clone();
  const out = await renderPublicCopy(img, [...faces, ...plates]);
  checks.push([`long side <= ${PUBLIC_MAX_PX}px`, Math.max(out.width, out.height) <= PUBLIC_MAX_PX]);
  checks.push(["no Exif in the public copy", !out.buffer.includes(Buffer.from("Exif\0\0")) &&
    !out.buffer.includes(Buffer.from("GPSLatitude"))]);

  // Compare the face centre and a far corner against the pre-blur image,
  // after scaling both to the output size.
  const after = await Jimp.read(out.buffer);
  before.scaleToFit({w: PUBLIC_MAX_PX, h: PUBLIC_MAX_PX});
  const scale = out.width / w;
  const variance = (im: typeof after, cx: number, cy: number) => {
    const vals: number[] = [];
    for (let dx = -10; dx <= 10; dx++) {
      for (let dy = -10; dy <= 10; dy++) {
        vals.push(im.bitmap.data[((cy + dy) * im.bitmap.width + (cx + dx)) * 4]);
      }
    }
    const mean = vals.reduce((a, b) => a + b, 0) / vals.length;
    return vals.reduce((a, b) => a + (b - mean) ** 2, 0) / vals.length;
  };
  const faceX = Math.round(500 * scale);
  const faceY = Math.round(410 * scale);
  checks.push(["face area is blurred (contrast collapses)",
    variance(after, faceX, faceY) < variance(before, faceX, faceY) * 0.2]);
  const farX = Math.round(1500 * scale);
  const farY = Math.round(200 * scale);
  checks.push(["far from any box stays sharp",
    variance(after, farX, farY) > variance(before, farX, farY) * 0.5]);

  checks.push(["SafeSearch LIKELY adult is rejected", isUnsafe({safeSearchAnnotation: {adult: "LIKELY"}})]);
  checks.push(["SafeSearch POSSIBLE is allowed", !isUnsafe({safeSearchAnnotation: {adult: "POSSIBLE", violence: "UNLIKELY"}})]);

  let failures = 0;
  for (const [name, ok] of checks) {
    if (!ok) failures++;
    console.log(`${ok ? "ok  " : "FAIL"}  ${name}`);
  }
  console.log(`\n${checks.length - failures}/${checks.length} passed`);
  process.exit(failures ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
