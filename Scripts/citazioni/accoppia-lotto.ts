#!/usr/bin/env bun
/**
 * Accoppia a lotti: per ogni citazione di un autore, le prime N candidate inglesi.
 *
 * Uso: bun accoppia-lotto.ts <autore> <file EN> <sezione-da-opera> [da] [quante]
 *   bun accoppia-lotto.ts Seneca seneca-lettere-en.txt "Letter %N" 0 20
 *
 * `%N` nella sezione viene sostituito col numero preso dall'opera italiana — «Lettere a Lucilio,
 * 82» dà «Letter 82». È il modo in cui l'indicizzazione che già c'è (il numero della lettera)
 * fa il lavoro pesante: invece di cercare in 1,2 MB si cerca dentro la lettera giusta.
 *
 * Il tool NON sceglie e non scrive niente: stampa i candidati e basta. La scelta di quale frase
 * inglese corrisponde è una lettura, e delegarla a un punteggio sarebbe rimettere in mezzo la
 * traduzione automatica dalla porta di servizio.
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";

const [autore, fileEN, schemaSezione, daStr = "0", quanteStr = "20"] = process.argv.slice(2);
if (!autore || !fileEN || !schemaSezione) {
  console.error("uso: bun accoppia-lotto.ts <autore> <file EN> <sezione con %N> [da] [quante]");
  process.exit(2);
}
const da = Number(daStr), quante = Number(quanteStr);

const QUI = dirname(new URL(import.meta.url).pathname);
const OTIUM = join(QUI, "..", "..");

// Le citazioni dell'autore che non hanno ancora l'inglese: quelle con tre argomenti.
const src = readFileSync(join(OTIUM, "Sources/OtiumCore/Quotes.swift"), "utf8");
type C = { it: string; opera: string; originale?: string };
const citazioni: C[] = [];
for (const m of src.matchAll(/^\s*q\("((?:[^"\\]|\\.)*)",\s*"([^"]+)",\s*"([^"]+)"\)/gm)) {
  if (m[2] !== autore) continue;
  citazioni.push({ it: m[1]!.replace(/\\"/g, '"'), opera: m[3]! });
}

// L'originale, dove esiste: è il segnale migliore, perché latino e tedesco condividono con
// l'inglese dotto molto più lessico di quanto ne condivida l'italiano.
const originali = new Map<string, string>();
for (const f of ["passate.json", "passate-2.json"]) {
  const p = join(QUI, f);
  if (!existsSync(p)) continue;
  for (const q of JSON.parse(readFileSync(p, "utf8"))) originali.set(q.it, q.originale);
}
for (const c of citazioni) c.originale = originali.get(c.it);

const righeEN = readFileSync(join(QUI, "fonti", fileEN), "utf8").split("\n");

const radici = (s: string): Set<string> =>
  new Set(
    s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
      .split(/[^a-z]+/).filter((w) => w.length >= 5).map((w) => w.slice(0, 4)),
  );

function sezioneDi(opera: string): string {
  const numero = opera.match(/(\d+)\s*$/)?.[1] ?? opera.split(", ").pop() ?? "";
  return schemaSezione.replace("%N", numero);
}

function frasiDi(sezione: string): string[] {
  const i = righeEN.findIndex((r) => r.startsWith("@@@ ") && r.endsWith(sezione));
  if (i < 0) return [];
  let fine = righeEN.length;
  for (let k = i + 1; k < righeEN.length; k++) if (righeEN[k]!.startsWith("@@@ ")) { fine = k; break; }
  const testo = righeEN.slice(i + 1, fine).join("\n");
  const out: string[] = [];
  for (const p of testo.split(/\n\s*\n/).map((x) => x.split("\n").map((r) => r.trim()).join(" "))) {
    for (const f of p.split(/(?<=[.!?])\s+/)) {
      const t = f.trim().replace(/^[“"]?\s*/, "");
      if (t.length >= 35 && t.length <= 300 && !t.includes("{") && !t.includes("djvu")) out.push(t);
    }
  }
  return out;
}

const fetta = citazioni.slice(da, da + quante);
console.log(`${autore}: ${citazioni.length} senza inglese · mostro ${da}–${da + fetta.length - 1}\n`);

for (const [i, c] of fetta.entries()) {
  const sezione = sezioneDi(c.opera);
  const frasi = frasiDi(sezione);
  console.log(`──── ${da + i} · ${c.opera} → ${sezione}`);
  console.log(`  IT  ${c.it}`);
  if (c.originale) console.log(`  OR  ${c.originale}`);
  if (!frasi.length) { console.log(`  ⚠ sezione «${sezione}» non trovata nel file\n`); continue; }
  const cercate = radici(`${c.originale ?? ""} ${c.it}`);
  const scored = frasi
    .map((f) => { const r = radici(f); let n = 0; for (const x of cercate) if (r.has(x)) n++; return { f, n }; })
    .filter((x) => x.n > 0)
    .sort((a, b) => b.n - a.n || a.f.length - b.f.length)
    .slice(0, 3);
  if (!scored.length) console.log(`  (nessuna sovrapposizione fra ${frasi.length} frasi)`);
  for (const s of scored) console.log(`  [${s.n}] ${s.f}`);
  console.log();
}
