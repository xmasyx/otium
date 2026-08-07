import XCTest
@testable import OtiumCore

/// La pagina della crescita legge il registro, quindi qui si prova che lo legge **bene**: che non
/// conta quello che non è stato fatto, che l'ordine è il tempo, e che i giorni sono giorni veri.
final class GrowthTests: XCTestCase {

    private let giorno: TimeInterval = 24 * 3600

    private func quando(_ giorniFa: Int, ora: Int = 10) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 4 - giorniFa; c.hour = ora
        return Calendar.current.date(from: c)!
    }

    private func fatto(_ kind: ExerciseKind, _ reps: Int, _ giorniFa: Int, ora: Int = 10) -> LedgerEntry {
        LedgerEntry(timestamp: quando(giorniFa, ora: ora), type: .exerciseDone,
                    exercise: kind, reps: reps)
    }

    /// Mette una chiusura di pausa fra una conferma e l'altra. Senza, due conferme di fila
    /// stanno nella stessa pausa, e una pausa con due conferme **è** un circuito: il test
    /// misurerebbe il ramo sbagliato senza dirlo.
    private func intervallate(_ entries: [LedgerEntry]) -> [LedgerEntry] {
        var out: [LedgerEntry] = []
        for e in entries {
            out.append(e)
            out.append(LedgerEntry(timestamp: e.timestamp.addingTimeInterval(30),
                                   type: .completed, breakKind: .micro))
        }
        return out
    }

    func testOnlyConfirmedExercisesCount() {
        let entries = [
            fatto(.squat, 10, 2),
            // Rumore che NON deve entrare: una pausa saltata, una completata senza conferma,
            // e il tempo attivo. Sono i tre eventi più frequenti del registro.
            LedgerEntry(timestamp: quando(2), type: .skipped, exercise: .squat, reps: 99),
            LedgerEntry(timestamp: quando(2), type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: quando(2), type: .active, seconds: 600),
        ]
        let report = Growth.report(entries: entries, book: ProgressBook())
        XCTAssertEqual(report.lines.count, 1)
        XCTAssertEqual(report.totalReps, 10, "99 ripetizioni saltate non sono ripetizioni fatte")
        XCTAssertEqual(report.sessions, 1)
    }

    func testSessionsKeepTimeOrderEvenIfTheLedgerDoesNot() {
        // Il registro è append-only e in ordine, ma la lettura non deve **dipendere** da questo:
        // un file ricostruito a mano, o due processi, e l'ordine salta.
        let entries = [fatto(.pushUp, 11, 0), fatto(.pushUp, 8, 4), fatto(.pushUp, 9, 2)]
        let line = Growth.report(entries: entries, book: ProgressBook()).lines.first!
        XCTAssertEqual(line.sessions, [8, 9, 11])
        XCTAssertEqual(line.firstReps, 8)
        XCTAssertEqual(line.lastReps, 11)
        XCTAssertEqual(line.bestReps, 11)
        XCTAssertEqual(line.totalReps, 28)
    }

    /// **Una stazione di circuito non è un calo.**
    ///
    /// Il caso vero, e la domanda del principale che l'ha trovato: *«perché l'archer è sceso? io
    /// ho sempre completato»*. Non era sceso. Nel suo registro l'archer valeva 6 da solo e 4 come
    /// stazione di un circuito, dove il volume è distribuito su quattro esercizi: la pagina
    /// metteva i due numeri nella stessa fila e leggeva un calo del 33% dove c'era una giornata
    /// con quattro esercizi invece di uno.
    func testCircuitStationsAreNotADecline() {
        // Pausa 1: archer da solo, 6. Pausa 2: circuito di quattro stazioni, archer a 4.
        var entries = [fatto(.archerPushUp, 6, 3)]
        entries.append(LedgerEntry(timestamp: quando(3).addingTimeInterval(60),
                                   type: .completed, breakKind: .micro))
        for (i, k) in [ExerciseKind.gluteBridge, .archerPushUp, .crunch, .jumpSquat].enumerated() {
            entries.append(fatto(k, k == .archerPushUp ? 4 : 10, 1, ora: 10 + i))
        }
        entries.append(LedgerEntry(timestamp: quando(1, ora: 14), type: .completed,
                                   breakKind: .micro, reason: "circuito"))

        let line = Growth.report(entries: entries, book: ProgressBook())
            .lines.first { $0.kind == .archerPushUp }!
        XCTAssertEqual(line.all.count, 2, "il lavoro fatto si vede tutto")
        XCTAssertEqual(line.singles.map(\.reps), [6], "ma solo il singolo è confrontabile")
        XCTAssertEqual(line.totalReps, 10, "e il volume totale resta quello vero")
        // La misura usa il singolo, quindi non c'è nessun calo da dichiarare.
        XCTAssertEqual(line.percentOfBase,
                       Int((6.0 / Double(line.baseReps) * 100).rounded()))
    }

    /// **Cresciuto non vuol dire «il moltiplicatore dice 105%».**
    ///
    /// L'altra metà dello stesso difetto: il polpaccio aveva la pastiglia «105%» accanto a
    /// `15 → 15`. Il moltiplicatore si applica alle ripetizioni di base, che cambiano da sole con
    /// la rampa e con le varianti, quindi non è la misura di dove sei.
    func testTheMultiplierIsNotTheMeasure() {
        let pieno = Ramp.reps(for: .calfRaise, factor: 1.0, sex: nil)
        let entries = intervallate([fatto(.calfRaise, pieno, 3), fatto(.calfRaise, pieno, 1)])
        let book = ProgressBook(byExercise: [ExerciseKind.calfRaise.rawValue: ExerciseProgress(level: 1.05)])
        let line = Growth.report(entries: entries, book: book).lines.first!
        XCTAssertEqual(line.levelPercent, 105, "il moltiplicatore resta leggibile")
        XCTAssertEqual(line.percentOfBase, 100, "ma la pagina dice dove sei: al pieno")
        XCTAssertFalse(line.grown, "e al pieno non sei cresciuto oltre il pieno")
    }

    /// I giorni sono i giorni in cui hai fatto qualcosa, non il calendario fra il primo e
    /// l'ultimo: contare quelli vuoti abbasserebbe la media e racconterebbe una storia più brutta
    /// di quella vera.
    func testActiveDaysCountsOnlyDaysWithAConfirmation() {
        let entries = [
            fatto(.squat, 10, 6),
            fatto(.squat, 11, 0, ora: 9),
            fatto(.crunch, 12, 0, ora: 18),   // stesso giorno del precedente
        ]
        let report = Growth.report(entries: entries, book: ProgressBook())
        XCTAssertEqual(report.activeDays, 2, "sei giorni di distanza, due giorni di lavoro")
        XCTAssertEqual(report.sessions, 3)
    }

    /// **Il pieno è lo zero, non la prima conferma.**
    ///
    /// Correzione del principale, 2026-08-04: *«il 100% di partenza per i push-up era 8, quindi se
    /// adesso ne faccio 8 sono a livello base, non ho un incremento»*. Misurare dalla prima volta
    /// premiava chi era partito dentro la rampa: tornare al pieno si leggeva come un progresso.
    func testFullPrescriptionIsTheZeroNotTheFirstConfirmation() {
        let pieno = Ramp.reps(for: .pushUp, factor: 1.0, sex: nil)
        // Prima conferma a metà (rampa), ultima esattamente al pieno.
        let entries = [fatto(.pushUp, max(1, pieno / 2), 3), fatto(.pushUp, pieno, 0)]
        // Chiude ogni pausa, o due conferme di fila sembrerebbero un circuito.
        let conChiusure = intervallate(entries)
        let line = Growth.report(entries: conChiusure, book: ProgressBook()).lines.first!
        XCTAssertEqual(line.baseReps, pieno)
        XCTAssertEqual(line.percentOfBase, 100, "al pieno si è al 100%, non «migliorato»")
        XCTAssertEqual(line.overFullPercent, 0)
        XCTAssertFalse(line.grown, "essere al pieno non è crescere oltre il pieno")
    }

    /// Sopra il pieno la riga lo dice, e il numero è quello vero.
    func testAboveFullIsReportedAsAboveFull() {
        let pieno = Ramp.reps(for: .squat, factor: 1.0, sex: nil)
        let entries = intervallate([fatto(.squat, pieno, 3), fatto(.squat, pieno * 2, 0)])
        let line = Growth.report(entries: entries, book: ProgressBook()).lines.first!
        XCTAssertEqual(line.percentOfBase, 200)
        XCTAssertEqual(line.overFullPercent, 100)
        XCTAssertTrue(line.grown)
    }

    func testAnEmptyLedgerProducesAnEmptyReport() {
        let report = Growth.report(entries: [], book: ProgressBook())
        XCTAssertTrue(report.lines.isEmpty)
        XCTAssertEqual(report.totalReps, 0)
        XCTAssertEqual(report.activeDays, 0)
        XCTAssertNil(report.firstDay)
        XCTAssertEqual(report.grownCount, 0)
    }

    /// Una conferma con zero ripetizioni non è una conferma: se entrasse, `firstReps` potrebbe
    /// valere 0 e `deltaPercent` dividerebbe per zero.
    func testZeroRepEntriesAreIgnored() {
        let entries = [fatto(.squat, 0, 2), fatto(.squat, 10, 1)]
        let line = Growth.report(entries: intervallate(entries), book: ProgressBook()).lines.first!
        XCTAssertEqual(line.sessions, [10])
    }
}
