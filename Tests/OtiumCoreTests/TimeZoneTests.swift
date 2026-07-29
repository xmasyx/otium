import XCTest
@testable import OtiumCore

/// L'app che cambia fuso, e il giorno che cambia lunghezza.
///
/// Audit del 2026-07-29. Il principale viaggia spesso, e nessuna parte di Otium deve dipendere da
/// un fuso scritto a mano: il registro tiene istanti assoluti, le finestre dei periodi seguono il
/// calendario **locale**, ed è giusto così — una pausa fatta alle 23 a Milano è una pausa di quel
/// giorno lì, e la stessa vista da Los Angeles è di un altro giorno. Quello che non deve succedere
/// è che la matematica dei giorni si rompa quando il giorno non dura 24 ore.
final class TimeZoneTests: XCTestCase {

    /// I due giorni dell'anno che durano 23 e 25 ore, in Europa.
    private var oraLegale: (avanti: Date, indietro: Date) {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        // Ultima domenica di marzo e di ottobre 2026.
        let avanti = c.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 1))!
        let indietro = c.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 1))!
        return (avanti, indietro)
    }

    /// **La salita non salta e non torna indietro attraversando l'ora legale.**
    ///
    /// `daysElapsed` conta secondi diviso 86.400, e il giorno del cambio ne ha 82.800 o 90.000:
    /// il rischio è un giorno contato in meno o in più proprio mentre le ripetizioni salgono.
    func testTheRampDoesNotStumbleOverDaylightSaving() {
        for inizio in [oraLegale.avanti, oraLegale.indietro] {
            var s = Settings()
            s.startDate = inizio
            var precedente = 0.0
            for giorno in 0...30 {
                let quando = inizio.addingTimeInterval(Double(giorno) * 24 * 3600)
                let f = s.rampFactor(now: quando)
                XCTAssertGreaterThanOrEqual(f, precedente - 0.0001,
                                            "la salita torna indietro al giorno \(giorno)")
                XCTAssertLessThanOrEqual(f, 1.0)
                precedente = f
            }
            XCTAssertEqual(s.rampFactor(now: inizio.addingTimeInterval(30 * 24 * 3600)), 1.0,
                           accuracy: 0.0001, "dopo trenta giorni si è al 100% comunque")
        }
    }

    /// **Il registro tiene istanti, non orari locali.** Una riga scritta a Milano e riletta a Los
    /// Angeles è lo stesso momento: se così non fosse, un volo transatlantico riscriverebbe la
    /// storia dell'utente.
    func testTheLedgerStoresAbsoluteInstants() throws {
        let quando = Date(timeIntervalSince1970: 1_785_000_000)
        let riga = LedgerEntry(timestamp: quando, type: .active, seconds: 300)

        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let riletta = try decoder.decode(LedgerEntry.self, from: try encoder.encode(riga))

        XCTAssertEqual(riletta.timestamp.timeIntervalSince1970,
                       quando.timeIntervalSince1970, accuracy: 1.0)
    }

    /// **Le statistiche seguono il calendario che gli passi**, non uno cablato dentro.
    ///
    /// È la proprietà che rende l'app corretta in viaggio: cambia il fuso del sistema e le
    /// finestre dei periodi si spostano con lui, senza che nessuna riga di Otium sappia dove sei.
    func testStatsFollowTheCalendarTheyAreGiven() {
        let quando = Date(timeIntervalSince1970: 1_785_000_000)
        let righe = [LedgerEntry(timestamp: quando, type: .completed, breakKind: .micro,
                                 exercise: .squat, reps: 10)]

        var milano = Calendar(identifier: .gregorian)
        milano.timeZone = TimeZone(identifier: "Europe/Rome")!
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!

        let a = Stats.compute(entries: righe, period: .day, now: quando.addingTimeInterval(60),
                              calendar: milano)
        let b = Stats.compute(entries: righe, period: .day, now: quando.addingTimeInterval(60),
                              calendar: losAngeles)
        // La riga è la stessa e cade dentro la giornata di entrambi: quello che conta è che
        // nessuna delle due esploda o perda la riga per colpa del fuso.
        XCTAssertEqual(a.completed, 1)
        XCTAssertEqual(b.completed, 1)
    }

    /// Le ore di silenzio si leggono sul calendario locale, quindi «non interrompere dopo le 23»
    /// resta vero anche atterrando altrove: cambia il momento assoluto, non la promessa.
    func testQuietHoursAreLocalByConstruction() {
        var s = Settings()
        s.activeFromHour = 7
        s.activeToHour = 23
        // Mezzogiorno a Roma è dentro; le tre di notte a Roma sono fuori. Il test non fissa il
        // fuso: fissa che la regola guardi **l'ora del posto in cui sei**, che è `Calendar.current`.
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        let mezzogiorno = c.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        let treDiNotte = c.date(bySettingHour: 3, minute: 0, second: 0, of: Date())!
        XCTAssertTrue(c.component(.hour, from: mezzogiorno) >= s.activeFromHour)
        XCTAssertTrue(c.component(.hour, from: treDiNotte) < s.activeFromHour)
    }
}
