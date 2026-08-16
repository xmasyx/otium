import XCTest
@testable import OtiumCore

/// Il volume dei suoni, chiesto il 2026-08-16: *«il livello di volume della notifica, che non
/// dipenda unicamente dal volume generale del Mac»*.
///
/// Qui si prova quello che è provabile senza schede audio: il **limite** del campo e la
/// **decodifica** di un file scritto prima che l'impostazione esistesse. Che il suono esca davvero
/// più piano lo dicono le orecchie, e nessun test può prenderne il posto.
final class SoundVolumeTests: XCTestCase {

    func testDefaultIsFullVolume() {
        XCTAssertEqual(Settings().soundVolume, 1.0,
                       "chi non ha mai toccato la manopola deve sentire quello che sentiva prima")
    }

    /// Il limite vive in **un posto solo** e i tre chiamanti lo importano. Se un giorno qualcuno se
    /// ne ricopiasse una versione sua, questo test resterebbe verde e la copia divergerebbe in
    /// silenzio: per questo il test chiama la stessa funzione del codice di produzione.
    func testVolumeIsClamped() {
        XCTAssertEqual(Settings.clampSoundVolume(-3), 0)
        XCTAssertEqual(Settings.clampSoundVolume(9), 1)
        XCTAssertEqual(Settings.clampSoundVolume(0.35), 0.35, accuracy: 0.0001)
        XCTAssertEqual(Settings.clampSoundVolume(.nan), 1,
                       "un numero che non è un numero non deve poter mutare l'app")
    }

    /// **Il polo positivo del limite**: un valore legittimo passa intero attraverso l'init, o il
    /// test qui sopra proverebbe soltanto che l'app sa dire di no a tutto.
    func testInitKeepsALegitimateValueAndClampsAnImpossibleOne() {
        XCTAssertEqual(Settings(soundVolume: 0.4).soundVolume, 0.4, accuracy: 0.0001)
        XCTAssertEqual(Settings(soundVolume: 4).soundVolume, 1)
    }

    /// Un file scritto prima del 2026-08-16 non ha la chiave: si legge lo stesso e il volume resta
    /// pieno. È lo stesso patto delle altre chiavi aggiunte in corsa — un'impostazione che compare
    /// non deve cambiare quelle che c'erano già.
    func testOldFileWithoutTheKeyDecodesAtFullVolume() throws {
        let json = """
        {"activeFromHour":7,"activeToHour":23,"notificationSound":"Tink","holdEndSound":"Glass",\
        "rampWeeks":3,"rampStartFactor":0.55,"theme":"alloro","vigorousDailyTarget":3}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let s = try decoder.decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(s.soundVolume, 1.0)
        XCTAssertEqual(s.notificationSound, "Tink", "il resto del file arriva intero")
    }

    /// Il polo opposto: la chiave c'è, e il valore scritto vince sul default. Senza questo, il test
    /// qui sopra sarebbe verde anche se la decodifica ignorasse il campo per sempre.
    func testWrittenValueWinsOverTheDefault() throws {
        let json = #"{"theme":"alloro","soundVolume":0.3}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let s = try decoder.decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(s.soundVolume, 0.3, accuracy: 0.0001)
    }

    /// Un file scritto a mano con un valore impossibile non deve poter zittire o assordare l'app:
    /// i `didSet` non scattano dentro un inizializzatore, quindi il limite va riapplicato nella
    /// decodifica, ed è la trappola in cui il progetto è già caduto con `rampStartFactor`.
    func testHandWrittenFileOutOfRangeIsClampedOnDecode() throws {
        let json = #"{"theme":"alloro","soundVolume":7.5}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let s = try decoder.decode(Settings.self, from: Data(json.utf8))
        XCTAssertEqual(s.soundVolume, 1.0)
    }

    /// Il giro completo: quello che scrivo lo rileggo uguale.
    func testRoundTrip() throws {
        var s = Settings()
        s.soundVolume = 0.25
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let riletta = try decoder.decode(Settings.self, from: encoder.encode(s))
        XCTAssertEqual(riletta.soundVolume, 0.25, accuracy: 0.0001)
    }
}
