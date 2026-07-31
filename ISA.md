---
slug: otium
title: Otium — pause forzate con allenamento integrato per macOS
phase: complete
progress: true
iteration: 1
context_sufficient: true
interview_invoked: false
principal_stated_goal: "voglio creare qualcosa che sia in grado di monitorare il tempo reale che spendo davanti al computer mentre uso lifeos o altri tipi di lavori e che dopo un tempo determinato, che dobbiamo valutare insieme quale sia il miglior tempo scientificamente e con studi, obbligare a fare una pausa di un tempo altrettanto studiato e che durante questa pausa mi obblighi a fare un tot numero di squat, pushups, burpees, jumpingjacks o quello che è meglio così da integrare allenamento all'interno delle sessioni di lavoro. e che se non vengono eseguite lo schermo rimane bloccato o qualcosa del genere. non serve la telecamera, già il richiamo permette di essere in condizione di scelta"
created: 2026-07-26
---

# Otium

## Goal

> "voglio creare qualcosa che sia in grado di monitorare il tempo reale che spendo davanti al
> computer … e che dopo un tempo determinato … obbligare a fare una pausa … e che durante questa
> pausa mi obblighi a fare un tot numero di squat, pushups, burpees, jumpingjacks … e che se non
> vengono eseguite lo schermo rimane bloccato … non serve la telecamera, già il richiamo permette
> di essere in condizione di scelta"

Poi, nel secondo turno: *"esiste già qualcosa di simile in commercio o su github? in caso positivo
possiamo prendere spunto e migliorarla. in ogni caso pensiamo a pubblicarla una volta ultimata
proponendo i vari studi come spinta ad utilizzarlo"* — e la scelta della cadenza: **opzione A**.

Un'app macOS nativa che conta il **tempo attivo reale** davanti al Mac, e a intervalli fissati
dalla letteratura blocca lo schermo finché non è stato fatto un esercizio a corpo libero. Niente
telecamera, niente abbonamento, niente rete.

## Problem

Il lavoro al computer produce due danni su due orologi diversi, e nessuno strumento su Mac li
affronta insieme. Il primo è **metabolico**: stare seduti a lungo alza i picchi glicemici, e
l'unica dose che li appiattisce davvero è un'interruzione ogni ~30 minuti (Duran 2023). Il secondo
è **muscoloscheletrico/cognitivo**: dolori, affaticamento visivo e calo di vigore, che 5 minuti di
pausa ogni ora riducono senza costare produttività (Galinsky 2000/2007).

Il panorama attuale (sondato il 2026-07-26) lascia un buco preciso: chi blocca ed esercita è
**solo iPhone**, a pagamento e con la telecamera (Pushscroll, Fitlock, PushUp Time, StepBloc); su
Mac o si blocca senza esercizi (Time Out) o si suggerisce senza bloccare (Stretchly, che mostra
solo idee testuali); l'unico con esercizi guidati veri, Workrave, **su Mac non esiste** (port Qt5
fermo nel ramo `next`). E nessuno mostra le fonti dei propri numeri: "Exercise Snacks" chiede
49,99 £/anno dichiarandosi *science-backed* senza citare un solo studio.

Il problema personale sotto: il vincolo dichiarato in TELOS (C2, distrazione/perdita di focus)
rende inaccettabile una soluzione che interrompa a caso; deve interrompere **poco e nel momento
giusto**, misurando il lavoro vero e non l'orologio a muro.

## Vision

l'autore lavora. In alto a destra un'icona conta in silenzio. Dopo 30 minuti di lavoro *vero* —
non 30 minuti di orologio — arriva un preavviso di 60 secondi, poi lo schermo si copre: un
esercizio, un conteggio, 90 secondi, e si torna al lavoro. Ogni terza volta la pausa è piena: 5
minuti, un bout vigoroso, e tre minuti lontano dallo schermo. A fine giornata il registro dice
quanti squat, quante flessioni, quante pause saltate. Ogni numero dell'app ha accanto lo studio
da cui viene, leggibile dall'app stessa. Se si alza da solo, il timer se ne accorge e non lo
punisce. Se è in call, la pausa aspetta.

## Out of Scope

- **Telecamera e pose detection** — escluse per richiesta esplicita, e le recensioni di Pushscroll
  confermano che contano male.
- **Verifica biometrica delle ripetizioni** (AirPods `CMHeadphoneMotionManager`, Apple Watch):
  possibile, non in v1.
- **iOS, Windows, Linux.**
- **Blocco a prova di manomissione**: dallo spazio utente non esiste; l'obiettivo dichiarato è
  attrito forte, non una prigione.
- **Sandbox e App Store**: la revisione litigherebbe con `disableForceQuit`; distribuzione diretta.
- **Notarizzazione**: sonda del 2026-07-26 — su questa macchina esiste solo un certificato
  self-signed ("Parla Dev"), nessun Developer ID. Firma ad-hoc, notarizzazione rinviata alla
  pubblicazione.
- **Rete, account, telemetria.**
- **Pubblicazione su GitHub**: decisa ("pensiamo a pubblicarla una volta ultimata"), non in questo
  run — nessun push senza permesso esplicito.

## Principles

- **Il tempo attivo è l'unica unità di misura.** Mai l'orologio a muro: è il difetto n.1 nelle
  recensioni dei concorrenti.
- **Le fonti sono il prodotto, non il marketing.** Ogni parametro porta il suo studio, e l'app
  dichiara anche cosa *non* implementa e perché (la regola 20-20-20, senza supporto sperimentale).
- **L'attrito è forte ma l'uscita esiste sempre.** Un'app che può intrappolare una persona davanti
  a uno schermo bloccato durante un'emergenza è un difetto, non una funzione.
- **Nessun permesso di sistema.** Niente Accessibilità, niente Registrazione schermo, niente
  telecamera: se serve un permesso TCC, la funzione si ridisegna.
- **La pausa spontanea si premia, non si annulla.** Alzarsi da soli è il comportamento desiderato.

## Constraints

- macOS 15+, Swift 6.3 / Xcode 26.6 (sondati sulla macchina il 2026-07-26).
- SwiftPM con la stessa forma di Peel (`Package.swift`, `Sources/`, `Tests/`, `Scripts/build-app.sh`).
- App accessoria (`LSUIElement`) — nessuna icona nel Dock in condizioni normali.
- Il blocco usa `NSApplication.presentationOptions` in combinazione chiosco (TN2062) + finestre a
  livello `.screenSaver` su ogni schermo: da High Sierra nessuna finestra può stare sopra il lock
  screen di sistema, quindi il blocco è dell'area di lavoro, non del login.
- Nessuna dipendenza esterna: solo AppKit/SwiftUI/CoreAudio/CoreGraphics.
- Italiano nell'interfaccia (l'inglese arriverà con la pubblicazione).

## Goal criteria — la cadenza scelta

Opzione **A**, confermata dal principale il 2026-07-26:

| Evento | Ogni | Durata | Esercizio |
|---|---|---|---|
| micro-snack | 30 min di tempo attivo | 90 s | 15 squat / 10 push-up / 20 jumping jack (a rotazione) |
| pausa piena | ogni 3° break (≈90 min) | 5 min | 60-90 s vigorosi (burpee) + 3 min lontano dallo schermo |

Rampa: settimana 1 al 55% delle ripetizioni, +15% a settimana fino al 100% in settimana 4.

## Criteria

> **Stato al 2026-07-29, iterazione 16: 142 chiusi su 143.** L'unico aperto resta ISC-28.
>
> ISC-28 è esperienziale e non si chiude con un probe: si chiude **usando l'app**. Al 29 luglio
> sono 16 pause vere in tutto, quindi la cadenza non è ancora stata falsificata da nessuno.

### Tempo attivo

- [x] **ISC-1** L'orologio accumula solo quando c'è input reale: con inattività ≥ 60 s
      l'accumulo si ferma. — `swift test`, `testStopsAccumulatingBeyondIdleThreshold` +
      `testIdleTimeNeverTriggersABreak`.
- [x] **ISC-2** Una pausa spontanea ≥ la durata del micro-snack azzera il contatore del
      micro-snack e viene registrata come `natural`, senza esercizio. —
      `testNaturalBreakCreditsTheMicro`.
- [x] **ISC-3** Una pausa spontanea ≥ 5 minuti azzera anche il contatore della pausa piena. —
      `testLongAbsenceCreditsTheLongBreak` (`creditedLong == true`, `microsSinceLong == 0`).
- [x] **ISC-4** L'inattività non consuma il credito oltre quanto dovuto: rientrando entro la
      soglia, il contatore riprende dal valore che aveva, non da zero. —
      `testCounterEqualsTrueWorkTimeAfterCrossingTheThreshold`: 200 s di lavoro veri, l'orologio
      sale a 259 mentre non sa ancora dell'assenza, e torna a ~200 al momento in cui lo capisce.
- [x] **ISC-5** La sospensione del sistema (sleep/wake) non viene contata come tempo attivo. —
      `testSleepGapIsNeverCreditedAsActiveTime`: un salto di 3600 s lascia il contatore a 100.

### Motore delle pause

- [x] **ISC-6** Con cadenza A, la sequenza dei break su 90 minuti di tempo attivo è
      micro → micro → piena, e riparte. — `testCadenceASequenceIsMicroMicroLong`:
      `[.micro, .micro, .long, .micro, .micro, .long]`.
- [x] **ISC-7** Prima di ogni blocco arriva un preavviso di 60 s. — `testWarningFiresAtTheInterval`.
- [x] **ISC-8** Il rinvio è concesso una sola volta per break (2 minuti), poi non più. —
      `testOnlyOnePostponeIsAllowed`.
- [x] **ISC-9** Se un dispositivo d'ingresso audio è in uso (call), il break si rimanda
      automaticamente e lo dichiara, invece di bloccare lo schermo. —
      `testBreakIsDeferredWhileTheMicrophoneIsInUse` + `testDeferralsAreBoundedByMaxAutoDefers`
      (non rimanda all'infinito).
- [x] **ISC-10** La rampa progressiva calcola le ripetizioni in funzione delle settimane
      trascorse dalla prima esecuzione. — `RampTests`: 0.55 → 0.70 → 0.85 → 1.0, monotona.

### Blocco dello schermo

- [x] **ISC-11** Il blocco copre **ogni** schermo collegato, e uno schermo collegato durante il
      blocco viene coperto anch'esso. — `swift Scripts/probe-blocker.swift` a due poli:
      **FAIL 0/1** con l'app spenta, **PASS 1/1** con l'app in blocco (finestra coincidente con
      il metro tarato, `livello 2147483628`). Il caso dello schermo aggiunto a blocco già attivo
      è coperto dall'osservatore `didChangeScreenParametersNotification` (ispezione codice: un
      secondo monitor non era disponibile per la prova).
- [x] **ISC-12** Durante il blocco Dock e barra dei menu sono nascosti, ⌘-Tab, Exposé, uscita
      forzata e terminazione di sessione sono disabilitati. — **ispezione codice**: combinazione
      chiosco TN2062 in `BlockerController.kioskOptions`. Non provata da un probe indipendente:
      l'effetto è visivo e la cattura schermo su questa macchina non è disponibile (vedi
      Verification).
- [x] **ISC-13** La finestra di blocco è visibile su tutte le Spaces e sopra le app a schermo
      intero. — livello misurato `2147483628` = `CGShieldingWindowLevel()`, sopra ogni finestra
      normale; `collectionBehavior` con `.canJoinAllSpaces` e `.fullScreenAuxiliary`.
- [x] **ISC-14** `Anti:` il blocco non richiede **nessun** permesso TCC — l'app non compare in
      Accessibilità, Registrazione schermo o Telecamera. — grep su `Sources/` per
      `AVCaptureDevice|CGWindowListCreateImage|AXIsProcessTrusted|CGEventTap|UNUserNotificationCenter|SCStream`:
      **zero occorrenze**; `codesign -d --entitlements` non riporta alcun entitlement.

### Esercizio

- [x] **ISC-15** Il pulsante "fatto" resta disabilitato finché non è trascorso il tempo minimo
      plausibile per quelle ripetizioni. — `testDoneButtonIsDeadBeforeTheMinimumTime`: prima del
      tempo, `markExerciseDone()` non emette eventi e la fase resta `.breaking`.
- [x] **ISC-16** Gli esercizi ruotano invece di ripetere sempre lo stesso gruppo muscolare. —
      `testABadlyOrderedPoolGetsStraightened`, con polo negativo **eseguito**: sabotando
      `spreadByMuscleGroup` a identità il test diventa rosso (4 fallimenti), ripristinandolo
      torna verde.
- [x] **ISC-17** La pausa piena propone un bout vigoroso (la dose VILPA di Stamatakis 2022). —
      `testLongBreakUsesAVigorousExercise`.
- [x] **ISC-18** `Anti:` nessuna schermata di esercizio può essere chiusa premendo Esc, ⌘W, ⌘Q
      o cliccando fuori. — ispezione codice: `performKeyEquivalent` inghiotte ⌘Q/W/H/M/`,
      `cancelOperation` è vuoto di proposito, la finestra è `.borderless` senza controlli.

### Uscita di sicurezza

- [x] **ISC-19** Esiste un'uscita d'emergenza che richiede di digitare per esteso una frase
      esatta; ogni uso viene registrato. — `testEscapeRequiresTheExactPhrase` (frase parziale e
      vuota non aprono; maiuscole e spazi perdonati) + riga `skipped/escapePhrase` nel registro.
- [x] **ISC-20** `Anti:` l'app non può lasciare lo schermo bloccato in modo permanente. —
      **criterio riscritto in corso d'opera** (vedi Decisions): due reti invece di una,
      `testBlockReleasesWhenNobodyIsThere` e `testFailsafeCeilingReleasesTheBlock`, più il polo
      opposto `testStandingAwayDuringALongBreakDoesNotCancelIt`.

### Registro e prove

- [x] **ISC-21** Ogni evento finisce in un JSONL append-only sotto Application Support. —
      `LedgerTests` + file reale scritto dalle esecuzioni di prova
      (`~/Library/Application Support/Otium/ledger.jsonl`, 8 righe, tipi `natural`/`active`).
- [x] **ISC-22** Il menu mostra i totali di oggi: ripetizioni per esercizio, pause fatte,
      saltate, e i bout vigorosi rispetto al bersaglio di 3/giorno. — `testDailySummaryAggregates`
      (solo il burpee conta come bout vigoroso) + `MenuPanel`.
- [x] **ISC-23** Ogni parametro dell'app è associato in-app allo studio che lo giustifica, con
      titolo, anno e link. — `testEveryStudyIsFullyCited` + la citazione compare **nella
      schermata di blocco resa** (immagini guardate: Gao 2024 sul micro, Stamatakis su quella piena).
- [x] **ISC-24** L'app dichiara in-app la regola 20-20-20 come *non implementata per mancanza di
      prove*. — `testTheUnimplementedRuleIsDeclared`.

### Presenza silenziosa — video e lettura (aggiunta il 2026-07-26, iterazione 2)

> Nate da un'osservazione del principale: *«può funzionare anche durante youtube, netflix etc.
> non durante telefonate o call di lavoro»*. La versione 1 faceva l'opposto — un film è
> immobilità perfetta, quindi veniva **accreditato come pausa ben fatta**.

- [x] **ISC-30** Il tempo passato davanti a un video in riproduzione conta come tempo sedentario:
      30 minuti di film senza toccare niente fanno scattare la pausa. —
      `testWatchingAVideoStillTriggersABreak`, con il polo negativo nello stesso file
      (`testWithoutTheSignalTheSameStillnessCreditsFakeBreaks`: senza segnale, gli stessi 30
      minuti vengono accreditati come pausa piena — il comportamento vecchio, provato).
- [x] **ISC-31** Il segnale del video è attribuito **al processo**, mai letto come flag globale. —
      `testOnlyKnownPlayersCount`: Safari, Chrome e Brave contano; Terminal, iTerm e Xcode no.
      Motivazione dal campo: durante lo sviluppo girava un `caffeinate` lanciato da Claude Code, e
      il principale ha sollevato esattamente questo dubbio.
      **Criterio riscritto il 2026-07-26 dopo una prova sul campo fallita** (vedi Decisions): il
      segnale primario non è più l'asserzione sullo schermo — i browser Chromium non la alzano
      affatto — ma l'**audio attribuito al processo**. Prova end-to-end, con YouTube in
      riproduzione in Brave: `audio in riproduzione — Brave Browser` ·
      `presenza: media · tetto 45 min`.
- [x] **ISC-31b** L'attribuzione risale dagli helper annidati all'app che li possiede. — Sondato
      sul processo reale: `Brave Browser Helper` (pid 32652) → `NSRunningApplication` diretta
      `nil` → percorso dell'eseguibile → `/Applications/Brave Browser.app` → `com.brave.Browser`,
      che è in elenco.
- [x] **ISC-32** Leggere un documento in primo piano conta come tempo sedentario, e il documento
      viene riconosciuto per nome (`.pdf .doc .docx .pages .md .txt` e altri). —
      `testReadingADocumentCountsAsSedentaryTime`, `testReadingExtensionsCoverWhatWasAsked`, e
      **prova end-to-end sul vivo**: PDF aperto in Anteprima → `lettura: prova-radar-otium.pdf —
      Anteprima`. Il nome del file arriva da `lsof`, quindi lo strato 2 funziona per intero e non
      solo nel riconoscimento dell'app.
- [x] **ISC-33** Ogni segnale scade: 45 minuti per un video, 15 per un documento, senza un solo
      input. — `testSignalsExpireAtTheirCapOnBothSides` (sondato su entrambi i lati di ogni
      tetto) + `testTheClockStopsCountingWhenTheSignalDrops`.
- [x] **ISC-34** `Anti:` rientrare da un film non accredita una pausa mai presa: l'assenza vale
      solo da quando il segnale è scaduto, non dall'inizio del film. —
      `testReturningFromAVideoDoesNotCreditABreakYouNeverTook`.
- [x] **ISC-35** Una call rimanda il break **anche** in presenza di un segnale video: il
      microfono resta il discriminante fra un film e una riunione. —
      `testACallStillDefersEvenWithAPresenceSignal`.
- [x] **ISC-36** La schermata di blocco dichiara cosa ha riconosciuto ("fermo davanti a un video:
      …", "fermo su un documento: relazione.pdf — Anteprima"). Un'app che agisce su una deduzione
      senza mostrarla è un'app a cui non puoi dare torto. —
      `testTheDetectedSignalIsCarriedToTheBreakScreen` + `BreakView.header`.
- [x] **ISC-37** `Anti:` il radar non introduce **nessun** permesso nuovo. —
      `IOPMCopyAssertionsByProcess`, `NSWorkspace.frontmostApplication` e `lsof` sui propri
      processi non passano da TCC; grep sulle API a permesso confermato a zero dopo la modifica.

- [x] **ISC-38** La classificazione parte da **cosa hai in primo piano**, non da cosa sta
      suonando: un documento davanti batte un audio dietro. — `PresenceClassifier`, provato ramo
      per ramo (`testWhatYouHaveInFrontWinsOverWhatIsPlayingBehind`,
      `testAPlayerInFrontThatIsActuallyPlayingIsVideo`, `testABrowserThatIsNotPlayingIsReading`,
      `testEverythingElseIsNoPresence`), con polo negativo **eseguito**: invertendo l'ordine nel
      codice, `testWhenAnAppIsBothReaderAndPlayerReadingWins` diventa rosso.
      Prova end-to-end (timeline `--watch`): iTerm2 → nessuna presenza · Anteprima col PDF →
      `reading · tetto 15′ · prova-radar-otium.pdf` · Brave senza audio →
      `reading · tetto 15′ · pagina web`.
- [x] **ISC-39** Un browser in primo piano che non suona conta come **lettura**, non come
      assenza. — `testABrowserThatIsNotPlayingIsReading` + la timeline sopra.

- [x] **ISC-40** Una sola istanza alla volta: cercare Otium da Spotlight quando è già viva
      **sveglia quella che c'è**, non ne avvia una seconda. — Presidio con lock di file (regge
      anche lanciando l'eseguibile a mano, dove il controllo sul bundle identifier non
      funzionerebbe). Provato sulle tre vie d'avvio — binario diretto, secondo binario, `open`
      del bundle come fa Spotlight: **1 processo** in tutti i casi. Polo negativo **eseguito**:
      disattivando il lock, il secondo avvio produce **2 processi** — il difetto riprodotto.
- [x] **ISC-41** Il secondo avvio produce una risposta **visibile**, non silenzio: un pannello
      che dice fra quanto arriva la prossima pausa. — Verificato via lista finestre del server
      grafico: dopo il secondo avvio compare una finestra di Otium 320×84, la misura del
      pannello. Il silenzio è indistinguibile da un'app morta, ed è la ragione per cui uno
      finisce col lanciarla due volte.

- [x] **ISC-42** Le notifiche di Otium compaiono **in alto a destra**, dove macOS mette le
      proprie. — Misurato a schermo: pannello 320×84 a (1176, 45) su uno schermo 1512×982 →
      in alto e a destra. (Era in basso a destra: segnalato dal principale il 2026-07-26.)
- [x] **ISC-43** I comandi in fondo alla schermata di blocco **sembrano** comandi: capsula con
      bordo, icona e reazione al passaggio del mouse. — Schermate rese e guardate (break n. 2 e
      n. 4): «Rinvia 2 minuti» e «Non posso adesso» sono bottoni, non parole grigie.
- [x] **ISC-44** La rotazione degli esercizi **sopravvive alla chiusura dell'app**. — Era il
      difetto per cui sembrava proporre solo squat: `breakIndex` ripartiva da zero a ogni avvio,
      e il break n. 1 è sempre squat. Ora lo stato si salva a ogni pausa e si ripristina
      all'avvio. Provato rendendo quattro break consecutivi dopo ripristino da disco:
      **squat → push-up → (burpee, pausa piena) → sollevamenti sui polpacci**.
      Test: `testRestoringContinuesTheRotationInsteadOfRestartingIt`,
      `testSnapshotSurvivesADiskRoundTrip`, `testRestoreClampsAbsurdValues`.

- [x] **ISC-45** Il catalogo esercizi è ampio e vario: **16 esercizi** su sei gruppi muscolari
      (gambe, glutei, polpacci, spinta, tricipiti, tutto il corpo). — `testEveryExerciseIsFullyDescribed`
      (ognuno ha nome, istruzione, gruppo, ripetizioni e ritmo) + pool di serie allargato a 6
      esercizi e pool vigoroso a 4, con la proprietà "mai due gruppi uguali di fila" ancora
      valida (`testDefaultPoolIsWiderAndStillWellSpread`).
- [x] **ISC-46** Le varianti dei push-up sono **opzionali dentro la pausa**: diamond, archer,
      dip su sedia (bench dips — nome verificato su fonti, non scelto a orecchio), pike,
      inclinati. — Schermata resa e guardata: la riga "oppure" mostra le cinque alternative con
      le ripetizioni già scalate sulla difficoltà (diamond 4, archer 3, dip 7 contro i 6 push-up
      di base). Preferenza `offerVariants` per spegnerle.
- [x] **ISC-47** `Anti:` cambiare variante non è una scorciatoia per finire prima — il tempo
      minimo riparte dal cambio. — `testSwappingRestartsTheAntiBluffTimer`: arrivato al punto in
      cui potrebbe premere "fatto", dopo lo scambio `canFinishNow` torna falso e
      `markExerciseDone()` non chiude niente. E si può passare **solo** a una variante:
      `testSwappingToAnUnrelatedExerciseIsRefused`.

- [x] **ISC-48** Il testo scientifico **cambia a ogni pausa**: nove fonti in rotazione, poi
      ricomincia. — `testTheStudyChangesAtEveryBreak` (nessuna ripetuta nel giro, mai due uguali
      di fila) + due schermate rese e guardate su break diversi (n. 5 e n. 8) con testi diversi.
      Prima era fisso: Gao sui micro, Stamatakis sulle piene.
- [x] **ISC-49** All'avvio compare una **citazione**, diversa a ogni apertura. — Pannello 380×132
      in alto a destra, misurato a schermo a 2 s e 6 s dall'avvio, sparito a 14 s. Il contatore
      degli avvii vive nello stesso file di stato della rotazione
      (`testLaunchCountDrivesTheQuoteAndPersists`).
- [x] **ISC-50** `Anti:` nessuna citazione senza opera identificabile. — `testNoUnsourcedAttributions`
      congela il criterio, **Lao Tzu compreso**: la frase «la natura non ha fretta, eppure tutto
      si compie», ovunque attribuita al Tao Te Ching, non compare in nessuna traduzione del
      capitolo 64 — è una parafrasi moderna. Verificata e **scartata**. Un'app che chiede di
      essere creduta sulle fonti degli studi non può sbagliare una citazione.
- [x] **ISC-51** L'app cita anche le prove sulla **concentrazione**, non solo sul metabolismo:
      Biwer 2023 (le pause imposte battono quelle contrattate) e Ariga & Lleras 2011 (il calo di
      attenzione è disabituazione all'obiettivo, non una batteria scarica). —
      `testTheConcentrationEvidenceIsPresent`.
- [x] **ISC-52** `Anti:` l'app **non promette** che 90 secondi di esercizio migliorino il lavoro
      subito dopo — e lo dichiara in schermata, con l'etichetta «Non promesso» invece di
      «Perché». — Voce `exerciseAndCognition` + `testDisclaimersAreDeclaredAndExcludedFromSupportingSources`.

- [x] **ISC-53** La citazione compare **anche a ogni pausa**, al centro della schermata, e non è
      quella dell'avvio. — Schermata resa e guardata (break n. 2: Marco Aurelio in serif sotto le
      varianti) + `testBreakQuoteDiffersFromLaunchQuoteAndRotates` (quattro pause, quattro
      citazioni diverse, mai uguale a quella dell'avvio).
- [x] **ISC-54** La citazione contesa è **ammessa come anonima**, non attribuita. — Cercata due
      volte: circola ovunque come di Lao Tzu, non compare in nessuna traduzione del capitolo 64,
      nessuna fonte autorevole indica l'originale. Resta nel catalogo con autore «anonimo» e la
      nota che dice perché. `testTheDisputedQuoteIsPresentAsAnonymous`.
- [x] **ISC-55** Le fonti sul **focus** sono nella pagina «Da dove vengono questi numeri». —
      Pagina resa e guardata per intero: Biwer 2023 e Ariga & Lleras 2011 ci sono, e le due voci
      che dichiarano i limiti si distinguono a colpo d'occhio (titolo grigio invece di ambra).
- [x] **ISC-56** Chiudendo e riaprendo entro la finestra di grazia il conto **riprende**; oltre,
      riparte. — `testReopeningWithinTheGraceContinuesTheCount` /
      `testReopeningAfterTheGraceStartsFresh`. La finestra vale **5 minuti** e non è un numero
      nuovo: è la durata di una pausa piena, cioè la soglia oltre la quale per Otium quello è
      già un vero stacco (`testGraceEqualsAFullBreakByDefault`). Lo stato si salva ogni 30 s e
      alla chiusura, non solo a fine pausa.
- [x] **ISC-57** Si può **dichiarare da quanto si è già seduti** se ci si è scordati di aprire
      l'app. — Sottomenu con 10/15/20/30/45/60/90 minuti; il conto sale a quel valore, la pausa
      arriva quando è dovuta e il tempo finisce nel registro come `dichiarato`.
      `testDeclaringTimeAlreadySeatedMovesTheCounter` e, per il verso opposto,
      `testDeclaringLessThanMeasuredDoesNotShrinkTheCounter`.
- [x] **ISC-58** Il **suono del preavviso si sceglie**, fra i 14 di sistema o nessuno, con
      anteprima. — Nessun file audio spedito con l'app; `NotificationSounds` + selettore in
      preferenze con pulsante «ascolta».
- [x] **ISC-59** `Anti:` nessun markdown crudo nei testi a schermo. — Difetto visto a schermo in
      **tre punti** (introduzione delle fonti, due claim): `Text` interpreta il markdown solo su
      stringhe letterali, e su una concatenazione stampa gli asterischi. Class-sweep su tutte le
      stringhe visibili, zero residui, e `NoRawMarkdownTests` chiude la classe su studi,
      citazioni ed esercizi.

- [x] **ISC-60** Le notifiche si **scorrono via come quelle di sistema**: trascinamento verso
      destra oltre soglia per farle sparire, ritorno elastico sotto soglia, clic per chiudere. —
      Codice ispezionato + il difetto che il gesto avrebbe avuto: la finestra è larga 840 px
      contro un pannello di 380, cioè **460 px di corsa** — misurati a schermo. Senza, il
      pannello si sarebbe tagliato al bordo della finestra e il gesto sarebbe sembrato rotto.
      `[DEFERRED-VERIFY]` sul gesto vero: serve un dito sul trackpad, che da qui non ho.
- [x] **ISC-61** L'arancione su nero è **fuori**: era la livrea di Sveglia, Timer e Promemoria di
      Apple — su un Mac non dice "Otium", dice "sistema operativo" — ed è per giunta il colore
      dell'allarme, cioè l'opposto del messaggio. — Zero occorrenze di `amber` nel codice;
      schermata resa e guardata col tema nuovo.
- [x] **ISC-62** Tre livree con un'identità dichiarata, scelte in preferenze:
      **Alloro** (verde notte + salvia: la corona romana, un colore che dice riposo),
      **Ardesia** (blu-grigio profondo, per chi lavora di notte),
      **Porpora** (il colore che a Roma se lo poteva permettere solo chi non doveva lavorare).
      Il fondo non è più nero puro. — Schermata di blocco e pagina delle fonti rese e guardate
      con Alloro; l'accento ha una variante dedicata per le finestre su fondo chiaro, perché il
      salvia che funziona sul nero sparisce sul bianco.

- [x] **ISC-63** `Anti:` nessun test intermittente nella suite. — Ne è comparso uno proprio in
      questo giro (`testReopeningWithinTheGraceContinuesTheCount`, **2 fallimenti su 8 giri**):
      confrontava con l'uguaglianza esatta un divario temporale calcolato fra due `Date()`, che
      non è mai esattamente 30. Riparato asserendo il caso e i numeri con tolleranza; **8 giri
      consecutivi verdi** dopo la correzione, e sweep sulla classe per gli altri confronti
      fragili sul tempo (nessuno).

- [x] **ISC-64** `Anti:` l'avvio automatico non può entrare in ciclo infinito. — **Difetto
      riprodotto sul banco** (segnalato dal principale): con `KeepAlive: true`, launchd avvia una
      copia, quella trova il lock già preso ed esce **pulita**, launchd la rilancia perché "keep
      alive" vuol dire *sempre* → `state = spawn scheduled`, all'infinito. Rimedio:
      `KeepAlive: {SuccessfulExit: false}` — riparte solo se è morta male — più
      `ThrottleInterval: 10`. Provato sui due poli: copia doppia → `runs = 1`, nessun rilancio;
      `kill -9` sul processo di launchd → **ripartita da sola**, `runs = 2`, pid nuovo.
- [x] **ISC-65** «Applica» nelle preferenze **risponde**: conferma «Preferenze aggiornate» per
      2,5 s e il pulsante è spento finché non cambi qualcosa. — Prima salvava in silenzio, e un
      pulsante che non risponde è indistinguibile da un pulsante rotto.
- [x] **ISC-66** Si possono dichiarare le **pause già fatte** a app chiusa, brevi o piene. —
      Sottomenu dedicato; fa avanzare rotazione e ciclo micro/piena e azzera il conto, ma **non
      accredita ripetizioni**: quante ne hai fatte non lo so, e un registro che se le inventa non
      serve a niente. `testRecordingABreakAdvancesTheCycleAndResetsTheClock`,
      `testRecordingALongBreakResetsTheLongCycle`.
- [x] **ISC-67** Affondi e split squat non sono più due voci in rotazione. — Sono **parenti
      stretti, non gemelli**: nell'affondo il piede si muove a ogni ripetizione, nello split
      squat resta piantato. Averli entrambi in rotazione faceva sembrare l'app ripetitiva senza
      aggiungere niente: lo split squat resta come **variante** dell'affondo, e le due istruzioni
      ora dicono in cosa differiscono. `testSplitSquatIsAVariantOfTheLungeNotASeparateRotationEntry`.

- [x] **ISC-68** `Anti:` dichiarare una pausa passata **non azzera il conto del tempo**. —
      Difetto notato dal principale guardando il timer tornare indietro da 24 minuti: dichiarare
      è *dare un'informazione*, non prendersi una pausa adesso, e il tempo trascorso da allora
      l'orologio l'ha già contato bene. Ora avanzano solo rotazione e ciclo micro/piena.
      Polo negativo **eseguito**: rimettendo `clock.reset()`,
      `testRecordingABreakAdvancesTheCycleButLeavesTheClockAlone` diventa rosso.
- [x] **ISC-69** Partire all'accensione del Mac **non crea tempi morti**. — Il timore era
      ragionevole ma non si applica a questo disegno, e la prova è un test invece di un'opinione:
      venti minuti di Mac acceso con la scrivania vuota lasciano il contatore a **zero** e non
      fanno scattare nessuna pausa (`testStartingAtLoginWithNobodyThereAccumulatesNothing`).
      L'orologio conta l'attività, non l'orologio a muro: è esattamente il motivo per cui
      l'avvio automatico è la scelta giusta.

- [x] **ISC-70** La micro-pausa **dura i 90 secondi che dichiara**. — Incoerenza vera fra
      preferenze e vissuto, notata dal principale al primo uso: 7 dip su sedia sono 18 secondi, e
      una "micro-pausa da 90 secondi" ne durava 18, perché il micro finiva appena l'esercizio era
      fatto. Ora la regola è una sola per entrambe le pause — esercizio **e** durata.
      `testAMicroBreakLastsItsFullDeclaredDuration`; il test del vecchio contratto è stato
      riscritto, non ammorbidito.
- [x] **ISC-71** Esiste un'**uscita d'emergenza** immediata: due Esc, o il pulsante «Emergenza».
      Nessuna frase da digitare. — Contata e segnalata come tale nel registro e nelle statistiche
      (`testEmergencyExitIsImmediateAndRecorded`, `testStatsSeparateEmergencyExitsFromOrdinarySkips`).
      Il prezzo non è l'attrito, è la traccia: un'uscita che non lascia traccia si usa sempre.
      Due Esc e non uno, con innesco che scade in 6 secondi, perché uno solo si preme per sbaglio.
- [x] **ISC-72** Si può **togliere** una pausa segnata a mano. — Caso reale: il principale ne
      segna una, poi la pausa arriva davvero e viene contata due volte. Il registro resta
      append-only: non si cancella una riga, se ne scrive una che la annulla
      (`testUndoRemovesTheDeclaredBreakFromTheCount`, `testUndoOnTheEngineWalksTheCycleBack`).
- [x] **ISC-73** Statistiche per **giorno, settimana e mese**: interruzioni, ripetizioni totali e
      per esercizio, tempo davanti al Mac, bout vigorosi, e la cronologia di quando. — Finestra
      resa e guardata; periodi **di calendario**, non "ultimi 7 giorni". Le uscite d'emergenza
      compaiono in rosso, distinte dalle pause saltate.
- [x] **ISC-74** `Anti:` le statistiche non promettono mai un risultato personale. — Dicono cosa
      hanno **osservato gli studi su numeri come questi**, mai «hai ottenuto». È la promessa su
      cui l'app si regge, e sbagliarla qui costerebbe tutto il resto: il divieto è congelato in
      `testInsightsNeverClaimAPersonalResult`, che fallisce se in un testo compare «hai ottenuto»,
      «hai ridotto», «hai migliorato». Ogni soglia è marcata raggiunta solo quando lo è davvero
      (`testInsightsMarkTheThresholdAsMetOnlyWhenItIs`).

- [x] **ISC-75** Nessun gergo inglese non spiegato nell'interfaccia. — «bout» era gergo da
      articolo scientifico e il principale non sapeva cosa volesse dire. Sostituito con
      **«scatto intenso»**: la metafora è la corsa — non stai facendo una sessione, fai uno
      scatto. Zero occorrenze di «bout» nel sorgente.
- [x] **ISC-76** Dichiarare una pausa fatta chiede **quale esercizio e quante ripetizioni**, e
      quando è successa. — Prima era un clic sul solo tipo e le ripetizioni sparivano proprio dal
      numero che interessa. Pannello dedicato, reso e guardato; la voce «non lo ricordo» registra
      davvero **niente** invece di squat — un registro che si inventa i numeri è peggio di uno vuoto.
- [x] **ISC-77** «Sono già al computer da…» accetta un **numero libero**, non solo i preset. —
      Pannello con campo numerico più le scorciatoie 15/30/45/60/90.

- [x] **ISC-78** «sessioni intense» al posto di «scatto». — Rinomina su tutto il sorgente.
- [x] **ISC-79** `Anti:` una modifica di massa ai testi non può rompere le fonti. — Guasto vero
      di questo giro: il replace cieco «scatto → sessione intensa» ha riscritto anche `about-us`
      **dentro un URL** (`asessione intensa-us`), lasciando un link morto che nessun test vedeva.
      Riparato e chiuso con `SourceUrlTests`: ogni URL è https, senza spazi, senza parole
      italiane finite dentro, e costruibile.
- [x] **ISC-80** Dopo una pausa arriva un **complimento**, non una nota tecnica. — Il messaggio
      diceva «il conto non si tocca»: giusto la prima volta, rumore dalla seconda. Otto frasi che
      girano (`testPraiseRotatesAndNeverRepeatsTwiceInARow`), con parole diverse per la pausa
      dura, e il complimento più pieno va alla pausa **fatta davvero** sotto il blocco, non a
      quella dichiarata.
- [x] **ISC-81** Il report è **scandagliabile a colpo d'occhio**, non una pagina lunga. —
      Quattro numeri col confronto sul periodo precedente, tasso di rispetto, sei schede per
      gruppo muscolare al posto di dieci barre, fascia oraria, e le fonti in fondo. Reso e
      guardato.
- [x] **ISC-82** La cronologia minuto per minuto è **rimossa** (bocciata dal principale: non
      aveva valenza), e al suo posto c'è **«come va nella giornata»** — le pause fatte e saltate
      per ora. È la stessa informazione temporale resa azionabile: se salti sempre alle 15, si
      cambia quell'ora nelle preferenze. `testHourlyBreakdownSeparatesDoneFromMissed`.
- [x] **ISC-83** Il report confronta col **periodo precedente** e mostra il **tasso di rispetto**
      e i giorni di fila. — Un numero da solo non dice niente: 90 ripetizioni sono tante o poche
      dipende da ieri. `testPreviousPeriodIsTheOneBeforeNotTheSame`,
      `testComplianceRateCountsProposedBreaksOnly`.

- [x] **ISC-84** Il conto alla rovescia è **uno solo e parte dall'inizio della pausa**. — Prima
      erano due cronometri diversi nella stessa schermata (prima quello dell'esercizio, poi
      quello del recupero) e nessuno dei due era la pausa. Ora va da 1:30 a 0.
- [x] **ISC-85** La pausa **non si chiude da sola**: a tempo scaduto il pulsante si accende ed è
      il gesto a chiuderla. — `testReturnButtonStaysLockedUntilTheWholeBreakHasElapsed` e
      `testReturnButtonStaysLockedWithoutTheExercise`: né il tempo senza esercizio né l'esercizio
      senza tempo sbloccano il pulsante. Le due reti restano — assenza e tetto assoluto.
- [x] **ISC-86** Il report ha **una sola forma**: una scheda, un raggio, uno stesso respiro
      interno. — Prima era un collage di riquadri con bordi e spaziature diverse: armonia qui non
      vuol dire più bello, vuol dire che l'occhio non ricomincia da capo a ogni blocco. Reso e
      guardato.
- [x] **ISC-87** Il progetto è **salvato e ripartibile a freddo**: `RESUME.md` con comandi,
      stato, cosa manca e le sette trappole già pagate; repo git locale con la storia.

- [x] **ISC-88** «Sono già al computer da…» distingue **«in tutto»** da **«in più»**, accetta un
      numero libero senza tetto, e permette di **abbassare** il conto. — Difetto vero: prima
      prendeva sempre il massimo, quindi una dichiarazione sbagliata all'insù restava lì per
      sempre. `testTotalModeCanCorrectDownwardsWhileAddModeSums` — e il vecchio test, che diceva
      l'opposto, è stato riscritto perché il contratto è cambiato, non ammorbidito.
- [x] **ISC-89** Il **totale di oggi davanti al Mac** è un numero **diverso** dal conto per la
      prossima pausa, ed è correggibile. — È la confusione che ha prodotto il «più di tre ore»
      sbagliato: il conto prende il valore dichiarato, il totale del giorno **somma le righe**.
      Ora sono due sezioni separate con due spiegazioni, e la correzione scrive una **riga
      negativa** invece di riscrivere il registro (`testTheDailyTotalIsCorrectedWithASignedRow`).

### Impacchettamento

- [x] **ISC-25** `Scripts/build-app.sh` produce `Otium.app` avviabile con doppio clic, firmata
      ad-hoc. — script eseguito, bundle aperto e in esecuzione più volte.
- [x] **ISC-26** Un LaunchAgent con `KeepAlive` riavvia l'app se viene uccisa. —
      `--install-agent` → `launchctl print` riporta `state = running` e `program =` il bundle;
      l'app risulta viva dopo l'installazione. Poi **rimosso**: il Mac è stato lasciato com'era.
- [x] **ISC-27** L'app verifica che il LaunchAgent punti al proprio bundle e lo segnala se il
      bersaglio non esiste più. — provato su tre stati reali: `notInstalled`, `danglingTarget(…)`
      con un percorso inesistente, `pointsElsewhere("/bin/echo")`.
- [ ] **ISC-28** `Antecedent:` l'interruzione è accettabile perché breve, prevedibile e motivata.
      **Aperto per costruzione**: è il criterio esperienziale, e si chiude solo con qualche
      giorno d'uso vero. Il falsificatore è semplice — se dopo una settimana il registro mostra
      più `skipped` che `completed`, la cadenza è sbagliata, non tu.
- [x] **ISC-29** `Anti:` l'app non effettua nessuna chiamata di rete. — grep su `Sources/` per
      `URLSession|NSURLConnection|Network\.|CFSocket|socket\(`: zero occorrenze (gli unici
      `https://` sono le stringhe delle citazioni).

### Iterazione 3 — segnalata dall'uso vero (2026-07-27)

Sei difetti e due funzioni chieste dal principale dopo il primo giorno d'uso. Tutti nati
guardando l'app funzionare, non leggendo il codice: è la ragione per cui ISC-28 è esperienziale.

- [x] **ISC-30** Dichiarare il tempo già seduto **mentre l'app è sospesa** non perde il numero
      dichiarato: il conto alla prossima pausa diventa `intervallo − dichiarato`. — riprodotto
      prima di correggere (test rosso: «paused non è working», poi conto a 30 invece che a 10);
      causa in `setPaused(false)`, che azzerava l'orologio **dopo** la dichiarazione. Chiuso da
      due test: quello del caso vero, e quello che protegge il comportamento normale (una ripresa
      senza dichiarazione riparte comunque da zero).
- [x] **ISC-31** Il pulsante grande della pausa si clicca **su tutta la sua superficie**, non solo
      sul testo. — causa: sfondo applicato fuori dal `Button`, area sensibile ridotta alla forma
      del testo. Corretto con `contentShape(Rectangle())` e sfondo dentro l'etichetta.
- [x] **ISC-32** Nessuna finestra dell'app supera l'area visibile dello schermo, e tutte si
      ridimensionano. — misurato con `--window-probe`: le fonti chiedevano **1303 punti** di
      altezza su uno schermo visibile di **888**, ed è per questo che il fondo restava fuori pur
      arrivando in fondo allo scorrimento. Ora la finestra è 640×652 e la sonda risponde
      `STA NELLO SCHERMO`, `ridimensionabile: sì`.
- [x] **ISC-33** Gli esercizi di addome esistono e sono in rotazione. — nove nuovi tipi (crunch,
      sit-up, sollevamento gambe, crunch bicicletta, dead bug, russian twist, plank, plank
      laterale, hollow hold), ognuno con istruzione e alternative; quattro accesi nelle
      preferenze del principale.
- [x] **ISC-34** Gli esercizi **a tempo** dicono secondi, non ripetizioni, e il cancello
      anti-bluff conta di conseguenza. — `isTimed` con `secondsPerRep = 1`; test su tutti e tre:
      etichetta «45 s di plank», tempo minimo pari ai secondi dichiarati.
- [x] **ISC-35** Le preferenze raggruppano gli esercizi per famiglia, con «tutti/nessuno» per
      gruppo. — quattro sezioni (Gambe, Spinta e braccia, Addome, Vigorosi), rese e guardate.
- [x] **ISC-36** La pausa piena **propone** un microcircuito — una stazione per famiglia,
      esplosivo compreso — e resta facoltativo. — 15 test: proposta presente solo nelle pause
      piene, non attiva finché non la scegli, cancello anti-bluff che riparte a ogni stazione
      (provato anche al contrario: rimuovendo il reset, il test diventa rosso), uscita a metà che
      conserva le stazioni fatte, e **una pausa sola nel registro** anche con quattro stazioni.
- [x] **ISC-37** Le frasi sono casuali e non si ripetono per almeno un mese di uso. — mazzo che
      si estrae senza rimettere dentro, persistito su disco, che scarta le frasi tolte da un
      aggiornamento; **489 frasi** contro le 480 di un mese (16 pause al giorno × 30 giorni), test
      che fallisce se qualcuno taglia il corpus. Le frasi senza fonte tracciabile sono ammesse
      come **anonime**, mai attribuite per bellezza: il pool `Quotes` resta a fonte verificata e
      un test vieta le attribuzioni tentennanti.
- [x] **ISC-38** Otium riparte a ogni accensione senza che il principale se ne ricordi. —
      `autoStartAtLogin` acceso di serie, il LaunchAgent si installa da solo al primo avvio e si
      ripara se punta altrove; toglierlo dalle preferenze **spegne anche la preferenza**, così
      l'app non se lo rimette. Verificato: `--agent-status` → `healthy`.

### Iterazione 4 — rifiniture dall'uso (2026-07-27, sera)

- [x] **ISC-39** Gli esercizi che alternano i lati mostrano le ripetizioni **per lato**, e il
      totale resta pari a ogni gradino della rampa. — «6 archer push-up» si leggeva come sei per
      braccio, il doppio del lavoro previsto. Ora «2 archer push-up per lato», con il totale (4)
      nel registro e nel cancello anti-bluff; `Ramp.reps` arrotonda al pari, o al 55% uscirebbe
      «1,5 per lato». Vale anche per affondi, split squat, crunch bicicletta, russian twist e
      plank laterale — che è insieme a tempo e a lati alterni.
- [x] **ISC-40** La notifica che registra la pausa appena chiusa **non suona**. — il suono avvisa
      di ciò che non ti aspetti; l'hai appena chiusa tu con un clic. Il preavviso, che arriva
      mentre fai altro, il suono ce l'ha ancora.
- [x] **ISC-41** Il pannello del menu non elenca più gli esercizi del giorno. — con dieci tipi in
      rotazione la lista cresceva e i nomi lunghi («archer push-up») finivano tagliati contro la
      larghezza fissa. Il dettaglio vive nelle Statistiche. Reso e guardato con `--surface=menu`.
- [x] **ISC-42** In «Dove è andato il lavoro» i gruppi dicono cosa lavora, non il movimento. —
      «spinta» → **petto** (e **spalle** per il pike push-up, che di petto ne fa poco), «tutto il
      corpo» → **total body**. Guardato: gambe 15 · tricipiti 14 · total body 4 · petto 3.

### Iterazione 5 — due segnalazioni dallo schermo (2026-07-27, sera)

- [x] **ISC-43** In «Dove è andato il lavoro» ogni gruppo si apre e mostra **quali** esercizi e
      con quante ripetizioni. — «petto 3» non faceva distinguere tre push-up da tre archer, che
      non sono la stessa giornata. Reso e guardato aperto con `--surface=stats --expanded`:
      gambe → affondi 11 (5 per lato) e squat 8; petto → archer push-up 3 (1 per lato). Gli
      esercizi a tempo dicono i secondi, quelli a lati alterni il per lato.
- [x] **ISC-44** Durante una pausa non compare mai una fonte che dichiara una funzione **assente**.
      — segnalato con una foto dello schermo: a esercizio finito era comparso «Non promesso: una
      funzione deliberatamente assente — regola 20-20-20». Vero, ma risponde a una domanda che
      nessuno fa mentre esegue: la riga sotto il blocco esiste per dire perché ti sto
      interrompendo. Le due voci restano nella finestra delle fonti. Test su 200 pause di fila.

### Iterazione 6 — il recap dice la verità nell'istante in cui lo apri (2026-07-27)

- [x] **ISC-45** Le ripetizioni finiscono nel registro **quando confermi l'esercizio**, non alla
      chiusura della pausa. — prima si scrivevano al «Torna al lavoro», cioè fino a cinque minuti
      dopo averle eseguite: il recap aperto nel frattempo non le vedeva. Ora la conferma emette
      `exerciseConfirmed` e scrive la sua riga `exerciseDone`; la riga della pausa conserva il
      nome dell'esercizio ma **non** le ripetizioni, o sarebbero contate due volte. Le righe
      scritte prima hanno le ripetizioni sulla riga della pausa e continuano a contare.
- [x] **ISC-46** Aprire il recap o il menu **scrive** il tempo attivo non ancora registrato. — il
      tempo si accumula a blocchi di cinque minuti (3.600 righe l'ora sarebbero insostenibili),
      e il prezzo era un numero vecchio fino a cinque minuti proprio mentre lo guardavi. Ora
      `flushForDisplay()` paga la scrittura una volta, quando apri.

### Iterazione 7 — quello che si vede all'apertura (2026-07-27)

- [x] **ISC-47** La finestra delle statistiche mostra i numeri di **adesso** nell'istante in cui
      si apre. — riaprendola compariva per un attimo il disegno di quando l'avevi chiusa, poi si
      aggiornava sotto gli occhi al primo battito: una finestra nascosta non ridisegna. Ora il
      contenuto si ricostruisce a ogni apertura, dopo lo svuotamento del tempo; il periodo scelto
      è passato dalla vista al modello, o la ricostruzione lo riporterebbe su «Oggi» ogni volta.
- [x] **ISC-48** Nelle finestre normali l'accento segue l'aspetto del sistema. — in modalità
      scura si vedeva `accentOnLight`, cioè il verde **nato per la carta bianca**: su fondo scuro
      diventava fango. La palette aveva già la tinta per il buio — è quella della schermata di
      blocco — e non veniva mai usata. Reso e guardato nelle tre livree in scuro.

### Iterazione 8 — la livrea arriva fino in fondo (2026-07-27)

- [x] **ISC-49** Le livree si possono guardare in chiaro **e** in scuro senza cambiare le
      impostazioni del Mac. — il render aveva solo `--dark`, e senza quel flag ereditava
      l'aspetto vivo del sistema: rese di sera, le sei immagini uscivano tutte scure e sembravano
      identiche. Aggiunto `--light`. Dentro c'era un secondo difetto, `.cgColor` risolve un
      colore dinamico contro l'aspetto **corrente del thread**, non contro quello messo su
      `NSApp`, quindi lo sfondo della finestra restava quello del buio anche in chiaro.
- [x] **ISC-50** Il selettore Oggi/Settimana/Mese porta il colore della livrea. — con
      `.pickerStyle(.segmented)` il controllo prende l'accento **del Mac**, non quello dell'app:
      restava blu in tutte e tre le livree, l'unico pezzo della finestra fuori dal tema. Riscritto
      a mano con pulsanti veri, non testo cliccabile, per non perdere tastiera e VoiceOver. Il
      testo sopra il riempimento non è sempre bianco: in chiaro l'accento è verde bosco e vuole
      bianco, in scuro è salvia chiara e vuole il verde notte del fondo.
- **Livrea scelta dal principale: Alloro**, le sfumature verdi. Era già la predefinita, ora è
  anche una decisione presa guardando le tre in entrambi gli aspetti.

### Iterazione 9 — la notte che contava senza nessuno (2026-07-28)

- [x] **ISC-51** Un risveglio del Mac non è un'interruzione della sedentarietà. — con il coperchio
      chiuso macOS si sveglia da solo ogni quarto d'ora, e l'orologio restituiva quel salto come
      pausa spontanea: fra le 23:33 del 27 e le 10:27 del 28 il registro ha scritto **47
      interruzioni** con nessuno davanti allo schermo. La sospensione ora è un evento suo
      (`ClockEvent.suspended`) e il motore decide invece di ereditare. Il tempo attivo era rimasto
      onesto per tutta la notte, ed è la prova che il difetto stava solo in quel ramo.
- [x] **ISC-52** Una pausa spontanea vale solo dopo della sedentarietà vera. — cinque minuti di
      tempo attivo accumulato, sotto i quali un'assenza non viene scritta. Serve a due cose: tiene
      in piedi il caso legittimo (lavori, chiudi il Mac, vai a camminare, e quella pausa resta
      tua) e chiude lo stesso buco sul ramo di tutti i giorni, dove un'assenza veniva accreditata
      senza guardare se prima ci fosse stato del lavoro. È anche ciò che il numero *dice*: Duran
      misura l'interruzione di una seduta prolungata.
- [x] **ISC-53** Lo scarto della notifica segue l'inerzia del gesto. — la decisione stava su
      `.ended`, l'istante in cui alzi le dita, e gli eventi di spinta che il sistema manda **dopo**
      finivano in un ramo che li scartava. Un colpetto veloce muoveva la notifica e la vedeva
      tornare indietro. Provato con `Scripts/probe-swipe.swift` su tre poli: controllo di
      consegna, codice nuovo, codice di HEAD.
- **Dati corretti, non riscritti.** Le 47 righe fantasma sono state tolte dal registro dopo averlo
  archiviato in `ledger.jsonl.pre-fix-20260728`. Il recap di oggi torna a 0 interruzioni.

### Iterazione 10 — le citazioni, e le parole a schermo (2026-07-28)

- [x] **ISC-54** Nel pool firmato non c'è nessuna citazione inventata. — aperta da un errore visto
      a schermo dal principale, «toglie il giudizio» invece di «togli» (Pensieri IV, 7 è un
      imperativo). Rilette tutte e 126 e tolte cinque attribuzioni false o non collocabili
      (Musashi ×2, Schopenhauer, Goethe, Dalai Lama) più cinque doppioni. Aggiunte quattro
      verificate su fonte in sessione. **Il corpus era sceso a 478 e la guardia del mese senza
      ripetizioni è diventata rossa da sola**: è la prova che quel test misura qualcosa.
- [x] **ISC-55** I numeri a schermo concordano con le parole. — «1 interruzioni», «1 fatte»,
      «1 minuti di movimento». In italiano lo zero vuole il plurale e l'uno il singolare, e uno
      sbaglio così fa sembrare fatta male anche la parte fatta bene.
- [x] **ISC-56** Con poche ore attive la striscia resta una striscia. — con una sola ora la barra
      si allargava per tutta la scheda e si leggeva come un blocco pieno, cioè come un errore.

### Iterazione 11 — lo schermo nero senza uscita (2026-07-28)

Il guasto più grave che l'app abbia prodotto: due volte, il 27 e il 28 luglio, ha lasciato il Mac
inchiodato su un rettangolo nero da cui si esce solo col tasto di accensione. Entrambe le volte
attribuito ad altro — la sera del 27 alle AI locali in esecuzione — finché il registro non ha detto
la stessa cosa due volte, con i secondi esatti della soglia d'assenza.

- [x] **ISC-57** Una pausa chiusa **dal motore** libera sempre lo schermo. — dei sei modi di finire
      una pausa, `.naturalBreak` era l'unico il cui gestore non chiamava `blocker.hide()`. Il motore
      tornava a `working` con `plan` a nil, la vista senza piano non disegnava niente, e restava a
      schermo intero un nero a livello di schermatura con ⌘-Tab, uscita forzata e chiusura di
      sessione ancora disabilitate. La cura non è aggiungere il caso mancante — sarebbe la stessa
      architettura con un buco in meno — ma `AppModel.reconcileBlocker()`, che dopo ogni giro di
      eventi libera lo schermo se la fase non è `.breaking`. *Falsificatore:* `--orphan-probe`, che
      apre un blocco vero, alza l'inattività oltre la soglia d'assenza e misura finestre e opzioni
      chiosco. **Rosso sul codice di prima** (1 finestra, chiosco 490), verde su questo.
- [x] **ISC-58** Ogni rete regge **da sola**. — tre reti in tre strati (modello, finestra, vista)
      provate tutte insieme dimostrerebbero solo che almeno una funziona, cioè quello che già
      sapevamo. `--senza-rete-modello` spegne la riconciliazione: il battito da 2 s di
      `BlockerController`, che prima di rimettersi davanti si chiede se la sua pausa esiste ancora,
      libera lo schermo lo stesso. *Falsificatore e controllo negativo:* `--senza-reti` deve
      **riprodurre il guasto**, o le reti non stanno reggendo niente. Riprodotto: 1 finestra,
      chiosco 490.
- [x] **ISC-59** L'uscita d'emergenza non dipende dal motore. — `engine.emergencyExit()` è guardata
      da `phase == .breaking || .warning`: a scudo orfano restituiva una lista vuota e i due Esc
      non facevano niente, proprio nello stato in cui sono l'unica cosa che resta. Ora, quando non
      c'è niente da chiudere, lo scudo si smonta comunque. *Falsificatore:* dentro `--senza-reti`,
      subito dopo il controllo negativo, `emergencyExit()` deve portare finestre e chiosco a zero.
- [x] **ISC-60** Mentre il Mac dorme o lo schermo è bloccato, lo scudo si ritira — e torna. — non è
      la causa di questi due episodi, è la stessa ferita un passo più in là: una finestra a livello
      di schermatura che ogni due secondi riattiva l'app mentre la schermata di accesso possiede lo
      schermo. *Falsificatore:* `--sleep-probe` — a schermo bloccato finestre 0 e chiosco 0, **ma
      fase ancora `breaking`**, perché sospendere non è condonare; allo sblocco finestre 1 e chiosco
      490. Sollecitato con le notifiche vere di sistema postate a mano: prova la mia logica di
      sospensione, non che macOS le mandi (quello è comportamento documentato del sistema).
- [x] **ISC-61** La schermata senza piano non è un nero muto. — terza rete, e la più semplice:
      l'`if let plan` senza `else` disegnava esattamente niente, e un nero che non dice cosa sia
      non si distingue da un Mac morto. Ora dice cosa sta succedendo e porta il pulsante grande,
      non quello discreto: questa è l'ultima uscita prima del tasto di accensione.
      *Falsificatore:* `--snapshot --orfana`, resa e **guardata**.
- **Anti-claim** — la cura non deve poter sciogliere una pausa vera. La riconciliazione vale in una
  direzione sola («non sto bloccando → libera»); «sto bloccando → copri» resta compito di
  `.breakStarted`. *Provato:* in tutte e quattro le sonde lo scudo si apre e resta finché la fase è
  `.breaking`, e al blocco schermo la pausa sopravvive alla sospensione.

### Iterazione 12 — il battito, il menu che prometteva, e la sonda che cambiava la macchina (2026-07-28)

- [x] **ISC-62** Il radar si guarda intorno ogni 3 secondi, e ogni secondo solo dove serve. — la
      parte cara del battito è l'app in primo piano, l'audio e il documento aperto; il resto è
      aritmetica. Tre secondi non tolgono niente, perché i tetti della presenza si misurano in
      minuti (45 e 15). Nel **preavviso** si torna a ogni secondo: lì il valore non è contabilità,
      decide se la pausa parte o si rimanda perché sei al telefono. *Falsificatore:* `--radar-probe`
      conta le interrogazioni vere, e il preavviso fa da polo di controllo dentro la sonda stessa —
      se il rallentamento non funzionasse le due fasi darebbero lo stesso ritmo. Misurato: **0,33/s
      lavorando contro 0,80/s nel preavviso, il 67% di interrogazioni in meno.**
- [x] **ISC-63** Il menu non promette scorciatoie che l'app non ha. — accanto a «Statistiche…» c'era
      **⌘S**, che è il tasto di Salva ovunque, e il principale se l'è trovato addosso in un'altra
      app. Ma quella combinazione non poteva funzionare fuori dal menu aperto: questo non è il menu
      principale (`NSApp.mainMenu` è **nessuno**, misurato) e l'app non registra nessun tasto
      globale (nessun `RegisterEventHotKey`, nessun monitor, verificato sul sorgente). Restano
      lettere nude, che a menu aperto funzionano davvero. ⌘Q su «Esci» resta, perché lì il simbolo
      non si legge come una promessa ma come «questa è la voce che chiude».
      *Falsificatore:* `--menu-probe`, che boccia qualunque voce con ⌘ diversa dall'uscita.
- [x] **ISC-64** La notifica non taglia le parole. — «prossima pausa fra 30 min di lavoro att…», e
      la parola tagliata era proprio quella che distingue il tempo di lavoro vero dall'orologio a
      muro. Segnalato dal principale guardandola. Accorciare la frase avrebbe curato questa e
      lasciato in piedi la prossima: ora è il pannello a cedere, l'altezza la detta il contenuto e
      il testo va a capo fino a tre righe. *Falsificatore:* `--snapshot --surface=hud [--testo=…]`,
      resa e **guardata** a due lunghezze — la frase vera sta in una riga (84 punti), una più lunga
      va a capo e il pannello cresce a 87. Nessuna delle due ha puntini.
- [x] **ISC-65** Una sonda non tocca la macchina che sta misurando. — trovato **causandolo**:
      `applyAutoStartPreference()` reinstalla l'avvio automatico quando punta a un'altra copia
      dell'app, e le mie sonde su `.build/debug/OtiumApp` hanno riscritto l'avvio automatico del
      principale dal bundle al binario di sviluppo, che ogni `swift build` sovrascrive. Al login
      sarebbe partita una copia di lavoro, in silenzio. Due cure: `ProbeMode` (l'avvio automatico
      non si tocca mai da una sonda) e `Paths.overrideDirectory`, che manda registro, rotazione,
      mazzi, preferenze **e il lock dell'istanza unica** in una cartella usa e getta.
      *Falsificatore:* `rotation.json` invariato al bit dopo una sonda, con l'app vera in esecuzione.
      Effetto collaterale utile: le sonde ora girano **mentre l'app lavora**, non serve più fermarla.
- **Anti-claim** — il rallentamento non deve rendere l'app cieca nel momento in cui decide. Il
  preavviso resta a ritmo pieno, e la sonda lo misura invece di dichiararlo.

### Iterazione 13 — ⌃S vero, e la caccia ai bug della stessa famiglia (2026-07-28)

- [x] **ISC-66** ⌃S apre le statistiche **da qualunque app**, senza chiedere permessi. — la via
      moderna (`NSEvent.addGlobalMonitorForEvents`) pretende il Monitoraggio input, cioè il
      permesso che l'app ha promesso di non chiedere; `RegisterEventHotKey` non chiede niente.
      Prezzo dichiarato e non nascosto: ⌃S smette di arrivare alle altre app, quindi niente XOFF
      nei terminali e niente ricerca incrementale in Emacs. Si cambia da una costante sola.
      *Falsificatore, e questa volta serve davvero end-to-end:* registrare non basta, il sistema
      deve **consegnare** il tasto. Con Finder in primo piano, ⌃S sintetizzato ha fatto comparire
      una finestra di Otium da 640×712 che prima non c'era. `--hotkey-probe` copre l'altro pezzo,
      cioè che il ponte con Carbon sia cablato.
- [x] **ISC-67** Il motore regge sequenze che nessuno ha immaginato. — 40 semi × 400 passi con
      tutte le azioni umane in ordine casuale, invarianti controllati **dopo ogni passo**. Il più
      importante è quello del guasto: fuori da una pausa non esiste un piano, perché l'interfaccia
      disegna leggendo il piano. *Falsificatore a tre livelli:* il fuzz è verde; la copertura
      pretende di aver visitato **tutte** le fasi, o sarebbe verde senza aver provato niente; e
      sabotando `finish()` perché non azzeri il piano il fuzz **diventa rosso al primo seme**, con
      la sequenza esatta che lo riproduce. Un test mai visto fallire è un'asserzione travestita.
- [x] **ISC-68** Chiudere una finestra riporta Otium nella barra dei menu. — trovato cercando, non
      usando: `present(_:)` metteva l'app nel Dock (`.regular`) e nessuno la rimetteva mai in
      `.accessory`. Bastava aprire le preferenze una volta e Otium restava per sempre nel Dock con
      la sua barra dei menu, smettendo di essere l'app di barra di stato che `LSUIElement` dichiara.
      *Falsificatore:* `--policy-probe`, **rosso prima** (`accessory → regular → regular`) e verde
      dopo (`accessory → regular → accessory`).
- [x] **ISC-69** Sospesa, l'app non interroga il sistema. — mentre è in pausa il motore ignora la
      risposta del radar, quindi chiederla è lavoro puro, e su un portatile il lavoro puro è
      batteria.
- **Anti-claim** — una scorciatoia globale non deve rubare un tasto in silenzio. Il prezzo è
  scritto in `GlobalHotKey`, e se il tasto è già di un'altra app l'avvio lo dice invece di fingere
  che vada — che è esattamente il difetto che ⌘S aveva.

**Aperto, non fatto:** la livrea tocca solo il recap. Preferenze, dichiarazione e i loro interruttori
usano ancora l'accento di sistema, quindi blu. E in cima alle Preferenze c'è una fascia vuota di
circa 120 punti da sondare.

### Iterazione 14 — l'audit, prima metà (2026-07-28/29)

Quattro assi su cinque, tenuti fuori dai file dell'altra sessione. **Otto difetti**, e nessuno
sarebbe emerso dall'uso: sette fallivano in silenzio e uno solo in modo visibile.

- [x] **ISC-70** Le promesse di privacy reggono dopo tutto quello che è stato aggiunto. — nessuna
      chiamata di rete, nessuna API che chieda permessi, nessun entitlement, e il nome del
      documento che stai leggendo non finisce mai nel registro. *Falsificatore:* grep sulle
      famiglie di API più `codesign -d --entitlements`.
- [x] **ISC-71** Lavorando, l'app non lancia processi esterni. — `lsof` costava 31 ms e 0,03 s di
      CPU ogni 8 secondi con un'app da lettura davanti, cioè circa lo 0,4% di un core contro lo
      0,13% dell'app intera, e serviva solo alla riga mostrata nella schermata di blocco. Ora si
      chiede nel preavviso. *Falsificatore:* `--lsof-probe` conta i lanci veri, e prima di credere
      allo zero chiama `lsof` a mano per verificare che il contatore sappia contare.
- [x] **ISC-72** Il registro non si può perdere per un permesso. — **il difetto peggiore
      dell'audit**: con il file non scrivibile, `append` non falliva, *riusciva* — il ripiego
      atomico rinomina un file nuovo sopra il vecchio, e il permesso che conta è quello della
      cartella. Mesi di storia sostituiti da una riga sola, con `append` che restituiva `true`.
      *Falsificatore:* `DurabilityTests`, file a 0444, si pretende `false` **e** che le righe
      precedenti siano ancora lì.
- [x] **ISC-73** Una riga rotta non porta via il resto e non sparisce in silenzio. — saltarla è
      giusto, non contarla no: le statistiche uscivano più basse del vero senza dirlo.
- [x] **ISC-74** I numeri mostrati raccontano il registro. — tre difetti: togliere una pausa
      segnata lasciava dentro le sue ripetizioni; la serie dei giorni ignorava le pause naturali,
      cioè spezzava la serie a chi si alza da solo, che è il comportamento che l'app dice di
      premiare; e il tempo davanti al Mac poteva andare sotto zero.
- [x] **ISC-75** La suite non dipende dall'ora del giorno. — nove test costruivano i timestamp
      rispetto a `Date()` e li leggevano dentro la finestra del giorno: dopo la mezzanotte
      diventavano rossi. Diciassette rossi comparsi da soli a metà audit, che per un attimo ho
      creduto miei.
- [x] **ISC-76** Il fuzz copre anche la progressione, e la copre davvero. — due incoerenze
      trovate (sospendere e rinviare lasciavano «esercizio fatto» senza pausa) più un bluff
      possibile («nove su dieci» un istante dopo l'inizio). *Falsificatore, e la parte che conta:*
      sabotando il pavimento del livello il fuzz restava **verde**, perché non arrivava mai in
      quello stato — mancava la mossa più umana, aspettare. Aggiunta, la stessa sabotatura produce
      776 rossi.
- **Anti-claim** — l'audit non doveva toccare i file dell'altra sessione. `Quotes.swift`,
  `Mindful.swift` e `Phrases.swift` non sono stati aperti, e `Views.swift` solo dove serviva.

### Iterazione 15 — l'audit, seconda parte (2026-07-29)

- [x] **ISC-77** La livrea regge la soglia di leggibilità su ogni tema. — WCAG AA, calcolata e non
      guardata. I tre temi passano con margine (il peggiore 5,67:1 contro 4,5), ma **cinque punti
      di testo stendevano un'opacità su `dim`**, che è già il colore più tenue leggibile: al 55%
      scendeva a 2,67:1, e sempre su testo da 11 punti. *Falsificatore:* `ContrastTests` calcola i
      rapporti, pretende che l'opacità sul secondario **fallisca** (se passasse, la regola non
      servirebbe) e scansiona i sorgenti perché il difetto non torni.
- [x] **ISC-78** Un file di impostazioni scritto a mano non rompe l'app. — le validazioni vivevano
      solo nell'`init`, quindi l'assegnazione e **la decodifica** le scavalcavano: con
      `rampStartFactor: -5` le ripetizioni diventavano negative, con `exercisePool: []` la
      rotazione restava senza esercizi. *Falsificatore:* sedici configurazioni assurde guidate per
      duecento passi ciascuna, nessun NaN e nessun giro a vuoto.
- [x] **ISC-79** Viaggiare non rompe i conti. — nessun difetto trovato, ed è la notizia buona: la
      salita non salta né torna indietro attraversando i giorni da 23 e 25 ore, il registro tiene
      istanti assoluti, e le statistiche seguono il calendario che gli passi invece di uno cablato.
- [x] **ISC-80** Nessun controllo parla per sola icona. — i due tondi «+» e «−» del pannello delle
      ripetizioni erano, per VoiceOver, due pulsanti identici senza nome.

- [x] **ISC-81** Nessuna stringa visibile resta in una lingua sola. — sedici trovate: nove nei due
      pannelli di dichiarazione, quattro nelle intestazioni delle statistiche, una nella riga dello
      studio sotto il blocco. Tutte in superfici che si aprono di rado, che è il posto dove una
      traduzione mancante sopravvive per mesi — chi apre le statistiche una volta a settimana non
      segnala, si abitua. *Falsificatore:* `NoUntranslatedStringsTests` scansiona i sorgenti,
      riconosce l'italiano per parole e accenti, guarda solo le righe che finiscono a schermo, e
      dichiara per nome le due stringhe di sonda ammesse. Provato al polo opposto rimettendo una
      `Section` non tradotta.

### Iterazione 16 — il doctor (2026-07-29)

- [x] **ISC-82** L'app sa dire cosa è rotto e come si aggiusta. — `Otium --doctor` e la voce
      Diagnostica del menu, che condividono lo stesso `Doctor.report()` così non possono
      raccontare cose diverse. Undici controlli, esce 1 se un controllo **obbligatorio** fallisce;
      gli stati (avvio automatico assente, primo avvio non fatto, crescita spenta) si riportano e
      non fanno mai fallire, perché sono scelte e non guasti. Autonomo per costruzione: legge il
      disco, non tocca `AppModel`, e **non passa da `ProbeMode`** — guarderebbe una cartella usa e
      getta e direbbe che va tutto bene guardando altrove.
      *Falsificatore, ai due poli sui difetti che l'hanno fatto nascere:* avvio automatico
      dirottato dentro `.build/` → rosso, `exit 1`, con la riga da premere; registro a 444 → rosso,
      `exit 1`; ripristinati entrambi → verde.
      *Dead end pagato:* il primo controllo dell'avvio automatico chiedeva «punta a me?» invece di
      «punta a qualcosa che regge?», e dal terminale dava rosso su un'installazione sana. Terza
      volta nella stessa giornata che una sonda risponde a una domanda più debole di quella fatta.

**L'audit è chiuso.** Sedici difetti in tutto, tredici dei quali fallivano in silenzio, e nessuno
sarebbe emerso dall'uso. Quattro li ha trovati un test che prima non esisteva, due il fuzz, uno la
guardia di un'altra sessione, e uno l'ho causato io stesso sondando.

### Iterazione 17 — la lingua che non arrivava in fondo, e la frase persa (2026-07-29)

Due segnalazioni dallo stesso schermo, alla fine di una pausa da cinque minuti con l'app in
inglese: il complimento finale era in italiano, e la citazione «lì sembra persa».

- [x] **ISC-83** Nessuna stringa a schermo esce nella lingua sbagliata. — Il difetto visto era
      `Praise`, cioè le 22 righe di complimento, **solo italiane**: non una traduzione dimenticata
      ma una *forma* sbagliata, perché una riga lì era un dato di un `enum` e non una `Text` in una
      vista, e nessuno cerca le stringhe da tradurre dentro i dati. Ora la coppia `(it, en)` è il
      tipo: aggiungerne una senza inglese non compila. Sondando il resto ne sono uscite altre
      dodici della stessa specie — `StatsPeriod`, «sospesa», «apri l'articolo», «Suono del
      preavviso», «nessuno», «Frase per saltare», «Ore attive», «ieri/prima», «minuti», e i tre
      pulsanti «Applica / Correggi / Chiudi» che nessuno dei miei grep aveva visto.
      `SeatedMode.title` era codice morto e l'ho tolto invece di tradurlo.
      *La rete, che è il punto:* `LanguageLintTests` legge il **sorgente** e boccia ogni testo
      dentro `Text`/`Button`/`Label`/`Picker`/`Stepper`/`LabeledContent`/`Link`/`title:` che non
      passi da `L.t`. Le eccezioni si dichiarano accanto alla riga con `// lingua: ok <motivo>` —
      il nome dell'app, le sonde di sviluppo, il nome di un suono — perché una lista di eccezioni
      in fondo a un test è un posto dove le eccezioni invecchiano senza che nessuno se ne accorga.
      *Falsificatore ai due poli:* `testTheLintActuallyCatchesAnUntranslatedLine` gli dà la riga
      esatta che il principale ha visto (deve bocciarla), la stessa tradotta (deve promuoverla) e
      una esentata (deve ignorarla). Più il conteggio delle righe lette: sotto le 5.000 il verde
      vorrebbe dire «non ho guardato», non «tutto tradotto».
      *Prova che era rosso:* il primo giro ha stampato 11 rilievi, tre dei quali difetti veri che i
      miei `grep` sull'italiano avevano mancato perché erano parole singole senza accenti.

- [x] **ISC-84** Dentro la pausa la frase non è una didascalia. — La schermata era **una colonna di
      dodici blocchi**, quasi tutti grigi fra gli 11 e i 17 punti, e la citazione era il settimo,
      schiacciata fra l'elenco del microcircuito e il cronometro. Ora la pausa ha due facce, sulla
      `exerciseDone` che il motore già conosceva: finché devi muoverti la pagina parla solo
      dell'esercizio; premuto «Fatte tutte», la frase prende la pagina a 40 punti di grazie su
      nero, con la conferma di quello che hai fatto in alto e il conto alla rovescia sotto.
      **I tre minuti e mezzo che riempie erano una schermata ferma con un pulsante spento.**
      *Falsificatore misurato, non stimato:* `--surface=provino --riposo --misura` disegna
      `RestQuote`, cioè **la stessa vista** che si vede nella pausa, e stampa l'altezza di tutte e
      492 le frasi. La più alta è 171 punti in italiano e 171 in inglese, contro i ~580 disponibili
      fra intestazione e comandi: la soglia dei 95 caratteri che scende da 40 a 30 punti regge.
      *Rete sul caso limite:* mazzo illeggibile → la fase di riposo dice comunque qualcosa. Uno
      schermo nero muto è la ferita del 27-28 luglio e non si ripete.

- [x] **ISC-85** Dalla fase di riposo si esce come dalla prima. — Richiesta esplicita del
      principale. I tre pulsanti e il doppio Esc vivono fuori dal ramo che distingue le due facce,
      quindi ci sono in entrambe.
      *Falsificatore:* `testEmergencyExitStillWorksAfterTheExerciseIsDone` — esercizio confermato,
      poi `emergencyExit()` deve produrre eventi e togliere la fase da `.breaking`. I pulsanti li
      ho guardati nei pixel, ma «ci sono» e «premerli funziona» sono due affermazioni diverse, e la
      seconda è quella che conta nel momento in cui ti serve uscire.

- [x] **ISC-86** L'onboarding dice cosa fa l'app, perché, e come si esce. — Il blocco «Perché:
      <studio>» in fondo alla pausa occupava tre righe di grigio e rubava il ruolo alla frase: due
      testi da leggere sulla stessa pagina, e vinceva il più lungo. Nella pausa resta la **mini
      frase** — cosa governa quello studio, con chi lo firma, su una riga — e solo mentre devi
      muoverti; le ragioni per esteso le dice l'onboarding una volta, con calma, insieme all'uscita
      d'emergenza. **Il doppio Esc sta lì perché scoprire come si esce mentre ti serve uscire è
      troppo tardi.**
      *Vincolo di costruzione:* le tre righe del «perché» le scrivono gli `Study`, non io — una
      copia a mano invecchierebbe separata dalla fonte — e i numeri della cadenza vengono dalle
      impostazioni vere.
      *Rischio dichiarato e accettato dal principale:* chi salta l'onboarding non legge mai le
      ragioni. Mitigazione: nella pausa resta la riga che dice dove trovarle.
      *Dead end pagato:* avevo messo il grassetto markdown dentro le stringhe. Arrivano a `Text`
      come `String` interpolata e non come letterale, quindi il markdown non viene interpretato e
      gli asterischi si vedono a schermo — lo stesso difetto già pagato nei fatti, ripetuto.

**L'audit cross-vendor ha girato quattro volte, e undici rilievi su dodici erano veri.** Nessuno
sull'app: tutti sulla **guardia**, cioè sulla cosa che deve impedire il ritorno del difetto. Il più
importante è arrivato al secondo giro e diceva la cosa più scomoda possibile — *il lettore non
prende la classe di difetti che dichiara di prendere* — perché guardava le viste, e il difetto
segnalato dal principale viveva in un `enum`. Da lì: la ricerca di prosa italiana su tutto
`Sources`, `Praise` traslocato in un file suo perché la guardia potesse vederlo, e il test negativo
che gli dà in pasto il testo com'era davvero. Tre giri dopo, la classe era diventata **22 righe di
complimento più 70 punti bilingui**, e più di metà li aveva trovati il lettore invece dei miei
`grep`: le quattro schede delle statistiche, le tre livree, il suggerimento della barra dei menu,
le targhette con le loro parole al plurale.

Il dodicesimo rilievo era **falso** — diceva che la resa della fase di riposo sporca il registro
vero, e non è così perché `--snapshot` passa da `ProbeMode`, che devia i percorsi su una cartella
temporanea prima che nasca qualunque modello. Sondato nel sorgente prima di rispondere: un rilievo
di un agente delegato è a fonte singola, anche quando ha ragione undici volte su dodici.

*Dove ci si è fermati, e perché:* dal terzo giro in poi i rilievi riguardano solo casi limite del
lettore lessicale, e un parser scritto a mano ne ha sempre uno in più. Il caso patologico — testo
composto a pezzi da più variabili — resta **scritto dentro il test** invece che risolto: risolverlo
vorrebbe dire SwiftSyntax, cioè una dipendenza su un'app che non ne ha nessuna, e quella è una
decisione del principale.

### Iterazione 18 — quello che avevo verificato non era quello che lui usava (2026-07-30)

> **Nota sulla numerazione, scoperta scrivendo questa iterazione.** Gli identificativi in questo
> file **non sono unici**: l'intervallo ISC-30…ISC-88 compare due volte, perché il blocco dei
> criteri iniziali e quello delle iterazioni sono stati numerati ognuno per conto suo. Le due
> voci qui sotto partono da 90, oltre il massimo vero (89). Anche le ISC-83…86 dell'iterazione 17
> collidono con la prima serie: non le rinumero, perché sono già citate altrove e cambiarle
> romperebbe i riferimenti — ma **un ISC non basta a identificare un criterio in questo file**,
> serve anche l'iterazione.


- [x] **ISC-90** Le due fasi arrivano nell'app che gira davvero. — Il 30/07 il principale ha fatto
      una pausa e ha visto **la schermata vecchia**. Non era un difetto del codice: il codice era
      giusto. Avevo verificato tutto con `--snapshot` sul **binario di debug**, e non ho mai
      lanciato `Scripts/build-app.sh`: l'app che lui usa è `dist/Otium.app`, ferma alle 10:54 del
      29 luglio, cioè a prima di tutto il lavoro. Sondato: `ps` dice quale binario gira, `ls -la`
      da quando.
      *La lezione, che è la stessa già scritta due volte in questo file con parole diverse:* **la
      sonda deve rispondere alla domanda che hai fatto.** «La schermata nuova è disegnata bene?» e
      «la schermata nuova è quella che vedi tu?» sono due domande, e per un pomeriggio di rese ho
      risposto solo alla prima. Un binario di debug verde è indistinguibile da un'app aggiornata
      finché non guardi la data del bundle.
      *Chiuso:* bundle ricostruito, resa delle due fasi rifatta **dal bundle** e guardata, app
      chiusa con un `quit` pulito (che passa da `applicationWillTerminate` → `model.stop()`,
      quindi scarica il tempo attivo invece di perderlo) e riaperta. `--doctor`: undici controlli
      verdi, istanza unica, avvio automatico che punta a questa copia.

- [x] **ISC-91** Nessuna riga esce mezza in una lingua e mezza nell'altra. — Sempre dal suo
      screenshot: *«still, on a document: documento aperto in Microsoft Word»*. Il prefisso passava
      da `L.t`, il seguito no — arrivava da `PresenceClassifier`, e la stessa frase esisteva
      **due volte**, in `Presence.swift` e in `SystemProbes.swift`. Tradotte entrambe, più «video
      in riproduzione», «audio in riproduzione» e «pagina web».
      *Perché la guardia non l'aveva vista, e cosa è cambiato:* il rilevatore di prosa chiedeva
      **due** parole comuni nella stessa stringa, e «documento aperto in ￼» ne ha una sola. Ora
      esistono le **spie forti** — parole che l'inglese non ha, come «riproduzione», «documento»,
      «sedentarietà» — e ne basta una. Rinforzato il rilevatore, sono uscite subito le altre tre
      righe di `Presence.swift`, un file che non avevo nemmeno guardato.
      *Falsificatore:* due casi negativi con le righe esatte che il principale ha letto a schermo.


### Iterazione 19 — l'armonia fra le due facce, e la dissolvenza (2026-07-30)

- [x] **ISC-92** Il pulsante dice dove ti porta, non che ora è. — Nella fase di riposo il
      cronometro diceva 2:11 e il pulsante spento sotto «2:11 left»: lo stesso numero due volte a
      dodici punti di distanza. Segnalato dal principale con la soluzione già dentro la domanda.
      Ora l'etichetta resta ferma sulla destinazione ed è lo stato spento a dire «non ancora».
      Nell'esercizio il numero non era un doppione — l'orologio conta la pausa, quello contava il
      minimo di movimento — quindi è sceso sotto il pulsante e dice anche perché stai aspettando.
      *Dead end pagato:* il primo pulsante aveva misura fissa, e l'etichetta lunga usciva dal
      rettangolo finendo sopra la linea del piede. La causa vera era che ripeteva il nome
      dell'esercizio, che sta a 44 punti trenta righe più su.

- [x] **ISC-93** Le due facce condividono lo scheletro. — Il blocco in basso cambiava altezza fra
      esercizio e riposo, perché l'istruzione del riposo c'è solo in una e il «Perché» solo
      nell'altra: cronometro, barra, pulsante e uscite saltavano nell'istante della transizione.
      Ora quelle righe stanno in **tre fessure ad altezza fissa** che tengono il loro spazio anche
      da vuote.
      *Falsificatore misurato:* uno script legge le rese e trova la linea del piede riga per riga
      nei pixel. Micro-pausa: **0 punti di scarto**. Pausa piena col microcircuito: **7 punti**,
      perché lì il contenuto eccede l'altezza disponibile e la colonna si assesta più in basso.
      Resta aperto per scelta: chiuderlo vuol dire togliere qualcosa dal blocco dell'esercizio, e
      quella è una decisione di contenuto.
      *Costo pagato due volte:* ogni fessura aggiunta ha riportato la pausa piena oltre gli 804
      punti disponibili a 1440×900, e ogni volta è servito recuperare spazio da molle e spaziature.

- [x] **ISC-94** Il passaggio all'esercizio fatto è una dissolvenza, non un taglio netto. — Le due
      facce si scambiano dentro la stessa `ZStack` con `.transition(.opacity)`, 0,6 secondi, con
      dieci punti di scorrimento in senso opposto. L'animazione è legata alla sola `exerciseDone`,
      così il cronometro che cambia ogni secondo non si trascina dietro niente.
      *Verificato dal principale, non da me, ed è l'unico modo che aveva di esserlo:* uno snapshot
      cattura un fotogramma fermo, quindi io potevo solo controllare che l'animazione fosse
      cablata sul sottoalbero giusto. Chiuso il 2026-07-30 su sua osservazione diretta —
      **«la dissolvenza regge»**.

- [x] **ISC-95** Il pool governa il turno, le sostituzioni restano libere. — La regola, con le sue
      parole: *«l'opzione più semplice può essere proposta come sostituzione, ma se non è nel pool
      mai come esercizio»*. Il comportamento c'era già; mancava la guardia.
      *Dead end pagato, e revertito:* avevo filtrato anche le **varianti** col pool, cioè tolto la
      via d'uscita verso il gesto più facile proprio nel momento in cui serve — dentro una pausa
      che non riesci a finire — portandomi via per giunta affondi e sit-up, che facili non sono,
      solo fuori dalla rotazione. Due ruoli diversi per lo stesso elenco, fusi in uno.
      *Falsificatore, una metà per test:* l'esercizio del turno esce dall'elenco scelto su 24
      turni, con un controllo che la rotazione giri davvero; e la regressione sulle ginocchia
      resta offerta come sostituzione anche se non è nell'elenco.

### Iterazione 20 — la giornata ricomincia, e le preferenze smettono di essere una lista (2026-07-31)

Tre cose viste all'uso, tutte e tre dal principale in un turno solo: la prima pausa di oggi era
piena, l'attribuzione «consenso» non si capisce, e le preferenze sono una lista unica da scorrere.

- [x] **ISC-96** La prima pausa di ogni giornata è breve. — Il ciclo micro/micro/piena viveva in
      `rotation.json` e non sapeva che fosse cambiato il giorno: chiudendo il 30/07 con due micro,
      la prima pausa del 31/07 è arrivata piena. Ora l'istantanea porta anche **la data
      dell'ultima pausa**, e al momento di decidere il tipo un giorno diverso vale zero micro
      alle spalle. Scelta del principale fra le due letture di «turno di lavoro»: **giorno di
      calendario**, non stacco vero — con la grazia di 5 minuti ogni caffè avrebbe azzerato il
      ciclo e la pausa piena non sarebbe arrivata mai.
      *Falsificatore:* due test sul motore, uno per polo — stessa istantanea, un `now` di ieri
      dà `.long` e un `now` di oggi dà `.micro` — più il caso reale del 30→31 luglio ricostruito
      dal registro vero.

- [x] **ISC-97** L'attribuzione dice cos'è, in italiano leggibile. — «cronobiologia
      dell'esercizio, consenso» ha fatto chiedere al principale cosa volesse dire: da solo
      «consenso» in italiano sembra quello della privacy. Diventa **«consenso scientifico»**, e la
      forma girata («consenso di fisiologia dell'esercizio») si allinea allo stesso schema
      `<campo>, consenso scientifico`. Resta intatta la dichiarazione di consenso di Buckley 2015,
      che è il nome proprio di un documento con autori e anno; e resta intatto l'inglese, dove
      `consensus` non è ambiguo.
      *Falsificatore:* un grep che pretende zero occorrenze della forma nuda, più il lint delle
      due lingue.

- [x] **ISC-98** Le preferenze si navigano, non si scorrono. — `NavigationSplitView`: sei voci a
      sinistra — Profilo, Cadenza, Esercizi, Interruzioni, Aspetto, Sistema — e a destra solo il
      pannello scelto. Nessuna impostazione persa nel passaggio.
      *Falsificatore:* l'elenco dei controlli prima e dopo, campo per campo, più la schermata
      catturata e **guardata**.

- [x] **ISC-99** Il pulsante che salva non scorre via. — Oggi «Applica» è l'ultima sezione di un
      modulo lungo: cambi la cadenza, scendi agli esercizi, e non lo vedi più. Esce dal pannello e
      diventa una barra fissa in basso, sotto il contenuto e comune a tutte le voci — la bozza è
      una sola e attraversa i pannelli, quindi il pulsante non può vivere dentro uno solo.
      *Falsificatore:* schermata di due voci diverse con la barra visibile in entrambe, e la prova
      che una modifica fatta in un pannello sopravvive al passaggio a un altro.

- [x] **ISC-100** Il numero pieno si sceglie, non si aspetta. — Chiesto a metà lavoro: *«devo
      avere la possibilità anche di mettere il 100% dalle impostazioni»*. Lo stepper arrivava già
      a 100, ma dice «si parte al…» — parla di com'è cominciata, non di adesso — e l'unica altra
      via era la finestra che l'app propone da sé dopo una settimana, cioè una domanda che arriva
      quando decide lei. Ora in Profilo → Ripetizioni c'è **«Passa subito al 100%»**, che scrive
      anche la data del pieno (da lì partono i sette giorni della domanda sulla crescita) e
      spegne la domanda delle due settimane. Chi c'è già legge «Sei al numero pieno».
      *Reversibile per costruzione:* riabbassando la percentuale la data del pieno si cancella, o
      la domanda sulla crescita oltre il 100% arriverebbe a chi al 100% non è.
      *Falsificatore:* la finestra vera, guardata — il pulsante c'è sotto i 100 e sparisce sopra.

- [x] **ISC-101** In alto a destra, il conto dell'esercizio che stai facendo. — Sua richiesta a
      metà lavoro, con la domanda giusta attaccata (*«o pensi che sia sbagliato?»*). Non è
      sbagliato **se** vuol dire *quanti ne ho fatti oggi di questo*, che è la domanda che ti fai
      mentre sei lì; sarebbe sbagliato se volesse dire *le ripetizioni di questa pausa*, perché
      quelle sono già il numero grande al centro dello schermo — lo stesso numero due volte, il
      difetto chiuso con ISC-92. Ora la riga è `oggi: 2ª pausa · 12 squat · 46 in tutto`:
      l'esercizio davanti perché è la domanda, il totale dopo perché è il volume della giornata,
      quello che gli studi misurano. Nel microcircuito segue la stazione in corso.
      *Niente zeri:* al primo di quell'esercizio il pezzo di mezzo sparisce invece di dire «0
      squat». Le due copie della riga sono diventate una funzione sola.
      *Falsificatore:* `--registro-finto` semina una giornata già cominciata — il ramo con il
      conto non esiste su un registro vuoto, e senza la semina si guarda sempre lo stesso ramo.

- [x] **ISC-102** Il menu non ha più il buco sotto i numeri. — L'altezza del pannello era una
      costante scritta a mano, 260 punti contro un contenuto che ne occupa 181: sotto «sessioni
      intense» restava una fascia vuota grande quanto tre voci, e sembrava che mancasse qualcosa.
      È la stessa cura della notifica del 28 luglio, e lo stesso difetto: **una costante scritta a
      mano scommette sull'altezza del contenuto**, e la scommessa si perde al primo cambiamento.
      *Anche la sonda mentiva allo stesso modo*: `--surface=menu` aveva il suo 260 scritto a mano,
      quindi avrebbe riprodotto la fascia vuota invece di mostrarla sparita.
      *Falsificatore:* il menu vero, aperto e fotografato — 181 punti, e la resa concorda.

- [x] **ISC-103** Le fonti, il registro e la diagnostica stanno nelle Preferenze, con la riga che
      dice cosa sono. — Un menu di barra di stato è la lista delle cose che fai spesso; quelle tre
      si aprono una volta ogni tanto, e due su tre erano **nomi senza spiegazione** — «Apri il
      registro» non dice a nessuno cosa ci trova dentro. Ora sono la voce **Avanzate**, ognuna con
      il suo paragrafo: cos'è, a cosa serve, e per il registro anche che è la sola verità da cui
      escono le statistiche e che non lascia mai questo Mac.
      *Come ci arrivano:* tre closure che l'`AppDelegate` assegna al modello all'avvio — non
      `NSApp.sendAction(Selector(("showEvidence")))`, che è un nome di metodo dentro una stringa,
      cioè una cosa che il compilatore non controlla e che si rompe in silenzio.

- [x] **ISC-104** Gli esercizi si scelgono per famiglia, non scorrendo. — Quattro sezioni impilate
      erano tre schermate di scorrimento: per arrivare agli esplosivi passavi davanti a
      venticinque caselle che non stavi cercando. Ora una linguetta per famiglia.
      *Il contatore nella linguetta è la parte che conta* — «Gambe 4/5» — perché la lista lunga un
      vantaggio ce l'aveva, si vedeva tutta insieme, e senza il numero aprire quattro pannelli
      costerebbe la memoria. I due interruttori su come vengono proposti restano sotto, fuori
      dalle linguette: valgono per tutte le famiglie.

- [x] **ISC-105** Rinviare non fa rumore. — *«non mi piace il suono quando posticipo la pausa.
      togliamolo»*. La regola c'era già scritta per la chiusura della pausa: il suono avvisa di
      qualcosa che non ti aspetti, e quello che hai appena premuto tu non è una sorpresa. Non era
      stata applicata qui. Muto anche l'auto-rinvio per call, e lì c'è un motivo in più: scatta
      mentre stai parlando, cioè nell'unico momento in cui un suono di sistema non lo senti solo tu.

- [x] **ISC-106** Aprire una finestra non porta Otium nel Dock. — *«è ricomparsa l'icona
      dell'applicazione nel dock. Non dovrebbe.»* Il 28 luglio avevo curato la metà peggiore del
      difetto — ci restava **per sempre** — lasciando in piedi la premessa: che una finestra valga
      un posto nel Dock. Tolto `.regular` da `present(_:)`: un'app `.accessory` le finestre le
      mostra e il fuoco lo prende, e quello che perde sono le due cose che `LSUIElement` dichiara
      di non volere. **Il blocco della pausa resta l'eccezione e resta com'è**: lì `.regular`
      serve davvero, e è il pezzo che ha prodotto lo schermo nero — non si tocca per un'icona.
      *La sonda ora chiede la cosa giusta:* apre le **Preferenze**, che è la finestra che il
      principale tiene aperta, non le Statistiche che non lascia aperte mai; e controlla che la
      finestra **prenda il fuoco**, perché stare fuori dal Dock non serve a niente se poi nel
      campo di testo non si scrive. Provata a due poli: rimettendo `.regular` diventa rossa.
      *Difetto vicino, trovato mentre cercavo questo:* il ripristino della politica guardava
      **cinque** finestre su nove — mancavano diagnostica, primo avvio, ritmo e crescita, e una
      finestra fuori dall'elenco fa dire «non c'è più niente aperto» a schermo pieno di roba.

- [x] **ISC-107** La pausa rimandata per la call torna quando la call finisce. — *«quando viene
      posticipata una pausa perché ero con il microfono attivo, deve essere avvisato al momento in
      cui il microfono viene chiuso che la pausa precedente non è stata fatta»*. Rimandare di
      cinque minuti era giusto per non piombare addosso mentre parli; ma se la riunione finisce
      dopo quaranta secondi, quei cinque minuti diventano un'attesa senza più causa, e nel
      frattempo la pausa arretrata non la sa più nessuno.
      *Riparte dal preavviso, non dalla pausa:* riattaccare il telefono e trovarsi lo schermo
      coperto nello stesso istante sarebbe peggio dell'attesa che questo toglie. E l'avviso dice
      **perché** — «Il microfono si è chiuso · la pausa rimandata riparte fra un minuto» — o il
      preavviso arriverebbe senza che si capisca da dove.
      *Vale solo per il rinvio deciso dall'app:* quello chiesto a mano dura quello che dura, o
      premere «rinvia» a fine riunione non varrebbe niente.
      *Il rimbalzo è già gestito dalla porta normale:* se la call ricomincia durante i sessanta
      secondi, `startBreak` rimanda di nuovo da solo — nessuna isteresi in più da mantenere.
      *Falsificatore, cinque test con due controlli veri:* sabotando la sveglia diventano rossi
      **tre**, e restano verdi proprio i due controlli — il rinvio a mano e il microfono ancora
      occupato — che distinguono «funziona» da «l'attesa è stata tolta a tutti».

- [x] **ISC-108** L'intervallo promesso è quello vissuto. — Il preavviso scattava **dopo** i 30
      minuti e la pausa arrivava a 31: la barra prometteva «prossima fra 30 min», Duran 2023 dice
      30, e l'intervallo vero era 31. *«il warning viene quando sono già passati 30 minuti»*.
      **Nessun test lo vedeva perché tutti erano scritti con la stessa assunzione dentro** — la
      classe di difetto che si nasconde meglio, quella dove il test copia l'errore del codice: i
      dodici rossi dopo la cura erano tutti helper che avanzavano `intervallo + preavviso`.
      *Difetto trovato dal test nuovo, non dall'uso:* con un preavviso più lungo dell'intervallo
      la soglia andava a fondo scala e la pausa scattava al primo secondo. Il tetto è metà
      intervallo, e sta **sul campo** e non solo nell'`init` — perché nell'`init` si scavalca
      assegnando la proprietà dopo, ed è precisamente quello che il test ha fatto al primo colpo.

- [x] **ISC-109** Il richiamo quando la pausa è finita. — *«magari non essere andata dal laptop e
      deve tornare»*. La pausa piena chiede di stare tre minuti lontano dallo schermo, e da lontano
      non c'è modo di sapere che il tempo è passato: adesso suona, con lo stesso suono del
      preavviso.
      *Agganciato al pulsante, non al cronometro:* con l'esercizio ancora da fare «puoi tornare»
      sarebbe falso. La differenza fra le due implementazioni è tutta in un test — sostituendo la
      condizione col solo cronometro, resta rosso solo quello e gli altri tre passano.
      *Solo suono, nessun pannello:* lo schermo è coperto dal blocco, e chi è dall'altra parte
      della stanza un pannello non lo vede comunque.

- [x] **ISC-110** La cadenza dice di cosa parla, e «personalizzata» dice perché. — *«ogni quanto,
      quanto dura, ma cosa?»*. Intestazione in cima al pannello, preset scritti per esteso («una
      pausa breve ogni 30 minuti, una piena ogni 90») invece della formula compressa.
      *«Personalizzata» era una voce fantasma:* sempre presente e senza effetto, perché
      `applyPreset` non ha un caso per lei — non è una scelta, è lo stato in cui finisci toccando
      i valori sotto. Ora compare **solo** quando quello stato è vero, e sotto c'è la riga che
      dice quali campi ti ci hanno portato, confrontati col preset più vicino.
      *Il caso vivo che l'ha chiesta:* il principale ha trovato «personalizzata» senza aver
      toccato la cadenza. La trappola è che «consenti N rinvii a mano» vive nel pannello
      *Interruzioni* ma è un campo della *cadenza*. Spostarlo sarebbe stato peggio — nessuno cerca
      i rinvii sotto «Cadenza» — quindi l'app lo dice invece di nasconderlo.
      *Difetto visto nei pixel, non nel codice:* gli asterischi del grassetto uscivano a schermo.
      `Text(String)` non passa dal markdown, `Text(.init(String))` sì; era la stessa classe già
      pagata sulle frasi, e il grep ha trovato l'unico altro punto — che era già corretto.

- [x] **ISC-111** Nella barra dei menu il numero dice la sua unità. — C'era un `!` nel preavviso,
      che non dice niente. Scriverci `60` l'ha scartato il principale stesso, per il motivo
      giusto: si legge come sessanta minuti. Ora `47s` nel preavviso e `23m` mentre lavori — il
      numero nudo di prima aveva lo stesso difetto al contrario.

- [x] **ISC-112** «Spinta e braccia» diventa «Spinta». — In italiano il paio corretto è
      *spinta / trazione*; «e braccia» era un riempitivo che non nomina niente. Il sottotitolo
      resta quello vero: petto, spalle, tricipiti.

- [x] **ISC-113** I posturali, la famiglia che mancava. — *«peccato che non ci sia niente da fare
      per il dorso»*. A corpo libero e senza barra la trazione vera non esiste, e le alternative
      che circolano — rematore allo stipite, auto-resistenza mano contro mano — hanno tutte lo
      stesso difetto, che il principale ha visto per primo: *«credo sia minima veramente la forza
      necessaria»*. Il carico dipende da quanto tiri, quindi non è misurabile, quindi non è
      verificabile: scartate. **Sui bicipiti non c'è soluzione e resta scritto così**, invece di
      metterci un esercizio finto.
      Restano due cose vere: **Y-T-W** (trapezio inferiore e romboidi, tre angoli) e **superman**
      (erettori spinali). Famiglia «Posturali», nome scelto da lui.
      *In rotazione ne va uno solo:* sono entrambi «dorso», e nel pool di serie finivano uno
      dietro l'altro — il test che vieta due gruppi uguali di fila l'ha visto al primo giro. Gira
      il Y-T-W, più mirato; il superman resta spuntabile e **resta offerto come sostituzione
      dentro la pausa anche da spento**, che è la regola dell'ISC-95.
      *Le istruzioni sono il prodotto, qui più che altrove:* «Y-T-W» non lo conosceva nemmeno chi
      l'ha chiesto, e un esercizio che non sai eseguire è un esercizio che salti. Un test pretende
      che le tre lettere siano nominate e che la riga sia lunga abbastanza da insegnare il gesto.
      *Coefficiente per sesso dichiarato stima, non misura*, come già per l'addome: Miller non
      misura la schiena alta, e qui non si sposta un carico esterno.

- [x] **ISC-114** Il burpee dice il piegamento. — La descrizione era «squat, gambe indietro, torna
      su, salto»: quello è lo **squat thrust**, cioè il burpee senza push-up — un esercizio
      diverso e più facile. Trovato dal principale raccontando come lo fa lui. Ora la sequenza è
      scritta per intero, ed è il gesto più complesso che l'app propone: saltarne un passaggio
      significa farne un altro senza accorgersene.

- [x] **ISC-115** Il richiamo dice «la pausa è finita», non «puoi tornare». — Correzione della mia
      prima versione, che l'aveva agganciato al pulsante e quindi taceva finché l'esercizio non
      era confermato. *«Non chiude la pagina, ma ti dice: la pausa è finita. Poi sta alla persona
      se ha fatto meno l'esercizio.»* Il tempo scade comunque, e cosa farne è una decisione della
      persona: l'app annuncia un fatto, non concede un permesso.
      *Nei test il controllo è diventato il claim e viceversa* — la stessa coppia, girata.

- **Anti-claim** — il giorno nuovo azzera **solo** il ciclo micro/piena. Non la rotazione degli
  esercizi (che è `breakIndex`, e senza di lei si torna a squat-squat-squat, il difetto del
  26/07), non il conto del tempo attivo, non i mazzi delle frasi.

- **Anti-claim** — la barra laterale non deve nascondere niente. Sei voci che coprono tutti i
  controlli di oggi: una preferenza che esiste ma non si trova più è peggio di una lista lunga.

## Test Strategy

Tre strumenti: `swift test` per tutta la logica pura (orologio, motore, rampa, registro), che è
dove vivono i difetti veri; l'ispezione del codice per i contratti AppKit; e **gli occhi** per il
blocco — uno screenshot reale dell'overlay, guardato, perché un overlay "corretto nei numeri" e
uno che non copre la barra dei menu sono indistinguibili nei test.

| ISC | Probe | anchors_to |
|---|---|---|
| 1-5 | `swift test` — `ActivityClockTests`, sorgente di inattività iniettata | literal ("monitorare il tempo reale") |
| 6-10 | `swift test` — `SessionEngineTests`, tempo simulato | literal ("dopo un tempo determinato") |
| 11-13 | ispezione codice + screenshot dell'overlay guardato | literal ("lo schermo rimane bloccato") |
| 14 | `codesign -d --entitlements` + assenza di API TCC via grep | derived: nessun permesso |
| 15-17 | `swift test` — `ExerciseTests` | literal ("mi obblighi a fare un tot numero di squat") |
| 18, 20 | ispezione codice (nessun responder di chiusura) + test del timeout di sicurezza | derived: attrito con uscita |
| 19 | `swift test` — `EscapeHatchTests` + prova a schermo | derived: sicurezza |
| 21-22 | `swift test` — `LedgerTests` + lettura del file JSONL scritto | derived: registro |
| 23-24 | grep delle citazioni nel sorgente + lettura della schermata "Perché" | literal ("proponendo i vari studi") |
| 25-27 | esecuzione dello script + `open Otium.app` + `launchctl list` | derived: impacchettamento |
| 28 | uso reale del principale (esperienziale — nessun probe automatico) | literal (tenibilità) |
| 29 | `grep -rE "URLSession\|NSURL\|Network\." Sources/` → zero occorrenze | derived: privacy |

## Features

| # | Feature | Stato |
|---|---|---|
| F1 | `OtiumCore` — orologio del tempo attivo, motore delle pause, esercizi, rampa, registro, fonti | da fare |
| F2 | `OtiumApp` — menubar, sonda di inattività, radar microfono, finestre di blocco, UI esercizio, preferenze | da fare |
| F3 | Test — `swift test` su tutta la logica pura | da fare |
| F4 | Impacchettamento — `build-app.sh`, icona, LaunchAgent, README con le fonti | da fare |

## Decisions

- **2026-07-31 — installare non è `open`, se l'app è già viva.** Ricostruito il bundle, `open
  Otium.app` **non rilancia niente**: trova l'app in esecuzione e la porta davanti, e basta. Il
  processo continua col binario vecchio, mappato in memoria, mentre sul disco c'è quello nuovo —
  e tutto sembra a posto: nessun errore, l'app risponde, la versione del file è aggiornata. La
  prima volta non me n'ero accorto per un caso fortunato, cioè che il build aveva fatto morire
  l'istanza da sé. **La sonda è il pid**: se non cambia, non hai installato niente. Chiudere
  prima, riaprire dopo, e confrontare i due numeri.


- **2026-07-28 — una sonda si isola per costruzione, non per disciplina.** Le prime sonde di questa
  giornata scrivevano nei dati veri, e ci si compensava con un backup prima e un ripristino dopo,
  cioè con l'attenzione di chi lancia il comando. Ha ceduto: le sonde hanno riscritto l'avvio
  automatico del principale, puntandolo al binario di sviluppo. La cura non è ricordarsene meglio,
  è `Paths.overrideDirectory` più `ProbeMode` — la sonda non *deve* stare attenta, non *può* fare
  danni. Guadagno inatteso: ora girano mentre l'app vera lavora, perché anche il lock dell'istanza
  unica finisce nella cartella usa e getta.

- **2026-07-28 — il pannello cede, il significato no.** La notifica tagliava «di lavoro attivo». Le
  due strade erano accorciare la frase o far crescere il pannello. Accorciare curava quel caso e
  lasciava in piedi il prossimo, e per giunta la parola da sacrificare era «attivo», cioè quella
  che rende onesta l'app (30 minuti di lavoro vero, non di orologio a muro). Ora l'altezza la detta
  il contenuto, e una costante scritta a mano nel codice non scommette più sulla lunghezza di ogni
  frase futura.

- **2026-07-28 — lo schermo coperto è una funzione della fase, non l'effetto di un evento.** La
  correzione ovvia dello schermo nero era aggiungere `blocker.hide()` al caso `.naturalBreak`, cioè
  l'unico dei sei a non averlo. Scartata: sarebbe la stessa architettura con un buco in meno, e il
  prossimo evento che qualcuno aggiungerà al motore ricomincerebbe da capo — con lo stesso prezzo,
  che qui è un riavvio forzato. Al suo posto la lista degli eventi perde il potere di lasciare uno
  scudo orfano: dopo ogni giro, se la fase non è `.breaking`, lo schermo si libera. Il caso
  `.naturalBreak` è rimasto **deliberatamente senza** `hide()`, così la responsabilità ha un solo
  proprietario e non due che si coprono a vicenda.
  *Corollario pagato subito:* tre reti in tre strati sono utili solo se ognuna regge da sola, e per
  saperlo vanno spente una per volta. Da qui `SafetyNets`, due interruttori usati solo dalle sonde.
  Scaffolding di prova dentro il codice di produzione, accettato consapevolmente: l'alternativa era
  scrivere «ridondante» nei commenti e non poterlo dimostrare.
  *Dead end:* la prima ipotesi puntava allo sleep del Mac, perché è lì che il guasto si è **visto**
  entrambe le volte. Il registro dice altro — lo schermo era già morto da cinque minuti quando il
  display si è spento da solo — e la coincidenza aveva già portato fuori strada una volta, la sera
  del 27, quando la colpa era finita sulle AI locali.

- **2026-07-28 — il corpus si riempie con un cancello, non con la buona fede.** Dopo la scrematura
  il pool era sceso a 275 frasi contro le 480 che la promessa richiede. Invece di aggiungere
  citazioni «lette da qualche parte», i testi primari sono stati scaricati sul disco e ogni
  candidata porta con sé il frammento in **lingua originale**: `Scripts/citazioni/verifica-citazioni.ts`
  lo cerca dentro il file e restituisce la riga, e se non lo trova la frase non si scrive. Su 152
  candidate ne ha bocciate **19**, sempre per lo stesso motivo, cioè che il testo con quelle parole
  esatte non esisteva. **Il cancello è stato provato ai due poli** prima di fidarsene
  (`prova-negativa.json`): boccia l'inventata, il doppione, l'opera tentennante e la frase troppo
  lunga, e lascia passare le vere. Risultato: 275 → **408**, il pool d'avvio torna verde a 327,
  la guardia del mese senza ripetizioni resta rossa e **il ramo non si fonde**.
  *Dead end pagato:* alla prima corsa il cancello bocciava sei citazioni **vere**. Non era rigore,
  era un difetto suo, perché appiattendo il testo riga per riga una riga con spazio in coda
  produceva due spazi, e il frammento con spazi singoli non ci si trovava più. Una guardia che
  sbaglia verso il rosso è più insidiosa di una che sbaglia verso il verde, perché sembra che stia
  funzionando.
  *Corretto dal principale, non dal cancello:* due rese italiane erano lecite nel dizionario e
  sbagliate a schermo, `circumscribe` reso «restringi» invece di «traccia un confine intorno», e
  `Der Leib ist eine grosse Vernunft` accorciato a «il corpo è una grande ragione», che da solo in
  italiano si legge «motivo». Nessun controllo automatico vede questa classe di errore.

- **2026-07-26 — cadenza A** (micro 90 s ogni 30 min + piena 5 min ogni 90 min), scelta dal
  principale fra tre opzioni presentate con pro/contro/rischi. Alternative scartate: B (5 min ogni
  50, protegge il focus ma manca il bersaglio glicemico), C (protocollo Duran puro, il più
  efficace e il primo che si abbandona).
- **2026-07-26 — niente telecamera in v1.** Richiesta esplicita del principale, e le recensioni di
  Pushscroll ("undercounting pushups") mostrano che la pose detection sbaglia proprio dove servirebbe.
- **2026-07-26 — tre idee prese dai concorrenti**, dopo il sondaggio del panorama: da Stretchly la
  struttura mini/long con il contatore "dopo N mini arriva il long" e il rinvio singolo; da Time Out
  le *natural breaks* (la pausa spontanea conta); da Workrave l'esercizio guidato con conteggio a
  schermo. Nessuna riga di codice copiata: Stretchly è Electron/BSD-2, qui si riscrive nativo.
- **2026-07-26 — nessun permesso TCC come vincolo di design**, non come effetto collaterale: il
  radar delle call usa CoreAudio (`kAudioDevicePropertyDeviceIsRunningSomewhere`), che non richiede
  il permesso microfono perché non legge audio.

- **2026-07-26 — ISC-20 riscritto durante il build, ed è la scoperta più utile del run.**
  Il criterio diceva «il blocco cade da solo entro il doppio della durata prevista». Applicandolo
  si è visto che è un criterio *sbagliato*: la pausa piena chiede tre minuti lontano dallo schermo,
  quindi una soglia di assenza fissa a tre minuti annulla la pausa **mentre la stai facendo bene**,
  e la registra come saltata. Ora la soglia è `max(180, durata + 120)` e l'assenza si registra come
  pausa **naturale**, non come salto: il registro non deve mentire in nessuna delle due direzioni.
  Il tetto assoluto (30 min) resta, ma come rete contro un motore incoerente, non come timeout
  sulla disciplina — un timeout sulla disciplina svuoterebbe l'app.

- **2026-07-26 — la rotazione degli esercizi caricava due volte di fila lo stesso gruppo.**
  Trovato da un test, non a occhio: un pool `[squat, affondi, …]` faceva gambe → gambe. Aggiunto
  `spreadByMuscleGroup`, un riordino greedy che separa i gruppi e non si impianta quando i gruppi
  sono meno degli esercizi (lì una ripetizione è aritmeticamente inevitabile, e il codice fa del
  suo meglio invece di ciclare a vuoto).

- **2026-07-26 — verifica visiva: tre sonde sbagliate di fila, stessa causa.**
  (1) `screencapture` risponde **nero** senza il permesso Registrazione schermo, e un nero non si
  distingue da una finestra che non ha disegnato niente — la sonda di controllo (`probe.png`,
  scattata a schermo pieno di roba) era nera identica, il che l'ha smascherata.
  (2) `kCGWindowBounds` **non** vive nello spazio di `NSScreen.frame`: una finestra da 1512×982
  punti viene elencata 1362×884, e una finestra di controllo da 400×300 diventa 361×271 — stesso
  fattore, attorno al centro dello schermo. Confrontando i numeri grezzi ho dichiarato rotta
  un'app sana, due volte.
  (3) `CGDisplayBounds` riporta 1512×982, quindi **nemmeno lui** è nello spazio di
  `kCGWindowBounds`: anche la seconda correzione era sbagliata.
  Rimedio strutturale: la sonda si **tara da sola**, costruendo una finestra che sa essere grande
  quanto lo schermo e leggendosi nella stessa lista. Il fattore non si suppone: si misura, ogni
  volta, su questa macchina. *La sonda deve rispondere alla domanda che hai fatto, non a una più
  debole* — la lezione era già scritta in OPERATIONAL_RULES, e mi ha morso tre volte in un'ora.

- **2026-07-26 — commento falso rimosso.** L'override `constrainFrameRect` era stato aggiunto con
  un commento che gli attribuiva la correzione del "90% dello schermo". Misurato: la finestra esce
  1512×982 con e senza quella riga — il 90% era un artefatto della sonda. La riga resta come
  cintura, il commento ora dice la verità. Una spiegazione sbagliata dentro il codice è peggio di
  nessun commento: è la prossima persona che ci costruisce sopra.

- **2026-07-26 — il segnale scelto per il video era semplicemente inesistente, e l'ha scoperto una
  prova sul campo del principale.** Il disegno appoggiava il riconoscimento del video
  sull'asserzione `PreventUserIdleDisplaySleep`. Con YouTube in riproduzione in Brave, l'elenco
  **completo** delle asserzioni conteneva solo `caffeinate`, `powerd` e WindowServer: **i browser
  Chromium non la alzano affatto**. Non un bug di implementazione — un presupposto sbagliato, che
  nessun test unitario avrebbe mai potuto smentire perché i test provavano la mia idea del mondo,
  non il mondo. Segnale primario riscritto sull'**audio per processo**
  (`kAudioProcessPropertyIsRunningOutput`), che si vede sempre.
  **Secondo strato dentro il primo:** chi suona non è Brave ma `Brave Browser Helper.app`, un
  processo annidato che per il sistema non è un'applicazione — `NSRunningApplication` risponde
  `nil` e l'attribuzione lo scartava. Ora si risale il percorso dell'eseguibile fino al bundle
  `.app` più esterno.
  **Conseguenza sulla lista:** Spotify e Musica tolti. Da quando il segnale è l'audio, un'app di
  sola musica in elenco significherebbe che la musica di sottofondo mentre sei in cucina conta
  come "sei davanti allo schermo".

- **2026-07-26 — la sonda `--presence` aveva un difetto di *protocollo*, non di codice.** Per
  lanciarla bisogna mettere a fuoco il terminale, quindi l'app da riconoscere non può mai essere
  in primo piano nel momento della misura: uno strumento che distrugge ciò che vuole misurare.
  Due rimedi: `--presence --watch=N`, che campiona nel tempo mentre l'operatore fa altro; e — per
  le prove automatiche — `open -a <app> <file>`, che porta l'app in primo piano **senza** che il
  comando successivo dalla shell rubi il fuoco. È così che il caso PDF si è chiuso da solo,
  senza chiedere niente al principale.

- **2026-07-26 — rinominata da "Pausa" a "Otium"**, su richiesta del principale (*«non mi piace il
  nome, troviamo qualcosa in inglese o latino o greco che suoni bene»*). *Otium* è il riposo che
  rigenera, opposto a *negotium*, il lavoro: l'app fa letteralmente questo. Il rinomino ha toccato
  identificatori, bundle, cartella dei dati e prosa, **ma non la parola «pausa» dove è il nome
  comune della cosa** — «PAUSA PIENA» nella schermata, «Pausa fra un minuto» nel preavviso, la
  frase d'emergenza «salto la pausa» restano tali. Il registro storico è stato trasferito nella
  nuova cartella (11 righe) e la vecchia archiviata, non cancellata.

- **2026-07-26 — «ma non ha registrato il PDF»: la priorità era sbagliata, e non era un bug di
  stampa.** Il radar provava l'audio per primo e si fermava al primo segnale trovato. Con una
  scheda di Brave che suonava **dietro**, il PDF che il principale aveva **davanti** non veniva
  mai nemmeno guardato. Due difetti in uno: la lettura restava invisibile, e la musica di
  sottofondo bastava a dichiarare "sta guardando un video" — col tetto largo dei 45 minuti —
  anche a stanza vuota.
  **Regola nuova: conta cosa hai davanti.** Si parte dall'app in primo piano e la si classifica;
  l'audio non è più un segnale a sé ma la *conferma* che il player davanti a te sta davvero
  riproducendo. Aggiunto il ramo mancante: un browser in primo piano che **non** suona è
  **lettura** (tetto 15′) — leggere un articolo lungo non deve essere scambiato per assenza.
  Il rischio opposto (browser lasciato davanti mentre esci) è limitato due volte, dal tetto e
  dallo scioglimento automatico del blocco a scrivania vuota.

- **2026-07-26 — la decisione è stata spostata nel nucleo** (`PresenceClassifier`), separandola
  dalla raccolta dei fatti che parla con macOS. Finché stavano insieme nessun test poteva
  raggiungere la classificazione — ed è esattamente lì che si era annidato l'ordine sbagliato.
  Ora ogni ramo ha il suo test.

- **2026-07-26 — il primo polo negativo del nuovo ordine NON è diventato rosso, e il test è stato
  rifatto.** Provava Anteprima con l'audio spento: un caso in cui i due ordini danno la stessa
  risposta, quindi invertendo il codice restava verde e non dimostrava nulla. Sostituito con
  l'unico caso in cui i due ordini divergono davvero — un'app che è **sia** lettore **sia**
  player (Anteprima) mentre sta suonando. Con quello, l'inversione produce 2 fallimenti.
  *Un polo negativo che non morde è un'asserzione travestita da verifica, e ne avevo appena
  scritto uno.*

## Changelog

- **2026-07-31 (iterazione 20c)** — La pausa rimandata per una call torna appena il microfono si
  libera, con l'avviso che dice perché, invece di aspettare la scadenza dei cinque minuti. **258
  test verdi**, e i due controlli che restano verdi sotto sabotaggio sono la parte che conta.
- **2026-07-31 (iterazione 20b)** — Il giro di rifiniture, tutto dall'uso vero. Il menu perde la
  fascia vuota (l'altezza la detta il contenuto) e tre voci, che passano in **Preferenze →
  Avanzate** con la riga che dice cosa sono. Gli esercizi si scelgono per famiglia con il conto
  nella linguetta invece di scorrere. Rinviare non fa più rumore. E **aprire una finestra non
  porta più Otium nel Dock**: il 28 luglio avevo curato la metà peggiore del difetto lasciando in
  piedi la premessa. La sonda della politica ora apre le Preferenze e controlla anche il fuoco —
  senza quella riga avrebbe chiamato verde metà cosa, ed è esattamente quello che ha trovato al
  primo giro.
- **2026-07-31 (iterazione 20)** — Tre cose viste all'uso e due chieste a lavoro in corso. Il ciclo
  micro/piena non sapeva che fosse cambiato il giorno, e la prima pausa del 31 luglio è arrivata
  piena: adesso l'istantanea porta la data dell'ultima pausa e la giornata comincia sempre corta.
  «Consenso» da solo diventa «consenso scientifico» in ventuno attribuzioni. Le preferenze passano
  dalla lista unica a **sei voci con barra laterale**, con «Applica» in una barra fissa che non
  scorre più via. Poi il numero pieno si sceglie da solo dalle impostazioni, e in alto a destra
  nella pausa compare il conto dell'esercizio in corso prima del totale.
  **253 test verdi** (da 243), quattro nuovi resi rossi di proposito sabotando la cura.
  *Lezione sulla sonda:* `--surface=prefs` disegna fuori da una finestra, e lì una barra laterale
  di sistema esce **bianca e vuota** — una resa che non sa disegnare la vista dice solo che la
  sonda non ci arriva. Da qui `--mostra-prefs`, che apre la finestra vera, e la cattura per **id
  di finestra** invece che per regione, perché una regione fotografa qualunque cosa ci sia sopra.

- **2026-07-28 (iterazione 13)** — ⌃S diventa una scorciatoia vera, che apre le statistiche da
  qualunque app senza chiedere permessi (Carbon, non il monitor globale che pretende il
  Monitoraggio input). Poi caccia ai bug della stessa famiglia di quello dello schermo nero: un
  fuzz sul motore con invarianti a ogni passo (16.000 passi, tutte le fasi visitate, sabotatura che
  lo fa diventare rosso) non ha trovato niente nel motore, e una sonda nuova ha trovato invece che
  l'app restava per sempre nel Dock dopo la prima finestra aperta. **174 test verdi.**
- **2026-07-28 (iterazione 12)** — Il radar di presenza passa da ogni secondo a ogni 3, tranne nel
  preavviso dove il valore decide qualcosa (−67% di interrogazioni, misurate). Il menu smette di
  promettere ⌘S, che era il tasto di Salva e non poteva funzionare fuori dal menu aperto. La
  notifica non taglia più le parole: l'altezza la detta il contenuto. E le sonde diventano
  ermetiche, dopo che le mie avevano dirottato l'avvio automatico del principale sul binario di
  sviluppo — ora girano anche mentre l'app lavora.
- **2026-07-28 (iterazione 11)** — Lo schermo nero senza uscita, il guasto peggiore dell'app: due
  Mac inchiodati (27 e 28 luglio) risolti col tasto di accensione. Causa unica e provata, una pausa
  chiusa dal motore che non scopriva lo schermo. Tre reti in tre strati più un'uscita d'emergenza
  che non dipende più dal motore, e la sospensione dello scudo quando il Mac dorme. **Quattro sonde
  nuove**, ognuna con il suo polo rosso: `--orphan-probe` in tre configurazioni (tutte le reti,
  senza quella del modello, senza nessuna) e `--sleep-probe`. Girate anche sul binario di rilascio,
  non solo su quello di sviluppo.
- **2026-07-27 (iterazione 3)** — Primo giorno d'uso vero, e l'uso ha trovato quello che il
  codice non diceva: il conto perso dopo la sospensione, il pulsante cliccabile solo sul testo,
  la finestra delle fonti più alta dello schermo. Aggiunti addome, esercizi a tempo, preferenze
  per famiglia, microcircuito facoltativo nelle pause piene, avvio automatico, e un corpus di
  489 frasi estratte a mazzo invece che in rotazione fissa. **156 test verdi** (da 128), di cui
  uno sondato al contrario per provare che vedrebbe il guasto.
- **2026-07-26** — ISA creata e chiusa a 28/29 nello stesso giorno. Ricerca sulle fonti e sul
  panorama fatta *prima* della scrittura del codice; cadenza scelta dal principale fra tre
  opzioni; sonda dell'ambiente (Swift 6.3, Xcode 26.6, `HIDIdleTime` vivo, nessun Developer ID).
  52 test verdi, blocco provato a due poli, LaunchAgent installato-verificato-rimosso.

## Verification

**Lo schermo nero senza uscita (2026-07-28)** — quattro sonde nuove, tutte con il polo rosso
eseguito e non asserito. Girate due volte: sul binario di sviluppo e su
`dist/Otium.app/Contents/MacOS/Otium`, cioè quello che parte davvero al login.

| Sonda | Prima della cura | Dopo |
|---|---|---|
| `--orphan-probe` | `FAIL` — fase `working`, **1 finestra**, chiosco **490** | `PASS` — 0 finestre, chiosco 0 |
| `--orphan-probe --senza-rete-modello` | — | `PASS` — il battito della finestra basta da solo |
| `--orphan-probe --senza-reti` | — | guasto **riprodotto** (1 finestra, chiosco 490), poi `PASS`: l'uscita d'emergenza smonta lo scudo a motore già chiuso |
| `--sleep-probe` | — | `PASS` — bloccato: 0 finestre, chiosco 0, fase ancora `breaking`; sbloccato: 1 finestra, chiosco 490 |

**La scorciatoia globale e la caccia (2026-07-28)** — `--hotkey-probe`: registrazione riuscita e
gestore Carbon che scatta. **End-to-end, che qui è l'unica prova che conta:** con Finder in primo
piano, ⌃S sintetizzato ha fatto comparire una finestra di Otium da 640×712 che prima non c'era, sul
bundle di rilascio. `--policy-probe`: **rosso prima** (`accessory → regular → regular`), verde dopo.
`InvariantTests`: 40 semi × 400 passi verdi, tutte le fasi visitate, e sabotando `finish()` il fuzz
diventa rosso al primo seme con la sequenza che lo riproduce.

**Il ritmo del radar (2026-07-28)** — `--radar-probe` conta le interrogazioni vere: **0,33/s
lavorando** contro **0,80/s nel preavviso**, cioè il **67% in meno** nello stato in cui l'app passa
il 99% del tempo. Il preavviso fa da polo di controllo dentro la sonda: se il rallentamento non
funzionasse, le due fasi darebbero lo stesso ritmo.

**Dichiarato, perché la misura non regge la conclusione facile:** il consumo di CPU **non** mostra
il risparmio. 0,094% medio su 180 s prima, 0,133% dopo — cioè il numero è salito, il che è
impossibile per una modifica che toglie lavoro e basta. A 0,1% di CPU la misura è dominata da tutto
il resto della macchina (build in corso, redraw, altre app) e non ha la risoluzione per vedere due
interrogazioni al secondo in meno. La prova che regge è il **conteggio**, non il cronometro; il
risparmio di batteria dichiarabile è «non peggiora, e fa un terzo del lavoro di prima».

**Il menu e la notifica** — `--menu-probe`: `NSApp.mainMenu` è **nessuno**, quindi le combinazioni
di questo menu valgono solo a menu aperto; nessuna voce mostra più ⌘ tranne l'uscita.
`--snapshot --surface=hud` guardato a due lunghezze: la frase vera sta in una riga (84 punti), una
più lunga va a capo e il pannello cresce a 87. Nessuna delle due ha puntini di sospensione.

**Sonde ermetiche** — dopo `--snapshot` con l'app viva, `rotation.json` è identico al bit. Prima di
`ProbeMode` le sonde avevano riscritto l'avvio automatico dal bundle a `.build/debug/OtiumApp`:
rimesso a posto e verificato nel plist.

**Prove sul registro, non sul sospetto.** Gli stessi secondi due giorni di fila, e sono esattamente
le soglie d'assenza del codice: 28/07 `natural` long **420,07 s** (soglia `max(180, 300+120)` = 420)
alle 14:56:17, riavvio alle 15:02; 27/07 `natural` micro **210,19 s** (soglia `max(180, 90+120)` =
210) alle 22:18:55, riavvio alle 22:26. Il display si è spento **dopo**, alle 14:59:28 — lo sleep
non era la causa, era il momento in cui il guasto si vedeva.

**Schermata orfana resa e guardata** — `--snapshot --orfana`: 2880×1800, titolo «La pausa è finita»,
sottotitolo, pulsante Alloro pieno e riga su Esc. Prima di questa iterazione la stessa resa era un
rettangolo di un colore solo.

**Dichiarato:** `--sleep-probe` posta a mano `com.apple.screenIsLocked` e la sua gemella. Prova la
logica di sospensione e ripresa, **non** che macOS mandi quelle notifiche — quello è comportamento
documentato del sistema, e addormentare il Mac per verificarlo costerebbe più di quanto vale.

**Test automatici** — `swift test`: **52 test, 0 fallimenti**. Coprono orologio del tempo attivo,
motore delle pause, rampa, rotazione, uscita d'emergenza, registro, fonti, preferenze.

**Polo negativo eseguito** (non asserito): sabotando `spreadByMuscleGroup` a identità, i test sulla
rotazione diventano rossi; ripristinato, tornano verdi. Un test che non si è mai visto fallire è
un'asserzione travestita da verifica.

**Blocco dello schermo** — `swift Scripts/probe-blocker.swift`, due poli:
- app spenta → `RISULTATO: FAIL — 0/1 schermi coperti` (exit 1)
- app in blocco → `RISULTATO: PASS — 1/1 schermi coperti a livello di schermatura` (exit 0),
  finestra `1362x884 @ (75,49)` coincidente con il metro tarato, livello `2147483628`.

**Schermate rese e guardate** — `--snapshot`: micro-pausa (8 squat, cancello "ancora 20 s",
citazione Gao 2024) e pausa piena (4 burpee, citazione Stamatakis/Nature Medicine). Immagini
non degeneri: ~120 colori distinti campionati, contro l'unico colore delle catture nere.

**Dichiarato, non nascosto — quello che NON è stato verificato:**
- **Nessuna cattura a pixel del blocco a schermo intero.** `screencapture` da questa sessione
  restituisce immagini nere: manca il permesso Registrazione schermo, che solo il principale può
  concedere. La copertura è provata per geometria e livello, l'aspetto è provato sul render
  offscreen, ma le due prove non si sono mai toccate in un'unica immagine. `[DEFERRED-VERIFY]`
- **ISC-12 (Dock, barra dei menu, ⌘-Tab) chiuso su ispezione del codice**, non su un probe
  indipendente: è un effetto visivo, e vale il limite qui sopra.
- **Secondo schermo mai provato**: la macchina ne ha uno solo.
- **Notarizzazione**: impossibile oggi, non esiste un Developer ID su questa macchina — solo un
  certificato self-signed. Serve per la pubblicazione, non per l'uso locale.
