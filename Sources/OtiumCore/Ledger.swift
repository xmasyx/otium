import Foundation

public enum EntryType: String, Codable, Equatable, Sendable {
    /// Battito del tempo attivo: è questo che risponde a "quanto sono stato davvero al computer".
    case active
    case completed
    case skipped
    case natural
    case postponed
    case deferred
    /// Una pausa segnata a mano e poi tolta. Il registro è append-only: non si cancella una
    /// riga, se ne scrive una che la annulla — così la storia resta leggibile com'è andata.
    case undo
    /// **Ripetizioni confermate.** Porta le sue ripetizioni e **non** conta come pausa: quattro
    /// stazioni di circuito sono una pausa sola, e un esercizio confermato a metà pausa non è
    /// una pausa finita. Si scrive nell'istante in cui premi «Fatto», non alla chiusura della
    /// pausa: il recap aperto nel frattempo deve già vederle.
    case exerciseDone
    /// Come sopra, ma è il nome vecchio: le stazioni di circuito scritte prima del 2026-07-27
    /// hanno questo tipo. Resta solo per non perdere quelle righe in lettura — il registro è
    /// append-only, e una riga che non si decodifica è una riga persa.
    case circuitStation
}

public struct LedgerEntry: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let type: EntryType
    public let breakKind: BreakKind?
    public let exercise: ExerciseKind?
    public let reps: Int?
    public let seconds: Double?
    public let reason: String?

    public init(
        timestamp: Date,
        type: EntryType,
        breakKind: BreakKind? = nil,
        exercise: ExerciseKind? = nil,
        reps: Int? = nil,
        seconds: Double? = nil,
        reason: String? = nil
    ) {
        self.timestamp = timestamp
        self.type = type
        self.breakKind = breakKind
        self.exercise = exercise
        self.reps = reps
        self.seconds = seconds
        self.reason = reason
    }
}

/// Il riassunto di una giornata, ricostruito dal registro. Nessuno stato parallelo da tenere
/// allineato: c'è una sola verità su disco, e questa è la sua lettura.
public struct DailySummary: Equatable, Sendable {
    public init() {}

    public var activeSeconds: Double = 0
    public var completed: Int = 0
    public var skipped: Int = 0
    public var natural: Int = 0
    public var postponed: Int = 0
    public var deferred: Int = 0
    public var vigorousBouts: Int = 0
    public var repsByExercise: [ExerciseKind: Int] = [:]
    /// **Quante delle pause completate erano di respiro.** Sottoinsieme di `completed`, non un
    /// totale a parte: una pausa Zen è una pausa, e sommarla di nuovo la conterebbe due volte.
    /// Esiste perché senza di lei una giornata tutta in ufficio mostrerebbe pause completate e
    /// zero ripetizioni, che dal solo numero è indistinguibile da una giornata di pause saltate.
    public var zenBreaks: Int = 0

    public var totalReps: Int { repsByExercise.values.reduce(0, +) }

    public var activeHoursLabel: String {
        let total = Int(activeSeconds)
        return String(format: "%dh %02dm", total / 3600, (total % 3600) / 60)
    }
}

/// Registro append-only in JSONL. Append-only per la stessa ragione per cui lo è ovunque nel
/// sistema: una riga scritta non si riscrive, quindi due processi non possono corrompersi a vicenda
/// e la storia di ieri non cambia mai.
public final class Ledger: @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "app.otium.ledger")
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL = Paths.ledgerFile) {
        self.url = url
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public var fileURL: URL { url }

    @discardableResult
    public func append(_ entry: LedgerEntry) -> Bool {
        queue.sync {
            guard var data = try? encoder.encode(entry) else { return false }
            data.append(0x0A)
            let fm = FileManager.default
            let dir = url.deletingLastPathComponent()
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                // **Il `try?` qui diceva sempre di sì.** Con il disco pieno, o il file senza
                // permesso di scrittura, la riga non veniva scritta e `append` restituiva `true`
                // lo stesso: il lavoro spariva e nessuno lo sapeva. Trovato nell'audit del
                // 2026-07-28. Adesso il risultato è il risultato.
                do {
                    try handle.write(contentsOf: data)
                    return true
                } catch {
                    return false
                }
            }
            // **Il ripiego serve solo a creare il file la prima volta.**
            //
            // Prima era incondizionato, e questa è la riga più pericolosa che l'audit del
            // 2026-07-28 abbia trovato: `write(to:options:.atomic)` scrive un file nuovo e lo
            // rinomina sopra il vecchio, e la rinomina riesce anche quando il file esistente non
            // è scrivibile, perché il permesso che conta è quello della **cartella**. Cioè: un
            // registro reso di sola lettura — da un backup, da un errore, da chiunque — non
            // faceva fallire la scrittura, la faceva riuscire **sostituendo mesi di storia con
            // una riga sola**. Il difetto era invisibile: `append` restituiva `true`.
            guard !fm.fileExists(atPath: url.path) else { return false }
            return (try? data.write(to: url, options: .atomic)) != nil
        }
    }

    /// Quante righe del registro non si sono lasciate leggere, all'ultima lettura.
    ///
    /// Saltare una riga rotta è la cosa giusta — un registro che si rifiuta di aprirsi per una
    /// riga sbagliata perde tutto il resto — ma **saltarla in silenzio** no: le statistiche
    /// verrebbero fuori più basse del vero e nessuno saprebbe perché. Qui il numero resta, e chi
    /// mostra i numeri può dirlo.
    public private(set) var unreadableLines = 0

    public func entries() -> [LedgerEntry] {
        queue.sync {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            var scartate = 0
            let righe: [LedgerEntry] = text.split(separator: "\n").compactMap { line in
                guard let data = line.data(using: .utf8),
                      let entry = try? decoder.decode(LedgerEntry.self, from: data)
                else {
                    if !line.trimmingCharacters(in: .whitespaces).isEmpty { scartate += 1 }
                    return nil
                }
                return entry
            }
            unreadableLines = scartate
            return righe
        }
    }

    public func summary(for day: Date = Date(), calendar: Calendar = .current) -> DailySummary {
        Self.summarize(entries().filter { calendar.isDate($0.timestamp, inSameDayAs: day) })
    }

    public static func summarize(_ entries: [LedgerEntry]) -> DailySummary {
        var s = DailySummary()
        for e in entries {
            switch e.type {
            case .active:
                s.activeSeconds += e.seconds ?? 0
            case .completed:
                s.completed += 1
                if e.reason?.hasPrefix("zen:") == true { s.zenBreaks += 1 }
                if let kind = e.exercise, let reps = e.reps {
                    s.repsByExercise[kind, default: 0] += reps
                    if kind.isVigorous { s.vigorousBouts += 1 }
                }
            case .skipped:
                s.skipped += 1
            case .natural:
                s.natural += 1
            case .postponed:
                s.postponed += 1
            case .deferred:
                s.deferred += 1
            case .exerciseDone, .circuitStation:
                if let kind = e.exercise, let reps = e.reps {
                    s.repsByExercise[kind, default: 0] += reps
                    if kind.isVigorous { s.vigorousBouts += 1 }
                }
            case .undo:
                s.completed = max(0, s.completed - 1)
                // L'annullamento non dice *quale* pausa toglie, quindi il sottoinsieme si limita
                // invece di indovinare: senza questa riga una giornata annullata potrebbe mostrare
                // più pause di respiro che pause, che è un numero impossibile.
                s.zenBreaks = min(s.zenBreaks, s.completed)
            }
        }
        return s
    }

    /// Traduce un evento del motore nella riga di registro corrispondente. `nil` per gli eventi
    /// che non meritano una riga (il preavviso, l'inizio del break: sono rumore).
    public static func entry(for event: EngineEvent, now: Date) -> LedgerEntry? {
        switch event {
        // `deferredBreakDue` non lascia riga per la stessa ragione del preavviso: è un avviso,
        // non un fatto. Il fatto — la pausa rimandata — l'ha già scritto `autoDeferred`, e
        // scriverlo di nuovo gonfierebbe il conto dei rinvii con l'atto di finirli.
        // `callWatchdog` non lascia riga per la stessa ragione: è un sospetto sul mondo, non un
        // fatto sulla tua giornata, e il registro deve poter essere letto come cronologia di
        // quello che hai fatto davvero.
        // `postponeWarning` sta con loro, e vale la pena dirlo: il rinvio l'ha già scritto
        // `postponed`, e questo evento è solo la sua ultima parte. Una riga qui conterebbe due
        // volte lo stesso rinvio.
        case .warningStarted, .breakStarted, .deferredBreakDue, .breakTimeOver, .callWatchdog,
             .postponeWarning:
            return nil
        case .exerciseConfirmed(let exercise):
            return LedgerEntry(timestamp: now, type: .exerciseDone,
                               exercise: exercise.kind, reps: exercise.reps)
        case .breakCompleted(let plan):
            // **Una pausa Zen è una pausa, e non è un esercizio.** È la terza strada fra le due
            // sbagliate: scriverci dentro l'esercizio del turno sporcherebbe lo storico con
            // ripetizioni mai fatte, e non scrivere niente farebbe sembrare saltata una pausa che
            // hai fatto. Qui la riga c'è e conta come pausa, `exercise` resta vuoto — quindi
            // nessuna ripetizione e nessun conteggio di sessioni intense può attaccarsi — e il
            // `reason` dice quale respiro era.
            if let respiro = plan.breath {
                return LedgerEntry(
                    timestamp: now, type: .completed, breakKind: plan.kind,
                    exercise: nil, reps: nil, reason: "zen:\(respiro.rawValue)"
                )
            }
            // **Senza ripetizioni**: quelle hanno già la loro riga, scritta quando le hai
            // confermate. Qui resta il nome dell'esercizio, che serve alla cronologia a dire
            // *cosa* era quella pausa; il numero no, o finirebbe contato due volte.
            // Le righe scritte prima del 2026-07-27 hanno ancora `reps` qui, e continuano a
            // contare: il registro non si riscrive.
            return LedgerEntry(
                timestamp: now, type: .completed, breakKind: plan.kind,
                exercise: plan.exercise.kind, reps: nil,
                reason: plan.circuitActive ? "circuito" : nil
            )
        case .breakSkipped(let plan, let reason):
            return LedgerEntry(
                timestamp: now, type: .skipped, breakKind: plan.kind,
                exercise: plan.exercise.kind, reps: nil, seconds: nil, reason: reason.rawValue
            )
        case .naturalBreak(let seconds, let creditedLong):
            return LedgerEntry(
                timestamp: now, type: .natural, breakKind: creditedLong ? .long : .micro,
                seconds: seconds
            )
        case .postponed(let plan):
            return LedgerEntry(timestamp: now, type: .postponed, breakKind: plan.kind)
        case .autoDeferred(let plan, let reason):
            return LedgerEntry(
                timestamp: now, type: .deferred, breakKind: plan.kind, reason: reason
            )
        }
    }
}
