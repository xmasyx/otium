import Foundation

/// Le quattro famiglie, nell'ordine in cui hanno senso in un allenamento e nelle preferenze.
///
/// Esistono per due motivi arrivati insieme il 2026-07-27: scegliere fra 25 caselle in fila è
/// una fatica inutile quando 25 caselle sono in realtà quattro decisioni; e il microcircuito
/// deve poter dire «una stazione per famiglia» senza indovinare quale sia quale.
public enum ExerciseCategory: String, Codable, CaseIterable, Sendable {
    case gambe
    case spinta
    case addome
    case vigorosi

    public var italianName: String {
        switch self {
        case .gambe: return "Gambe"
        case .spinta: return "Spinta e braccia"
        case .addome: return "Addome"
        case .vigorosi: return "Vigorosi"
        }
    }

    /// Una riga che dice a cosa serve la famiglia, perché una casella senza motivo non si spunta
    /// con criterio.
    public var englishName: String {
        switch self {
        case .gambe: return "Legs"
        case .spinta: return "Push and arms"
        case .addome: return "Core"
        case .vigorosi: return "Vigorous"
        }
    }

    public var localizedName: String { L.t(italianName, englishName) }

    public var subtitle: String {
        switch self {
        case .gambe: return "le masse grosse: sono loro ad abbassare la glicemia"
        case .spinta: return "petto, spalle, tricipiti"
        case .addome: return "il core, che stando seduti non lavora mai"
        case .vigorosi: return "il fiatone: contano verso le 3 sessioni intense del giorno"
        }
    }
}

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
    // Addome — aggiunti il 2026-07-27: senza, la giornata allenava gambe e spinta e lasciava
    // fuori il core, che è metà del lavoro di chi sta seduto.
    case crunch
    case sitUp
    case legRaise
    case bicycleCrunch
    case deadBug
    case russianTwist
    case plank
    case sidePlank
    case hollowHold
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
        case .crunch: return 20
        case .sitUp: return 15
        case .legRaise: return 12
        case .bicycleCrunch: return 24
        case .deadBug: return 16
        case .russianTwist: return 24
        // Per i tre esercizi a tempo questo numero è **secondi**, non ripetizioni: vedi `isTimed`.
        case .plank: return 45
        case .sidePlank: return 40
        case .hollowHold: return 30
        case .burpee: return 8
        case .jumpingJack: return 25
        case .jumpSquat: return 10
        case .mountainClimber: return 24
        case .highKnees: return 30
        }
    }

    /// Si misura in **secondi tenuti**, non in ripetizioni.
    ///
    /// Non è un dettaglio di etichetta: il cancello anti-bluff calcola il tempo minimo come
    /// `reps × secondsPerRep`, e un plank "da 45" con 2,5 s per ripetizione pretenderebbe due
    /// minuti di tenuta per sbloccare il pulsante. Con `secondsPerRep = 1` il conto torna a
    /// dire la verità: 45 significa 45 secondi.
    public var isTimed: Bool {
        switch self {
        case .plank, .sidePlank, .hollowHold: return true
        default: return false
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
        case .crunch: return 2.0
        case .sitUp: return 2.5
        case .legRaise: return 3.0
        case .bicycleCrunch: return 1.4
        case .deadBug: return 2.5
        case .russianTwist: return 1.2
        case .plank, .sidePlank, .hollowHold: return 1.0   // un "rep" è un secondo di tenuta
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

    /// Gruppo muscolare, usato per non caricare due volte di fila la stessa catena — e mostrato
    /// in «Esercizi svolti».
    ///
    /// Sono i nomi di **quello che lavora**, non della famiglia in cui l'esercizio è archiviato:
    /// «spinta» era il nome del movimento e diceva poco a chi legge il recap accanto a «gambe» e
    /// «tricipiti». Il pike push-up sta a parte perché di petto ne fa poco: sono spalle.
    public var muscleGroup: String {
        switch self {
        case .squat, .lunge, .splitSquat: return "gambe"
        case .gluteBridge: return "glutei"
        case .calfRaise: return "polpacci"
        case .pushUp, .diamondPushUp, .archerPushUp, .inclinePushUp: return "petto"
        case .pikePushUp: return "spalle"
        case .benchDip: return "tricipiti"
        case .crunch, .sitUp, .legRaise, .bicycleCrunch, .deadBug, .russianTwist,
             .plank, .sidePlank, .hollowHold: return "addome"
        case .burpee, .jumpingJack, .jumpSquat, .mountainClimber, .highKnees: return "total body"
        }
    }

    /// Il movimento alterna i due lati, e il numero sensato è **per lato**.
    ///
    /// Un archer push-up da sei si fa tre di qua e tre di là: scrivere «6 archer push-up» fa
    /// contare sei ripetizioni per braccio, che è il doppio del lavoro previsto. Il totale resta
    /// il numero vero — il cancello anti-bluff conta quello — ma a schermo va il per lato, che è
    /// l'unico numero che sai usare mentre li fai.
    public var isPerSide: Bool {
        switch self {
        case .archerPushUp, .lunge, .splitSquat, .bicycleCrunch, .russianTwist, .sidePlank:
            return true
        default:
            return false
        }
    }

    /// La famiglia sotto cui l'esercizio compare nelle preferenze, e da cui il microcircuito
    /// pesca una stazione per ciascuna.
    ///
    /// È più grossolana di `muscleGroup` di proposito: `muscleGroup` serve a non far lavorare due
    /// volte di fila la stessa catena — quindi distingue glutei da polpacci — mentre qui serve a
    /// far scegliere in fretta a un umano, e "glutei" e "polpacci" sono gambe.
    public var category: ExerciseCategory {
        switch self {
        case .squat, .lunge, .splitSquat, .gluteBridge, .calfRaise: return .gambe
        case .pushUp, .diamondPushUp, .archerPushUp, .inclinePushUp, .pikePushUp, .benchDip: return .spinta
        case .crunch, .sitUp, .legRaise, .bicycleCrunch, .deadBug, .russianTwist,
             .plank, .sidePlank, .hollowHold: return .addome
        case .burpee, .jumpingJack, .jumpSquat, .mountainClimber, .highKnees: return .vigorosi
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
        case .crunch: return "crunch"
        case .sitUp: return "sit-up"
        case .legRaise: return "sollevamento gambe"
        case .bicycleCrunch: return "crunch bicicletta"
        case .deadBug: return "dead bug"
        case .russianTwist: return "russian twist"
        case .plank: return "plank"
        case .sidePlank: return "plank laterale"
        case .hollowHold: return "hollow hold"
        case .burpee: return "burpee"
        case .jumpingJack: return "jumping jack"
        case .jumpSquat: return "jump squat"
        case .mountainClimber: return "mountain climber"
        case .highKnees: return "corsa sul posto"
        }
    }

    public var englishName: String {
        switch self {
        case .squat: return "squat"
        case .lunge: return "lunges"
        case .splitSquat: return "split squat"
        case .gluteBridge: return "glute bridge"
        case .calfRaise: return "calf raises"
        case .pushUp: return "push-ups"
        case .diamondPushUp: return "diamond push-ups"
        case .archerPushUp: return "archer push-ups"
        case .inclinePushUp: return "incline push-ups"
        case .pikePushUp: return "pike push-ups"
        case .benchDip: return "chair dips"
        case .crunch: return "crunches"
        case .sitUp: return "sit-ups"
        case .legRaise: return "leg raises"
        case .bicycleCrunch: return "bicycle crunches"
        case .deadBug: return "dead bug"
        case .russianTwist: return "russian twists"
        case .plank: return "plank"
        case .sidePlank: return "side plank"
        case .hollowHold: return "hollow hold"
        case .burpee: return "burpees"
        case .jumpingJack: return "jumping jacks"
        case .jumpSquat: return "jump squats"
        case .mountainClimber: return "mountain climbers"
        case .highKnees: return "high knees"
        }
    }

    /// Il nome nella lingua scelta. `italianName` resta il nome canonico usato dal registro e
    /// dai test: quello non si traduce mai, o una riga scritta in inglese e riletta in italiano
    /// diventerebbe un altro esercizio.
    public var localizedName: String { L.t(italianName, englishName) }

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
        case .crunch:
            return "A terra, ginocchia piegate: stacca solo le scapole, mento lontano dal petto. Non tirarti il collo."
        case .sitUp:
            return "Salita completa fino a sederti, discesa lenta. Se i piedi si alzano, mettili sotto la scrivania."
        case .legRaise:
            return "Schiena a terra, mani sotto i glutei: gambe tese salgono e scendono senza toccare terra."
        case .bicycleCrunch:
            return "Gomito verso il ginocchio opposto, alternando. Conta una ripetizione per lato."
        case .deadBug:
            return "Schiena piatta a terra: allunga braccio e gamba opposti, torna, cambia lato. Lentissimo."
        case .russianTwist:
            return "Seduto, busto inclinato indietro, ruota le spalle da un lato all'altro. Un lato, una ripetizione."
        case .plank:
            return "Gomiti sotto le spalle, corpo in linea, glutei stretti. Se la schiena si inarca, fermati."
        case .sidePlank:
            return "Su un gomito, corpo in linea vista di lato. Metà del tempo per lato, cambia a metà."
        case .hollowHold:
            return "Schiena a terra e ben aderente, braccia e gambe sollevate. Se la lombare si stacca, alza le gambe."
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
        case .crunch, .sitUp, .bicycleCrunch, .russianTwist:
            return [.crunch, .sitUp, .bicycleCrunch, .russianTwist, .legRaise].filter { $0 != self }
        case .legRaise, .deadBug:
            return [.legRaise, .deadBug, .hollowHold, .crunch].filter { $0 != self }
        // Le tenute stanno fra loro: passare da un plank a un crunch a metà pausa cambia il
        // mestiere dell'esercizio, non la sua difficoltà.
        case .plank, .sidePlank, .hollowHold:
            return [.plank, .sidePlank, .hollowHold, .deadBug].filter { $0 != self }
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

    /// Il numero da **mostrare**: per gli esercizi che alternano i lati è quello per lato, non il
    /// totale. Il totale resta `reps` e governa il tempo minimo: mostrarne metà non sconta nulla.
    public var displayReps: Int {
        kind.isPerSide ? max(1, reps / 2) : reps
    }

    public var label: String {
        // Il plank laterale è l'unico che è insieme a tempo e a lati alterni: 40 secondi vogliono
        // dire venti per lato, e senza dirlo se ne farebbero ottanta.
        let nome = kind.localizedName
        if kind.isTimed && kind.isPerSide {
            return L.t("\(displayReps) s per lato di \(nome)", "\(displayReps) s per side of \(nome)")
        }
        if kind.isTimed { return L.t("\(displayReps) s di \(nome)", "\(displayReps) s of \(nome)") }
        if kind.isPerSide { return L.t("\(displayReps) \(nome) per lato", "\(displayReps) \(nome) per side") }
        return "\(reps) \(nome)"
    }

    /// Nel pannello «Ho già fatto una pausa» il numero che si digita è il **totale** — è quello
    /// che finisce nel registro — ma accanto va detto quanto fa per lato, o si sbaglia il conto.
    public var stepperLabel: String {
        kind.isTimed
            ? L.t("\(reps) secondi", "\(reps) seconds")
                + (kind.isPerSide ? L.t(" (\(displayReps) per lato)", " (\(displayReps) per side)") : "")
            : L.t("\(reps) ripetizioni", "\(reps) reps")
                + (kind.isPerSide ? L.t(" (\(displayReps) per lato)", " (\(displayReps) per side)") : "")
    }

    /// Cosa scrivere **sotto il numero grande** nella schermata di blocco. Per una tenuta il
    /// numero è in secondi, e senza l'unità «45 plank» si legge come quarantacinque plank; per un
    /// esercizio a lati alterni senza «per lato» si leggerebbe come il doppio del lavoro.
    public var title: String {
        let nome = kind.localizedName
        if kind.isTimed && kind.isPerSide {
            return L.t("secondi per lato di \(nome)", "seconds per side of \(nome)")
        }
        if kind.isTimed { return L.t("secondi di \(nome)", "seconds of \(nome)") }
        if kind.isPerSide { return L.t("\(nome) per lato", "\(nome) per side") }
        return nome
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

    /// Le ripetizioni di oggi, rampa applicata.
    ///
    /// Per gli esercizi a lati alterni il totale è **arrotondato al pari**: la rampa al 55% su un
    /// archer push-up da sei darebbe 3, cioè un lato e mezzo, e «1,5 per lato» non è un'istruzione
    /// eseguibile. Si arrotonda una volta sola qui, dove il numero nasce, invece di rattoppare la
    /// divisione in ogni punto che lo mostra.
    /// - Parameter sex: sposta il **punto di partenza** per gruppo muscolare (`SexCalibration`,
    ///   fondato su Miller 1993). `nil` = nessuna calibrazione, cioè il numero pieno.
    public static func reps(for kind: ExerciseKind, factor: Double, sex: Sex? = nil) -> Int {
        let scaled = Double(kind.baseReps) * factor
            * SexCalibration.factor(for: kind.muscleGroup, sex: sex)
        guard kind.isPerSide else { return max(1, Int(scaled.rounded())) }
        return max(2, Int((scaled / 2).rounded()) * 2)
    }

    /// Il pari più vicino, per gli esercizi che alternano i lati.
    ///
    /// Serve dove il numero **non** nasce qui ma lo scrivi tu: dichiarando una pausa già fatta si
    /// poteva salire di uno alla volta e fermarsi su 7 affondi, che a schermo diventavano «3 per
    /// lato» — un lato scoperto e un totale che non torna. Segnalato dal principale il 28 luglio
    /// 2026. Si arrotonda per eccesso: chi ha fatto sette affondi ne ha fatti quattro di qua e
    /// tre di là, e il lato lungo è quello che comanda.
    public static func evenIfPerSide(_ reps: Int, for kind: ExerciseKind) -> Int {
        guard kind.isPerSide else { return max(1, reps) }
        return max(2, reps % 2 == 0 ? reps : reps + 1)
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
    public func exercise(breakIndex: Int, kind: BreakKind, factor: Double, sex: Sex? = nil) -> Exercise {
        let table = (kind == .long) ? vigorousPool : pool
        let idx = max(0, breakIndex - 1) % table.count
        let chosen = table[idx]
        return Exercise(kind: chosen, reps: Ramp.reps(for: chosen, factor: factor, sex: sex))
    }

    /// Quanto vale una stazione dentro il circuito rispetto allo stesso esercizio da solo.
    ///
    /// Quattro esercizi al volume pieno non stanno in cinque minuti, e chi ci prova la seconda
    /// volta non lo rifà. Tre quarti è la quota che tiene il circuito sotto i due minuti di
    /// lavoro effettivo lasciando il resto della pausa a quello per cui esiste: stare lontano
    /// dallo schermo.
    public static let circuitFactor: Double = 0.75

    /// Il microcircuito della pausa piena: **una stazione per famiglia**, esplosivo compreso.
    ///
    /// È facoltativo per costruzione — lo si sceglie dentro la pausa, non lo si subisce — e per
    /// questo pesca dagli stessi pool delle preferenze: se hai spento l'addome, il circuito non
    /// te lo rimette dentro dalla finestra. Ruota con `breakIndex` come tutto il resto, così due
    /// pause piene di fila non propongono lo stesso giro.
    public func circuit(breakIndex: Int, factor: Double, sex: Sex? = nil) -> [Exercise] {
        let order: [ExerciseCategory] = [.gambe, .spinta, .addome, .vigorosi]
        let scaled = factor * Self.circuitFactor
        return order.compactMap { category in
            let table = (category == .vigorosi ? vigorousPool : pool).filter { $0.category == category }
            guard !table.isEmpty else { return nil }
            // Lo sfasamento per famiglia evita che tutte e quattro avanzino insieme e ripetano
            // sempre lo stesso accoppiamento.
            let offset = order.firstIndex(of: category) ?? 0
            let chosen = table[(max(0, breakIndex - 1) + offset) % table.count]
            return Exercise(kind: chosen, reps: Ramp.reps(for: chosen, factor: scaled, sex: sex))
        }
    }
}
