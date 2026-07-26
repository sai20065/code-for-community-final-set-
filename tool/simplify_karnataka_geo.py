"""Generates the bundled statewide map assets from the full-precision data.

Reads `functions/src/data/karnataka_districts.json` and
`karnataka_taluks.json` (KGIS/KSRSAC official boundaries, ~5.5 MB combined)
and writes Douglas-Peucker-simplified copies to `assets/geo/`, ~750 KB
combined, for the statewide Karnataka map to draw all 30 districts and 227
taluks without a multi-megabyte Firestore read.

**The output is display-only.** Nothing routes, scores or assigns a citizen
to an area from these outlines — that is always point-in-polygon against the
full-precision data server-side (`functions/src/lib/talukGeo.ts`). A boundary
nudged a few hundred metres to make a drawing cheaper must never decide whose
MP hears a complaint.

Re-run after refreshing the source boundary data:

    python tool/simplify_karnataka_geo.py

Tolerances are in degrees: 0.004 ~= 400 m for districts, 0.002 ~= 200 m for
taluks. Both are well below what is visible at the zoom levels the statewide
map uses, and both preserve enough shape that a district stays recognisable.
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "geo"

# Deeply-nested coastal rings recurse further than the default limit allows.
sys.setrecursionlimit(200_000)


def _perpendicular_distance(point, start, end):
    (x, y), (x1, y1), (x2, y2) = point, start, end
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x - x1, y - y1)
    t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return math.hypot(x - (x1 + t * dx), y - (y1 + t * dy))


def _douglas_peucker(points, tolerance):
    if len(points) < 3:
        return points
    worst, index = 0.0, 0
    for i in range(1, len(points) - 1):
        d = _perpendicular_distance(points[i], points[0], points[-1])
        if d > worst:
            worst, index = d, i
    if worst > tolerance:
        left = _douglas_peucker(points[: index + 1], tolerance)
        right = _douglas_peucker(points[index:], tolerance)
        return left[:-1] + right
    return [points[0], points[-1]]


def _simplify_ring(ring, tolerance):
    simplified = _douglas_peucker([tuple(p[:2]) for p in ring], tolerance)
    # A ring that collapses below four points is no longer a polygon; drop it
    # rather than emitting a degenerate shape the renderer will choke on.
    if len(simplified) < 4:
        return None
    if simplified[0] != simplified[-1]:
        simplified.append(simplified[0])
    # Five decimals is ~1 m — far finer than the tolerance, and it halves the
    # file size versus the source's full float precision.
    return [[round(x, 5), round(y, 5)] for x, y in simplified]


def _simplify_geometry(geometry, tolerance):
    kind = geometry["type"]
    if kind == "Polygon":
        # Holes are dropped: these are outlines for orientation, not an exact
        # area render, and the client's own parser ignores them anyway.
        ring = _simplify_ring(geometry["coordinates"][0], tolerance)
        return {"type": "Polygon", "coordinates": [ring]} if ring else None
    if kind == "MultiPolygon":
        polygons = []
        for polygon in geometry["coordinates"]:
            ring = _simplify_ring(polygon[0], tolerance)
            if ring:
                polygons.append([ring])
        return {"type": "MultiPolygon", "coordinates": polygons} if polygons else None
    if kind == "GeometryCollection":
        polygons = []
        for sub in geometry["geometries"]:
            simplified = _simplify_geometry(sub, tolerance)
            if not simplified:
                continue
            if simplified["type"] == "Polygon":
                polygons.append(simplified["coordinates"])
            else:
                polygons.extend(simplified["coordinates"])
        return {"type": "MultiPolygon", "coordinates": polygons} if polygons else None
    return None


def build(name, source, tolerance, keys):
    data = json.loads((ROOT / source).read_text(encoding="utf-8"))
    features, dropped = [], 0
    for feature in data["features"]:
        geometry = _simplify_geometry(feature["geometry"], tolerance)
        if not geometry:
            dropped += 1
            continue
        props = feature["properties"]
        # Properties are stored positionally against a shared `keys` header:
        # repeating five key names across 227 features costs more bytes than
        # a whole simplification pass saves.
        features.append({"p": [props.get(k) for k in keys], "g": geometry})

    blob = json.dumps({"keys": list(keys), "features": features}, separators=(",", ":"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / f"karnataka_{name}.json").write_text(blob, encoding="utf-8")
    print(
        f"{name}: {len(features)} features, {dropped} dropped, "
        f"{round(len(blob.encode()) / 1024)} KB"
    )


def main():
    build(
        "districts",
        "functions/src/data/karnataka_districts.json",
        0.004,
        ("districtId", "name"),
    )
    build(
        "taluks",
        "functions/src/data/karnataka_taluks.json",
        0.002,
        ("talukId", "talukName", "districtId", "districtName", "constituencyId"),
    )


if __name__ == "__main__":
    main()
