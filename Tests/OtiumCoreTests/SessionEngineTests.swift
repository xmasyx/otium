import XCTest
@testable import OtiumCore

final class SessionEngineTests: XCTestCase {

    /// Un martedì alle 10:00 — dentro le ore attive, così l'orario non è mai la variabile
    /// nascosta che fa passare o fallire un test.
    static let workingHour: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 28; c.hour = 10; c.minute = 0
        return Calendar.current.date(from: c)!
    }()

    static let night: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 28; c.hour = 3; c.minute = 0
        return Calendar.current.date(from: c)!
    }()

    private func makeEngine(_ settings: Settings? = nil) -> SessionEngine {
        var s = settings ?? Settings()
        s.startDate = Self.workingHour        // settimana 0 della rampa
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    @discardableResult
    private func advance(
        _ engine: inout SessionEngine,
        seconds: Double,
        step: Double = 10,
        idle: Double = 0,
        now: Date = SessionEngineTests.workingHour,
        env: EngineEnvironment = .quiet
    ) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var t = 0.0
        while t < seconds {
            events += engine.tick(elapsed: step, idle: idle, now: now, environment: env)
            t += step
        }
        return events
    }

    /// Porta il motore fino allo schermo coperto e restituisce il piano del break.
    @discardableResult
    private func reachBreak(_ engine: inout SessionEngine, env: EngineEnvironment = .quiet) -> BreakPlan? {
        advance(&engine, seconds: engine.settings.cadence.intervalSeconds, env: env)
        // Passo fine sul preavviso: così il break comincia con il cronometro quasi a zero, e i
        // test sul tempo minimo misurano l'esercizio, non l'avanzo del tick.
        advance(&engine, seconds: engine.settings.cadence.warningSeconds + 1, step: 1, env: env)
        return engine.plan
    }

    /// Esegue l'esercizio rispettando il tempo minimo, e chiude il break.
    /// Esegue l'esercizio, aspetta che la pausa finisca e **preme per tornare al lavoro**:
    /// dal 2026-07-27 la pausa non si chiude più da sola.
    private func performExercise(_ engine: inout SessionEngine) {
        guard let plan = engine.plan else { return XCTFail("nessun break in corso") }
        advance(&engine, seconds: plan.exercise.minimumSeconds + 10, step: 1)
        engine.markExerciseDone()
        advance(&engine, seconds: plan.duration + 10, step: 5)
        engine.returnToWork()
    }

    // MARK: - Quando scatta

    func testNoBreakBeforeTheInterval() {
        var engine = makeEngine()
        let events = advance(&engine, seconds: 29 * 60)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(engine.phase, .working)
    }

    /// ISC-7 — prima del blocco arriva il preavviso.
    func testWarningFiresAtTheInterval() {
        var engine = makeEngine()
        let events = advance(&engine, seconds: 30 * 60)
        XCTAssertEqual(engine.phase, .warning)
        guard case .warningStarted = events.last else {
            return XCTFail("atteso warningStarted, ricevuto \(String(describing: events.last))")
        }
        XCTAssertEqual(engine.timer, 60, accuracy: 10)
    }

    func testBreakStartsAfterTheWarning() {
        var engine = makeEngine()
        advance(&engine, seconds: 30 * 60)
        let events = advance(&engine, seconds: 70)
        XCTAssertEqual(engine.phase, .breaking)
        XCTAssertTrue(events.contains { if case .breakStarted = $0 { return true }; return false })
    }

    /// ISC-6 — la sequenza dell'opzione A: micro, micro, piena.
    func testCadenceASequenceIsMicroMicroLong() {
        var engine = makeEngine()
        var kinds: [BreakKind] = []
        for _ in 0..<6 {
            guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
            kinds.append(plan.kind)
            performExercise(&engine)
            XCTAssertEqual(engine.phase, .working)
        }
        XCTAssertEqual(kinds, [.micro, .micro, .long, .micro, .micro, .long])
    }

    /// ISC-1 — il contatore è sul tempo attivo: fermo, non arriva nessun break.
    func testIdleTimeNeverTriggersABreak() {
        var engine = makeEngine()
        for i in 0..<400 {
            engine.tick(elapsed: 10, idle: 60 + Double(i * 10), now: Self.workingHour)
        }
        XCTAssertEqual(engine.phase, .working)
        XCTAssertNil(engine.plan)
    }

    // MARK: - Pause spontanee

    /// ISC-2 — alzarsi da soli conta come micro-pausa.
    func testNaturalBreakCreditsTheMicro() {
        var engine = makeEngine()
        advance(&engine, seconds: 20 * 60)
        for i in 0..<20 { engine.tick(elapsed: 10, idle: 60 + Double(i * 10), now: Self.workingHour) }
        let events = engine.tick(elapsed: 10, idle: 0.5, now: Self.workingHour)

        guard case .naturalBreak(_, let creditedLong)? = events.first else {
            return XCTFail("atteso naturalBreak, ricevuto \(events)")
        }
        XCTAssertFalse(creditedLong)
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 1)
        XCTAssertEqual(engine.microsSinceLong, 1)
    }

    /// ISC-3 — un'assenza di almeno cinque minuti vale come pausa piena.
    func testLongAbsenceCreditsTheLongBreak() {
        var engine = makeEngine()
        advance(&engine, seconds: 20 * 60)
        engine.tick(elapsed: 10, idle: 400, now: Self.workingHour)
        let events = engine.tick(elapsed: 10, idle: 0.5, now: Self.workingHour)

        guard case .naturalBreak(let seconds, let creditedLong)? = events.first else {
            return XCTFail("atteso naturalBreak, ricevuto \(events)")
        }
        XCTAssertGreaterThanOrEqual(seconds, 300)
        XCTAssertTrue(creditedLong)
        XCTAssertEqual(engine.microsSinceLong, 0)
    }

    // MARK: - La notte del 28 luglio 2026

    /// **Il caso vero, riprodotto.** Coperchio chiuso, nessuno davanti: macOS si sveglia da solo
    /// ogni quarto d'ora, e prima ogni risveglio scriveva un'interruzione della sedentarietà.
    /// Fra le 02:14 e le 10:27 ne ha scritte 47. Adesso deve scriverne zero.
    func testNightOfWakeUpsWritesNoInterruptions() {
        var engine = makeEngine()
        var events: [EngineEvent] = []
        for _ in 0..<37 {
            // Un risveglio: un salto di un quarto d'ora fra due battiti, con l'inattività alta
            // perché nessuno ha toccato niente.
            events += engine.tick(elapsed: 927, idle: 927, now: Self.night)
        }
        let natural = events.filter { if case .naturalBreak = $0 { return true }; return false }
        XCTAssertTrue(natural.isEmpty, "un Mac chiuso ha prodotto \(natural.count) interruzioni")
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 0.001)
    }

    /// Il polo positivo dello stesso confine: se hai lavorato davvero e poi chiudi il Mac e te ne
    /// vai, quella pausa è tua e va scritta. Senza questo test la correzione qui sopra si
    /// chiuderebbe anche non contando mai niente.
    func testSuspensionAfterRealWorkStillCounts() {
        var engine = makeEngine()
        advance(&engine, seconds: 20 * 60)
        let events = engine.tick(elapsed: 3600, idle: 3600, now: Self.workingHour)

        guard case .naturalBreak(let seconds, let creditedLong)? = events.first else {
            return XCTFail("atteso naturalBreak, ricevuto \(events)")
        }
        XCTAssertEqual(seconds, 3600, accuracy: 1)
        XCTAssertTrue(creditedLong)
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 0.001)
    }

    /// Lo stesso confine sul ramo di tutti i giorni: due minuti di lavoro non sono una seduta
    /// prolungata, quindi alzarsi non interrompe niente.
    func testAbsenceWithoutSedentaryTimeIsNotAnInterruption() {
        var engine = makeEngine()
        advance(&engine, seconds: 2 * 60)
        engine.tick(elapsed: 10, idle: 400, now: Self.workingHour)
        let events = engine.tick(elapsed: 10, idle: 0.5, now: Self.workingHour)

        let natural = events.filter { if case .naturalBreak = $0 { return true }; return false }
        XCTAssertTrue(natural.isEmpty, "assenza senza sedentarietà contata come interruzione")
    }

    /// Un'assenza troppo breve non compra niente.
    func testShortAbsenceDoesNotCreditABreak() {
        var engine = makeEngine()
        advance(&engine, seconds: 20 * 60)
        let beforeActive = engine.clock.activeSeconds
        engine.tick(elapsed: 10, idle: 70, now: Self.workingHour)
        let events = engine.tick(elapsed: 10, idle: 0.5, now: Self.workingHour)
        XCTAssertTrue(events.isEmpty)
        XCTAssertGreaterThan(engine.clock.activeSeconds, beforeActive - 120)
    }

    // MARK: - Esercizio

    /// ISC-15 — "fatto" prima del tempo minimo non è "fatto".
    func testDoneButtonIsDeadBeforeTheMinimumTime() {
        var engine = makeEngine()
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        XCTAssertGreaterThan(plan.exercise.minimumSeconds, 5)
        XCTAssertGreaterThan(engine.secondsUntilCanFinish, 0, "il cancello dev'essere chiuso")

        XCTAssertFalse(engine.canFinishNow)
        let events = engine.markExerciseDone()
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(engine.phase, .breaking, "lo schermo deve restare coperto")

        advance(&engine, seconds: engine.secondsUntilCanFinish + 2, step: 1)
        XCTAssertTrue(engine.canFinishNow)
        engine.markExerciseDone()

        // Contratto cambiato il 2026-07-27 su richiesta del principale: la micro-pausa **dura
        // i suoi 90 secondi**. Prima finiva appena premevi "fatto" — 7 dip su sedia sono 18
        // secondi, e una pausa "da 90 secondi" ne durava 18. Il numero nelle preferenze e quello
        // vissuto devono coincidere.
        XCTAssertEqual(engine.phase, .breaking, "l'esercizio è fatto, la pausa no")
        advance(&engine, seconds: plan.duration, step: 5)
        XCTAssertTrue(engine.canReturnToWork, "a tempo scaduto il pulsante si accende")
        engine.returnToWork()
        XCTAssertEqual(engine.phase, .working)
    }

    /// Il pulsante non è cliccabile prima del tempo, nemmeno con l'esercizio già fatto.
    func testReturnButtonStaysLockedUntilTheWholeBreakHasElapsed() {
        var engine = makeEngine()
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        advance(&engine, seconds: plan.exercise.minimumSeconds + 2, step: 1)
        engine.markExerciseDone()

        XCTAssertFalse(engine.canReturnToWork, "esercizio fatto ma la pausa non è finita")
        XCTAssertTrue(engine.returnToWork().isEmpty)
        XCTAssertEqual(engine.phase, .breaking)

        advance(&engine, seconds: engine.secondsLeftOfBreak + 2, step: 1)
        XCTAssertTrue(engine.canReturnToWork)
        XCTAssertFalse(engine.returnToWork().isEmpty)
        XCTAssertEqual(engine.phase, .working)
    }

    /// E nemmeno a tempo scaduto se l'esercizio non è stato fatto.
    func testReturnButtonStaysLockedWithoutTheExercise() {
        var engine = makeEngine()
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        advance(&engine, seconds: plan.duration + 20, step: 5)
        XCTAssertFalse(engine.canReturnToWork, "il tempo passa, l'esercizio no")
        XCTAssertEqual(engine.phase, .breaking)
    }

    /// La micro-pausa dura quanto dice di durare, anche facendo l'esercizio in un lampo.
    func testAMicroBreakLastsItsFullDeclaredDuration() {
        var engine = makeEngine()
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        XCTAssertEqual(plan.kind, .micro)
        XCTAssertEqual(plan.duration, 90)
        XCTAssertLessThan(plan.exercise.minimumSeconds, 60, "l'esercizio è più corto della pausa")

        advance(&engine, seconds: plan.exercise.minimumSeconds + 2, step: 1)
        engine.markExerciseDone()
        XCTAssertEqual(engine.phase, .breaking)
        XCTAssertGreaterThan(engine.secondsLeftOfBreak, 20, "restano i secondi della pausa")

        advance(&engine, seconds: engine.secondsLeftOfBreak + 5, step: 1)
        engine.returnToWork()
        XCTAssertEqual(engine.phase, .working)
    }

    /// L'uscita d'emergenza: immediata, ma **contata e segnalata** come tale.
    func testEmergencyExitIsImmediateAndRecorded() {
        var engine = makeEngine()
        reachBreak(&engine)
        let events = engine.emergencyExit()
        XCTAssertEqual(engine.phase, .working)
        XCTAssertTrue(events.contains {
            if case .breakSkipped(_, let reason) = $0 { return reason == .emergency }
            return false
        }, "deve risultare come uscita d'emergenza, non come una pausa qualunque")
    }

    /// La pausa piena pretende anche il suo tempo: l'esercizio non compra l'uscita anticipata.
    func testLongBreakRequiresItsFullDurationEvenAfterTheExercise() {
        var engine = makeEngine()
        for _ in 0..<2 {                      // due micro, poi tocca la piena
            reachBreak(&engine)
            performExercise(&engine)
        }
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        XCTAssertEqual(plan.kind, .long)

        advance(&engine, seconds: plan.exercise.minimumSeconds + 5, step: 1)
        engine.markExerciseDone()
        XCTAssertEqual(engine.phase, .breaking, "manca ancora il recupero")

        advance(&engine, seconds: plan.duration)
        engine.returnToWork()
        XCTAssertEqual(engine.phase, .working)
    }

    /// ISC-17 — la pausa piena porta il bout vigoroso (la dose VILPA).
    func testLongBreakUsesAVigorousExercise() {
        var engine = makeEngine()
        for _ in 0..<2 { reachBreak(&engine); performExercise(&engine) }
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        XCTAssertTrue(plan.exercise.kind.isVigorous)
    }

    // MARK: - Rinvii, call, orari

    /// ISC-8 — un rinvio, non due.
    func testOnlyOnePostponeIsAllowed() {
        var engine = makeEngine()
        advance(&engine, seconds: 30 * 60)
        XCTAssertTrue(engine.canPostpone)
        XCTAssertFalse(engine.postpone().isEmpty)
        XCTAssertEqual(engine.phase, .postponed)

        advance(&engine, seconds: 130)
        XCTAssertEqual(engine.phase, .breaking)
        XCTAssertFalse(engine.canPostpone)
        XCTAssertTrue(engine.postpone().isEmpty)
        XCTAssertEqual(engine.phase, .breaking)
    }

    /// ISC-9 — microfono in uso: si rimanda, non si blocca.
    func testBreakIsDeferredWhileTheMicrophoneIsInUse() {
        var engine = makeEngine()
        let inCall = EngineEnvironment(microphoneActive: true)
        advance(&engine, seconds: 30 * 60, env: inCall)
        let events = advance(&engine, seconds: 70, env: inCall)

        XCTAssertEqual(engine.phase, .postponed)
        XCTAssertTrue(events.contains { if case .autoDeferred = $0 { return true }; return false })
    }

    /// …ma non all'infinito: dopo N rinvii automatici il break arriva comunque.
    func testDeferralsAreBoundedByMaxAutoDefers() {
        var s = Settings()
        s.maxAutoDefers = 2
        s.autoDeferSeconds = 60
        var engine = makeEngine(s)
        let inCall = EngineEnvironment(microphoneActive: true)

        advance(&engine, seconds: 30 * 60, env: inCall)
        advance(&engine, seconds: 70, env: inCall)
        for _ in 0..<3 { advance(&engine, seconds: 70, env: inCall) }
        XCTAssertEqual(engine.phase, .breaking)
    }

    /// Fuori dalle ore attive Otium non interrompe.
    func testNoBreakOutsideActiveHours() {
        var engine = makeEngine()
        advance(&engine, seconds: 30 * 60, now: Self.night)
        let events = advance(&engine, seconds: 70, now: Self.night)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertTrue(events.contains {
            if case .breakSkipped(_, let reason) = $0 { return reason == .outOfHours }
            return false
        })
    }

    // MARK: - Uscita di sicurezza

    /// ISC-19 — la frase esatta, o niente.
    func testEscapeRequiresTheExactPhrase() {
        var engine = makeEngine()
        reachBreak(&engine)

        XCTAssertTrue(engine.escape(phrase: "salto").isEmpty)
        XCTAssertTrue(engine.escape(phrase: "").isEmpty)
        XCTAssertEqual(engine.phase, .breaking)

        let events = engine.escape(phrase: "  Salto La Pausa  ")   // spazi e maiuscole perdonati
        XCTAssertEqual(engine.phase, .working)
        XCTAssertTrue(events.contains {
            if case .breakSkipped(_, let reason) = $0 { return reason == .escapePhrase }
            return false
        })
    }

    /// ISC-20 — se non c'è nessuno davanti al Mac, il blocco cade da solo, e quella è una
    /// pausa **vera**: si registra come naturale, non come saltata.
    func testBlockReleasesWhenNobodyIsThere() {
        var engine = makeEngine()
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        let events = advance(&engine, seconds: 30,
                             idle: SessionEngine.absentThreshold(for: plan) + 5)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertTrue(events.contains {
            if case .naturalBreak = $0 { return true }
            return false
        })
        XCTAssertFalse(events.contains {
            if case .breakSkipped = $0 { return true }
            return false
        })
    }

    /// Il polo opposto, ed è il difetto che questa soglia esiste per uccidere: durante la pausa
    /// **piena** ti si chiede di stare tre minuti lontano dallo schermo. Quei tre minuti di
    /// silenzio non devono annullare la pausa che stai facendo bene.
    func testStandingAwayDuringALongBreakDoesNotCancelIt() {
        var engine = makeEngine()
        for _ in 0..<2 { reachBreak(&engine); performExercise(&engine) }
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break") }
        XCTAssertEqual(plan.kind, .long)

        advance(&engine, seconds: plan.exercise.minimumSeconds + 2, step: 1)
        engine.markExerciseDone()

        // Tre minuti in piedi, senza toccare niente: è esattamente ciò che l'app ha chiesto.
        var idle = 0.0
        var events: [EngineEvent] = []
        while engine.phase == .breaking, idle < 400, !engine.canReturnToWork {
            idle += 10
            events += engine.tick(elapsed: 10, idle: idle, now: Self.workingHour)
        }
        XCTAssertTrue(engine.canReturnToWork,
                      "la pausa piena arriva in fondo: i tre minuti in piedi non l'annullano")
        events += engine.returnToWork()
        XCTAssertTrue(events.contains { if case .breakCompleted = $0 { return true }; return false })
    }

    /// ISC-20 — e comunque esiste un tetto assoluto: nessuno schermo resta coperto per sempre.
    func testFailsafeCeilingReleasesTheBlock() {
        var engine = makeEngine()
        reachBreak(&engine)
        // Input continuo (nessuno se n'è andato), esercizio mai eseguito.
        let events = advance(&engine, seconds: SessionEngine.failsafeCeiling + 60, step: 30, idle: 1)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertTrue(events.contains {
            if case .breakSkipped(_, let reason) = $0 { return reason == .failsafe }
            return false
        })
    }

    // MARK: - Sospensione manuale

    func testPauseStopsEverythingAndResumeStartsClean() {
        var engine = makeEngine()
        advance(&engine, seconds: 20 * 60)
        engine.setPaused(true)
        advance(&engine, seconds: 60 * 60)
        XCTAssertEqual(engine.phase, .paused)
        XCTAssertNil(engine.plan)

        engine.setPaused(false)
        XCTAssertEqual(engine.phase, .working)
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 0.001)
    }

    /// Il caso vero, segnalato il 2026-07-27: sospendi, ti dimentichi di riprendere, e quando te
    /// ne accorgi dichiari «sono al computer da 20 minuti». Il conto deve dire 10 minuti alla
    /// prossima pausa, non 30.
    ///
    /// Prima falliva perché `setPaused(false)` azzerava l'orologio **dopo** la dichiarazione:
    /// i 20 minuti dichiarati venivano cancellati dalla ripresa, in silenzio.
    func testDeclaringTimeWhileSuspendedResumesInsteadOfLosingIt() {
        var engine = makeEngine()
        engine.setPaused(true)

        engine.declareTimeAlreadySeated(20 * 60, mode: .total)

        XCTAssertEqual(engine.phase, .working, "dichiarare di essere al computer riprende l'app")
        XCTAssertEqual(engine.clock.activeSeconds, 20 * 60, accuracy: 0.001)
        XCTAssertEqual(engine.secondsUntilNextBreak, 10 * 60, accuracy: 0.001,
                       "30 minuti di intervallo meno i 20 dichiarati")
    }

    /// L'altro verso della stessa moneta: una ripresa **senza** dichiarazione riparte pulita,
    /// perché una sospensione di due ore non è lavoro. Se questo test cade, la correzione sopra
    /// ha rotto il comportamento normale.
    func testResumingWithoutDeclaringStillStartsFromZero() {
        var engine = makeEngine()
        advance(&engine, seconds: 20 * 60)
        engine.setPaused(true)
        engine.setPaused(false)
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 0.001)
    }

    /// Cambiare preferenze a metà mattina non deve buttare via il lavoro già contato.
    func testChangingSettingsKeepsTheAccumulatedTime() {
        var engine = makeEngine()
        advance(&engine, seconds: 15 * 60)
        let before = engine.clock.activeSeconds
        engine.settings.escapePhrase = "basta"
        XCTAssertEqual(engine.clock.activeSeconds, before, accuracy: 0.001)
    }

    /// **L'uscita d'emergenza vale anche a esercizio già fatto.**
    ///
    /// Dal 2026-07-29 la pausa ha due facce, e la seconda disegna un'altra schermata: la richiesta
    /// esplicita del principale è che da lì si esca comunque. I pulsanti li ho guardati nei pixel,
    /// ma «i pulsanti ci sono» e «premerli funziona» sono due affermazioni diverse, e questa è
    /// quella che conta nel momento in cui ti serve davvero uscire.
    func testEmergencyExitStillWorksAfterTheExerciseIsDone() {
        var engine = makeEngine()
        guard let plan = reachBreak(&engine) else { return XCTFail("nessun break in corso") }
        advance(&engine, seconds: plan.exercise.minimumSeconds + 10, step: 1)
        engine.markExerciseDone()
        XCTAssertTrue(engine.exerciseDone, "l'esercizio non risulta fatto: il test proverebbe altro")
        XCTAssertEqual(engine.phase, .breaking, "la pausa deve essere ancora in corso")

        let events = engine.emergencyExit()
        XCTAssertFalse(events.isEmpty, "l'uscita d'emergenza non produce nulla nella fase di riposo")
        XCTAssertNotEqual(engine.phase, .breaking, "lo schermo resterebbe coperto")
    }
}
