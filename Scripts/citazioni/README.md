# Le citazioni — come si aggiungono, e perché così

> Scritto il 2026-07-28, mentre si riempiva il pool dopo la scrematura. Chi riprende il lavoro
> parte da qui e da `HANDOFF-CITAZIONI.md`.

## La regola, in una riga

**Nessuna citazione entra nel pool firmato senza essere stata ritrovata dentro il testo primario,
in lingua originale, a una riga precisa.** Niente aggregatori. Il 28 luglio cinque citazioni false
sono uscite dal corpus, e tutte e cinque venivano da lì.

## Il giro completo

```bash
cd Scripts/citazioni
mkdir -p fonti

# 1. Le fonti sul disco. Wikisource per latino e italiano.
bun fetch-wikisource.ts la "Epistulae morales ad Lucilium" fonti/seneca-epistulae-la.txt
bun fetch-wikisource.ts it "Operette morali"                fonti/leopardi-operette-it.txt

#    Project Gutenberg: il sito diretto NON risponde da qui, mentre il mirror sì.
#    Il percorso sono tutte le cifre tranne l'ultima, come cartelle, quindi 205 diventa 2/0/205
curl -sL -o fonti/walden-en.txt https://gutenberg.pglaf.org/2/0/205/205-0.txt

# 2. Leggere e scegliere
bun estrai.ts seneca-epistulae-la.txt "corpus|otium|quies|exerce" 45 120 60
bun cerca.ts  seneca-epistulae-la.txt "circumscribe corpus tuum" 300 1

# 3. Il cancello, fail-closed
bun verifica-citazioni.ts lotto-07.json --out passate.json

# 4. Nel codice, e poi i test
bun scrivi-quotes.ts passate.json
cd ../.. && swift test
```

## Il formato di un candidato

```json
{
  "it":        "La resa italiana, quella che finisce a schermo",
  "originale": "il frammento in LINGUA ORIGINALE, cercato alla lettera",
  "autore":    "Seneca",
  "opera":     "Lettere a Lucilio, 15",
  "fonte":     "seneca-epistulae-la.txt"
}
```

`originale` è il campo che porta il peso. Il cancello lo cerca nel file, e se non lo trova la
frase non si scrive. Vale anche quando sei sicuro: su 152 candidate, **19 sono state bocciate**
perché il testo, con quelle parole esatte, non c'era.

## Cosa controlla il cancello, oltre al frammento

Doppioni contro il corpus già scritto · collisioni di identificativo (`autore` più le prime 24
lettere) · opere che si dichiarano incerte («tradizione», «attr.», «attribuita») · markdown crudo ·
frasi troppo lunghe per lo schermo. Sono gli stessi controlli dei test Swift, ma prima di compilare.

**Il cancello è stato provato su tutti e due i poli**, e la prova sta in `prova-negativa.json`:
boccia la citazione inventata, il doppione, l'opera tentennante e la frase troppo lunga, e lascia
passare le due vere. Se lo tocchi, rifallo girare: un controllo mai controllato è un'asserzione
travestita da verifica.

## Due trappole già pagate

1. **Lo spazio di fine riga.** Appiattendo il testo riga per riga, una riga con spazio in coda
   produceva due spazi, e un frammento con spazi singoli non ci si trovava più. Il cancello
   bocciava citazioni vere dicendo «non trovato» — che è il modo peggiore di sbagliare, perché
   sembra rigore. Da lì viene il `.trim()` in `fonte()`.

2. **Le pagine con la scansione a fronte** non contengono il testo, contengono un `<pages index=…/>`
   che lo tira dentro. Chiederne il wikitext restituisce lo stub: un corpus fatto di stub *sembra*
   scaricato e non lo è. `fetch-wikisource.ts` se ne accorge e ripiega sull'endpoint REST, servito
   dalla cache, perché `action=parse` a raffica prende 429 e il JSON che torna è testo d'errore.

## Sulla traduzione

Le rese italiane sono nostre, non copiate da un'edizione sotto diritti, e si fanno **sull'originale
dove la lingua lo permette**: latino, tedesco, francese, inglese. Per greco, sanscrito, cinese e
pali si passa da una traduzione di pubblico dominio, e va dichiarato a sé stessi che è una
traduzione di traduzione.

Fedeli, non belle. Se una resa ti sembra bella ma lontana dall'originale, è sbagliata, e il 28
luglio due sono state strette proprio per questo.

Una parola giusta nel dizionario può essere sbagliata a schermo. *Circumscribe* non è «restringi»
ma «traccia un confine intorno»; *Vernunft* è la facoltà di ragionare, e «il corpo è una grande
ragione», da sola, in italiano si legge «motivo». Le ho viste tutte e due io, non il
cancello. Il controllo finale è come suona la frase in italiano, da sola, a chi la legge durante
una pausa.
