// Synthesises the sound played when a book is tapped and slides off the shelf: a soft knock of
// the book leaving its neighbours, then a short papery swish. Deterministic (seeded), so running
// it again gives the same file. No samples or third-party audio are used.
//
//   node design/sounds/make-book-sound.mjs
//
// Writes Shelfie/Resources/Sounds/book-pull.wav (44.1 kHz, 16-bit, mono).
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rate = 44100;
const duration = 0.34;
const count = Math.round(rate * duration);
const out = new Float64Array(count);

// Small seeded random generator (mulberry32).
let seed = 20260928;
const random = () => {
  seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
};
const noise = () => random() * 2 - 1;

// Biquad band-pass (RBJ cookbook), used to shape noise into a paper/cardboard swish.
function bandPass(center, q) {
  const w = (2 * Math.PI * center) / rate;
  const alpha = Math.sin(w) / (2 * q);
  const a0 = 1 + alpha;
  const b0 = alpha / a0, b2 = -alpha / a0, a1 = (-2 * Math.cos(w)) / a0, a2 = (1 - alpha) / a0;
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  return (x) => {
    const y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x; y2 = y1; y1 = y;
    return y;
  };
}

// 1. The knock: a low, quickly damped thump with a falling pitch, plus a tiny bright click.
let phase = 0;
for (let i = 0; i < count; i++) {
  const t = i / rate;
  const frequency = 140 + 60 * Math.exp(-t / 0.02);
  phase += (2 * Math.PI * frequency) / rate;
  out[i] += 0.55 * Math.sin(phase) * Math.exp(-t / 0.028);
  out[i] += 0.25 * noise() * Math.exp(-t / 0.003);
}

// 2. The swish: band-passed noise that rises quickly and fades out, with an uneven "friction"
// wobble so it sounds like a cover rubbing past its neighbours rather than a steady hiss.
const swishStart = 0.012;
const swishLength = duration - swishStart - 0.01;
const low = bandPass(900, 0.8);
const high = bandPass(3200, 1.1);
let wobble = 0.8;
for (let i = 0; i < count; i++) {
  const t = i / rate - swishStart;
  if (t < 0 || t > swishLength) continue;
  const x = t / swishLength;
  const envelope = Math.sin(Math.min(1, t / 0.045) * (Math.PI / 2)) * (1 - x) ** 2.2;
  // Friction: a slowly wandering level between about 0.55 and 1.
  wobble += (0.55 + 0.45 * random() - wobble) * 0.004;
  const n = noise();
  out[i] += envelope * wobble * (0.9 * low(n) + 0.45 * high(n));
}

// Gentle low-pass for warmth, a 10 ms fade-out, then normalise to -6 dBFS so it stays soft.
let smooth = 0;
for (let i = 0; i < count; i++) {
  smooth += (out[i] - smooth) * 0.55;
  out[i] = smooth;
}
const fade = Math.round(rate * 0.01);
for (let i = 0; i < fade; i++) out[count - 1 - i] *= i / fade;
const peak = out.reduce((m, v) => Math.max(m, Math.abs(v)), 0);
const gain = 0.5 / peak;

const data = Buffer.alloc(count * 2);
for (let i = 0; i < count; i++) {
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, out[i] * gain)) * 32767), i * 2);
}
const header = Buffer.alloc(44);
header.write('RIFF', 0);
header.writeUInt32LE(36 + data.length, 4);
header.write('WAVE', 8);
header.write('fmt ', 12);
header.writeUInt32LE(16, 16);      // fmt chunk size
header.writeUInt16LE(1, 20);       // PCM
header.writeUInt16LE(1, 22);       // mono
header.writeUInt32LE(rate, 24);
header.writeUInt32LE(rate * 2, 28); // byte rate
header.writeUInt16LE(2, 32);       // block align
header.writeUInt16LE(16, 34);      // bits per sample
header.write('data', 36);
header.writeUInt32LE(data.length, 40);

const target = path.join(path.dirname(fileURLToPath(import.meta.url)), '../../Shelfie/Resources/Sounds/book-pull.wav');
fs.mkdirSync(path.dirname(target), { recursive: true });
fs.writeFileSync(target, Buffer.concat([header, data]));
console.log(`Wrote ${path.relative(process.cwd(), target)} (${(duration * 1000).toFixed(0)} ms)`);
