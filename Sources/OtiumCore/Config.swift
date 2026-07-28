import Foundation

public enum BreakKind: String, Codable, Equatable, Sendable {
    /// 90 secondi: un esercizio, e si torna al lavoro.
    case micro
    /// 5 minuti: sessione intensa e poi lontano dallo schermo.
    case long
}

/// La cadenza — i numeri che vengono dagli studi, non dal gusto.
public struct Cadence: Codable, Equatable, Sendable {
    /// Secondi di **tempo attivo** fra un break e l'altro. Duran 2023 → 30 minuti.
    public var intervalSeconds: Double
    /// Durata del micro-snack. Albulescu 2022 → ben dentro i 10 minuti.
    public var microDurationSeconds: Double
    /// Durata della pausa piena. Galinsky 2000 → 5 minuti.
    public var longDurationSeconds: Double
    /// Ogni quanti break ne arriva uno pieno. 3 → micro, micro, pieno.
    public var longEveryNBreaks: Int
    /// Oltre questa inattività l'orologio si ferma e la pausa diventa "naturale".
    public var idleThresholdSeconds: Double
    /// Preavviso prima che lo schermo si copra: serve a chiudere quello che stai facendo.
    public var warningSeconds: Double
    /// Quanto dura un rinvio.
    public var postponeSeconds: Double
    /// Quanti rinvii per break. Stretchly ne concede uno: è la scelta giusta.
    public var postponesAllowed: Int

    public init(
        intervalSeconds: Double,
        microDurationSeconds: Double,
        longDurationSeconds: Double,
        longEveryNBreaks: Int,
        idleThresholdSeconds: Double,
        warningSeconds: Double,
        postponeSeconds: Double,
        postponesAllowed: Int
    ) {
        self.intervalSeconds = intervalSeconds
        self.microDurationSeconds = microDurationSeconds
        self.longDurationSeconds = longDurationSeconds
        self.longEveryNBreaks = max(1, longEveryNBreaks)
        self.idleThresholdSeconds = idleThresholdSeconds
        self.warningSeconds = warningSeconds
        self.postponeSeconds = postponeSeconds
        self.postponesAllowed = max(0, postponesAllowed)
    }

    public func duration(for kind: BreakKind) -> Double {
        kind == .long ? longDurationSeconds : microDurationSeconds
    }

    /// **Opzione A** — la cadenza scelta il 2026-07-26.
    /// Micro-snack di 90 s ogni 30 minuti di lavoro attivo; ogni terzo break è pieno (≈90 min).
    public static let optionA = Cadence(
        intervalSeconds: 30 * 60,
        microDurationSeconds: 90,
        longDurationSeconds: 5 * 60,
        longEveryNBreaks: 3,
        idleThresholdSeconds: 60,
        warningSeconds: 60,
        postponeSeconds: 120,
        postponesAllowed: 1
    )

    /// **Opzione B** — deep work: una sola pausa da 5 minuti ogni 50 di lavoro attivo.
    public static let optionB = Cadence(
        intervalSeconds: 50 * 60,
        microDurationSeconds: 5 * 60,
        longDurationSeconds: 5 * 60,
        longEveryNBreaks: 1,
        idleThresholdSeconds: 60,
        warningSeconds: 60,
        postponeSeconds: 120,
        postponesAllowed: 1
    )

    /// **Opzione C** — protocollo Duran puro: 5 minuti ogni 30. Il più efficace, il più invasivo.
    public static let optionC = Cadence(
        intervalSeconds: 30 * 60,
        microDurationSeconds: 5 * 60,
        longDurationSeconds: 5 * 60,
        longEveryNBreaks: 1,
        idleThresholdSeconds: 60,
        warningSeconds: 60,
        postponeSeconds: 120,
        postponesAllowed: 1
    )
}

public struct Settings: Codable, Equatable, Sendable {
    public var cadence: Cadence
    /// Data della prima esecuzione: da qui parte la rampa.
    public var startDate: Date
    public var rampWeeks: Int
    public var rampStartFactor: Double
    public var exercisePool: [ExerciseKind]
    public var vigorousPool: [ExerciseKind]
    /// Bersaglio giornaliero di sessioni intense — Stamatakis 2022 → 3.
    public var vigorousDailyTarget: Int
    /// La frase da digitare per esteso per saltare un break. Attrito, non impossibilità.
    public var escapePhrase: String
    /// Dopo quante settimane di uso l'app **chiede** se vuoi già passare al numero pieno.
    ///
    /// La partenza graduale esiste perché iniziare a quindici squat quando sei fermo da mesi è il
    /// modo di smettere in tre giorni. Ma quattro settimane sono lunghe per chi è già allenato, e
    /// un'app che decide da sola quanto sei in forma sbaglia in una delle due direzioni. Dopo due
    /// settimane lo chiede una volta sola: **una domanda, non una tacca in più sul cursore**.
    public var fullPaceOfferWeeks: Int
    /// La domanda è già stata fatta. Una volta sola: un'app che ripropone la stessa scelta ogni
    /// settimana non sta chiedendo, sta insistendo.
    public var fullPaceAnswered: Bool
    /// Il sesso biologico, **solo** per il punto di partenza delle ripetizioni (vedi
    /// `SexCalibration`). `nil` finché non l'hai scelto: è uno dei due inneschi dell'onboarding.
    public var sex: Sex?
    /// La lingua dell'interfaccia. `nil` finché non l'hai scelta: l'altro innesco dell'onboarding.
    public var language: AppLanguage?
    /// Se un microfono è in uso (call), il break si rimanda invece di piombare addosso.
    public var deferWhenMicrophoneActive: Bool
    /// Offri le varianti dentro la pausa (diamond, archer, dip su sedia…). Restano opzionali:
    /// spegnendolo, la pausa propone solo l'esercizio che tocca alla rotazione.
    public var offerVariants: Bool
    /// Proponi il microcircuito nelle pause piene: una stazione per famiglia — gambe, spinta,
    /// addome, esplosivo. **Proposta, non imposizione**: dentro la pausa scegli tu se fare il
    /// giro completo o il solo esercizio del turno.
    public var offerCircuit: Bool
    /// Otium riparte da sola a ogni accensione. Diventa `false` quando l'avvio automatico viene
    /// rimosso dalle preferenze, così l'app non se lo rimette da sola al riavvio successivo —
    /// una preferenza che si riscrive addosso all'utente è un difetto, non una comodità.
    public var autoStartAtLogin: Bool
    /// Conta come tempo sedentario anche quando non tocchi niente ma sei lì: video in
    /// riproduzione, documento aperto davanti. Spegnendolo, guardare un film torna a valere
    /// come una pausa — che è comodo e sbagliato.
    public var detectQuietPresence: Bool
    /// Quante volte di fila può rimandare da solo prima di arrendersi e bloccare comunque.
    public var maxAutoDefers: Int
    /// Quanto dura un rinvio automatico per call.
    public var autoDeferSeconds: Double
    /// La livrea. Di serie Alloro: verde notte e salvia, non nero e arancione — quello è il
    /// vestito di Sveglia e Timer di Apple.
    public var theme: ThemeName
    /// Il suono del preavviso. Nome di un suono di sistema macOS; stringa vuota = nessun suono.
    public var notificationSound: String
    /// Riaprendo l'app entro questo tempo, il conto riprende da dov'era. Di serie vale quanto
    /// una pausa piena (5 min): sotto è un riavvio, sopra è già una pausa vera.
    public var resumeGraceSeconds: Double
    /// Ore di silenzio: fuori da questa finestra Otium non interrompe.
    public var activeFromHour: Int
    public var activeToHour: Int

    public init(
        cadence: Cadence = .optionA,
        startDate: Date = Date(),
        rampWeeks: Int = 4,
        rampStartFactor: Double = 0.55,
        exercisePool: [ExerciseKind] = [.squat, .pushUp, .crunch, .lunge, .benchDip, .plank,
                                        .calfRaise, .gluteBridge, .legRaise],   // split squat non c'è: è una variante dell'affondo, non un esercizio a sé in rotazione
        vigorousPool: [ExerciseKind] = [.burpee, .jumpingJack, .mountainClimber, .highKnees],
        vigorousDailyTarget: Int = 3,
        escapePhrase: String = "salto la pausa",
        fullPaceOfferWeeks: Int = 2,
        fullPaceAnswered: Bool = false,
        sex: Sex? = nil,
        language: AppLanguage? = nil,
        deferWhenMicrophoneActive: Bool = true,
        detectQuietPresence: Bool = true,
        offerVariants: Bool = true,
        offerCircuit: Bool = true,
        autoStartAtLogin: Bool = true,
        maxAutoDefers: Int = 6,
        autoDeferSeconds: Double = 5 * 60,
        theme: ThemeName = .alloro,
        notificationSound: String = "Tink",
        resumeGraceSeconds: Double = 5 * 60,
        activeFromHour: Int = 7,
        activeToHour: Int = 23
    ) {
        self.cadence = cadence
        self.startDate = startDate
        self.rampWeeks = max(1, rampWeeks)
        self.rampStartFactor = min(1.0, max(0.1, rampStartFactor))
        self.exercisePool = exercisePool.isEmpty ? [.squat] : exercisePool
        self.vigorousPool = vigorousPool.isEmpty ? [.jumpingJack] : vigorousPool
        self.vigorousDailyTarget = max(0, vigorousDailyTarget)
        self.escapePhrase = escapePhrase
        self.fullPaceOfferWeeks = max(1, fullPaceOfferWeeks)
        self.fullPaceAnswered = fullPaceAnswered
        self.sex = sex
        self.language = language
        self.deferWhenMicrophoneActive = deferWhenMicrophoneActive
        self.detectQuietPresence = detectQuietPresence
        self.offerVariants = offerVariants
        self.offerCircuit = offerCircuit
        self.autoStartAtLogin = autoStartAtLogin
        self.maxAutoDefers = max(0, maxAutoDefers)
        self.autoDeferSeconds = autoDeferSeconds
        self.theme = theme
        self.notificationSound = notificationSound
        self.resumeGraceSeconds = max(0, resumeGraceSeconds)
        self.activeFromHour = activeFromHour
        self.activeToHour = activeToHour
    }

    public var planner: ExercisePlanner {
        ExercisePlanner(pool: exercisePool, vigorousPool: vigorousPool)
    }

    /// È il momento di chiedere se vuoi già il numero pieno?
    ///
    /// Tre condizioni, e servono tutte. Sono passate abbastanza settimane; non l'hai già
    /// risposto; e **non sei già al numero pieno**, perché chiedere «vuoi passare al pieno» a chi
    /// ci è già arrivato è una domanda senza risposta possibile.
    public func shouldOfferFullPace(now: Date) -> Bool {
        guard !fullPaceAnswered else { return false }
        guard rampFactor(now: now) < 1.0 else { return false }
        return Ramp.weeksElapsed(since: startDate, now: now) >= fullPaceOfferWeeks
    }

    public func rampFactor(now: Date) -> Double {
        Ramp.factor(
            weeksElapsed: Ramp.weeksElapsed(since: startDate, now: now),
            weeks: rampWeeks,
            startFactor: rampStartFactor
        )
    }

    /// Le decodifiche vecchie non devono morire quando aggiungo un campo: ogni chiave assente
    /// ricade sul default del `init`, invece di far fallire l'intero file di configurazione.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        cadence = (try? c.decode(Cadence.self, forKey: .cadence)) ?? d.cadence
        startDate = (try? c.decode(Date.self, forKey: .startDate)) ?? d.startDate
        rampWeeks = (try? c.decode(Int.self, forKey: .rampWeeks)) ?? d.rampWeeks
        rampStartFactor = (try? c.decode(Double.self, forKey: .rampStartFactor)) ?? d.rampStartFactor
        exercisePool = (try? c.decode([ExerciseKind].self, forKey: .exercisePool)) ?? d.exercisePool
        vigorousPool = (try? c.decode([ExerciseKind].self, forKey: .vigorousPool)) ?? d.vigorousPool
        vigorousDailyTarget = (try? c.decode(Int.self, forKey: .vigorousDailyTarget)) ?? d.vigorousDailyTarget
        escapePhrase = (try? c.decode(String.self, forKey: .escapePhrase)) ?? d.escapePhrase
        // Assenti nei file scritti prima dell'onboarding: restano nil, e l'app chiede.
        fullPaceOfferWeeks = (try? c.decode(Int.self, forKey: .fullPaceOfferWeeks)) ?? d.fullPaceOfferWeeks
        fullPaceAnswered = (try? c.decode(Bool.self, forKey: .fullPaceAnswered)) ?? d.fullPaceAnswered
        sex = try? c.decode(Sex.self, forKey: .sex)
        language = try? c.decode(AppLanguage.self, forKey: .language)
        deferWhenMicrophoneActive = (try? c.decode(Bool.self, forKey: .deferWhenMicrophoneActive)) ?? d.deferWhenMicrophoneActive
        detectQuietPresence = (try? c.decode(Bool.self, forKey: .detectQuietPresence)) ?? d.detectQuietPresence
        offerVariants = (try? c.decode(Bool.self, forKey: .offerVariants)) ?? d.offerVariants
        offerCircuit = (try? c.decode(Bool.self, forKey: .offerCircuit)) ?? d.offerCircuit
        autoStartAtLogin = (try? c.decode(Bool.self, forKey: .autoStartAtLogin)) ?? d.autoStartAtLogin
        maxAutoDefers = (try? c.decode(Int.self, forKey: .maxAutoDefers)) ?? d.maxAutoDefers
        autoDeferSeconds = (try? c.decode(Double.self, forKey: .autoDeferSeconds)) ?? d.autoDeferSeconds
        theme = (try? c.decode(ThemeName.self, forKey: .theme)) ?? d.theme
        notificationSound = (try? c.decode(String.self, forKey: .notificationSound)) ?? d.notificationSound
        resumeGraceSeconds = (try? c.decode(Double.self, forKey: .resumeGraceSeconds)) ?? d.resumeGraceSeconds
        activeFromHour = (try? c.decode(Int.self, forKey: .activeFromHour)) ?? d.activeFromHour
        activeToHour = (try? c.decode(Int.self, forKey: .activeToHour)) ?? d.activeToHour
    }
}

/// Dove vivono configurazione e registro. Niente `~/.pausa`: la convenzione macOS è
/// Application Support, e ci sta anche il backup di Time Machine.
public enum Paths {
    /// Dove vivono i dati quando **non** sono i dati veri: una cartella usa e getta, impostata
    /// all'avvio se l'app parte per una sonda o per una resa.
    ///
    /// Esiste perché una sonda che scrive nel registro, nella rotazione e nei mazzi del principale
    /// non sta misurando l'app, la sta modificando. Prima ci si compensava a mano, con un backup
    /// prima e un ripristino dopo, cioè con la disciplina di chi lancia il comando — la garanzia
    /// più fragile che ci sia, e il 2026-07-28 ha ceduto: le sonde hanno riscritto l'avvio
    /// automatico del principale. Con la deviazione qui la sonda è ermetica per costruzione, e per
    /// giunta può girare mentre l'app vera lavora, perché anche il lock dell'istanza unica finisce
    /// nella cartella usa e getta.
    public static var overrideDirectory: URL?

    public static var supportDirectory: URL {
        if let overrideDirectory { return overrideDirectory }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otium", isDirectory: true)
    }

    public static var settingsFile: URL { supportDirectory.appendingPathComponent("settings.json") }
    public static var ledgerFile: URL { supportDirectory.appendingPathComponent("ledger.jsonl") }
    public static var rotationFile: URL { supportDirectory.appendingPathComponent("rotation.json") }
    /// I mazzi delle frasi: quali sono già uscite e quali restano.
    public static var decksFile: URL { supportDirectory.appendingPathComponent("decks.json") }
    /// Le frasi aggiunte a mano. L'app le legge e non le scrive mai.
    public static var userPhrasesFile: URL { supportDirectory.appendingPathComponent("frasi-mie.json") }

    @discardableResult
    public static func ensureDirectory() -> Bool {
        (try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)) != nil
    }
}

public enum SettingsStore {
    public static func load(from url: URL = Paths.settingsFile) -> Settings {
        guard let data = try? Data(contentsOf: url) else { return Settings() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Settings.self, from: data)) ?? Settings()
    }

    @discardableResult
    public static func save(_ settings: Settings, to url: URL = Paths.settingsFile) -> Bool {
        Paths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(settings) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}


/// Dove vive la rotazione fra un'esecuzione e l'altra.
public enum RotationStore {
    public static func load(from url: URL = Paths.rotationFile) -> EngineSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(EngineSnapshot.self, from: data)
    }

    @discardableResult
    public static func save(_ snapshot: EngineSnapshot, to url: URL = Paths.rotationFile) -> Bool {
        Paths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}


/// I suoni di sistema disponibili per il preavviso. Sono quelli che macOS ha già: nessun file
/// audio da spedire con l'app, nessun asset da mantenere.
public enum NotificationSounds {
    public static let names = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]
    public static let silent = ""
}
