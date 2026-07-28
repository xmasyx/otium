#!/usr/bin/env bun
/**
 * Il cancello delle citazioni: fail-closed, nessuna frase entra senza un riscontro sul testo.
 *
 * Uso: bun verifica-citazioni.ts <candidati.json> [--contesto N]
 *
 * Ogni candidato porta il frammento in **lingua originale**. Il tool lo cerca nel file scaricato
 * (confronto su testo appiattito, perché l'a capo di una scansione non è un fatto sul testo) e
 * restituisce riga e collocazione. Se non lo trova, esce 1 e la frase non si scrive.
 *
 * Perché esiste. Il 28 luglio 2026 cinque citazioni false erano entrate nel pool firmato, tutte
 * da aggregatori. «L'ho letta» e «l'ho provata» sembrano la stessa cosa finché qualcuno non
 * chiede il numero del verso. Questo tool è la differenza.
 *
 * Controlla anche quello che controllano i test Swift, ma prima di compilare: doppioni di testo,
 * collisioni di identificativo, opere tentennanti, markdown crudo.
 */

import { readFileSync, existsSync } from "node:fs";
import { basename, dirname, join } from "node:path";

type Candidato = {
  it: string;          // la resa italiana che finirà a schermo
  originale: string;   // il frammento da cercare, in lingua originale
  autore: string;
  opera: string;       // come apparirà sotto la frase, con il numero
  fonte: string;       // nome del file in fonti/
  pool?: "quotes" | "mindful";
};

const [file, ...rest] = process.argv.slice(2);
if (!file) { console.error("uso: bun verifica-citazioni.ts <candidati.json> [--contesto N]"); process.exit(2); }
const contesto = Number(rest[rest.indexOf("--contesto") + 1]) || 0;

const QUI = dirname(new URL(import.meta.url).pathname);
const FONTI = join(QUI, "fonti");
const OTIUM = `${process.env.HOME}/Desktop/lifeos/05-Tools/Otium/Sources/OtiumCore`;

const candidati: Candidato[] = JSON.parse(readFileSync(file, "utf8"));

/** Appiattisce: un a capo dentro una frase non è un fatto sul testo, è impaginazione. */
const piatto = (s: string) =>
  s.normalize("NFC")
    .replace(/[‘’ʼ`´]/g, "'")
    .replace(/[“”«»]/g, '"')
    .replace(/[‐-―−]/g, "-")
    .replace(/\s+/g, " ")
    .toLowerCase();

/** Testi già nel corpus, per non aggiungere un doppione che i test bocceranno dopo. */
function corpusEsistente(): { testi: Set<string>; id: Set<string> } {
  const testi = new Set<string>(), id = new Set<string>();
  for (const f of ["Quotes.swift", "Mindful.swift", "Facts.swift"]) {
    const p = join(OTIUM, f);
    if (!existsSync(p)) continue;
    const src = readFileSync(p, "utf8");
    for (const m of src.matchAll(/^\s*(?:q|m|t|f)\("((?:[^"\\]|\\.)*)"/gm)) {
      const t = m[1]!.replace(/\\"/g, '"');
      testi.add(piatto(t));
    }
    for (const m of src.matchAll(/^\s*q\("((?:[^"\\]|\\.)*)",\s*"([^"]+)"/gm)) {
      id.add(`${m[2]}-${m[1]!.replace(/\\"/g, '"').slice(0, 24)}`);
    }
  }
  return { testi, id };
}

const { testi: giaCiSono, id: giaId } = corpusEsistente();

const cache = new Map<string, { righe: string[]; piatta: string; offsets: number[] }>();
function fonte(nome: string) {
  if (cache.has(nome)) return cache.get(nome)!;
  const p = join(FONTI, nome);
  if (!existsSync(p)) throw new Error(`fonte assente: ${nome}`);
  const righe = readFileSync(p, "utf8").split("\n");
  // Indice: per ogni riga, l'offset del suo inizio nel testo appiattito.
  const offsets: number[] = [];
  let acc = "";
  // `.trim()` non è cosmetico: una riga con spazio in coda produceva DUE spazi nel testo
  // appiattito, e un frammento con spazi singoli non ci si trovava più. Il cancello bocciava
  // citazioni vere dicendo «non trovato», che è il modo peggiore di sbagliare — sembra rigore.
  for (const r of righe) { offsets.push(acc.length); acc += piatto(r).trim() + " "; }
  const v = { righe, piatta: acc, offsets };
  cache.set(nome, v);
  return v;
}

/** La riga che contiene un offset del testo appiattito. */
function rigaDi(offsets: number[], off: number): number {
  let lo = 0, hi = offsets.length - 1, r = 0;
  while (lo <= hi) { const m = (lo + hi) >> 1; if (offsets[m]! <= off) { r = m; lo = m + 1; } else hi = m - 1; }
  return r;
}

/** L'intestazione più vicina sopra la riga: il marcatore `@@@`, o una riga corta senza punto. */
function collocazione(righe: string[], i: number): string {
  for (let k = i; k >= 0 && k > i - 400; k--) {
    const r = righe[k]!.trim();
    if (r.startsWith("@@@ ")) return r.slice(4);
  }
  for (let k = i; k >= 0 && k > i - 60; k--) {
    const r = righe[k]!.trim();
    if (!r || r.length > 70) continue;
    if (/^(chapter|book|letter|epistula|liber|caput|canto|cap\.|[IVXLCDM]+\.?$)/i.test(r) || /^[A-ZÀ-Ü0-9 .,'’—-]{6,70}$/.test(r)) return r;
  }
  return "(nessuna intestazione vicina)";
}

let passati: Candidato[] = [];
let bocciati = 0;
const visti = new Set<string>();

console.log(`Cancello citazioni — ${candidati.length} candidati\n`);

for (const [n, c] of candidati.entries()) {
  const guai: string[] = [];
  const etichetta = `${String(n + 1).padStart(3)}. ${c.autore} — ${c.opera}`;

  // 1. il riscontro sul testo primario, che è il punto di tutto
  let dove = "";
  try {
    const { righe, piatta, offsets } = fonte(c.fonte);
    const ago = piatto(c.originale).trim();
    const off = piatta.indexOf(ago);
    if (off < 0) guai.push(`frammento NON TROVATO in ${c.fonte}`);
    else {
      const i = rigaDi(offsets, off);
      dove = `riga ${i + 1} · ${collocazione(righe, i)}`;
      if (contesto) dove += "\n" + righe.slice(Math.max(0, i - contesto), i + contesto + 1).map((r) => "      | " + r).join("\n");
    }
  } catch (e) { guai.push((e as Error).message); }

  // 2. le stesse regole dei test Swift, ma prima di compilare
  if (c.pool !== "mindful") {
    for (const hedge of ["tradizione", "attr.", "attribuit", "anonim"]) {
      if (c.opera.toLowerCase().includes(hedge)) guai.push(`opera tentennante: «${c.opera}»`);
    }
    // Il luogo dev'esserci: un numero (Lettere a Lucilio, 82) o una sezione con nome
    // (Il profeta, Il lavoro). Il titolo nudo dell'opera non basta a ritrovare il passo.
    if (!/\d/.test(c.opera) && !c.opera.includes(",")) guai.push(`opera senza luogo: «${c.opera}»`);
  }
  if (/\*\*|__/.test(c.it) || /\*\*|__/.test(c.opera)) guai.push("markdown crudo");
  if (!c.autore.trim()) guai.push("autore vuoto");
  if (c.it.length > 145) guai.push(`troppo lunga per lo schermo (${c.it.length} caratteri)`);

  // 3. doppioni, contro il corpus e contro il lotto stesso
  const chiave = piatto(c.it);
  if (giaCiSono.has(chiave)) guai.push("testo già nel corpus");
  if (visti.has(chiave)) guai.push("doppione dentro il lotto");
  visti.add(chiave);
  const id = `${c.autore}-${c.it.slice(0, 24)}`;
  if (giaId.has(id)) guai.push(`identificativo già preso: «${id}» (stesso autore, stesse prime 24 lettere)`);
  giaId.add(id);

  if (guai.length) { bocciati++; console.log(`✗ ${etichetta}\n      ${guai.join("\n      ")}`); }
  else { passati.push(c); console.log(`✓ ${etichetta}\n      ${dove}`); }
}

console.log(`\n${candidati.length - bocciati}/${candidati.length} passano.`);

// Le passate, su richiesta, per il generatore Swift. Si scrive SOLO ciò che ha superato il cancello.
const iOut = process.argv.indexOf("--out");
if (iOut > 0 && process.argv[iOut + 1]) {
  await Bun.write(process.argv[iOut + 1]!, JSON.stringify(passati, null, 2));
  console.log(`scritte ${passati.length} passate in ${process.argv[iOut + 1]}`);
}

if (bocciati) { console.log(`${bocciati} bocciati: non si scrivono.`); process.exit(1); }
