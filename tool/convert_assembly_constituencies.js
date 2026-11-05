/**
 * One-off: DataMeet India_AC shapefile -> Karnataka assembly constituencies
 * GeoJSON for functions/src/data/karnataka_assembly.json.
 *
 * Source: https://github.com/datameet/maps/tree/master/assembly-constituencies
 * (CC BY 2.5 India). Coordinates are rounded to 5 decimals (~1 m).
 *
 *   npm install shapefile          (in any scratch folder)
 *   NODE_PATH=<that folder>/node_modules node tool/convert_assembly_constituencies.js \
 *       <path/to/India_AC.shp> functions/src/data/karnataka_assembly.json
 */
const fs = require('fs');
const shapefile = require('shapefile');

const [, , shpPath, outPath] = process.argv;
if (!shpPath || !outPath) {
  console.error('usage: node convert_assembly_constituencies.js <India_AC.shp> <out.json>');
  process.exit(1);
}

const round = (c) =>
  typeof c[0] === 'number' ? [Math.round(c[0] * 1e5) / 1e5, Math.round(c[1] * 1e5) / 1e5] : c.map(round);

(async () => {
  const src = await shapefile.open(shpPath, shpPath.replace(/\.shp$/i, '.dbf'));
  const features = [];
  let firstProps;
  for (;;) {
    const r = await src.read();
    if (r.done) break;
    const p = r.value.properties;
    firstProps = firstProps || p;
    const state = String(p.ST_NAME || p.STATE || '').toUpperCase();
    if (!state.includes('KARNATAKA')) continue;
    const no = Number(p.AC_NO ?? p.AC_NUMBER);
    // The source has one unnamed AC_NO 0 sliver in Bengaluru; not a seat.
    if (!no) continue;
    features.push({
      type: 'Feature',
      properties: {
        ac_no: no,
        ac_name: String(p.AC_NAME || '').trim(),
        pc_no: p.PC_NO != null ? Number(p.PC_NO) : null,
        district: p.DIST_NAME ? String(p.DIST_NAME).trim() : null,
      },
      geometry: {type: r.value.geometry.type, coordinates: round(r.value.geometry.coordinates)},
    });
  }
  features.sort((a, b) => a.properties.ac_no - b.properties.ac_no);
  fs.writeFileSync(outPath, JSON.stringify({
    type: 'FeatureCollection',
    _source: 'DataMeet maps/assembly-constituencies India_AC (CC BY 2.5 India), Karnataka only.',
    features,
  }));
  console.log('sample source properties:', JSON.stringify(firstProps));
  console.log(`wrote ${features.length} Karnataka assembly constituencies to ${outPath}`);
})();
