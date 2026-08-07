import XCTest
@testable import OtiumCore

/// I numeri mostrati contro le righe del registro, calcolati a mano.
///
/// Audit del 2026-07-28. La domanda non è «il codice fa quello che dice il codice» — quello lo
/// dicono già gli altri test — ma «i numeri a schermo raccontano il registro, o raccontano se
/// stessi».
final class StatsAuditTests: XCTestCase {

    private let giorno = Date(timeIntervalSince1970: 1_785_000_000)   // un giorno qualunque, fisso

    private func at(_ minuti: Int) -> Date { giorno.addingTimeInterval(Double(minuti) * 60) }

    /// **Le ripetizioni non si contano due volte.**
    ///
    /// Una pausa vera lascia due righe, la conferma dell'esercizio e la chiusura della pausa.
    /// Se entrambe portassero le ripetizioni, ogni squat varrebbe due squat.
    func testRepsAreNotCountedTwiceForOneBreak() {
        let righe = [
            LedgerEntry(timestamp: at(0), type: .exerciseDone, exercise: .squat, reps: 10),
            LedgerEntry(timestamp: at(1), type: .completed, breakKind: .micro, exercise: .squat),
        ]
        let s = Stats.compute(entries: righe, period: .day, now: at(10), from: at(-1))
        XCTAssertEqual(s.totalReps, 10, "dieci squat fatti, dieci contati")
        XCTAssertEqual(s.completed, 1, "e una pausa sola")
    }

    /// Una pausa **dichiarata a mano** porta le sue ripetizioni sulla riga di chiusura, perché
    /// non ha una riga di conferma: quelle vanno contate, o il lavoro dichiarato sparisce.
    func testDeclaredBreakCarriesItsOwnReps() {
        let righe = [
            LedgerEntry(timestamp: at(0), type: .completed, breakKind: .micro,
                        exercise: .squat, reps: 12, reason: "dichiarata"),
        ]
        let s = Stats.compute(entries: righe, period: .day, now: at(10), from: at(-1))
        XCTAssertEqual(s.totalReps, 12)
        XCTAssertEqual(s.completed, 1)
    }

    /// **Togliere una pausa segnata deve togliere anche le sue ripetizioni.**
    ///
    /// Il difetto trovato dall'audit: `undo` toglieva la pausa dal conto e dalla cronologia, ma
    /// le ripetizioni restavano. Il totale del giorno continuava a includere il lavoro di una
    /// pausa che l'utente aveva appena dichiarato mai avvenuta.
    func testUndoAlsoRemovesTheRepsItHadAdded() {
        let righe = [
            LedgerEntry(timestamp: at(0), type: .completed, breakKind: .micro,
                        exercise: .burpee, reps: 8, reason: "dichiarata"),
            LedgerEntry(timestamp: at(1), type: .undo, breakKind: .micro, reason: "tolta a mano"),
        ]
        let s = Stats.compute(entries: righe, period: .day, now: at(10), from: at(-1))
        XCTAssertEqual(s.completed, 0, "la pausa è stata tolta")
        XCTAssertEqual(s.totalReps, 0, "e con lei le sue ripetizioni")
        XCTAssertEqual(s.vigorousBouts, 0, "e la sessione intensa che si portava dietro")
    }

    /// Un calendario **fisso**, con la settimana che comincia di lunedì come in Italia.
    ///
    /// I test qui sotto parlano di giorni consecutivi e di confini di settimana: con
    /// `Calendar.current` e `Date()` misurerebbero anche il giorno in cui girano, ed è
    /// esattamente com'è nato il difetto qui sotto — un test rosso il lunedì e verde negli altri
    /// sei giorni, che per mesi è sembrato rumore.
    private var calendarioFisso: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Rome")!
        cal.firstWeekday = 2
        return cal
    }

    /// Le 10:00 di un giorno preciso, in quel calendario.
    private func giorno(_ anno: Int, _ mese: Int, _ giorno: Int, ora: Int = 10) -> Date {
        calendarioFisso.date(from: DateComponents(year: anno, month: mese, day: giorno, hour: ora))!
    }

    /// **La serie di giorni deve usare la stessa definizione di «pausa» del resto dell'app.**
    ///
    /// L'app dichiara che le interruzioni sono `completed + natural`: alzarsi da soli conta, ed
    /// è scritto in `interruptions`. La serie però guardava solo le `completed`, quindi un giorno
    /// passato ad alzarsi spontaneamente spezzava la serie — cioè l'app puniva esattamente il
    /// comportamento che dice di voler premiare.
    ///
    /// **Il lunedì è la data apposta**: lunedì 3 agosto 2026, con la pausa di ieri che cade nella
    /// settimana precedente. È il giorno in cui questo test era rosso.
    func testStreakUsesTheSameDefinitionOfBreakAsTheRestOfTheApp() {
        let lunedi = giorno(2026, 8, 3)
        let domenica = giorno(2026, 8, 2)
        let righe = [
            LedgerEntry(timestamp: domenica, type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: lunedi, type: .natural, breakKind: .micro, seconds: 200),
        ]
        let s = Stats.compute(entries: righe, period: .week,
                              now: lunedi.addingTimeInterval(3600), calendar: calendarioFisso)
        XCTAssertEqual(s.streakDays, 2,
                       "ieri una pausa fatta, oggi una naturale: la serie è di due giorni")
    }

    /// **La serie non è una proprietà della finestra che stai guardando.**
    ///
    /// Il difetto che il test qui sopra rendeva visibile un giorno su sette: `streakDays` si
    /// leggeva sui soli `moments`, cioè su ciò che il periodo aveva già filtrato. Con «Oggi»
    /// davanti la serie non poteva superare **1** per costruzione — e la medaglia «giorni di
    /// fila» compare solo sopra 1, quindi su quella scheda non è mai comparsa. Con «Settimana»
    /// si accorciava al confine del lunedì: trenta giorni di fila letti come uno.
    func testStreakIgnoresTheSelectedPeriodBecauseItIsAPropertyOfHistory() {
        let righe = [
            LedgerEntry(timestamp: giorno(2026, 8, 1), type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: giorno(2026, 8, 2), type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: giorno(2026, 8, 3), type: .completed, breakKind: .micro, exercise: .squat),
        ]
        let oggi = giorno(2026, 8, 3, ora: 18)
        for periodo in [StatsPeriod.day, .week, .month] {
            let s = Stats.compute(entries: righe, period: periodo, now: oggi, calendar: calendarioFisso)
            XCTAssertEqual(s.streakDays, 3,
                           "tre giorni di fila restano tre anche guardando il periodo «\(periodo.rawValue)»")
        }
    }

    /// Il polo negativo: un buco spezza davvero la serie, o il numero direbbe sempre di sì.
    func testAGapBreaksTheStreak() {
        let righe = [
            LedgerEntry(timestamp: giorno(2026, 8, 1), type: .completed, breakKind: .micro, exercise: .squat),
            // 2 agosto: niente.
            LedgerEntry(timestamp: giorno(2026, 8, 3), type: .completed, breakKind: .micro, exercise: .squat),
        ]
        let s = Stats.compute(entries: righe, period: .month,
                              now: giorno(2026, 8, 3, ora: 18), calendar: calendarioFisso)
        XCTAssertEqual(s.streakDays, 1, "fra le due c'è un giorno vuoto: la serie riparte da oggi")
    }

    /// Una pausa dichiarata e poi **tolta** non tiene in piedi la sua giornata.
    ///
    /// È la stessa regola che vale per i conti e per le ripetizioni: correggere all'ingiù è metà
    /// del motivo per cui l'`undo` esiste. Leggendo la serie dal registro grezzo invece che dai
    /// `moments` questa regola andava riscritta a mano — senza, una pausa cancellata avrebbe
    /// continuato a puntellare la serie.
    func testAnUndoneBreakDoesNotHoldUpItsDay() {
        let righe = [
            LedgerEntry(timestamp: giorno(2026, 8, 2), type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: giorno(2026, 8, 3, ora: 9), type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: giorno(2026, 8, 3, ora: 11), type: .undo, breakKind: .micro, reason: "tolta a mano"),
        ]
        let s = Stats.compute(entries: righe, period: .month,
                              now: giorno(2026, 8, 3, ora: 18), calendar: calendarioFisso)
        XCTAssertEqual(s.streakDays, 0, "l'unica pausa di oggi è stata tolta: oggi non conta")
    }

    /// La finestra del periodo esclude ciò che sta fuori, e include gli estremi.
    func testTheWindowIncludesItsEdgesAndExcludesTheRest() {
        let righe = [
            LedgerEntry(timestamp: at(-5), type: .active, seconds: 100),   // fuori, prima
            LedgerEntry(timestamp: at(0), type: .active, seconds: 200),    // dentro, sul bordo
            LedgerEntry(timestamp: at(10), type: .active, seconds: 300),   // dentro, sul bordo
            LedgerEntry(timestamp: at(20), type: .active, seconds: 400),   // fuori, dopo
        ]
        let s = Stats.compute(entries: righe, period: .day, now: at(10), from: at(0))
        XCTAssertEqual(s.activeSeconds, 500, accuracy: 0.001)
    }

    /// Le correzioni negative abbassano il totale, ma il totale non va sotto zero: un numero
    /// negativo di minuti davanti al Mac non significa niente.
    func testCorrectionsNeverPushTheTotalBelowZero() {
        let righe = [
            LedgerEntry(timestamp: at(0), type: .active, seconds: 600),
            LedgerEntry(timestamp: at(1), type: .active, seconds: -3000, reason: "correzione"),
        ]
        let s = Stats.compute(entries: righe, period: .day, now: at(10), from: at(-1))
        XCTAssertGreaterThanOrEqual(s.activeSeconds, 0,
                                    "meno di zero minuti davanti al Mac non vuol dire niente")
    }

    /// Le sessioni intense si contano una volta per esercizio vigoroso, non una per riga.
    func testVigorousBoutsCountOncePerExercise() {
        let righe = [
            LedgerEntry(timestamp: at(0), type: .exerciseDone, exercise: .burpee, reps: 5),
            LedgerEntry(timestamp: at(1), type: .completed, breakKind: .long, exercise: .burpee),
            LedgerEntry(timestamp: at(30), type: .exerciseDone, exercise: .jumpingJack, reps: 20),
            LedgerEntry(timestamp: at(31), type: .completed, breakKind: .long, exercise: .jumpingJack),
        ]
        let s = Stats.compute(entries: righe, period: .day, now: at(40), from: at(-1))
        XCTAssertEqual(s.vigorousBouts, 2, "due esercizi vigorosi, due sessioni")
    }
}
