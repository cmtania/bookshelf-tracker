// Adds Phosphor icons (phosphoricons.com, MIT licence) to the app as custom SF Symbols, so they
// behave like system symbols: they scale with the text, take the text colour and sit on the baseline.
//
//   node design/icons/make-symbols.mjs books flame-fill caret-left
//
// Names are Phosphor file names; "-fill" ones use the Fill weight, the rest Regular. Each becomes
// Shelfie/Resources/Assets.xcassets/Phosphor/ph-<name>.symbolset, used in code as Image("ph-<name>")
// or Label("Title", image: "ph-<name>"). Needs Node 18+ and internet (downloads from jsDelivr).
// Nothing is added to the app except the symbol files.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const version = '2.1.1';
const names = process.argv.slice(2);
if (names.length === 0) {
  console.error('Usage: node design/icons/make-symbols.mjs <phosphor-name> ...');
  process.exit(1);
}
const out = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../Shelfie/Resources/Assets.xcassets/Phosphor');

// Symbol template v.3.0, Regular-M only (Xcode uses it for every weight).
// Medium scale guides at 100 pt: baseline 1126, cap height 70.46. The icon is centred on the middle
// of the cap height, like SF Symbols.
const baselineM = 1126;
const capHeight = 70.4595;
const capMiddle = baselineM - capHeight / 2;
const left = 1391.3;
const scale = 0.365; // Phosphor's 256-unit box → 93.4 units: about the size of SF Symbols next to text
const tx = left;
const ty = capMiddle - 128 * scale;
const right = +(left + 256 * scale).toFixed(3);

function tokens(d) {
  const re = /([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)/g;
  const list = [];
  let m;
  while ((m = re.exec(d))) list.push(m[1] ?? Number(m[2]));
  return list;
}

/** Scales and moves path data from Phosphor's 256 box onto the template's Regular-M position. */
function transform(d) {
  const t = tokens(d);
  const counts = { M: 2, L: 2, H: 1, V: 1, C: 6, S: 4, Q: 4, T: 2, A: 7, Z: 0 };
  const round = (v) => +v.toFixed(3);
  const parts = [];
  let i = 0;
  let cmd = null;
  while (i < t.length) {
    if (typeof t[i] === 'string') {
      cmd = t[i++];
      parts.push(cmd);
      if (cmd.toUpperCase() === 'Z') continue;
    }
    const up = cmd.toUpperCase();
    const rel = cmd !== up;
    const n = counts[up];
    const a = t.slice(i, i + n);
    i += n;
    if (a.length < n || a.some((v) => typeof v !== 'number')) throw new Error(`Unexpected path data near token ${i}`);
    const X = (v) => round(rel ? v * scale : v * scale + tx);
    const Y = (v) => round(rel ? v * scale : v * scale + ty);
    let r;
    switch (up) {
      case 'H': r = [X(a[0])]; break;
      case 'V': r = [Y(a[0])]; break;
      case 'A': r = [round(a[0] * scale), round(a[1] * scale), a[2], a[3], a[4], X(a[5]), Y(a[6])]; break;
      default: r = a.map((v, k) => (k % 2 === 0 ? X(v) : Y(v)));
    }
    parts.push(r.join(' '));
    // Extra coordinate pairs after a moveto are linetos.
    if (up === 'M') cmd = rel ? 'l' : 'L';
  }
  return parts.join(' ');
}

const guide = (id, x1, y1, x2, y2) =>
  `    <line id="${id}" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"/>`;

function template(name, d) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<!-- ${name}: Phosphor Icons (MIT, phosphoricons.com), converted to a custom symbol for Shelfie. -->
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="3300" height="2200">
  <g id="Notes">
    <rect id="artboard" style="fill:white;opacity:1" x="0" y="0" width="3300" height="2200"/>
    <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>
    <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;" transform="matrix(1 0 0 1 263 1933)">${name}</text>
  </g>
  <g id="Guides">
${guide('Baseline-S', 263, 696, 3036, 696)}
${guide('Capline-S', 263, 625.541, 3036, 625.541)}
${guide('Baseline-M', 263, 1126, 3036, 1126)}
${guide('Capline-M', 263, 1055.54, 3036, 1055.54)}
${guide('Baseline-L', 263, 1556, 3036, 1556)}
${guide('Capline-L', 263, 1485.54, 3036, 1485.54)}
${guide('left-margin-Regular-M', left, 1030.79, left, 1150.12)}
${guide('right-margin-Regular-M', right, 1030.79, right, 1150.12)}
  </g>
  <g id="Symbols">
    <g id="Regular-M">
      <path d="${transform(d)}"/>
    </g>
  </g>
</svg>
`;
}

const json = (value) => JSON.stringify(value, null, 2) + '\n';

fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, 'Contents.json'), json({ info: { author: 'xcode', version: 1 } }));

let written = 0;
for (const icon of names) {
  const weight = icon.endsWith('-fill') ? 'fill' : 'regular';
  const response = await fetch(`https://cdn.jsdelivr.net/npm/@phosphor-icons/core@${version}/assets/${weight}/${icon}.svg`);
  if (!response.ok) {
    console.error(`Not found: ${icon} (check the name on phosphoricons.com)`);
    process.exitCode = 1;
    continue;
  }
  const svg = await response.text();
  const paths = svg.match(/<path d="([^"]+)"/g) ?? [];
  if (paths.length !== 1) {
    console.error(`Skipped ${icon}: expected exactly one path, found ${paths.length}`);
    process.exitCode = 1;
    continue;
  }
  const d = paths[0].slice('<path d="'.length, -1);
  const name = `ph-${icon}`;
  const dir = path.join(out, `${name}.symbolset`);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, `${name}.svg`), template(name, d));
  fs.writeFileSync(path.join(dir, 'Contents.json'), json({
    info: { author: 'xcode', version: 1 },
    symbols: [{ filename: `${name}.svg`, idiom: 'universal' }],
  }));
  written++;
}
console.log(`Wrote ${written} symbol(s) to ${path.relative(process.cwd(), out)}`);
