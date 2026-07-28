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
const FILE = `${process.env.HOME}/Desktop/lifeos/05-Tools/Otium/Sources/OtiumCore/Quotes.swift`;

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
        // MARK: Aggiunte del 2026-07-28 — ${n} citazioni ritrovate sul testo primario.
        //
        // Nessuna viene da un aggregatore. Per ognuna il frammento in lingua originale è stato
        // cercato dentro il testo scaricato (Wikisource latino e italiano, Project Gutenberg,
        // Zarathustra in tedesco) e ritrovato alla riga indicata dal cancello di verifica; la
        // resa italiana è nostra, fatta sull'originale dove la lingua lo permetteva — latino,
        // tedesco, francese, inglese — e sulla traduzione di pubblico dominio altrove.
        //
        // Diciannove candidate su centocinquantadue sono state bocciate dal cancello perché il
        // frammento non esisteva nel testo con quelle parole: quelle NON sono qui, ed è
        // esattamente il motivo per cui il cancello esiste.
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
