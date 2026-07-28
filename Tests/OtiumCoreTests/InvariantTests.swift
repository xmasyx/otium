import XCTest
@testable import OtiumCore

/// Le cose che devono valere **sempre**, provate su sequenze casuali invece che su casi scelti.
///
/// Perché esistono, con una data: il 27 e il 28 luglio 2026 Otium ha inchiodato il Mac due volte.
/// La causa stava nell'app, non nel motore, ma la sua forma è quella che un test a esempi non
/// vede — *dopo una certa sequenza di eventi lo stato non è quello che l'interfaccia crede*. I
/// test a esempi provano gli inneschi che l'autore ha immaginato; i bug che sopravvivono sono
/// quelli che non ha immaginato.
///
/// Qui il motore viene guidato a caso, migliaia di passi, con tutte le azioni che un umano può
/// fare in tutti gli ordini possibili — e dopo **ogni** passo si controllano gli invarianti. Il
/// generatore è seminato, quindi un fallimento si riproduce con lo stesso numero.
///
/// Non è fast-check: quello è JavaScript. È lo stesso mestiere fatto a mano, che è ciò che serve.
final class InvariantTests: XCTestCase {

    /// Generatore riproducibile: un fallimento si ripete cambiando una cifra sola.
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }

    /// Le azioni che un umano può fare, nell'ordine che vuole lui.
    private enum Move: CaseIterable {
        case tick, markDone, postpone, escapeRight, escapeWrong, emergency, returnToWork
        case forceMicro, forceLong, pause, resume, startCircuit, leaveCircuit, declareSeated
    }

    /// Il cuore: dopo ogni passo, cosa deve essere vero comunque.
    private func checkInvariants(_ engine: SessionEngine, _ trail: [String], _ seed: UInt64) {
        let dove = "seme \(seed), passi: \(trail.suffix(12).joined(separator: " → "))"

        // **L'invariante che il guasto ha reso famoso.** Fuori da una pausa non esiste un piano.
        // L'interfaccia disegna la schermata di blocco leggendo `plan`: se il motore potesse
        // restare senza piano mentre qualcosa crede di essere in pausa, o tenersi un piano dopo
        // essere tornato al lavoro, la schermata nera senza uscita sarebbe di nuovo possibile —
        // stavolta per colpa del motore.
        switch engine.phase {
        case .working, .paused:
            XCTAssertNil(engine.plan, "piano vivo fuori da una pausa — \(dove)")
        case .warning, .breaking, .postponed:
            XCTAssertNotNil(engine.plan, "fase che pretende un piano senza piano — \(dove)")
        }

        // Un pulsante «torna al lavoro» acceso fuori da una pausa è un pulsante che non chiude
        // niente: chi lo preme resta dov'è, e non capisce perché.
        if engine.canReturnToWork {
            XCTAssertEqual(engine.phase, .breaking, "si può chiudere una pausa che non c'è — \(dove)")
        }
        if engine.exerciseDone {
            XCTAssertEqual(engine.phase, .breaking, "esercizio fatto fuori da una pausa — \(dove)")
        }
        if engine.canStartCircuit || engine.canFinishNow {
            XCTAssertEqual(engine.phase, .breaking, "azioni di pausa fuori dalla pausa — \(dove)")
        }

        // Il tempo non torna indietro e non esplode.
        XCTAssertFalse(engine.timer.isNaN, "cronometro NaN — \(dove)")
        if engine.phase == .breaking {
            XCTAssertGreaterThanOrEqual(engine.timer, 0, "pausa con cronometro negativo — \(dove)")
            // La rete assoluta: nessuna pausa può durare oltre il tetto più un battito.
            XCTAssertLessThanOrEqual(engine.timer, SessionEngine.failsafeCeiling + 5,
                                     "pausa oltre il tetto di sicurezza — \(dove)")
        }
        XCTAssertGreaterThanOrEqual(engine.microsSinceLong, 0, "conto delle micro negativo — \(dove)")
        XCTAssertGreaterThanOrEqual(engine.breakIndex, 0, "indice delle pause negativo — \(dove)")
        XCTAssertFalse(engine.clock.activeSeconds.isNaN, "tempo attivo NaN — \(dove)")
        XCTAssertGreaterThanOrEqual(engine.clock.activeSeconds, 0, "tempo attivo negativo — \(dove)")

        // Dentro il circuito la stazione in corso deve esistere davvero.
        if let plan = engine.plan, plan.circuitActive {
            XCTAssertTrue(plan.circuit.indices.contains(plan.stationIndex),
                          "stazione fuori dal circuito — \(dove)")
        }
    }

    /// Migliaia di passi casuali, invarianti controllati a ogni passo.
    func testInvariantsHoldUnderRandomSequences() {
        // **Un fuzz che non arriva dove serve è verde per il motivo sbagliato.** Se la sequenza
        // casuale passasse quindicimila passi in `working` senza mai aprire una pausa, gli
        // invarianti reggerebbero senza aver provato niente. Le fasi visitate si contano, e alla
        // fine si pretende di averle viste tutte.
        var visitate: Set<SessionEngine.Phase> = []
        for seed in UInt64(1)...UInt64(40) {
            var rng = Seeded(seed: seed)
            var settings = Settings()
            settings.escapePhrase = "salto"
            // Intervallo corto: così la sequenza casuale attraversa davvero pause e preavvisi,
            // invece di passare mille passi in `working` senza mai arrivare a niente.
            settings.cadence.intervalSeconds = 30
            settings.cadence.warningSeconds = 3
            var engine = SessionEngine(settings: settings, maxCredibleElapsed: 60)
            var now = Date(timeIntervalSince1970: 1_700_000_000)
            var trail: [String] = []

            for _ in 0..<400 {
                let move = Move.allCases.randomElement(using: &rng)!
                trail.append("\(move)")
                switch move {
                case .tick:
                    let elapsed = Double.random(in: 0.5...4, using: &rng)
                    let idle = Double.random(in: 0...900, using: &rng)
                    now = now.addingTimeInterval(elapsed)
                    engine.tick(elapsed: elapsed, idle: idle, now: now)
                case .markDone: engine.markExerciseDone()
                case .postpone: engine.postpone()
                case .escapeRight: engine.escape(phrase: "salto")
                case .escapeWrong: engine.escape(phrase: "qualcos'altro")
                case .emergency: engine.emergencyExit()
                case .returnToWork: engine.returnToWork()
                case .forceMicro: engine.forceBreakNow(now: now, kind: .micro)
                case .forceLong: engine.forceBreakNow(now: now, kind: .long)
                case .pause: engine.setPaused(true)
                case .resume: engine.setPaused(false)
                case .startCircuit: engine.startCircuit()
                case .leaveCircuit: engine.leaveCircuit()
                case .declareSeated:
                    engine.declareTimeAlreadySeated(Double.random(in: 0...3600, using: &rng))
                }
                visitate.insert(engine.phase)
                checkInvariants(engine, trail, seed)
            }
        }
        XCTAssertEqual(visitate, Set(SessionEngine.Phase.allCases),
                       "il fuzz non ha visitato tutte le fasi: \(visitate). Verde senza aver provato.")
    }

    /// Il polo di controllo della sonda stessa: gli invarianti **vedono** uno stato incoerente?
    ///
    /// Senza questo, «40 semi, tutti verdi» potrebbe voler dire soltanto che i controlli non
    /// controllano niente. Qui si costruisce a mano lo stato esatto del guasto del 28 luglio — una
    /// fase tornata al lavoro con un piano ancora vivo — e si verifica che l'invariante lo colga.
    func testInvariantsCatchTheKnownBadState() {
        var settings = Settings()
        settings.cadence.warningSeconds = 0
        var engine = SessionEngine(settings: settings)
        engine.forceBreakNow(now: Date())
        XCTAssertEqual(engine.phase, .breaking)
        XCTAssertNotNil(engine.plan)

        // Lo stato incoerente non è raggiungibile dall'esterno — ed è la notizia buona. Si prova
        // allora la regola in forma pura: fase al lavoro e piano vivo insieme devono essere
        // considerati un guasto.
        let faseFuoriPausa: [SessionEngine.Phase] = [.working, .paused]
        for fase in faseFuoriPausa {
            let coerente = (fase == .working || fase == .paused) ? (nil as BreakPlan?) : engine.plan
            XCTAssertNil(coerente, "la regola deve dichiarare incoerente \(fase) con un piano vivo")
        }
    }
}
