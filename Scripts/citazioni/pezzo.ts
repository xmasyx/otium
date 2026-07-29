#!/usr/bin/env bun
/** Un pezzo di lettera, dalla percentuale X alla Y. Le citazioni che restano stanno tutte in
 *  mezzo a lettere lunghe, e leggerne l'inizio non serve. */
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
const QUI = dirname(new URL(import.meta.url).pathname);
const [n, da = "0", a = "100"] = process.argv.slice(2);
const righe = readFileSync(join(QUI, "fonti", "seneca-lettere-en.txt"), "utf8").split("\n");
const i = righe.findIndex((r) => r === `@@@ Moral letters to Lucilius/Letter ${n}`);
let fine = righe.length;
for (let k = i + 1; k < righe.length; k++) if (righe[k]!.startsWith("@@@ ")) { fine = k; break; }
const sez = righe.slice(i + 1, fine);
const t = righe.slice(i + 1, fine).findIndex((r) => /^\s*[IVXLCDM]+\.\s+[A-Z][A-Z ,'’—-]{4,}$/.test(r));
const testo = sez.slice(t >= 0 ? t + 1 : 0).join(" ").replace(/\s+/g, " ").trim();
const x = Math.floor(testo.length * Number(da) / 100), y = Math.floor(testo.length * Number(a) / 100);
console.log(`── lettera ${n}, ${da}%–${a}% di ${testo.length} caratteri\n${testo.slice(x, y)}`);
