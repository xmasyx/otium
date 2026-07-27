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

> **Stato al 2026-07-27, iterazione 5: 43 chiusi su 44.** L'unico aperto resta ISC-28.
>
> Chiusi 28 su 29 il 2026-07-26. L'unico aperto è ISC-28, che è esperienziale: si chiude usando
> l'app per qualche giorno, non con un probe.

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
