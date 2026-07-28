#!/usr/bin/env bun
/** Le citazioni italiane di una lettera, e la prosa inglese di quella lettera. Per accoppiare a occhio in una lettura sola. */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
const QUI = dirname(new URL(import.meta.url).pathname), OTIUM = join(QUI, "..", "..");
const numeri = process.argv.slice(2);
const src = readFileSync(join(OTIUM, "Sources/OtiumCore/Quotes.swift"), "utf8");
const righe = readFileSync(join(QUI, "fonti", "seneca-lettere-en.txt"), "utf8").split("\n");
for (const n of numeri) {
  console.log(`\n══════════ LETTERA ${n}`);
  for (const m of src.matchAll(/^\s*q\("((?:[^"\\]|\\.)*)",\s*"Seneca",\s*"Lettere a Lucilio, (\d+)"\)/gm))
    if (m[2] === n) console.log(`  IT · ${m[1]!.replace(/\\"/g, '"')}`);
  const i = righe.findIndex((r) => r === `@@@ Moral letters to Lucilius/Letter ${n}`);
  if (i < 0) { console.log("  ⚠ lettera assente dal file"); continue; }
  let fine = righe.length;
  for (let k = i + 1; k < righe.length; k++) if (righe[k]!.startsWith("@@@ ")) { fine = k; break; }
  const sez = righe.slice(i + 1, fine);
  const t = sez.findIndex((r) => /^\s*[IVXLCDM]+\.\s+[A-Z][A-Z ,'’—-]{4,}$/.test(r));
  console.log("  ───");
  console.log(sez.slice(t >= 0 ? t + 1 : 0).join("\n").replace(/\n{2,}/g, "\n").replace(/\s{2,}/g, " ").trim().slice(0, 5200));
}
