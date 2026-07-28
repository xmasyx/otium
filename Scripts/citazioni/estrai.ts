#!/usr/bin/env bun
/**
 * Estrae frasi candidate da un testo primario, già filtrate per tema e per lunghezza.
 *
 * Uso: bun estrai.ts <file in fonti/> <regex tema> [minLen=40] [maxLen=210] [max=80]
 *
 * Perché non basta `cerca.ts`: leggere 200 finestre da 180 caratteri per scegliere 200 citazioni
 * costa più contesto di quanto serva. Qui la frase arriva già isolata, con la sua collocazione,
 * e la scelta è una lettura sola.
 *
 * La collocazione porta DUE informazioni, perché nessuna delle due basta da sola: l'intestazione
 * grande (libro, lettera, capitolo) e l'ultimo marcatore di sezione incontrato (romano o [n]).
 */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";

const [file, tema, min = "40", max = "210", limite = "80"] = process.argv.slice(2);
if (!file || !tema) { console.error("uso: bun estrai.ts <file> <regex tema> [min] [max] [limite]"); process.exit(2); }

const QUI = dirname(new URL(import.meta.url).pathname);
const righe = readFileSync(join(QUI, "fonti", file), "utf8").split("\n");

const re = new RegExp(tema, "i");
const MIN = Number(min), MAX = Number(max), LIM = Number(limite);

/** Intestazione grande: `@@@ …`, `== … ==`, o una riga tutta maiuscola. */
const isTitolo = (r: string) =>
  r.startsWith("@@@ ") || /^==\s*.+\s*==$/.test(r) || (/^[A-ZÀ-Ü][A-ZÀ-Ü0-9 .,'’—:-]{5,69}$/.test(r) && !r.endsWith("."));

let titolo = "";
let sezione = "";
let n = 0;

/**
 * I paragrafi, non le righe.
 *
 * I testi di Gutenberg vanno a capo ogni ~72 caratteri: spezzare sulle righe restituisce monconi
 * di frase che sembrano candidati e non lo sono. Una riga vuota chiude il paragrafo; dentro, le
 * righe si riuniscono. Sui file di Wikisource, dove il paragrafo È una riga sola, non cambia niente.
 */
type Paragrafo = { riga: number; testo: string; titolo: string; sezione: string };
const paragrafi: Paragrafo[] = [];
let buf: string[] = [];
let inizio = 0;

const chiudi = () => {
  if (buf.length) paragrafi.push({ riga: inizio, testo: buf.join(" "), titolo, sezione });
  buf = [];
};

for (const [i, raw] of righe.entries()) {
  const r = raw.trim();
  if (!r) { chiudi(); continue; }
  if (isTitolo(r)) { chiudi(); titolo = r.replace(/^@@@ |^=+\s*|\s*=+$/g, ""); sezione = ""; continue; }
  if (!buf.length) inizio = i + 1;
  buf.push(r);
}
chiudi();

for (const p of paragrafi) {
  // Marcatori di sezione dentro il paragrafo: `[12]` di Seneca, `XXI.` di Marco Aurelio.
  for (const m of p.testo.matchAll(/\[(\d+)\]|(?:^|\s)([IVXLCDM]{1,6})\.(?=\s+[A-Z])/g)) {
    p.sezione = m[1] ? `[${m[1]}]` : m[2]!;
  }
  const i = p.riga - 1;
  const titolo = p.titolo, sezione = p.sezione;

  // Le frasi: si spezza su punto/interrogativo/esclamativo/punto e virgola.
  for (const frase of p.testo.split(/(?<=[.!?;:])\s+/)) {
    const f = frase.trim().replace(/^[\[\(]\d+[\]\)]\s*/, "").replace(/^_+|_+$/g, "");
    if (f.length < MIN || f.length > MAX) continue;
    if (!re.test(f)) continue;
    if (/^[A-ZÀ-Ü0-9 .,'’—:-]+$/.test(f)) continue;   // righe di indice tutte maiuscole
    if (++n > LIM) { console.log(`… (fermato a ${LIM})`); process.exit(0); }
    console.log(`\n${i + 1} · ${titolo}${sezione ? " · " + sezione : ""}\n  ${f}`);
  }
}
if (!n) console.log("nessuna frase");
