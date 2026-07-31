import XCTest
@testable import OtiumCore

final class RampTests: XCTestCase {

    /// ISC-10 — si parte bassi e si sale. Il volume pieno al primo giorno è il modo più rapido
    /// per farsi male e disinstallare l'app.
    func testRampClimbsFromStartFactorToOne() {
        // I confini restano quelli di sempre: quello che cambia è che in mezzo c'è una linea.
        XCTAssertEqual(Ramp.factor(daysElapsed: 0, weeks: 3, startFactor: 0.55), 0.55, accuracy: 0.001)
        XCTAssertEqual(Ramp.factor(daysElapsed: 7, weeks: 3, startFactor: 0.55), 0.70, accuracy: 0.001)
        XCTAssertEqual(Ramp.factor(daysElapsed: 14, weeks: 3, startFactor: 0.55), 0.85, accuracy: 0.001)
        XCTAssertEqual(Ramp.factor(daysElapsed: 21, weeks: 3, startFactor: 0.55), 1.0, accuracy: 0.001)
        XCTAssertEqual(Ramp.factor(daysElapsed: 999, weeks: 3, startFactor: 0.55), 1.0, accuracy: 0.001)

        // **Nessuno scalino.** Il difetto della salita a settimane era il +27% comparso durante
        // la notte: qui si pretende che da un giorno all'altro non si salga mai più di un
        // ventunesimo del percorso, e che non si scenda mai.
        var ieri = Ramp.factor(daysElapsed: 0, weeks: 3, startFactor: 0.55)
        for giorno in 1...40 {
            let oggi = Ramp.factor(daysElapsed: giorno, weeks: 3, startFactor: 0.55)
            XCTAssertGreaterThanOrEqual(oggi, ieri, "la salita non torna indietro al giorno \(giorno)")
            XCTAssertLessThanOrEqual(oggi - ieri, 0.45 / 21 + 0.0001,
                                     "scalino troppo grosso al giorno \(giorno)")
            ieri = oggi
        }

        // Chi parte già al pieno non ha nessuna salita da fare, nemmeno il primo giorno.
        XCTAssertEqual(Ramp.factor(daysElapsed: 0, weeks: 3, startFactor: 1.0), 1.0, accuracy: 0.001)
    }

    func testRampIsMonotone() {
        var previous = 0.0
        for d in 0...80 {
            let f = Ramp.factor(daysElapsed: d, weeks: 6, startFactor: 0.4)
            XCTAssertGreaterThanOrEqual(f, previous)
            XCTAssertLessThanOrEqual(f, 1.0)
            previous = f
        }
    }

    func testWeeksElapsedCountsSevenDayBlocks() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(Ramp.weeksElapsed(since: start, now: start), 0)
        XCTAssertEqual(Ramp.weeksElapsed(since: start, now: start.addingTimeInterval(6 * 86400)), 0)
        XCTAssertEqual(Ramp.weeksElapsed(since: start, now: start.addingTimeInterval(8 * 86400)), 1)
        XCTAssertEqual(Ramp.weeksElapsed(since: start, now: start.addingTimeInterval(-86400)), 0)
    }

    func testRepsNeverDropBelowOne() {
        XCTAssertEqual(Ramp.reps(for: .burpee, factor: 0.01), 1)
        XCTAssertEqual(Ramp.reps(for: .squat, factor: 1.0), 15)
    }

    /// Dichiarando una pausa già fatta il numero lo scrivi tu, e su un esercizio a lati alterni
    /// un dispari non esiste: 7 affondi diventavano «3 per lato», con un lato scoperto.
    func testOddRepsAreImpossibleOnAlternatingExercises() {
        for kind in ExerciseKind.allCases where kind.isPerSide {
            for r in 1...41 {
                let fixed = Ramp.evenIfPerSide(r, for: kind)
                XCTAssertEqual(fixed % 2, 0, "\(kind) ha accettato \(fixed), che è dispari")
                XCTAssertGreaterThanOrEqual(fixed, r, "si arrotonda per eccesso, non si toglie lavoro")
                XCTAssertLessThanOrEqual(fixed - r, 1, "non si aggiunge più di una ripetizione")
                // E il per lato torna sempre: metà esatta, senza resto.
                XCTAssertEqual(Exercise(kind: kind, reps: fixed).displayReps * 2, fixed)
            }
        }
    }

    /// Il polo opposto: sugli esercizi normali un dispari è legittimo e non va toccato.
    func testNormalExercisesKeepOddNumbers() {
        for kind in ExerciseKind.allCases where !kind.isPerSide {
            XCTAssertEqual(Ramp.evenIfPerSide(7, for: kind), 7)
        }
    }
}

final class ExercisePlannerTests: XCTestCase {

    /// ISC-16 — la rotazione passa per tutti gli esercizi del pool, ciclicamente.
    func testRotationCyclesThroughTheWholePool() {
        let planner = ExercisePlanner(pool: [.squat, .pushUp, .lunge], vigorousPool: [.burpee])
        let kinds = (1...6).map { planner.exercise(breakIndex: $0, kind: .micro, factor: 1.0).kind }
        XCTAssertEqual(Set(kinds), Set([.squat, .pushUp, .lunge]))
        XCTAssertEqual(Array(kinds.prefix(3)), Array(kinds.suffix(3)), "il ciclo si ripete uguale")
    }

    /// ISC-16 — il polo negativo di questa proprietà: un pool scritto **male di proposito**,
    /// con due esercizi per le gambe uno dietro l'altro.
    ///
    /// Se `spreadByMuscleGroup` fosse l'identità — cioè se la correzione non ci fosse — la
    /// prima coppia sarebbe squat → affondi, gambe due volte, e questo test sarebbe rosso.
    /// È l'unico modo di sapere che il verde significa qualcosa.
    func testABadlyOrderedPoolGetsStraightened() {
        let badOrder: [ExerciseKind] = [.squat, .lunge, .pushUp, .calfRaise]
        XCTAssertEqual(badOrder[0].muscleGroup, badOrder[1].muscleGroup, "il pool di partenza collide")

        let planner = ExercisePlanner(pool: badOrder)
        let kinds = (1...12).map { planner.exercise(breakIndex: $0, kind: .micro, factor: 1.0).kind }
        XCTAssertEqual(Set(kinds), Set(badOrder), "nessun esercizio perso per strada")
        for (a, b) in zip(kinds, kinds.dropFirst()) {
            XCTAssertNotEqual(a.muscleGroup, b.muscleGroup,
                              "\(a.italianName) → \(b.italianName): stesso gruppo di fila")
        }
    }

    /// E il pool di serie regge la stessa proprietà, giro di boa compreso.
    func testDefaultPoolNeverRepeatsAMuscleGroupBackToBack() {
        let planner = ExercisePlanner(pool: Settings().exercisePool)
        let kinds = (1...12).map { planner.exercise(breakIndex: $0, kind: .micro, factor: 1.0).kind }
        for (a, b) in zip(kinds, kinds.dropFirst()) {
            XCTAssertNotEqual(a.muscleGroup, b.muscleGroup,
                              "\(a.italianName) → \(b.italianName): stesso gruppo di fila")
        }
    }

    /// Quando i gruppi sono meno degli esercizi, una ripetizione è aritmeticamente inevitabile:
    /// il riordino non deve andare in loop né perdere pezzi, deve solo fare del suo meglio.
    func testSpreadKeepsEveryExerciseEvenWhenGroupsCollide() {
        let ordered = ExercisePlanner.spreadByMuscleGroup([.squat, .lunge, .pushUp])
        XCTAssertEqual(Set(ordered), Set([.squat, .lunge, .pushUp]))
        XCTAssertEqual(ordered.count, 3)
        XCTAssertNotEqual(ordered[0].muscleGroup, ordered[1].muscleGroup)
    }

    func testLongBreaksDrawFromTheVigorousPool() {
        let planner = ExercisePlanner(pool: [.squat, .pushUp], vigorousPool: [.burpee, .jumpingJack])
        for i in 1...4 {
            XCTAssertTrue(planner.exercise(breakIndex: i, kind: .long, factor: 1.0).kind.isVigorous)
        }
    }

    /// Un pool vuoto non deve far esplodere niente: si degrada, non si schianta.
    func testEmptyPoolFallsBackInsteadOfCrashing() {
        let planner = ExercisePlanner(pool: [], vigorousPool: [])
        XCTAssertEqual(planner.exercise(breakIndex: 1, kind: .micro, factor: 1.0).kind, .squat)
        XCTAssertEqual(planner.exercise(breakIndex: 1, kind: .long, factor: 1.0).kind, .jumpingJack)
    }

    /// ISC-15 — il tempo minimo scala con le ripetizioni.
    func testMinimumSecondsTracksReps() {
        XCTAssertEqual(Exercise(kind: .squat, reps: 10).minimumSeconds, 25, accuracy: 0.001)
        XCTAssertEqual(Exercise(kind: .burpee, reps: 8).minimumSeconds, 36, accuracy: 0.001)
        XCTAssertGreaterThan(
            Exercise(kind: .squat, reps: 15).minimumSeconds,
            Exercise(kind: .squat, reps: 8).minimumSeconds
        )
    }
}

final class LedgerTests: XCTestCase {

    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-test-\(UUID().uuidString).jsonl")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
        super.tearDown()
    }

    /// ISC-21 — quello che è successo finisce su disco, riga per riga, e si rilegge uguale.
    func testAppendAndReadRoundTrip() {
        let ledger = Ledger(url: tempURL)
        let now = Date()
        ledger.append(LedgerEntry(timestamp: now, type: .completed, breakKind: .micro,
                                  exercise: .squat, reps: 15))
        ledger.append(LedgerEntry(timestamp: now, type: .active, seconds: 300))

        let entries = ledger.entries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].exercise, .squat)
        XCTAssertEqual(entries[0].reps, 15)
        XCTAssertEqual(entries[1].seconds, 300)
    }

    func testAppendIsAdditiveNotOverwriting() {
        let ledger = Ledger(url: tempURL)
        for i in 0..<20 {
            ledger.append(LedgerEntry(timestamp: Date(), type: .completed,
                                      breakKind: .micro, exercise: .squat, reps: i + 1))
        }
        XCTAssertEqual(ledger.entries().count, 20)
    }

    /// ISC-22 — i totali del giorno: ripetizioni, bout vigorosi, tempo davanti al Mac.
    func testDailySummaryAggregates() {
        let ledger = Ledger(url: tempURL)
        let now = Date()
        ledger.append(LedgerEntry(timestamp: now, type: .active, seconds: 3600))
        ledger.append(LedgerEntry(timestamp: now, type: .active, seconds: 1800))
        ledger.append(LedgerEntry(timestamp: now, type: .completed, breakKind: .micro, exercise: .squat, reps: 15))
        ledger.append(LedgerEntry(timestamp: now, type: .completed, breakKind: .micro, exercise: .squat, reps: 15))
        ledger.append(LedgerEntry(timestamp: now, type: .completed, breakKind: .long, exercise: .burpee, reps: 8))
        ledger.append(LedgerEntry(timestamp: now, type: .skipped, breakKind: .micro, reason: "escapePhrase"))
        ledger.append(LedgerEntry(timestamp: now, type: .natural, breakKind: .long, seconds: 600))

        let s = ledger.summary(for: now)
        XCTAssertEqual(s.activeSeconds, 5400, accuracy: 0.001)
        XCTAssertEqual(s.activeHoursLabel, "1h 30m")
        XCTAssertEqual(s.repsByExercise[.squat], 30)
        XCTAssertEqual(s.repsByExercise[.burpee], 8)
        XCTAssertEqual(s.totalReps, 38)
        XCTAssertEqual(s.completed, 3)
        XCTAssertEqual(s.skipped, 1)
        XCTAssertEqual(s.natural, 1)
        XCTAssertEqual(s.vigorousBouts, 1, "solo il burpee conta come bout vigoroso")
    }

    func testSummaryIgnoresOtherDays() {
        let ledger = Ledger(url: tempURL)
        let today = Date()
        let lastWeek = today.addingTimeInterval(-8 * 86400)
        ledger.append(LedgerEntry(timestamp: lastWeek, type: .completed, breakKind: .micro, exercise: .squat, reps: 99))
        ledger.append(LedgerEntry(timestamp: today, type: .completed, breakKind: .micro, exercise: .squat, reps: 15))

        XCTAssertEqual(ledger.summary(for: today).repsByExercise[.squat], 15)
    }

    /// Gli eventi rumorosi non sporcano il registro.
    func testWarningAndStartProduceNoLedgerRow() {
        let plan = BreakPlan(index: 1, kind: .micro, duration: 90,
                             exercise: Exercise(kind: .squat, reps: 15))
        XCTAssertNil(Ledger.entry(for: .warningStarted(plan), now: Date()))
        XCTAssertNil(Ledger.entry(for: .breakStarted(plan), now: Date()))
    }

    func testEventMappingCarriesTheReason() {
        let plan = BreakPlan(index: 1, kind: .micro, duration: 90,
                             exercise: Exercise(kind: .squat, reps: 15))
        let entry = Ledger.entry(for: .breakSkipped(plan, .escapePhrase), now: Date())
        XCTAssertEqual(entry?.type, .skipped)
        XCTAssertEqual(entry?.reason, "escapePhrase")

        let natural = Ledger.entry(for: .naturalBreak(seconds: 400, creditedLong: true), now: Date())
        XCTAssertEqual(natural?.type, .natural)
        XCTAssertEqual(natural?.breakKind, .long)
        XCTAssertEqual(natural?.seconds, 400)
    }
}

final class EvidenceTests: XCTestCase {

    /// ISC-23 — ogni fonte è completa: senza link e anno, la citazione è decorazione.
    func testEveryStudyIsFullyCited() {
        XCTAssertGreaterThanOrEqual(Evidence.all.count, 6)
        for study in Evidence.all {
            XCTAssertFalse(study.claim.isEmpty, "\(study.id): claim vuoto")
            XCTAssertFalse(study.citation.isEmpty, "\(study.id): citazione vuota")
            XCTAssertFalse(study.governs.isEmpty, "\(study.id): non dice cosa governa")
            XCTAssertTrue(study.url.hasPrefix("https://"), "\(study.id): link non https")
            XCTAssertGreaterThan(study.year, 1990)
        }
        XCTAssertEqual(Set(Evidence.all.map(\.id)).count, Evidence.all.count, "id duplicati")
    }

    /// ISC-24 — la 20-20-20 è dichiarata come funzione assente, non nascosta sotto il tappeto.
    func testTheUnimplementedRuleIsDeclared() {
        let study = Evidence.twentyTwentyTwenty
        XCTAssertTrue(study.claim.contains("NON IMPLEMENTATA"))
        XCTAssertFalse(Evidence.implemented.contains { $0.id == study.id })
    }
}

final class SettingsTests: XCTestCase {

    func testCadenceAIsTheChosenOne() {
        let c = Cadence.optionA
        XCTAssertEqual(c.intervalSeconds, 1800)
        XCTAssertEqual(c.microDurationSeconds, 90)
        XCTAssertEqual(c.longDurationSeconds, 300)
        XCTAssertEqual(c.longEveryNBreaks, 3)
        XCTAssertEqual(c.duration(for: .micro), 90)
        XCTAssertEqual(c.duration(for: .long), 300)
    }

    func testSettingsRoundTripThroughDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-settings-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        var s = Settings()
        s.escapePhrase = "mi arrendo"
        s.cadence.intervalSeconds = 1200
        XCTAssertTrue(SettingsStore.save(s, to: url))

        let loaded = SettingsStore.load(from: url)
        XCTAssertEqual(loaded.escapePhrase, "mi arrendo")
        XCTAssertEqual(loaded.cadence.intervalSeconds, 1200)
    }

    /// Un file di configurazione più vecchio del codice non deve far ripartire da zero l'app:
    /// le chiavi mancanti ricadono sui default, non fanno fallire l'intera decodifica.
    func testPartialSettingsFileFallsBackToDefaults() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-partial-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try? #"{"escapePhrase":"basta"}"#.data(using: .utf8)!.write(to: url)

        let loaded = SettingsStore.load(from: url)
        XCTAssertEqual(loaded.escapePhrase, "basta")
        XCTAssertEqual(loaded.cadence.intervalSeconds, Cadence.optionA.intervalSeconds)
        XCTAssertEqual(loaded.vigorousDailyTarget, 3)
    }

    func testMissingSettingsFileYieldsDefaults() {
        let missing = URL(fileURLWithPath: "/tmp/otium-nope-\(UUID().uuidString).json")
        XCTAssertEqual(SettingsStore.load(from: missing).cadence, Cadence.optionA)
    }
}

/// Le varianti dentro la pausa: scegliere il *come*, non il *se*.
final class VariantTests: XCTestCase {

    private func engineInBreak() -> SessionEngine {
        var s = Settings()
        s.startDate = Date()
        // Volume pieno, così i numeri sono quelli veri. **Si dice con la percentuale, non con le
        // settimane**: da quando la salita è giornaliera, «1 settimana» vuol dire una settimana di
        // salita vera, mentre prima era il modo obliquo di dire «nessuna salita».
        s.rampStartFactor = 1.0
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 120)
        engine.forceBreakNow(now: Date(), kind: .micro)
        return engine
    }

    func testPushUpOffersTheVariantsThatWereAskedFor() {
        let variants = ExerciseKind.pushUp.variants
        XCTAssertTrue(variants.contains(.diamondPushUp))
        XCTAssertTrue(variants.contains(.archerPushUp))
        XCTAssertTrue(variants.contains(.benchDip), "i dip su sedia (bench dips)")
        XCTAssertFalse(variants.contains(.pushUp), "un esercizio non è variante di sé stesso")
    }

    /// Le ripetizioni scalano con la difficoltà: un archer push-up non se ne fanno dieci.
    func testHarderVariantsAskForFewerReps() {
        XCTAssertLessThan(ExerciseKind.archerPushUp.baseReps, ExerciseKind.pushUp.baseReps)
        XCTAssertLessThan(ExerciseKind.diamondPushUp.baseReps, ExerciseKind.pushUp.baseReps)
        XCTAssertGreaterThan(ExerciseKind.inclinePushUp.baseReps, ExerciseKind.pushUp.baseReps,
                             "gli inclinati sono la regressione: più facili, più ripetizioni")
    }

    func testEveryExerciseIsFullyDescribed() {
        for kind in ExerciseKind.allCases {
            XCTAssertFalse(kind.italianName.isEmpty, "\(kind): senza nome")
            XCTAssertFalse(kind.cue.isEmpty, "\(kind): senza istruzione")
            XCTAssertFalse(kind.muscleGroup.isEmpty, "\(kind): senza gruppo muscolare")
            XCTAssertGreaterThan(kind.baseReps, 0)
            XCTAssertGreaterThan(kind.secondsPerRep, 0)
            XCTAssertFalse(kind.variants.contains(kind), "\(kind): variante di sé stesso")
        }
        XCTAssertGreaterThanOrEqual(ExerciseKind.allCases.count, 16)
    }

    func testSwappingChangesTheExerciseWithinTheSameBreak() {
        var engine = engineInBreak()
        let original = engine.plan?.exercise.kind
        guard let target = original?.variants.first else { return XCTFail("nessuna variante") }

        XCTAssertTrue(engine.swapExercise(to: target, now: Date()))
        XCTAssertEqual(engine.plan?.exercise.kind, target)
        XCTAssertEqual(engine.phase, .breaking, "la pausa non si interrompe: cambia solo l'esercizio")
        XCTAssertEqual(engine.plan?.exercise.reps, target.baseReps)
    }

    /// Non si può usare il cambio per scegliersi il più corto all'ultimo istante: il cronometro
    /// del "fatto" riparte da capo a ogni scambio.
    func testSwappingRestartsTheAntiBluffTimer() {
        var engine = engineInBreak()
        guard let plan = engine.plan, let target = plan.exercise.kind.variants.first else {
            return XCTFail("nessuna variante")
        }
        // Quasi pronto con l'esercizio originale…
        for _ in 0..<Int(plan.exercise.minimumSeconds) + 2 {
            engine.tick(elapsed: 1, idle: 0, now: Date())
        }
        XCTAssertTrue(engine.canFinishNow)

        engine.swapExercise(to: target, now: Date())
        XCTAssertFalse(engine.canFinishNow, "il tempo minimo riparte dalla variante scelta")
        XCTAssertTrue(engine.markExerciseDone().isEmpty)
        XCTAssertEqual(engine.phase, .breaking)
    }

    /// Solo verso una variante: non si salta a un esercizio qualunque.
    func testSwappingToAnUnrelatedExerciseIsRefused() {
        var engine = engineInBreak()
        let unrelated = ExerciseKind.allCases.first {
            !( engine.plan?.exercise.kind.variants.contains($0) ?? true ) && $0 != engine.plan?.exercise.kind
        }
        guard let unrelated else { return }
        XCTAssertFalse(engine.swapExercise(to: unrelated, now: Date()))
        XCTAssertNotEqual(engine.plan?.exercise.kind, unrelated)
    }

    func testNoSwappingOutsideABreak() {
        var s = Settings(); s.startDate = Date()
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 120)
        XCTAssertFalse(engine.swapExercise(to: .diamondPushUp, now: Date()))
        XCTAssertTrue(engine.variants(now: Date()).isEmpty)
    }

    /// Il pool di serie è più vario di prima, e resta senza gruppi ripetuti di fila.
    func testDefaultPoolIsWiderAndStillWellSpread() {
        let settings = Settings()
        XCTAssertGreaterThanOrEqual(settings.exercisePool.count, 6)
        XCTAssertTrue(settings.vigorousPool.contains(.mountainClimber))

        let planner = settings.planner
        let kinds = (1...12).map { planner.exercise(breakIndex: $0, kind: .micro, factor: 1.0).kind }
        for (a, b) in zip(kinds, kinds.dropFirst()) {
            XCTAssertNotEqual(a.muscleGroup, b.muscleGroup, "\(a.italianName) → \(b.italianName)")
        }
        XCTAssertGreaterThanOrEqual(Set(kinds).count, 6, "la rotazione passa da tutti")
    }
}

/// Le fonti ruotano, e le citazioni pure.
final class RotatingTextTests: XCTestCase {

    /// Ogni pausa mostra una fonte diversa, e il giro si chiude sulle sole fonti che
    /// giustificano qualcosa che sta accadendo.
    func testTheStudyChangesAtEveryBreak() {
        let shown = (1...Evidence.implemented.count).map { Evidence.study(forBreak: $0).id }
        XCTAssertEqual(Set(shown).count, Evidence.implemented.count, "nessuna fonte ripetuta nel giro")
        for (a, b) in zip(shown, shown.dropFirst()) {
            XCTAssertNotEqual(a, b, "due pause di fila con lo stesso testo")
        }
        XCTAssertEqual(Evidence.study(forBreak: 1).id,
                       Evidence.study(forBreak: 1 + Evidence.implemented.count).id, "il giro si chiude")
    }

    /// Segnalato guardando lo schermo il 2026-07-27: durante un esercizio era comparso
    /// «Non promesso: una funzione deliberatamente assente — regola 20-20-20». Vero, ma risponde
    /// a una domanda che nessuno ha fatto mentre fa i push-up. Fuori dal giro della pausa.
    func testNoDisclaimerEverAppearsDuringABreak() {
        for index in 1...200 {
            let study = Evidence.study(forBreak: index)
            XCTAssertFalse(Evidence.disclaimers.contains { $0.id == study.id },
                           "pausa \(index): mostrata una non-promessa (\(study.id))")
        }
    }

    func testStudyRotationSurvivesAbsurdIndexes() {
        XCTAssertNoThrow(Evidence.study(forBreak: 0))
        XCTAssertNoThrow(Evidence.study(forBreak: -7))
        XCTAssertNoThrow(Evidence.study(forBreak: 10_000))
    }

    /// Il catalogo dichiara anche cosa l'app NON promette: la 20-20-20 e il beneficio cognitivo
    /// immediato dei 90 secondi. Devono restare fuori dalle fonti "a supporto".
    func testDisclaimersAreDeclaredAndExcludedFromSupportingSources() {
        XCTAssertEqual(Evidence.disclaimers.count, 2)
        for d in Evidence.disclaimers {
            XCTAssertTrue(d.claim.contains("NON"), "\(d.id) deve dichiararsi come non-promessa")
            XCTAssertFalse(Evidence.implemented.contains { $0.id == d.id })
            XCTAssertTrue(Evidence.all.contains { $0.id == d.id }, "ma resta visibile in app")
        }
    }

    /// La domanda del principale sulla concentrazione ha una fonte dedicata.
    func testTheConcentrationEvidenceIsPresent() {
        XCTAssertTrue(Evidence.all.contains { $0.id == "biwer-2023" })
        XCTAssertTrue(Evidence.all.contains { $0.id == "ariga-lleras-2011" })
    }

    func testEveryQuoteHasAnIdentifiableWork() {
        XCTAssertGreaterThanOrEqual(Quotes.all.count, 10)
        for q in Quotes.all {
            XCTAssertFalse(q.text.isEmpty)
            XCTAssertFalse(q.author.isEmpty, "citazione senza autore: \(q.text)")
            XCTAssertFalse(q.work.isEmpty, "citazione senza opera: \(q.text) — \(q.author)")
        }
    }

    /// Il criterio di ammissione, congelato in un test: in questo pool niente attribuzioni
    /// generiche, e nessun anonimo travestito da autore.
    ///
    /// La versione precedente vietava la stringa «lao» **nell'autore**, per tenere fuori la frase
    /// «la natura non ha fretta» — una parafrasi moderna che circola come di Lao Tzu. Vietava
    /// però anche le citazioni **vere** dal Tao Te Ching, che hanno capitolo e traduzione. Il
    /// divieto giusto è sul testo conteso, non sul nome di un autore reale.
    func testNoUnsourcedAttributions() {
        for q in Quotes.all {
            XCTAssertFalse(q.work.lowercased().contains("anonim"))
            XCTAssertFalse(q.work.lowercased().hasPrefix("http"), "l'opera, non il sito")
            XCTAssertFalse(q.text.contains("non ha fretta"),
                           "quella frase non è nel Tao Te Ching: vive fra le anonime, non qui")
            // Un'opera che si dichiara incerta non è un'opera identificabile: quelle frasi
            // stanno in `Mindful`, dove essere anonime è previsto.
            for hedge in ["tradizione", "attr.", "attribuit"] {
                XCTAssertFalse(q.work.lowercased().contains(hedge),
                               "attribuzione tentennante in un pool che le vieta: \(q.text)")
            }
        }
    }

    /// Nessuna frase ripetuta dentro tutto il corpus: due copie della stessa riga con id diverso
    /// tornerebbero due volte nello stesso giro di mazzo, ed è proprio ciò che il mazzo evita.
    func testNoDuplicateTextsAcrossThePools() {
        let texts = PhraseLibrary.breakPool(includingUser: false).map(\.text)
        let unique = Set(texts)
        XCTAssertEqual(unique.count, texts.count, "frasi duplicate nel corpus")

        let ids = PhraseLibrary.breakPool(includingUser: false).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "id duplicati: il mazzo ne perderebbe una")

        // **Anche l'inglese**, e non è un di più: il 29 luglio 2026 il corpus conteneva lo stesso
        // passo di Bacon due volte, «Certi libri…» e «Alcuni libri…», con inglese identico. Il
        // controllo sull'italiano non poteva vederlo — due traduzioni diverse dello stesso testo
        // sono due stringhe diverse — e un doppione così esce due volte nello stesso mese.
        let englishes = PhraseLibrary.breakPool(includingUser: false)
            .map(\.textEN).filter { !$0.isEmpty }
        let ripetuti = Dictionary(grouping: englishes, by: { $0 }).filter { $0.value.count > 1 }
        XCTAssertTrue(ripetuti.isEmpty, "stesso passo tradotto due volte: \(ripetuti.keys.sorted())")
    }

    /// La voce dell'app non prende una firma, mai.
    ///
    /// `.voce` sono righe scritte per Otium: a schermo escono senza caporali e senza credito,
    /// perché non citano nessuno. Il giorno che una di queste si prende un'attribuzione torna a
    /// essere quello che era prima del 2026-07-29 — testo dell'AI vestito da massima — e stavolta
    /// con un nome sotto, che è peggio. Il pool anonimo (`.mindful` senza attribuzione) resta
    /// legittimo: lì l'autore è esistito e non lo sappiamo.
    func testTheAppsOwnVoiceIsNeverSigned() {
        let voci = PhraseLibrary.breakPool(includingUser: false).filter { $0.kind == .voce }
        XCTAssertGreaterThan(voci.count, 20, "il pool della voce si è svuotato: è un errore, non una pulizia")
        for v in voci {
            XCTAssertTrue(v.attribution.isEmpty, "la voce dell'app si è presa una firma: \(v.text)")
            XCTAssertTrue(v.attributionEN.isEmpty, "la voce dell'app si è presa una firma: \(v.text)")
        }
    }

    /// Niente marcatori markdown dentro le frasi.
    ///
    /// `Text("«\(phrase.localizedText)»")` interpola, e un valore interpolato **non** passa dal
    /// parser markdown: gli asterischi arrivano sullo schermo così come sono. Il 29 luglio 2026
    /// una frase diceva `lo stai **di fila**` e si è vista solo guardando il provino — il cancello
    /// delle citazioni cerca il testo nella fonte e non sa niente di come è fatto lo schermo.
    /// Questo test è quella lettura, resa automatica.
    func testNoMarkdownMarkersInPhrases() {
        for p in PhraseLibrary.breakPool(includingUser: false) {
            for testo in [p.text, p.textEN, p.attribution, p.attributionEN] where !testo.isEmpty {
                XCTAssertFalse(testo.contains("**"), "asterischi di grassetto a schermo: \(testo)")
                XCTAssertFalse(testo.contains("__"), "trattini bassi di markdown a schermo: \(testo)")
                XCTAssertNil(testo.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression),
                             "link markdown a schermo: \(testo)")
            }
        }
    }

    /// Il numero che rende vera la promessa «frasi sempre diverse per almeno un mese».
    ///
    /// Il conto: una pausa ogni 30 minuti di lavoro attivo fa ~16 pause al giorno; su 30 giorni
    /// sono ~480 estrazioni. Se il corpus è più piccolo, il mazzo si rimescola prima e le frasi
    /// tornano. Questo test è la promessa messa per iscritto: se qualcuno taglia il corpus, cade.
    func testCorpusIsLargeEnoughForAMonthWithoutRepeats() {
        let pool = PhraseLibrary.breakPool(includingUser: false)
        let breaksPerDay = (8 * 60) / 30          // otto ore di lavoro attivo, una pausa ogni 30'
        let month = breaksPerDay * 30
        XCTAssertGreaterThanOrEqual(pool.count, month,
                                    "servono almeno \(month) frasi per un mese senza ripetizioni, ce ne sono \(pool.count)")
    }

    /// Un file scritto prima che le citazioni esistessero non deve azzerare la rotazione.
    func testOldSnapshotFileStillRestoresTheRotation() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-old-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try? #"{"breakIndex":9,"microsSinceLong":1,"savedAt":"2026-07-26T18:00:00Z"}"#
            .data(using: .utf8)!.write(to: url)

        let loaded = RotationStore.load(from: url)
        XCTAssertEqual(loaded?.breakIndex, 9)
        XCTAssertEqual(loaded?.launchCount, 0, "chiave assente → default, non fallimento")
    }
}

/// Ripresa a caldo e tempo dichiarato.
final class ResumeTests: XCTestCase {

    private func makeEngine() -> SessionEngine {
        var s = Settings(); s.startDate = Date()
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Chiudi e riapri dopo pochi secondi: il conto riprende, non si butta mezz'ora.
    func testReopeningWithinTheGraceContinuesTheCount() {
        var engine = makeEngine()
        let snapshot = EngineSnapshot(breakIndex: 3, microsSinceLong: 1, launchCount: 2,
                                      activeSeconds: 1500,
                                      savedAt: Date().addingTimeInterval(-30))
        let outcome = engine.restore(snapshot)
        // Il divario fra due `Date()` non è **mai** esattamente 30: confrontarlo con
        // l'uguaglianza esatta rendeva questo test intermittente — 2 fallimenti su 8 giri.
        // Un test che a volte passa non è un test: si asserisce il caso, e i numeri con tolleranza.
        guard case .continued(let seconds, let gap) = outcome else {
            return XCTFail("atteso continued, ricevuto \(outcome)")
        }
        XCTAssertEqual(seconds, 1500, accuracy: 1)
        XCTAssertEqual(gap, 30, accuracy: 2)
        XCTAssertEqual(engine.clock.activeSeconds, 1500, accuracy: 1)
    }

    /// Oltre la finestra, no: quell'assenza **era** una pausa, e ripartire da zero è la risposta
    /// giusta, non una perdita.
    func testReopeningAfterTheGraceStartsFresh() {
        var engine = makeEngine()
        let snapshot = EngineSnapshot(breakIndex: 3, microsSinceLong: 1, launchCount: 2,
                                      activeSeconds: 1500,
                                      savedAt: Date().addingTimeInterval(-20 * 60))
        let outcome = engine.restore(snapshot)
        guard case .restarted = outcome else { return XCTFail("atteso restarted, ricevuto \(outcome)") }
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 0.001)
        XCTAssertEqual(engine.breakIndex, 3, "la rotazione però si conserva sempre")
    }

    /// La finestra di grazia vale quanto una pausa piena, e non per caso.
    func testGraceEqualsAFullBreakByDefault() {
        XCTAssertEqual(Settings().resumeGraceSeconds, Settings().cadence.longDurationSeconds)
        XCTAssertEqual(Settings().resumeGraceSeconds, 300)
    }

    func testDeclaringTimeAlreadySeatedMovesTheCounter() {
        var engine = makeEngine()
        let after = engine.declareTimeAlreadySeated(30 * 60)
        XCTAssertEqual(after, 1800, accuracy: 1)
        XCTAssertEqual(engine.secondsUntilNextBreak, 0, accuracy: 1, "mezz'ora seduto: la pausa è dovuta")
    }

    /// **Contratto cambiato il 2026-07-27.** Prima dichiarare meno del misurato non toglieva
    /// tempo — sembrava prudente, e invece rendeva impossibile correggere un errore all'insù:
    /// se avevi dichiarato tre ore per sbaglio, restavano lì per sempre. Ora «in tutto» vuol
    /// dire *esattamente*, in entrambe le direzioni; «in più» è l'altra frase, e somma.
    func testTotalModeCanCorrectDownwardsWhileAddModeSums() {
        var engine = makeEngine()
        for _ in 0..<100 { engine.tick(elapsed: 10, idle: 0, now: Date()) }
        let measured = engine.clock.activeSeconds
        XCTAssertGreaterThan(measured, 900)

        XCTAssertEqual(engine.declareTimeAlreadySeated(60, mode: .total), 60, accuracy: 1,
                       "«in tutto 1 minuto» significa un minuto, non il massimo")
        XCTAssertEqual(engine.declareTimeAlreadySeated(600, mode: .add), 660, accuracy: 1,
                       "«in più 10 minuti» si somma a quello che c'è")
    }

    /// La frase contesa è ammessa, ma **senza il nome che non le spetta**: vive fra le anonime.
    func testTheDisputedQuoteIsPresentAsAnonymous() {
        guard let phrase = Mindful.all.first(where: { $0.text.contains("La natura non ha fretta") }) else {
            return XCTFail("la frase doveva restare, come anonima")
        }
        XCTAssertTrue(phrase.attribution.isEmpty, "nessuna firma: non si sa di chi sia")
        XCTAssertEqual(phrase.credit, "anonimo", "e a schermo si dice così, non si lascia vuoto")
        XCTAssertFalse(Quotes.all.contains { $0.text.contains("non ha fretta") },
                       "e non deve rientrare dalla finestra nel pool delle verificate")
    }
}

/// Nessun markdown crudo nei testi che finiscono a schermo.
///
/// `Text` interpreta il markdown **solo** su una stringa letterale: su una concatenazione, o su
/// un valore che arriva da un modello, gli asterischi si stampano come sono. Visti a schermo il
/// 2026-07-27 in tre punti diversi — è una classe, non una svista, e questo test la chiude.
final class NoRawMarkdownTests: XCTestCase {

    private func assertClean(_ text: String, _ label: String) {
        XCTAssertFalse(text.contains("**"), "\(label): asterischi markdown crudi → \(text)")
        XCTAssertFalse(text.contains("__"), "\(label): underscore markdown crudi")
    }

    func testStudiesCarryNoRawMarkdown() {
        for s in Evidence.all {
            assertClean(s.claim, "claim di \(s.id)")
            assertClean(s.governs, "governs di \(s.id)")
            assertClean(s.citation, "citazione di \(s.id)")
        }
    }

    func testQuotesCarryNoRawMarkdown() {
        for q in Quotes.all {
            assertClean(q.text, "citazione di \(q.author)")
            assertClean(q.work, "opera di \(q.author)")
        }
    }

    func testExerciseTextsCarryNoRawMarkdown() {
        for k in ExerciseKind.allCases {
            assertClean(k.cue, "istruzione di \(k.rawValue)")
            assertClean(k.italianName, "nome di \(k.rawValue)")
        }
    }
}

/// Pause dichiarate a posteriori, e la distinzione affondo / split squat.
final class DeclaredBreaksTests: XCTestCase {
    /// **L'ora fissa, e perché.**
    ///
    /// `entry(minutiFa)` costruiva i timestamp rispetto a `Date()`, e `Stats.compute(period:.day)`
    /// guarda dalla mezzanotte a adesso: alle 00:06 una riga «di 120 minuti fa» finisce ieri, e
    /// mezza suite diventa rossa. Trovato nell'audit del 2026-07-28, girando i test dopo la
    /// mezzanotte — cioè per caso. Una suite che dipende dall'ora del giorno è una suite di cui
    /// non ci si fida, e la si smette di guardare proprio quando avrebbe qualcosa da dire.
    private let adesso = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)



    private func makeEngine() -> SessionEngine {
        var s = Settings(); s.startDate = Date()
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Dichiarare una pausa passata **non tocca il conto**: è un'informazione, non una pausa
    /// presa adesso. La prima versione lo azzerava, buttando via i minuti già misurati — che è
    /// esattamente ciò che il principale ha notato guardando il timer tornare indietro.
    func testRecordingABreakAdvancesTheCycleButLeavesTheClockAlone() {
        var engine = makeEngine()
        for _ in 0..<100 { engine.tick(elapsed: 10, idle: 0, now: Date()) }
        let measured = engine.clock.activeSeconds
        XCTAssertGreaterThan(measured, 900)

        engine.recordCompletedBreak(kind: .micro)
        XCTAssertEqual(engine.breakIndex, 1, "la rotazione avanza")
        XCTAssertEqual(engine.microsSinceLong, 1, "e il ciclo micro/piena pure")
        XCTAssertEqual(engine.clock.activeSeconds, measured, accuracy: 0.001,
                       "ma i minuti misurati restano dov'erano")
    }

    /// Il timore sull'avvio al login, misurato invece che discusso: il Mac acceso senza nessuno
    /// davanti **non** accumula tempo. È la ragione per cui l'orologio conta l'attività e non
    /// l'orologio a muro — e per cui partire all'accensione non crea tempi morti.
    func testStartingAtLoginWithNobodyThereAccumulatesNothing() {
        var engine = makeEngine()
        var idle = 0.0
        for _ in 0..<120 {              // venti minuti di Mac acceso e scrivania vuota
            idle += 10
            engine.tick(elapsed: 10, idle: idle, now: Date())
        }
        XCTAssertEqual(engine.clock.activeSeconds, 0, accuracy: 60,
                       "acceso ma non usato non è tempo di lavoro")
        XCTAssertEqual(engine.phase, .working, "e nessuna pausa è scattata a vuoto")
    }

    /// Una pausa piena dichiarata riazzera il ciclo: la prossima non è già quella lunga.
    func testRecordingALongBreakResetsTheLongCycle() {
        var engine = makeEngine()
        engine.recordCompletedBreak(kind: .micro)
        engine.recordCompletedBreak(kind: .micro)
        XCTAssertEqual(engine.nextBreakKind(), .long, "dopo due micro tocca la piena")

        engine.recordCompletedBreak(kind: .long)
        XCTAssertEqual(engine.microsSinceLong, 0)
        XCTAssertEqual(engine.nextBreakKind(), .micro, "riparte il ciclo")
    }

    /// Affondo e split squat **non** sono lo stesso esercizio, ma sono parenti stretti: uno solo
    /// sta nella rotazione, l'altro è una sua variante. Averli entrambi in rotazione faceva
    /// sembrare l'app ripetitiva senza aggiungere niente.
    func testSplitSquatIsAVariantOfTheLungeNotASeparateRotationEntry() {
        XCTAssertFalse(Settings().exercisePool.contains(.splitSquat))
        XCTAssertTrue(Settings().exercisePool.contains(.lunge))
        XCTAssertTrue(ExerciseKind.lunge.variants.contains(.splitSquat))
        XCTAssertEqual(ExerciseKind.lunge.muscleGroup, ExerciseKind.splitSquat.muscleGroup)
        // …ma restano distinti, e l'istruzione lo dice: nell'affondo il piede si muove, nello
        // split squat no.
        XCTAssertNotEqual(ExerciseKind.lunge.cue, ExerciseKind.splitSquat.cue)
        XCTAssertTrue(ExerciseKind.splitSquat.cue.contains("non si muovono"))
    }
}

/// Togliere una pausa segnata, e le statistiche.
final class StatsTests: XCTestCase {
    /// **L'ora fissa, e perché.**
    ///
    /// `entry(minutiFa)` costruiva i timestamp rispetto a `Date()`, e `Stats.compute(period:.day)`
    /// guarda dalla mezzanotte a adesso: alle 00:06 una riga «di 120 minuti fa» finisce ieri, e
    /// mezza suite diventa rossa. Trovato nell'audit del 2026-07-28, girando i test dopo la
    /// mezzanotte — cioè per caso. Una suite che dipende dall'ora del giorno è una suite di cui
    /// non ci si fida, e la si smette di guardare proprio quando avrebbe qualcosa da dire.
    private let adesso = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)



    private func entry(_ minutesAgo: Double, _ type: EntryType, kind: BreakKind = .micro,
                       exercise: ExerciseKind? = nil, reps: Int? = nil,
                       seconds: Double? = nil, reason: String? = nil) -> LedgerEntry {
        LedgerEntry(timestamp: adesso.addingTimeInterval(-minutesAgo * 60), type: type,
                    breakKind: kind, exercise: exercise, reps: reps, seconds: seconds, reason: reason)
    }

    /// Il caso vero che ha fatto nascere la funzione: segni una pausa a mano, poi arriva davvero,
    /// e finisce contata due volte.
    func testUndoRemovesTheDeclaredBreakFromTheCount() {
        let rows = [
            entry(60, .completed, reason: "dichiarata"),
            entry(30, .completed, exercise: .benchDip, reps: 7),
            entry(29, .undo, reason: "tolta a mano"),
        ]
        let s = Stats.compute(entries: rows, period: .day, now: adesso)
        XCTAssertEqual(s.completed, 1, "una segnata + una vera − una tolta = una")
        XCTAssertEqual(s.moments.count, 1)
    }

    func testUndoOnTheEngineWalksTheCycleBack() {
        var settings = Settings(); settings.startDate = Date()
        var engine = SessionEngine(settings: settings, maxCredibleElapsed: 120)
        engine.recordCompletedBreak(kind: .micro)
        engine.recordCompletedBreak(kind: .micro)
        XCTAssertEqual(engine.breakIndex, 2)
        XCTAssertEqual(engine.nextBreakKind(), .long)

        XCTAssertTrue(engine.undoDeclaredBreak(kind: .micro))
        XCTAssertEqual(engine.breakIndex, 1)
        XCTAssertEqual(engine.nextBreakKind(), .micro, "il ciclo torna indietro con lui")
        XCTAssertTrue(engine.undoDeclaredBreak(kind: .micro))
        XCTAssertFalse(engine.undoDeclaredBreak(kind: .micro), "sotto zero non si va")
    }

    func testStatsSeparateEmergencyExitsFromOrdinarySkips() {
        let rows = [
            entry(10, .skipped, reason: SkipReason.emergency.rawValue),
            entry(20, .skipped, reason: SkipReason.escapePhrase.rawValue),
        ]
        let s = Stats.compute(entries: rows, period: .day, now: adesso)
        XCTAssertEqual(s.emergency, 1)
        XCTAssertEqual(s.skipped, 1)
        XCTAssertTrue(s.moments.contains { $0.outcome == .emergency })
    }

    func testStatsAggregateRepsMovementAndVigorousBouts() {
        let rows = [
            entry(120, .active, seconds: 3600),
            entry(90, .completed, exercise: .squat, reps: 15),
            entry(60, .completed, exercise: .squat, reps: 15),
            entry(30, .completed, kind: .long, exercise: .burpee, reps: 8),
            entry(20, .natural),
        ]
        let s = Stats.compute(entries: rows, period: .day, now: adesso)
        XCTAssertEqual(s.totalReps, 38)
        XCTAssertEqual(s.vigorousBouts, 1)
        XCTAssertEqual(s.interruptions, 4, "tre fatte + una spontanea")
        XCTAssertEqual(s.estimatedMovementSeconds, 30 * 2.5 + 8 * 4.5, accuracy: 0.1)
    }

    /// La regola di scrittura più importante dell'app: le statistiche non dicono mai
    /// «hai ottenuto», dicono cosa è stato osservato su numeri come questi.
    func testInsightsNeverClaimAPersonalResult() {
        let rows = (0..<12).map { entry(Double($0) * 20, .completed, exercise: .squat, reps: 15) }
        let insights = Stats.insights(for: Stats.compute(entries: rows, period: .day, now: adesso))
        XCTAssertFalse(insights.isEmpty)
        for i in insights {
            let text = (i.headline + " " + i.detail).lowercased()
            for vietata in ["hai ottenuto", "hai ridotto", "hai migliorato", "ti ha ridotto", "hai guadagnato"] {
                XCTAssertFalse(text.contains(vietata), "promessa personale vietata: «\(vietata)» in \(i.id)")
            }
            XCTAssertFalse(i.headline.isEmpty)
        }
    }

    func testInsightsMarkTheThresholdAsMetOnlyWhenItIs() {
        let pochi = Stats.compute(entries: [entry(10, .completed, exercise: .squat, reps: 15)], period: .day, now: adesso)
        let molti = Stats.compute(entries: (0..<12).map { entry(Double($0) * 20, .completed, exercise: .squat, reps: 15) }, period: .day, now: adesso)
        let a = Stats.insights(for: pochi).first { $0.id == "interruzioni" }
        let b = Stats.insights(for: molti).first { $0.id == "interruzioni" }
        XCTAssertEqual(a?.met, false)
        XCTAssertEqual(b?.met, true)
    }

    func testPeriodsAreCalendarBased() {
        let cal = Calendar.current
        let now = Date()
        XCTAssertEqual(StatsPeriod.day.start(from: now), cal.startOfDay(for: now))
        XCTAssertLessThanOrEqual(StatsPeriod.week.start(from: now), cal.startOfDay(for: now))
        XCTAssertLessThanOrEqual(StatsPeriod.month.start(from: now), StatsPeriod.week.start(from: now).addingTimeInterval(7 * 86400))
    }
}

/// Le fonti devono restare raggiungibili anche dopo una modifica di massa ai testi.
///
/// Nato da un guasto vero: una sostituzione cieca «scatto → sessione intensa» ha riscritto anche
/// `about-us` dentro un URL, trasformandolo in `asessione intensa-us`. Il link era morto e
/// nessun test se ne sarebbe accorto — un'app che si regge sulle fonti non può permettersi
/// citazioni che non si aprono.
final class SourceUrlTests: XCTestCase {

    func testEveryStudyUrlIsWellFormedAndFreeOfItalianText() {
        for study in Evidence.all {
            XCTAssertTrue(study.url.hasPrefix("https://"), "\(study.id): non https")
            XCTAssertNil(URLComponents(string: study.url)?.host?.isEmpty == true ? "" : nil,
                         "\(study.id): host vuoto")
            XCTAssertFalse(study.url.contains(" "), "\(study.id): spazi nell'URL → \(study.url)")
            for parola in ["sessione", "scatto", "pausa", "intensa"] {
                XCTAssertFalse(study.url.lowercased().contains(parola),
                               "\(study.id): parola italiana finita dentro l'URL → \(study.url)")
            }
            XCTAssertNotNil(URL(string: study.url), "\(study.id): URL non costruibile")
        }
    }

    /// **Ogni fonte punta a PubMed, non a un sito qualunque.**
    ///
    /// Richiesta del principale il 2026-07-28, e non è una preferenza estetica: prima si andava su
    /// comunicati stampa di università, blog di fondazioni e riviste di settore, cioè pagine che
    /// *parlano* dello studio invece di essere lo studio. Un link a PubMed porta a un record
    /// stabile con PMID, autori e rivista, che è verificabile da chiunque e non sparisce quando
    /// il sito si rifà la grafica.
    func testEveryStudyLinksToPubMed() {
        for study in Evidence.all {
            XCTAssertTrue(study.url.hasPrefix("https://pubmed.ncbi.nlm.nih.gov/"),
                          "\(study.id): la fonte non è su PubMed → \(study.url)")
            let pmid = study.url
                .replacingOccurrences(of: "https://pubmed.ncbi.nlm.nih.gov/", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            XCTAssertFalse(pmid.isEmpty, "\(study.id): PMID mancante")
            XCTAssertTrue(pmid.allSatisfy(\.isNumber), "\(study.id): PMID non numerico → \(pmid)")
        }
    }
}

/// Il report riorganizzato: confronto, tasso di rispetto, gruppi muscolari, fasce orarie.
final class ReportTests: XCTestCase {
    /// **L'ora fissa, e perché.**
    ///
    /// `entry(minutiFa)` costruiva i timestamp rispetto a `Date()`, e `Stats.compute(period:.day)`
    /// guarda dalla mezzanotte a adesso: alle 00:06 una riga «di 120 minuti fa» finisce ieri, e
    /// mezza suite diventa rossa. Trovato nell'audit del 2026-07-28, girando i test dopo la
    /// mezzanotte — cioè per caso. Una suite che dipende dall'ora del giorno è una suite di cui
    /// non ci si fida, e la si smette di guardare proprio quando avrebbe qualcosa da dire.
    private let adesso = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)



    private func e(_ minutesAgo: Double, _ type: EntryType, kind: BreakKind = .micro,
                   exercise: ExerciseKind? = nil, reps: Int? = nil, reason: String? = nil) -> LedgerEntry {
        LedgerEntry(timestamp: adesso.addingTimeInterval(-minutesAgo * 60), type: type,
                    breakKind: kind, exercise: exercise, reps: reps, reason: reason)
    }

    /// Il numero che falsifica la cadenza: sotto la metà, è l'intervallo a essere sbagliato.
    func testComplianceRateCountsProposedBreaksOnly() {
        let rows = [
            e(10, .completed, exercise: .squat, reps: 8),
            e(20, .skipped, reason: SkipReason.escapePhrase.rawValue),
            e(30, .skipped, reason: SkipReason.emergency.rawValue),
            e(40, .natural),   // spontanea: non era una pausa proposta
        ]
        let s = Stats.compute(entries: rows, period: .day, now: adesso)
        XCTAssertEqual(s.complianceRate, 1.0 / 3.0, accuracy: 0.001)
    }

    func testMuscleGroupsCollapseTenBarsIntoFewCards() {
        let rows = [
            e(10, .completed, exercise: .squat, reps: 15),
            e(20, .completed, exercise: .lunge, reps: 12),
            e(30, .completed, exercise: .pushUp, reps: 10),
            e(40, .completed, exercise: .benchDip, reps: 12),
        ]
        let groups = Stats.compute(entries: rows, period: .day, now: adesso).repsByMuscleGroup
        XCTAssertEqual(groups.count, 3, "gambe, spinta, tricipiti")
        XCTAssertEqual(groups.first?.group, "gambe")
        XCTAssertEqual(groups.first?.reps, 27, "squat e affondi sommati")
    }

    /// La cronologia minuto per minuto non serviva; sapere in che ora la giornata si rompe sì.
    ///
    /// **Righe allo stesso istante, e l'ora presa da quell'istante.** La prima versione le metteva
    /// «uno e due minuti fa» e poi le cercava nell'ora *corrente*: nei primi due minuti di ogni ora
    /// finivano in quella precedente e il test diventava rosso da solo. Scoperto alle 20:00:21 del
    /// 2026-07-27, cioè ventun secondi dentro la finestra in cui falliva. Un test che dipende da
    /// che ore sono non misura il codice: misura l'orologio.
    /// **La stessa trappola, dall'altro lato, chiusa il 2026-07-29.** Le righe erano marcate
    /// `Date()` mentre il conto girava con `now: adesso`, che è mezzogiorno di oggi: dopo le
    /// 12:00 le righe cadevano *dopo* l'istante del calcolo e sparivano dalla finestra. Il test
    /// era verde di mattina e rosso di pomeriggio. L'istante delle righe e quello del conto
    /// devono essere lo stesso, e nessuno dei due può essere l'orologio vero.
    func testHourlyBreakdownSeparatesDoneFromMissed() {
        let istante = adesso
        let hour = Calendar.current.component(.hour, from: istante)
        let rows = [
            LedgerEntry(timestamp: istante, type: .completed, breakKind: .micro,
                        exercise: .squat, reps: 8),
            LedgerEntry(timestamp: istante, type: .skipped, breakKind: .micro,
                        reason: SkipReason.emergency.rawValue),
        ]
        let byHour = Stats.compute(entries: rows, period: .day, now: adesso).byHour
        let slot = byHour.first { $0.hour == hour }
        XCTAssertEqual(slot?.done, 1)
        XCTAssertEqual(slot?.missed, 1)
    }

    func testPreviousPeriodIsTheOneBeforeNotTheSame() {
        let rows = [
            e(10, .completed, exercise: .squat, reps: 8),                    // oggi
            e(60 * 30, .completed, exercise: .squat, reps: 99),              // ~30 ore fa: ieri
        ]
        let today = Stats.compute(entries: rows, period: .day, now: adesso)
        let yesterday = Stats.previous(entries: rows, period: .day, now: adesso)
        XCTAssertEqual(today.totalReps, 8)
        XCTAssertEqual(yesterday.totalReps, 99, "il confronto guarda il periodo prima, non questo")
    }

    /// I complimenti girano: uno sempre uguale smette di essere un complimento.
    func testPraiseRotatesAndNeverRepeatsTwiceInARow() {
        // Il giro dura quanto l'elenco: legato alla lista, non a un 8 scritto a mano che diventa
        // falso appena si aggiunge un complimento.
        let lines = (0..<Praise.afterBreak.count).map { Praise.line(at: $0) }
        XCTAssertEqual(Set(lines).count, Praise.afterBreak.count)
        for (a, b) in zip(lines, lines.dropFirst()) { XCTAssertNotEqual(a, b) }
        XCTAssertNotEqual(Praise.line(at: 3, hard: true), Praise.line(at: 3, hard: false),
                          "la pausa dura ha parole sue")
        XCTAssertNoThrow(Praise.line(at: -5))
    }
}

/// I due modi di dichiarare il tempo già seduto — e il fatto che sono due numeri diversi.
final class SeatedTimeTests: XCTestCase {
    /// **L'ora fissa, e perché.**
    ///
    /// `entry(minutiFa)` costruiva i timestamp rispetto a `Date()`, e `Stats.compute(period:.day)`
    /// guarda dalla mezzanotte a adesso: alle 00:06 una riga «di 120 minuti fa» finisce ieri, e
    /// mezza suite diventa rossa. Trovato nell'audit del 2026-07-28, girando i test dopo la
    /// mezzanotte — cioè per caso. Una suite che dipende dall'ora del giorno è una suite di cui
    /// non ci si fida, e la si smette di guardare proprio quando avrebbe qualcosa da dire.
    private let adesso = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)



    private func engineWith(_ seconds: Double) -> SessionEngine {
        var s = Settings(); s.startDate = Date()
        var e = SessionEngine(settings: s, maxCredibleElapsed: 120)
        e.declareTimeAlreadySeated(seconds, mode: .total)
        return e
    }

    /// «In tutto sono 100 minuti»: il conto diventa esattamente quello, anche se prima era di più.
    /// La prima versione prendeva il massimo, quindi un errore all'insù non si poteva correggere.
    func testTotalModeSetsTheCounterExactlyEvenDownwards() {
        var engine = engineWith(180 * 60)
        XCTAssertEqual(engine.declareTimeAlreadySeated(100 * 60, mode: .total), 6000, accuracy: 1)
        XCTAssertEqual(engine.clock.activeSeconds, 6000, accuracy: 1, "si può correggere all'ingiù")
    }

    func testAddModeSumsInsteadOfReplacing() {
        var engine = engineWith(20 * 60)
        XCTAssertEqual(engine.declareTimeAlreadySeated(30 * 60, mode: .add), 3000, accuracy: 1)
    }

    func testDeclaringZeroTotalResetsTheCounter() {
        var engine = engineWith(45 * 60)
        XCTAssertEqual(engine.declareTimeAlreadySeated(0, mode: .total), 0, accuracy: 0.001)
    }

    /// Il totale del giorno è una **somma di righe**: correggerlo all'ingiù significa scriverne
    /// una negativa, non riscrivere il registro.
    /// Le righe portano `adesso`, non `Date()`: vedi la nota su `testHourlyBreakdownSeparates…`.
    /// Con l'orologio vero il test cadeva ogni pomeriggio, perché le righe finivano dopo
    /// l'istante del conto.
    func testTheDailyTotalIsCorrectedWithASignedRow() {
        let now = adesso
        let rows = [
            LedgerEntry(timestamp: now, type: .active, seconds: 10800),           // 3 ore
            LedgerEntry(timestamp: now, type: .active, seconds: -3600, reason: "correzione"),
        ]
        let s = Stats.compute(entries: rows, period: .day, now: adesso)
        XCTAssertEqual(s.activeSeconds, 7200, accuracy: 1, "tre ore meno una: due")
    }
}

// MARK: - ISC-120 — la rotazione regge anche sul pool del principale

/// **Il pool di serie ne tiene uno, ma tu puoi accenderli tutti e due — e infatti lui l'ha
/// fatto.** Il 2026-07-31 avevo tolto il superman dalla rotazione di serie perché due «dorso»
/// finivano di fila; mezz'ora dopo il principale li ha accesi entrambi dalle preferenze, che è
/// esattamente il suo diritto. Quindi la garanzia non può dipendere da quale pool ho scelto io.
final class RealPoolSpreadTests: XCTestCase {

    /// Il pool vero letto dalle sue impostazioni il 2026-07-31: diciotto esercizi, **due
    /// posturali accesi insieme**.
    private let suo: [ExerciseKind] = [
        .squat, .pushUp, .calfRaise, .gluteBridge, .diamondPushUp, .archerPushUp,
        .pikePushUp, .benchDip, .crunch, .legRaise, .plank, .splitSquat,
        .russianTwist, .sidePlank, .hollowHold, .sitUp, .superman, .ytw,
    ]

    func testHisOwnPoolNeverRepeatsAMuscleGroupBackToBack() {
        var s = Settings(); s.exercisePool = suo
        let planner = s.planner
        let kinds = (1...60).map { planner.exercise(breakIndex: $0, kind: .micro, factor: 1.0).kind }
        for (a, b) in zip(kinds, kinds.dropFirst()) {
            XCTAssertNotEqual(a.muscleGroup, b.muscleGroup,
                              "\(a.italianName) → \(b.italianName): stesso gruppo di fila")
        }
        XCTAssertTrue(kinds.contains(.ytw) && kinds.contains(.superman),
                      "e in sessanta turni escono entrambi, o accenderli non sarebbe servito")
    }

    /// La stessa proprietà, ma senza fidarsi di **un** pool: due esercizi di ogni famiglia accesi
    /// insieme, che è il caso peggiore che l'interfaccia permette di costruire.
    func testAnyPoolWithTwoPerGroupStillSpreads() {
        var s = Settings()
        s.exercisePool = [.squat, .lunge, .pushUp, .diamondPushUp, .crunch, .sitUp, .superman, .ytw]
        let kinds = (1...40).map { s.planner.exercise(breakIndex: $0, kind: .micro, factor: 1.0).kind }
        for (a, b) in zip(kinds, kinds.dropFirst()) {
            XCTAssertNotEqual(a.muscleGroup, b.muscleGroup,
                              "\(a.italianName) → \(b.italianName)")
        }
    }
}

// MARK: - ISC-121 — la distanza fra gruppi è una proprietà, non un caso fortunato

/// **Il pool lo componi tu, quindi la garanzia non può valere solo per il pool che ho scelto io.**
/// Le preferenze permettono qualunque combinazione di caselle: qui si prova che la rotazione
/// regge su tutte quelle che l'aritmetica consente.
final class SpreadPropertyTests: XCTestCase {

    private func adiacenzeCicliche(_ ordered: [ExerciseKind]) -> Int {
        guard ordered.count > 1 else { return 0 }
        var coppie = zip(ordered, ordered.dropFirst()).filter { $0.muscleGroup == $1.muscleGroup }.count
        if ordered.count > 2, ordered.first?.muscleGroup == ordered.last?.muscleGroup { coppie += 1 }
        return coppie
    }

    /// Il limite è aritmetico e va detto: se un gruppo supera la metà del pool arrotondata per
    /// eccesso, le adiacenze **non si possono** togliere. Sotto quella soglia, devono essere zero.
    func testZeroAdjacenciesWheneverArithmeticAllowsIt() {
        var rng = SystemRandomNumberGenerator()
        let tutti = ExerciseKind.allCases.filter { !$0.isVigorous }
        for giro in 1...300 {
            let quanti = Int.random(in: 3...tutti.count, using: &rng)
            let pool = Array(tutti.shuffled(using: &rng).prefix(quanti))
            let ordered = ExercisePlanner.spreadByMuscleGroup(pool)

            XCTAssertEqual(Set(ordered), Set(pool), "giro \(giro): il riordino non perde né inventa")
            XCTAssertEqual(ordered.count, pool.count, "giro \(giro): nessun duplicato")

            var conteggio: [String: Int] = [:]
            for k in pool { conteggio[k.muscleGroup, default: 0] += 1 }
            let dominante = conteggio.values.max() ?? 0
            // **La soglia di un cerchio è più stretta di quella di una fila.** In fila bastano
            // `ceil(n/2)`; in cerchio l'ultimo confina col primo, e il limite scende a `n/2`.
            // La prima versione di questo test usava la formula lineare e bocciava
            // `[sit-up, squat, plank]` — dove due addome su tre in cerchio si toccano per
            // forza, qualunque ordine si scelga. Errore del test, non del codice.
            if dominante <= pool.count / 2 {
                XCTAssertEqual(adiacenzeCicliche(ordered), 0,
                               "giro \(giro): \(pool.map(\.italianName)) → \(ordered.map(\.muscleGroup))")
            }
        }
    }

    /// **Il polo che rende il test una prova.** Con l'algoritmo di prima — il primo disponibile
    /// invece del più numeroso — su un pool sbilanciato le adiacenze ci sono. Se qui fossero zero,
    /// il verde qui sopra non direbbe niente.
    func testTheOldGreedyWouldHaveFailedOnAnUnbalancedPool() {
        // Sbilanciato **ma risolvibile**: sei addome su tredici, cioè sotto la metà. È il caso del
        // pool vero del principale, dove il vecchio algoritmo impilava e il nuovo distanzia. Con
        // sette addome su dieci — la prima versione di questo test — le adiacenze sono aritmetica
        // e nessun algoritmo può toglierle: pretenderlo era un errore mio, non un difetto.
        // **Il pool vero del principale**, quello su cui il difetto è uscito: sette addome su
        // diciotto, cioè sotto la metà e quindi risolvibile. È il caso che ha aperto la caccia.
        let sbilanciato: [ExerciseKind] = [
            .squat, .pushUp, .calfRaise, .gluteBridge, .diamondPushUp, .archerPushUp,
            .pikePushUp, .benchDip, .crunch, .legRaise, .plank, .splitSquat,
            .russianTwist, .sidePlank, .hollowHold, .sitUp, .superman, .ytw,
        ]
        // Il vecchio algoritmo, riprodotto qui per il confronto.
        var remaining = sbilanciato
        var vecchio: [ExerciseKind] = []
        var precedente: String?
        while !remaining.isEmpty {
            let i = remaining.firstIndex { $0.muscleGroup != precedente } ?? 0
            let scelto = remaining.remove(at: i)
            vecchio.append(scelto)
            precedente = scelto.muscleGroup
        }
        XCTAssertGreaterThan(adiacenzeCicliche(vecchio), 0, "il vecchio impilava il gruppo dominante in coda")
        XCTAssertEqual(adiacenzeCicliche(ExercisePlanner.spreadByMuscleGroup(sbilanciato)), 0,
                       "il nuovo no")
    }
}
