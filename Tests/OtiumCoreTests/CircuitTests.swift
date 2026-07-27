import XCTest
@testable import OtiumCore

/// Il microcircuito della pausa piena, e gli esercizi che si misurano in secondi.
final class CircuitTests: XCTestCase {

    private func engineInLongBreak() -> SessionEngine {
        var s = Settings()
        s.startDate = Date(timeIntervalSinceNow: -400 * 24 * 3600)   // rampa completata
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 10_000)
        engine.forceBreakNow(now: Date(), kind: .long)
        return engine
    }

    // MARK: - La proposta

    func testALongBreakProposesACircuitWithOneStationPerFamily() {
        let engine = engineInLongBreak()
        guard let plan = engine.plan else { return XCTFail("nessuna pausa in corso") }

        XCTAssertEqual(plan.kind, .long)
        XCTAssertGreaterThanOrEqual(plan.circuit.count, 3, "gambe, spinta, addome, esplosivo")
        let families = Set(plan.circuit.map(\.kind.category))
        XCTAssertEqual(families.count, plan.circuit.count, "due stazioni della stessa famiglia")
        XCTAssertTrue(families.contains(.vigorosi), "il pezzo esplosivo deve esserci")
        XCTAssertTrue(families.contains(.addome), "e l'addome, che è la ragione per cui l'ho aggiunto")
    }

    /// Proposto non vuol dire imposto: finché non lo scegli, la pausa è a esercizio singolo.
    func testTheCircuitIsNotActiveUntilYouChooseIt() {
        let engine = engineInLongBreak()
        XCTAssertFalse(engine.plan?.circuitActive ?? true)
        XCTAssertTrue(engine.canStartCircuit)
    }

    /// Le micro-pause non lo propongono: novanta secondi non contengono quattro esercizi.
    func testMicroBreaksHaveNoCircuit() {
        var s = Settings()
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 10_000)
        s.cadence.longEveryNBreaks = 99
        engine.settings = s
        engine.forceBreakNow(now: Date(), kind: .micro)
        XCTAssertEqual(engine.plan?.circuit.count, 0)
        XCTAssertFalse(engine.canStartCircuit)
    }

    func testTheCircuitCanBeTurnedOffInPreferences() {
        var s = Settings(offerCircuit: false)
        s.startDate = Date()
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 10_000)
        engine.forceBreakNow(now: Date(), kind: .long)
        XCTAssertEqual(engine.plan?.circuit.count, 0)
        XCTAssertFalse(engine.canStartCircuit)
    }

    /// Le stazioni pesano meno dell'esercizio singolo: quattro al volume pieno non stanno in
    /// cinque minuti, e chi ci prova non lo rifà una seconda volta.
    func testStationsAreLighterThanTheSameExerciseAlone() {
        let engine = engineInLongBreak()
        guard let plan = engine.plan, let station = plan.circuit.first else { return XCTFail() }
        let alone = Ramp.reps(for: station.kind, factor: 1.0)
        XCTAssertLessThan(station.reps, alone, "la stazione deve costare meno dell'esercizio da solo")
    }

    // MARK: - Il percorso

    func testConfirmingAStationAdvancesToTheNextOne() {
        var engine = engineInLongBreak()
        XCTAssertTrue(engine.startCircuit())
        guard let plan = engine.plan else { return XCTFail() }
        XCTAssertTrue(plan.circuitActive)
        XCTAssertEqual(plan.exercise, plan.circuit[0])

        // Il cancello anti-bluff vale su ogni stazione: prima del tempo minimo non succede nulla.
        engine.markExerciseDone()
        XCTAssertEqual(engine.plan?.stationIndex, 0, "confermata senza averla fatta")

        advanceThroughStation(&engine)
        XCTAssertEqual(engine.plan?.stationIndex, 1)
        XCTAssertEqual(engine.plan?.exercise, engine.plan?.circuit[1])
        XCTAssertFalse(engine.exerciseDone, "la pausa non è finita: c'è un'altra stazione")
    }

    /// Il cronometro riparte a ogni stazione: senza, il tempo della prima le sbloccherebbe tutte.
    func testEachStationRestartsTheAntiBluffGate() {
        var engine = engineInLongBreak()
        engine.startCircuit()
        advanceThroughStation(&engine)
        XCTAssertFalse(engine.canFinishNow, "la seconda stazione parte già sbloccata")
        XCTAssertGreaterThan(engine.secondsUntilCanFinish, 0)
    }

    func testTheLastStationClosesTheExercise() {
        var engine = engineInLongBreak()
        engine.startCircuit()
        let stations = engine.plan?.circuit.count ?? 0
        for _ in 0..<stations { advanceThroughStation(&engine) }
        XCTAssertTrue(engine.exerciseDone, "finito il giro, l'esercizio è fatto")
    }

    /// Uscire a metà è ammesso, e quello che hai fatto resta fatto.
    func testLeavingTheCircuitKeepsTheStationsAlreadyDone() {
        var engine = engineInLongBreak()
        let single = engine.plan?.exercise
        engine.startCircuit()
        advanceThroughStation(&engine)          // prima stazione confermata
        XCTAssertTrue(engine.leaveCircuit())

        guard let plan = engine.plan else { return XCTFail() }
        XCTAssertFalse(plan.circuitActive)
        XCTAssertEqual(plan.exercise, single, "si torna all'esercizio che toccava")
        XCTAssertEqual(plan.bankedStations.count, 1, "la stazione fatta non si perde")
    }

    /// Le ripetizioni del circuito finiscono nel registro **una volta sola**, e la pausa resta
    /// una: quattro stazioni non sono quattro pause.
    func testACircuitBreakIsOneBreakWithSeparateStationRows() {
        var engine = engineInLongBreak()
        engine.startCircuit()
        let stations = engine.plan!.circuit
        for _ in 0..<stations.count { advanceThroughStation(&engine) }
        advance(&engine, seconds: engine.plan!.duration + 5)

        guard let plan = engine.plan else { return XCTFail("la pausa è sparita") }
        let events = engine.returnToWork()
        guard let entry = events.compactMap({ Ledger.entry(for: $0, now: Date()) }).first else {
            return XCTFail("nessuna riga di registro")
        }
        XCTAssertEqual(entry.type, .completed)
        XCTAssertNil(entry.exercise, "con il circuito le ripetizioni stanno nelle righe delle stazioni")
        XCTAssertNil(entry.reps)
        XCTAssertEqual(entry.reason, "circuito")

        let rows = plan.allStationsDone(currentConfirmed: true).map {
            LedgerEntry(timestamp: Date(), type: .circuitStation, exercise: $0.kind, reps: $0.reps)
        }
        let summary = Ledger.summarize([entry] + rows)
        XCTAssertEqual(summary.completed, 1, "una pausa, non quattro")
        XCTAssertEqual(summary.totalReps, stations.reduce(0) { $0 + $1.reps })
    }

    /// Cambiare variante dentro il circuito cambia **la stazione che va nel registro**, non solo
    /// quella a schermo.
    func testSwappingAStationIsWhatGetsRecorded() {
        var engine = engineInLongBreak()
        engine.startCircuit()
        guard let alternative = engine.variants(now: Date()).first else { return XCTFail() }
        XCTAssertTrue(engine.swapExercise(to: alternative.kind, now: Date()))
        XCTAssertEqual(engine.plan?.circuit[0].kind, alternative.kind)
    }

    // MARK: - Esercizi a tempo

    func testTimedExercisesCountSecondsNotRepetitions() {
        for kind in ExerciseKind.allCases where kind.isTimed {
            XCTAssertEqual(kind.secondsPerRep, 1.0, "\(kind): un «rep» deve valere un secondo")
            let exercise = Exercise(kind: kind, reps: kind.baseReps)
            XCTAssertEqual(exercise.minimumSeconds, Double(kind.baseReps), accuracy: 0.001,
                           "\(kind): il cancello chiederebbe un tempo che non è quello dichiarato")
            XCTAssertTrue(exercise.label.contains(" s "), "\(kind): l'etichetta deve dire i secondi")
            XCTAssertTrue(exercise.title.hasPrefix("secondi di"), "\(kind): sotto il numero grande")
        }
    }

    func testRepetitionExercisesKeepTheirOldLabel() {
        let squat = Exercise(kind: .squat, reps: 15)
        XCTAssertEqual(squat.label, "15 squat")
        XCTAssertEqual(squat.title, "squat")
    }

    /// Gli addominali esistono davvero e sono selezionabili come gli altri.
    func testAbdominalFamilyIsPresentAndComplete() {
        let core = ExerciseKind.allCases.filter { $0.category == .addome }
        XCTAssertGreaterThanOrEqual(core.count, 6)
        for kind in core {
            XCTAssertFalse(kind.italianName.isEmpty)
            XCTAssertFalse(kind.cue.isEmpty, "\(kind): senza istruzione non si esegue")
            XCTAssertFalse(kind.variants.isEmpty, "\(kind): senza alternative")
            XCTAssertEqual(kind.muscleGroup, "addome")
        }
    }

    /// Ogni esercizio appartiene a una famiglia e a una sola.
    func testEveryExerciseHasExactlyOneCategory() {
        for kind in ExerciseKind.allCases {
            XCTAssertEqual(kind.isVigorous, kind.category == .vigorosi,
                           "\(kind): vigoroso e famiglia devono dire la stessa cosa")
        }
        for category in ExerciseCategory.allCases {
            XCTAssertFalse(ExerciseKind.allCases.filter { $0.category == category }.isEmpty,
                           "\(category): famiglia vuota nelle preferenze")
        }
    }

    // MARK: - Attrezzi da banco

    /// Porta la stazione in corso fino alla conferma, passando il tempo minimo.
    private func advanceThroughStation(_ engine: inout SessionEngine) {
        let needed = engine.plan?.exercise.minimumSeconds ?? 0
        advance(&engine, seconds: needed + 1)
        engine.markExerciseDone()
    }

    private func advance(_ engine: inout SessionEngine, seconds: Double, step: Double = 1) {
        var elapsed = 0.0
        while elapsed < seconds {
            let slice = min(step, seconds - elapsed)
            engine.tick(elapsed: slice, idle: 0, now: Date())
            elapsed += slice
        }
    }
}
