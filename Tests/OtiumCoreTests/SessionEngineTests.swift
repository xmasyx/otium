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
        // Il preavviso sta **dentro** l'intervallo (2026-07-31): si arriva alla soglia del
        // preavviso, poi lo si consuma. In tutto fa `intervalSeconds`, che e' la promessa.
        advance(&engine, seconds: engine.settings.cadence.intervalSeconds
                                - engine.settings.cadence.warningSeconds, env: env)
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
        // 28 minuti: il preavviso parte al 29esimo, perche' sta dentro i 30.
        let events = advance(&engine, seconds: 28 * 60)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(engine.phase, .working)
    }

    /// ISC-7 — prima del blocco arriva il preavviso, **un minuto prima dell'intervallo**.
    func testWarningFiresAtTheInterval() {
        var engine = makeEngine()
        let events = advance(&engine, seconds: 29 * 60)
        XCTAssertEqual(engine.phase, .warning)
        guard case .warningStarted = events.last else {
            return XCTFail("atteso warningStarted, ricevuto \(String(describing: events.last))")
        }
        XCTAssertEqual(engine.timer, 60, accuracy: 10)
    }

    func testBreakStartsAfterTheWarning() {
        var engine = makeEngine()
        advance(&engine, seconds: 29 * 60)
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
        advance(&engine, seconds: 29 * 60, env: inCall)     // preavviso: sta dentro i 30
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
        advance(&engine, seconds: 29 * 60, now: Self.night)   // preavviso: sta dentro i 30
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

    /// **L'esercizio del turno esce sempre dal tuo elenco. Le alternative no, ed è giusto così.**
    ///
    /// La regola, con le parole del principale (2026-07-30): *«l'opzione più semplice può essere
    /// proposta come sostituzione, ma se non è nel pool mai come esercizio»*. Sono due ruoli
    /// diversi per lo stesso elenco, e il primo tentativo di correzione li aveva confusi:
    /// avevo filtrato anche le sostituzioni, cioè tolto la via d'uscita verso il gesto più facile
    /// proprio nel momento in cui serve — dentro una pausa che non riesci a fare.
    ///
    /// Questo test tiene ferma la metà che conta, su una rotazione lunga e non su un turno solo:
    /// una casella tolta non può tornare come esercizio proposto, mai.
    func testTheTurnExerciseAlwaysComesFromThePool() {
        var s = Settings()
        s.sex = .male
        s.pushVariant = .pushUp
        s.exercisePool = [.pushUp, .diamondPushUp, .archerPushUp, .pikePushUp, .benchDip]
        var engine = makeEngine(s)

        var visti: Set<ExerciseKind> = []
        for turno in 0..<24 {
            guard let plan = reachBreak(&engine) else { return XCTFail("nessun break al turno \(turno)") }
            let ammessi = plan.kind == .long ? s.exercisePool + s.vigorousPool : s.exercisePool
            XCTAssertTrue(ammessi.contains(plan.exercise.kind),
                          "turno \(turno): propone \(plan.exercise.kind), che non è nell'elenco scelto")
            visti.insert(plan.exercise.kind)
            performExercise(&engine)
        }
        XCTAssertFalse(visti.contains(.inclinePushUp), "gli inclinati sono arrivati come esercizio del turno")
        // Se la rotazione girasse su un esercizio solo, il test sopra passerebbe senza provare nulla.
        XCTAssertGreaterThan(visti.count, 2, "la rotazione non gira: il test non sta provando niente")
    }

    /// L'altra metà, quella che il primo tentativo aveva rotto: **la sostituzione più facile resta
    /// offerta anche se non è nell'elenco**, perché serve dentro la pausa e non alla prossima.
    func testVariantsStillOfferTheEasierWayOut() {
        var s = Settings()
        s.exercisePool = [.pushUp, .diamondPushUp, .archerPushUp, .pikePushUp, .benchDip]
        var engine = makeEngine(s)
        guard reachBreak(&engine) != nil else { return XCTFail("nessun break in corso") }
        engine.swapExercise(to: .pushUp, now: SessionEngineTests.workingHour, force: true)

        let offerte = engine.variants(now: SessionEngineTests.workingHour).map(\.kind)
        XCTAssertTrue(offerte.contains(.kneePushUp),
                      "la regressione sulle ginocchia non è più offerta come sostituzione")
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

// MARK: - ISC-96 — la prima pausa della giornata

/// **Il caso vero del 31 luglio 2026.** Il principale apre il Mac, lavora mezz'ora, e la prima
/// pausa della giornata è quella piena da cinque minuti. Il ciclo micro/micro/piena viveva solo in
/// `rotation.json` e non sapeva che fosse cambiato il giorno: il 30 luglio si era chiuso con due
/// micro alle spalle (14:51 e 15:25, lette dal registro vero), quindi la pausa dopo — la prima del
/// giorno nuovo — è arrivata piena.
///
/// Ogni test qui ha il suo **polo di controllo nello stesso giorno**: se il ciclo si azzerasse
/// sempre, o non si azzerasse mai, una delle due metà diventerebbe rossa.
final class NewDayCycleTests: XCTestCase {

    private static func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = day; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func makeEngine() -> SessionEngine {
        var s = Settings()
        s.startDate = Self.at(1, 10)          // rampa finita: le ripetizioni non c'entrano qui
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Riporta il motore com'era alla chiusura del 30 luglio: due micro fatte, ultima alle 17.
    private func engineClosedYesterdayWithTwoMicros() -> SessionEngine {
        var engine = makeEngine()
        engine.restore(EngineSnapshot(breakIndex: 82, microsSinceLong: 2, launchCount: 146,
                                      activeSeconds: 0,
                                      lastBreakAt: Self.at(30, 17),
                                      savedAt: Self.at(30, 17, 30)),
                       now: Self.at(31, 11))
        return engine
    }

    /// Il polo verde: giorno nuovo, la prima è breve.
    func testFirstBreakOfANewDayIsMicro() {
        var engine = engineClosedYesterdayWithTwoMicros()
        XCTAssertEqual(engine.microsSinceLong, 2, "il ciclo di ieri è stato ripreso davvero")

        let events = engine.forceBreakNow(now: Self.at(31, 11))
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(engine.plan?.kind, .micro,
                       "la prima pausa della giornata è breve, non cinque minuti")
    }

    /// **Il polo rosso, ed è quello che rende il test una prova.** Stesso stato identico, unica
    /// differenza il giorno di `now`: restando dentro il 30 luglio la pausa piena deve arrivare,
    /// o il "verde" qui sopra vorrebbe dire soltanto che il ciclo non funziona più.
    func testSameDayTheCycleStillDeliversTheLongBreak() {
        var engine = makeEngine()
        engine.restore(EngineSnapshot(breakIndex: 82, microsSinceLong: 2, launchCount: 146,
                                      activeSeconds: 0,
                                      lastBreakAt: Self.at(30, 15, 25),
                                      savedAt: Self.at(30, 15, 30)),
                       now: Self.at(30, 16))

        engine.forceBreakNow(now: Self.at(30, 16))
        XCTAssertEqual(engine.plan?.kind, .long,
                       "nello stesso giorno dopo due micro tocca la piena")
    }

    /// L'annuncio dell'interfaccia e la pausa che arriva devono dire la stessa cosa: se
    /// `nextBreakKind` non guardasse il giorno, il menu prometterebbe cinque minuti e ne
    /// arriverebbero novanta secondi.
    func testTheAnnouncedKindMatchesWhatArrives() {
        var engine = engineClosedYesterdayWithTwoMicros()
        let announced = engine.nextBreakKind(now: Self.at(31, 11))
        engine.forceBreakNow(now: Self.at(31, 11))
        XCTAssertEqual(announced, engine.plan?.kind)
        XCTAssertEqual(announced, .micro)
    }

    /// **Anti-claim.** Il giorno nuovo azzera il ciclo micro/piena e **nient'altro**: la rotazione
    /// degli esercizi va avanti. Senza questa, si tornerebbe a squat-squat-squat ogni mattina —
    /// il difetto del 26 luglio, rientrato dalla finestra.
    func testANewDayDoesNotResetTheExerciseRotation() {
        var engine = engineClosedYesterdayWithTwoMicros()
        engine.forceBreakNow(now: Self.at(31, 11))
        XCTAssertEqual(engine.breakIndex, 83, "la rotazione riprende da dov'era, non da zero")
        XCTAssertEqual(engine.plan?.index, 83)
    }

    /// Una giornata intera, e la sua forma: breve, breve, piena — e il giorno dopo si ricomincia
    /// da breve invece di continuare il conto di ieri.
    func testTwoDaysInARowEachStartShort() {
        var engine = makeEngine()
        var kinds: [BreakKind] = []
        for hour in [9, 10, 11, 12] {
            engine.forceBreakNow(now: Self.at(30, hour))
            kinds.append(engine.plan!.kind)
            engine.emergencyExit()
        }
        XCTAssertEqual(kinds, [.micro, .micro, .long, .micro], "il 30 luglio")

        kinds = []
        for hour in [9, 10, 11] {
            engine.forceBreakNow(now: Self.at(31, hour))
            kinds.append(engine.plan!.kind)
            engine.emergencyExit()
        }
        XCTAssertEqual(kinds, [.micro, .micro, .long],
                       "il 31 riparte da capo: la quarta micro di ieri non si trascina")
    }

    /// Le pause spontanee datano la giornata come quelle imposte. Senza, tre alzate stamattina
    /// resterebbero appese a ieri e la prima pausa imposta le butterebbe via azzerando il ciclo.
    func testNaturalBreaksAlsoStampTheDay() {
        var engine = makeEngine()
        engine.restore(EngineSnapshot(breakIndex: 10, microsSinceLong: 0, launchCount: 1,
                                      activeSeconds: 0,
                                      lastBreakAt: Self.at(30, 18),
                                      savedAt: Self.at(30, 18)),
                       now: Self.at(31, 9))

        // Mezz'ora di lavoro vero, poi due assenze da micro-pausa: oggi, non ieri.
        for _ in 0..<40 { engine.tick(elapsed: 10, idle: 0, now: Self.at(31, 9)) }
        engine.tick(elapsed: 10, idle: 100, now: Self.at(31, 9))
        engine.tick(elapsed: 10, idle: 0.5, now: Self.at(31, 9))
        XCTAssertEqual(engine.microsSinceLong, 1, "una micro spontanea, contata oggi")

        for _ in 0..<40 { engine.tick(elapsed: 10, idle: 0, now: Self.at(31, 10)) }
        engine.tick(elapsed: 10, idle: 100, now: Self.at(31, 10))
        engine.tick(elapsed: 10, idle: 0.5, now: Self.at(31, 10))
        XCTAssertEqual(engine.microsSinceLong, 2, "due")

        // La terza pausa della giornata è la piena, perché le prime due sono di oggi e restano.
        engine.forceBreakNow(now: Self.at(31, 11))
        XCTAssertEqual(engine.plan?.kind, .long,
                       "le pause spontanee di oggi non vengono buttate via dal cambio di giorno")
    }

    /// Il file scritto dalla versione precedente non ha il campo: deve valere «l'ultima pausa
    /// risale al salvataggio», non «non c'è mai stata una pausa». Altrimenti il difetto
    /// sopravvivrebbe a se stesso per tutta la prima giornata dopo l'aggiornamento.
    func testAnOldRotationFileFallsBackToItsSaveDate() throws {
        let json = #"{"breakIndex":83,"microsSinceLong":2,"launchCount":147,"activeSeconds":98,"savedAt":"2026-07-30T15:30:00Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(EngineSnapshot.self, from: Data(json.utf8))
        XCTAssertEqual(snapshot.lastBreakAt, snapshot.savedAt)

        var engine = makeEngine()
        engine.restore(snapshot, now: Self.at(31, 11))
        engine.forceBreakNow(now: Self.at(31, 11))
        XCTAssertEqual(engine.plan?.kind, .micro,
                       "aggiornare l'app non deve costare una giornata di ciclo sbagliato")
    }

    /// Un orologio spostato indietro non deve congelare la giornata per sempre: una data futura
    /// vale «adesso», così il giorno cambia comunque alla mezzanotte successiva.
    func testAFutureLastBreakIsClampedToNow() {
        var engine = makeEngine()
        engine.restore(EngineSnapshot(breakIndex: 5, microsSinceLong: 2, launchCount: 1,
                                      activeSeconds: 0,
                                      lastBreakAt: Self.at(31, 23),
                                      savedAt: Self.at(31, 23)),
                       now: Self.at(30, 10))
        XCTAssertEqual(engine.lastBreakAt, Self.at(30, 10))
    }
}

// MARK: - ISC-107 — la pausa rimandata per la call

/// **Il caso vero: rimandi per una riunione, la riunione finisce, e la pausa arretrata non la sa
/// più nessuno.** Il rinvio da cinque minuti era la scelta giusta per non piombare addosso mentre
/// parli; ma se la call dura quaranta secondi, quei cinque minuti sono un'attesa senza causa.
///
/// Due controlli tengono onesto il verde: il rinvio **a mano** non deve accorciarsi quando il
/// microfono si libera, e finché il microfono è occupato non deve succedere niente.
final class DeferredBreakTests: XCTestCase {

    private static let workingHour = SessionEngineTests.workingHour

    private func makeEngine() -> SessionEngine {
        var s = Settings()
        s.startDate = Self.workingHour
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    private func advance(_ engine: inout SessionEngine, seconds: Double, step: Double = 10,
                         env: EngineEnvironment) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var t = 0.0
        while t < seconds {
            events += engine.tick(elapsed: step, idle: 0, now: Self.workingHour, environment: env)
            t += step
        }
        return events
    }

    /// Porta il motore a una pausa rimandata perché il microfono è in uso.
    private func reachMicrophoneDefer(_ engine: inout SessionEngine) {
        let inCall = EngineEnvironment(microphoneActive: true)
        advance(&engine, seconds: engine.settings.cadence.intervalSeconds
                                - engine.settings.cadence.warningSeconds, env: inCall)
        advance(&engine, seconds: engine.settings.cadence.warningSeconds + 1, step: 1, env: inCall)
        XCTAssertEqual(engine.phase, .postponed, "in call la pausa si rimanda, non piomba addosso")
    }

    func testTheDeferredBreakComesBackWhenTheCallEnds() {
        var engine = makeEngine()
        reachMicrophoneDefer(&engine)

        // La call finisce dopo quaranta secondi, non dopo cinque minuti. **Un tick solo**: da qui
        // in poi il preavviso scende, e misurarlo dopo altri trenta secondi misurerebbe il
        // conto alla rovescia invece della sua partenza.
        let events = advance(&engine, seconds: 10, step: 10, env: .quiet)

        guard case .deferredBreakDue(let plan)? = events.first(where: {
            if case .deferredBreakDue = $0 { return true }; return false
        }) else {
            return XCTFail("atteso l'avviso che la pausa rimandata è dovuta, ricevuto \(events)")
        }
        XCTAssertEqual(plan.index, engine.plan?.index, "è la stessa pausa di prima, non una nuova")
        XCTAssertEqual(engine.phase, .warning,
                       "riparte dal preavviso: riattaccare e trovarsi lo schermo coperto sarebbe peggio")
        XCTAssertEqual(engine.timer, engine.settings.cadence.warningSeconds, accuracy: 1)
    }

    /// **Primo controllo.** Il rinvio chiesto a mano non c'entra col microfono e non si accorcia:
    /// se si accorciasse, premere «rinvia» a fine riunione non varrebbe niente.
    func testAManualPostponementIsNotCutShortByTheMicrophone() {
        var engine = makeEngine()
        advance(&engine, seconds: engine.settings.cadence.intervalSeconds
                                - engine.settings.cadence.warningSeconds, env: .quiet)
        advance(&engine, seconds: engine.settings.cadence.warningSeconds + 1, step: 1, env: .quiet)
        XCTAssertEqual(engine.phase, .breaking)
        XCTAssertFalse(engine.postpone().isEmpty, "il rinvio a mano è concesso")
        XCTAssertEqual(engine.phase, .postponed)

        let events = advance(&engine, seconds: 40, step: 10, env: .quiet)
        XCTAssertFalse(events.contains { if case .deferredBreakDue = $0 { return true }; return false },
                       "il rinvio a mano dura quello che dura")
        XCTAssertEqual(engine.phase, .postponed)
    }

    /// **Secondo controllo.** Finché il microfono è occupato non succede niente: senza questo, il
    /// verde qui sopra direbbe solo che l'attesa è stata tolta a tutti.
    func testNothingHappensWhileTheMicrophoneIsStillInUse() {
        var engine = makeEngine()
        reachMicrophoneDefer(&engine)

        let events = advance(&engine, seconds: 60, step: 10,
                             env: EngineEnvironment(microphoneActive: true))
        XCTAssertFalse(events.contains { if case .deferredBreakDue = $0 { return true }; return false })
        XCTAssertEqual(engine.phase, .postponed, "la call è ancora in corso")
    }

    /// Se la call ricomincia durante i sessanta secondi di preavviso, l'app rimanda di nuovo da
    /// sola: il rimbalzo è gestito dalla porta normale, e non serve nessuna isteresi in più.
    func testACallStartingAgainDuringTheWarningDefersOnceMore() {
        var engine = makeEngine()
        reachMicrophoneDefer(&engine)
        advance(&engine, seconds: 10, step: 10, env: .quiet)
        XCTAssertEqual(engine.phase, .warning)

        let events = advance(&engine, seconds: engine.settings.cadence.warningSeconds + 5, step: 5,
                             env: EngineEnvironment(microphoneActive: true))
        XCTAssertTrue(events.contains { if case .autoDeferred = $0 { return true }; return false },
                      "la call ricominciata rimanda di nuovo")
        XCTAssertEqual(engine.phase, .postponed)
    }

    /// L'avviso non lascia riga nel registro: il rinvio l'ha già scritto `autoDeferred`, e
    /// contarlo due volte gonfierebbe le statistiche con l'atto di finirlo.
    func testTheNoticeLeavesNoLedgerRow() {
        let plan = BreakPlan(index: 1, kind: .micro, duration: 90,
                             exercise: Exercise(kind: .squat, reps: 10))
        XCTAssertNil(Ledger.entry(for: .deferredBreakDue(plan), now: Self.workingHour))
    }
}

// MARK: - ISC-108 — l'intervallo promesso è quello vissuto

/// **Il numero che l'app dice deve essere il numero che l'app fa.**
///
/// Il preavviso scattava *dopo* i 30 minuti e la pausa arrivava a 31: la barra prometteva
/// «prossima fra 30 min», la letteratura che l'app cita dice 30 (Duran 2023), e l'intervallo vero
/// era 31. Nessun test lo vedeva perché tutti erano scritti con lo stesso errore dentro — la
/// classe di difetto che si nasconde meglio, quella dove il test copia l'assunzione del codice.
final class IntervalPromiseTests: XCTestCase {

    private func makeEngine(_ s: Settings = Settings()) -> SessionEngine {
        var settings = s
        settings.startDate = SessionEngineTests.workingHour
        return SessionEngine(settings: settings, maxCredibleElapsed: 120)
    }

    /// Un secondo per volta, e si guarda **quando** cambia fase: nessuna finestra di tolleranza in
    /// cui nascondere un minuto.
    private func momentOf(_ phase: SessionEngine.Phase, _ engine: inout SessionEngine) -> Double? {
        for i in 0..<(60 * 60) {
            engine.tick(elapsed: 1, idle: 0, now: SessionEngineTests.workingHour)
            if engine.phase == phase { return Double(i + 1) }
        }
        return nil
    }

    func testTheBreakArrivesExactlyAtTheDeclaredInterval() {
        var engine = makeEngine()
        let intervallo = engine.settings.cadence.intervalSeconds
        let preavviso = engine.settings.cadence.warningSeconds

        guard let quandoAvvisa = momentOf(.warning, &engine) else {
            return XCTFail("il preavviso non è mai arrivato")
        }
        XCTAssertEqual(quandoAvvisa, intervallo - preavviso, accuracy: 1,
                       "l'avviso arriva un minuto PRIMA dei 30, non dopo")

        guard let restanti = momentOf(.breaking, &engine) else {
            return XCTFail("la pausa non è mai arrivata")
        }
        // `momentOf` conta da dove era arrivato: il totale è la somma dei due tratti.
        XCTAssertEqual(quandoAvvisa + restanti, intervallo, accuracy: 1,
                       "la pausa arriva ai 30 minuti dichiarati, non a 31")
    }

    /// Vale per ogni preset, non solo per quello di serie: è il contratto della cadenza, non un
    /// numero fortunato dell'opzione A.
    func testEveryPresetKeepsItsPromise() {
        for (nome, cadenza) in [("A", Cadence.optionA), ("B", .optionB), ("C", .optionC)] {
            var s = Settings(); s.cadence = cadenza
            var engine = makeEngine(s)
            guard let avviso = momentOf(.warning, &engine),
                  let restanti = momentOf(.breaking, &engine) else {
                return XCTFail("preset \(nome): la pausa non è mai arrivata")
            }
            let quandoBlocca = avviso + restanti
            XCTAssertEqual(quandoBlocca, cadenza.intervalSeconds, accuracy: 1,
                           "preset \(nome): promette \(Int(cadenza.intervalSeconds / 60)) minuti")
        }
    }

    /// Caso limite scrivibile a mano nel file: preavviso più lungo dell'intervallo. Non deve
    /// diventare una soglia negativa, cioè una pausa al primo tick.
    func testAWarningLongerThanTheIntervalDoesNotFireImmediately() {
        var s = Settings()
        s.cadence.intervalSeconds = 60
        s.cadence.warningSeconds = 300
        var engine = makeEngine(s)
        engine.tick(elapsed: 1, idle: 0, now: SessionEngineTests.workingHour)
        XCTAssertEqual(engine.phase, .working, "un solo secondo di lavoro non è una pausa dovuta")
    }
}

// MARK: - ISC-109 — il richiamo di fine pausa

/// **La pausa piena ti chiede di stare lontano dallo schermo, e da lontano non si vede niente.**
/// Il richiamo suona quando **scade il cronometro**, e dice che la pausa è finita — non che puoi
/// tornare. Sono due fatti diversi: il tempo è passato comunque, e se l'esercizio manca ancora, è
/// una decisione della persona cosa farne.
///
/// *La prima versione lo agganciava al pulsante* — cioè taceva finché l'esercizio non era
/// confermato — e i test qui sotto asserivano quello. Corretti su indicazione del principale il
/// 2026-07-31: **il test che era il controllo è diventato il claim**, e viceversa.
final class BreakTimeOverTests: XCTestCase {

    private static let ora = SessionEngineTests.workingHour

    private func makeEngine() -> SessionEngine {
        var s = Settings(); s.startDate = Self.ora
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    @discardableResult
    private func advance(_ e: inout SessionEngine, _ seconds: Double, step: Double = 1) -> [EngineEvent] {
        var out: [EngineEvent] = []
        var t = 0.0
        while t < seconds { out += e.tick(elapsed: step, idle: 0, now: Self.ora); t += step }
        return out
    }

    private func reachBreak(_ e: inout SessionEngine) {
        advance(&e, e.settings.cadence.intervalSeconds - e.settings.cadence.warningSeconds, step: 10)
        advance(&e, e.settings.cadence.warningSeconds + 1)
    }

    private func richiami(_ events: [EngineEvent]) -> Int {
        events.filter { if case .breakTimeOver = $0 { return true }; return false }.count
    }

    func testTheChimeFiresWhenTheClockRunsOut() {
        var engine = makeEngine()
        reachBreak(&engine)
        guard let plan = engine.plan else { return XCTFail("nessuna pausa") }

        advance(&engine, plan.exercise.minimumSeconds + 2)
        engine.markExerciseDone()
        // Ancora dentro la durata: il tempo non è finito, quindi non si dice che è finito.
        let presto = advance(&engine, 5)
        XCTAssertEqual(richiami(presto), 0, "il tempo della pausa non è ancora passato")

        let dopo = advance(&engine, plan.duration)
        XCTAssertEqual(richiami(dopo), 1, "il richiamo parte quando scade il cronometro")
    }

    /// **Il claim vero, e prima era il suo contrario.** Il tempo scade anche se l'esercizio non
    /// l'hai fatto, e il richiamo lo dice lo stesso: annuncia un fatto — la pausa è finita — non
    /// un permesso. Cosa farne è tuo.
    func testTheChimeFiresEvenWithTheExerciseStillMissing() {
        var engine = makeEngine()
        reachBreak(&engine)
        guard let plan = engine.plan else { return XCTFail("nessuna pausa") }

        let events = advance(&engine, plan.duration + 30, step: 5)
        XCTAssertEqual(richiami(events), 1, "il tempo è passato, e questo è il fatto che annuncia")
        XCTAssertFalse(engine.canReturnToWork, "ma il pulsante resta spento: l'esercizio manca")
        XCTAssertEqual(engine.phase, .breaking, "e la pausa non si chiude da sola")
    }

    /// Una volta sola: un richiamo a ogni secondo sarebbe un allarme, non un avviso.
    func testTheChimeFiresOnlyOnce() {
        var engine = makeEngine()
        reachBreak(&engine)
        guard let plan = engine.plan else { return XCTFail("nessuna pausa") }
        advance(&engine, plan.exercise.minimumSeconds + 2)
        engine.markExerciseDone()

        let events = advance(&engine, plan.duration + 60)
        XCTAssertEqual(richiami(events), 1)
    }

    /// E riparte alla pausa dopo: il segnale è per pausa, non per sessione.
    func testTheChimeComesBackOnTheNextBreak() {
        var engine = makeEngine()
        for giro in 1...2 {
            reachBreak(&engine)
            guard let plan = engine.plan else { return XCTFail("giro \(giro): nessuna pausa") }
            advance(&engine, plan.exercise.minimumSeconds + 2)
            engine.markExerciseDone()
            let events = advance(&engine, plan.duration + 10)
            XCTAssertEqual(richiami(events), 1, "giro \(giro)")
            engine.returnToWork()
        }
    }
}

// MARK: - ISC-113 — i posturali

/// La famiglia che mancava: la schiena alta, l'unica zona senza niente.
final class PosturalTests: XCTestCase {

    func testTheTwoPosturalExercisesAreFullyDescribed() {
        for kind in [ExerciseKind.superman, .ytw] {
            XCTAssertEqual(kind.category, .posturali)
            XCTAssertEqual(kind.muscleGroup, "dorso")
            XCTAssertFalse(kind.isVigorous, "non fanno fiatone, non contano come sessione intensa")
            XCTAssertFalse(kind.italianName.isEmpty)
            XCTAssertFalse(kind.englishName.isEmpty)
            XCTAssertGreaterThan(kind.baseReps, 0)
            XCTAssertGreaterThan(kind.secondsPerRep, 0)
        }
    }

    /// **Le istruzioni sono il prodotto, per questi due più che per tutti.** Squat e push-up li
    /// sa fare chiunque; «Y-T-W» non lo conosceva nemmeno il principale quando l'ha chiesto, e un
    /// esercizio che non sai eseguire è un esercizio che salti.
    func testTheInstructionsActuallyExplainTheMovement() {
        let ytw = ExerciseKind.ytw.cue
        for pezzo in ["Y", "T", "W"] {
            XCTAssertTrue(ytw.contains(pezzo), "le istruzioni devono nominare la lettera \(pezzo)")
        }
        XCTAssertTrue(ytw.count > 80, "una riga sola non basta a insegnare un gesto nuovo")
        XCTAssertTrue(ExerciseKind.superman.cue.count > 60)
    }

    /// Si sostituiscono a vicenda dentro la pausa: chi non regge il Y-T-W ha dove andare.
    func testTheyAreEachOthersVariant() {
        XCTAssertEqual(ExerciseKind.superman.variants, [.ytw])
        XCTAssertEqual(ExerciseKind.ytw.variants, [.superman])
    }

    /// **Il superman è fuori dalla rotazione di serie ma resta raggiungibile.** È la regola
    /// dell'ISC-95: il pool governa il turno, le sostituzioni no — e senza questa, spegnere un
    /// esercizio significherebbe anche togliere la via d'uscita a chi non ce la fa.
    func testSupermanStaysReachableEvenWhenNotInTheRotation() {
        let settings = Settings()
        XCTAssertTrue(settings.exercisePool.contains(.ytw), "in rotazione va il più mirato")
        XCTAssertFalse(settings.exercisePool.contains(.superman), "due «dorso» di fila no")
        XCTAssertTrue(ExerciseKind.ytw.variants.contains(.superman),
                      "ma dalla pausa ci si arriva lo stesso")
    }

    /// Il burpee dice il piegamento: era la parte che mancava, e senza è un altro esercizio.
    func testTheBurpeeDescribesThePushUp() {
        let t = ExerciseKind.burpee.cue.lowercased()
        XCTAssertTrue(t.contains("piegamento") || t.contains("push-up"),
                      "senza il piegamento è uno squat thrust, non un burpee")
    }
}

// MARK: - ISC-116 — lo squat thrust

/// Il burpee senza il piegamento: un esercizio suo, non una descrizione approssimativa dell'altro.
final class SquatThrustTests: XCTestCase {

    func testItIsAVigorousExerciseInItsOwnRight() {
        XCTAssertEqual(ExerciseKind.squatThrust.category, .vigorosi)
        XCTAssertTrue(ExerciseKind.squatThrust.isVigorous, "conta verso le sessioni intense")
        XCTAssertGreaterThan(ExerciseKind.squatThrust.baseReps, ExerciseKind.burpee.baseReps,
                             "senza il piegamento se ne fanno di più")
        XCTAssertLessThan(ExerciseKind.squatThrust.secondsPerRep, ExerciseKind.burpee.secondsPerRep,
                          "e ognuno dura meno")
    }

    /// **La regressione scala il movimento, non il numero.** È la stessa regola dei push-up: a
    /// una donna il burpee arriva come squat thrust, non come «quattro burpee».
    func testItIsTheBurpeeRegression() {
        XCTAssertEqual(SexCalibration.regression(for: .burpee, sex: .female), .squatThrust)
        XCTAssertEqual(SexCalibration.regression(for: .burpee, sex: .male), .burpee,
                       "e per tutti gli altri il burpee resta il burpee")
    }

    /// Resta la prima via d'uscita dentro la pausa, per chiunque: il piegamento a terra è il
    /// pezzo che salta per primo quando la giornata è storta.
    func testItIsTheFirstWayOutOfABurpee() {
        XCTAssertEqual(ExerciseKind.burpee.variants.first, .squatThrust)
        XCTAssertTrue(ExerciseKind.squatThrust.variants.contains(.burpee), "e si torna su")
    }

    /// I due non si confondono: uno nomina il piegamento, l'altro dice che non c'è.
    func testTheTwoDescriptionsCannotBeMixedUp() {
        XCTAssertTrue(ExerciseKind.squatThrust.cue.lowercased().contains("senza il piegamento"))
        XCTAssertFalse(ExerciseKind.squatThrust.cue.lowercased().contains("salta in alto"))
    }
}
