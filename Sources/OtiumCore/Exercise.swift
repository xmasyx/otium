import Foundation

/// Un esercizio a corpo libero, eseguibile accanto alla scrivania.
/// L'unico "attrezzo" ammesso è una sedia, che c'è già.
public enum ExerciseKind: String, Codable, CaseIterable, Sendable {
    // Gambe
    case squat
    case lunge
    case splitSquat
    case gluteBridge
    case calfRaise
    // Spinta
    case pushUp
    case diamondPushUp
    case archerPushUp
    case inclinePushUp
    case pikePushUp
    case benchDip
    // Vigorosi — sono questi che contano verso i 3 sessione intensa VILPA al giorno
    case burpee
    case jumpingJack
    case jumpSquat
    case mountainClimber
    case highKnees

    /// Ripetizioni a regime, cioè a rampa completata. Scalano con la difficoltà: un archer
    /// push-up non si fa dieci volte come un push-up normale.
    public var baseReps: Int {
        switch self {
        case .squat: return 15
        case .lunge: return 12
        case .splitSquat: return 10
        case .gluteBridge: return 15
        case .calfRaise: return 20
        case .pushUp: return 10
        case .diamondPushUp: return 8
        case .archerPushUp: return 6
        case .inclinePushUp: return 12
        case .pikePushUp: return 8
        case .benchDip: return 12
        case .burpee: return 8
        case .jumpingJack: return 25
        case .jumpSquat: return 10
        case .mountainClimber: return 24
        case .highKnees: return 30
        }
    }

    /// Secondi per ripetizione eseguita con tecnica onesta. È il metro del cancello anti-bluff:
    /// il pulsante "fatto" non si sblocca prima di `reps × secondsPerRep`.
    public var secondsPerRep: Double {
        switch self {
        case .squat: return 2.5
        case .lunge: return 2.5
        case .splitSquat: return 2.8
        case .gluteBridge: return 2.0
        case .calfRaise: return 1.5
        case .pushUp: return 3.0
        case .diamondPushUp: return 3.2
        case .archerPushUp: return 4.0
        case .inclinePushUp: return 2.5
        case .pikePushUp: return 3.2
        case .benchDip: return 2.5
        case .burpee: return 4.5
        case .jumpingJack: return 1.2
        case .jumpSquat: return 2.2
        case .mountainClimber: return 0.8
        case .highKnees: return 0.6
        }
    }

    /// Vigoroso nel senso di Stamatakis 2022: alza la frequenza cardiaca in 60-90 secondi.
    public var isVigorous: Bool {
        switch self {
        case .burpee, .jumpingJack, .jumpSquat, .mountainClimber, .highKnees: return true
        default: return false
        }
    }

    /// Gruppo muscolare, usato per non caricare due volte di fila la stessa catena.
    public var muscleGroup: String {
        switch self {
        case .squat, .lunge, .splitSquat: return "gambe"
        case .gluteBridge: return "glutei"
        case .calfRaise: return "polpacci"
        case .pushUp, .diamondPushUp, .archerPushUp, .inclinePushUp, .pikePushUp: return "spinta"
        case .benchDip: return "tricipiti"
        case .burpee, .jumpingJack, .jumpSquat, .mountainClimber, .highKnees: return "tutto il corpo"
        }
    }

    public var italianName: String {
        switch self {
        case .squat: return "squat"
        case .lunge: return "affondi"
        case .splitSquat: return "split squat"
        case .gluteBridge: return "ponte per i glutei"
        case .calfRaise: return "sollevamenti sui polpacci"
        case .pushUp: return "push-up"
        case .diamondPushUp: return "diamond push-up"
        case .archerPushUp: return "archer push-up"
        case .inclinePushUp: return "push-up inclinati"
        case .pikePushUp: return "pike push-up"
        case .benchDip: return "dip su sedia"
        case .burpee: return "burpee"
        case .jumpingJack: return "jumping jack"
        case .jumpSquat: return "jump squat"
        case .mountainClimber: return "mountain climber"
        case .highKnees: return "corsa sul posto"
        }
    }

    public var cue: String {
        switch self {
        case .squat:
            return "Piedi alla larghezza delle spalle, scendi finché le cosce sono parallele, petto alto."
        case .lunge:
            return "Parti in piedi, fai un passo lungo, scendi, torna su. Ogni ripetizione un passo nuovo, alternando."
        case .splitSquat:
            return "Come l'affondo, ma i piedi non si muovono mai: resti nella posizione e sali e scendi. Metà per gamba."
        case .gluteBridge:
            return "A terra, ginocchia piegate: spingi coi talloni e stringi i glutei in alto."
        case .calfRaise:
            return "In piedi, sali sulle punte lentamente e scendi ancora più lentamente."
        case .pushUp:
            return "Corpo in linea dalla testa ai talloni, gomiti a 45°. In ginocchio va benissimo."
        case .diamondPushUp:
            return "Mani vicine sotto il petto, indici e pollici a formare un rombo. Tutto sui tricipiti."
        case .archerPushUp:
            return "Mani larghe: scendi da un lato tenendo l'altro braccio teso. Alterna i lati."
        case .inclinePushUp:
            return "Mani sulla scrivania o sulla sedia: più alto è l'appoggio, più è facile."
        case .pikePushUp:
            return "A V rovesciata, bacino alto, scendi con la testa fra le mani. Lavorano le spalle."
        case .benchDip:
            return "Mani sul bordo della sedia dietro di te, gomiti indietro, scendi e risali. Sedia stabile, contro il muro."
        case .burpee:
            return "Squat, gambe indietro, torna su, salto. Il pezzo duro della giornata: 60-90 secondi."
        case .jumpingJack:
            return "Ritmo continuo, atterra morbido sull'avampiede."
        case .jumpSquat:
            return "Squat e salta. Atterra piegando le ginocchia, silenzioso."
        case .mountainClimber:
            return "In appoggio sulle mani, ginocchia al petto alternate, veloce. Bacino basso."
        case .highKnees:
            return "Sul posto, ginocchia all'altezza del bacino, ritmo alto."
        }
    }

    /// Le alternative offerte **dentro** la pausa di questo esercizio.
    ///
    /// Sono opzionali per costruzione: la pausa propone il suo esercizio, e se hai voglia di
    /// qualcosa di più duro — o ti fa male una spalla — cambi con un clic, senza saltare la
    /// pausa. Il default resta quello che tocca alla rotazione, così scegliere non diventa
    /// un'altra decisione da prendere ogni mezz'ora.
    public var variants: [ExerciseKind] {
        switch self {
        case .pushUp:
            return [.diamondPushUp, .archerPushUp, .benchDip, .pikePushUp, .inclinePushUp]
        case .diamondPushUp, .archerPushUp, .pikePushUp, .inclinePushUp, .benchDip:
            return [.pushUp, .diamondPushUp, .archerPushUp, .benchDip, .pikePushUp, .inclinePushUp]
                .filter { $0 != self }
        case .squat:
            return [.splitSquat, .jumpSquat, .lunge, .gluteBridge]
        case .lunge:
            return [.splitSquat, .squat, .gluteBridge]
        case .splitSquat:
            return [.lunge, .squat, .gluteBridge]
        case .gluteBridge:
            return [.squat, .splitSquat, .lunge]
        case .calfRaise:
            return [.jumpingJack, .squat]
        case .burpee:
            return [.jumpSquat, .mountainClimber, .highKnees, .jumpingJack]
        case .jumpingJack, .jumpSquat, .mountainClimber, .highKnees:
            return [.burpee, .jumpingJack, .jumpSquat, .mountainClimber, .highKnees]
                .filter { $0 != self }
        }
    }
}

/// Un esercizio con le sue ripetizioni già calcolate per oggi (rampa applicata).
public struct Exercise: Equatable, Codable, Sendable {
    public let kind: ExerciseKind
    public let reps: Int

    public init(kind: ExerciseKind, reps: Int) {
        self.kind = kind
        self.reps = max(1, reps)
    }

    /// Il tempo minimo sotto il quale "fatto" è una bugia.
    public var minimumSeconds: Double {
        Double(reps) * kind.secondsPerRep
    }

    public var label: String {
        "\(reps) \(kind.italianName)"
    }
}

/// La rampa progressiva. Partire subito al volume pieno è il modo più rapido per farsi male
/// e disinstallare l'app: si sale in `weeks` settimane.
public enum Ramp {
    /// 0 → `startFactor`; `weeks-1` e oltre → 1.0; in mezzo, lineare.
    public static func factor(weeksElapsed: Int, weeks: Int, startFactor: Double) -> Double {
        guard weeks > 1 else { return 1.0 }
        let w = max(0, weeksElapsed)
        if w >= weeks - 1 { return 1.0 }
        let step = (1.0 - startFactor) / Double(weeks - 1)
        return min(1.0, startFactor + step * Double(w))
    }

    public static func weeksElapsed(since start: Date, now: Date) -> Int {
        let seconds = now.timeIntervalSince(start)
        guard seconds > 0 else { return 0 }
        return Int(seconds / (7 * 24 * 3600))
    }

    public static func reps(for kind: ExerciseKind, factor: Double) -> Int {
        max(1, Int((Double(kind.baseReps) * factor).rounded()))
    }
}

/// Sceglie che esercizio tocca. Deterministico: dato l'indice del break e il pool, la scelta è
/// sempre la stessa — così il registro è riproducibile e i test non inseguono il caso.
public struct ExercisePlanner: Sendable {
    public let pool: [ExerciseKind]
    public let vigorousPool: [ExerciseKind]

    public init(pool: [ExerciseKind], vigorousPool: [ExerciseKind]? = nil) {
        let cleaned = pool.isEmpty ? [.squat] : pool
        self.pool = Self.spreadByMuscleGroup(cleaned)
        let vigorous = vigorousPool ?? cleaned.filter { $0.isVigorous }
        self.vigorousPool = Self.spreadByMuscleGroup(vigorous.isEmpty ? [.jumpingJack] : vigorous)
    }

    /// Riordina il pool perché due esercizi consecutivi non peschino dallo stesso gruppo.
    ///
    /// Senza questo, un pool come [squat, push-up, affondi] fa gambe → spinta → gambe → gambe
    /// al giro successivo: le cosce si prendono due turni di fila e la rotazione serve a metà.
    /// Greedy: a ogni passo prendo il primo esercizio con un gruppo diverso dal precedente; se
    /// non esiste — perché il pool ha meno gruppi che elementi — prendo comunque il primo
    /// rimasto, invece di ciclare a vuoto.
    static func spreadByMuscleGroup(_ kinds: [ExerciseKind]) -> [ExerciseKind] {
        var remaining = kinds
        var ordered: [ExerciseKind] = []
        var previousGroup: String?

        while !remaining.isEmpty {
            let index = remaining.firstIndex { $0.muscleGroup != previousGroup } ?? 0
            let chosen = remaining.remove(at: index)
            ordered.append(chosen)
            previousGroup = chosen.muscleGroup
        }
        return ordered
    }

    /// `breakIndex` è 1-based e cresce per tutta la vita dell'app: la rotazione non riparte
    /// ogni giorno, altrimenti farebbe sempre squat il lunedì mattina.
    public func exercise(breakIndex: Int, kind: BreakKind, factor: Double) -> Exercise {
        let table = (kind == .long) ? vigorousPool : pool
        let idx = max(0, breakIndex - 1) % table.count
        let chosen = table[idx]
        return Exercise(kind: chosen, reps: Ramp.reps(for: chosen, factor: factor))
    }
}
