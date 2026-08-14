import Foundation

/// Il periodo che si sta guardando.
public enum StatsPeriod: String, CaseIterable, Sendable {
    case day, week, month
    /// **Tutto il registro.** Serve alla pagina dell'allenamento, dove «esercizi svolti» deve
    /// dire cosa hai allenato da quando usi l'app, non cosa hai fatto stamattina: la lista degli
    /// esercizi accanto a un andamento di settimane, filtrata su oggi, si legge come un errore.
    case all

    public var title: String {
        switch self {
        case .day: return L.t("Oggi", "Today")
        case .week: return L.t("Settimana", "Week")
        case .month: return L.t("Mese", "Month")
        case .all: return L.t("Sempre", "All time")
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
        case .all:
            return .distantPast
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

    /// **Giorni consecutivi, fino a oggi, con almeno una pausa fatta — e si legge su TUTTO il
    /// registro, non sulla finestra scelta.**
    ///
    /// Era una proprietà calcolata sui soli `moments`, cioè su quello che la finestra aveva già
    /// lasciato passare, e il difetto che ne usciva era grosso e silenzioso: con «Oggi» davanti
    /// la serie non poteva superare **1** per costruzione, quindi la medaglia «giorni di fila»
    /// — che compare solo sopra 1 — su quella scheda non è mai comparsa; e con «Settimana» la
    /// serie si accorciava al lunedì, perché la finestra comincia lunedì e la domenica prima
    /// restava fuori. Trenta giorni di fila letti come uno.
    ///
    /// A trovarlo è stato un test che falliva **un giorno su sette**: scritto con `Date()` vero,
    /// passava dal martedì alla domenica e diventava rosso il lunedì. Un test così non è rumore
    /// da zittire — è la spia che qualcosa dipende dal giorno in cui gira.
    public var streakDays: Int = 0

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
                // Una pausa segnata a mano e poi tolta sparisce dai conti, **e si porta via le
                // proprie ripetizioni**. Prima restavano: il totale del giorno continuava a
                // includere il lavoro di una pausa che l'utente aveva appena dichiarato mai
                // avvenuta, e il numero grosso in cima al recap era più alto della verità.
                // Trovato nell'audit del 2026-07-28.
                if let index = s.moments.lastIndex(where: { $0.outcome == .completed && $0.kind == (e.breakKind ?? .micro) }) {
                    let tolto = s.moments.remove(at: index)
                    s.completed = max(0, s.completed - 1)
                    if let kind = tolto.exercise, let reps = tolto.reps {
                        s.repsByExercise[kind, default: 0] -= reps
                        if s.repsByExercise[kind] ?? 0 <= 0 { s.repsByExercise[kind] = nil }
                        if kind.isVigorous { s.vigorousBouts = max(0, s.vigorousBouts - 1) }
                    }
                }
            case .postponed, .deferred:
                break
            }
        }
        // Le correzioni sono righe negative, ed è giusto che lo siano: correggere all'ingiù è
        // metà del motivo per cui esistono. Ma il totale mostrato non può finire sotto zero —
        // «meno venti minuti davanti al Mac» non vuol dire niente, e basta una correzione
        // esagerata per arrivarci. Trovato nell'audit del 2026-07-28.
        s.activeSeconds = max(0, s.activeSeconds)
        s.moments.sort { $0.at > $1.at }
        // **`entries`, non `window`**: la serie è una proprietà della cronologia, non della
        // finestra che stai guardando. E con `now` e `calendar` iniettati, non `Date()` e
        // `.current` presi di nascosto: un numero che dipende dall'orologio vero non si può
        // provare, ed è esattamente il motivo per cui l'unico test che lo toccava era rosso il
        // lunedì e verde negli altri sei giorni.
        s.streakDays = streak(in: entries, now: now, calendar: calendar)
        return s
    }

    /// Giorni consecutivi, fino a `now`, con almeno una pausa fatta.
    ///
    /// **Stessa definizione di pausa del resto dell'app.** `interruptions` dice che una pausa è
    /// `completed + natural` — alzarsi da soli conta, ed è il comportamento che l'app dice di
    /// voler premiare. Guardando solo le `completed`, una giornata passata ad alzarsi
    /// spontaneamente spezzerebbe la serie: l'app punirebbe ciò che dichiara di apprezzare.
    ///
    /// **Le correzioni valgono anche qui**: una pausa dichiarata e poi tolta non tiene in piedi
    /// la sua giornata. Si conta per giorno e l'`undo` scala di uno, come fa il resto dei conti —
    /// e non si potrebbe leggere dai soli `moments`, che è ciò che questa funzione ha smesso di
    /// fare.
    private static func streak(in entries: [LedgerEntry], now: Date, calendar: Calendar) -> Int {
        var perGiorno: [Date: Int] = [:]
        for e in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let giorno = calendar.startOfDay(for: e.timestamp)
            switch e.type {
            case .completed, .natural: perGiorno[giorno, default: 0] += 1
            case .undo: perGiorno[giorno] = max(0, (perGiorno[giorno] ?? 0) - 1)
            default: break
            }
        }
        var streak = 0
        var giorno = calendar.startOfDay(for: now)
        while (perGiorno[giorno] ?? 0) > 0 {
            streak += 1
            guard let precedente = calendar.date(byAdding: .day, value: -1, to: giorno) else { break }
            giorno = precedente
        }
        return streak
    }

    /// I benefici **possibili**, agganciati ciascuno al suo studio e alla sua soglia.
    ///
    /// Regola di scrittura, e vale più del codice: qui non si dice mai «hai ottenuto». Si dice
    /// cosa hanno misurato gli studi su chi ha fatto numeri come questi. La differenza fra le due
    /// frasi è la differenza fra un'app onesta e un'app che vende fumo — e siccome è proprio la
    /// promessa su cui questa app si regge, sbagliarla qui costerebbe tutto il resto.
    /// «1 interruzioni» fa sembrare fatta male anche la parte fatta bene. In italiano lo zero
    /// vuole il plurale e l'uno il singolare.
    ///
    /// **Era italiano e basta, come `Praise`.** Queste parole arrivano a schermo dentro una
    /// struttura dati, non dentro una `Text`, e il lettore della lingua guarda le viste: è la
    /// stessa specie di difetto vista all'uso il 2026-07-29, trovata lo stesso giorno
    /// rendendo la finestra delle statistiche in inglese e guardandola.
    private static func plural(_ n: Int, it one: String, _ many: String,
                               en oneEN: String, _ manyEN: String) -> String {
        L.language == .italian ? (n == 1 ? one : many) : (n == 1 ? oneEN : manyEN)
    }

    /// «· 8,4 al giorno». Separato perché il formato del numero e la parola cambiano insieme.
    private static func alGiorno(_ valore: Double) -> String {
        L.t(String(format: " · %.1f al giorno", valore), String(format: " · %.1f a day", valore))
    }

    public static func insights(for stats: PeriodStats, target: Int = 3) -> [Insight] {
        var out: [Insight] = []
        let perDay = Double(stats.interruptions) / Double(max(1, stats.days))

        out.append(Insight(
            id: "interruzioni",   // lingua: ok identificativo della scheda, non un testo
            headline: L.t("\(stats.interruptions) \(plural(stats.interruptions, it: "interruzione", "interruzioni", en: "interruption", "interruptions")) della sedentarietà",
                          "\(stats.interruptions) sitting \(plural(stats.interruptions, it: "interruzione", "interruzioni", en: "interruption", "interruptions"))")
                    + (stats.days > 1 ? alGiorno(perDay) : ""),
            detail: perDay >= 8
                ? L.t("Un ritmo vicino a quello dell'unica dose che nello studio di Duran ha appiattito i picchi glicemici: un'interruzione ogni 30 minuti di lavoro.",
                      "A pace close to the only dose that flattened glucose spikes in Duran's trial: one interruption every 30 minutes of work.")
                : L.t("Duran ha visto l'effetto sulla glicemia solo con interruzioni ogni 30 minuti — cioè circa 8-12 in una giornata di lavoro piena.",
                      "Duran only saw the effect on blood sugar with interruptions every 30 minutes, that is roughly 8-12 in a full working day."),
            study: Evidence.sittingInterval,
            met: perDay >= 8
        ))

        let vigorousPerDay = Double(stats.vigorousBouts) / Double(max(1, stats.days))
        out.append(Insight(
            id: "vigorosi",
            headline: "\(stats.vigorousBouts) \(plural(stats.vigorousBouts, it: "sessione intensa", "sessioni intense", en: "vigorous bout", "vigorous bouts"))"
                    + (stats.days > 1 ? alGiorno(vigorousPerDay) : ""),
            detail: vigorousPerDay >= Double(target)
                ? L.t("Nello studio su 25.241 adulti non sportivi, tre sessioni intense quotidiane da 1-2 minuti si associavano a circa il 40% di mortalità in meno a sette anni.",
                      "In the study of 25,241 non-exercising adults, three daily 1-2 minute vigorous bouts were associated with about 40% lower mortality over seven years.")
                : L.t("Il bersaglio dello studio di Stamatakis è tre al giorno: sotto, l'associazione misurata era più debole.",
                      "Stamatakis's target is three a day: below that, the measured association was weaker."),
            study: Evidence.vilpa,
            met: vigorousPerDay >= Double(target)
        ))

        if stats.totalReps > 0 {
            out.append(Insight(
                id: "muscolo",
                headline: L.t("\(stats.totalReps) \(plural(stats.totalReps, it: "ripetizione", "ripetizioni", en: "rep", "reps")) · circa \(Int(stats.estimatedMovementSeconds / 60)) \(plural(Int(stats.estimatedMovementSeconds / 60), it: "minuto", "minuti", en: "minute", "minutes")) di movimento",
                              "\(stats.totalReps) \(plural(stats.totalReps, it: "ripetizione", "ripetizioni", en: "rep", "reps")) · about \(Int(stats.estimatedMovementSeconds / 60)) \(plural(Int(stats.estimatedMovementSeconds / 60), it: "minuto", "minuti", en: "minute", "minutes")) of movement"),
                detail: L.t("In Gao 2024 il beneficio glicemico seguiva l'attivazione muscolare, non i passi: sono le ripetizioni a contare, non la distanza percorsa. I minuti qui sono una stima dal ritmo di esecuzione, non un cronometro.",
                            "In Gao 2024 the glycaemic benefit followed muscle activation, not steps: it is the reps that count, not the distance covered. The minutes here are an estimate from the pace of execution, not a stopwatch."),
                study: Evidence.squatsBeatWalking,
                met: true
            ))
        }

        if stats.skipped + stats.emergency > 0 {
            let saltate = stats.skipped + stats.emergency
            out.append(Insight(
                id: "saltate",
                headline: L.t("\(saltate) pause saltate", "\(saltate) breaks skipped")
                        + (stats.emergency > 0
                           ? L.t(" · \(stats.emergency) d'emergenza", " · \(stats.emergency) emergency")
                           : ""),
                detail: saltate > stats.completed
                    ? L.t("Più saltate che fatte: la cadenza è sbagliata, non tu. Allungala nelle preferenze — una pausa che salti sempre non è una pausa, è un rumore.",
                          "More skipped than done: it is the cadence that is wrong, not you. Lengthen it in preferences: a break you always skip is not a break, it is noise.")
                    : L.t("Le uscite d'emergenza sono contate apposta: servono, ma se diventano la regola vuol dire che l'orario o la cadenza vanno cambiati.",
                          "Emergency exits are counted on purpose: they are useful, but if they become the rule it means the hours or the cadence need changing."),
                study: nil,
                met: saltate <= stats.completed
            ))
        }

        return out
    }
}
