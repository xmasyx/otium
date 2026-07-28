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

    /// **Ogni fatto e ogni studio hanno l'inglese, e il conto è un conto, non una stima.**
    ///
    /// Un ripiego silenzioso sull'italiano è comodo mentre traduci e diventa un difetto il giorno
    /// dopo: in inglese comparirebbe una riga italiana e nessuno saprebbe che manca. Qui il test
    /// dice **quante** ne mancano e **quali**.
    func testEveryFactAndStudyIsTranslated() {
        let senzaInglese = Facts.all.filter { $0.textEN.isEmpty }
        XCTAssertTrue(senzaInglese.isEmpty,
                      "\(senzaInglese.count) fatti su \(Facts.all.count) senza inglese: "
                      + senzaInglese.prefix(3).map { String($0.text.prefix(40)) }.joined(separator: " | "))

        for study in Evidence.all {
            XCTAssertNotEqual(study.claimEN, study.claim, "\(study.id): il riassunto non è tradotto")
            XCTAssertNotEqual(study.governsEN, study.governs, "\(study.id): «cosa governa» non è tradotto")
            XCTAssertFalse(study.claimEN.isEmpty)
        }
    }

    /// La lingua cambia il testo mostrato ma **non l'identità della frase**: l'id resta ancorato
    /// all'italiano, o cambiare lingua rimescolerebbe il mazzo e la promessa del mese senza
    /// ripetizioni ripartirebbe da zero, in silenzio.
    func testFactIdentityDoesNotFollowTheLanguage() {
        L.language = .italian
        let itIds = Facts.all.map(\.id)
        L.language = .english
        let enIds = Facts.all.map(\.id)
        XCTAssertEqual(itIds, enIds, "gli id dei fatti cambiano con la lingua")
        XCTAssertNotEqual(Facts.all.first?.localizedText, Facts.all.first?.text,
                          "in inglese il testo mostrato deve cambiare")
    }

    /// **La domanda delle due settimane si fa quando ha senso farla, e una volta sola.**
    func testFullPaceIsOfferedOnlyWhenItMakesSense() {
        let inizio = Date(timeIntervalSince1970: 1_700_000_000)
        var s = Settings(startDate: inizio, rampWeeks: 6, rampStartFactor: 0.55)
        s.fullPaceOfferWeeks = 2

        // Troppo presto: la settimana dopo l'installazione non si chiede niente.
        XCTAssertFalse(s.shouldOfferFullPace(now: inizio.addingTimeInterval(6 * 24 * 3600)))
        // A due settimane, sì.
        XCTAssertTrue(s.shouldOfferFullPace(now: inizio.addingTimeInterval(15 * 24 * 3600)))
        // Risposto: non si richiede più, mai.
        var risposto = s
        risposto.fullPaceAnswered = true
        XCTAssertFalse(risposto.shouldOfferFullPace(now: inizio.addingTimeInterval(40 * 24 * 3600)))
        // Chi è già al numero pieno non ha niente a cui rispondere.
        var pieno = s
        pieno.rampStartFactor = 1.0
        XCTAssertFalse(pieno.shouldOfferFullPace(now: inizio.addingTimeInterval(15 * 24 * 3600)))
        // E nemmeno chi la salita l'ha già finita da sé.
        XCTAssertFalse(s.shouldOfferFullPace(now: inizio.addingTimeInterval(60 * 24 * 3600)),
                       "a salita finita il fattore è 1.0, non c'è niente da offrire")
    }

    /// «Sì» significa **adesso**: il numero pieno è quello di base, non un passo in più.
    func testFullPaceMeansTheBaseNumber() {
        var s = Settings(startDate: Date(), rampWeeks: 6, rampStartFactor: 0.55)
        XCTAssertLessThan(Ramp.reps(for: .squat, factor: s.rampFactor(now: Date()), sex: .male),
                          ExerciseKind.squat.baseReps)
        s.rampStartFactor = 1.0
        XCTAssertEqual(Ramp.reps(for: .squat, factor: s.rampFactor(now: Date()), sex: .male),
                       ExerciseKind.squat.baseReps)
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
