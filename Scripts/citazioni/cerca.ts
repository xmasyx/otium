#!/usr/bin/env bun
/**
 * Cerca in un testo primario e stampa la finestra intorno, con riga e collocazione.
 *
 * Uso: bun cerca.ts <file in fonti/> <regex> [finestra=180] [max=20]
 *
 * Serve a leggere i passi senza riversare in contesto interi capitoli: la citazione si sceglie
 * guardando la frase e il suo intorno, non l'opera intera.
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";

const [file, pattern, fin = "180", max = "20"] = process.argv.slice(2);
if (!file || !pattern) { console.error("uso: bun cerca.ts <file> <regex> [finestra] [max]"); process.exit(2); }

const QUI = dirname(new URL(import.meta.url).pathname);
const testo = readFileSync(join(QUI, "fonti", file), "utf8");
const righe = testo.split("\n");

// offset di inizio di ogni riga, per dire in che riga cade una corrispondenza
const inizi: number[] = [];
let acc = 0;
for (const r of righe) { inizi.push(acc); acc += r.length + 1; }
const rigaDi = (off: number) => {
  let lo = 0, hi = inizi.length - 1, r = 0;
  while (lo <= hi) { const m = (lo + hi) >> 1; if (inizi[m]! <= off) { r = m; lo = m + 1; } else hi = m - 1; }
  return r;
};
const collocazione = (i: number) => {
  for (let k = i; k >= 0 && k > i - 500; k--) {
    const r = righe[k]!.trim();
    if (r.startsWith("@@@ ")) return r.slice(4);
    if (/^==\s*.+\s*==$/.test(r)) return r.replace(/^=+\s*|\s*=+$/g, "");
  }
  for (let k = i; k >= 0 && k > i - 80; k--) {
    const r = righe[k]!.trim();
    if (r && r.length <= 70 && /^[A-ZÀ-Ü0-9][A-ZÀ-Ü0-9 .,'’—:-]{4,69}$/.test(r)) return r;
  }
  return "?";
};

const re = new RegExp(pattern, "gi");
const N = Number(fin);
let n = 0;
for (const m of testo.matchAll(re)) {
  if (++n > Number(max)) { console.log(`… (altre corrispondenze oltre le ${max})`); break; }
  const off = m.index!;
  const i = rigaDi(off);
  const finestra = testo.slice(Math.max(0, off - N), off + m[0].length + N).replace(/\s+/g, " ");
  console.log(`\n[riga ${i + 1} · ${collocazione(i)}]\n…${finestra}…`);
}
if (!n) console.log("nessuna corrispondenza");
