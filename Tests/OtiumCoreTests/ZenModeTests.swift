import XCTest
@testable import OtiumCore

/// **La modalità Zen**, chiesta il 2026-08-08: in ufficio non ci si allena, e la pausa chiede un
/// respiro guidato invece di un esercizio.
///
/// Quasi tutto quello che c'è qui, provato a mano, vuol dire stare cinque minuti davanti a uno
/// schermo che si gonfia e si sgonfia. `Breath` è un valore puro come `Hold`, per questo: cinque
/// minuti diventano una sottrazione, e i confini che nella vita capitano una volta ogni nove
/// secondi qui capitano tutti a ogni corsa.
final class ZenModeTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 2_000_000)

    static let workingHour: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 11; c.hour = 10; c.minute = 0
        return Calendar.current.date(from: c)!
    }()

    private func zenSettings(_ protocollo: BreathProtocol = .sospiro) -> Settings {
        var s = Settings()
        s.startDate = Self.workingHour
        s.zenMode = true
        s.zenProtocolShort = protocollo
        s.zenProtocolLong = protocollo
        return s
    }

    // MARK: - I numeri che vengono dagli studi

    /// **Sei respiri al minuto sono il parametro, non un'estetica.**
    ///
    /// È il numero che Laborde misura, e l'unico di questo file che non si può ritoccare per far
    /// stare meglio un'animazione. Se un giorno qualcuno cambia i cinque secondi, questo test è ciò
    /// che glielo dice.
    func testResonanceIsExactlySixBreathsPerMinute() {
        XCTAssertEqual(BreathProtocol.risonanza.cycleSeconds, 10)
        XCTAssertEqual(BreathProtocol.risonanza.breathsPerMinute, 6)
    }

    /// **La pausa a vuoto è stata ricavata dentro i dieci secondi, non aggiunta sopra.**
    ///
    /// È il test che protegge il solo numero di questo file che viene da uno studio: aggiungere
    /// mezzo secondo in fondo al ciclo porterebbe la risonanza a 5,7 respiri al minuto, cioè fuori
    /// dal parametro, e non fallirebbe nient'altro. E l'espirazione deve restare la fase più lunga,
    /// perché è quella che Laborde 2021 misura come efficace, al contrario delle pause.
    func testTheEmptyPauseDoesNotStealFromTheBreathingRate() {
        for p in [BreathProtocol.sospiro, .risonanza] {
            XCTAssertTrue(p.cycle.contains { $0.action == .pausa }, "\(p.rawValue) senza pausa a vuoto")
            XCTAssertEqual(p.cycleSeconds, 10, "\(p.rawValue): il ciclo deve restare di dieci secondi")
            let espira = p.cycle.first { $0.action == .espira }!.seconds
            let inspira = p.cycle.filter { $0.action == .inspira || $0.action == .ancora }
                .reduce(0) { $0 + $1.seconds }
            XCTAssertGreaterThanOrEqual(espira, inspira,
                                        "\(p.rawValue): l'espirazione deve restare almeno lunga quanto l'inspirazione")
        }
    }

    /// Il sospiro ciclico ha la forma descritta nello studio: due inspirazioni, la seconda corta, e
    /// un'espirazione più lunga di tutte e due messe insieme.
    func testCyclicSighingHasTwoInhalesAndALongerExhale() {
        let passi = BreathProtocol.sospiro.cycle
        XCTAssertEqual(passi.map(\.action), [.inspira, .ancora, .espira, .pausa])
        let inspirato = passi[0].seconds + passi[1].seconds
        XCTAssertGreaterThan(passi[2].seconds, inspirato,
                             "l'enfasi del protocollo è sull'espirazione: se non è più lunga, non è quel protocollo")
    }

    /// Il box breathing ha quattro tempi uguali. Il polo negativo è nella riga sopra: se tutti e tre
    /// i protocolli avessero la stessa forma, sceglierli non vorrebbe dire niente.
    func testBoxBreathingHasFourEqualCounts() {
        let passi = BreathProtocol.quadrato.cycle
        XCTAssertEqual(passi.count, 4)
        XCTAssertEqual(Set(passi.map(\.seconds)), [4])
        XCTAssertNotEqual(BreathProtocol.quadrato.cycle.map(\.action),
                          BreathProtocol.sospiro.cycle.map(\.action))
    }

    /// Ogni protocollo sa dire da quale studio viene: è la regola di `Evidence`, cioè che la
    /// citazione è il prodotto, e vale anche qui.
    func testEveryProtocolPointsAtAStudyThatExists() {
        for p in BreathProtocol.allCases {
            XCTAssertTrue(Evidence.all.contains { $0.id == p.studyID },
                          "\(p.rawValue) cita \(p.studyID), che non è fra le fonti")
        }
    }

    // MARK: - Il respiro, momento per momento

    private func respiro(_ protocollo: BreathProtocol = .sospiro, total: Double = 300) -> Breath {
        Breath(protocollo: protocollo, total: total, startedAt: t0)
    }

    func testPreparationCountsDownFromThree() {
        let b = respiro()
        XCTAssertEqual(b.phase(at: t0), .preparing(secondsLeft: 3))
        XCTAssertEqual(b.phase(at: t0.addingTimeInterval(2.2)), .preparing(secondsLeft: 1))
    }

    /// **I passi escono nell'ordine giusto e alle ore giuste.** È il cuore del modello: se il ciclo
    /// scivola, a schermo compare «espira» mentre stai inspirando.
    func testStepsFollowTheCycleInOrder() {
        let b = respiro(.sospiro, total: 300)
        let via = t0.addingTimeInterval(Breath.prepareSeconds)
        func azione(_ offset: Double) -> BreathProtocol.Step.Action? {
            guard case .breathing(let step, _, _, _, _)? = Optional(b.phase(at: via.addingTimeInterval(offset)))
            else { return nil }
            return step.action
        }
        // sospiro = inspira 2 · ancora 1 · espira 6 · pausa 1
        XCTAssertEqual(azione(0.0), .inspira)
        XCTAssertEqual(azione(1.9), .inspira)
        XCTAssertEqual(azione(2.1), .ancora)
        XCTAssertEqual(azione(3.5), .espira)
        XCTAssertEqual(azione(8.9), .espira)
        // **La pausa a vuoto**, che è il motivo per cui il ciclo dura dieci secondi e non nove.
        XCTAssertEqual(azione(9.1), .pausa)
        // e il ciclo ricomincia
        XCTAssertEqual(azione(10.1), .inspira)
    }

    /// Il numero del ciclo avanza di uno per giro, e comincia da 1 invece che da 0: a schermo si
    /// legge «respiro 1 di 33», e un respiro numero zero non esiste.
    func testCycleNumberStartsAtOneAndAdvances() {
        let b = respiro(.sospiro, total: 300)
        let via = t0.addingTimeInterval(Breath.prepareSeconds)
        func ciclo(_ offset: Double) -> Int? {
            guard case .breathing(_, _, _, _, let n)? = Optional(b.phase(at: via.addingTimeInterval(offset)))
            else { return nil }
            return n
        }
        XCTAssertEqual(ciclo(0.1), 1)
        XCTAssertEqual(ciclo(9.9), 1)
        XCTAssertEqual(ciclo(10.1), 2)
        XCTAssertEqual(ciclo(20.1), 3)
    }

    /// La frazione dentro il passo va da 0 a 1 e non esce mai: è quella che governa quanto è grande
    /// il cerchio, e un valore fuori scala lo farebbe uscire dallo schermo.
    func testProgressStaysInsideTheStep() {
        let b = respiro(.quadrato, total: 320)
        let via = t0.addingTimeInterval(Breath.prepareSeconds)
        for offset in stride(from: 0.0, to: 64.0, by: 0.37) {
            guard case .breathing(_, _, _, let p, _) = b.phase(at: via.addingTimeInterval(offset)) else {
                return XCTFail("a \(offset) s si dovrebbe respirare")
            }
            XCTAssertGreaterThanOrEqual(p, 0, "frazione negativa a \(offset) s")
            XCTAssertLessThanOrEqual(p, 1, "frazione oltre 1 a \(offset) s")
        }
    }

    /// **I due «trattieni» del respiro quadrato sono passi diversi, e il disegno deve poterli
    /// distinguere.** Senza l'indice il quadrato non si può animare: il lato destro e il sinistro
    /// portano lo stesso passo, e la vista disegnerebbe due volte lo stesso lato.
    ///
    /// Il polo negativo sta nella seconda metà: i due passi sono `==` fra loro, quindi un'animazione
    /// che si fidasse del solo `step` non avrebbe modo di accorgersi dell'errore.
    func testTheTwoHoldsOfBoxBreathingAreTellableApart() {
        let b = respiro(.quadrato, total: 320)
        let via = t0.addingTimeInterval(Breath.prepareSeconds)
        func passo(_ offset: Double) -> (BreathProtocol.Step.Action, Int)? {
            guard case .breathing(let s, let i, _, _, _)? = Optional(b.phase(at: via.addingTimeInterval(offset)))
            else { return nil }
            return (s.action, i)
        }
        // quadrato = inspira 4 · trattieni 4 · espira 4 · trattieni 4
        XCTAssertEqual(passo(1)?.1, 0)
        XCTAssertEqual(passo(5)?.1, 1)
        XCTAssertEqual(passo(9)?.1, 2)
        XCTAssertEqual(passo(13)?.1, 3)
        XCTAssertEqual(passo(17)?.1, 0, "finito il giro si ricomincia dal lato alto")

        XCTAssertEqual(passo(5)?.0, .trattieni)
        XCTAssertEqual(passo(13)?.0, .trattieni)
        XCTAssertEqual(BreathProtocol.quadrato.cycle[1], BreathProtocol.quadrato.cycle[3],
                       "i due passi sono identici: è per questo che serve l'indice")
    }

    func testItEndsWhenTheTimeIsUp() {
        let b = respiro(.risonanza, total: 60)
        let fine = t0.addingTimeInterval(Breath.prepareSeconds + 60)
        XCTAssertNotEqual(b.phase(at: fine.addingTimeInterval(-0.5)), .done)
        XCTAssertEqual(b.phase(at: fine), .done)
    }

    /// **I suoni sono due, e escono una volta sola.**
    ///
    /// Il polo negativo è dentro il test: contando i suoni su tutta la durata, battito per battito,
    /// il totale deve restare 2. Se un giorno qualcuno aggiungesse un suono per passo, qui il
    /// numero esploderebbe a un centinaio — che è esattamente il difetto che il commento su
    /// `Breath.Cue` promette di non avere.
    func testOnlyTwoCuesFireAndEachExactlyOnce() {
        let b = respiro(.sospiro, total: 60)
        var contati: [Breath.Cue] = []
        var t = t0
        while t < b.endsAt.addingTimeInterval(2) {
            let dopo = t.addingTimeInterval(0.1)
            contati += b.cues(from: t, to: dopo)
            t = dopo
        }
        XCTAssertEqual(contati, [.start, .end])
    }

    /// Quanti respiri entrano nella pausa: è il numero mostrato accanto a «respiro N di …».
    func testPlannedCyclesMatchTheProtocol() {
        // Cinque minuti di respiro ciclico, ciclo da 10 s → 30 respiri.
        XCTAssertEqual(respiro(.sospiro, total: 300).plannedCycles, 30)
        // Cinque minuti a sei al minuto → trenta respiri, che è la definizione di sei al minuto.
        XCTAssertEqual(respiro(.risonanza, total: 300).plannedCycles, 30)
    }

    // MARK: - Il piano della pausa

    /// **Con Zen accesa il piano porta un respiro, e non porta un circuito.**
    private func primoPiano(_ settings: Settings) -> BreakPlan {
        var engine = SessionEngine(settings: settings, maxCredibleElapsed: 120)
        var piano: BreakPlan?
        var t = 0.0
        while t < settings.cadence.intervalSeconds + 120, piano == nil {
            for event in engine.tick(elapsed: 10, idle: 0, now: Self.workingHour, environment: .quiet) {
                if case .breakStarted(let p) = event { piano = p }
            }
            t += 10
        }
        return piano!
    }

    func testZenPlanCarriesABreathAndNoCircuit() {
        var s = zenSettings(.risonanza)
        s.circuitMode = .subito        // il modo più insistente: se il circuito passasse, passerebbe qui
        let piano = primoPiano(s)
        XCTAssertEqual(piano.breath, .risonanza)
        XCTAssertTrue(piano.isZen)
        XCTAssertTrue(piano.circuit.isEmpty, "in Zen non si fanno esercizi, quindi non si fa nemmeno un circuito")
        XCTAssertFalse(piano.circuitActive)
    }

    /// **Le due pause chiedono due respiri diversi**, deciso con lui il 2026-08-08.
    ///
    /// Micro il respiro ciclico, che agisce respiro per respiro e in 87 secondi ne fa otto; piena la
    /// risonanza, la cui prova vagale è misurata proprio su cinque minuti. E il box non è il
    /// predefinito di nessuna delle due: nell'unico confronto diretto è quello che ha perso, e resta
    /// a menu per chi lo preferisce.
    func testTheTwoBreakKindsAskForDifferentBreathing() {
        var s = Settings()
        s.zenMode = true
        XCTAssertEqual(s.zenProtocol(for: .micro), .sospiro)
        XCTAssertEqual(s.zenProtocol(for: .long), .risonanza)
        XCTAssertNotEqual(s.zenProtocol(for: .micro), s.zenProtocol(for: .long),
                          "se fossero uguali, avere due impostazioni non vorrebbe dire niente")
        for kind in [BreakKind.micro, .long] {
            XCTAssertNotEqual(s.zenProtocol(for: kind), .quadrato,
                              "il quadrato è una scelta, non un default")
        }
    }

    /// Il polo negativo del test sopra: **spenta, la modalità non tocca niente**. Senza questo,
    /// «il piano ha un respiro» sarebbe compatibile con un'app che ce l'ha sempre.
    func testWithoutZenThePlanIsUntouched() {
        var s = Settings()
        s.startDate = Self.workingHour
        let piano = primoPiano(s)
        XCTAssertNil(piano.breath)
        XCTAssertFalse(piano.isZen)
    }

    /// **Il respiro guidato dura quanto dici tu, e mai più della pausa che lo contiene.**
    ///
    /// I due poli sono nello stesso test. Su una pausa piena la durata scelta comanda, e ne resta
    /// riposo; su una micro-pausa da 90 secondi la stessa scelta viene tagliata dalla pausa, o il
    /// respiro finirebbe dopo il tempo e il pulsante resterebbe spento davanti a chi ha finito.
    func testGuidedBreathingNeverOutlastsItsBreak() {
        // La prima pausa della giornata è una micro da 90 secondi, quindi qui la scelta da tre
        // minuti **deve** essere tagliata: è il polo che prova che il tetto esiste davvero.
        var s = zenSettings()
        s.zenBreathSeconds = 180
        let micro = primoPiano(s)
        XCTAssertEqual(micro.kind, .micro)
        // 87 secondi utili non sono un numero intero di respiri: scendono a 80, cioè otto cicli.
        XCTAssertEqual(SessionEngine.breathSeconds(for: micro), 80)

        // Su una pausa piena la stessa scelta passa intera, e ne resta riposo: il polo opposto.
        var piena = BreakPlan(index: 3, kind: .long, duration: 300,
                              exercise: Exercise(kind: .squat, reps: 15))
        piena.breath = .sospiro
        piena.breathSeconds = min(180, 300 - Breath.prepareSeconds)
        XCTAssertEqual(SessionEngine.breathSeconds(for: piena), 180)
        XCTAssertLessThan(SessionEngine.breathSeconds(for: piena), piena.duration,
                          "se riempie tutta la pausa non resta riposo")
    }

    /// La dose studiata resta raggiungibile: cinque minuti su una pausa piena sono esattamente
    /// quello che Balban ha misurato, e il menu deve poterci arrivare.
    ///
    /// **Il piano si costruisce a mano, e non con `primoPiano`.** La prima pausa della giornata è
    /// una micro da 90 secondi: con quella il test passerebbe anche se il tetto ignorasse la scelta,
    /// perché 300 e 87 finiscono tutti e due tagliati a 87. Sarebbe un verde che risponde a una
    /// domanda più debole di quella che ho fatto.
    func testTheStudiedDoseIsStillReachable() {
        var piena = BreakPlan(index: 3, kind: .long, duration: 300,
                              exercise: Exercise(kind: .squat, reps: 15))
        piena.breath = .sospiro
        piena.breathSeconds = min(300, 300 - Breath.prepareSeconds)
        XCTAssertEqual(SessionEngine.breathSeconds(for: piena), 290, "29 respiri interi, non 29,7")
        XCTAssertEqual(Breath(protocollo: .sospiro, total: 290, startedAt: t0).plannedCycles, 29)
    }

    /// **Il respiro non si tronca mai a metà.**
    ///
    /// Segnalato da lui il 2026-08-08: *«l'esercizio si interrompe all'improvviso»*, perché 87
    /// secondi utili facevano 8,7 respiri e l'ultimo veniva tagliato in piena espirazione. I due
    /// poli sono qui dentro: il tempo consegnato è un multiplo esatto del ciclo, **e** resta il più
    /// grande che ci sta, cioè non ha buttato via un respiro buono per arrotondare.
    func testTheLastBreathIsNeverCutInHalf() {
        for p in BreathProtocol.allCases {
            for richiesti in [60.0, 87.0, 90.0, 180.0, 297.0] {
                let dato = Breath.wholeCycles(richiesti, of: p)
                XCTAssertEqual(dato.truncatingRemainder(dividingBy: p.cycleSeconds), 0, accuracy: 0.001,
                               "\(p.rawValue) a \(richiesti) s: \(dato) non è un numero intero di respiri")
                XCTAssertLessThanOrEqual(dato, max(richiesti, p.cycleSeconds))
                XCTAssertGreaterThan(dato + p.cycleSeconds, richiesti,
                                     "\(p.rawValue): ci stava un respiro in più e l'ha buttato")
            }
        }
        // Sotto un ciclo si consegna comunque un respiro intero: mezzo respiro non è una guida.
        XCTAssertEqual(Breath.wholeCycles(4, of: .quadrato), 16)
    }

    // MARK: - Il cancello anti-bluff

    /// **Il respiro non si può dichiarare finito prima del tempo**, e finito il tempo si chiude.
    /// Due poli nello stesso test: senza il primo il cancello non esiste, senza il secondo il
    /// cancello è un muro.
    func testBreathCannotBeDeclaredDoneEarlyButClosesOnTime() {
        let s = zenSettings()
        var engine = SessionEngine(settings: s, maxCredibleElapsed: 120)
        var piano: BreakPlan?
        var t = 0.0
        while t < s.cadence.intervalSeconds + 120, piano == nil {
            for event in engine.tick(elapsed: 10, idle: 0, now: Self.workingHour, environment: .quiet) {
                if case .breakStarted(let p) = event { piano = p }
            }
            t += 10
        }
        let corrente = piano!

        // Un istante dopo l'inizio: no.
        engine.markBreathDone()
        XCTAssertFalse(engine.exerciseDone, "un respiro appena cominciato non è un respiro fatto")

        // Passato il tempo: sì.
        var trascorso = 0.0
        while trascorso < corrente.duration + 20 {
            engine.tick(elapsed: 10, idle: 0, now: Self.workingHour, environment: .quiet)
            trascorso += 10
        }
        engine.markBreathDone()
        XCTAssertTrue(engine.exerciseDone)
        XCTAssertTrue(engine.canReturnToWork, "finito il respiro, il pulsante si deve accendere")
    }

    // MARK: - Cosa annuncia il preavviso

    /// **Il difetto vero del 2026-08-08**: con Zen accesa il preavviso diceva «16 ponte per i
    /// glutei». Qui ci sono i tre casi, e i due poli sono nello stesso test: se `demandLabel`
    /// tornasse sempre l'esercizio, il primo fallirebbe; se tornasse sempre il respiro,
    /// fallirebbero gli altri due.
    func testTheBreakAnnouncesWhatItWillActuallyAskFor() {
        L.language = .italian
        var zen = BreakPlan(index: 1, kind: .long, duration: 300,
                            exercise: Exercise(kind: .gluteBridge, reps: 16))
        zen.breath = .sospiro
        XCTAssertEqual(zen.demandLabel, BreathProtocol.sospiro.localizedName)
        XCTAssertFalse(zen.demandLabel.contains("ponte"),
                       "questa è la riga esatta che il principale ha visto sbagliata")

        let singolo = BreakPlan(index: 1, kind: .micro, duration: 90,
                                exercise: Exercise(kind: .gluteBridge, reps: 16))
        XCTAssertEqual(singolo.demandLabel, singolo.exercise.label)

        var circuito = BreakPlan(index: 1, kind: .long, duration: 300,
                                 exercise: Exercise(kind: .squat, reps: 15),
                                 circuit: [Exercise(kind: .squat, reps: 15),
                                           Exercise(kind: .pushUp, reps: 10)])
        circuito.circuitActive = true
        XCTAssertEqual(circuito.demandLabel, "il circuito")
    }

    /// E in inglese non resta una parola italiana: il preavviso è una delle poche superfici che
    /// vede chi non ha mai aperto le preferenze.
    func testTheAnnouncementIsTranslated() {
        L.language = .english
        defer { L.language = .italian }
        var zen = BreakPlan(index: 1, kind: .long, duration: 300,
                            exercise: Exercise(kind: .squat, reps: 15))
        zen.breath = .risonanza
        XCTAssertEqual(zen.demandLabel, "six breaths a minute")
    }

    // MARK: - Il registro

    /// **Una pausa Zen conta come pausa e non conta come esercizio.** È la terza strada fra le due
    /// sbagliate, e questo test è il posto dove è scritta.
    func testZenBreakCountsAsABreakWithNoReps() {
        var piano = BreakPlan(index: 1, kind: .long, duration: 300,
                              exercise: Exercise(kind: .squat, reps: 20))
        piano.breath = .sospiro
        let riga = Ledger.entry(for: .breakCompleted(piano), now: t0)!

        XCTAssertEqual(riga.type, .completed)
        XCTAssertNil(riga.exercise, "l'esercizio del turno esiste nel piano, ma non l'ha fatto nessuno")
        XCTAssertNil(riga.reps)
        XCTAssertEqual(riga.reason, "zen:sospiro")

        let sommario = Ledger.summarize([riga])
        XCTAssertEqual(sommario.completed, 1)
        XCTAssertEqual(sommario.zenBreaks, 1)
        XCTAssertEqual(sommario.totalReps, 0)
        XCTAssertEqual(sommario.vigorousBouts, 0)
    }

    /// Il polo negativo: **una pausa normale continua a scrivere il suo esercizio e non è Zen**.
    func testNormalBreakStillNamesItsExerciseAndIsNotCountedAsZen() {
        let piano = BreakPlan(index: 1, kind: .micro, duration: 90,
                              exercise: Exercise(kind: .squat, reps: 20))
        let riga = Ledger.entry(for: .breakCompleted(piano), now: t0)!
        XCTAssertEqual(riga.exercise, .squat)
        XCTAssertNil(riga.reason)
        XCTAssertEqual(Ledger.summarize([riga]).zenBreaks, 0)
    }

    /// Un esercizio intenso fatto in una giornata mista resta contato: la modalità Zen non deve
    /// spegnere le statistiche di chi la accende solo il martedì.
    func testAMixedDayKeepsBothCounts() {
        var zen = BreakPlan(index: 1, kind: .long, duration: 300,
                            exercise: Exercise(kind: .squat, reps: 20))
        zen.breath = .risonanza
        let normale = BreakPlan(index: 2, kind: .micro, duration: 90,
                                exercise: Exercise(kind: .burpee, reps: 10))
        let righe = [
            Ledger.entry(for: .breakCompleted(zen), now: t0)!,
            Ledger.entry(for: .exerciseConfirmed(normale.exercise), now: t0)!,
            Ledger.entry(for: .breakCompleted(normale), now: t0)!,
        ]
        let s = Ledger.summarize(righe)
        XCTAssertEqual(s.completed, 2)
        XCTAssertEqual(s.zenBreaks, 1)
        XCTAssertEqual(s.totalReps, 10)
        XCTAssertEqual(s.vigorousBouts, 1)
    }

    /// Il sottoinsieme non può superare il totale nemmeno dopo un annullamento.
    func testUndoNeverLeavesMoreZenBreaksThanBreaks() {
        var zen = BreakPlan(index: 1, kind: .long, duration: 300,
                            exercise: Exercise(kind: .squat, reps: 20))
        zen.breath = .sospiro
        let righe = [
            Ledger.entry(for: .breakCompleted(zen), now: t0)!,
            LedgerEntry(timestamp: t0, type: .undo),
        ]
        let s = Ledger.summarize(righe)
        XCTAssertEqual(s.completed, 0)
        XCTAssertLessThanOrEqual(s.zenBreaks, s.completed)
    }

    // MARK: - Le frasi

    /// **In Zen non escono fatti scientifici.**
    func testZenPoolCarriesNoFacts() {
        let zen = PhraseLibrary.zenPool(includingUser: false)
        XCTAssertFalse(zen.isEmpty)
        XCTAssertFalse(zen.contains { $0.kind == .fatto },
                       "un fatto sulla glicemia mentre respiri risponde a una domanda che non hai fatto")
    }

    /// Il polo negativo: **il pool normale i fatti ce li ha**. Senza questa riga, il test sopra
    /// passerebbe anche se `Facts` fosse vuoto, cioè proprio quando non sta misurando niente.
    func testTheNormalPoolDoesCarryFacts() {
        XCTAssertTrue(PhraseLibrary.breakPool(includingUser: false).contains { $0.kind == .fatto })
    }

    // MARK: - Le impostazioni

    /// Un file scritto prima di questa versione non deve svegliarsi in modalità Zen.
    func testOldSettingsFilesDefaultToZenOff() throws {
        let json = #"{"theme":"alloro"}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let letto = try decoder.decode(Settings.self, from: json)
        XCTAssertFalse(letto.zenMode)
        XCTAssertEqual(letto.zenProtocolShort, .sospiro)
        XCTAssertEqual(letto.zenProtocolLong, .risonanza)
    }

    /// E una volta scelta, la scelta sopravvive al giro su disco.
    func testZenSurvivesARoundTrip() throws {
        var s = zenSettings(.quadrato)
        s.theme = .porpora
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let riletto = try decoder.decode(Settings.self, from: encoder.encode(s))
        XCTAssertTrue(riletto.zenMode)
        XCTAssertEqual(riletto.zenProtocolShort, .quadrato)
        XCTAssertEqual(riletto.zenProtocolLong, .quadrato)
    }

    // MARK: - I colori

    /// **La veste Zen cambia l'accento e non tocca la stanza.** È la regola di famiglia scritta in
    /// `MacAppRules`: le livree si distinguono per accento, carta e inchiostro sono comuni.
    func testZenPaletteMovesOnlyTheAccent() {
        for tema in ThemeName.allCases {
            let normale = tema.palette, zen = tema.zenPalette
            XCTAssertEqual(zen.ink, normale.ink, "\(tema.rawValue): lo sfondo non si tocca")
            XCTAssertEqual(zen.paper, normale.paper)
            XCTAssertEqual(zen.dim, normale.dim)
            XCTAssertNotEqual(zen.accent, normale.accent, "\(tema.rawValue): se l'accento non cambia, non si vede niente")
            XCTAssertNotEqual(zen.accentOnLight, normale.accentOnLight)
        }
    }
}
