import Foundation

/// Com'è andata l'ultima volta che hai fatto questo esercizio.
public enum Attempt: String, Codable, Sendable {
    /// Le hai fatte tutte.
    case complete
    /// Non tutte. Il numero vero finisce nel registro, e questo è il segnale che serve al motore.
    case partial
}

/// Quanto sei avanti su un esercizio, e quante conferme di fila hai messo insieme.
public struct ExerciseProgress: Codable, Equatable, Sendable {
    /// Il moltiplicatore **oltre** il 100%. Parte da 1.0 e non scende mai sotto.
    public var level: Double
    /// Conferme piene consecutive. Negativo = mancate consecutive.
    public var streak: Int

    public init(level: Double = 1.0, streak: Int = 0) {
        self.level = max(1.0, level)
        self.streak = streak
    }
}

/// **La crescita dopo il 100%, e perché è fatta così.**
///
/// Le fonti, verificate il 2026-07-28 e non citate a memoria:
///
/// - Plotkin, Coleman, Van Every et al., *«Progressive overload without progressing load? The
///   effects of load or repetition progression on muscular adaptations»*, PeerJ 10:e14142, 2022
///   (PMID 36199287). Otto settimane, 43 persone già allenate: far crescere le **ripetizioni**
///   produce adattamenti equivalenti a far crescere il **carico**. È il permesso scientifico per
///   un'app a corpo libero, dove il carico non si può aggiungere.
/// - ACSM, *Progression Models in Resistance Training for Healthy Adults* (position stand 2009):
///   si avanza quando si riesce a fare 1-2 ripetizioni oltre il bersaglio **per due sessioni
///   consecutive**, con incrementi nell'ordine del 2-10%. È la regola nota come *2-for-2*.
/// - ACSM, aggiornamento 2026 delle linee guida: allenare **a cedimento non migliora** gli esiti
///   nell'adulto medio, e la costanza conta più del piano perfetto.
///
/// Da qui le quattro regole, e ognuna risponde a una di quelle righe.
///
/// 1. **Il segnale è dichiarato, non dedotto.** Il registro sa quante ripetizioni ti sono state
///    *chieste*, non quante ne avresti potute fare: senza che tu lo dica, qualunque progressione
///    starebbe indovinando.
/// 2. **Si sale dopo due conferme piene consecutive**, del 5% e mai meno di una ripetizione.
///    Due e non una, perché una giornata buona non è una capacità nuova.
/// 3. **Si scende dopo due mancate consecutive**, di un gradino solo, e mai sotto il 100%.
///    Il 100% resta il pavimento: quello è il programma, il resto è allenamento in più.
/// 4. **Il tetto porta alla variante, non a numeri assurdi.** Trenta squat non stanno in novanta
///    secondi. Quando il bersaglio non ci sta più nella pausa, la strada non è un numero più
///    grande ma un movimento più duro, ed è per questo che le varianti esistono.
public enum Progression {

    /// L'incremento: 5%, dentro la banda 2-10% del position stand.
    public static let step = 0.05
    /// Quante conferme di fila servono per muoversi. La regola *2-for-2*.
    public static let confirmationsNeeded = 2

    /// Il nuovo stato dopo un tentativo.
    public static func advance(_ current: ExerciseProgress, attempt: Attempt) -> ExerciseProgress {
        var next = current
        switch attempt {
        case .complete:
            next.streak = max(0, current.streak) + 1
            if next.streak >= confirmationsNeeded {
                next.level = current.level * (1 + step)
                next.streak = 0
            }
        case .partial:
            next.streak = min(0, current.streak) - 1
            if -next.streak >= confirmationsNeeded {
                next.level = max(1.0, current.level / (1 + step))
                next.streak = 0
            }
        }
        return next
    }

    /// Quante ripetizioni ci stanno davvero in una pausa di questa durata.
    ///
    /// Il tetto non è un numero scelto a gusto: è quanto tempo il movimento occupa. Si lascia una
    /// riserva del 40% perché la pausa non è solo l'esercizio — c'è da leggersi cosa fare, mettersi
    /// in posizione, e respirare alla fine.
    public static func ceiling(for kind: ExerciseKind, breakSeconds: Double) -> Int {
        max(kind.baseReps, Int((breakSeconds * 0.6) / max(0.5, kind.secondsPerRep)))
    }

    /// Il bersaglio è arrivato al tetto: da qui si cambia movimento, non numero.
    public static func hasHitCeiling(kind: ExerciseKind, reps: Int, breakSeconds: Double) -> Bool {
        reps >= ceiling(for: kind, breakSeconds: breakSeconds)
    }

    /// La versione più dura dello stesso gesto, se esiste. `nil` quando non c'è più niente sopra:
    /// lì il tetto è un tetto vero, e il numero smette di crescere.
    public static func harder(than kind: ExerciseKind) -> ExerciseKind? {
        switch kind {
        case .wallPushUp: return .kneePushUp
        case .kneePushUp: return .inclinePushUp
        case .inclinePushUp: return .pushUp
        case .pushUp: return .diamondPushUp
        case .diamondPushUp: return .archerPushUp
        case .squat: return .splitSquat
        case .splitSquat: return .jumpSquat
        case .gluteBridge: return .splitSquat
        case .crunch: return .sitUp
        case .sitUp: return .hollowHold
        case .legRaise: return .hollowHold
        case .benchDip: return .diamondPushUp
        // Il gradino piu' basso dei vigorosi: le salite non saltano, i jumping jack si'.
        case .stepUp: return .jumpingJack
        case .jumpingJack: return .highKnees
        case .highKnees: return .mountainClimber
        // L'incrociato sta **fra** il classico e il burpee, e non e' un gradino di comodo: la
        // diagonale aggiunge il lavoro degli obliqui contro la rotazione del bacino, che il
        // classico non chiede. Chi ha finito i secondi del mountain climber ha ancora questo
        // prima di trovarsi davanti un burpee.
        case .mountainClimber: return .crossMountainClimber
        case .crossMountainClimber: return .burpee
        // Il bird-dog e il dead bug sono lo stesso mestiere in due posizioni: il primo a
        // quattro zampe, il secondo a terra e piu' duro da tenere onesto.
        case .birdDog: return .deadBug
        // La regressione del plank risale al plank, come le ginocchia risalgono al push-up.
        case .easyPlank: return .plank
        default: return nil
        }
    }
}

public extension Progression {

    /// Perché l'app sta proponendo un movimento più duro.
    enum HarderReason: Sendable, Equatable {
        /// Il numero non ci sta più nella pausa: da qui si cambia gesto o non si cresce più.
        case ceiling
        /// Stai andando bene da un po'. È un invito, non un tetto.
        case doingWell
    }

    /// **La quota oltre la quale conviene proporre il movimento più duro invece del numero più
    /// grande.** Tre incrementi consecutivi, cioè circa il 15% sopra il 100%.
    ///
    /// Prima di questa soglia il numero che cresce è la progressione giusta: è quella misurata da
    /// Plotkin 2022, ed è anche quella che si sente meno. Dopo, aggiungere ripetizioni a un
    /// movimento che ormai fai bene allunga la pausa senza renderla più allenante, e la strada
    /// utile diventa un gesto che pesa di più.
    static let suggestHarderAbove = 1.15

    /// Il movimento più duro da proporre adesso, e perché. `nil` quando non c'è niente da dire.
    static func suggestHarder(
        kind: ExerciseKind, reps: Int, progress: ExerciseProgress, breakSeconds: Double
    ) -> (kind: ExerciseKind, reason: HarderReason)? {
        guard let up = harder(than: kind) else { return nil }
        if hasHitCeiling(kind: kind, reps: reps, breakSeconds: breakSeconds) {
            return (up, .ceiling)
        }
        if progress.level >= suggestHarderAbove { return (up, .doingWell) }
        return nil
    }
}

/// Lo stato della progressione su disco, un esercizio per riga.
public struct ProgressBook: Codable, Equatable, Sendable {
    public var byExercise: [String: ExerciseProgress]

    public init(byExercise: [String: ExerciseProgress] = [:]) {
        self.byExercise = byExercise
    }

    public func progress(for kind: ExerciseKind) -> ExerciseProgress {
        byExercise[kind.rawValue] ?? ExerciseProgress()
    }

    public mutating func record(_ attempt: Attempt, for kind: ExerciseKind) {
        byExercise[kind.rawValue] = Progression.advance(progress(for: kind), attempt: attempt)
    }
}

/// Il registro della progressione su disco.
public enum ProgressStore {
    public static func load(from url: URL = Paths.progressFile) -> ProgressBook {
        guard let data = try? Data(contentsOf: url),
              let book = try? JSONDecoder().decode(ProgressBook.self, from: data)
        else { return ProgressBook() }
        return book
    }

    @discardableResult
    public static func save(_ book: ProgressBook, to url: URL = Paths.progressFile) -> Bool {
        Paths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(book) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}
