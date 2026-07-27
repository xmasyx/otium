import Foundation

/// Il periodo che si sta guardando.
public enum StatsPeriod: String, CaseIterable, Sendable {
    case day, week, month

    public var title: String {
        switch self {
        case .day: return "Oggi"
        case .week: return "Settimana"
        case .month: return "Mese"
        }
    }

    /// Da quando contare. Settimana e mese sono quelli **di calendario**, non "gli ultimi 7
    /// giorni": lunedì è lunedì, e il primo del mese azzera. È così che uno guarda i propri
    /// numeri, e confonderli fa sembrare l'app imprecisa quando è solo diversa.
    public func start(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .day:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        }
    }
}

/// Una pausa, come compare nella cronologia.
public struct BreakMoment: Equatable, Sendable, Identifiable {
    public let at: Date
    public let kind: BreakKind
    public let exercise: ExerciseKind?
    public let reps: Int?
    public let outcome: Outcome

    public enum Outcome: String, Sendable {
        case completed, skipped, natural, emergency
    }

    public var id: String { "\(at.timeIntervalSince1970)-\(outcome.rawValue)" }
}

/// I numeri di un periodo, ricostruiti dal registro. Nessuno stato parallelo: una sola verità
/// su disco, e questa è la sua lettura.
public struct PeriodStats: Sendable {
    public var period: StatsPeriod = .day
    public var days: Int = 1
    public var activeSeconds: Double = 0
    public var completed: Int = 0
    public var skipped: Int = 0
    public var emergency: Int = 0
    public var natural: Int = 0
    public var vigorousBouts: Int = 0
    public var repsByExercise: [ExerciseKind: Int] = [:]
    public var moments: [BreakMoment] = []

    public var totalReps: Int { repsByExercise.values.reduce(0, +) }
    /// Le interruzioni della sedentarietà: quelle che l'esercizio l'hanno visto, più quelle
    /// prese spontaneamente. Sono la grandezza che gli studi misurano.
    public var interruptions: Int { completed + natural }

    /// I minuti di movimento, stimati dal ritmo di esecuzione dichiarato per ogni esercizio.
    /// È una stima, e va detto: nessuno ha misurato quanto ci hai messo davvero.
    public var estimatedMovementSeconds: Double {
        repsByExercise.reduce(0) { $0 + Double($1.value) * $1.key.secondsPerRep }
    }

    /// Quante delle pause proposte hai davvero fatto. È il numero che falsifica la cadenza:
    /// se sta sotto la metà, non sei tu che sbagli — è l'intervallo a essere sbagliato.
    public var complianceRate: Double {
        let proposte = completed + skipped + emergency
        guard proposte > 0 else { return 0 }
        return Double(completed) / Double(proposte)
    }

    /// Le ripetizioni raggruppate per catena muscolare: dieci barre non si leggono, sei gruppi sì.
    public var repsByMuscleGroup: [(group: String, reps: Int, exercises: [(ExerciseKind, Int)])] {
        Dictionary(grouping: repsByExercise.map { ($0.key, $0.value) }, by: { $0.0.muscleGroup })
            .map { (group: $0.key,
                    reps: $0.value.reduce(0) { $0 + $1.1 },
                    exercises: $0.value.sorted { $0.1 > $1.1 }) }
            .sorted { $0.reps > $1.reps }
    }

    /// Quante pause per ora del giorno, fatte e saltate. Serve a vedere **dove** si rompe la
    /// giornata: se salti sempre fra le 15 e le 16, il problema è quell'ora, non la disciplina.
    public var byHour: [(hour: Int, done: Int, missed: Int)] {
        var done = [Int: Int](), missed = [Int: Int]()
        let cal = Calendar.current
        for m in moments {
            let h = cal.component(.hour, from: m.at)
            switch m.outcome {
            case .completed, .natural: done[h, default: 0] += 1
            case .skipped, .emergency: missed[h, default: 0] += 1
            }
        }
        let hours = Set(done.keys).union(missed.keys)
        guard let first = hours.min(), let last = hours.max() else { return [] }
        return (first...last).map { (hour: $0, done: done[$0] ?? 0, missed: missed[$0] ?? 0) }
    }

    /// Giorni consecutivi, fino a oggi, con almeno una pausa fatta.
    public var streakDays: Int {
        let cal = Calendar.current
        let giorni = Set(moments.filter { $0.outcome == .completed }.map { cal.startOfDay(for: $0.at) })
        guard !giorni.isEmpty else { return 0 }
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while giorni.contains(day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    public func label(_ seconds: Double) -> String {
        let total = Int(seconds)
        return total >= 3600
            ? String(format: "%dh %02dm", total / 3600, (total % 3600) / 60)
            : String(format: "%d min", total / 60)
    }
}

/// Cosa dicono gli studi per **numeri come questi**. Non una misura su di te.
public struct Insight: Identifiable, Sendable {
    public let id: String
    public let headline: String
    public let detail: String
    public let study: Study?
    /// `true` quando il numero raggiunto incontra la soglia dello studio; `false` quando manca.
    public let met: Bool
}

public enum Stats {

    /// I numeri del periodo **precedente**, per il confronto. Un numero da solo non dice niente:
    /// 40 ripetizioni sono tante o poche? Dipende da quante ne facevi la settimana scorsa.
    public static func previous(
        entries: [LedgerEntry],
        period: StatsPeriod,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> PeriodStats {
        let start = period.start(from: now, calendar: calendar)
        let unit: Calendar.Component = period == .day ? .day : (period == .week ? .weekOfYear : .month)
        guard let prevStart = calendar.date(byAdding: unit, value: -1, to: start) else {
            return PeriodStats(period: period)
        }
        let window = entries.filter { $0.timestamp >= prevStart && $0.timestamp < start }
        return compute(entries: window, period: period, now: start.addingTimeInterval(-1), calendar: calendar,
                       from: prevStart)
    }

    public static func compute(
        entries: [LedgerEntry],
        period: StatsPeriod,
        now: Date = Date(),
        calendar: Calendar = .current,
        from overrideStart: Date? = nil
    ) -> PeriodStats {
        let from = overrideStart ?? period.start(from: now, calendar: calendar)
        let window = entries.filter { $0.timestamp >= from && $0.timestamp <= now }

        var s = PeriodStats(period: period)
        s.days = max(1, calendar.dateComponents([.day], from: from, to: now).day.map { $0 + 1 } ?? 1)

        for e in window {
            switch e.type {
            case .active:
                s.activeSeconds += e.seconds ?? 0
            case .completed:
                s.completed += 1
                if let kind = e.exercise, let reps = e.reps {
                    s.repsByExercise[kind, default: 0] += reps
                    if kind.isVigorous { s.vigorousBouts += 1 }
                }
                s.moments.append(BreakMoment(at: e.timestamp, kind: e.breakKind ?? .micro,
                                             exercise: e.exercise, reps: e.reps, outcome: .completed))
            case .skipped:
                let emergency = e.reason == SkipReason.emergency.rawValue
                if emergency { s.emergency += 1 } else { s.skipped += 1 }
                s.moments.append(BreakMoment(at: e.timestamp, kind: e.breakKind ?? .micro,
                                             exercise: e.exercise, reps: nil,
                                             outcome: emergency ? .emergency : .skipped))
            case .natural:
                s.natural += 1
                s.moments.append(BreakMoment(at: e.timestamp, kind: e.breakKind ?? .micro,
                                             exercise: nil, reps: nil, outcome: .natural))
            // Un esercizio confermato porta ripetizioni vere, ma **non** è una pausa in più:
            // niente `completed`, niente momento nella cronologia. La pausa che lo contiene ha
            // già la sua riga, e contarla due volte falserebbe proprio il numero — pause fatte
            // contro saltate — su cui si decide se la cadenza regge.
            case .exerciseDone, .circuitStation:
                if let kind = e.exercise, let reps = e.reps {
                    s.repsByExercise[kind, default: 0] += reps
                    if kind.isVigorous { s.vigorousBouts += 1 }
                }
            case .undo:
                // Una pausa segnata a mano e poi tolta: sparisce dai conti, non resta a metà.
                if let index = s.moments.lastIndex(where: { $0.outcome == .completed && $0.kind == (e.breakKind ?? .micro) }) {
                    s.moments.remove(at: index)
                    s.completed = max(0, s.completed - 1)
                }
            case .postponed, .deferred:
                break
            }
        }
        s.moments.sort { $0.at > $1.at }
        return s
    }

    /// I benefici **possibili**, agganciati ciascuno al suo studio e alla sua soglia.
    ///
    /// Regola di scrittura, e vale più del codice: qui non si dice mai «hai ottenuto». Si dice
    /// cosa hanno misurato gli studi su chi ha fatto numeri come questi. La differenza fra le due
    /// frasi è la differenza fra un'app onesta e un'app che vende fumo — e siccome è proprio la
    /// promessa su cui questa app si regge, sbagliarla qui costerebbe tutto il resto.
    public static func insights(for stats: PeriodStats, target: Int = 3) -> [Insight] {
        var out: [Insight] = []
        let perDay = Double(stats.interruptions) / Double(max(1, stats.days))

        out.append(Insight(
            id: "interruzioni",
            headline: "\(stats.interruptions) interruzioni della sedentarietà"
                    + (stats.days > 1 ? String(format: " · %.1f al giorno", perDay) : ""),
            detail: perDay >= 8
                ? "Un ritmo vicino a quello dell'unica dose che nello studio di Duran ha appiattito i picchi glicemici: un'interruzione ogni 30 minuti di lavoro."
                : "Duran ha visto l'effetto sulla glicemia solo con interruzioni ogni 30 minuti — cioè circa 8-12 in una giornata di lavoro piena.",
            study: Evidence.sittingInterval,
            met: perDay >= 8
        ))

        let vigorousPerDay = Double(stats.vigorousBouts) / Double(max(1, stats.days))
        out.append(Insight(
            id: "vigorosi",
            headline: "\(stats.vigorousBouts) sessioni intense"
                    + (stats.days > 1 ? String(format: " · %.1f al giorno", vigorousPerDay) : ""),
            detail: vigorousPerDay >= Double(target)
                ? "Nello studio su 25.241 adulti non sportivi, tre sessioni intense quotidiane da 1-2 minuti si associavano a circa il 40% di mortalità in meno a sette anni."
                : "Il bersaglio dello studio di Stamatakis è tre al giorno: sotto, l'associazione misurata era più debole.",
            study: Evidence.vilpa,
            met: vigorousPerDay >= Double(target)
        ))

        if stats.totalReps > 0 {
            out.append(Insight(
                id: "muscolo",
                headline: "\(stats.totalReps) ripetizioni · circa \(Int(stats.estimatedMovementSeconds / 60)) minuti di movimento",
                detail: "In Gao 2024 il beneficio glicemico seguiva l'attivazione muscolare, non i passi: sono le ripetizioni a contare, non la distanza percorsa. I minuti qui sono una stima dal ritmo di esecuzione, non un cronometro.",
                study: Evidence.squatsBeatWalking,
                met: true
            ))
        }

        if stats.skipped + stats.emergency > 0 {
            let saltate = stats.skipped + stats.emergency
            out.append(Insight(
                id: "saltate",
                headline: "\(saltate) pause saltate" + (stats.emergency > 0 ? " · \(stats.emergency) d'emergenza" : ""),
                detail: saltate > stats.completed
                    ? "Più saltate che fatte: la cadenza è sbagliata, non tu. Allungala nelle preferenze — una pausa che salti sempre non è una pausa, è un rumore."
                    : "Le uscite d'emergenza sono contate apposta: servono, ma se diventano la regola vuol dire che l'orario o la cadenza vanno cambiati.",
                study: nil,
                met: saltate <= stats.completed
            ))
        }

        return out
    }
}
