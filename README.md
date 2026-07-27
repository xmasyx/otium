# Otium

Un'app per macOS che conta il **tempo attivo** davanti al Mac e, a intervalli decisi dalla
letteratura, copre lo schermo finché non hai fatto un esercizio a corpo libero.

Niente telecamera. Niente abbonamento. Niente rete. Nessun permesso di sistema.

```
30 min di lavoro attivo  →  90 s  ·  8-15 squat o push-up
30 min                   →  90 s  ·  esercizio diverso
30 min                   →  5 min ·  bout vigoroso + 3 min lontano dallo schermo
```

---

## Perché questi numeri

Ogni parametro risponde a uno studio, e l'app te lo mostra **mentre** ti interrompe. Questa è la
differenza principale con tutto il resto: le app concorrenti si dichiarano *science-backed* senza
citare una fonte.

| Parametro | Da dove viene |
|---|---|
| **Un break ogni 30 minuti** | [Duran et al. 2023](https://www.cuimc.columbia.edu/news/rx-prolonged-sitting-five-minute-stroll-every-half-hour) — crossover randomizzato su quattro dosi: solo "5 minuti ogni 30" ha appiattito i picchi glicemici (−58%). Dosi minori abbassano la pressione ma non la glicemia. |
| **Esercizi di forza, non una camminata** | [Gao, Li, Finni & Pesola 2024](https://onlinelibrary.wiley.com/doi/abs/10.1111/sms.14628) — 3 minuti di squat ogni 45' hanno battuto una singola camminata da 30', con circa il doppio del beneficio glicemico. Conta l'attivazione muscolare, non i passi. |
| **La pausa piena da 5 minuti** | [Galinsky et al. 2000](https://pubmed.ncbi.nlm.nih.gov/10877480/) (+ follow-up 2007) — 5 minuti di pausa extra ogni ora riducono disturbi muscoloscheletrici e affaticamento visivo **senza perdita di produttività misurata**. |
| **90 secondi per il micro-snack** | [Albulescu et al. 2022](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0272460) — meta-analisi di 22 studi: le micro-pause ≤10 min riducono fatica e alzano il vigore. Gli autori avvertono che dopo lavoro cognitivo pesante 10 minuti non bastano: per questo ogni 90 minuti la pausa è piena. |
| **Il bout vigoroso, e il bersaglio di 3 al giorno** | [Stamatakis et al. 2022, *Nature Medicine*](https://www.wcrf.org/about-us/news-and-blogs/vigorous-exercise-and-the-science-behind-exercise-snacking/) — 25.241 adulti non sportivi: tre bout quotidiani da 1-2 minuti di attività vigorosa si associano a ~40% di mortalità in meno a 7 anni. |

### E una funzione che Otium NON implementa

La **regola 20-20-20** (ogni 20 minuti guarda a 6 metri per 20 secondi) è in quasi tutte le app di
pausa. In un [trial del 2023](https://www.optometryadvisor.com/features/digital-eye-strain-may-not-be-solved-by-the-20-20-20-rule/)
che ha confrontato pause da 20 secondi a intervalli di 5, 10 e 20 minuti non è emersa alcuna
differenza su sintomi, velocità e accuratezza di lettura. I tre "20" furono scelti perché
memorabili, non perché ottimizzati.

Otium non costruisce un timer per gli occhi. La pausa motoria li riposa comunque.

---

## Come funziona

**Conta il tempo attivo, mai l'orologio a muro.** Se ti fermi più di un minuto il contatore si
ferma; se torni prima, riprende da dov'era. È il difetto più citato nelle recensioni delle
alternative: sbloccano in base all'ora, così basta fermarsi un attimo per trovarsi la schermata
addosso.

**La pausa spontanea vale.** Se ti alzi da solo per più di 90 secondi, la micro-pausa è considerata
fatta. Oltre 5 minuti vale come pausa piena. Alzarsi da soli è il comportamento desiderato, non un
modo di imbrogliare.

**Ma stare fermo non è alzarsi.** Guardare un film o leggere un PDF è immobilità perfetta — cioè
esattamente il bout sedentario che gli studi misurano. Otium distingue i due casi:

| Cosa stai facendo | Come lo capisce | Cosa fa |
|---|---|---|
| guardi un video | un player **in elenco** sta producendo audio, attribuito al processo (helper annidati compresi) | conta come tempo fermo → la pausa scatta |
| leggi un documento | l'app in primo piano è un lettore, e `lsof` dice quale `.pdf`/`.docx`/`.md` tiene aperto | conta come tempo fermo → la pausa scatta |
| sei in call | microfono in uso | **rimanda**, e lo dichiara |
| te ne sei andato | nessun segnale, nessun input | pausa naturale, nessun esercizio |

Ogni segnale **scade**, o basterebbe lasciare un PDF aperto e andare a pranzo per far contare il
pranzo come lavoro: **45 minuti** per un video, **15** per un documento, senza un solo input.
Oltre il tetto l'orologio si ferma — e rientrando non ti viene regalata una pausa che non hai
preso: l'assenza vale solo da quando il segnale è scaduto.

L'elenco dei player è chiuso di proposito: contano solo browser e riproduttori video, mai un
processo qualsiasi che stia suonando. Spotify e Musica sono **fuori** — la musica di sottofondo
mentre sei in cucina non è "essere davanti allo schermo".

Una nota tecnica che è costata una prova sul campo: il primo disegno leggeva l'asserzione di
sistema *«non spegnere lo schermo»*, quella che i player alzano durante un video. **I browser
Chromium non la alzano affatto** — con YouTube in riproduzione in Brave, l'elenco completo delle
asserzioni conteneva solo `caffeinate`, `powerd` e WindowServer. L'audio invece si vede sempre. E
chi suona non è il browser: è un helper annidato dentro il suo bundle, che per il sistema non è
un'applicazione — va risalito il percorso dell'eseguibile fino al `.app` più esterno.

Per vedere cosa riconosce in questo momento:

```bash
dist/Otium.app/Contents/MacOS/Otium --presence
```

**Il pulsante "fatto" ha un cancello.** Si sblocca solo dopo il tempo minimo plausibile per quelle
ripetizioni (ripetizioni × secondi per ripetizione). Senza telecamera è un sistema d'onore, ma
l'onore con un cronometro davanti costa più fatica della verità.

**Sedici esercizi, e le varianti dentro la pausa.** La rotazione propone quello che tocca —
squat, push-up, affondi, polpacci, ponte per i glutei, dip su sedia — e mai due volte di fila lo
stesso gruppo muscolare. Se la pausa è di push-up puoi passare con un clic a **diamond**,
**archer**, **dip su sedia**, **pike** o **inclinati**: le ripetizioni si adeguano alla
difficoltà, e il cronometro del "fatto" riparte dal cambio, così scegliere la variante più corta
all'ultimo secondo non serve a niente.

**Rampa progressiva.** Si parte al 55% del volume e si sale al 100% in quattro settimane. Partire
pieni il primo giorno è il modo più rapido per farsi male e disinstallare l'app.

**Non ti blocca durante una call.** Se un microfono è in uso, la pausa si rimanda e lo dichiara.

**Non ti chiude fuori.** C'è sempre un'uscita: digitare per esteso una frase esatta. Ogni salto
finisce nel registro — non è un giudizio, è un dato. E se non c'è nessuno davanti al Mac il blocco
cade da solo.

### Onestà su cosa il blocco è, e cosa non è

Da macOS High Sierra nessuna finestra può stare sopra il lock screen di sistema, e qualunque
processo si può uccidere da un terminale. Otium non è un lucchetto: è **attrito forte**. Copre ogni
schermo a livello di schermatura, nasconde Dock e barra dei menu, disabilita ⌘-Tab, Exposé, uscita
forzata e chiusura di sessione. Chi vuole aggirarla ci riesce — e va bene così: il punto è mettere
la scelta davanti agli occhi, non toglierla.

---

## Privacy e permessi

Otium **non compare** in Impostazioni → Privacy e sicurezza, perché non usa niente che lo richieda:

- l'inattività si legge da `CGEventSource`, che non richiede né Accessibilità né Input Monitoring;
- il rilevamento delle call legge `kAudioDevicePropertyDeviceIsRunningSomewhere`, cioè *se* un
  dispositivo è in uso — nessuno stream aperto, nessun byte di audio, nessun permesso microfono;
- il preavviso è un pannello dell'app, non una notifica di sistema (che richiederebbe un permesso);
- niente telecamera, niente registrazione schermo, niente rete.

Tutto resta in `~/Library/Application Support/Otium/`: `settings.json` e `ledger.jsonl`, un registro
append-only in JSON Lines che puoi leggere con qualsiasi cosa.

---

## Installazione

Serve macOS 15+ e Xcode (o i Command Line Tools).

```bash
git clone <questo-repo> && cd Otium
Scripts/build-app.sh          # produce dist/Otium.app, firmata ad-hoc
open dist/Otium.app
```

Ne gira **una sola alla volta**: cercarla di nuovo da Spotlight sveglia quella che c'è e ti dice
fra quanto arriva la prossima pausa, invece di avviare un secondo timer in parallelo.

L'app vive nella barra dei menu: il numero è quanti minuti di lavoro attivo mancano alla prossima
pausa. Da lì: totali di oggi, preferenze, le fonti, il registro.

Per farla ripartire da sola se viene chiusa, in Preferenze → *Avvio automatico*, oppure:

```bash
dist/Otium.app/Contents/MacOS/Otium --install-agent   # LaunchAgent con KeepAlive
dist/Otium.app/Contents/MacOS/Otium --agent-status
dist/Otium.app/Contents/MacOS/Otium --remove-agent
```

Lo stato dell'avvio automatico non risponde "il file esiste?" ma "il file che lancia esiste ancora,
ed è questa copia?" — un plist che punta a un binario spostato riparte ogni giorno fallendo in
silenzio.

### Vedere la schermata senza aspettare mezz'ora

```bash
dist/Otium.app/Contents/MacOS/Otium --demo-break=20        # si spegne da sola dopo 20 s
dist/Otium.app/Contents/MacOS/Otium --snapshot=out.png     # la disegna fuori schermo
```

L'auto-spegnimento non è una comodità: durante il blocco l'app disabilita l'uscita forzata, quindi
una demo che dipendesse da qualcuno che la chiude a mano sarebbe il modo perfetto di lasciare un
Mac inchiodato.

---

## Cosa c'è già, e cosa no

| | Otium | [Stretchly](https://github.com/hovancik/stretchly) | Time Out | [Workrave](https://workrave.org) | app "sblocca con i push-up" |
|---|---|---|---|---|---|
| macOS nativo | ✅ ~5 MB | Electron | ✅ | ❌ (port fermo) | solo iPhone |
| conta il tempo **attivo** | ✅ | pausa su idle | ✅ *natural breaks* | ✅ | ❌ orologio a muro |
| blocca davvero lo schermo | ✅ | parziale | ❌ | ✅ | ✅ |
| esercizi con ripetizioni | ✅ | idee testuali | ❌ | ✅ guidati | ✅ |
| conta le ripetizioni | ❌ (onore + cronometro) | ❌ | ❌ | ❌ | ✅ telecamera |
| mostra le fonti | ✅ | ❌ | ❌ | ❌ | ❌ |
| prezzo | gratis, open source | gratis | gratis | gratis | 15 $/mese |

## In programma

- Verifica reale delle ripetizioni **senza telecamera**: movimento della testa dagli AirPods
  (`CMHeadphoneMotionManager`) o Apple Watch.
- Interfaccia in inglese (oggi è in italiano) e notarizzazione per la distribuzione fuori dal
  repo.
- Report settimanale: ripetizioni, pause rispettate, tempo davanti al Mac.

## Test

```bash
swift test    # 52 test sulla logica pura: orologio, motore, rampa, rotazione, registro
swift Scripts/probe-blocker.swift    # verifica che il blocco copra ogni schermo (con l'app in blocco)
```

La sonda del blocco si tara da sola costruendo una finestra di misura nota, perché
`kCGWindowBounds` non vive nello stesso spazio di coordinate di `NSScreen.frame`: su un display in
modalità scalata una finestra da 1512×982 punti viene elencata come 1362×884, e confrontare i
numeri grezzi fa dichiarare rotta un'app sana.
