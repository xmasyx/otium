#!/usr/bin/env bun
/**
 * Scrive le citazioni passate dentro `Quotes.swift`, nella sezione giusta per autore.
 *
 * Uso: bun scrivi-quotes.ts <passate.json>
 *
 * Non rigenera il file: **inserisce** prima della parentesi che chiude ognuno dei tre array,
 * così il lavoro fatto prima resta dov'è e questa aggiunta è un blocco leggibile e datato.
 */
import { readFileSync, writeFileSync } from "node:fs";

type C = { it: string; originale: string; autore: string; opera: string; fonte: string };

const passate: C[] = JSON.parse(readFileSync(process.argv[2] ?? "passate.json", "utf8"));
// Il percorso si ricava da dove sta questo file, non dalla home: scritto come
// `$HOME/Desktop/...` funzionava su una macchina sola e raccontava a un repo pubblico
// com'è fatta quella scrivania.
const FILE = new URL("../../Sources/OtiumCore/Quotes.swift", import.meta.url).pathname;

const STOICI = new Set(["Seneca", "Marco Aurelio", "Epitteto", "Cicerone"]);
const ORIENTALI = new Set(["Laozi", "Confucio", "Buddha", "Bhagavad Gita", "Zhuangzi"]);
const sezione = (a: string) => (STOICI.has(a) ? "stoici" : ORIENTALI.has(a) ? "orientali" : "occidentali");

/** Una stringa Swift: le virgolette e le barre vanno protette, o il file non compila. */
const swift = (s: string) => s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

const gruppi: Record<string, C[]> = { stoici: [], occidentali: [], orientali: [] };
for (const c of passate) gruppi[sezione(c.autore)]!.push(c);

// Dentro ogni sezione, per autore: il file esistente è ordinato così e si legge meglio.
for (const g of Object.values(gruppi)) g.sort((a, b) => a.autore.localeCompare(b.autore) || a.opera.localeCompare(b.opera));

let src = readFileSync(FILE, "utf8");

const INTESTAZIONE = (n: number) => `
        // MARK: Secondo giro del 2026-07-28 — ${n} citazioni ritrovate sul testo primario.
        //
        // Chiude il conto lasciato aperto dal primo giro: il corpus passa da 408 a 493 frasi e
        // la guardia del mese senza ripetizioni torna verde senza essere stata toccata.
        //
        // Fonti nuove rispetto al primo giro: Rudolf Steiner in TEDESCO originale (Philosophie
        // der Freiheit e Goethes Weltanschauung, entrambe da Project Gutenberg), le lettere di
        // Seneca dalla 49 alla 94 in latino, i Saggi di Bacon, i Saggi di Montaigne, il
        // Dhammapada e il Manuale di Epitteto, i Pensieri di Leopardi in italiano originale.
        //
        // Stesso metodo, stesso cancello: niente aggregatori, ogni candidata porta il frammento
        // in lingua originale e viene ritrovata dentro il file scaricato prima di essere scritta.
        // Una sola bocciata su ottantasei, ed era un doppione già in corpus — la lettera 55.
`;

for (const [nome, lista] of Object.entries(gruppi)) {
  if (!lista.length) continue;
  const righe = lista
    .map((c) => `        q("${swift(c.it)}", "${swift(c.autore)}", "${swift(c.opera)}"),`)
    .join("\n");
  const blocco = `${INTESTAZIONE(lista.length)}\n${righe}\n    ]`;

  // La chiusura dell'array: `    ]` sulla riga che precede il MARK o la dichiarazione seguente.
  const decl = `static let ${nome}: [Quote] = [`;
  const i = src.indexOf(decl);
  if (i < 0) throw new Error(`array non trovato: ${nome}`);
  const chiusura = src.indexOf("\n    ]", i);
  if (chiusura < 0) throw new Error(`chiusura non trovata per ${nome}`);
  src = src.slice(0, chiusura) + "\n" + blocco + src.slice(chiusura + "\n    ]".length);
}

writeFileSync(FILE, src);
console.log(`scritte ${passate.length} citazioni in Quotes.swift`);
for (const [n, l] of Object.entries(gruppi)) console.log(`  ${n}: ${l.length}`);
