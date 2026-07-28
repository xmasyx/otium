#!/usr/bin/env bun
/**
 * Scrive l'inglese dentro Quotes.swift, una coppia per volta e solo dove l'italiano combacia
 * alla lettera. Fail-closed: se una riga non si trova, non scrive NIENTE e dice quale.
 *
 * Uso: bun applica-en.ts <coppie.json>   — [["italiano", "english"], ...]
 */
import { readFileSync, writeFileSync } from "node:fs";

const coppie: [string, string][] = JSON.parse(readFileSync(process.argv[2]!, "utf8"));
const FILE = `${process.env.HOME}/Desktop/lifeos/05-Tools/Otium/Sources/OtiumCore/Quotes.swift`;
let src = readFileSync(FILE, "utf8");
const esc = (s: string) => s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

const guai: string[] = [];
for (const [it, en] of coppie) {
  if (en.length > 145) { guai.push(`${en.length} caratteri, troppo lunga: ${en.slice(0, 60)}…`); continue; }
  const cerca = new RegExp(`q\\("${esc(it).replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}",\\s*"([^"]+)",\\s*"([^"]+)"\\)`);
  const m = src.match(cerca);
  if (!m) { guai.push(`non trovata in Quotes.swift (o ha già l'inglese): ${it.slice(0, 60)}…`); continue; }
  src = src.replace(cerca, `q("${esc(it)}", "${esc(en)}", "${m[1]}", "${m[2]}")`);
}
if (guai.length) { console.error("NIENTE SCRITTO:\n  " + guai.join("\n  ")); process.exit(1); }
writeFileSync(FILE, src);
console.log(`${coppie.length} inglesi scritti in Quotes.swift`);
