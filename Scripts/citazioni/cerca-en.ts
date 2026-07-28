#!/usr/bin/env bun
/** Cerca frasi nella traduzione inglese. Sostituisce grep, che su questo file multibyte con
 *  finestre di contesto lunghe sbatte contro i limiti di complessità di ugrep. */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
const QUI = dirname(new URL(import.meta.url).pathname);
const [file, ...aghi] = process.argv.slice(2);
const t = readFileSync(join(QUI, "fonti", file), "utf8").replace(/\s+/g, " ");
for (const ago of aghi) {
  const i = t.toLowerCase().indexOf(ago.toLowerCase());
  console.log(`── ${ago}`);
  console.log(i < 0 ? "   (non trovato)\n" : `   …${t.slice(Math.max(0, i - 90), i + ago.length + 130)}…\n`);
}
