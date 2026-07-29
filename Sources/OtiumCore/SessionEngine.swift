import Foundation

public struct BreakPlan: Equatable, Sendable {
    public let index: Int
    public let kind: BreakKind
    public let duration: Double
    /// Sostituibile durante la pausa: puoi scegliere una variante senza saltare il break.
    public var exercise: Exercise
    /// Il microcircuito **proposto** per questa pausa piena: una stazione per famiglia. Vuoto
    /// sulle micro-pause e quando è spento nelle preferenze. Proposto non vuol dire attivo:
    /// finché non lo scegli, la pausa resta a esercizio singolo.
    public var circuit: [Exercise] = []
    /// L'hai scelto: `exercise` ora è la stazione in corso.
    public var circuitActive: Bool = false
    /// Quale stazione, 0-based.
    public var stationIndex: Int = 0

    public init(index: Int, kind: BreakKind, duration: Double, exercise: Exercise,
                circuit: [Exercise] = []) {
        self.index = index
        self.kind = kind
        self.duration = duration
        self.exercise = exercise
        self.circuit = circuit
    }
}

public enum SkipReason: String, Codable, Equatable, Sendable {
    /// Frase d'emergenza digitata per esteso.
    case escapePhrase
    /// Fuori dalle ore attive: Otium non interrompe di notte.
    case outOfHours
    /// Rete di sicurezza assoluta: qualcosa non torna, lo schermo si libera.
    case failsafe
    /// Uscita d'emergenza: due Esc, o il pulsante. Immediata, ma **contata e segnalata**.
    case emergency
}

/// Lo stato della rotazione, che deve sopravvivere alla chiusura dell'app.
///
/// Senza, ogni avvio riparte da `breakIndex = 0` e la prima pausa è **sempre** lo stesso
/// esercizio. Il difetto è invisibile finché non lo vivi: chi chiude e riapre il Mac ogni giorno
/// vede squat, squat, squat, e conclude che l'app conosca un esercizio solo. Segnalato dal
/// principale il 2026-07-26 guardando la schermata — «break n. 1» ogni volta.
public struct EngineSnapshot: Codable, Equatable, Sendable {
    public var breakIndex: Int
    public var microsSinceLong: Int
    /// Quante volte l'app è stata avviata: serve a far girare le citazioni.
    public var launchCount: Int
    /// Il tempo attivo accumulato al momento del salvataggio: se l'app riparte subito, riprende
    /// da qui invece di buttare via mezz'ora di lavoro per un riavvio.
    public var activeSeconds: Double
    public var savedAt: Date

    public init(breakIndex: Int, microsSinceLong: Int, launchCount: Int = 0,
                activeSeconds: Double = 0, savedAt: Date = Date()) {
        self.breakIndex = breakIndex
        self.microsSinceLong = microsSinceLong
        self.launchCount = launchCount
        self.activeSeconds = activeSeconds
        self.savedAt = savedAt
    }

    /// Tollerante alle chiavi mancanti: un file scritto da una versione precedente non deve
    /// far ripartire la rotazione da zero, che è il difetto che questo stato esiste per curare.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        breakIndex = (try? c.decode(Int.self, forKey: .breakIndex)) ?? 0
        microsSinceLong = (try? c.decode(Int.self, forKey: .microsSinceLong)) ?? 0
        launchCount = (try? c.decode(Int.self, forKey: .launchCount)) ?? 0
        activeSeconds = (try? c.decode(Double.self, forKey: .activeSeconds)) ?? 0
        savedAt = (try? c.decode(Date.self, forKey: .savedAt)) ?? Date()
    }
}

public enum EngineEvent: Equatable, Sendable {
    case warningStarted(BreakPlan)
    case breakStarted(BreakPlan)
    /// L'esercizio è stato confermato: **le ripetizioni sono fatte adesso**, e adesso vanno
    /// contate. Prima finivano nel registro solo alla chiusura della pausa — cioè fino a cinque
    /// minuti dopo averle eseguite — e il recap aperto nel frattempo non le vedeva.
    case exerciseConfirmed(Exercise)
    case breakCompleted(BreakPlan)
    case breakSkipped(BreakPlan, SkipReason)
    case naturalBreak(seconds: Double, creditedLong: Bool)
    case postponed(BreakPlan)
    case autoDeferred(BreakPlan, reason: String)
}

/// Cosa sta succedendo intorno, nel momento in cui il break vorrebbe partire.
public struct EngineEnvironment: Equatable, Sendable {
    /// Un dispositivo d'ingresso audio è in uso: probabile call. Non si blocca uno schermo
    /// mentre stai parlando con un cliente.
    public var microphoneActive: Bool
    /// Perché sei lì pur non toccando niente: un video, un documento aperto. `nil` = nessun
    /// segnale, quindi fermo significa assente.
    public var presence: PresenceSignal?

    public init(microphoneActive: Bool = false, presence: PresenceSignal? = nil) {
        self.microphoneActive = microphoneActive
        self.presence = presence
    }

    public static let quiet = EngineEnvironment()
}

/// Il motore: decide quando il break è dovuto, di che tipo, e quando può finire.
///
/// Tutto a tempo iniettato — `tick(elapsed:idle:now:environment:)` — perché una macchina a stati
/// che legge `Date()` da sola non si può provare, e questa deve esserlo riga per riga.
public struct SessionEngine {

    public enum Phase: String, Equatable, Sendable, CaseIterable {
        case working
        /// Preavviso: lo schermo non è ancora coperto, hai 60 secondi per chiudere quello che fai.
        case warning
        /// Schermo coperto.
        case breaking
        /// Rinviato (a mano o per call).
        case postponed
        /// Sospeso dall'utente dal menu.
        case paused
    }

    /// Cambiare le preferenze a metà giornata non deve azzerare il lavoro già contato: si
    /// aggiorna la soglia dell'orologio, non si costruisce un orologio nuovo.
    public var settings: Settings {
        didSet { clock.idleThreshold = settings.cadence.idleThresholdSeconds }
    }

    /// Quanto sei avanti su ogni esercizio. Vuoto finché la crescita oltre il 100% è spenta:
    /// senza il suo interruttore acceso, il motore non deve nemmeno sapere che esiste.
    public var progress: ProgressBook = ProgressBook()
    public private(set) var clock: ActivityClock
    public private(set) var phase: Phase = .working
    public private(set) var plan: BreakPlan?
    /// Significato per fase: `warning` → secondi che mancano; `breaking` → secondi trascorsi;
    /// `postponed` → secondi che mancano al ritorno.
    public private(set) var timer: Double = 0
    public private(set) var breakIndex: Int = 0
    public private(set) var microsSinceLong: Int = 0
    public private(set) var postponesUsed: Int = 0
    public private(set) var autoDefersUsed: Int = 0
    public private(set) var exerciseDone: Bool = false
    /// L'ultimo segnale di presenza visto mentre lavoravi: finisce nella schermata di blocco,
    /// perché se ti interrompo credendo che tu stia guardando un video devi poter vedere **cosa**
    /// ho riconosciuto, e darmi torto.
    public private(set) var lastPresence: PresenceSignal?
    /// Inattività accumulata **durante** un break: se nessuno è davanti al Mac, il blocco cade.
    private var idleDuringBreak: Double = 0
    /// Da che punto del break conta il tempo minimo dell'esercizio in corso. Cambiando variante
    /// riparte da lì: altrimenti basterebbe aspettare col push-up e passare al più corto un
    /// istante prima di premere "fatto".
    private var exerciseBaseline: Double = 0
    /// L'esercizio singolo messo da parte quando entri nel circuito, per poterci tornare.
    private var singleExercise: Exercise?

    /// Quando l'assenza durante un blocco significa "se n'è andato davvero".
    ///
    /// **Non** un valore fisso, e la differenza è tutta la ragione per cui questo esiste: la
    /// pausa piena ti chiede *proprio* di stare tre minuti lontano dallo schermo, quindi una
    /// soglia fissa a tre minuti annullerebbe la pausa mentre la stai facendo bene, e la
    /// segnerebbe come saltata. La soglia sta sempre due minuti oltre la durata del break.
    public static func absentThreshold(for plan: BreakPlan) -> Double {
        max(180, plan.duration + 120)
    }
    /// Rete di sicurezza assoluta. Non è un timeout sulla disciplina — quello svuoterebbe l'app:
    /// è la garanzia che un motore incoerente non lasci uno schermo nero per sempre.
    public static let failsafeCeiling: Double = 30 * 60

    /// Quanto lavoro deve esserci **prima**, perché un'assenza valga come interruzione.
    ///
    /// Il numero che l'app mostra si chiama «interruzioni della sedentarietà», e negli studi che
    /// cita (Duran 2023) la cosa misurata è l'interruzione di una **seduta prolungata**. Se non
    /// ti sei seduto non c'è niente da interrompere: contarla lo stesso gonfia il numero senza
    /// che tu abbia fatto nulla, ed è esattamente così che la notte del 28 luglio 2026 ne sono
    /// comparse 47 con il Mac chiuso. Cinque minuti è la sedentarietà più corta che abbia senso
    /// chiamare tale.
    public static let minimumSedentaryBeforeCredit: Double = 300

    /// `maxCredibleElapsed` è iniettabile perché i test fanno passare il tempo a grandi passi:
    /// con il valore di produzione (5 s) ogni tick da un minuto sembrerebbe una sospensione.
    public init(settings: Settings = Settings(), maxCredibleElapsed: Double = 5) {
        self.settings = settings
        self.clock = ActivityClock(
            idleThreshold: settings.cadence.idleThresholdSeconds,
            maxCredibleElapsed: maxCredibleElapsed
        )
    }

    // MARK: - Ingresso del tempo

    @discardableResult
    public mutating func tick(
        elapsed: Double,
        idle: Double,
        now: Date,
        environment: EngineEnvironment = .quiet
    ) -> [EngineEvent] {
        switch phase {
        case .paused:
            return []
        case .working:
            lastPresence = environment.presence
            return tickWorking(elapsed: elapsed, idle: idle, now: now, environment: environment)
        case .warning:
            return tickWarning(elapsed: elapsed, now: now, environment: environment)
        case .breaking:
            return tickBreaking(elapsed: elapsed, idle: idle)
        case .postponed:
            return tickPostponed(elapsed: elapsed, now: now, environment: environment)
        }
    }

    /// Il segnale vale finché non supera il proprio tetto: oltre, sei uscito e hai lasciato il
    /// film — o il PDF — acceso.
    public func presenceHolds(_ presence: PresenceSignal?, idle: Double) -> Bool {
        guard let presence else { return false }
        return idle < PresenceCap.seconds(for: presence.kind)
    }

    private mutating func tickWorking(
        elapsed: Double,
        idle: Double,
        now: Date,
        environment: EngineEnvironment
    ) -> [EngineEvent] {
        var events: [EngineEvent] = []
        let clockEvent = clock.tick(
            elapsed: elapsed,
            idle: idle,
            presenceHolds: presenceHolds(environment.presence, idle: idle)
        )

        switch clockEvent {
        case .naturalBreak(let seconds):
            // Time Out fa una cosa giusta che nessun altro fa: la pausa spontanea vale.
            // Alzarsi da soli È il comportamento desiderato, non un modo di imbrogliare.
            events.append(contentsOf: creditNatural(seconds: seconds, alwaysReset: false))
        case .suspended(let gap):
            // Il Mac si è sospeso. Il contatore verso la prossima pausa riparte comunque, perché
            // il tempo passato lontano dallo schermo è tempo lontano dallo schermo; ma
            // l'interruzione si scrive solo se prima c'era del lavoro da interrompere.
            events.append(contentsOf: creditNatural(seconds: gap, alwaysReset: true))
        case .accumulating, .quietPresence, .idling:
            break
        }

        guard clock.activeSeconds >= settings.cadence.intervalSeconds else { return events }

        let newPlan = planNextBreak(now: now)
        plan = newPlan
        postponesUsed = 0
        autoDefersUsed = 0
        exerciseDone = false
        idleDuringBreak = 0

        if settings.cadence.warningSeconds > 0 {
            phase = .warning
            timer = settings.cadence.warningSeconds
            events.append(.warningStarted(newPlan))
        } else {
            events.append(contentsOf: startBreak(newPlan, now: now, environment: .quiet))
        }
        return events
    }

    /// Scrive — o non scrive — l'interruzione per un'assenza appena conclusa.
    ///
    /// Due condizioni, e servono tutte e due. L'assenza dev'essere lunga almeno quanto una
    /// micro-pausa, o ogni volta che ti giri a parlare con qualcuno diventerebbe una pausa. E
    /// prima dell'assenza dev'esserci stata della sedentarietà vera, o il numero conta assenze
    /// di nessuno da nessun posto.
    private mutating func creditNatural(seconds: Double, alwaysReset: Bool) -> [EngineEvent] {
        let longEnough = seconds >= settings.cadence.microDurationSeconds
        let earned = clock.activeSeconds >= Self.minimumSedentaryBeforeCredit
        var events: [EngineEvent] = []
        if longEnough && earned {
            let creditedLong = seconds >= settings.cadence.longDurationSeconds
            if creditedLong { microsSinceLong = 0 } else { microsSinceLong += 1 }
            events.append(.naturalBreak(seconds: seconds, creditedLong: creditedLong))
        }
        if alwaysReset || longEnough { clock.reset() }
        return events
    }

    private mutating func tickWarning(elapsed: Double, now: Date, environment: EngineEnvironment) -> [EngineEvent] {
        guard let current = plan else { phase = .working; return [] }
        timer -= elapsed
        guard timer <= 0 else { return [] }
        return startBreak(current, now: now, environment: environment)
    }

    private mutating func tickBreaking(elapsed: Double, idle: Double) -> [EngineEvent] {
        guard let current = plan else { phase = .working; return [] }
        timer += elapsed
        idleDuringBreak = idle

        // Nessuno davanti al Mac: la pausa se l'è presa camminando via, ed è una pausa vera —
        // si registra come naturale, non come saltata. L'esercizio non viene accreditato,
        // perché non risulta fatto: il registro non deve mentire in nessuna delle due direzioni.
        if idle >= Self.absentThreshold(for: current) {
            return finish(current, event: .naturalBreak(seconds: idle, creditedLong: current.kind == .long))
        }

        if timer >= Self.failsafeCeiling {
            return finish(current, event: .breakSkipped(current, .failsafe))
        }

        // **La pausa dura quanto dichiarato.** La prima versione lasciava finire il micro appena
        // l'esercizio era fatto: 7 dip su sedia sono 18 secondi, e una "micro-pausa da 90
        // secondi" ne durava 18. Il numero nelle preferenze e il numero vissuto devono essere lo
        // stesso, o le preferenze mentono — notato dal principale al primo uso vero.
        //
        // I secondi che restano dopo l'esercizio non sono tempo sprecato: sono l'unico momento
        // della giornata in cui non guardi lo schermo.
        // **La pausa non si chiude da sola.** Il conto alla rovescia arriva a zero e il pulsante
        // si accende: sei tu a tornare al lavoro. Chiudere in automatico toglieva il gesto —
        // e un gesto che non c'è non si può nemmeno rimandare di due secondi per finire il
        // respiro. Le due reti restano: se non c'è nessuno il blocco si scioglie, e il tetto
        // assoluto vale sempre.
        return []
    }

    private mutating func tickPostponed(elapsed: Double, now: Date, environment: EngineEnvironment) -> [EngineEvent] {
        guard let current = plan else { phase = .working; return [] }
        timer -= elapsed
        guard timer <= 0 else { return [] }
        return startBreak(current, now: now, environment: environment)
    }

    // MARK: - Transizioni

    private mutating func startBreak(
        _ current: BreakPlan,
        now: Date,
        environment: EngineEnvironment,
        forced: Bool = false
    ) -> [EngineEvent] {
        // Fuori dalle ore attive non si interrompe. Di notte il Mac è di chi lo usa.
        if !forced, !isWithinActiveHours(now) {
            return finish(current, event: .breakSkipped(current, .outOfHours))
        }

        // In call: si rimanda e lo si dichiara. Un blocco a schermo intero durante una riunione
        // è un difetto, per quanto ben motivato sia l'esercizio.
        if !forced,
           environment.microphoneActive,
           settings.deferWhenMicrophoneActive,
           autoDefersUsed < settings.maxAutoDefers {
            autoDefersUsed += 1
            phase = .postponed
            timer = settings.autoDeferSeconds
            return [.autoDeferred(current, reason: "microfono in uso")]
        }

        phase = .breaking
        timer = 0
        exerciseDone = false
        idleDuringBreak = 0
        exerciseBaseline = 0
        return [.breakStarted(current)]
    }

    private mutating func finish(_ current: BreakPlan, event: EngineEvent) -> [EngineEvent] {
        if current.kind == .long {
            microsSinceLong = 0
        } else {
            microsSinceLong += 1
        }
        clock.reset()
        phase = .working
        timer = 0
        plan = nil
        exerciseDone = false
        idleDuringBreak = 0
        exerciseBaseline = 0
        singleExercise = nil
        return [event]
    }

    private mutating func planNextBreak(now: Date, forcedKind: BreakKind? = nil) -> BreakPlan {
        let kind: BreakKind = forcedKind
            ?? ((microsSinceLong + 1 >= settings.cadence.longEveryNBreaks) ? .long : .micro)
        breakIndex += 1
        let factor = settings.rampFactor(now: now)
        let exercise = settings.planner.exercise(breakIndex: breakIndex, kind: kind,
                                                 factor: factor, sex: settings.sex,
                                                 pushVariant: settings.pushVariant,
                                                 progress: settings.progressBeyondFull ? progress : nil)
        // Il circuito si prepara solo dove ha senso — la pausa piena — e resta una proposta.
        let circuit = (kind == .long && settings.offerCircuit)
            ? settings.planner.circuit(breakIndex: breakIndex, factor: factor, sex: settings.sex,
                                       pushVariant: settings.pushVariant)
            : []
        return BreakPlan(
            index: breakIndex,
            kind: kind,
            duration: settings.cadence.duration(for: kind),
            exercise: exercise,
            circuit: circuit
        )
    }

    private func isWithinActiveHours(_ now: Date) -> Bool {
        let hour = Calendar.current.component(.hour, from: now)
        let from = settings.activeFromHour
        let to = settings.activeToHour
        if from == to { return true }
        if from < to { return hour >= from && hour < to }
        return hour >= from || hour < to   // finestra che scavalca la mezzanotte
    }

    // MARK: - Azioni dell'utente

    /// Il cancello anti-bluff: prima del tempo minimo plausibile per quelle ripetizioni,
    /// "fatto" non è cliccabile e questa chiamata non fa niente.
    /// Conferma l'esercizio. Non chiude la pausa: quella finisce quando il tempo è scaduto e
    /// premi tu.
    ///
    /// Dentro il circuito lo stesso gesto vale «stazione fatta, avanti la prossima»: il cancello
    /// riparte da capo su ogni stazione, così le quattro non si sbloccano tutte con il tempo
    /// della prima.
    @discardableResult
    public mutating func markExerciseDone() -> [EngineEvent] {
        guard phase == .breaking, var current = plan else { return [] }
        guard timer - exerciseBaseline >= current.exercise.minimumSeconds else { return [] }

        // Le ripetizioni si contano **qui**, dove sono state fatte. Che poi la pausa duri altri
        // quattro minuti, o che tu esca d'emergenza, non toglie nulla al lavoro già svolto.
        let done = current.exercise
        // Il segnale della progressione: quando confermi senza dire altro, le hai fatte tutte.
        if settings.progressBeyondFull { progress.record(.complete, for: done.kind) }

        if current.circuitActive, current.stationIndex + 1 < current.circuit.count {
            current.stationIndex += 1
            current.exercise = current.circuit[current.stationIndex]
            plan = current
            exerciseBaseline = timer
            exerciseDone = false
            return [.exerciseConfirmed(done)]
        }
        exerciseDone = true
        return [.exerciseConfirmed(done)]
    }

    /// «Non tutte»: hai fatto meno di quante te ne aveva chieste, e lo dici.
    ///
    /// Vale come conferma dell'esercizio — il lavoro l'hai fatto e va contato — ma per la
    /// progressione è il segnale opposto. Un'app che accetta solo il successo misura solo le
    /// giornate buone, e su quelle qualunque progressione sembra funzionare.
    @discardableResult
    public mutating func markExercisePartial(actualReps: Int) -> [EngineEvent] {
        guard phase == .breaking, var current = plan else { return [] }
        let reps = max(0, min(actualReps, current.exercise.reps))
        // **Il cancello anti-bluff vale anche qui, in proporzione.** Dire «ne ho fatte nove su
        // dieci» un istante dopo l'inizio è un bluff esattamente come dirle tutte: il tempo
        // richiesto scende con le ripetizioni dichiarate, non sparisce. Il buco l'ha aperto il
        // bottone nuovo e l'ha trovato il fuzz, non l'uso.
        let richiesto = Double(reps) * current.exercise.kind.secondsPerRep
        guard timer - exerciseBaseline >= richiesto else { return [] }
        let done = Exercise(kind: current.exercise.kind, reps: reps)
        if settings.progressBeyondFull { progress.record(.partial, for: done.kind) }

        if current.circuitActive, current.stationIndex + 1 < current.circuit.count {
            current.stationIndex += 1
            current.exercise = current.circuit[current.stationIndex]
            plan = current
            exerciseBaseline = timer
            exerciseDone = false
            return [.exerciseConfirmed(done)]
        }
        exerciseDone = true
        return [.exerciseConfirmed(done)]
    }

    /// Il circuito è proponibile adesso? Solo dentro una pausa piena che ne ha uno pronto e non
    /// è già cominciato.
    public var canStartCircuit: Bool {
        guard phase == .breaking, let current = plan else { return false }
        return !current.circuitActive && current.circuit.count >= 2
    }

    /// «Faccio il giro completo.» Facoltativo: si sceglie dentro la pausa, non lo decide l'app.
    @discardableResult
    public mutating func startCircuit() -> Bool {
        guard canStartCircuit, var current = plan else { return false }
        singleExercise = current.exercise
        current.circuitActive = true
        current.stationIndex = 0
        current.exercise = current.circuit[0]
        plan = current
        // Il cronometro dell'esercizio riparte: entrare nel circuito dopo aver aspettato non
        // deve regalare la prima stazione già sbloccata.
        exerciseBaseline = timer
        exerciseDone = false
        return true
    }

    /// «Basta così, torno all'esercizio singolo.» Le stazioni già confermate restano fatte — sono
    /// già nel registro, scritte nel momento in cui le hai confermate — e la pausa torna a
    /// chiudersi con un esercizio solo.
    @discardableResult
    public mutating func leaveCircuit() -> Bool {
        guard phase == .breaking, var current = plan, current.circuitActive else { return false }
        current.circuitActive = false
        current.stationIndex = 0
        current.exercise = singleExercise ?? current.exercise
        plan = current
        exerciseBaseline = timer
        exerciseDone = false
        return true
    }

    /// Il pulsante è cliccabile solo quando **entrambe** le condizioni sono vere: l'esercizio
    /// confermato e il tempo della pausa scaduto.
    public var canReturnToWork: Bool {
        guard phase == .breaking, let current = plan else { return false }
        return exerciseDone && timer >= current.duration
    }

    /// «Torno al lavoro»: il gesto che chiude la pausa.
    @discardableResult
    public mutating func returnToWork() -> [EngineEvent] {
        guard canReturnToWork, let current = plan else { return [] }
        return finish(current, event: .breakCompleted(current))
    }

    /// Quanto manca alla fine della pausa, esercizio a parte.
    public var secondsLeftOfBreak: Double {
        guard phase == .breaking, let current = plan else { return 0 }
        return max(0, current.duration - timer)
    }

    public var canFinishNow: Bool {
        guard phase == .breaking, let current = plan else { return false }
        return timer - exerciseBaseline >= current.exercise.minimumSeconds
    }

    public var secondsUntilCanFinish: Double {
        guard phase == .breaking, let current = plan else { return 0 }
        return max(0, current.exercise.minimumSeconds - (timer - exerciseBaseline))
    }

    /// Le alternative proponibili adesso, con le ripetizioni già calcolate per oggi.
    public func variants(now: Date) -> [Exercise] {
        guard phase == .breaking, let current = plan else { return [] }
        let factor = settings.rampFactor(now: now)
        return current.exercise.kind.variants.map {
            Exercise(kind: $0, reps: Ramp.reps(for: $0, factor: factor, sex: settings.sex))
        }
    }

    /// Cambia esercizio restando nella stessa pausa. Ammesso solo verso una variante di quello
    /// proposto: è una scelta sul *come*, non un modo di scegliersi il più corto.
    @discardableResult
    /// - Parameter force: salta il controllo sulle varianti. Serve al passaggio al movimento più
    ///   duro proposto dalla progressione, che è una **scala** e non una variante laterale: da
    ///   crunch si sale a sit-up, che nell'elenco delle alternative del crunch non c'è.
    public mutating func swapExercise(to kind: ExerciseKind, now: Date, force: Bool = false) -> Bool {
        guard phase == .breaking, var current = plan else { return false }
        guard force || current.exercise.kind.variants.contains(kind) else { return false }
        let factor = current.circuitActive
            ? settings.rampFactor(now: now) * ExercisePlanner.circuitFactor
            : settings.rampFactor(now: now)
        current.exercise = Exercise(kind: kind, reps: Ramp.reps(for: kind, factor: factor, sex: settings.sex))
        // Dentro il circuito la stazione sostituita è quella che va nel registro: senza questa
        // riga il registro scriverebbe l'esercizio proposto e non quello davvero fatto.
        if current.circuitActive, current.circuit.indices.contains(current.stationIndex) {
            current.circuit[current.stationIndex] = current.exercise
        }
        plan = current
        exerciseDone = false
        exerciseBaseline = timer
        return true
    }

    public var canPostpone: Bool {
        (phase == .warning || phase == .breaking) && postponesUsed < settings.cadence.postponesAllowed
    }

    @discardableResult
    public mutating func postpone() -> [EngineEvent] {
        guard canPostpone, let current = plan else { return [] }
        postponesUsed += 1
        phase = .postponed
        timer = settings.cadence.postponeSeconds
        // Stessa incoerenza di `setPaused`, stesso rimedio: rinviare lascia il piano in piedi ma
        // non può lasciare in piedi «esercizio fatto», o per due minuti lo stato dice che hai
        // finito una pausa che deve ancora ricominciare. Le ripetizioni già confermate sono al
        // sicuro, perché il registro le ha scritte alla conferma e non alla chiusura.
        exerciseDone = false
        exerciseBaseline = 0
        return [.postponed(current)]
    }

    /// L'uscita d'emergenza vera: immediata, senza digitare niente.
    ///
    /// Esiste perché una pausa piena può cascare nel momento sbagliato — una chiamata che entra,
    /// qualcuno alla porta — e in quel momento nessuno digita una frase. Il prezzo non è
    /// l'attrito: è che **viene contata e compare nelle statistiche**. Un'uscita che non lascia
    /// traccia si usa sempre; una che lascia traccia si usa quando serve.
    @discardableResult
    public mutating func emergencyExit() -> [EngineEvent] {
        guard phase == .breaking || phase == .warning, let current = plan else { return [] }
        return finish(current, event: .breakSkipped(current, .emergency))
    }

    /// L'uscita con frase. La frase va digitata per esteso: è attrito, non un pulsante.
    @discardableResult
    public mutating func escape(phrase: String) -> [EngineEvent] {
        guard phase == .breaking || phase == .warning, let current = plan else { return [] }
        let typed = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let expected = settings.escapePhrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !expected.isEmpty, typed == expected else { return [] }
        return finish(current, event: .breakSkipped(current, .escapePhrase))
    }

    /// Pausa a richiesta, dal menu. Salta l'attesa dell'intervallo, l'orario e il radar delle
    /// call: l'hai chiesta tu, e una richiesta esplicita batte ogni euristica.
    @discardableResult
    public mutating func forceBreakNow(now: Date, kind: BreakKind? = nil) -> [EngineEvent] {
        guard phase == .working else { return [] }
        let newPlan = planNextBreak(now: now, forcedKind: kind)
        plan = newPlan
        postponesUsed = 0
        autoDefersUsed = 0
        exerciseDone = false
        idleDuringBreak = 0
        return startBreak(newPlan, now: now, environment: .quiet, forced: true)
    }

    // MARK: - Stato che sopravvive alla chiusura

    public private(set) var launchCount: Int = 0

    public var snapshot: EngineSnapshot {
        EngineSnapshot(breakIndex: breakIndex, microsSinceLong: microsSinceLong,
                       launchCount: launchCount, activeSeconds: clock.activeSeconds)
    }

    /// Un avvio in più. Le frasi non dipendono più da questo numero — le estrae il mazzo, che è
    /// casuale e senza ripetizioni — ma il conteggio resta: dice quante volte l'app è partita, e
    /// serve a distinguere un riavvio da una sessione lunga.
    public mutating func countLaunch() { launchCount += 1 }

    /// Come interpretare il tempo che dichiari.
    public enum SeatedMode: String, CaseIterable, Sendable {
        /// «Sono seduto da 100 minuti in tutto»: il conto diventa esattamente quello.
        case total
        /// «Aggiungine altri 20 a quello che hai già»: si somma.
        case add
        // Qui c'era un `title` italiano-e-basta che non chiamava nessuno: le due voci del
        // selettore le scrive `DeclareSeatedView` con `L.t`. Tolto invece di tradotto — una
        // stringa a schermo che nessuna vista mostra è solo un posto in più da sbagliare.
    }

    /// «Sono già al computer da un'ora, mi sono scordato di aprirti.»
    ///
    /// Due modi, e servono entrambi perché sono due frasi diverse: *«mi sono seduto alle 13, in
    /// tutto sono 100 minuti»* è un **totale** — e deve poter anche **abbassare** il conto, se
    /// prima avevi dichiarato troppo. *«aggiungi mezz'ora»* è una **somma**. La prima versione
    /// prendeva sempre il massimo: non si poteva correggere all'ingiù, e un errore restava lì.
    ///
    /// **Dichiarare mentre l'app è sospesa la riprende.** Non è una comodità: è l'unico modo di
    /// non perdere il numero appena scritto. Il caso vero — sospendi, ti dimentichi di riprendere,
    /// e quando te ne accorgi dichiari i minuti — finiva contro `setPaused(false)`, che azzera
    /// l'orologio: i 20 minuti dichiarati sparivano **dopo** essere stati accettati, e il conto
    /// tornava a 30. Dire «sono al computer da 20 minuti» *è* dire che non sei più sospeso.
    @discardableResult
    public mutating func declareTimeAlreadySeated(_ seconds: Double, mode: SeatedMode = .total) -> Double {
        let value = max(0, seconds)
        // Prima del seed, o la ripresa lo cancellerebbe: `setPaused(false)` fa `clock.reset()`.
        if phase == .paused { phase = .working }
        let target = mode == .total ? value : clock.activeSeconds + value
        clock.seed(activeSeconds: target)
        return target
    }

    /// «Ne ho già fatta una, l'app era chiusa.»
    ///
    /// Fa avanzare **solo** rotazione e ciclo micro/piena. **Non tocca il conto del tempo**, e la
    /// prima versione sbagliava proprio qui: azzerava il contatore, buttando via i 24 minuti che
    /// l'app aveva misurato davvero. Ma dichiarare una pausa passata è *dare un'informazione*,
    /// non prendersi una pausa adesso — e il tempo trascorso da allora l'orologio l'ha contato
    /// bene da solo. Per la pausa che stai facendo ora c'è «Fai una pausa adesso».
    ///
    /// **Non** accredita ripetizioni: quante ne hai fatte davvero non lo so, e un registro che se
    /// lo inventa non serve a niente.
    public mutating func recordCompletedBreak(kind: BreakKind, now: Date = Date()) {
        breakIndex += 1
        if kind == .long { microsSinceLong = 0 } else { microsSinceLong += 1 }
    }

    /// «Quella pausa l'avevo segnata a mano, ma poi è arrivata davvero.»
    ///
    /// Serve perché la doppia contabilità è un caso reale, non teorico: segni una pausa fatta,
    /// poi lo schermo si copre e la conta di nuovo. Toglie l'ultima segnata dal ciclo.
    @discardableResult
    public mutating func undoDeclaredBreak(kind: BreakKind) -> Bool {
        guard breakIndex > 0 else { return false }
        breakIndex -= 1
        if kind == .long {
            microsSinceLong = max(0, settings.cadence.longEveryNBreaks - 1)
        } else {
            microsSinceLong = max(0, microsSinceLong - 1)
        }
        return true
    }

    /// Esito del ripristino, per poterlo dire invece di farlo in silenzio.
    public enum Resume: Equatable, Sendable {
        /// L'app è ripartita entro la finestra di grazia: il conto riprende da dov'era.
        case continued(seconds: Double, afterGap: Double)
        /// Troppo tempo fuori: quello è stato un vero stacco, si riparte da zero.
        case restarted(afterGap: Double)
    }

    /// Riprende rotazione **e conto del tempo** da dove li aveva lasciati l'esecuzione precedente.
    ///
    /// La finestra di grazia vale quanto una pausa piena, e non è una coincidenza: sotto quella
    /// soglia l'assenza è un riavvio dell'app (un aggiornamento, un crash, un `quit` per sbaglio);
    /// sopra, per la logica di Otium **quello è già una pausa vera** — e allora ripartire da zero
    /// non è una perdita, è la risposta giusta.
    @discardableResult
    public mutating func restore(_ snapshot: EngineSnapshot, now: Date = Date()) -> Resume {
        breakIndex = max(0, snapshot.breakIndex)
        microsSinceLong = max(0, snapshot.microsSinceLong) % max(1, settings.cadence.longEveryNBreaks)
        launchCount = max(0, snapshot.launchCount)

        let gap = max(0, now.timeIntervalSince(snapshot.savedAt))
        guard gap <= settings.resumeGraceSeconds, snapshot.activeSeconds > 0 else {
            return .restarted(afterGap: gap)
        }
        clock.seed(activeSeconds: snapshot.activeSeconds)
        return .continued(seconds: snapshot.activeSeconds, afterGap: gap)
    }

    public mutating func setPaused(_ paused: Bool) {
        if paused {
            phase = .paused
            plan = nil
            timer = 0
            // **Lo stato dell'esercizio va azzerato come lo azzera `finish`.** Restava «fatto»
            // con il piano già a nil, cioè un esercizio confermato dentro una pausa che non
            // esiste: incoerenza trovata dal fuzz il 2026-07-28, dopo `forceLong → non tutte →
            // sospendi`. Non si vedeva prima perché l'unica via per confermare passava dal
            // cancello del tempo minimo, che in una sequenza casuale non si apre quasi mai.
            exerciseDone = false
            idleDuringBreak = 0
            exerciseBaseline = 0
            singleExercise = nil
        } else if phase == .paused {
            phase = .working
            clock.reset()
        }
    }

    // MARK: - Lettura per l'interfaccia

    /// Che tipo sarà il prossimo break, senza pianificarlo.
    public var nextBreakKind: BreakKind {
        (microsSinceLong + 1 >= settings.cadence.longEveryNBreaks) ? .long : .micro
    }

    public var secondsUntilNextBreak: Double {
        clock.secondsRemaining(of: settings.cadence.intervalSeconds)
    }
}
