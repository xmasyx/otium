import XCTest
@testable import OtiumCore

/// Il conto alla rovescia delle tenute.
///
/// Tutto quello che c'è qui, provato a mano, vuol dire stare in plank quarantacinque secondi per
/// vedere un numero. Il modello è puro apposta: quarantacinque secondi diventano una sottrazione,
/// e i momenti che nella vita capitano una volta — l'istante esatto del cambio di lato, l'ultimo
/// secondo — qui capitano a ogni corsa.
final class HoldTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func plank(_ seconds: Double = 45) -> Hold {
        Hold(total: seconds, perSide: false, startedAt: t0)
    }

    private func sidePlank(_ seconds: Double = 40) -> Hold {
        Hold(total: seconds, perSide: true, startedAt: t0)
    }

    // MARK: - La preparazione

    /// I cinque secondi per scendere si vedono scendere, e cominciano da 5.
    func testPreparationCountsDownFromFive() {
        let h = plank()
        XCTAssertEqual(h.phase(at: t0), .preparing(secondsLeft: 5))
        // A 0,8 secondi dal via il numero è 1, non 0: lo zero non si mostra, si parte.
        XCTAssertEqual(h.phase(at: t0.addingTimeInterval(4.2)), .preparing(secondsLeft: 1))
    }

    /// **Il quinto secondo dura un secondo.** Con un arrotondamento al posto di `ceil` il conto
    /// partirebbe da 4 e la preparazione promessa sarebbe più corta di quella data.
    func testTheFirstSecondOfPreparationIsWholeAndShownAsFive() {
        let h = plank()
        for offset in [0.0, 0.3, 0.99] {
            XCTAssertEqual(h.phase(at: t0.addingTimeInterval(offset)), .preparing(secondsLeft: 5),
                           "a \(offset) s dal via si deve ancora leggere 5")
        }
        XCTAssertEqual(h.phase(at: t0.addingTimeInterval(1.01)), .preparing(secondsLeft: 4))
    }

    // MARK: - La tenuta

    /// Il tempo va all'indietro, e comincia dal numero promesso.
    func testTheHoldCountsBackwardsFromTheAskedSeconds() {
        let h = plank(45)
        XCTAssertEqual(h.phase(at: h.holdStart), .holding(side: 0, secondsLeft: 45))
        XCTAssertEqual(h.phase(at: h.holdStart.addingTimeInterval(20)), .holding(side: 0, secondsLeft: 25))
        XCTAssertEqual(h.phase(at: h.holdStart.addingTimeInterval(44.5)), .holding(side: 0, secondsLeft: 1))
    }

    /// Finita è finita: un istante dopo la scadenza non si torna in tenuta.
    func testItIsDoneAtTheDeadlineAndStaysDone() {
        let h = plank(45)
        XCTAssertEqual(h.phase(at: h.endsAt), .done)
        XCTAssertEqual(h.phase(at: h.endsAt.addingTimeInterval(600)), .done)
    }

    /// **Il numero non dipende da quanti battiti sono arrivati.** È la ragione per cui il tempo si
    /// legge dall'orologio: sondando a caso, o saltando venti secondi come farebbe un Mac che si
    /// addormenta, il conto resta quello giusto.
    func testTheCountIsTheSameWhicheverInstantsYouAskAbout() {
        let h = plank(45)
        for tick in stride(from: 0.0, through: 45.0, by: 0.37) {
            guard case .holding(_, let left) = h.phase(at: h.holdStart.addingTimeInterval(tick))
            else {
                XCTAssertEqual(tick, 45.0, accuracy: 0.4, "solo l'ultimo campione può essere finito")
                continue
            }
            XCTAssertEqual(left, max(0, Int(ceil(45 - tick))), "a \(tick) s dall'inizio")
        }
    }

    // MARK: - I due lati

    /// Quaranta secondi di plank laterale sono venti per lato, e il lato cambia a metà.
    func testTheSidePlankSplitsInTwoHalves() {
        let h = sidePlank(40)
        XCTAssertEqual(h.phase(at: h.holdStart), .holding(side: 1, secondsLeft: 40))
        XCTAssertEqual(h.phase(at: h.holdStart.addingTimeInterval(19.5)), .holding(side: 1, secondsLeft: 21))
        // L'istante esatto del cambio non appartiene a nessuno dei due lati: è la finestra per
        // girarsi. Il secondo lato comincia cinque secondi dopo, intero.
        XCTAssertEqual(h.phase(at: h.holdStart.addingTimeInterval(20)), .switching(secondsLeft: 5))
        XCTAssertEqual(h.phase(at: h.holdStart.addingTimeInterval(25)), .holding(side: 2, secondsLeft: 20))
    }

    /// **I cinque secondi per girarsi ci sono, e scendono da soli.**
    ///
    /// Chiesto dal principale il 2026-08-08: *«al cambio lato deve darmi 5 secondi per mettermi in
    /// posizione, senza dover cliccare»*. Nessun gesto compare in questo test perché nessun gesto
    /// esiste: la finestra si apre e si chiude sull'orologio, come tutto il resto qui dentro.
    func testTheSwitchOpensAFiveSecondWindowWithoutAnyGesture() {
        let h = sidePlank(40)
        let cambio = h.holdStart.addingTimeInterval(20)
        XCTAssertEqual(h.switchAt, cambio)
        XCTAssertEqual(h.secondSideStart, cambio.addingTimeInterval(5))
        for (offset, atteso) in [(0.0, 5), (0.5, 5), (1.2, 4), (4.1, 1), (4.99, 1)] {
            XCTAssertEqual(h.phase(at: cambio.addingTimeInterval(offset)), .switching(secondsLeft: atteso),
                           "a \(offset) s dal cambio")
        }
    }

    /// **Il lavoro non si accorcia: si allunga l'orologio.** È la riga che rende la finestra una
    /// cosa buona invece che uno sconto — venti secondi per lato restano venti per lato, e il
    /// polo negativo è la vecchia versione, dove il secondo lato finiva a 40 e i cinque secondi
    /// per girarsi se li mangiava lui.
    func testTheTurnaroundIsNotStolenFromTheSecondSide() {
        let h = sidePlank(40)
        XCTAssertEqual(h.endsAt, h.holdStart.addingTimeInterval(45), "40 di tenuta più 5 per girarsi")
        guard let inizioSecondo = h.secondSideStart else { return XCTFail("nessun secondo lato") }
        XCTAssertEqual(h.phase(at: inizioSecondo), .holding(side: 2, secondsLeft: 20))
        XCTAssertEqual(h.phase(at: inizioSecondo.addingTimeInterval(19.5)), .holding(side: 2, secondsLeft: 1))
        XCTAssertEqual(h.phase(at: inizioSecondo.addingTimeInterval(20)), .done)
    }

    /// Un esercizio senza lati non paga nessuna finestra: la sua tenuta dura quello che dice.
    func testAnExerciseWithoutSidesIsNotLengthened() {
        let h = plank(45)
        XCTAssertEqual(h.endsAt, h.holdStart.addingTimeInterval(45))
        XCTAssertNil(h.secondSideStart)
    }

    /// **Il numero che serve sotto sforzo è quello del lato**, non il totale: quaranta che scende
    /// non dice quando girarsi, e girarsi è la cosa che devi sapere.
    func testTheCurrentSideHasItsOwnCount() {
        let h = sidePlank(40)
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart), 20)
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart.addingTimeInterval(19)), 1)
        // Mentre ti giri il lato in corso è già il secondo, e il secondo è intero: farlo scendere
        // durante il cambio scalerebbe un tempo che non stai tenendo.
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart.addingTimeInterval(20)), 20)
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart.addingTimeInterval(24)), 20)
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart.addingTimeInterval(25)), 20)
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart.addingTimeInterval(44)), 1)
    }

    /// Senza lati, il conto del lato è il conto e basta.
    func testWithoutSidesTheSideCountIsJustTheCount() {
        let h = plank(45)
        XCTAssertEqual(h.secondsLeftOnCurrentSide(at: h.holdStart.addingTimeInterval(10)), 35)
    }

    // MARK: - I suoni

    /// Ogni suono esce **una volta sola** se si chiede battito per battito, che è come lo usa la
    /// vista. È l'invariante che tiene: un suono ripetuto a ogni decimo di secondo è un difetto
    /// che non si vede in nessuna schermata.
    func testEachCueFiresExactlyOnceOverTheWholeRun() {
        let h = sidePlank(40)
        var counts: [Hold.Cue: Int] = [:]
        var previous = h.startedAt
        for step in stride(from: 0.1, through: 60.0, by: 0.1) {
            let now = h.startedAt.addingTimeInterval(step)
            for cue in h.cues(from: previous, to: now) { counts[cue, default: 0] += 1 }
            previous = now
        }
        for cue in Hold.Cue.allCases {
            XCTAssertEqual(counts[cue], 1, "\(cue.rawValue) doveva suonare una volta sola")
        }
    }

    /// L'ordine è quello della vita: via, avviso, fermati e girati, riparti, fine.
    func testTheCuesComeInTheOrderYouLiveThem() {
        let h = sidePlank(40)
        let all = h.cues(from: h.startedAt.addingTimeInterval(-1),
                         to: h.endsAt.addingTimeInterval(1))
        XCTAssertEqual(all, [.start, .switchWarning, .switchSide, .secondSideStart, .end])
    }

    /// **Il «riparti» arriva cinque secondi dopo il «fermati», non insieme.** È l'unica cosa che
    /// senti mentre sei girato dall'altra parte e lo schermo non lo guardi.
    func testTheSecondSideIsAnnouncedWhenItActuallyStarts() {
        let h = sidePlank(40)
        guard let cambio = h.switchAt, let via = h.secondSideStart else { return XCTFail("nessun cambio") }
        XCTAssertEqual(h.cues(from: cambio.addingTimeInterval(-0.1), to: cambio), [.switchSide])
        XCTAssertTrue(h.cues(from: cambio, to: via.addingTimeInterval(-0.1)).isEmpty,
                      "mentre ti giri non deve suonare niente")
        XCTAssertEqual(h.cues(from: via.addingTimeInterval(-0.1), to: via), [.secondSideStart])
    }

    /// **L'avviso arriva prima del cambio, non insieme.** Tre secondi, perché in plank non guardi
    /// lo schermo e il tempo di girarti fa parte dell'avviso.
    func testTheSwitchIsAnnouncedThreeSecondsAhead() {
        let h = sidePlank(40)
        let avviso = h.holdStart.addingTimeInterval(20 - Hold.switchWarningSeconds)
        XCTAssertEqual(h.cues(from: avviso.addingTimeInterval(-0.1), to: avviso), [.switchWarning])
        XCTAssertTrue(h.cues(from: avviso, to: avviso.addingTimeInterval(2.9)).isEmpty,
                      "fra l'avviso e il cambio non deve suonare altro")
    }

    /// Un esercizio senza lati non annuncia nessun cambio, perché non ce n'è uno.
    func testAnExerciseWithoutSidesHasNoSwitchCues() {
        let h = plank(45)
        let all = h.cues(from: h.startedAt.addingTimeInterval(-1), to: h.endsAt.addingTimeInterval(1))
        XCTAssertEqual(all, [.start, .end])
        XCTAssertNil(h.switchAt)
    }

    /// **Il polo negativo.** Se `cues` rispondesse sull'intervallo chiuso a sinistra, chiamandola
    /// due volte di fila sullo stesso istante il suono uscirebbe due volte. Qui non esce.
    func testAskingTwiceAboutTheSameInstantDoesNotRepeatTheSound() {
        let h = plank(45)
        let a = h.holdStart.addingTimeInterval(-0.05)
        let b = h.holdStart.addingTimeInterval(0.05)
        XCTAssertEqual(h.cues(from: a, to: b), [.start])
        XCTAssertTrue(h.cues(from: b, to: b.addingTimeInterval(0.1)).isEmpty)
    }

    /// Una tenuta di durata assurda non produce una fase assurda: il minimo è un secondo.
    func testAZeroLengthHoldIsClampedInsteadOfBreaking() {
        let h = Hold(total: 0, perSide: false, startedAt: t0)
        XCTAssertEqual(h.total, 1)
        XCTAssertEqual(h.phase(at: h.holdStart), .holding(side: 0, secondsLeft: 1))
    }
}
