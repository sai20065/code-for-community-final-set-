import {PUBLIC_GEO_SNAP_DEGREES} from "../config";

/**
 * Coordinate blurring for anything published to the world-readable
 * dashboard.
 *
 * A civic report's exact coordinate is, very often, the reporter's own home.
 * Publishing that alongside "waterlogging complaint, filed 12 June" tells
 * anyone who cares exactly which house complained about the neighbours'
 * drain — which is precisely the kind of exposure that stops people
 * reporting at all.
 */

/** FNV-1a. A tiny non-cryptographic hash — this needs to be *stable and
 * uniform*, not secure. */
function fnv1a(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

/**
 * Snaps a coordinate to a ~330 m grid, then offsets it within the cell by a
 * **deterministic** amount derived from [seed].
 *
 * The determinism is the point, and it is easy to get wrong. Re-rolling a
 * random jitter on every write would look more private but be strictly less
 * so: an observer who reads the same pin repeatedly could average the noise
 * out and recover the true position. Keying the offset to the document id
 * means the pin is identical on every read, forever, and there is nothing to
 * average.
 *
 * The offset is bounded to 60% of a cell so a point cannot drift into a
 * neighbouring cell and defeat the snapping.
 */
export function snapCoordinate(
  lat: number,
  lng: number,
  seed: string,
): {lat: number; lng: number} {
  const cell = PUBLIC_GEO_SNAP_DEGREES;
  const hash = fnv1a(seed);
  const jitterLat = ((hash & 0xffff) / 0xffff - 0.5) * cell * 0.6;
  const jitterLng = (((hash >>> 16) & 0xffff) / 0xffff - 0.5) * cell * 0.6;
  return {
    lat: Math.round(lat / cell) * cell + jitterLat,
    lng: Math.round(lng / cell) * cell + jitterLng,
  };
}
