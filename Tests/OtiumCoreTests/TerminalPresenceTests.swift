import XCTest
@testable import OtiumCore

/// Il caso del 2026-08-05: **leggere l'output di un terminale è tempo seduto**, e fino a quel
/// giorno l'app lo leggeva come assenza. Il principale ha lavorato due ore senza una sola
/// interruzione e ha chiesto perché; il registro diceva cinque pause «naturali» mai fatte, di cui
/// tre da 90, 121 e 123 secondi — cioè esattamente la lettura di un output lungo, accreditata
/// come riposo.
///
/// La sonda dell'input non c'entrava e la misura lo ha provato: `CGEventSource` vedeva la sua
/// tastiera al decimo di secondo. Mancava il ramo: `PresenceClassifier` conosceva lettori, player
/// e browser, e un terminale in primo piano cadeva su `nil`.
///
/// Qui si prova che il caso è morto e che il rimedio **non** ha rotto quello opposto: oltre il
/// tetto dei 5 minuti, terminale davanti o no, l'assenza torna a valere come assenza.
final class TerminalPresenceTests: XCTestCase {

    static let workingHour: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 5; c.hour = 10
        return Calendar.current.date(from: c)!
    }()

    private let terminal = PresenceSignal(kind: .terminal, detail: "terminale — iTerm2")

    private func makeEngine() -> SessionEngine {
        var s = Settings()
        s.startDate = Self.workingHour
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Guida il motore per N secondi **senza un solo input**, col terminale in primo piano: è
    /// l'agente che macina mentre lui legge quello che esce.
    /// **`presence` non ha un default risolto con `??`, e la ragione è un test che si è spento da
    /// solo.** Scritto come `presence ?? terminal`, passare `nil` di proposito — cioè l'app com'era
    /// prima del rimedio — restituiva il terminale, e il polo negativo misurava il caso positivo.
    /// Un parametro che il chiamante non può davvero mettere a zero non è un parametro.
    @discardableResult
    private func readTheOutput(
        _ engine: inout SessionEngine,
        seconds: Double,
        presence: PresenceSignal?,
        step: Double = 10
    ) -> [EngineEvent] {
        var events: [EngineEvent] = []
        var idle = 0.0
        let segnale = presence
        while idle < seconds {
            idle += step
            events += engine.tick(
                elapsed: step, idle: idle, now: Self.workingHour,
                environment: EngineEnvironment(presence: segnale)
            )
        }
        return events
    }

    private func naturalBreaks(_ events: [EngineEvent]) -> [EngineEvent] {
        events.filter {
            if case .naturalBreak = $0 { return true }
            return false
        }
    }

    // MARK: - Il polo positivo · sotto il tetto il tempo continua a contare

    /// Le tre pause fantasma vere del 5 agosto, prese dal suo `ledger.jsonl`. Nessuna delle tre
    /// deve più esistere.
    func testTheThreeGhostBreaksOfAugustFifthAreGone() {
        for seconds in [90.0, 121.0, 123.0] {
            var engine = makeEngine()
            let events = readTheOutput(&engine, seconds: seconds, presence: terminal)
            XCTAssertTrue(naturalBreaks(events).isEmpty,
                          "\(Int(seconds))s di lettura col terminale davanti non sono una pausa")
        }
    }

    /// **Il polo negativo, e senza di lui il test qui sopra non prova niente.** Stessa identica
    /// immobilità *senza* il segnale — cioè l'app com'era la mattina del 5 agosto — e le tre
    /// pause fantasma tornano tutte e tre. È la misura che dice che a chiuderle è stato il
    /// rimedio, non la soglia a 90 e non il caso.
    func testWithoutTheSignalTheGhostBreaksComeBack() {
        for seconds in [121.0, 123.0] {
            var engine = makeEngine()
            for _ in 0..<120 {
                engine.tick(elapsed: 10, idle: 0, now: Self.workingHour,
                            environment: EngineEnvironment(presence: nil))
            }
            readTheOutput(&engine, seconds: seconds, presence: nil)
            let ritorno = engine.tick(elapsed: 10, idle: 0, now: Self.workingHour,
                                      environment: EngineEnvironment(presence: nil))
            XCTAssertFalse(naturalBreaks(ritorno).isEmpty,
                           "senza segnale \(Int(seconds))s tornano a essere una pausa regalata")
        }
    }

    func testFourMinutesOfReadingStillCountAsSittingTime() {
        var engine = makeEngine()
        readTheOutput(&engine, seconds: 4 * 60, presence: terminal)
        XCTAssertGreaterThan(engine.clock.activeSeconds, 4 * 60 - 30,
                             "sotto il tetto l'orologio deve camminare")
    }

    // MARK: - Il polo negativo · oltre il tetto l'assenza torna assenza

    /// Senza questo, il rimedio sarebbe peggiore del difetto: basterebbe lasciare iTerm davanti e
    /// andare a pranzo per farsi contare il pranzo come lavoro.
    func testBeyondTheCapTheSignalStopsHolding() {
        let engine = makeEngine()
        XCTAssertTrue(engine.presenceHolds(terminal, idle: PresenceCap.terminal - 1))
        XCTAssertFalse(engine.presenceHolds(terminal, idle: PresenceCap.terminal + 1))
    }

    /// **La pausa si scrive al rientro, non mentre sei via** — il primo giro di questo test la
    /// cercava durante l'assenza e usciva rosso sul codice giusto. Qui l'assenza finisce con un
    /// tocco, che è l'unico momento in cui il motore può sapere quanto è durata.
    func testAnHourAwayWithTheTerminalInFrontIsStillANaturalBreak() {
        var engine = makeEngine()
        // **Prima si lavora davvero.** Una pausa vale solo dopo `minimumSedentaryBeforeCredit`
        // secondi di seduta: senza questo, il motore vergine non accredita niente e il test
        // uscirebbe rosso su codice sano — che è come è uscito al primo giro.
        for _ in 0..<120 {
            engine.tick(elapsed: 10, idle: 0, now: Self.workingHour,
                        environment: EngineEnvironment(presence: terminal))
        }
        readTheOutput(&engine, seconds: 3600, presence: terminal, step: 60)
        let ritorno = engine.tick(elapsed: 10, idle: 0, now: Self.workingHour,
                                  environment: EngineEnvironment(presence: terminal))
        let pause = naturalBreaks(ritorno)
        XCTAssertFalse(pause.isEmpty, "un'ora immobile resta un'assenza, terminale o no")

        // E il credito parte da **dove il segnale ha smesso di tenere**, non dall'ultimo tocco:
        // i primi 5 minuti li hai passati a leggere, e leggere non è riposare. Accreditare
        // l'ora intera regalerebbe una pausa piena a chi ha appena finito di fissare lo schermo.
        guard case .naturalBreak(let credito)? = pause.first else {
            return XCTFail("attesa una pausa naturale")
        }
        XCTAssertEqual(credito.seconds, 3600 - PresenceCap.terminal, accuracy: 90,
                       "il tempo sotto il tetto non è pausa")
    }

    /// Il tetto del terminale è **il più stretto dei quattro**, ed è una scelta, non un caso:
    /// un terminale resta in primo piano da solo molto più facilmente di un PDF aperto.
    func testTerminalHasTheTightestCap() {
        XCTAssertEqual(PresenceCap.terminal, 5 * 60)
        XCTAssertLessThan(PresenceCap.terminal, PresenceCap.reading)
        XCTAssertLessThan(PresenceCap.reading, PresenceCap.media)
        XCTAssertFalse(PresenceCap.call.isFinite)
    }

    // MARK: - Il classificatore

    func testTerminalsAndEditorsAreRecognised() {
        for bundle in ["com.googlecode.iterm2", "com.apple.Terminal", "com.mitchellh.ghostty",
                       "com.microsoft.VSCode", "com.apple.dt.Xcode"] {
            let signal = PresenceClassifier.classify(
                frontmost: bundle, isPlayingAudio: false, document: nil, appName: "app"
            )
            XCTAssertEqual(signal?.kind, .terminal, "\(bundle) deve contare come terminale")
        }
    }

    /// L'elenco è chiuso di proposito: qui il segnale è **solo** l'app in primo piano, senza la
    /// seconda conferma che hanno player e lettori. Con un elenco aperto, qualunque app diventerebbe
    /// presenza — e con lei qualunque scrivania vuota.
    func testAnUnknownAppIsStillAbsence() {
        XCTAssertNil(PresenceClassifier.classify(
            frontmost: "com.example.sconosciuta", isPlayingAudio: false, document: nil, appName: "X"
        ))
        XCTAssertNil(PresenceClassifier.classify(
            frontmost: nil, isPlayingAudio: false, document: nil, appName: "X"
        ))
    }

    /// La call vince su tutto, terminale compreso: chi è in riunione con iTerm davanti ha il tetto
    /// infinito della call, non i 5 minuti del terminale.
    func testACallBeatsTheTerminal() {
        let signal = PresenceClassifier.classify(
            frontmost: "com.googlecode.iterm2", isPlayingAudio: false, document: nil,
            appName: "iTerm2", microphoneActive: true
        )
        XCTAssertEqual(signal?.kind, .call)
    }

    // MARK: - La soglia

    /// Sua richiesta del 2026-08-05: *«non dovrebbe essere 60 secondi ma 90 come una vera pausa
    /// naturale»*. Vale per tutte e tre le cadenze, non solo per quella attiva.
    func testIdleThresholdIsNinetySecondsInEveryCadence() {
        for cadence in [Cadence.optionA, Cadence.optionB, Cadence.optionC] {
            XCTAssertEqual(cadence.idleThresholdSeconds, 90)
        }
    }
}
