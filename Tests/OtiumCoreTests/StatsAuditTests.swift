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

    /// **La serie di giorni deve usare la stessa definizione di «pausa» del resto dell'app.**
    ///
    /// L'app dichiara che le interruzioni sono `completed + natural`: alzarsi da soli conta, ed
    /// è scritto in `interruptions`. La serie però guardava solo le `completed`, quindi un giorno
    /// passato ad alzarsi spontaneamente spezzava la serie — cioè l'app puniva esattamente il
    /// comportamento che dice di voler premiare.
    func testStreakUsesTheSameDefinitionOfBreakAsTheRestOfTheApp() {
        let cal = Calendar.current
        let oggi = cal.startOfDay(for: Date()).addingTimeInterval(10 * 3600)
        let ieri = cal.date(byAdding: .day, value: -1, to: oggi)!
        let righe = [
            LedgerEntry(timestamp: ieri, type: .completed, breakKind: .micro, exercise: .squat),
            LedgerEntry(timestamp: oggi, type: .natural, breakKind: .micro, seconds: 200),
        ]
        let s = Stats.compute(entries: righe, period: .week, now: oggi.addingTimeInterval(3600))
        XCTAssertEqual(s.streakDays, 2,
                       "ieri una pausa fatta, oggi una naturale: la serie è di due giorni")
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
