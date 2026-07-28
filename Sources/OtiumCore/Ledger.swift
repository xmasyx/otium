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
                try? handle.write(contentsOf: data)
                return true
            }
            return (try? data.write(to: url, options: .atomic)) != nil
        }
    }

    public func entries() -> [LedgerEntry] {
        queue.sync {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(LedgerEntry.self, from: data)
            }
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
            }
        }
        return s
    }

    /// Traduce un evento del motore nella riga di registro corrispondente. `nil` per gli eventi
    /// che non meritano una riga (il preavviso, l'inizio del break: sono rumore).
    public static func entry(for event: EngineEvent, now: Date) -> LedgerEntry? {
        switch event {
        case .warningStarted, .breakStarted:
            return nil
        case .exerciseConfirmed(let exercise):
            return LedgerEntry(timestamp: now, type: .exerciseDone,
                               exercise: exercise.kind, reps: exercise.reps)
        case .breakCompleted(let plan):
            // **Senza ripetizioni**: quelle hanno già la loro riga, scritta quando le hai
            // confermate. Qui resta il nome dell'esercizio, che serve alla cronologia a dire
            // *cosa* era quella pausa; il numero no, o finirebbe contato due volte.
            // Le righe scritte prima del 2026-07-27 hanno ancora `reps` qui, e continuano a
            // contare: il registro non si riscrive.
            return LedgerEntry(
                timestamp: now, type: .completed, breakKind: plan.kind,
                exercise: plan.exercise.kind, reps: nil,
                // Chi l'ha chiesta finisce nel motivo: senza, il registro dice *che* una pausa
                // è avvenuta ma non *perché*, e «me ne ha proposta un'altra, perché?» resta
                // senza risposta anche avendo il file davanti.
                reason: [plan.circuitActive ? "circuito" : nil,
                         plan.requested ? "richiesta" : nil]
                        .compactMap { $0 }.joined(separator: "+").nilIfEmpty
            )
        case .breakSkipped(let plan, let reason):
            return LedgerEntry(
                timestamp: now, type: .skipped, breakKind: plan.kind,
                exercise: plan.exercise.kind, reps: nil, seconds: nil,
                reason: plan.requested ? "\(reason.rawValue)+richiesta" : reason.rawValue
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

extension String {
    /// Una stringa vuota nel registro è rumore: meglio l'assenza del campo.
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
