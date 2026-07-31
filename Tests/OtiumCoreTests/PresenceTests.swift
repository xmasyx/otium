import XCTest
@testable import OtiumCore

/// Il caso che ha fatto nascere tutto questo: guardare un film è **immobilità perfetta**, cioè
/// il bout sedentario peggiore che esista — e la prima versione lo trattava come una pausa
/// riuscita, accreditandola. Qui si prova che non succede più, e che il rimedio non ha rotto il
/// caso opposto (l'assenza vera).
final class PresenceTests: XCTestCase {

    static let workingHour: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 28; c.hour = 10
        return Calendar.current.date(from: c)!
    }()

    private let netflix = PresenceSignal(kind: .media, detail: "Netflix — Safari")
    private let pdf = PresenceSignal(kind: .reading, detail: "relazione.pdf — Anteprima")

    private func makeEngine() -> SessionEngine {
        var s = Settings()
        s.startDate = Self.workingHour
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Guida il motore per N secondi senza **un solo** input, con il segnale di presenza acceso.
    @discardableResult
    private func sitStill(
        _ engine: inout SessionEngine,
        seconds: Double,
        presence: PresenceSignal?,
        step: Double = 10
    ) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var idle = 0.0
        while idle < seconds {
            idle += step
            events += engine.tick(
                elapsed: step, idle: idle, now: Self.workingHour,
                environment: EngineEnvironment(presence: presence)
            )
        }
        return events
    }

    // MARK: - Il caso Netflix

    /// 30 minuti di film senza toccare niente → la pausa **scatta**.
    func testWatchingAVideoStillTriggersABreak() {
        var engine = makeEngine()
        // 29 minuti: dal 2026-07-31 il preavviso sta dentro l'intervallo, non dopo.
        let events = sitStill(&engine, seconds: 29 * 60, presence: netflix)
        XCTAssertTrue(events.contains { if case .warningStarted = $0 { return true }; return false },
                      "il tempo davanti a un video deve contare come tempo sedentario")
        XCTAssertEqual(engine.phase, .warning)
    }

    /// Il polo negativo dello stesso minuto: **senza** il segnale, quei 30 minuti spariscono.
    /// Non fanno scattare niente, e da oggi non regalano nemmeno una pausa mai fatta.
    ///
    /// Fino al 27 luglio l'ultima riga di questo test asseriva l'opposto — al rientro arrivava una
    /// pausa piena accreditata — e serviva a mostrare la bugia che il segnale di presenza è venuto
    /// a correggere. La regola del 28 luglio, per cui un'assenza vale solo dopo della sedentarietà
    /// vera, toglie di mezzo anche quella: senza segnale il tempo non è mai stato contato come
    /// seduto, quindi non c'è niente da interrompere. Restano due errori possibili, e questo è il
    /// meno grave dei due: il numero tace invece di mentire.
    func testWithoutTheSignalTheHalfHourSimplyDisappears() {
        var engine = makeEngine()
        var events = sitStill(&engine, seconds: 30 * 60, presence: nil)
        XCTAssertFalse(events.contains { if case .warningStarted = $0 { return true }; return false },
                       "senza segnale, mezz'ora di immobilità non fa scattare niente")
        // Il credito si materializzerebbe al **rientro**: è lì che l'orologio dichiara quanto sei
        // stato via. Senza un tocco finale non c'è nessun evento da osservare.
        events += engine.tick(elapsed: 10, idle: 0.5, now: Self.workingHour)
        XCTAssertFalse(events.contains { if case .naturalBreak = $0 { return true }; return false },
                       "senza sedentarietà riconosciuta non si accredita nessuna pausa")
    }

    /// Leggere un PDF non è essersene andati.
    func testReadingADocumentCountsAsSedentaryTime() {
        var engine = makeEngine()
        sitStill(&engine, seconds: 10 * 60, presence: pdf)
        XCTAssertGreaterThan(engine.clock.activeSeconds, 9 * 60,
                             "dieci minuti di lettura sono dieci minuti seduto")
        XCTAssertEqual(engine.microsSinceLong, 0, "nessuna pausa naturale accreditata")
    }

    // MARK: - I tetti

    /// I tetti, sondati su entrambi i lati. Un segnale che non scade non è un segnale: basterebbe
    /// lasciare un PDF aperto e andare a pranzo per far contare il pranzo come lavoro.
    func testSignalsExpireAtTheirCapOnBothSides() {
        let engine = makeEngine()

        XCTAssertTrue(engine.presenceHolds(netflix, idle: PresenceCap.media - 60), "un film regge")
        XCTAssertFalse(engine.presenceHolds(netflix, idle: PresenceCap.media + 60), "oltre no")

        XCTAssertTrue(engine.presenceHolds(pdf, idle: PresenceCap.reading - 60))
        XCTAssertFalse(engine.presenceHolds(pdf, idle: PresenceCap.reading + 60))

        // Il documento scade prima del film, e non per gusto: leggere senza mai scrollare per un
        // quarto d'ora non è plausibile, guardare un film per 45 minuti sì.
        XCTAssertLessThan(PresenceCap.reading, PresenceCap.media)
        XCTAssertEqual(PresenceCap.reading, 15 * 60)
        XCTAssertEqual(PresenceCap.media, 45 * 60)
        XCTAssertFalse(engine.presenceHolds(pdf, idle: 16 * 60), "a 16 minuti il PDF ha smesso")
        XCTAssertTrue(engine.presenceHolds(netflix, idle: 16 * 60), "ma il film regge ancora")
        XCTAssertFalse(engine.presenceHolds(nil, idle: 10), "nessun segnale, nessuna presenza")
    }

    /// E l'orologio smette davvero di contare quando il segnale cade — misurato sull'orologio
    /// nudo, senza il motore intorno, perché lì una pausa scattata a metà prova falserebbe il
    /// conteggio e il verde non direbbe più niente.
    func testTheClockStopsCountingWhenTheSignalDrops() {
        var clock = ActivityClock(idleThreshold: 60, maxCredibleElapsed: 120)
        for i in 1...60 { clock.tick(elapsed: 30, idle: Double(i) * 30, presenceHolds: true) }
        let whileWatching = clock.activeSeconds
        XCTAssertEqual(whileWatching, 1800, accuracy: 1, "mezz'ora di film è mezz'ora seduto")

        for i in 61...80 { clock.tick(elapsed: 30, idle: Double(i) * 30, presenceHolds: false) }
        XCTAssertLessThanOrEqual(clock.activeSeconds, whileWatching,
                                 "caduto il segnale, il conteggio non sale più")
        XCTAssertTrue(clock.isIdle)
    }

    /// Il tranello più sottile: finito il film, tocchi il trackpad. Non ti sei assentato —
    /// eri lì tutto il tempo — quindi **non** ti spetta una pausa piena in regalo.
    func testReturningFromAVideoDoesNotCreditABreakYouNeverTook() {
        var engine = makeEngine()
        sitStill(&engine, seconds: PresenceCap.media + 5 * 60, presence: netflix, step: 30)
        let events = engine.tick(
            elapsed: 10, idle: 0.5, now: Self.workingHour,
            environment: EngineEnvironment(presence: netflix)
        )
        for event in events {
            if case .naturalBreak(let seconds, _) = event {
                XCTAssertLessThan(seconds, 5 * 60 + 60,
                                  "l'assenza vale solo da quando il segnale è scaduto, non da inizio film")
            }
        }
        XCTAssertEqual(engine.microsSinceLong, 0, "nessuna pausa piena regalata")
    }

    /// E l'assenza vera continua a funzionare come prima: nessun segnale, nessuna presenza.
    func testARealAbsenceStillCreditsANaturalBreak() {
        var engine = makeEngine()
        // Venti minuti di lavoro vero prima di alzarsi: senza sedentarietà non c'è niente da
        // interrompere, ed è la regola aggiunta il 28 luglio. Qui la cosa in prova è un'altra —
        // che un'assenza senza segnale di presenza resti un'assenza — quindi la premessa va data.
        for _ in 0..<120 { engine.tick(elapsed: 10, idle: 0, now: Self.workingHour) }
        var idle = 0.0
        var events: [EngineEvent] = []
        for _ in 0..<40 {
            idle += 10
            events += engine.tick(elapsed: 10, idle: idle, now: Self.workingHour)
        }
        events += engine.tick(elapsed: 10, idle: 0.5, now: Self.workingHour)
        XCTAssertTrue(events.contains { if case .naturalBreak = $0 { return true }; return false })
    }

    // MARK: - La call resta intoccabile

    /// Video sì, call no: è la regola esplicita. Con il microfono in uso il break si rimanda
    /// anche se il segnale di presenza dice che sei fermo davanti allo schermo.
    func testACallStillDefersEvenWithAPresenceSignal() {
        var engine = makeEngine()
        var idle = 0.0
        let inCall = EngineEnvironment(microphoneActive: true, presence: netflix)
        // Limite esplicito: un `while` senza tetto in un test non è un test, è un modo di far
        // pendere la suite per sempre. Costato una volta, il 2026-07-26, sabotando il segnale
        // di presenza: la condizione d'uscita non arrivava più e `swift test` non tornava.
        var ticks = 0
        while engine.phase == .working, ticks < 1000 {
            idle += 10
            ticks += 1
            engine.tick(elapsed: 10, idle: idle, now: Self.workingHour, environment: inCall)
        }
        XCTAssertLessThan(ticks, 1000, "il break non è mai arrivato: il segnale non regge")
        // preavviso → poi il break vorrebbe partire
        for _ in 0..<10 {
            idle += 10
            engine.tick(elapsed: 10, idle: idle, now: Self.workingHour, environment: inCall)
        }
        XCTAssertEqual(engine.phase, .postponed, "durante una call non si blocca lo schermo")
    }

    // MARK: - Il segnale mostrato

    func testTheDetectedSignalIsCarriedToTheBreakScreen() {
        var engine = makeEngine()
        sitStill(&engine, seconds: 60, presence: pdf)
        XCTAssertEqual(engine.lastPresence?.kind, .reading)
        XCTAssertEqual(engine.lastPresence?.detail, "relazione.pdf — Anteprima")
    }

    // MARK: - Riconoscimento dei documenti

    func testReadingExtensionsCoverWhatWasAsked() {
        for name in ["a.pdf", "b.doc", "c.docx", "d.pages", "e.md", "f.txt", "G.PDF", "h.rtf"] {
            XCTAssertTrue(ReadingDocument.isReadable(name), "\(name) dovrebbe contare")
        }
        for name in ["a.app", "b.dylib", "c", "d.sqlite", "e.plist", ""] {
            XCTAssertFalse(ReadingDocument.isReadable(name), "\(name) non dovrebbe contare")
        }
    }

    // MARK: - La classificazione, ramo per ramo

    /// Il difetto che questi test esistono per impedire, trovato dal principale il 2026-07-26:
    /// con una scheda di Brave che suonava **dietro**, il PDF che aveva **davanti** non veniva
    /// mai nemmeno guardato. L'audio era provato per primo e vinceva sempre.
    func testWhatYouHaveInFrontWinsOverWhatIsPlayingBehind() {
        let signal = PresenceClassifier.classify(
            frontmost: "com.apple.Preview",
            isPlayingAudio: false,          // Anteprima non suona: suona Brave, dietro
            document: "relazione.pdf",
            appName: "Anteprima"
        )
        XCTAssertEqual(signal?.kind, .reading)
        XCTAssertEqual(signal?.detail, "relazione.pdf — Anteprima")
        XCTAssertEqual(PresenceCap.seconds(for: .reading), 15 * 60, "e col tetto stretto")
    }

    /// Il test che rende l'ordine **falsificabile**, e la sua storia merita due righe.
    ///
    /// Il primo tentativo di provare la priorità non poteva fallire: usava Anteprima con l'audio
    /// spento, e in quel caso i due ordini danno la stessa risposta. Invertendo il codice restava
    /// verde — cioè non provava niente.
    ///
    /// Questo invece usa l'unico caso in cui i due ordini divergono davvero: un'app che è **sia**
    /// lettore **sia** player (Anteprima lo è, per le presentazioni a schermo intero) mentre sta
    /// producendo audio. Con la lettura per prima → `reading`, tetto stretto. Con il video per
    /// primo → `media`, tetto largo. Invertendo l'ordine nel codice, questo test diventa rosso.
    func testWhenAnAppIsBothReaderAndPlayerReadingWins() {
        let signal = PresenceClassifier.classify(
            frontmost: "com.apple.Preview",
            isPlayingAudio: true,
            document: "slide.pdf",
            appName: "Anteprima"
        )
        XCTAssertEqual(signal?.kind, .reading,
                       "hai un documento davanti: vale il tetto stretto, non quello del film")
        XCTAssertEqual(signal?.detail, "slide.pdf — Anteprima")
    }

    func testAPlayerInFrontThatIsActuallyPlayingIsVideo() {
        let signal = PresenceClassifier.classify(
            frontmost: "com.brave.Browser", isPlayingAudio: true,
            document: nil, appName: "Brave Browser"
        )
        XCTAssertEqual(signal?.kind, .media)
        XCTAssertEqual(signal?.detail, "video in riproduzione — Brave Browser")
    }

    /// Un browser davanti che non suona è lettura, non video: leggere un articolo lungo non
    /// deve essere scambiato per assenza.
    func testABrowserThatIsNotPlayingIsReading() {
        let signal = PresenceClassifier.classify(
            frontmost: "com.brave.Browser", isPlayingAudio: false,
            document: nil, appName: "Brave Browser"
        )
        XCTAssertEqual(signal?.kind, .reading)
        XCTAssertEqual(signal?.detail, "pagina web — Brave Browser")
    }

    func testAReaderWithoutARecognisedDocumentIsStillReading() {
        let signal = PresenceClassifier.classify(
            frontmost: "com.microsoft.Word", isPlayingAudio: false,
            document: nil, appName: "Microsoft Word"
        )
        XCTAssertEqual(signal?.kind, .reading)
        XCTAssertEqual(signal?.detail, "documento aperto in Microsoft Word")
    }

    /// Un terminale davanti non è né lettura né video: fermo lì significa assente davvero.
    func testEverythingElseIsNoPresence() {
        for id in ["com.googlecode.iterm2", "com.apple.Terminal", "com.apple.dt.Xcode", nil] {
            XCTAssertNil(PresenceClassifier.classify(
                frontmost: id, isPlayingAudio: false, document: nil, appName: "?"
            ), "\(id ?? "nil") non deve produrre presenza")
        }
    }

    /// E nemmeno un'app qualunque che sta suonando: se non è un player riconosciuto, non conta.
    func testAnUnknownAppPlayingAudioIsNotPresence() {
        XCTAssertNil(PresenceClassifier.classify(
            frontmost: "com.apple.Terminal", isPlayingAudio: true, document: nil, appName: "Terminale"
        ))
    }

    /// L'elenco chiuso è la protezione contro il caso `caffeinate`: uno strumento da riga di
    /// comando che tiene sveglio il Mac non è un film.
    func testOnlyKnownPlayersCount() {
        XCTAssertTrue(MediaPlayers.isPlayer("com.apple.Safari"))
        XCTAssertTrue(MediaPlayers.isPlayer("com.google.Chrome"))
        XCTAssertFalse(MediaPlayers.isPlayer("com.apple.Terminal"))
        XCTAssertFalse(MediaPlayers.isPlayer("com.googlecode.iterm2"))
        XCTAssertFalse(MediaPlayers.isPlayer("com.apple.dt.Xcode"))
        XCTAssertFalse(MediaPlayers.isPlayer(nil))
    }

    func testReaderAppsList() {
        XCTAssertTrue(ReaderApps.isReader("com.apple.Preview"))
        XCTAssertTrue(ReaderApps.isReader("com.microsoft.Word"))
        XCTAssertTrue(ReaderApps.isReader("md.obsidian"))
        XCTAssertFalse(ReaderApps.isReader("com.googlecode.iterm2"))
        XCTAssertFalse(ReaderApps.isReader(nil))
    }

    func testCapsAreLookedUpByKind() {
        XCTAssertEqual(PresenceCap.seconds(for: .media), PresenceCap.media)
        XCTAssertEqual(PresenceCap.seconds(for: .reading), PresenceCap.reading)
    }
}

/// La rotazione deve sopravvivere alla chiusura dell'app.
final class RotationPersistenceTests: XCTestCase {

    private func makeEngine() -> SessionEngine {
        var s = Settings()
        s.startDate = Date()
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Il difetto segnalato dal principale: riaprendo l'app la prima pausa era **sempre** la
    /// stessa, perché il contatore dei break ripartiva da zero. Qui si prova che riprende.
    func testRestoringContinuesTheRotationInsteadOfRestartingIt() {
        var first = makeEngine()
        var seen: [ExerciseKind] = []
        for _ in 0..<2 {
            first.forceBreakNow(now: Date())
            if let plan = first.plan { seen.append(plan.exercise.kind) }
            first.markExerciseDone()
            // chiude comunque il break, esercizio o meno
            first.tick(elapsed: 1, idle: 0, now: Date())
            if first.phase == .breaking {
                first.tick(elapsed: 400, idle: 400, now: Date())
            }
        }
        let snapshot = first.snapshot
        XCTAssertGreaterThanOrEqual(snapshot.breakIndex, 2)

        // Nuova esecuzione: senza ripristino ripartirebbe dal primo esercizio.
        var reopened = makeEngine()
        XCTAssertEqual(reopened.snapshot.breakIndex, 0)
        reopened.restore(snapshot)
        reopened.forceBreakNow(now: Date())

        XCTAssertEqual(reopened.breakIndex, snapshot.breakIndex + 1)
        XCTAssertFalse(seen.isEmpty)
        XCTAssertNotEqual(reopened.plan?.exercise.kind, seen.first,
                          "dopo il ripristino non deve ripresentare il primo esercizio di sempre")
    }

    func testSnapshotSurvivesADiskRoundTrip() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-rot-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let snapshot = EngineSnapshot(breakIndex: 17, microsSinceLong: 2)
        XCTAssertTrue(RotationStore.save(snapshot, to: url))
        let loaded = RotationStore.load(from: url)
        XCTAssertEqual(loaded?.breakIndex, 17)
        XCTAssertEqual(loaded?.microsSinceLong, 2)
    }

    func testMissingRotationFileIsNotAnError() {
        XCTAssertNil(RotationStore.load(from: URL(fileURLWithPath: "/tmp/otium-none-\(UUID().uuidString).json")))
    }

    /// Un valore incoerente sul disco non deve mandare fuori giri il ciclo micro/micro/piena.
    func testRestoreClampsAbsurdValues() {
        var engine = makeEngine()
        engine.restore(EngineSnapshot(breakIndex: -5, microsSinceLong: 99))
        XCTAssertEqual(engine.breakIndex, 0)
        XCTAssertLessThan(engine.microsSinceLong, engine.settings.cadence.longEveryNBreaks)
    }
}
