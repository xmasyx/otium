import XCTest
@testable import OtiumCore

/// L'app davanti a impostazioni assurde.
///
/// Audit del 2026-07-29. `settings.json` è un file di testo nella cartella dell'utente: si apre,
/// si modifica e si sbaglia. Non è una superficie ostile nel senso della sicurezza — chi lo tocca
/// è già padrone della macchina — ma è una superficie **reale**, e il modo in cui un'app reagisce
/// a un valore impossibile è la differenza fra «si comporta strano» e «gira a vuoto per sempre».
final class HostileSettingsTests: XCTestCase {

    /// Nessun valore fa girare a vuoto il motore o produce numeri che non sono numeri.
    func testAbsurdSettingsNeverProduceNaNOrHang() {
        let assurde: [(String, (inout Settings) -> Void)] = [
            ("intervallo a zero", { $0.cadence.intervalSeconds = 0 }),
            ("intervallo negativo", { $0.cadence.intervalSeconds = -600 }),
            ("micro-pausa a zero", { $0.cadence.microDurationSeconds = 0 }),
            ("pausa piena negativa", { $0.cadence.longDurationSeconds = -1 }),
            ("preavviso enorme", { $0.cadence.warningSeconds = 1_000_000 }),
            ("soglia di inattività a zero", { $0.cadence.idleThresholdSeconds = 0 }),
            ("una pausa piena ogni zero", { $0.cadence.longEveryNBreaks = 0 }),
            ("partenza graduale a zero settimane", { $0.rampWeeks = 0 }),
            ("partenza dal 1000%", { $0.rampStartFactor = 10 }),
            ("partenza da meno infinito", { $0.rampStartFactor = -5 }),
            ("nessun esercizio", { $0.exercisePool = [] }),
            ("nessun esercizio vigoroso", { $0.vigorousPool = [] }),
            ("ore attive invertite", { $0.activeFromHour = 23; $0.activeToHour = 7 }),
            ("ore attive impossibili", { $0.activeFromHour = 99; $0.activeToHour = -4 }),
            ("frase di fuga vuota", { $0.escapePhrase = "" }),
            ("grazia negativa", { $0.resumeGraceSeconds = -100 }),
        ]

        for (nome, rovina) in assurde {
            var s = Settings()
            rovina(&s)
            var engine = SessionEngine(settings: s, maxCredibleElapsed: 60)
            var now = Date(timeIntervalSince1970: 1_700_000_000)

            for _ in 0..<200 {
                now = now.addingTimeInterval(5)
                engine.tick(elapsed: 5, idle: 1, now: now)
                engine.markExerciseDone()
                engine.returnToWork()
            }

            XCTAssertFalse(engine.timer.isNaN, "\(nome): cronometro NaN")
            XCTAssertFalse(engine.clock.activeSeconds.isNaN, "\(nome): tempo attivo NaN")
            XCTAssertFalse(engine.secondsUntilNextBreak.isNaN, "\(nome): conto alla rovescia NaN")
            XCTAssertFalse(engine.secondsUntilNextBreak.isInfinite, "\(nome): conto infinito")
            XCTAssertFalse(s.rampFactor(now: now).isNaN, "\(nome): fattore NaN")
            XCTAssertGreaterThan(s.rampFactor(now: now), 0, "\(nome): fattore non positivo")
            if let plan = engine.plan {
                XCTAssertGreaterThanOrEqual(plan.exercise.reps, 1, "\(nome): esercizio da zero ripetizioni")
                XCTAssertFalse(plan.duration.isNaN, "\(nome): durata NaN")
            }
        }
    }

    /// **Un pool vuoto non lascia l'app senza esercizi.** Il costruttore ricade su un esercizio
    /// di serie: preferire un default a un crash è la scelta giusta, ma dev'essere una scelta.
    func testAnEmptyPoolFallsBackInsteadOfEmptying() {
        var s = Settings()
        s.exercisePool = []
        s.vigorousPool = []
        XCTAssertFalse(s.exercisePool.isEmpty)
        XCTAssertFalse(s.vigorousPool.isEmpty)

        var engine = SessionEngine(settings: s)
        engine.forceBreakNow(now: Date())
        XCTAssertNotNil(engine.plan, "con il pool vuoto la pausa deve comunque avere un esercizio")
    }

    /// Il tetto della progressione non divide mai per zero, nemmeno con una pausa di durata nulla.
    func testTheCeilingSurvivesAZeroLengthBreak() {
        for kind in ExerciseKind.allCases {
            let tetto = Progression.ceiling(for: kind, breakSeconds: 0)
            XCTAssertGreaterThanOrEqual(tetto, 1, "\(kind.rawValue): tetto a zero")
            XCTAssertLessThan(tetto, 100_000, "\(kind.rawValue): tetto esploso")
        }
    }

    /// **Il fattore della partenza graduale resta dentro i suoi estremi**, qualunque cosa dica il
    /// file: sopra il 100% le ripetizioni sarebbero più di quelle promesse, sotto zero sarebbero
    /// negative, e in mezzo non c'è niente da difendere.
    func testTheRampFactorStaysBetweenItsBounds() {
        for start in [-10.0, -0.1, 0.0, 0.3, 1.0, 5.0] {
            var s = Settings()
            s.rampStartFactor = start
            s.startDate = Date().addingTimeInterval(-30 * 24 * 3600)
            let f = s.rampFactor(now: Date())
            XCTAssertGreaterThan(f, 0, "fattore non positivo partendo da \(start)")
            XCTAssertLessThanOrEqual(f, 1.0, "fattore sopra il 100% partendo da \(start)")
        }
    }
}
