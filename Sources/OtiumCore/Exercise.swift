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
    /// **Aggiunta il 2026-07-31**, per mia scelta: *«peccato che non ci sia niente
    /// da fare per il dorso»*. A corpo libero e senza barra la trazione vera non c'è — e le
    /// alternative che circolano (rematore allo stipite, auto-resistenza) hanno tutte lo stesso
    /// difetto: il carico dipende da quanto tiri, quindi non è misurabile, quindi non è
    /// verificabile. Scartate insieme a lui. Quello che resta è reale e vale: i muscoli che
    /// tengono le scapole indietro e la schiena estesa, cioè i primi a spegnersi davanti a uno
    /// schermo.
    case posturali
    case vigorosi

    public var italianName: String {
        switch self {
        case .gambe: return "Gambe"
        case .spinta: return "Spinta"
        case .addome: return "Addome"
        case .posturali: return "Posturali"
        case .vigorosi: return "Vigorosi"
        }
    }

    /// Una riga che dice a cosa serve la famiglia, perché una casella senza motivo non si spunta
    /// con criterio.
    public var englishName: String {
        switch self {
        case .gambe: return "Legs"
        case .spinta: return "Push"
        case .addome: return "Core"
        case .posturali: return "Posture"
        case .vigorosi: return "Vigorous"
        }
    }

    public var localizedName: String { L.t(italianName, englishName) }

    public var subtitle: String {
        switch self {
        case .gambe: return L.t("le masse grosse, sono loro ad abbassare la glicemia",
                                "the big muscles: these are the ones that lower blood sugar")
        case .spinta: return L.t("petto, spalle, tricipiti", "chest, shoulders, triceps")
        case .addome: return L.t("il core, che stando seduti non lavora mai",
                                 "the core, which never works while you sit")
        case .posturali: return L.t("la schiena alta e le scapole, i primi a spegnersi allo schermo",
                                    "upper back and shoulder blades, the first to switch off at a screen")
        case .vigorosi: return L.t("il fiatone, contano verso le 3 sessioni intense del giorno",
                                   "the breathless ones: they count towards the 3 vigorous bouts a day")
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
    /// **La sedia al muro**, cioè lo squat isometrico. Aggiunta il 2026-08-19, e il posto che
    /// copre non e' un muscolo: e' una situazione. Tutte le altre gambe chiedono di muoversi in
    /// modo visibile o di andare a terra, e vestito bene, in un posto pubblico o davanti a
    /// qualcuno la pausa si saltava. Questa si fa contro un muro senza che nessuno se ne accorga.
    case wallSit
    // Spinta
    case pushUp
    case diamondPushUp
    case archerPushUp
    case inclinePushUp
    /// Sulle ginocchia: la regressione classica del push-up, non una versione «per signore».
    case kneePushUp
    /// Mani al muro: la più facile di tutte, e la porta d'ingresso di chi parte da zero.
    case wallPushUp
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
    /// **Il bird-dog**: il core lento, che si fa senza sudare e senza rumore. Braccio e gamba
    /// opposti, e il lavoro vero e' il bacino che **non** deve ruotare.
    case birdDog
    case plank
    /// Il plank **a braccia tese**, cioè sulle mani invece che sui gomiti. Aggiunto il
    /// 2026-08-19 come regressione del plank: alzarsi sulle mani accorcia la leva fra le spalle
    /// e i piedi, quindi lo stesso addome regge più a lungo. È la versione facile, e si chiama
    /// così perché è quello che deve capire chi la sceglie.
    /// **Non entra nel giro di serie**: è una via d'uscita e una scelta, non un turno.
    case easyPlank
    case sidePlank
    case hollowHold
    // Posturali — aggiunti il 2026-07-31: la schiena alta era l'unica zona senza niente.
    case superman
    case ytw
    /// **Gli angeli al muro**: e' l'esercizio della postura da schermo, e i due posturali che
    /// c'erano chiedono entrambi di stendersi per terra. In piedi contro un muro si fa ovunque,
    /// e lavora esattamente cio' che lo schermo spegne: le scapole e i rotatori della spalla.
    case wallAngel
    // Vigorosi — sono questi che contano verso i 3 sessione intensa VILPA al giorno
    case burpee
    /// Il burpee **senza il piegamento**: squat, gambe indietro, gambe avanti, in piedi.
    ///
    /// Aggiunto il 2026-07-31, e per due ruoli insieme. È la regressione del burpee per chi
    /// parte più in basso sulla parte alta — la stessa logica dei push-up sulle ginocchia, dove
    /// si scala il **movimento** e non il numero — ed è la via d'uscita dentro la pausa per
    /// chiunque, quel giorno lì, il piegamento a terra non ce l'abbia. Ha un nome suo perché è
    /// un esercizio suo: fino a stamattina la descrizione del burpee descriveva *questo*, ed è
    /// esattamente per non confonderli più che adesso esistono separati.
    case squatThrust
    case jumpingJack
    case jumpSquat
    case mountainClimber
    /// Il mountain climber **incrociato**: il ginocchio destro va verso il gomito sinistro, e
    /// viceversa. Chiesto il 2026-08-19. Non è un mountain climber più veloce: la diagonale
    /// chiede agli obliqui di fermare la rotazione del bacino, quindi è più lento per
    /// ripetizione e lavora un pezzo che il classico non tocca.
    case crossMountainClimber
    case highKnees
    /// **Le salite sulla sedia**: l'unico vigoroso che non salta. Serve la sera in appartamento,
    /// dove burpee e jump squat sono un rumore che non puoi fare, e serve a chi le ginocchia le
    /// ha stanche. La sedia c'e' gia', ed e' l'unico attrezzo che l'app si permette.
    case stepUp

    /// Ripetizioni a regime, cioè a rampa completata. Scalano con la difficoltà: un archer
    /// push-up non si fa dieci volte come un push-up normale.
    public var baseReps: Int {
        switch self {
        case .squat: return 15
        case .lunge: return 12
        case .splitSquat: return 10
        case .gluteBridge: return 15
        case .calfRaise: return 20
        // Secondi, come le altre tenute. Un minuto e' il traguardo classico della sedia al muro,
        // e regge dentro la micro-pausa da 90 secondi senza mangiarsela tutta.
        case .wallSit: return 60
        case .pushUp: return 10
        case .diamondPushUp: return 8
        case .archerPushUp: return 6
        case .inclinePushUp: return 12
        case .kneePushUp: return 12
        case .wallPushUp: return 15
        case .pikePushUp: return 8
        case .benchDip: return 12
        case .crunch: return 20
        case .sitUp: return 15
        case .legRaise: return 12
        case .bicycleCrunch: return 24
        case .deadBug: return 16
        case .russianTwist: return 24
        // Dodici in tutto, cioe' sei per lato: e' lento, e un numero alto qui premierebbe
        // proprio la fretta che rovina l'esercizio.
        case .birdDog: return 12
        // Per i tre esercizi a tempo questo numero è **secondi**, non ripetizioni: vedi `isTimed`.
        case .plank: return 45
        case .easyPlank: return 50
        case .sidePlank: return 40
        case .hollowHold: return 30
        case .superman: return 12
        // Una ripetizione è **un ciclo intero**: Y, poi T, poi W. Contare le lettere separate
        // darebbe un numero tre volte più alto per lo stesso lavoro.
        case .ytw: return 8
        // Dieci cicli lenti: qui il numero alto non serve a niente, la qualita' e' restare
        // attaccato al muro con polsi e gomiti per tutta la salita.
        case .wallAngel: return 10
        case .burpee: return 8
        case .squatThrust: return 12
        case .jumpingJack: return 25
        case .jumpSquat: return 10
        case .mountainClimber: return 24
        // Meno del classico perche' una ripetizione costa piu' tempo, non perche' sia piu' facile.
        case .crossMountainClimber: return 20
        case .highKnees: return 30
        // Venti salite, cioe' dieci per gamba: e' la dose che alza il battito in un minuto
        // senza chiedere di saltare.
        case .stepUp: return 20
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
        case .plank, .easyPlank, .sidePlank, .hollowHold, .wallSit: return true
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
        case .kneePushUp: return 2.6
        case .wallPushUp: return 2.0
        case .pikePushUp: return 3.2
        case .benchDip: return 2.5
        case .crunch: return 2.0
        case .sitUp: return 2.5
        case .legRaise: return 3.0
        case .bicycleCrunch: return 1.4
        case .deadBug: return 2.5
        case .russianTwist: return 1.2
        case .birdDog: return 3.0        // due secondi di tenuta piu' il cambio, per lato
        case .plank, .easyPlank, .sidePlank, .hollowHold, .wallSit: return 1.0   // un "rep" è un secondo di tenuta
        case .superman: return 3.5      // due secondi di tenuta più la discesa controllata
        case .ytw: return 6.0           // tre lettere, due secondi l'una: il ciclo è lungo
        case .wallAngel: return 3.0     // sale e scende lento, altrimenti stacca dal muro
        case .burpee: return 4.5
        case .squatThrust: return 3.0   // senza il piegamento il ciclo è più corto
        case .jumpingJack: return 1.2
        case .jumpSquat: return 2.2
        case .mountainClimber: return 0.8
        case .crossMountainClimber: return 1.1   // la diagonale non si fa di slancio
        case .highKnees: return 0.6
        case .stepUp: return 2.0        // sali, sali, scendi, scendi: due secondi pieni
        }
    }

    /// Vigoroso nel senso di Stamatakis 2022: alza la frequenza cardiaca in 60-90 secondi.
    public var isVigorous: Bool {
        switch self {
        case .burpee, .squatThrust, .jumpingJack, .jumpSquat, .mountainClimber,
             .crossMountainClimber, .highKnees, .stepUp: return true
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
        // Le salite stanno con le gambe e non con il «total body» degli altri vigorosi: e' cio'
        // che lavora davvero, ed e' quello che serve alla regola che non carica due volte di
        // fila la stessa catena.
        case .squat, .lunge, .splitSquat, .wallSit, .stepUp: return "gambe"
        case .gluteBridge: return "glutei"
        case .calfRaise: return "polpacci"
        case .pushUp, .diamondPushUp, .archerPushUp, .inclinePushUp,
             .kneePushUp, .wallPushUp: return "petto"
        case .pikePushUp: return "spalle"
        case .benchDip: return "tricipiti"
        case .crunch, .sitUp, .legRaise, .bicycleCrunch, .deadBug, .russianTwist, .birdDog,
             .plank, .easyPlank, .sidePlank, .hollowHold: return "addome"
        case .superman, .ytw, .wallAngel: return "dorso"
        case .burpee, .squatThrust, .jumpingJack, .jumpSquat, .mountainClimber,
             .crossMountainClimber, .highKnees: return "total body"
        }
    }

    /// Il gruppo muscolare **da mostrare**. `muscleGroup` resta in italiano perché è una chiave:
    /// la usa `spreadByMuscleGroup` per non far lavorare due volte di fila la stessa zona, e la
    /// usa `SexCalibration` per scegliere il coefficiente. Tradurre la chiave significherebbe far
    /// dipendere la rotazione degli esercizi dalla lingua dell'interfaccia.
    public var localizedMuscleGroup: String { ExerciseKind.localizedGroup(muscleGroup) }

    /// La traduzione parte dalla **chiave**, non dall'esercizio, perché la pagina delle statistiche
    /// raggruppa per chiave e poi deve scrivere quel gruppo a schermo: senza questa funzione
    /// l'unica strada era mostrare la chiave grezza, ed è quello che faceva. Trovato il 2026-08-12
    /// fotografando la pagina in inglese, dove le barre dicevano «addome», «gambe», «petto».
    ///
    /// **`dorso` diceva «total body», che è falso**, ed era il `default` a dirlo: un ramo di
    /// scarto che risponde per un caso vero produce una traduzione plausibile e sbagliata, cioè il
    /// guasto peggiore. Adesso ogni chiave ha la sua riga e il default resta per l'unica che lo
    /// merita.
    public static func localizedGroup(_ key: String) -> String {
        guard L.language == .english else { return key }
        switch key {
        case "gambe": return "legs"
        case "glutei": return "glutes"
        case "polpacci": return "calves"
        case "petto": return "chest"
        case "spalle": return "shoulders"
        case "tricipiti": return "triceps"
        case "addome": return "core"
        case "dorso": return "back"
        default: return "total body"
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
        case .archerPushUp, .lunge, .splitSquat, .bicycleCrunch, .russianTwist, .sidePlank,
             .birdDog, .stepUp:
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
        case .squat, .lunge, .splitSquat, .gluteBridge, .calfRaise, .wallSit: return .gambe
        case .pushUp, .diamondPushUp, .archerPushUp, .inclinePushUp, .pikePushUp, .benchDip,
             .kneePushUp, .wallPushUp: return .spinta
        case .crunch, .sitUp, .legRaise, .bicycleCrunch, .deadBug, .russianTwist, .birdDog,
             .plank, .easyPlank, .sidePlank, .hollowHold: return .addome
        case .superman, .ytw, .wallAngel: return .posturali
        case .burpee, .squatThrust, .jumpingJack, .jumpSquat, .mountainClimber,
             .crossMountainClimber, .highKnees, .stepUp: return .vigorosi
        }
    }

    public var italianName: String {
        switch self {
        case .squat: return "squats"
        case .lunge: return "affondi"
        case .splitSquat: return "split squats"
        case .gluteBridge: return "ponte per i glutei"
        case .calfRaise: return "sollevamenti sui polpacci"
        case .wallSit: return "sedia al muro"
        case .pushUp: return "push-ups"
        case .diamondPushUp: return "diamond push-ups"
        case .archerPushUp: return "archer push-ups"
        case .inclinePushUp: return "push-ups inclinati"
        case .kneePushUp: return "push-ups sulle ginocchia"
        case .wallPushUp: return "push-ups al muro"
        case .pikePushUp: return "pike push-ups"
        case .benchDip: return "dips su sedia"
        case .crunch: return "crunches"
        case .sitUp: return "sit-ups"
        case .legRaise: return "sollevamento gambe"
        case .bicycleCrunch: return "crunch bicicletta"
        case .deadBug: return "dead bugs"
        case .russianTwist: return "russian twists"
        case .birdDog: return "bird-dog"
        case .plank: return "plank"
        case .easyPlank: return "easy plank"
        case .sidePlank: return "plank laterale"
        case .hollowHold: return "hollow hold"
        case .superman: return "superman"
        case .ytw: return "Y-T-W"
        case .wallAngel: return "angeli al muro"
        case .burpee: return "burpees"
        case .squatThrust: return "squat thrusts"
        case .jumpingJack: return "jumping jacks"
        case .jumpSquat: return "jump squats"
        case .mountainClimber: return "mountain climbers"
        case .crossMountainClimber: return "mountain climbers incrociati"
        case .highKnees: return "corsa sul posto"
        case .stepUp: return "salite sulla sedia"
        }
    }

    public var englishName: String {
        switch self {
        case .squat: return "squats"
        case .lunge: return "lunges"
        case .splitSquat: return "split squats"
        case .gluteBridge: return "glute bridges"
        case .calfRaise: return "calf raises"
        case .pushUp: return "push-ups"
        case .diamondPushUp: return "diamond push-ups"
        case .archerPushUp: return "archer push-ups"
        case .inclinePushUp: return "incline push-ups"
        case .kneePushUp: return "knee push-ups"
        case .wallPushUp: return "wall push-ups"
        case .pikePushUp: return "pike push-ups"
        case .benchDip: return "chair dips"
        case .crunch: return "crunches"
        case .sitUp: return "sit-ups"
        case .legRaise: return "leg raises"
        case .bicycleCrunch: return "bicycle crunches"
        case .deadBug: return "dead bugs"
        case .russianTwist: return "russian twists"
        case .plank: return "plank"
        case .easyPlank: return "easy plank"
        case .sidePlank: return "side plank"
        case .hollowHold: return "hollow hold"
        case .superman: return "superman"
        case .ytw: return "Y-T-W"
        case .burpee: return "burpees"
        case .squatThrust: return "squat thrusts"
        case .jumpingJack: return "jumping jacks"
        case .jumpSquat: return "jump squats"
        case .mountainClimber: return "mountain climbers"
        case .crossMountainClimber: return "cross-body mountain climbers"
        case .highKnees: return "high knees"
        case .wallSit: return "wall sit"
        case .wallAngel: return "wall angels"
        case .birdDog: return "bird-dog"
        case .stepUp: return "chair step-ups"
        }
    }

    /// Il nome nella lingua scelta.
    ///
    /// **I nomi inglesi vanno al plurale anche in italiano** (sua richiesta, 2026-08-04). La
    /// grammatica direbbe il contrario — un prestito straniero in italiano non prende la -s — ma
    /// questi non sono prestiti generici: sono i nomi che si usano in palestra, dove si dice
    /// «dieci burpees» e nessuno dice «dieci burpee». Restano singolari le tenute (plank, hollow
    /// hold, superman), perché lì il numero sono secondi e non ripetizioni, e i nomi italiani
    /// (affondi, sollevamento gambe, corsa sul posto), che seguono la loro lingua.
    ///
    /// **Il registro non passa da qui**: su disco si scrive `rawValue`, cioè il nome del caso.
    /// La riga di commento che diceva il contrario era vecchia e sbagliata, e l'ho tolta invece
    /// di ereditarla.
    public var localizedName: String { L.t(italianName, englishName) }

    public var cue: String {
        switch self {
        case .squat:
            return L.t("Piedi alla larghezza delle spalle, scendi finché le cosce sono parallele, petto alto.",
                       "Feet shoulder-width apart, go down until your thighs are parallel, chest up.")
        case .lunge:
            return L.t("Parti in piedi, fai un passo lungo, scendi, torna su. Ogni ripetizione un passo nuovo, alternando.",
                       "Start standing, take a long step, go down, come back up. A new step each rep, alternating sides.")
        case .splitSquat:
            return L.t("Come l'affondo, ma i piedi non si muovono mai, resti nella posizione e sali e scendi. Metà per gamba.",
                       "Like a lunge, but your feet never move: hold the stance and go up and down. Half per leg.")
        case .gluteBridge:
            return L.t("A terra, ginocchia piegate, spingi coi talloni e stringi i glutei in alto.",
                       "On the floor, knees bent: push through your heels and squeeze your glutes at the top.")
        case .calfRaise:
            return L.t("In piedi, sali sulle punte lentamente e scendi ancora più lentamente.",
                       "Standing, rise onto your toes slowly and come down even more slowly.")
        case .pushUp:
            return L.t("Corpo in linea dalla testa ai talloni, gomiti a 45°. In ginocchio va benissimo.",
                       "Body in a straight line from head to heels, elbows at 45°. On your knees is perfectly fine.")
        case .diamondPushUp:
            return L.t("Mani vicine sotto il petto, indici e pollici a formare un rombo. Tutto sui tricipiti.",
                       "Hands close together under your chest, index fingers and thumbs forming a diamond. All triceps.")
        case .archerPushUp:
            return L.t("Mani larghe, scendi da un lato tenendo l'altro braccio teso. Alterna i lati.",
                       "Hands wide: lower to one side keeping the other arm straight. Alternate sides.")
        case .inclinePushUp:
            return L.t("Mani sulla scrivania o sulla sedia, più alto è l'appoggio e più è facile.",
                       "Hands on the desk or the chair: the higher the surface, the easier it gets.")
        case .kneePushUp:
            return L.t("Ginocchia a terra, corpo in linea dalle ginocchia alla testa. Non è un push-up a metà, è un push-up con meno peso.",
                       "Knees on the floor, body in line from knees to head. It is not half a push-up: it is a push-up with less weight.")
        case .wallPushUp:
            return L.t("Mani al muro all'altezza delle spalle, piedi un passo indietro. Più ti allontani dal muro, più è duro.",
                       "Hands on the wall at shoulder height, feet a step back. The further from the wall, the harder it gets.")
        case .pikePushUp:
            return L.t("A V rovesciata, bacino alto, scendi con la testa fra le mani. Lavorano le spalle.",
                       "Inverted V, hips high, lower your head between your hands. This one is shoulders.")
        case .benchDip:
            return L.t("Mani sul bordo della sedia dietro di te, gomiti indietro, scendi e risali. Gambe dritte; se è troppo dura, piegale. Sedia stabile, contro il muro.",
                       "Hands on the edge of the chair behind you, elbows back, down and up. Legs straight; if it's too hard, bend them. Stable chair, against the wall.")
        case .crunch:
            return L.t("A terra, ginocchia piegate, stacca solo le scapole e tieni il mento lontano dal petto. Non tirarti il collo.",
                       "On the floor, knees bent: lift only your shoulder blades, chin away from your chest. Don't pull on your neck.")
        case .sitUp:
            return L.t("Salita completa fino a sederti, discesa lenta. Se i piedi si alzano, mettili sotto la scrivania.",
                       "All the way up to sitting, slow on the way down. If your feet lift, tuck them under the desk.")
        case .legRaise:
            return L.t("Schiena a terra, mani sotto i glutei, gambe tese che salgono e scendono senza toccare terra.",
                       "Back on the floor, hands under your glutes: straight legs go up and down without touching the ground.")
        case .bicycleCrunch:
            return L.t("Gomito verso il ginocchio opposto, alternando. Conta una ripetizione per lato.",
                       "Elbow towards the opposite knee, alternating. Count one rep per side.")
        case .deadBug:
            return L.t("Schiena piatta a terra, allunga braccio e gamba opposti, torna, cambia lato. Lentissimo.",
                       "Back flat on the floor: extend opposite arm and leg, return, switch sides. Very slowly.")
        case .russianTwist:
            return L.t("Seduto, busto inclinato indietro, ruota le spalle da un lato all'altro. Un lato, una ripetizione.",
                       "Seated, torso leaning back, rotate your shoulders from side to side. One side, one rep.")
        case .plank:
            return L.t("Gomiti sotto le spalle, corpo in linea, glutei stretti. Se la schiena si inarca, fermati.",
                       "Elbows under your shoulders, body in line, glutes tight. If your back arches, stop.")
        case .easyPlank:
            return L.t("Il plank sulle mani invece che sui gomiti: polsi sotto le spalle, braccia tese, corpo in linea dalle spalle ai talloni. Braccia tese vuol dire leva più corta, quindi si tiene più a lungo.",
                       "The plank on your hands instead of your elbows: wrists under your shoulders, arms straight, body in line from shoulders to heels. Straight arms mean a shorter lever, so you hold it longer.")
        case .sidePlank:
            return L.t("Su un gomito, corpo in linea vista di lato. Metà del tempo per lato, cambia a metà.",
                       "On one elbow, body in line seen from the side. Half the time per side, switch halfway.")
        case .hollowHold:
            return L.t("Schiena a terra e ben aderente, braccia e gambe sollevate. Se la lombare si stacca, alza le gambe.",
                       "Back flat and pressed to the floor, arms and legs lifted. If your lower back lifts, raise your legs.")
        // **Il piegamento mancava, ed è il pezzo che rende il burpee un burpee.** Diceva «squat,
        // gambe indietro, torna su, salto», che è lo *squat thrust*: il burpee senza push-up,
        // cioè un esercizio diverso e più facile. Visto all'uso il 2026-07-31
        // raccontando come lo fa lui — *«squat, piegamento di push up, salto»*. Scritta per
        // intero perché è il gesto più complesso che l'app propone, e saltarne un passaggio
        // significa farne un altro senza accorgersene.
        case .superman:
            return L.t("A pancia in giù, braccia avanti. Stacca da terra petto, braccia e gambe insieme, tieni due secondi, scendi piano. Guarda il pavimento, non avanti.",
                       "Face down, arms forward. Lift chest, arms and legs together, hold two seconds, lower slowly. Look at the floor, not ahead.")
        case .ytw:
            return L.t("A pancia in giù, fronte a terra. Braccia a Y in alto, poi a T di lato, poi a W coi gomiti stretti: due secondi ciascuna, staccando le mani da terra. Un giro delle tre lettere è una ripetizione.",
                       "Face down, forehead on the floor. Arms in a Y overhead, then a T out to the sides, then a W with elbows tucked: two seconds each, hands off the floor. One round of the three letters is one rep.")
        case .burpee:
            return L.t("Squat, mani a terra, gambe indietro. Un piegamento a terra, gambe avanti, e salta in alto.",
                       "Squat, hands down, legs back. One push-up on the floor, legs forward, and jump up.")
        case .squatThrust:
            return L.t("Come il burpee, senza il piegamento: squat, mani a terra, gambe indietro, gambe avanti, in piedi. Ritmo continuo.",
                       "Like a burpee without the push-up: squat, hands down, legs back, legs forward, stand up. Keep a steady rhythm.")
        case .jumpingJack:
            return L.t("Ritmo continuo, atterra morbido sull'avampiede.",
                       "Steady rhythm, land softly on the balls of your feet.")
        case .jumpSquat:
            return L.t("Squat e salta. Atterra piegando le ginocchia, silenzioso.",
                       "Squat and jump. Land bending your knees, quietly.")
        case .mountainClimber:
            return L.t("In appoggio sulle mani, ginocchia al petto alternate, veloce. Bacino basso.",
                       "In a plank on your hands, knees to your chest alternating, fast. Hips low.")
        case .crossMountainClimber:
            return L.t("In appoggio sulle mani, porta il ginocchio destro verso il gomito sinistro e viceversa, alternando. Bacino basso, senza ruotare le anche.",
                       "In a plank on your hands, drive your right knee towards your left elbow and vice versa, alternating. Hips low, without rotating them.")
        case .wallSit:
            return L.t("Schiena piatta al muro, scendi finché le cosce sono parallele, ginocchia sopra le caviglie. Il peso sui talloni, le mani lontane dalle gambe.",
                       "Back flat against the wall, slide down until your thighs are parallel, knees above your ankles. Weight on your heels, hands off your legs.")
        case .wallAngel:
            return L.t("Schiena, testa e braccia al muro, gomiti a novanta gradi. Sali e scendi lento tenendo polsi e gomiti attaccati al muro: dove si staccano, fermati.",
                       "Back, head and arms against the wall, elbows at ninety degrees. Slide up and down slowly keeping wrists and elbows on the wall: where they lift off, stop.")
        case .birdDog:
            return L.t("A quattro zampe, allunga braccio e gamba opposti fino alla linea del corpo, tieni un secondo, cambia lato. Il bacino resta fermo, non ruota.",
                       "On all fours, extend the opposite arm and leg in line with your body, hold a second, switch sides. Your hips stay still, no rotation.")
        case .stepUp:
            return L.t("Sali sulla sedia con un piede, poi con l'altro, e scendi nello stesso ordine. Sedia stabile e senza rotelle, piede tutto in appoggio, alterna la gamba che guida.",
                       "Step onto the chair with one foot, then the other, and step down in the same order. A stable chair with no wheels, the whole foot on the seat, alternate the leading leg.")
        case .highKnees:
            return L.t("Sul posto, ginocchia all'altezza del bacino, ritmo alto.",
                       "On the spot, knees up to hip height, high tempo.")
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
            return [.kneePushUp, .inclinePushUp, .wallPushUp, .diamondPushUp, .archerPushUp,
                    .benchDip, .pikePushUp]
        // Dalle regressioni si sale **e** si scende: chi è partito dal muro deve poter provare le
        // ginocchia senza cercarle nelle preferenze, e chi ha sbagliato a scegliere deve poter
        // tornare indietro dentro la pausa, non alla prossima.
        case .kneePushUp:
            return [.wallPushUp, .inclinePushUp, .pushUp, .benchDip]
        case .wallPushUp:
            return [.inclinePushUp, .kneePushUp, .pushUp]
        case .diamondPushUp, .archerPushUp, .pikePushUp, .inclinePushUp, .benchDip:
            return [.pushUp, .diamondPushUp, .archerPushUp, .benchDip, .pikePushUp, .inclinePushUp]
                .filter { $0 != self }
        // **I sollevamenti sulle punte per ultimi, ma ci sono.** Le altre alternative dello squat
        // chiedono tutte spazio o pavimento — affondi, split squat, ponte — e in treno, in coda,
        // in ascensore non ne fai nessuna: restava solo saltare la pausa. Li ho
        // fatti lo stesso il 2026-08-04, fuori menu, e il registro ha scritto squat.
        // La sedia al muro entra fra le alternative delle gambe per lo stesso motivo dei
        // polpacci: e' quella che si puo' fare quando non puoi ne' muoverti ne' andare a terra.
        case .squat:
            return [.splitSquat, .jumpSquat, .lunge, .gluteBridge, .calfRaise, .wallSit]
        case .lunge:
            return [.splitSquat, .squat, .gluteBridge, .calfRaise]
        case .splitSquat:
            return [.lunge, .squat, .gluteBridge, .calfRaise]
        case .gluteBridge:
            return [.squat, .splitSquat, .lunge, .calfRaise, .wallSit]
        case .wallSit:
            return [.squat, .splitSquat, .calfRaise, .gluteBridge]
        case .calfRaise:
            return [.jumpingJack, .squat]
        case .crunch, .sitUp, .bicycleCrunch, .russianTwist:
            return [.crunch, .sitUp, .bicycleCrunch, .russianTwist, .legRaise].filter { $0 != self }
        case .legRaise, .deadBug, .birdDog:
            return [.legRaise, .deadBug, .birdDog, .hollowHold, .crunch].filter { $0 != self }
        // Le tenute stanno fra loro: passare da un plank a un crunch a metà pausa cambia il
        // mestiere dell'esercizio, non la sua difficoltà.
        // Il plank sulle ginocchia sta **con le tenute**, e in tutti e due i sensi: chi non
        // regge il plank lo trova dentro la pausa senza cercarlo nelle preferenze, e chi lo ha
        // scelto per prudenza puo' risalire lo stesso giorno, non alla prossima.
        case .plank, .easyPlank, .sidePlank, .hollowHold:
            return [.plank, .easyPlank, .sidePlank, .hollowHold, .deadBug].filter { $0 != self }
        // Fra loro: sono due modi di fare la stessa cosa, uno più facile da tenere e uno più
        // preciso sulle scapole.
        case .superman, .ytw, .wallAngel:
            return [.superman, .ytw, .wallAngel].filter { $0 != self }
        // Lo squat thrust **per primo**: è lo stesso gesto con un pezzo in meno, quindi è la
        // sostituzione che chiedi quando il piegamento a terra oggi non c'è.
        case .burpee:
            return [.squatThrust, .jumpSquat, .mountainClimber, .crossMountainClimber, .highKnees]
        case .squatThrust:
            return [.burpee, .jumpSquat, .mountainClimber, .crossMountainClimber, .highKnees]
        case .jumpingJack, .jumpSquat, .mountainClimber, .crossMountainClimber, .highKnees,
             .stepUp:
            return [.burpee, .squatThrust, .jumpingJack, .jumpSquat, .mountainClimber,
                    .crossMountainClimber, .highKnees, .stepUp]
                .filter { $0 != self }
        }
    }
}

/// Come si dispongono le alternative sotto l'esercizio della pausa.
///
/// Il push-up ne offre **sette**, e sette pulsanti in una fila sola si leggono come un muro:
/// visto all'uso il 2026-07-31 — *«sono tutti su una linea, risultano appiccicati»*.
/// La stessa fila con lo squat ne ha quattro e col muro tre, quindi il numero non è mai lo
/// stesso e una riga scritta a mano non esiste.
///
/// Da quattro in su si spezza in due righe **bilanciate** — sette diventa 4+3 — così la seconda
/// riga è una riga e non un avanzo. Da tre in giù resta una fila sola: un 2+1 lascerebbe un
/// pulsante spaiato in mezzo allo schermo senza guadagnare aria, che era il difetto da togliere.
///
/// Sta nel nucleo e non nella vista perché è aritmetica, e l'aritmetica si prova con un test
/// invece che guardando uno snapshot.
public enum VariantLayout {
    /// Fino a questo numero le alternative restano su una riga sola.
    ///
    /// **Era 3, è 4 dal 2026-08-04.** Il numero che conta è quattro perché quattro è il caso più
    /// frequente nel corpus (lo squat, la sedia, il polpaccio), e spezzato 2+2 dava una griglia
    /// invece di una scelta. Visto guardando la schermata: *«voglio che siano
    /// messe in fila, non due sopra e due sotto, risulta brutto così»*. Il push-up con le sue
    /// sette varianti resta su due righe, 4+3, perché sette in fila non ci starebbero.
    public static let singleRowLimit = 4

    public static func rows<T>(_ items: [T]) -> [[T]] {
        if items.isEmpty { return [] }
        guard items.count > singleRowLimit else { return [items] }
        // La riga di sopra prende l'elemento in più quando sono dispari: il peso sta in alto,
        // come in una colonna di testo giustificata.
        let prima = (items.count + 1) / 2
        return [Array(items.prefix(prima)), Array(items.dropFirst(prima))]
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
    /// Il moltiplicatore di oggi: `startFactor` il primo giorno, 1.0 alla fine della salita, e in
    /// mezzo una linea **continua, giorno per giorno**.
    ///
    /// Prima saliva a scatti settimanali, e lo scatto era grosso: dal 55% al 70% da un giorno
    /// all'altro è un +27% di ripetizioni comparso durante la notte, senza che niente lo
    /// annunciasse. Giorno per giorno la stessa salita è invisibile mentre la vivi, ed è il modo
    /// in cui credevo già che funzionasse — cioè quello che una persona si aspetta
    /// leggendo «partenza graduale».
    ///
    /// I valori ai confini non cambiano: giorno 0 → 55%, giorno 7 → 70%, giorno 14 → 85%,
    /// giorno 21 → 100%. Cambia solo che adesso esiste anche il mercoledì.
    /// - Parameter weeks: **quante settimane dura la salita**, non quanti gradini ha. Prima il 4
    ///   significava «quattro livelli» e la salita finiva in ventuno giorni: l'etichetta diceva
    ///   quattro settimane e il numero pieno arrivava alla terza. Adesso 3 vuol dire 3.
    public static func factor(daysElapsed: Int, weeks: Int, startFactor: Double) -> Double {
        let span = max(1, weeks * 7)                // giorni fino al numero pieno
        let d = min(max(0, daysElapsed), span)
        return min(1.0, startFactor + (1.0 - startFactor) * Double(d) / Double(span))
    }

    public static func daysElapsed(since start: Date, now: Date) -> Int {
        let seconds = now.timeIntervalSince(start)
        guard seconds > 0 else { return 0 }
        return Int(seconds / (24 * 3600))
    }

    public static func weeksElapsed(since start: Date, now: Date) -> Int {
        daysElapsed(since: start, now: now) / 7
    }

    /// Le ripetizioni di oggi, rampa applicata.
    ///
    /// Per gli esercizi a lati alterni il totale è **arrotondato al pari**: la rampa al 55% su un
    /// archer push-up da sei darebbe 3, cioè un lato e mezzo, e «1,5 per lato» non è un'istruzione
    /// eseguibile. Si arrotonda una volta sola qui, dove il numero nasce, invece di rattoppare la
    /// divisione in ogni punto che lo mostra.
    /// - Parameter sex: sposta il **punto di partenza** per gruppo muscolare (`SexCalibration`,
    ///   fondato su Miller 1993). `nil` = nessuna calibrazione, cioè il numero pieno.
    /// - Parameter level: la crescita **oltre** il 100% (`Progression`). 1.0 = nessuna crescita.
    ///   Non tocca la partenza graduale: quella è `factor`, e i due si moltiplicano solo quando
    ///   la salita è finita, perché prima il livello resta a 1.0 per costruzione.
    public static func reps(for kind: ExerciseKind, factor: Double, sex: Sex? = nil,
                            level: Double = 1.0) -> Int {
        let scaled = Double(kind.baseReps) * factor * max(1.0, level)
            * SexCalibration.factor(for: kind, sex: sex)
        guard kind.isPerSide else { return max(1, Int(scaled.rounded())) }
        return max(2, Int((scaled / 2).rounded()) * 2)
    }

    /// Il pari più vicino, per gli esercizi che alternano i lati.
    ///
    /// Serve dove il numero **non** nasce qui ma lo scrivi tu: dichiarando una pausa già fatta si
    /// poteva salire di uno alla volta e fermarsi su 7 affondi, che a schermo diventavano «3 per
    /// lato» — un lato scoperto e un totale che non torna. Visto all'uso il 28 luglio
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
    ///
    /// **Si prende sempre dal gruppo più numeroso rimasto**, purché diverso dal precedente. La
    /// prima versione prendeva il *primo* disponibile, e su un pool sbilanciato falliva in modo
    /// prevedibile: il gruppo dominante non veniva speso finché c'era altro, e i suoi si
    /// ammucchiavano tutti in coda. Trovato il 2026-07-31 sul pool **vero** —
    /// diciotto esercizi di cui **sette d'addome** — dove uscivano `russian twist → plank
    /// laterale → hollow hold → sit-up`, quattro addominali di fila. Il pool di serie non lo
    /// mostrava: è abbastanza equilibrato da non far emergere il difetto, ed è esattamente il
    /// motivo per cui un test sul solo pool di serie non bastava.
    ///
    /// È il greedy classico per distanziare elementi ripetuti, e riesce **ogni volta che è
    /// possibile**: cioè quando il gruppo più numeroso non supera la metà del pool arrotondata
    /// per eccesso. Oltre, le adiacenze sono aritmetica e non si possono togliere — sette addome
    /// su otto esercizi si toccheranno, qualunque ordine si scelga.
    ///
    /// **Il pool è ciclico**, quindi anche l'ultimo confina col primo: senza l'ultimo passo, la
    /// giuntura del giro sarebbe l'unico punto scoperto — e sarebbe scoperto per sempre, perché
    /// `breakIndex` ci passa a ogni ricircolo.
    static func spreadByMuscleGroup(_ kinds: [ExerciseKind]) -> [ExerciseKind] {
        var remaining = kinds
        var ordered: [ExerciseKind] = []
        var previousGroup: String?

        while !remaining.isEmpty {
            var conteggio: [String: Int] = [:]
            for k in remaining { conteggio[k.muscleGroup, default: 0] += 1 }

            // Il più numeroso fra quelli ammessi; a parità, il primo che si incontra — così
            // l'ordine resta stabile e il risultato non dipende dall'ordine dei dizionari.
            let index = remaining.indices
                .filter { remaining[$0].muscleGroup != previousGroup }
                .max { (conteggio[remaining[$0].muscleGroup] ?? 0, $1) < (conteggio[remaining[$1].muscleGroup] ?? 0, $0) }
                ?? 0

            let chosen = remaining.remove(at: index)
            ordered.append(chosen)
            previousGroup = chosen.muscleGroup
        }

        // La giuntura del giro: l'ultimo confina col primo, e il greedy può lasciarci due dello
        // stesso gruppo — succede quando il gruppo dominante finisce in coda.
        //
        // **Si prova e si conta, invece di indovinare la condizione.** La prima versione cercava
        // il punto giusto con quattro confronti in fila, e uno di quelli confrontava un elemento
        // con sé stesso: la riparazione non scattava mai proprio nei casi che doveva curare.
        // Costruire il candidato e contargli le adiacenze costa niente su un pool di venti
        // elementi, non si può sbagliare, e si tiene solo se **migliora davvero**.
        if ordered.count > 2, adjacencies(ordered) > 0 {
            let ultimo = ordered.removeLast()
            var migliore = ordered + [ultimo]
            var punteggio = adjacencies(migliore)
            for i in 1..<ordered.count where punteggio > 0 {
                var candidato = ordered
                candidato.insert(ultimo, at: i)
                let suo = adjacencies(candidato)
                if suo < punteggio { migliore = candidato; punteggio = suo }
            }
            ordered = migliore
        }
        return ordered
    }

    /// Quante coppie di gruppo uguale si toccano, **contando anche la giuntura del giro**.
    static func adjacencies(_ ordered: [ExerciseKind]) -> Int {
        guard ordered.count > 1 else { return 0 }
        var n = zip(ordered, ordered.dropFirst()).filter { $0.muscleGroup == $1.muscleGroup }.count
        if ordered.count > 2, ordered[0].muscleGroup == ordered[ordered.count - 1].muscleGroup { n += 1 }
        return n
    }

    /// `breakIndex` è 1-based e cresce per tutta la vita dell'app: la rotazione non riparte
    /// ogni giorno, altrimenti farebbe sempre squat il lunedì mattina.
    public func exercise(breakIndex: Int, kind: BreakKind, factor: Double, sex: Sex? = nil,
                         pushVariant: ExerciseKind? = nil, progress: ProgressBook? = nil) -> Exercise {
        let table = (kind == .long) ? vigorousPool : pool
        let idx = max(0, breakIndex - 1) % table.count
        let chosen = SexCalibration.regression(for: table[idx], sex: sex, chosen: pushVariant)
        let level = progress?.progress(for: chosen).level ?? 1.0
        return Exercise(kind: chosen,
                        reps: Ramp.reps(for: chosen, factor: factor, sex: sex, level: level))
    }

    /// Quanto vale una stazione dentro il circuito rispetto allo stesso esercizio da solo.
    ///
    /// **Uno, dal 2026-08-04.** Era tre quarti, con la motivazione che quattro esercizi al volume
    /// pieno non stanno in cinque minuti. L'ho ribaltata con un argomento che vale
    /// più del mio: *«quegli esercizi sono singoli per ogni gruppo muscolare»*, cioè le quattro
    /// stazioni non si sommano sullo stesso muscolo — gambe, spinta, addome, esplosivo — quindi
    /// non c'è un affaticamento da ripartire, e ridurre toglieva lavoro senza una ragione
    /// fisiologica. È il suo corpo e la sua app.
    public static let circuitFactor: Double = 1.0

    /// Quanto valeva **prima** del 2026-08-04, e la data del cambio.
    ///
    /// Non è nostalgia: la pagina dell'andamento misura ogni conferma su quello che era stato
    /// prescritto *in quel momento*. Senza questi due valori, tutte le stazioni di circuito già
    /// fatte verrebbero rilette contro il volume pieno e risulterebbero al 75% di se stesse —
    /// cioè un calo comparso per un cambio di costante, che è esattamente il difetto appena
    /// riparato, al contrario.
    public static let legacyCircuitFactor: Double = 0.75
    public static let circuitFactorChangedOn: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 8; c.day = 4
        return Calendar.current.date(from: c) ?? .distantPast
    }()

    /// Il microcircuito della pausa piena: **una stazione per famiglia**, esplosivo compreso.
    ///
    /// È facoltativo per costruzione — lo si sceglie dentro la pausa, non lo si subisce — e per
    /// questo pesca dagli stessi pool delle preferenze: se hai spento l'addome, il circuito non
    /// te lo rimette dentro dalla finestra. Ruota con `breakIndex` come tutto il resto, così due
    /// pause piene di fila non propongono lo stesso giro.
    ///
    /// **`progress` è arrivato il 2026-08-12, e la sua assenza era il difetto.** Il parametro non
    /// c'era, quindi ogni stazione nasceva a livello 1.0 mentre l'esercizio singolo, che il
    /// registro lo riceveva, saliva: la progressione si guadagnava dentro il circuito e non si
    /// spendeva mai lì. Visto all'uso, con livelli a 1,2155 nel registro.
    public func circuit(breakIndex: Int, factor: Double, sex: Sex? = nil,
                        pushVariant: ExerciseKind? = nil, progress: ProgressBook? = nil) -> [Exercise] {
        let order: [ExerciseCategory] = [.gambe, .spinta, .addome, .vigorosi]
        let scaled = factor * Self.circuitFactor
        return order.compactMap { category in
            let table = (category == .vigorosi ? vigorousPool : pool).filter { $0.category == category }
            guard !table.isEmpty else { return nil }
            // Lo sfasamento per famiglia evita che tutte e quattro avanzino insieme e ripetano
            // sempre lo stesso accoppiamento.
            let offset = order.firstIndex(of: category) ?? 0
            let chosen = table[(max(0, breakIndex - 1) + offset) % table.count]
            let vero = SexCalibration.regression(for: chosen, sex: sex, chosen: pushVariant)
            // Il livello si legge sul gesto **vero**, cioè dopo la regressione: chi fa le
            // flessioni sulle ginocchia guadagna su quelle, non sulla versione a terra.
            let level = progress?.progress(for: vero).level ?? 1.0
            return Exercise(kind: vero, reps: Ramp.reps(for: vero, factor: scaled, sex: sex, level: level))
        }
    }
}
