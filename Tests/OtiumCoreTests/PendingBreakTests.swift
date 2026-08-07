import XCTest
@testable import OtiumCore

/// **La pausa che ti dovevo deve sopravvivere alla chiusura dell'app.**
///
/// Il caso vero, ricostruito dal registro del principale il 2026-08-04: alle 18:20:28 rinvia una
/// pausa **piena**, chiude Otium, la riapre, e alle 18:22:26 quella che torna è una **micro** —
/// chiusa con 16 squat invece dei cinque minuti che gli spettavano. La piena non era stata fatta
/// e non è più arrivata.
///
/// La causa non è il rinvio: è che `EngineSnapshot` salvava rotazione, orologio e data, e **non**
/// il tipo della pausa in attesa. Alla riapertura il tipo veniva ricalcolato da zero, e un tipo
/// che dipende dall'orologio del momento in cui è stato scritto non si ricalcola dopo — chiudere
/// l'app quell'orologio lo riporta indietro.
///
/// I test qui dentro provano il giro completo: il tipo esce nello snapshot, sopravvive al JSON su
/// disco, torna al ripristino, vale **una volta sola** e scade se sei stato via abbastanza da
/// aver fatto la pausa camminando.
final class PendingBreakTests: XCTestCase {

    private static let workingHour = SessionEngineTests.workingHour

    private func makeEngine(_ settings: Settings? = nil) -> SessionEngine {
        var s = settings ?? Settings()
        s.startDate = Self.workingHour
        return SessionEngine(settings: s, maxCredibleElapsed: 120)
    }

    /// Porta il motore al preavviso di una pausa **piena** e la rinvia: è lo stato in cui il
    /// principale ha chiuso l'app.
    private func postponedLongBreak() -> SessionEngine {
        var engine = makeEngine()
        // Due micro complete, così la terza pausa è la piena del ciclo.
        for _ in 0..<2 {
            engine.forceBreakNow(now: Self.workingHour)
            guard let plan = engine.plan else { continue }
            _ = engine.tick(elapsed: plan.exercise.minimumSeconds + 5, idle: 0,
                            now: Self.workingHour, environment: .quiet)
            engine.markExerciseDone()
            _ = engine.tick(elapsed: plan.duration + 5, idle: 0,
                            now: Self.workingHour, environment: .quiet)
            engine.returnToWork()
        }
        // Il tempo per arrivare al preavviso da solo, come nella vita.
        var t = 0.0
        let soglia = engine.settings.cadence.intervalSeconds - engine.settings.cadence.warningSeconds
        while t < soglia + 10 {
            _ = engine.tick(elapsed: 10, idle: 0, now: Self.workingHour, environment: .quiet)
            t += 10
        }
        XCTAssertEqual(engine.plan?.kind, .long, "premessa: la terza pausa del ciclo è la piena")
        _ = engine.postpone()
        XCTAssertEqual(engine.phase, .postponed)
        return engine
    }

    /// Il difetto, per intero: rinvio una piena, chiudo, riapro, e quella che arriva è ancora una
    /// piena. Prima della riparazione qui usciva `.micro`.
    func testAPostponedLongBreakSurvivesQuittingTheApp() throws {
        let prima = postponedLongBreak()
        XCTAssertEqual(prima.snapshot.pendingKind, .long,
                       "il tipo della pausa in attesa deve finire nello snapshot")

        // Il giro vero passa da un file JSON, non da una struct in memoria.
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        var riletto = try decoder.decode(EngineSnapshot.self,
                                         from: encoder.encode(prima.snapshot))
        XCTAssertEqual(riletto.pendingKind, .long, "e sopravvivere al giro su disco")

        // **Il ciclo va messo a tacere, o il verde non dimostra niente.** Arrivati qui
        // `microsSinceLong` vale 2, cioè la piena la imporrebbe comunque la rotazione: azzerato,
        // la rotazione vuole una micro e la piena può arrivare da una parte sola.
        riletto.microsSinceLong = 0

        var dopo = makeEngine()
        dopo.restore(riletto, now: Self.workingHour.addingTimeInterval(40))
        dopo.forceBreakNow(now: Self.workingHour.addingTimeInterval(40))
        XCTAssertEqual(dopo.plan?.kind, .long,
                       "la pausa piena rinviata non deve tornare come micro dopo un riavvio")

        // L'altro polo, che cambia **un campo solo**: senza la pausa dovuta, lo stesso identico
        // stato consegna la micro che il principale si è ritrovato il 2026-08-04.
        var senza = riletto
        senza.pendingKind = nil
        var controllo = makeEngine()
        controllo.restore(senza, now: Self.workingHour.addingTimeInterval(40))
        controllo.forceBreakNow(now: Self.workingHour.addingTimeInterval(40))
        XCTAssertEqual(controllo.plan?.kind, .micro,
                       "è il campo nuovo a fare il lavoro, non la rotazione")
    }

    /// **Il polo negativo, e senza di lui il verde non vale niente:** chi chiude l'app mentre
    /// lavora non ha nessuna pausa in sospeso, e alla riapertura il ciclo decide da sé.
    func testQuittingWhileWorkingLeavesNothingPending() {
        var engine = makeEngine()
        var t = 0.0
        while t < 600 {
            _ = engine.tick(elapsed: 10, idle: 0, now: Self.workingHour, environment: .quiet)
            t += 10
        }
        XCTAssertEqual(engine.phase, .working)
        XCTAssertNil(engine.snapshot.pendingKind)

        var dopo = makeEngine()
        dopo.restore(engine.snapshot, now: Self.workingHour.addingTimeInterval(30))
        dopo.forceBreakNow(now: Self.workingHour.addingTimeInterval(30))
        XCTAssertEqual(dopo.plan?.kind, .micro, "senza niente in sospeso comanda il ciclo")
    }

    /// **Il secondo polo negativo: la fase `breaking` resta fuori.** Chiudere l'app con lo schermo
    /// già coperto vuol dire che la pausa la stavi facendo; riproporla intera alla riapertura
    /// punirebbe proprio chi l'aveva quasi finita.
    func testABreakAlreadyOnScreenIsNotOwedAgain() {
        var engine = postponedLongBreak()
        // Il rinvio scade e lo schermo si copre.
        var t = 0.0
        while t < engine.settings.cadence.postponeSeconds + 70 {
            _ = engine.tick(elapsed: 10, idle: 0, now: Self.workingHour, environment: .quiet)
            t += 10
        }
        XCTAssertEqual(engine.phase, .breaking, "premessa: la pausa è cominciata")
        XCTAssertNil(engine.snapshot.pendingKind)
    }

    /// Oltre la finestra di grazia la pausa non si deve più: sei stato via quanto una pausa
    /// piena, e quella pausa l'hai fatta camminando. È la stessa soglia con cui l'orologio decide
    /// se riprendere o ripartire da zero, e vale una sola volta anche dentro la finestra.
    ///
    /// **Lo snapshot qui è scritto a mano, e non è una scorciatoia: è l'unico modo di misurare
    /// qualcosa.** Con `microsSinceLong` a 2 la pausa piena la impone già il ciclo, quindi
    /// qualunque verde direbbe solo che il ciclo funziona — la prima versione di questo test è
    /// caduta esattamente lì. A zero il ciclo vuole una micro, e la piena può arrivare da una
    /// sola parte: la pausa che ti dovevo.
    func testThePendingBreakExpiresWithTheGraceWindowAndIsSpentOnce() {
        let dovuta = EngineSnapshot(breakIndex: 7, microsSinceLong: 0, launchCount: 3,
                                    activeSeconds: 1_500,
                                    lastBreakAt: Self.workingHour,
                                    pendingKind: .long,
                                    savedAt: Self.workingHour)
        let grazia = makeEngine().settings.resumeGraceSeconds

        var tardi = makeEngine()
        tardi.restore(dovuta, now: Self.workingHour.addingTimeInterval(grazia + 60))
        tardi.forceBreakNow(now: Self.workingHour.addingTimeInterval(grazia + 60))
        XCTAssertEqual(tardi.plan?.kind, .micro,
                       "via cinque minuti: la pausa piena l'hai fatta alzandoti")

        // Consumata una volta: la pausa **dopo** torna a essere quella che tocca al ciclo, o
        // ogni pausa della giornata erediterebbe il tipo di quella persa.
        var subito = makeEngine()
        subito.restore(dovuta, now: Self.workingHour.addingTimeInterval(40))
        subito.forceBreakNow(now: Self.workingHour.addingTimeInterval(40))
        XCTAssertEqual(subito.plan?.kind, .long, "dentro la grazia, la piena che ti dovevo")
        guard let piano = subito.plan else { return XCTFail("nessun piano") }
        _ = subito.tick(elapsed: piano.exercise.minimumSeconds + 5, idle: 0,
                        now: Self.workingHour, environment: .quiet)
        subito.markExerciseDone()
        _ = subito.tick(elapsed: piano.duration + 5, idle: 0,
                        now: Self.workingHour, environment: .quiet)
        subito.returnToWork()
        subito.forceBreakNow(now: Self.workingHour.addingTimeInterval(200))
        XCTAssertEqual(subito.plan?.kind, .micro, "la pausa dovuta vale una volta sola")
    }

    /// Un `rotation.json` scritto dalla versione precedente non ha il campo: deve valere «niente
    /// in sospeso», non inventarsi una pausa che nessuno ha rinviato.
    func testAnOldRotationFileHasNothingPending() throws {
        let json = #"{"breakIndex":112,"microsSinceLong":1,"launchCount":198,"activeSeconds":247,"savedAt":"2026-08-04T16:29:12Z"}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(EngineSnapshot.self, from: Data(json.utf8))
        XCTAssertNil(snapshot.pendingKind)
    }
}
