import Foundation

/// Il conto alla rovescia di una **tenuta**: plank, plank laterale, hollow hold.
///
/// Nasce da una richiesta precisa del principale (2026-07-31): *«45 secondi di plank, e vorrei che
/// il tempo vada all'indietro, così so quanto devo tenere. Non lo posso far partire perché sono
/// già giù»*. Da lì scendono tutte le scelte qui dentro.
///
/// **Il tempo si legge dall'orologio, non si accumula.** Ogni fase ha un istante di scadenza, e
/// quanto manca è una sottrazione fra adesso e quello. Un contatore che scala a ogni battito
/// perde qualche decimo al minuto — poco per un'interfaccia, troppo per un numero che dice a
/// qualcuno quanto deve stare sotto sforzo, e che deve valere quanto un cronometro da palestra.
///
/// **È un valore puro, e per questo si può provare.** Nessun timer, nessun suono, nessuna vista:
/// si passa `now` e si chiede in che fase sei. Un test copre quarantacinque secondi di plank in
/// un millesimo, e i casi che nella vita capitano una volta al mese — il cambio di lato esatto,
/// l'ultimo secondo — qui capitano a ogni corsa.
public struct Hold: Equatable, Sendable {

    /// I cinque secondi fra «Pronto» e l'inizio della tenuta: il tempo di scendere.
    public static let prepareSeconds: Double = 5
    /// Quanto prima si avvisa del cambio di lato. Tre secondi perché **in plank non guardi lo
    /// schermo**: l'avviso deve arrivare in tempo per finire il lato e girarsi, non nell'istante
    /// in cui è già ora. Il principale l'ha chiesto con due parole, «detto prima».
    public static let switchWarningSeconds: Double = 3

    /// Quanto dura in tutto, in secondi. Per gli esercizi a lati alterni è il **totale**.
    public let total: Double
    /// Se il tempo va diviso in due metà uguali, una per lato.
    public let perSide: Bool
    /// Quando è stato premuto «Pronto».
    public let startedAt: Date

    public init(total: Double, perSide: Bool, startedAt: Date) {
        self.total = max(1, total)
        self.perSide = perSide
        self.startedAt = startedAt
    }

    /// Dove sei adesso.
    public enum Phase: Equatable, Sendable {
        /// Ti stai mettendo in posizione. `secondsLeft` scende da 5 a 1.
        case preparing(secondsLeft: Int)
        /// Sei sotto. `side` vale 1 o 2 per gli esercizi a lati alterni, 0 per gli altri.
        case holding(side: Int, secondsLeft: Int)
        /// Finito.
        case done
    }

    /// Un momento che merita un suono. Sono discreti apposta: la vista li confronta fra un battito
    /// e il successivo e suona quelli **attraversati**, così un battito perso non perde il suono e
    /// un battito doppio non lo raddoppia.
    public enum Cue: String, Equatable, Sendable, CaseIterable {
        /// La tenuta comincia adesso.
        case start
        /// Manca poco al cambio di lato: è l'avviso, non il cambio.
        case switchWarning
        /// Cambia lato adesso.
        case switchSide
        /// Finita.
        case end
    }

    /// L'istante in cui la tenuta comincia davvero.
    public var holdStart: Date { startedAt.addingTimeInterval(Self.prepareSeconds) }
    /// L'istante del cambio di lato. `nil` se l'esercizio non ha due lati.
    public var switchAt: Date? { perSide ? holdStart.addingTimeInterval(total / 2) : nil }
    /// L'istante in cui è finita.
    public var endsAt: Date { holdStart.addingTimeInterval(total) }

    public func phase(at now: Date) -> Phase {
        if now >= endsAt { return .done }
        if now < holdStart {
            // `ceil` e non `round`: a 4,2 secondi dalla fine della preparazione il numero da
            // mostrare è 5, perché il quinto secondo non è ancora passato. Con `round` il conto
            // partirebbe da 4 e ti darebbe un secondo in meno di quello promesso.
            let left = Int(ceil(holdStart.timeIntervalSince(now)))
            return .preparing(secondsLeft: max(1, left))
        }
        let left = Int(ceil(endsAt.timeIntervalSince(now)))
        guard perSide, let switchAt else {
            return .holding(side: 0, secondsLeft: max(0, left))
        }
        return .holding(side: now < switchAt ? 1 : 2, secondsLeft: max(0, left))
    }

    /// **Quanto manca sul lato in corso**, che è il numero che serve quando i lati sono due: il
    /// totale che scende da 40 non dice quando girarti, e girarsi è la cosa che devi sapere.
    public func secondsLeftOnCurrentSide(at now: Date) -> Int {
        guard perSide, let switchAt else {
            return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        }
        let bordo = now < switchAt ? switchAt : endsAt
        return max(0, Int(ceil(bordo.timeIntervalSince(now))))
    }

    /// I suoni attraversati fra due istanti, in ordine. Estremo sinistro escluso, destro incluso:
    /// chiamandola a ogni battito con `(precedente, adesso)` ogni suono esce **una volta sola**.
    public func cues(from: Date, to: Date) -> [Cue] {
        guard to > from else { return [] }
        var out: [Cue] = []
        func crossed(_ instant: Date) -> Bool { instant > from && instant <= to }

        if crossed(holdStart) { out.append(.start) }
        if let switchAt {
            if crossed(switchAt.addingTimeInterval(-Self.switchWarningSeconds)) {
                out.append(.switchWarning)
            }
            if crossed(switchAt) { out.append(.switchSide) }
        }
        if crossed(endsAt) { out.append(.end) }
        return out
    }
}
