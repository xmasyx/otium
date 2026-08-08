import XCTest
@testable import OtiumCore

/// I gradini del conto alla rovescia nella barra dei menu.
final class CountdownTests: XCTestCase {

    private func passo(_ r: Double, _ preavviso: Double = 60) -> Int {
        Countdown.step(remaining: r, warningSeconds: preavviso)
    }

    /// La sequenza chiesta, letta come la legge lui: 60s, 30s, poi gli ultimi cinque.
    func testTheLadderIsSixtyThirtyThenTheLastFive() {
        XCTAssertEqual(passo(60), 60)
        XCTAssertEqual(passo(31), 60, "finché non tocca 30, il gradino resta 60")
        XCTAssertEqual(passo(30), 30)
        XCTAssertEqual(passo(6), 30, "il gradino dei 30 regge fino al quinto secondo")
        XCTAssertEqual(passo(5), 5)
        XCTAssertEqual(passo(4), 4)
        XCTAssertEqual(passo(3), 3)
        XCTAssertEqual(passo(2), 2)
        XCTAssertEqual(passo(1), 1)
        XCTAssertEqual(passo(0.4), 0, "sotto il mezzo secondo la pausa è già qui")
    }

    /// **Il polo negativo, ed è il motivo per cui questa scala esiste.** Il conto vecchio scriveva
    /// il secondo esatto: se un giorno tornasse, questo test diventa rosso.
    func testItIsNotTheRawSecondCount() {
        for r in [59, 47, 31, 29, 12, 6] {
            XCTAssertNotEqual(passo(Double(r)), r, "\(r)s non è un gradino, non deve comparire")
        }
        XCTAssertEqual(Set((1...60).map { passo(Double($0)) }), Set(Countdown.steps),
                       "in tutto il preavviso si vedono sette numeri, non sessanta")
    }

    /// Claim universale: il gradino non anticipa mai l'allarme, e scendendo non risale.
    func testItNeverUnderstatesAndNeverGoesBackUp() {
        var precedente = Int.max
        for decimi in stride(from: 600, through: 0, by: -1) {
            let r = Double(decimi) / 10
            let g = passo(r)
            XCTAssertGreaterThanOrEqual(Double(g), r - 0.5,
                                        "a \(r)s il gradino \(g) suonerebbe l'allarme in anticipo")
            XCTAssertLessThanOrEqual(g, precedente, "a \(r)s il conto è risalito da \(precedente) a \(g)")
            precedente = g
        }
    }

    /// Il preavviso è un campo in secondi delle impostazioni: la scala si taglia su quello, e il
    /// primo numero che si legge è sempre quello vero.
    func testTheLadderAdaptsToAShorterWarning() {
        XCTAssertEqual(passo(8, 8), 8, "con otto secondi di preavviso non si scrive 60")
        XCTAssertEqual(passo(6, 8), 8)
        XCTAssertEqual(passo(5, 8), 5)
        XCTAssertEqual(passo(45, 45), 45)
        XCTAssertEqual(passo(31, 45), 45)
        XCTAssertEqual(passo(30, 45), 30)
    }

    /// E su un preavviso più lungo del minuto i gradini restano quelli, con la partenza in testa.
    func testALongerWarningKeepsTheSameSteps() {
        XCTAssertEqual(passo(120, 120), 120)
        XCTAssertEqual(passo(61, 120), 120)
        XCTAssertEqual(passo(60, 120), 60)
        XCTAssertEqual(passo(31, 120), 60)
    }
}
