import XCTest
@testable import OtiumCore

/// Le alternative sotto l'esercizio della pausa: quante righe, e chi va dove.
///
/// La domanda vera non è «con sette esce 4+3?» — quella è una: è **«esiste un numero di
/// alternative che esce storto?»**. Il corpus le decide esercizio per esercizio (sette per il
/// push-up, quattro per lo squat, tre per il muro) e cresce a ogni versione, quindi il test gira
/// su tutti i conteggi possibili invece che sui tre che ho guardato oggi.
final class VariantLayoutTests: XCTestCase {

    /// Ogni conteggio, da zero a venti: mai più di due righe, mai una riga vuota, e nessuna
    /// alternativa persa o duplicata per strada.
    func testEveryCountSplitsIntoAtMostTwoNonEmptyRowsKeepingOrder() {
        for n in 0...20 {
            let items = Array(0..<n)
            let rows = VariantLayout.rows(items)
            XCTAssertLessThanOrEqual(rows.count, 2, "\(n) alternative: mai più di due righe")
            XCTAssertFalse(rows.contains(where: \.isEmpty), "\(n) alternative: nessuna riga vuota")
            XCTAssertEqual(rows.flatMap { $0 }, items,
                           "\(n) alternative: stesso contenuto, stesso ordine")
        }
    }

    /// Fino al limite resta una fila sola. Il limite è **quattro** dal 2026-08-04, perché quattro
    /// spezzato 2+2 si legge come una griglia e non come una scelta.
    func testUpToTheLimitTheyStayOnASingleRow() {
        XCTAssertEqual(VariantLayout.rows([Int]()).count, 0)
        for n in 1...VariantLayout.singleRowLimit {
            XCTAssertEqual(VariantLayout.rows(Array(0..<n)).count, 1, "\(n) alternative: una riga")
        }
    }

    /// Oltre il limite sono **due righe bilanciate**: si differiscono al massimo di uno, e il
    /// dispari va di sopra. È la differenza fra due righe e una riga con un avanzo appeso.
    func testAboveTheLimitTheySplitIntoTwoBalancedRowsWithTheOddOneOnTop() {
        for n in (VariantLayout.singleRowLimit + 1)...20 {
            let rows = VariantLayout.rows(Array(0..<n))
            XCTAssertEqual(rows.count, 2, "\(n) alternative: due righe")
            let sopra = rows[0].count, sotto = rows[1].count
            XCTAssertLessThanOrEqual(sopra - sotto, 1, "\(n): la riga di sopra sfora")
            XCTAssertGreaterThanOrEqual(sopra, sotto, "\(n): il dispari va di sopra")
            XCTAssertLessThanOrEqual(abs(sopra - sotto), 1, "\(n): righe sbilanciate")
        }
    }

    /// **Il polo che rende verde il test una prova.** Il caso vivo che ha aperto la richiesta —
    /// le sette alternative del push-up — prima usciva in una fila da sette. Se questo passasse
    /// anche col vecchio comportamento, il resto del file non direbbe niente.
    func testThePushUpRowThatCausedTheComplaintIsNoLongerSevenWide() {
        let alternative = ExerciseKind.pushUp.variants
        XCTAssertEqual(alternative.count, 7, "il caso vivo: il push-up ne offre sette")
        let rows = VariantLayout.rows(alternative)
        XCTAssertEqual(rows.map(\.count), [4, 3])
        XCTAssertFalse(rows.contains { $0.count == alternative.count },
                       "nessuna riga porta ancora tutte e sette")
    }

    /// Il caso che l'ha fatto cambiare, ancorato al numero e non al limite: **quattro
    /// alternative stanno in fila**. Scritto con il 4 letterale di proposito — un test che dice
    /// `singleRowLimit` si adegua da solo a qualunque valore, e allora non prova niente.
    func testFourVariantsStayOnOneRow() {
        XCTAssertEqual(VariantLayout.rows(Array(0..<4)).count, 1)
        XCTAssertEqual(VariantLayout.rows(Array(0..<4)).first?.count, 4)
    }

    /// Il polo opposto: le sette del push-up restano su due righe, 4+3.
    func testSevenVariantsStillSplit() {
        let rows = VariantLayout.rows(Array(0..<7))
        XCTAssertEqual(rows.map(\.count), [4, 3])
    }

}
