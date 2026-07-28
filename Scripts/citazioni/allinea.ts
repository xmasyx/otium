#!/usr/bin/env bun
/**
 * Accoppia originale e traduzione **per posizione**, non per lessico.
 *
 * Uso: bun allinea.ts <autore> <file OR> <file EN> <schema sezione EN> [da] [quante]
 *   bun allinea.ts Seneca seneca-epistulae-la.txt seneca-lettere-en.txt "Letter %N" 0 25
 *
 * **Perché la posizione batte le radici.** `accoppia-lotto.ts` conta la sovrapposizione del
 * lessico, e dove latino e inglese condividono la radice funziona benissimo — «exercitationes»
 * trova «exercise». Dove il vocabolario diverge non trova niente: «nessun vento è favorevole»
 * contro «no wind is favourable» non ha una sola radice in comune, perché *ventus* e *wind* non
 * si somigliano. Su una prima corsa il lessico ha lasciato scoperta circa metà delle citazioni.
 *
 * La posizione non ha quel problema. Una traduzione segue l'originale frase per frase: se il
 * frammento latino sta al 38% della lettera, l'inglese corrispondente sta al 38% della stessa
 * lettera, più o meno lo scarto che la lingua d'arrivo introduce allungando o accorciando. Non
 * serve capire niente delle due lingue, e proprio per questo non può sbagliare *per bias*: può
 * solo essere impreciso, e lo è di poco su un testo lungo come una lettera.
 *
 * I due segnali sono indipendenti, e questo è il punto: dove concordano la scelta è quasi
 * automatica, e dove discordano la citazione va guardata a mano invece che accettata. Il tool
 * continua a NON scegliere.
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";

const [autore, fileOR, fileEN, schemaSezione, daStr = "0", quanteStr = "25"] = process.argv.slice(2);
if (!autore || !fileOR || !fileEN || !schemaSezione) {
  console.error("uso: bun allinea.ts <autore> <file OR> <file EN> <sezione con %N> [da] [quante]");
  process.exit(2);
}

const QUI = dirname(new URL(import.meta.url).pathname);
const OTIUM = join(QUI, "..", "..");

const piatto = (s: string) =>
  s.normalize("NFC").replace(/[‘’ʼ`´]/g, "'").replace(/[“”«»]/g, '"')
    .replace(/[‐-―−]/g, "-").replace(/\s+/g, " ").toLowerCase();

// — le citazioni ancora senza inglese
const src = readFileSync(join(OTIUM, "Sources/OtiumCore/Quotes.swift"), "utf8");
type C = { it: string; opera: string; originale?: string };
const citazioni: C[] = [];
for (const m of src.matchAll(/^\s*q\("((?:[^"\\]|\\.)*)",\s*"([^"]+)",\s*"([^"]+)"\)/gm)) {
  if (m[2] === autore) citazioni.push({ it: m[1]!.replace(/\\"/g, '"'), opera: m[3]! });
}
const originali = new Map<string, string>();
for (const f of ["passate.json", "passate-2.json"]) {
  const p = join(QUI, f);
  if (existsSync(p)) for (const q of JSON.parse(readFileSync(p, "utf8"))) originali.set(q.it, q.originale);
}
for (const c of citazioni) c.originale = originali.get(c.it);

// — l'originale, appiattito una volta sola
const testoOR = readFileSync(join(QUI, "fonti", fileOR), "utf8");
const orPiatto = piatto(testoOR);
/**
 * I confini fra una lettera e l'altra.
 *
 * **La forma dell'intestazione va guardata, non indovinata.** La prima versione cercava una riga
 * col solo numero romano e ne trovava 7 su 124: l'edizione latina di Wikisource scrive le
 * intestazioni in wikitext, `== CI. SENECA LUCILIO SUO SALUTEM ==`, e con sette confini su
 * centoventiquattro ogni posizione risultava relativa al file intero invece che alla lettera —
 * cioè sempre vicina a zero, e sempre sbagliata. Il difetto non si annunciava: il tool rispondeva,
 * i numeri sembravano numeri.
 */
const CONFINI = [...testoOR.matchAll(/^\s*={2,}\s*([IVXLCDM]{1,7})\.[^\n=]*={2,}\s*$|^\s*([IVXLCDM]{1,7})\.\s+SENECA/gm)]
  .map((m) => piatto(testoOR.slice(0, m.index!)).length)
  .sort((a, b) => a - b);
if (CONFINI.length < 50) {
  process.stderr.write(`  ⚠ solo ${CONFINI.length} confini di lettera trovati: la posizione sarà inaffidabile\n`);
}

function posizioneRelativa(frammento: string): number | null {
  const off = orPiatto.indexOf(piatto(frammento).trim());
  if (off < 0) return null;
  let inizio = 0, fine = orPiatto.length;
  for (const c of CONFINI) { if (c <= off) inizio = c; else { fine = c; break; } }
  return fine > inizio ? (off - inizio) / (fine - inizio) : null;
}

// — la traduzione, sezione per sezione
const righeEN = readFileSync(join(QUI, "fonti", fileEN), "utf8").split("\n");
function frasiDi(sezione: string): { f: string; p: number }[] {
  const i = righeEN.findIndex((r) => r.startsWith("@@@ ") && r.endsWith(sezione));
  if (i < 0) return [];
  let fine = righeEN.length;
  for (let k = i + 1; k < righeEN.length; k++) if (righeEN[k]!.startsWith("@@@ ")) { fine = k; break; }
  // **L'intestazione di navigazione non è la lettera.** Ogni pagina di Wikisource si apre con
  // sei o sette righe di apparato — «← Letter 14», il nome del traduttore, l'id numerico — che
  // sopravvivono allo spoglio dei tag e, stando all'inizio, vincono per vicinanza qualunque
  // citazione posizionata all'inizio della lettera. Il testo vero comincia dopo il titolo in
  // maiuscolo («XV. ON BRAWN AND BRAINS»), che è il marcatore più stabile che questa edizione ha.
  const righeSezione = righeEN.slice(i + 1, fine);
  const titolo = righeSezione.findIndex((r) => /^\s*[IVXLCDM]+\.\s+[A-Z][A-Z ,'’—-]{4,}$/.test(r));
  const testo = righeSezione.slice(titolo >= 0 ? titolo + 1 : 0).join("\n");
  const grezze: string[] = [];
  for (const par of testo.split(/\n\s*\n/).map((x) => x.split("\n").map((r) => r.trim()).join(" "))) {
    for (const f of par.split(/(?<=[.!?])\s+/)) {
      const t = f.trim().replace(/^[“"]?\s*/, "");
      if (t.length >= 30 && t.length <= 320 && !t.includes("{") && !t.includes("djvu")) grezze.push(t);
    }
  }
  // La posizione di una frase è dove comincia, in proporzione al totale della sezione.
  const totale = grezze.reduce((n, f) => n + f.length, 0) || 1;
  let acc = 0;
  return grezze.map((f) => { const p = acc / totale; acc += f.length; return { f, p }; });
}

const radici = (s: string): Set<string> =>
  new Set(s.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
    .split(/[^a-z]+/).filter((w) => w.length >= 5).map((w) => w.slice(0, 4)));

const da = Number(daStr), quante = Number(quanteStr);
const fetta = citazioni.slice(da, da + quante);
console.log(`${autore}: ${citazioni.length} senza inglese · ${da}–${da + fetta.length - 1}\n`);

for (const [i, c] of fetta.entries()) {
  const numero = c.opera.match(/(\d+)\s*$/)?.[1] ?? "";
  const sezione = schemaSezione.replace("%N", numero);
  const frasi = frasiDi(sezione);
  console.log(`── ${da + i} · ${c.opera}`);
  console.log(`   IT ${c.it}`);
  if (!frasi.length) { console.log(`   ⚠ «${sezione}» assente\n`); continue; }

  const pos = c.originale ? posizioneRelativa(c.originale) : null;
  const cercate = radici(`${c.originale ?? ""} ${c.it}`);
  const scored = frasi.map((x) => {
    const r = radici(x.f);
    let comuni = 0; for (const y of cercate) if (r.has(y)) comuni++;
    const vicinanza = pos === null ? 0 : 1 - Math.min(1, Math.abs(x.p - pos) * 4);
    return { ...x, comuni, punteggio: comuni * 1.5 + vicinanza * 2 };
  }).sort((a, b) => b.punteggio - a.punteggio);

  console.log(`   ${pos === null ? "posizione ignota" : `posizione ${(pos * 100) | 0}%`}`);
  for (const s of scored.slice(0, 2)) {
    console.log(`   → [r${s.comuni} p${(s.p * 100) | 0}%] ${s.f.slice(0, 190)}`);
  }
  console.log();
}
