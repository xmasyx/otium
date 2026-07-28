#!/usr/bin/env bun
/**
 * Trova, dentro una traduzione inglese, la frase che corrisponde a una citazione già in corpus.
 *
 * Uso: bun accoppia.ts <file EN in fonti/> <sezione> <testo di riferimento> [quante=8]
 *   bun accoppia.ts seneca-lettere-en.txt "Letter 15" "Esercitare il corpo con poco"
 *
 * **Perché esiste.** L'inglese delle citazioni non si traduce: si prende dalla traduzione
 * pubblicata, così è verificabile alla lettera come lo è l'originale. Ma per prenderla bisogna
 * prima trovarla, e 246 passi cercati a occhio dentro 1,5 MB di testo sono il modo migliore per
 * accoppiare la frase sbagliata con l'aria di aver fatto un lavoro preciso.
 *
 * **Come sceglie.** Non traduce niente: conta la sovrapposizione del lessico. Italiano, latino e
 * inglese condividono così tanto vocabolario latino che le radici di quattro lettere bastano a
 * portare in cima la frase giusta — «esercizio/exercitatione/exercise» collassano tutte su
 * `exerc`. Dove il vocabolario diverge (animus → mind) il punteggio cala, e infatti il tool NON
 * decide: mostra le prime N e la scelta resta di chi legge. Un tool che scegliesse da solo qui
 * sarebbe un traduttore travestito da indice.
 *
 * La sezione si filtra sui marcatori `@@@` messi da `fetch-wikisource.ts`, o su una riga di
 * intestazione nei file di Gutenberg.
 */
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";

const [file, sezione, riferimento, quante = "8"] = process.argv.slice(2);
if (!file || !sezione || !riferimento) {
  console.error("uso: bun accoppia.ts <file EN> <sezione> <testo di riferimento> [quante]");
  process.exit(2);
}

const QUI = dirname(new URL(import.meta.url).pathname);
const path = join(QUI, "fonti", file);
if (!existsSync(path)) { console.error(`fonte assente: ${file}`); process.exit(1); }
const righe = readFileSync(path, "utf8").split("\n");

/** Le parole che portano significato: via le corte, che sono quasi tutte grammatica. */
const radici = (s: string): Set<string> =>
  new Set(
    s.toLowerCase()
      .normalize("NFD").replace(/[̀-ͯ]/g, "")
      .split(/[^a-z]+/)
      .filter((w) => w.length >= 5)
      .map((w) => w.slice(0, 4)),
  );

/**
 * La sezione richiesta. Un marcatore `@@@` la apre e il successivo la chiude; se la sezione non
 * si trova come marcatore si cerca come riga di intestazione, e in ultima istanza si guarda tutto
 * il file — dicendolo, perché cercare in tutto il file è molto più impreciso e chi legge deve saperlo.
 */
function estraiSezione(): { testo: string; dove: string } {
  const marcatore = righe.findIndex((r) => r.startsWith("@@@ ") && r.includes(sezione));
  if (marcatore >= 0) {
    let fine = righe.length;
    for (let i = marcatore + 1; i < righe.length; i++) {
      if (righe[i]!.startsWith("@@@ ")) { fine = i; break; }
    }
    return { testo: righe.slice(marcatore + 1, fine).join("\n"), dove: righe[marcatore]!.slice(4) };
  }
  const intestazione = righe.findIndex((r) => r.trim().toLowerCase() === sezione.toLowerCase());
  if (intestazione >= 0) {
    return { testo: righe.slice(intestazione + 1, intestazione + 400).join("\n"), dove: `riga ${intestazione + 1}` };
  }
  return { testo: righe.join("\n"), dove: "TUTTO IL FILE — sezione non trovata, punteggi meno affidabili" };
}

const { testo, dove } = estraiSezione();

// Le frasi: i testi di Gutenberg vanno a capo ogni ~72 caratteri, quindi prima si riuniscono i
// paragrafi e solo dopo si spezza sulla punteggiatura forte.
const paragrafi = testo.split(/\n\s*\n/).map((p) => p.split("\n").map((r) => r.trim()).join(" "));
const frasi: string[] = [];
for (const p of paragrafi) {
  for (const f of p.split(/(?<=[.!?])\s+/)) {
    const t = f.trim().replace(/^\[?\d+\]?\s*/, "");
    if (t.length >= 40 && t.length <= 400) frasi.push(t);
  }
}

const cercate = radici(riferimento);
const punteggi = frasi
  .map((f) => {
    const r = radici(f);
    let comuni = 0;
    for (const c of cercate) if (r.has(c)) comuni++;
    return { f, comuni, quota: cercate.size ? comuni / cercate.size : 0 };
  })
  .filter((x) => x.comuni > 0)
  .sort((a, b) => b.quota - a.quota || a.f.length - b.f.length);

console.log(`${dove} · ${frasi.length} frasi · ${cercate.size} radici cercate\n`);
if (!punteggi.length) { console.log("nessuna sovrapposizione: la sezione è quella giusta?"); process.exit(0); }
for (const p of punteggi.slice(0, Number(quante))) {
  console.log(`[${p.comuni}/${cercate.size}] ${p.f}\n`);
}
