import XCTest
@testable import OtiumCore

/// Il punto di partenza delle ripetizioni, e la lingua.
final class ProfileTests: XCTestCase {

    override func tearDown() {
        L.language = .italian
        super.tearDown()
    }

    /// Senza scelta, niente calibrazione: chi non ha risposto vede il numero pieno, non uno
    /// dedotto per lui.
    func testNoSexMeansNoCalibration() {
        for kind in ExerciseKind.allCases {
            XCTAssertEqual(Ramp.reps(for: kind, factor: 1.0, sex: nil),
                           Ramp.reps(for: kind, factor: 1.0))
        }
    }

    func testMaleIsTheFullNumber() {
        for kind in ExerciseKind.allCases {
            XCTAssertEqual(Ramp.reps(for: kind, factor: 1.0, sex: .male),
                           Ramp.reps(for: kind, factor: 1.0, sex: nil),
                           "\(kind.rawValue) non deve cambiare")
        }
    }

    /// Il verso della calibrazione, e il fatto che **la parte alta scenda più della bassa**: è la
    /// forma della misura di Miller 1993, non un'intensità generica.
    func testFemaleStartsLowerAndUpperBodyDropsMost() {
        let push = Ramp.reps(for: .pushUp, factor: 1.0, sex: .female)
        let pushFull = Ramp.reps(for: .pushUp, factor: 1.0, sex: .male)
        let squat = Ramp.reps(for: .squat, factor: 1.0, sex: .female)
        let squatFull = Ramp.reps(for: .squat, factor: 1.0, sex: .male)

        XCTAssertLessThan(push, pushFull)
        XCTAssertLessThan(squat, squatFull)
        let rapportoAlto = Double(push) / Double(pushFull)
        let rapportoBasso = Double(squat) / Double(squatFull)
        XCTAssertLessThan(rapportoAlto, rapportoBasso,
                          "la parte alta deve scendere più della bassa (Miller 1993)")
    }

    /// **Mai zero, e mai un numero che non si può eseguire.** Una calibrazione che proponesse
    /// «0 push-up» o «1,5 affondi per lato» sarebbe peggio di nessuna calibrazione.
    func testCalibratedRepsStayExecutable() {
        for kind in ExerciseKind.allCases {
            for factor in [0.4, 0.55, 0.7, 1.0] {
                for sex in [Sex.male, .female] {
                    let reps = Ramp.reps(for: kind, factor: factor, sex: sex)
                    XCTAssertGreaterThanOrEqual(reps, 1, "\(kind.rawValue) a \(factor) con \(sex)")
                    if kind.isPerSide {
                        XCTAssertEqual(reps % 2, 0, "\(kind.rawValue) a lati alterni deve restare pari")
                    }
                }
            }
        }
    }

    /// La lingua cambia le parole, **non** il nome canonico che finisce nel registro: una riga
    /// scritta in inglese e riletta in italiano diventerebbe un altro esercizio.
    func testLanguageChangesWordsNotTheCanonicalName() {
        L.language = .italian
        XCTAssertEqual(ExerciseKind.lunge.localizedName, "affondi")
        XCTAssertEqual(ExerciseKind.lunge.rawValue, "lunge")
        L.language = .english
        XCTAssertEqual(ExerciseKind.lunge.localizedName, "lunges")
        XCTAssertEqual(ExerciseKind.lunge.rawValue, "lunge",
                       "il nome canonico non si traduce mai")
        XCTAssertEqual(ExerciseKind.lunge.italianName, "affondi",
                       "l'italiano resta raggiungibile, serve al registro storico")
    }

    /// Ogni esercizio ha un nome in entrambe le lingue, e nessuno dei due è vuoto: una traduzione
    /// mancante a schermo è una riga bianca, e una riga bianca non si distingue da un guasto.
    func testEveryExerciseHasBothNames() {
        for kind in ExerciseKind.allCases {
            XCTAssertFalse(kind.italianName.isEmpty, "\(kind.rawValue) senza nome italiano")
            XCTAssertFalse(kind.englishName.isEmpty, "\(kind.rawValue) senza nome inglese")
        }
        for family in ExerciseCategory.allCases {
            XCTAssertFalse(family.italianName.isEmpty)
            XCTAssertFalse(family.englishName.isEmpty)
        }
    }

    /// Le impostazioni scritte prima che l'onboarding esistesse non devono morire, e devono
    /// **chiedere**: lingua e sesso restano nil, che è l'innesco della prima schermata.
    func testOldSettingsFileTriggersOnboarding() throws {
        let json = #"{"rampWeeks":4,"escapePhrase":"salto la pausa"}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let settings = try decoder.decode(Settings.self, from: json)
        XCTAssertNil(settings.sex)
        XCTAssertNil(settings.language)
        XCTAssertEqual(settings.escapePhrase, "salto la pausa")
    }
}
