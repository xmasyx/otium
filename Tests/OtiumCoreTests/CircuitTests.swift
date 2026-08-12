import XCTest
@testable import OtiumCore

/// Il microcircuito della pausa piena, e gli esercizi che si misurano in secondi.
final class CircuitTests: XCTestCase {

    /// **La lingua si dichiara, non si eredita.** Questi test guardano etichette in italiano e
    /// `L.language` è globale: dichiararla qui li rende indipendenti dall'ordine di esecuzione.
    /// (Il fallimento che me l'ha fatta scrivere era mio: avevo messo il plurale inglese dentro
    /// `italianName`. Il difetto era il plurale nel posto sbagliato, non l'ordine dei test.)
    override func setUp() {
        super.setUp()
        L.language = .italian
    }


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
        var s = Settings(circuitMode: .singolo)
        s.startDate = Date()
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 10_000)
        engine.forceBreakNow(now: Date(), kind: .long)
        XCTAssertEqual(engine.plan?.circuit.count, 0)
        XCTAssertFalse(engine.canStartCircuit)
    }

    /// **Una stazione vale quanto l'esercizio da solo** (2026-08-04).
    ///
    /// Questo test diceva l'opposto — «la stazione deve costare meno» — con la motivazione che
    /// quattro esercizi al volume pieno non stanno in cinque minuti. Il principale l'ha ribaltata
    /// con un argomento migliore: *«quegli esercizi sono singoli per ogni gruppo muscolare»*. Le
    /// quattro stazioni sono gambe, spinta, addome ed esplosivo, quindi non si sommano sullo
    /// stesso muscolo e non c'è nessun affaticamento da ripartire.
    func testStationsCarryTheSameLoadAsTheExerciseAlone() {
        let engine = engineInLongBreak()
        guard let plan = engine.plan, let station = plan.circuit.first else { return XCTFail() }
        let alone = Ramp.reps(for: station.kind, factor: 1.0)
        XCTAssertEqual(station.reps, alone, "la stazione vale quanto l'esercizio da solo")
        XCTAssertEqual(ExercisePlanner.circuitFactor, 1.0)
    }

    /// **Il circuito spende la progressione che hai guadagnato** (segnalato dal principale il
    /// 2026-08-12: *«perché quando faccio il circuito non mi propone esercizi con un numero
    /// aumentato di ripetizioni?»*).
    ///
    /// Il difetto era di costruzione e non di calcolo: `ExercisePlanner.circuit` non riceveva il
    /// registro della progressione, quindi ogni stazione nasceva a livello 1.0 mentre l'esercizio
    /// singolo, che il registro ce l'ha, saliva. Nel suo `progress.json` c'erano livelli a 1,2155,
    /// cioè quattro aumenti guadagnati e mai spesi.
    func testCircuitStationsSpendTheProgressionYouEarned() {
        var engine = engineWithLevel(1.5, growing: true)
        engine.forceBreakNow(now: Date(), kind: .long)
        guard let plan = engine.plan, !plan.circuit.isEmpty else { return XCTFail("nessun circuito") }
        for station in plan.circuit {
            let cento = Ramp.reps(for: station.kind, factor: 1.0, sex: engine.settings.sex)
            XCTAssertGreaterThan(station.reps, cento,
                                 "\(station.kind): la stazione resta al 100% mentre il livello è 1.5")
        }
    }

    /// Il polo negativo: a crescita **spenta** le stazioni tornano al 100% esatto, com'è giusto.
    /// Senza questa riga il test qui sopra passerebbe anche moltiplicando sempre, cioè imponendo
    /// la crescita a chi ha scelto di restare al programma.
    func testWithGrowthOffTheStationsStayAtFullVolume() {
        var engine = engineWithLevel(1.5, growing: false)
        engine.forceBreakNow(now: Date(), kind: .long)
        guard let plan = engine.plan, !plan.circuit.isEmpty else { return XCTFail("nessun circuito") }
        for station in plan.circuit {
            XCTAssertEqual(station.reps, Ramp.reps(for: station.kind, factor: 1.0, sex: engine.settings.sex),
                           "\(station.kind): crescita spenta e stazione cresciuta lo stesso")
        }
    }

    /// **Cambiare variante non azzera il livello.** `swapExercise` ricostruiva l'esercizio senza
    /// `level:`, quindi passare a diamond dentro la pausa faceva sparire la progressione di quel
    /// gesto: stesso buco del circuito, in un punto diverso.
    func testSwappingAVariantKeepsTheProgressionOfTheNewMovement() {
        var engine = engineWithLevel(1.5, growing: true)
        engine.forceBreakNow(now: Date(), kind: .long)
        guard let alternative = engine.variants(now: Date()).first else { return XCTFail("nessuna variante") }
        XCTAssertTrue(engine.swapExercise(to: alternative.kind, now: Date()))
        let cento = Ramp.reps(for: alternative.kind, factor: 1.0, sex: engine.settings.sex)
        XCTAssertGreaterThan(engine.plan?.exercise.reps ?? 0, cento,
                             "\(alternative.kind): la variante nasce al 100% e il livello sparisce")
    }

    /// Un motore a rampa finita, con lo stesso livello su ogni esercizio: qualunque stazione esca
    /// dalla rotazione, il confronto è valido.
    private func engineWithLevel(_ level: Double, growing: Bool) -> SessionEngine {
        var s = Settings()
        s.startDate = Date(timeIntervalSinceNow: -400 * 24 * 3600)
        s.progressBeyondFull = growing
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 10_000)
        var book = ProgressBook()
        for kind in ExerciseKind.allCases {
            book.byExercise[kind.rawValue] = ExerciseProgress(level: level)
        }
        engine.progress = book
        return engine
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

    /// Uscire a metà è ammesso, e quello che hai fatto resta fatto: la stazione confermata è già
    /// nel registro, scritta al momento della conferma.
    func testLeavingTheCircuitKeepsTheStationsAlreadyDone() {
        var engine = engineInLongBreak()
        let single = engine.plan?.exercise
        engine.startCircuit()
        let prima = engine.plan!.circuit[0]
        let eventi = advanceThroughStation(&engine)          // prima stazione confermata
        XCTAssertEqual(eventi, [.exerciseConfirmed(prima)], "la stazione fatta va contata subito")
        XCTAssertTrue(engine.leaveCircuit())

        guard let plan = engine.plan else { return XCTFail() }
        XCTAssertFalse(plan.circuitActive)
        XCTAssertEqual(plan.exercise, single, "si torna all'esercizio che toccava")
    }

    /// Le ripetizioni del circuito finiscono nel registro **una volta sola**, e la pausa resta
    /// una: quattro stazioni non sono quattro pause.
    func testACircuitBreakIsOneBreakWithSeparateStationRows() {
        var engine = engineInLongBreak()
        engine.startCircuit()
        let stations = engine.plan!.circuit

        var righe: [LedgerEntry] = []
        for _ in 0..<stations.count {
            righe += advanceThroughStation(&engine).compactMap { Ledger.entry(for: $0, now: Date()) }
        }
        XCTAssertEqual(righe.count, stations.count, "una riga per stazione, alla conferma")
        XCTAssertTrue(righe.allSatisfy { $0.type == .exerciseDone })

        advance(&engine, seconds: engine.plan!.duration + 5)
        let chiusura = engine.returnToWork().compactMap { Ledger.entry(for: $0, now: Date()) }
        guard let entry = chiusura.first else { return XCTFail("nessuna riga di chiusura") }
        XCTAssertEqual(entry.type, .completed)
        XCTAssertNil(entry.reps, "le ripetizioni hanno già la loro riga: qui sarebbero doppie")
        XCTAssertEqual(entry.reason, "circuito")

        let summary = Ledger.summarize(righe + [entry])
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

    // MARK: - Quando si contano le ripetizioni

    /// Segnalato il 2026-07-27: il recap non vedeva le ripetizioni finché la pausa non era
    /// chiusa — fino a cinque minuti dopo averle fatte. Ora si contano alla **conferma**.
    func testRepsAreCountedWhenTheExerciseIsConfirmedNotWhenTheBreakCloses() {
        var engine = engineInLongBreak()
        let esercizio = engine.plan!.exercise

        // Prima del tempo minimo, «Fatto» non fa niente: nessuna riga.
        XCTAssertEqual(engine.markExerciseDone(), [])

        advance(&engine, seconds: esercizio.minimumSeconds + 1)
        let eventi = engine.markExerciseDone()
        XCTAssertEqual(eventi, [.exerciseConfirmed(esercizio)])

        guard let riga = eventi.compactMap({ Ledger.entry(for: $0, now: Date()) }).first else {
            return XCTFail("la conferma non ha prodotto una riga di registro")
        }
        XCTAssertEqual(riga.type, .exerciseDone)
        XCTAssertEqual(riga.exercise, esercizio.kind)
        XCTAssertEqual(riga.reps, esercizio.reps)
        XCTAssertEqual(Ledger.summarize([riga]).totalReps, esercizio.reps,
                       "il recap deve poterle contare già adesso")
        XCTAssertEqual(Ledger.summarize([riga]).completed, 0,
                       "confermare un esercizio non è aver finito la pausa")
    }

    /// L'altra metà della stessa regola: alla chiusura le ripetizioni **non** si contano di
    /// nuovo. Senza questo, ogni pausa varrebbe il doppio.
    func testClosingTheBreakDoesNotCountTheRepsASecondTime() {
        var engine = engineInLongBreak()
        let esercizio = engine.plan!.exercise
        advance(&engine, seconds: esercizio.minimumSeconds + 1)
        let conferma = engine.markExerciseDone().compactMap { Ledger.entry(for: $0, now: Date()) }
        advance(&engine, seconds: engine.plan!.duration + 5)
        let chiusura = engine.returnToWork().compactMap { Ledger.entry(for: $0, now: Date()) }

        XCTAssertEqual(chiusura.first?.type, .completed)
        XCTAssertNil(chiusura.first?.reps)
        XCTAssertEqual(chiusura.first?.exercise, esercizio.kind,
                       "il nome resta: la cronologia deve dire cos'era quella pausa")

        let summary = Ledger.summarize(conferma + chiusura)
        XCTAssertEqual(summary.totalReps, esercizio.reps, "contate una volta sola")
        XCTAssertEqual(summary.completed, 1)
    }

    /// Se esci d'emergenza dopo aver fatto l'esercizio, quelle ripetizioni restano tue: sono
    /// state eseguite. La pausa risulta saltata, il lavoro no.
    func testConfirmedRepsSurviveAnEmergencyExit() {
        var engine = engineInLongBreak()
        let esercizio = engine.plan!.exercise
        advance(&engine, seconds: esercizio.minimumSeconds + 1)
        let conferma = engine.markExerciseDone().compactMap { Ledger.entry(for: $0, now: Date()) }
        let uscita = engine.emergencyExit().compactMap { Ledger.entry(for: $0, now: Date()) }

        let summary = Ledger.summarize(conferma + uscita)
        XCTAssertEqual(summary.totalReps, esercizio.reps)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.completed, 0)
    }

    /// Il registro è append-only: le righe scritte prima di questa regola portano le ripetizioni
    /// sulla riga della pausa, e devono continuare a contare.
    func testOldRowsWithRepsOnTheCompletedLineStillCount() {
        let vecchia = LedgerEntry(timestamp: Date(), type: .completed, breakKind: .micro,
                                  exercise: .squat, reps: 15)
        let vecchiaStazione = LedgerEntry(timestamp: Date(), type: .circuitStation,
                                          exercise: .burpee, reps: 4)
        let summary = Ledger.summarize([vecchia, vecchiaStazione])
        XCTAssertEqual(summary.totalReps, 19, "la storia non si riscrive")
        XCTAssertEqual(summary.completed, 1)
    }

    // MARK: - Esercizi a tempo

    func testTimedExercisesCountSecondsNotRepetitions() {
        for kind in ExerciseKind.allCases where kind.isTimed {
            XCTAssertEqual(kind.secondsPerRep, 1.0, "\(kind): un «rep» deve valere un secondo")
            let exercise = Exercise(kind: kind, reps: kind.baseReps)
            XCTAssertEqual(exercise.minimumSeconds, Double(kind.baseReps), accuracy: 0.001,
                           "\(kind): il cancello chiederebbe un tempo che non è quello dichiarato")
            XCTAssertTrue(exercise.label.contains(" s "), "\(kind): l'etichetta deve dire i secondi")
            XCTAssertTrue(exercise.title.hasPrefix("secondi"), "\(kind): sotto il numero grande")
        }
    }

    // MARK: - Esercizi a lati alterni

    /// Il caso segnalato il 2026-07-27: «6 archer push-up» si legge come sei per braccio, che è
    /// il doppio del lavoro previsto. A schermo va il **per lato**, il totale resta nel registro.
    func testAlternatingExercisesShowRepsPerSide() {
        let archer = Exercise(kind: .archerPushUp, reps: 6)
        XCTAssertEqual(archer.displayReps, 3)
        XCTAssertEqual(archer.label, "3 archer push-ups per lato")
        XCTAssertEqual(archer.title, "archer push-ups per lato")
        XCTAssertEqual(archer.reps, 6, "il totale non cambia: è quello che va nel registro")
        XCTAssertEqual(archer.minimumSeconds, 6 * ExerciseKind.archerPushUp.secondsPerRep, accuracy: 0.001,
                       "il cancello anti-bluff conta il totale, o mostrare metà scontererebbe il tempo")
    }

    /// «1,5 per lato» non è un'istruzione eseguibile: il totale di un esercizio a lati alterni
    /// dev'essere pari a ogni gradino della rampa.
    func testPerSideTotalsAreAlwaysEven() {
        for kind in ExerciseKind.allCases where kind.isPerSide {
            for factor in stride(from: 0.3, through: 1.0, by: 0.05) {
                let reps = Ramp.reps(for: kind, factor: factor)
                XCTAssertEqual(reps % 2, 0, "\(kind) al \(Int(factor * 100))%: totale dispari (\(reps))")
                XCTAssertGreaterThanOrEqual(reps, 2)
            }
        }
    }

    /// Il plank laterale è insieme a tempo e a lati alterni: deve dirlo tutto e due.
    func testSidePlankSaysBothSecondsAndPerSide() {
        let side = Exercise(kind: .sidePlank, reps: 40)
        XCTAssertEqual(side.label, "20 s per lato di plank laterale")
        XCTAssertEqual(side.title, "secondi per lato di plank laterale")
    }

    /// Gli esercizi che **non** alternano restano com'erano: nessuna dicitura di troppo.
    func testNonAlternatingExercisesAreUnchanged() {
        XCTAssertEqual(Exercise(kind: .squat, reps: 15).label, "15 squats")
        XCTAssertEqual(Exercise(kind: .pushUp, reps: 10).title, "push-ups")
        XCTAssertFalse(ExerciseKind.pushUp.isPerSide)
    }

    /// I nomi che compaiono in «Esercizi svolti»: quello che lavora, non il movimento.
    func testMuscleGroupNamesAreTheOnesShownInTheRecap() {
        XCTAssertEqual(ExerciseKind.archerPushUp.muscleGroup, "petto")
        XCTAssertEqual(ExerciseKind.pushUp.muscleGroup, "petto")
        XCTAssertEqual(ExerciseKind.pikePushUp.muscleGroup, "spalle")
        XCTAssertEqual(ExerciseKind.benchDip.muscleGroup, "tricipiti")
        XCTAssertEqual(ExerciseKind.burpee.muscleGroup, "total body")
        for kind in ExerciseKind.allCases {
            XCTAssertNotEqual(kind.muscleGroup, "spinta", "«spinta» è il movimento, non ciò che lavora")
            XCTAssertNotEqual(kind.muscleGroup, "tutto il corpo")
        }
    }

    func testRepetitionExercisesKeepTheirOldLabel() {
        let squat = Exercise(kind: .squat, reps: 15)
        XCTAssertEqual(squat.label, "15 squats")
        XCTAssertEqual(squat.title, "squats")
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
    @discardableResult
    private func advanceThroughStation(_ engine: inout SessionEngine) -> [EngineEvent] {
        let needed = engine.plan?.exercise.minimumSeconds ?? 0
        advance(&engine, seconds: needed + 1)
        return engine.markExerciseDone()
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

// MARK: - ISC-122 — le pause piene già in circuito

/// **Chi il circuito lo fa sempre non deve dirlo ogni volta.** Facoltativa e spenta di serie: il
/// circuito è quattro esercizi in cinque minuti, e arrivarci senza averlo scelto è il modo di
/// odiarlo al secondo giorno.
final class StartInCircuitTests: XCTestCase {

    private static let ora: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 7; c.day = 31; c.hour = 10
        return Calendar.current.date(from: c)!
    }()

    private func engine(startInCircuit: Bool) -> SessionEngine {
        var s = Settings()
        s.startDate = Self.ora
        s.circuitMode = startInCircuit ? .subito : .proposto
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    func testTheFullBreakOpensAlreadyInTheCircuit() {
        var e = engine(startInCircuit: true)
        e.forceBreakNow(now: Self.ora, kind: .long)
        guard let plan = e.plan else { return XCTFail("nessuna pausa") }
        XCTAssertTrue(plan.circuitActive, "parte dentro il giro")
        XCTAssertEqual(plan.stationIndex, 0)
        XCTAssertEqual(plan.exercise.kind, plan.circuit.first?.kind, "e mostra la prima stazione")
        XCTAssertFalse(e.canStartCircuit, "non si propone quello che è già in corso")
    }

    /// Il controllo: spenta, la pausa piena si apre come sempre — con la proposta, non col giro.
    func testWithTheSettingOffNothingChanges() {
        var e = engine(startInCircuit: false)
        e.forceBreakNow(now: Self.ora, kind: .long)
        guard let plan = e.plan else { return XCTFail("nessuna pausa") }
        XCTAssertFalse(plan.circuitActive)
        XCTAssertTrue(e.canStartCircuit, "il circuito resta una proposta")
    }

    /// **L'uscita deve restare vera anche entrando dal giro.** Se `singleExercise` non fosse
    /// stato messo da parte al momento del piano, uscire dal circuito lascerebbe a schermo la
    /// stazione invece dell'esercizio del turno — cioè l'uscita non riporterebbe da nessuna parte.
    func testLeavingTheCircuitGivesBackTheExerciseOfTheTurn() {
        var normale = engine(startInCircuit: false)
        normale.forceBreakNow(now: Self.ora, kind: .long)
        let esercizioDelTurno = normale.plan?.exercise.kind

        var e = engine(startInCircuit: true)
        e.forceBreakNow(now: Self.ora, kind: .long)
        XCTAssertTrue(e.leaveCircuit(), "l'uscita c'è")
        XCTAssertFalse(e.plan?.circuitActive ?? true)
        XCTAssertEqual(e.plan?.exercise.kind, esercizioDelTurno,
                       "e riporta all'esercizio che sarebbe toccato, non alla stazione")
    }

    /// Le micro-pause non c'entrano: il circuito vive solo nelle piene.
    func testMicroBreaksAreUntouched() {
        var e = engine(startInCircuit: true)
        e.forceBreakNow(now: Self.ora, kind: .micro)
        XCTAssertFalse(e.plan?.circuitActive ?? true)
        XCTAssertTrue(e.plan?.circuit.isEmpty ?? false)
    }
}

// MARK: - ISC-123 — una scelta sola, tre valori

/// **Due interruttori dipendenti producono stati che non esistono.** «Proponi il microcircuito» e
/// «comincia già in circuito» erano due caselle, e spenta la prima la seconda comandava una cosa
/// che non c'era: l'interfaccia doveva disabilitarla per difendersi da sé stessa, e chi voleva
/// solo il circuito trovava la strada sbarrata in entrambi i sensi.
final class CircuitModeTests: XCTestCase {

    private static let ora: Date = {
        var c = DateComponents(); c.year = 2026; c.month = 7; c.day = 31; c.hour = 10
        return Calendar.current.date(from: c)!
    }()

    private func pianoLungo(_ modo: CircuitMode) -> BreakPlan? {
        var s = Settings(); s.startDate = Self.ora; s.circuitMode = modo
        var e = SessionEngine(settings: s, maxCredibleElapsed: 120)
        e.forceBreakNow(now: Self.ora, kind: .long)
        return e.plan
    }

    func testTheThreeValuesAreThreeDifferentBreaks() {
        XCTAssertTrue(pianoLungo(.singolo)?.circuit.isEmpty ?? false,
                      "in singolo il circuito non si costruisce nemmeno")
        XCTAssertFalse(pianoLungo(.singolo)?.circuitActive ?? true)

        XCTAssertFalse(pianoLungo(.proposto)?.circuit.isEmpty ?? true, "proposto: c'è ma spento")
        XCTAssertFalse(pianoLungo(.proposto)?.circuitActive ?? true)

        XCTAssertFalse(pianoLungo(.subito)?.circuit.isEmpty ?? true)
        XCTAssertTrue(pianoLungo(.subito)?.circuitActive ?? false, "subito: c'è e parte acceso")
    }

    /// **Nessuno stato impossibile, per costruzione.** È il punto di avere un asse solo: qualunque
    /// valore si scelga, il piano che ne esce è coerente — non esiste più «attivo senza circuito».
    func testNoImpossibleStateCanBeExpressed() {
        for modo in CircuitMode.allCases {
            guard let p = pianoLungo(modo) else { return XCTFail("\(modo): nessuna pausa") }
            if p.circuitActive {
                XCTAssertGreaterThanOrEqual(p.circuit.count, 2,
                                            "\(modo): attivo su un circuito che non c'è")
                XCTAssertEqual(p.exercise.kind, p.circuit.first?.kind)
            }
            XCTAssertFalse(modo.startsActive && !modo.buildsCircuit,
                           "\(modo): parte acceso senza costruire — la combinazione che l'enum esiste per vietare")
        }
    }

    /// **Le impostazioni scritte prima non si perdono.** Un file con i due booleani va letto e
    /// tradotto: chi aveva spento il circuito non deve ritrovarselo acceso senza sapere perché.
    func testOldFilesWithTwoBooleansStillLoad() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let casi: [(String, CircuitMode)] = [
            (#"{"offerCircuit":true,"startLongInCircuit":true}"#, .subito),
            (#"{"offerCircuit":true,"startLongInCircuit":false}"#, .proposto),
            (#"{"offerCircuit":false,"startLongInCircuit":false}"#, .singolo),
            (#"{"offerCircuit":false,"startLongInCircuit":true}"#, .singolo),   // stato impossibile: vince chi vieta
            (#"{}"#, .proposto),                                                 // file antico: il default
        ]
        for (json, atteso) in casi {
            let s = try decoder.decode(Settings.self, from: Data(json.utf8))
            XCTAssertEqual(s.circuitMode, atteso, "migrazione di \(json)")
        }
    }

    /// E il valore nuovo, quando c'è, batte i vecchi campi rimasti nel file.
    func testTheNewKeyWinsOverTheOldOnes() throws {
        let json = #"{"circuitMode":"singolo","offerCircuit":true,"startLongInCircuit":true}"#
        let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(s.circuitMode, .singolo)
    }

    /// **Il file vero del principale**, com'era sul disco il 2026-07-31 dopo che gli avevo acceso
    /// l'impostazione vecchia: trenta chiavi, i due booleani, e nessun `circuitMode`. Un test sul
    /// JSON minimo prova la funzione; questo prova il **caso che sta davvero succedendo**.
    func testHisActualSettingsFileMigratesToStartingInTheCircuit() throws {
        let json = """
        {"activeFromHour":7,"activeToHour":23,"autoDeferSeconds":300,"autoStartAtLogin":true,\
        "cadence":{"idleThresholdSeconds":90,"intervalSeconds":1800,"longDurationSeconds":300,\
        "longEveryNBreaks":3,"microDurationSeconds":90,"postponeSeconds":120,"postponesAllowed":1,\
        "warningSeconds":60},"deferWhenMicrophoneActive":true,"detectQuietPresence":true,\
        "escapePhrase":"salto la pausa","fullPaceAnswered":false,"growthAnswered":false,\
        "language":"italian","maxAutoDefers":6,"notificationSound":"Tink","offerCircuit":true,\
        "offerVariants":true,"progressBeyondFull":false,"rampStartFactor":0.55,"rampWeeks":3,\
        "resumeGraceSeconds":300,"sex":"male","startLongInCircuit":true,"theme":"alloro",\
        "vigorousDailyTarget":3}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let s = try decoder.decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(s.circuitMode, .subito, "l'impostazione che gli ho acceso non deve perdersi")
        // **Campo per campo, non contro il preset.** Fino al 2026-08-12 questa riga diceva
        // `s.cadence == .optionA`, e il giorno in cui il preset A è passato a due rinvii è diventata
        // rossa pur essendo la lettura del file ancora perfetta: confrontava un file storico con
        // una costante viva. Il file di allora aveva un rinvio, e deve continuare a leggersi con un
        // rinvio — è quello il senso di «arriva intero».
        XCTAssertEqual(s.cadence.intervalSeconds, 1800)
        XCTAssertEqual(s.cadence.microDurationSeconds, 90)
        XCTAssertEqual(s.cadence.longDurationSeconds, 300)
        XCTAssertEqual(s.cadence.longEveryNBreaks, 3)
        XCTAssertEqual(s.cadence.warningSeconds, 60)
        XCTAssertEqual(s.cadence.postponesAllowed, 1, "il file diceva uno: la storia non si riscrive")
        XCTAssertTrue(s.offerVariants)
    }
}

// MARK: - ISC-229 — il gruppo muscolare a schermo parla la lingua dell'interfaccia

/// **La chiave resta italiana, il testo a schermo no.** `muscleGroup` è una chiave: la usano la
/// rotazione (per non caricare due volte la stessa catena) e la calibrazione per sesso, quindi
/// tradurla farebbe dipendere gli esercizi proposti dalla lingua. Ma la pagina delle statistiche
/// raggruppa per quella chiave e poi la **scriveva così com'era**: in inglese le barre dicevano
/// «addome», «gambe», «petto». Trovato il 2026-08-12 fotografando la pagina, non da un test.
final class MuscleGroupLanguageTests: XCTestCase {

    override func tearDown() { L.language = .italian; super.tearDown() }

    func testEveryGroupKeyHasAnEnglishName() {
        L.language = .english
        let chiavi = Set(ExerciseKind.allCases.map(\.muscleGroup))
        for chiave in chiavi {
            let tradotto = ExerciseKind.localizedGroup(chiave)
            XCTAssertFalse(tradotto.isEmpty, "\(chiave): nessun nome inglese")
            // «total body» è uguale nelle due lingue ed è l'unica coincidenza ammessa: ogni altra
            // chiave che torna identica a sé stessa è una traduzione che manca.
            if chiave != "total body" {
                XCTAssertNotEqual(tradotto, chiave, "\(chiave): a schermo resta italiano")
            }
        }
    }

    /// Il caso che il ramo di scarto sbagliava: `dorso` rispondeva «total body», che è un'altra
    /// cosa. Una traduzione plausibile e falsa è peggio di una mancante, perché nessuno la guarda.
    func testTheBackIsNotTheWholeBody() {
        L.language = .english
        XCTAssertEqual(ExerciseKind.localizedGroup("dorso"), "back")
        XCTAssertEqual(ExerciseKind.superman.localizedMuscleGroup, "back")
    }

    /// E in italiano la chiave si mostra tale e quale, cioè la traduzione non inventa niente.
    func testInItalianTheKeyIsAlreadyTheName() {
        L.language = .italian
        for kind in ExerciseKind.allCases {
            XCTAssertEqual(kind.localizedMuscleGroup, kind.muscleGroup)
        }
    }
}

// MARK: - ISC-230 — il referto della diagnostica non porta il nome di chi segnala

/// **Il testo che si incolla in una segnalazione pubblica non deve contenere la cartella home.**
///
/// Il 2026-08-12, progettando il pulsante «Segnala un problema…», è emerso che il referto stampava
/// due volte `/Users/<nome>/`: la strada che l'app suggerisce per chiedere aiuto pubblicava il nome
/// di chi la usava. La riparazione vive in `Doctor.senzaNome`, che sta nel bersaglio dell'app e
/// quindi qui si prova la funzione pura, con i casi che contano.
///
/// *(La regola è dichiarata qui, in `OtiumCore`, perché è dove vivono i test: la sonda a due poli
/// sul referto vero è `Otium --doctor | grep -c '/Users/'`, che deve stampare zero.)*
final class DiagnosticsPrivacyTests: XCTestCase {

    /// La sostituzione, riscritta con la stessa regola del tool: prefisso della home vera, mai un
    /// modello indovinato del tipo `/Users/[^/]+`, che sbaglierebbe su chi ha la home altrove.
    private func senzaNome(_ percorso: String, home: String) -> String {
        guard !home.isEmpty, percorso.hasPrefix(home) else { return percorso }
        return "~" + percorso.dropFirst(home.count)
    }

    func testTheHomeFolderBecomesATilde() {
        let home = "/Users/qualcuno"
        XCTAssertEqual(senzaNome("\(home)/Library/Application Support/Otium", home: home),
                       "~/Library/Application Support/Otium")
        XCTAssertEqual(senzaNome("\(home)/Desktop/Otium.app/Contents/MacOS/Otium", home: home),
                       "~/Desktop/Otium.app/Contents/MacOS/Otium")
    }

    /// Il polo negativo: un percorso che **non** sta nella home resta intero, o la funzione
    /// starebbe accorciando cose che non c'entrano e il referto perderebbe informazione.
    func testAPathOutsideTheHomeIsLeftAlone() {
        let home = "/Users/qualcuno"
        XCTAssertEqual(senzaNome("/Applications/Otium.app", home: home), "/Applications/Otium.app")
        XCTAssertEqual(senzaNome("/Users/qualcunaltro/Documenti", home: home),
                       "/Users/qualcunaltro/Documenti",
                       "la home di un altro utente non è la tua: accorciarla direbbe il falso")
    }

    /// E se il sistema non sa dire quale sia la home, si preferisce un percorso intero a una
    /// sostituzione cieca: `""` come prefisso corrisponde a qualunque stringa.
    func testAnEmptyHomeChangesNothing() {
        XCTAssertEqual(senzaNome("/Users/qualcuno/x", home: ""), "/Users/qualcuno/x")
    }
}
