import Foundation

/// Il conto alla rovescia di una **tenuta**: plank, plank laterale, hollow hold.
///
/// Nasce da una mia richiesta precisa (2026-07-31): *«45 secondi di plank, e vorrei che
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
    /// in cui è già ora. L'ho chiesto con due parole, «detto prima».
    public static let switchWarningSeconds: Double = 3
    /// Il tempo per girarsi, **fra un lato e l'altro**.
    ///
    /// Prima non c'era: il secondo lato cominciava nell'istante stesso in cui finiva il primo, e i
    /// secondi che passavi a rimetterti in posizione se li mangiava il lato nuovo. Venti secondi
    /// per lato diventavano venti di qua e sedici di là, in silenzio. Deciso il
    /// 2026-08-08: *«al cambio lato deve darmi 5 secondi per mettermi in posizione, ma senza dover
    /// cliccare, automaticamente»* — ed è la stessa finestra che c'è già all'inizio, per lo stesso
    /// motivo. **La tenuta si allunga di cinque secondi, il lavoro no**: venti per lato restano
    /// venti per lato, che è il numero scritto sullo schermo.
    public static let switchPrepareSeconds: Double = 5

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
        /// `secondsLeft` è il tempo di **tenuta** che resta, senza i cinque secondi del cambio:
        /// contarli come tenuta prometterebbe uno sforzo che in quel momento non stai facendo.
        case holding(side: Int, secondsLeft: Int)
        /// Il primo lato è finito e ti stai girando. `secondsLeft` scende da 5 a 1, da solo.
        case switching(secondsLeft: Int)
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
        /// Fermati e girati: qui comincia la finestra per rimettersi in posizione.
        case switchSide
        /// Il secondo lato comincia adesso. È il gemello di `start`, e sta a sé perché i due
        /// momenti si contano separatamente: un suono che esce due volte con lo stesso nome è
        /// indistinguibile da un suono che esce due volte per sbaglio.
        case secondSideStart
        /// Finita.
        case end
    }

    /// L'istante in cui la tenuta comincia davvero.
    public var holdStart: Date { startedAt.addingTimeInterval(Self.prepareSeconds) }
    /// L'istante in cui **finisce il primo lato**, cioè quando ti giri. `nil` se l'esercizio non
    /// ha due lati. Da qui parte la finestra per rimettersi in posizione, non il secondo lato.
    public var switchAt: Date? { perSide ? holdStart.addingTimeInterval(total / 2) : nil }
    /// L'istante in cui comincia davvero il secondo lato: cinque secondi dopo il cambio.
    public var secondSideStart: Date? {
        switchAt?.addingTimeInterval(Self.switchPrepareSeconds)
    }
    /// L'istante in cui è finita. Per gli esercizi a due lati comprende i cinque secondi del
    /// cambio: il tempo sotto sforzo resta `total`, ma sull'orologio ne passano cinque in più.
    public var endsAt: Date {
        holdStart.addingTimeInterval(total + (perSide ? Self.switchPrepareSeconds : 0))
    }

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
        guard perSide, let switchAt, let secondSideStart else {
            return .holding(side: 0, secondsLeft: max(0, left))
        }
        // Sul primo lato la tenuta che resta è quella che si vive: i cinque secondi del cambio
        // sono già dentro `endsAt` e vanno tolti, o il numero grande prometterebbe cinque secondi
        // di plank che nessuno farà.
        if now < switchAt {
            return .holding(side: 1, secondsLeft: max(0, left - Int(Self.switchPrepareSeconds)))
        }
        if now < secondSideStart {
            return .switching(secondsLeft: max(1, Int(ceil(secondSideStart.timeIntervalSince(now)))))
        }
        return .holding(side: 2, secondsLeft: max(0, left))
    }

    /// **Quanto manca sul lato in corso**, che è il numero che serve quando i lati sono due: il
    /// totale che scende da 40 non dice quando girarti, e girarsi è la cosa che devi sapere.
    public func secondsLeftOnCurrentSide(at now: Date) -> Int {
        guard perSide, let switchAt, let secondSideStart else {
            return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
        }
        if now < switchAt { return max(0, Int(ceil(switchAt.timeIntervalSince(now)))) }
        // Mentre ti giri il lato in corso è già quello nuovo, e quello nuovo è intero: farlo
        // scendere durante il cambio scalerebbe un tempo che non stai tenendo.
        if now < secondSideStart { return max(0, Int(ceil(total / 2))) }
        return max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    /// I suoni attraversati fra due istanti, in ordine. Estremo sinistro escluso, destro incluso:
    /// chiamandola a ogni battito con `(precedente, adesso)` ogni suono esce **una volta sola**.
    public func cues(from: Date, to: Date) -> [Cue] {
        guard to > from else { return [] }
        var out: [Cue] = []
        func crossed(_ instant: Date) -> Bool { instant > from && instant <= to }

        if crossed(holdStart) { out.append(.start) }
        if let switchAt, let secondSideStart {
            if crossed(switchAt.addingTimeInterval(-Self.switchWarningSeconds)) {
                out.append(.switchWarning)
            }
            if crossed(switchAt) { out.append(.switchSide) }
            if crossed(secondSideStart) { out.append(.secondSideStart) }
        }
        if crossed(endsAt) { out.append(.end) }
        return out
    }
}
