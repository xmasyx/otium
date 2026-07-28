#!/usr/bin/env bun
/**
 * Scarica un'opera da Wikisource come UN file di testo, con i marcatori di sezione.
 *
 * Uso: bun fetch-wikisource.ts <lang> <prefisso pagina> <file di uscita>
 *   - se esistono sottopagine `<prefisso>/...` le scarica tutte, in ordine;
 *   - altrimenti scarica la pagina singola.
 *
 * Ogni sezione entra preceduta da `@@@ <titolo pagina>`, così il verificatore può risalire
 * dal frammento trovato alla sua collocazione senza indovinare.
 *
 * Il contenuto arriva dall'API `prop=revisions` a lotti di 50 titoli: `?action=raw` sulle
 * sottopagine falliva perché la barra del percorso veniva percent-encodata.
 */

const [lang, prefix, out] = process.argv.slice(2);
if (!lang || !prefix || !out) {
  console.error("uso: bun fetch-wikisource.ts <lang> <prefisso> <out>");
  process.exit(2);
}

const api = `https://${lang}.wikisource.org/w/api.php`;

/**
 * Una GET educata verso l'API: identificata, distanziata, e con ritentativo sul 429.
 *
 * Senza questo, `action=parse` in sequenza prende «too many requests» e il JSON che torna è
 * testo di errore. Il difetto si presentava come un errore di parsing, non come un rifiuto, e
 * quella è la maschera peggiore: sembra un bug nel codice mentre è il server che dice di no.
 */
async function json(url: URL): Promise<any> {
  for (let tentativo = 0; tentativo < 6; tentativo++) {
    const r = await fetch(url, {
      headers: { "User-Agent": "OtiumCorpusFetcher/1.0 (script locale di ricerca; testi di pubblico dominio)" },
    });
    if (r.status === 429 || r.status === 503) {
      await Bun.sleep(1000 * 2 ** tentativo);
      continue;
    }
    if (!r.ok) throw new Error(`${r.status} su ${url.searchParams.get("page") ?? url.searchParams.get("titles") ?? url}`);
    await Bun.sleep(250);
    return await r.json();
  }
  throw new Error(`limite di frequenza non superato su ${url}`);
}

async function subpages(p: string): Promise<string[]> {
  const titles: string[] = [];
  let cont: string | undefined;
  do {
    const url = new URL(api);
    url.searchParams.set("action", "query");
    url.searchParams.set("list", "allpages");
    url.searchParams.set("apprefix", p + "/");
    url.searchParams.set("aplimit", "500");
    url.searchParams.set("format", "json");
    if (cont) url.searchParams.set("apcontinue", cont);
    const r = (await json(url)) as any;
    for (const a of r.query?.allpages ?? []) titles.push(a.title);
    cont = r.continue?.apcontinue;
  } while (cont);
  return titles;
}

/**
 * Testo RESO di una pagina, non il wikitext.
 *
 * Le opere con scansione a fronte non contengono il testo: contengono un `<pages index=…/>` che
 * lo tira dentro dal namespace `Pagina:`. Chiedere il wikitext di quelle pagine restituisce lo
 * stub, e un corpus fatto di stub sembra scaricato e non lo è. `action=parse` risolve le
 * trasclusioni e restituisce l'HTML, da cui si toglie il marcatore.
 */
async function reso(title: string): Promise<string> {
  // Endpoint REST e non `action=parse`: il secondo viene strozzato a raffica (429 di fila), il
  // primo è servito dalla cache e regge la sequenza.
  const url = `https://${lang}.wikisource.org/api/rest_v1/page/html/${encodeURIComponent(title.replace(/ /g, "_"))}`;
  let html = "";
  for (let tentativo = 0; tentativo < 5; tentativo++) {
    const r = await fetch(url, { headers: { "User-Agent": "OtiumCorpusFetcher/1.0 (script locale di ricerca)" } });
    if (r.status === 429 || r.status === 503) { await Bun.sleep(2000 * (tentativo + 1)); continue; }
    if (!r.ok) { process.stderr.write(`  RESO KO ${r.status} ${title}\n`); return ""; }
    html = await r.text();
    break;
  }
  if (!html) { process.stderr.write(`  RESO strozzato ${title}\n`); return ""; }
  await Bun.sleep(900);
  return html
    .replace(/<style[\s\S]*?<\/style>/g, "")
    .replace(/<sup[\s\S]*?<\/sup>/g, "")
    .replace(/<\/(p|div|h[1-6]|li|br)>/g, "\n")
    .replace(/<br\s*\/?>/g, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&#160;|&nbsp;/g, " ")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

/** Contenuto wikitext di un lotto di titoli, per titolo. */
async function contents(titles: string[]): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  for (let i = 0; i < titles.length; i += 50) {
    const lotto = titles.slice(i, i + 50);
    const url = new URL(api);
    url.searchParams.set("action", "query");
    url.searchParams.set("prop", "revisions");
    url.searchParams.set("rvprop", "content");
    url.searchParams.set("rvslots", "main");
    url.searchParams.set("titles", lotto.join("|"));
    url.searchParams.set("format", "json");
    url.searchParams.set("formatversion", "2");
    const r = (await json(url)) as any;
    for (const p of r.query?.pages ?? []) {
      const c = p.revisions?.[0]?.slots?.main?.content;
      if (typeof c === "string") map.set(p.title, c);
      else process.stderr.write(`  VUOTA ${p.title}\n`);
    }
  }
  return map;
}

/** Ordina numerando i romani in coda al titolo, così i capitoli non escono in ordine alfabetico. */
const ROMANI: Record<string, number> = { I: 1, V: 5, X: 10, L: 50, C: 100, D: 500, M: 1000 };
function chiave(t: string): number {
  const coda = t.split("/").pop() ?? "";
  const m = coda.match(/^([IVXLCDM]+)\b/);
  if (!m) return Number.POSITIVE_INFINITY;
  let n = 0;
  const s = m[1];
  for (let i = 0; i < s.length; i++) {
    const v = ROMANI[s[i]!]!;
    n += v < (ROMANI[s[i + 1]!] ?? 0) ? -v : v;
  }
  return n;
}

/**
 * Un rinvio non è un testo.
 *
 * `#REDIRECT [[X]]` (e il suo gemello italiano `#RINVIA`) occupa una pagina intera e pesa
 * settanta byte: ventuno pagine di rinvii scaricano due kilobyte e sembrano un'opera. È la stessa
 * famiglia di guasto degli stub di trasclusione — il file esiste, il conteggio delle pagine torna,
 * dentro non c'è niente — e va risolta prima, non diagnosticata dopo.
 */
const RINVIO = /^\s*#\s*(?:REDIRECT|RINVIA|RINVIO)\s*\[\[\s*([^\]|#]+)/i;

/**
 * Risolve i rinvii A LOTTI, non uno per uno.
 *
 * Una chiamata per pagina prende «too many requests» dopo poche decine di titoli: il batch da 50
 * di `contents()` è la ragione per cui questo scarico regge, e va conservata anche mentre si
 * inseguono i rinvii. Si fanno round: ogni round chiede in blocco i bersagli scoperti nel round
 * prima, al massimo tre volte (una catena di rinvii più lunga è un anello, non un'opera).
 */
async function risolviRinvii(map: Map<string, string>, titoli: string[]): Promise<Map<string, string>> {
  const finale = new Map(map);
  let daRisolvere = titoli.filter((t) => RINVIO.test(finale.get(t) ?? ""));
  for (let round = 0; round < 3 && daRisolvere.length; round++) {
    const bersaglio = new Map<string, string>();
    for (const t of daRisolvere) bersaglio.set(t, finale.get(t)!.match(RINVIO)![1]!.trim());
    process.stderr.write(`  ${daRisolvere.length} rinvii da seguire (round ${round + 1})\n`);
    const presi = await contents([...new Set(bersaglio.values())]);
    for (const [t, b] of bersaglio) finale.set(t, presi.get(b) ?? "");
    daRisolvere = daRisolvere.filter((t) => RINVIO.test(finale.get(t) ?? ""));
  }
  return finale;
}

let pages = await subpages(prefix);
// Il prefisso stesso può essere un rinvio: allora le sottopagine vere stanno sotto un altro nome.
if (!pages.length) {
  const radice = (await contents([prefix])).get(prefix) ?? "";
  const r = radice.match(RINVIO);
  if (r) {
    const bersaglio = r[1]!.trim();
    process.stderr.write(`  rinvio della radice: ${prefix} → ${bersaglio}\n`);
    pages = await subpages(bersaglio);
    if (!pages.length) pages = [bersaglio];
  }
}
const list = (pages.length ? pages : [prefix]).sort((a, b) => chiave(a) - chiave(b));
const map = await risolviRinvii(await contents(list), list);

let body = "";
let mancanti = 0;
let resi = 0;
for (const t of list) {
  let text = map.get(t) ?? "";
  // Uno stub di trasclusione non è il testo: si ripiega sul reso, che costa una chiamata in più.
  if (!text || /<pages\s+index=/.test(text)) {
    text = await reso(t);
    if (text) resi++;
  }
  if (!text) { mancanti++; continue; }
  body += `\n@@@ ${t}\n\n${text}\n`;
}
if (resi) console.log(`  (${resi} pagine prese come testo reso)`);

const prese = list.length - mancanti;
await Bun.write(out, body);
console.log(`${out}  ${prese}/${list.length} pagine  ${body.length} byte${mancanti ? `  (${mancanti} mancanti)` : ""}`);

// Fail-loud: un'opera che pesa meno di 300 byte a pagina non è un'opera, è un indice o una
// collezione di rinvii. Meglio uscire 1 adesso che scoprirlo dal cancello, dove il sintomo
// («frammento non trovato») punta al posto sbagliato — la citazione, invece della fonte.
const perPagina = prese ? body.length / prese : 0;
if (prese && perPagina < 300) {
  console.error(`\nSOSPETTO: ${Math.round(perPagina)} byte a pagina. Questo non è testo — controlla`);
  console.error(`se «${prefix}» è una pagina indice o una raccolta di rinvii, e punta al titolo vero.`);
  process.exit(1);
}
