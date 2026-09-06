import XCTest
@testable import OtiumCore

/// **Modalità Agentic: la pausa non copre lo schermo** (chiesta il 2026-09-06 guardando gli agenti
/// che lavoravano nel browser mentre lo scudo li fermava).
///
/// Qui c'è solo la parte che un test può stringere: che la preferenza esista, sopravviva al disco,
/// finisca nel piano e nel registro, e che **non cambi la pausa**. Il pannello, il fuoco che resta
/// all'app davanti e lo spostamento si provano con la fotografia e con `--agentic-demo`.
final class AgenticModeTests: XCTestCase {

    // MARK: la preferenza

    /// Spenta di serie: lo scudo è la ragione per cui l'app esiste, e il pannello è il ripiego.
    func testAgenticModeIsOffByDefault() {
        XCTAssertFalse(Settings().agenticMode)
    }

    /// Un file scritto prima di questa versione non ha la chiave, e deve leggersi spento.
    func testAFileWithoutTheKeyDecodesAsOff() throws {
        var s = Settings()
        s.zenMode = true
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as! [String: Any]
        json.removeValue(forKey: "agenticMode")
        let riletto = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(riletto.agenticMode)
        XCTAssertTrue(riletto.zenMode, "le altre chiavi non si perdono")
    }

    func testAgenticModeSurvivesTheDisk() throws {
        var s = Settings()
        s.agenticMode = true
        let riletto = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        XCTAssertTrue(riletto.agenticMode)
    }

    // MARK: il piano

    private func engine(agentic: Bool, zen: Bool = false) -> SessionEngine {
        var s = Settings()
        s.agenticMode = agentic
        s.zenMode = zen
        return SessionEngine(settings: s, maxCredibleElapsed: 10_000)
    }

    /// Il piano fotografa la preferenza al momento in cui nasce, come fa con `breath`.
    func testThePlanCarriesTheModeItWasBornWith() {
        var acceso = engine(agentic: true)
        acceso.forceBreakNow(now: Date(), kind: .micro)
        XCTAssertTrue(acceso.plan?.agentic ?? false)

        var spento = engine(agentic: false)
        spento.forceBreakNow(now: Date(), kind: .micro)
        XCTAssertFalse(spento.plan?.agentic ?? true)
    }

    /// Cambiare preferenza a pausa aperta non riscrive la pausa in corso.
    func testTogglingMidBreakDoesNotRewriteTheRunningPlan() {
        var e = engine(agentic: false)
        e.forceBreakNow(now: Date(), kind: .micro)
        e.settings.agenticMode = true
        e.tick(elapsed: 1, idle: 0, now: Date())
        XCTAssertFalse(e.plan?.agentic ?? true)
    }

    /// **Agentic vince su Zen**: lui ha chiesto «solamente esercizi da fare», e un respiro guidato in
    /// un pannello da 360 punti non è né l'una né l'altra cosa. Il piano è a esercizio, senza respiro.
    func testAgenticOverridesZenAndAsksForAnExercise() {
        var e = engine(agentic: true, zen: true)
        e.forceBreakNow(now: Date(), kind: .long)
        guard let plan = e.plan else { return XCTFail("nessuna pausa") }
        XCTAssertTrue(plan.agentic)
        XCTAssertNil(plan.breath)
        XCTAssertFalse(plan.isZen)
        XCTAssertEqual(plan.demandLabel, plan.exercise.label)
    }

    /// Il polo opposto: con Agentic spento Zen resta Zen. Senza questa riga il test sopra passerebbe
    /// anche buttando via il respiro per tutti.
    func testWithAgenticOffZenStillBreathes() {
        var e = engine(agentic: false, zen: true)
        e.forceBreakNow(now: Date(), kind: .long)
        XCTAssertNotNil(e.plan?.breath)
    }

    // MARK: la pausa resta una pausa (Anti-claim)

    /// Il pannello cambia **dove** si vede la pausa, non **cosa** chiede: esercizio confermato E
    /// tempo scaduto, come sotto lo scudo. Un pannello che si chiude prima è un rinvio travestito.
    func testAnAgenticBreakStillNeedsExerciseAndTimeToEnd() {
        var e = engine(agentic: true)
        e.forceBreakNow(now: Date(), kind: .micro)
        guard let plan = e.plan else { return XCTFail("nessuna pausa") }
        XCTAssertFalse(e.canReturnToWork)
        var passati = 0.0
        while passati < plan.exercise.minimumSeconds + 1 {
            e.tick(elapsed: 1, idle: 0, now: Date()); passati += 1
        }
        XCTAssertFalse(e.canReturnToWork, "tempo non scaduto: non si torna al lavoro")
        e.markExerciseDone()
        XCTAssertFalse(e.canReturnToWork, "esercizio fatto ma tempo non scaduto")
        while passati < plan.duration + 1 {
            e.tick(elapsed: 1, idle: 0, now: Date()); passati += 1
        }
        XCTAssertTrue(e.canReturnToWork)
    }

    // MARK: il registro

    /// La riga della pausa completata dice che era Agentic, così le statistiche possono contarle. La
    /// forma è quella dei motivi già scritti (`circuito+richiesta`): un gettone `agentic` in mezzo
    /// agli altri, unito con `+`, mai al posto loro. Qui la pausa è forzata, quindi «richiesta» c'è.
    func testTheLedgerMarksAnAgenticBreak() {
        var e = engine(agentic: true)
        e.forceBreakNow(now: Date(), kind: .micro)
        guard let plan = e.plan else { return XCTFail("nessuna pausa") }
        let riga = Ledger.entry(for: .breakCompleted(plan), now: Date())
        XCTAssertEqual(riga?.type, .completed)
        XCTAssertEqual(riga?.exercise, plan.exercise.kind, "l'esercizio resta: è una pausa con esercizio")
        let gettoni = riga?.reason?.split(separator: "+").map(String.init) ?? []
        XCTAssertTrue(gettoni.contains("agentic"), "motivo: \(riga?.reason ?? "nil")")
        XCTAssertTrue(gettoni.contains("richiesta"), "il gettone nuovo non scaccia quelli vecchi")
    }

    /// Una pausa normale non porta il marchio: il registro non cambia per chi non usa la modalità.
    func testANormalBreakIsNotMarked() {
        var e = engine(agentic: false)
        e.forceBreakNow(now: Date(), kind: .micro)
        guard let plan = e.plan else { return XCTFail("nessuna pausa") }
        let gettoni = Ledger.entry(for: .breakCompleted(plan), now: Date())?.reason?.split(separator: "+") ?? []
        XCTAssertFalse(gettoni.contains("agentic"))
    }
}
