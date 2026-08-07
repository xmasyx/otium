import XCTest
@testable import OtiumCore

/// Il caso che ha fatto nascere l'iterazione 22: **una call è tempo seduto**, e fino al
/// 2026-08-04 l'app la leggeva come assenza. Chi passava due ore in riunione senza toccare il
/// trackpad usciva con zero minuti contati — e nel frattempo il rinvio per microfono aveva un
/// tetto, quindi dopo mezz'ora lo schermo si copriva **in piena call**.
///
/// Qui si prova che entrambe le cose sono morte, e che il rimedio non ha rotto il caso opposto:
/// la stessa immobilità **senza** call continua a valere come assenza.
final class CallPresenceTests: XCTestCase {

    static let workingHour: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 28; c.hour = 10
        return Calendar.current.date(from: c)!
    }()

    private let inCall = PresenceSignal(kind: .call, detail: "microfono in uso")

    private func makeEngine(_ settings: Settings? = nil) -> SessionEngine {
        var s = settings ?? Settings()
        s.startDate = Self.workingHour
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Guida il motore per N secondi **senza un solo input**, con il microfono acceso e il
    /// segnale di call in piedi: è la riunione a cui si assiste ascoltando.
    @discardableResult
    private func stayOnTheCall(
        _ engine: inout SessionEngine,
        seconds: Double,
        step: Double = 30,
        presence: PresenceSignal? = nil,
        microphone: Bool = true
    ) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var idle = 0.0
        let segnale = presence ?? inCall
        while idle < seconds {
            idle += step
            events += engine.tick(
                elapsed: step, idle: idle, now: Self.workingHour,
                environment: EngineEnvironment(microphoneActive: microphone, presence: segnale)
            )
        }
        return events
    }

    // MARK: - ISC-156 · il tempo in call si conta, e non ha tetto

    func testTwoHoursOfCallCountAsTwoHoursOfSittingTime() {
        var engine = makeEngine()
        stayOnTheCall(&engine, seconds: 2 * 3600)

        // Il minuto di preavviso è l'unico pezzo in cui l'orologio non cammina: si tollera.
        XCTAssertGreaterThan(engine.clock.activeSeconds, 2 * 3600 - 120,
                             "due ore di call devono contare come due ore sedute")
    }

    /// Il polo negativo, ed è quello che rende il criterio falsificabile: la **stessa**
    /// immobilità senza call resta assenza, e il contatore non cresce.
    func testTheSameStillnessWithoutACallStaysAbsence() {
        var engine = makeEngine()
        var idle = 0.0
        while idle < 2 * 3600 {
            idle += 30
            engine.tick(elapsed: 30, idle: idle, now: Self.workingHour, environment: .quiet)
        }
        XCTAssertLessThan(engine.clock.activeSeconds, 60,
                          "senza segnale, fermo significa assente — comportamento invariato")
    }

    /// ISC-156, il tetto: `.call` è l'unico segnale che non scade.
    func testTheCallSignalHasNoCap() {
        let engine = makeEngine()
        XCTAssertTrue(engine.presenceHolds(inCall, idle: 10 * 3600),
                      "dieci ore di call reggono ancora")
        XCTAssertFalse(PresenceCap.call.isFinite)
        XCTAssertTrue(PresenceCap.media.isFinite, "video e lettura il tetto ce l'hanno ancora")
        XCTAssertTrue(PresenceCap.reading.isFinite)
    }

    /// `Int(Double.infinity)` fa terminare il processo: il tetto a schermo si scrive a parole.
    func testTheInfiniteCapIsPrintableWithoutCrashing() {
        XCTAssertTrue(PresenceCap.label(for: .media).contains("45′"))
        XCTAssertTrue(PresenceCap.label(for: .reading).contains("15′"))
        XCTAssertFalse(PresenceCap.label(for: .call).contains("′"))
    }

    // MARK: - ISC-157 · rinviata non vuol dire ferma

    func testTheClockKeepsRunningWhileTheBreakIsPostponed() {
        var engine = makeEngine()
        stayOnTheCall(&engine, seconds: 31 * 60)
        XCTAssertEqual(engine.phase, .postponed, "in call la pausa si rimanda")

        let prima = engine.clock.activeSeconds
        stayOnTheCall(&engine, seconds: 10 * 60)
        let dopo = engine.clock.activeSeconds

        XCTAssertGreaterThan(dopo - prima, 9 * 60,
                             "dieci minuti di rinvio sono dieci minuti seduti")
    }

    // MARK: - ISC-159 · la call ha la precedenza

    func testACallOutranksReadingAndMedia() {
        // Riunione su Meet: il browser è in primo piano e suona. Senza precedenza sarebbe
        // «video» (tetto 45′) o «pagina web» (tetto 15′), e a riunione ancora aperta il
        // contatore si fermerebbe.
        let segnale = PresenceClassifier.classify(
            frontmost: "com.google.Chrome",
            isPlayingAudio: true,
            document: nil,
            appName: "Google Chrome",
            microphoneActive: true
        )
        XCTAssertEqual(segnale?.kind, .call)

        // Anche con un PDF davanti, che è il ramo che vinceva su tutto.
        let conPdf = PresenceClassifier.classify(
            frontmost: "com.apple.Preview",
            isPlayingAudio: false,
            document: "relazione.pdf",
            appName: "Anteprima",
            microphoneActive: true
        )
        XCTAssertEqual(conPdf?.kind, .call)

        // Polo negativo: spenti microfono e telecamera, la classificazione è quella di prima.
        let senzaCall = PresenceClassifier.classify(
            frontmost: "com.apple.Preview",
            isPlayingAudio: false,
            document: "relazione.pdf",
            appName: "Anteprima"
        )
        XCTAssertEqual(senzaCall?.kind, .reading)
    }

    func testTheCameraWinsOverTheMicrophone() {
        let video = PresenceClassifier.call(microphoneActive: true, cameraActive: true)
        XCTAssertEqual(video?.kind, .call)
        XCTAssertTrue(video!.detail.contains("video") || video!.detail.contains("chiamata"),
                      "la telecamera è il segnale forte e deve dirlo: \(video!.detail)")
        XCTAssertNil(PresenceClassifier.call(microphoneActive: false, cameraActive: false))
    }

    // MARK: - ISC-160 / ISC-161 · la pausa arretrata arriva lunga, e lo dice prima

    func testABreakOverdueByAFullCycleComesBackLong() {
        var engine = makeEngine()
        // Due ore di riunione: la pausa è rimandata per tutto il tempo, e l'orologio cammina.
        stayOnTheCall(&engine, seconds: 2 * 3600)
        XCTAssertEqual(engine.phase, .postponed)
        XCTAssertTrue(engine.isOverdue)

        // La call finisce.
        let events = engine.tick(elapsed: 30, idle: 0, now: Self.workingHour, environment: .quiet)
        let annuncio = events.compactMap { evento -> BreakPlan? in
            if case .deferredBreakDue(let piano) = evento { return piano }
            return nil
        }.first

        XCTAssertNotNil(annuncio, "il rientro dalla call deve annunciarsi")
        // ISC-161: il preavviso annuncia la pausa che poi arriva davvero.
        XCTAssertEqual(annuncio?.kind, .long, "dopo due ore sedute, 90 secondi sono la risposta sbagliata")
        XCTAssertEqual(annuncio?.duration, engine.settings.cadence.longDurationSeconds)
        XCTAssertEqual(engine.plan?.kind, .long, "e il piano vivo è lo stesso che è stato annunciato")
    }

    /// Il polo negativo di ISC-160: una call corta non promuove niente.
    func testAShortCallStillEndsInAMicroBreak() {
        var engine = makeEngine()
        stayOnTheCall(&engine, seconds: 35 * 60)      // sotto il doppio dell'intervallo
        XCTAssertEqual(engine.phase, .postponed)
        XCTAssertFalse(engine.isOverdue)

        let events = engine.tick(elapsed: 30, idle: 0, now: Self.workingHour, environment: .quiet)
        let annuncio = events.compactMap { evento -> BreakPlan? in
            if case .deferredBreakDue(let piano) = evento { return piano }
            return nil
        }.first
        XCTAssertEqual(annuncio?.kind, .micro)
    }

    /// La soglia è una scelta dichiarata, non un numero sparso nel codice.
    func testTheOverdueThresholdIsOneWholeCycle() {
        var engine = makeEngine()
        XCTAssertEqual(SessionEngine.overdueLongFactor, 2)
        XCTAssertFalse(engine.isOverdue, "a contatore fermo non si è in ritardo")
        stayOnTheCall(&engine, seconds: 2 * engine.settings.cadence.intervalSeconds + 60)
        XCTAssertTrue(engine.isOverdue)
    }

    // MARK: - ISC-162 · il richiamo delle quattro ore

    func testAMicrophoneOpenForFourHoursWithoutATouchIsAnnouncedOnce() {
        var engine = makeEngine()
        let events = stayOnTheCall(&engine, seconds: 5 * 3600, step: 60)
        let richiami = events.filter { if case .callWatchdog = $0 { return true }; return false }

        XCTAssertEqual(richiami.count, 1, "si dice una volta sola, non a ogni tick")
        // E non blocca: il veto resta il veto.
        XCTAssertNotEqual(engine.phase, .breaking)
    }

    func testNoWatchdogBeforeFourHours() {
        var engine = makeEngine()
        let events = stayOnTheCall(&engine, seconds: 3 * 3600 + 59 * 60, step: 60)
        XCTAssertFalse(events.contains { if case .callWatchdog = $0 { return true }; return false })
    }

    /// Un tocco azzera il sospetto: se stai usando il Mac, la call è una call.
    func testTouchingTheMacResetsTheWatchdog() {
        var engine = makeEngine()
        let ambiente = EngineEnvironment(microphoneActive: true, presence: inCall)
        var events: [EngineEvent] = []
        // Sei ore di riunione in cui però ogni tanto scrivi: idle non supera mai la soglia.
        for _ in 0..<(6 * 60) {
            events += engine.tick(elapsed: 60, idle: 5, now: Self.workingHour, environment: ambiente)
        }
        XCTAssertFalse(events.contains { if case .callWatchdog = $0 { return true }; return false },
                       "chi tocca il Mac non è sparito")
    }

    // MARK: - ISC-164 · `Anti:` il microfono non fa arretrare il contatore

    func testTurningTheMicrophoneOnNeverRewindsTheClock() {
        var engine = makeEngine()
        var massimo = 0.0
        var idle = 0.0
        // Mezz'ora alternando: microfono acceso e spento, immobile e non.
        for passo in 0..<180 {
            let microfono = (passo / 10) % 2 == 0
            idle = microfono ? idle + 10 : 0
            engine.tick(
                elapsed: 10, idle: idle, now: Self.workingHour,
                environment: EngineEnvironment(microphoneActive: microfono,
                                               presence: microfono ? inCall : nil)
            )
            // L'unico calo lecito è quello di una pausa presa: fuori da lì non si arretra.
            if engine.phase == .working, engine.clock.activeSeconds < massimo {
                XCTAssertGreaterThanOrEqual(engine.clock.activeSeconds, massimo,
                                            "il contatore è arretrato al passo \(passo)")
            }
            massimo = max(massimo, engine.clock.activeSeconds)
        }
    }
}
