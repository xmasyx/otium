import Foundation

/// Il sesso biologico, che qui serve a **una cosa sola**: da quante ripetizioni si parte.
///
/// Non è una categoria identitaria e non cambia nient'altro nell'app — né gli esercizi proposti,
/// né la cadenza, né il linguaggio. Cambia il punto di partenza di un numero, ed è modificabile
/// dalle preferenze in qualunque momento.
public enum Sex: String, Codable, CaseIterable, Sendable {
    case male
    case female
}

/// Le lingue dell'interfaccia. Due, e dichiarate: aggiungerne una terza significa tradurre la
/// tabella in `Strings.swift`, non toccare il resto.
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case italian = "it"
    case english = "en"

    /// Quella del Mac, se è una che sappiamo parlare. Serve come proposta all'onboarding e come
    /// ripiego per il referto di `--doctor`, non come decisione: la scelta resta di chi installa.
    public static var systemDefault: AppLanguage {
        from(preferredLanguages: Locale.preferredLanguages)
    }

    /// La regola, staccata da chi la interroga.
    ///
    /// Serve a poterla **provare**: `systemDefault` legge la lingua del Mac su cui gira, quindi
    /// un test che lo interroga asserisce la macchina e non il codice — sul Mac italiano di chi
    /// scrive sarebbe verde comunque, e lo sarebbe anche se la regola dicesse «sempre italiano».
    /// Qui l'ingresso lo passa il chiamante, e i due poli si scrivono per davvero.
    ///
    /// Fuori dall'italiano si risponde inglese, che è la scelta giusta per un'app pubblicata in
    /// inglese: chi ha il Mac in tedesco legge una lingua che non è la sua in entrambi i casi, e
    /// fra le due gli serve quella che il README e le segnalazioni parlano già.
    public static func from(preferredLanguages: [String]) -> AppLanguage {
        (preferredLanguages.first ?? "en").hasPrefix("it") ? .italian : .english
    }

    public var nativeName: String {
        switch self {
        case .italian: return "Italiano"
        case .english: return "English"
        }
    }
}

/// Da quante ripetizioni si parte, per gruppo muscolare.
///
/// **Perché esiste, con la fonte.** Miller et al. 1993 (*Gender differences in strength and muscle
/// fiber characteristics*, Eur J Appl Physiol 66:254-262, PMID 8477683) misura su otto uomini e
/// otto donne che le donne esprimono circa il **52%** della forza maschile nella parte alta del
/// corpo e circa il **66%** in quella bassa, e mostra che la differenza segue la sezione
/// trasversale del muscolo, non una diversa qualità del muscolo. Dieci push-up non sono lo stesso
/// esercizio per tutti, e proporre lo stesso numero a chiunque significa proporre a metà delle
/// persone un compito che non riescono a fare — che è il modo più rapido di far disinstallare
/// un'app di allenamento.
///
/// **Cosa questi numeri NON sono.** Non un tetto, non una previsione su di te, non un giudizio:
/// sono il **primo giorno**. Da lì la rampa sale come per chiunque altro, e le ripetizioni si
/// cambiano a mano dalle preferenze. Un uomo che parte da fermo starà meglio con il profilo più
/// basso, e va benissimo.
public enum SexCalibration {

    /// Il coefficiente sulle ripetizioni di partenza, per gruppo muscolare.
    ///
    /// I due numeri della parte alta e della parte bassa vengono da Miller 1993, arrotondati verso
    /// l'alto (0,55 e 0,70) perché quello studio misura la **forza massimale** su un movimento
    /// singolo, mentre qui si contano ripetizioni a corpo libero, dove il divario osservato è più
    /// stretto. **L'addome è dichiaratamente diverso:** 0,85 non viene da Miller, che non lo
    /// misura, e nella letteratura sull'endurance del core il divario fra i sessi è piccolo. È una
    /// stima prudente, ed è segnata come tale invece di essere spacciata per un dato.
    public static func factor(for muscleGroup: String, sex: Sex?) -> Double {
        guard sex == .female else { return 1.0 }
        switch muscleGroup {
        case "petto", "spalle", "tricipiti": return 0.55     // Miller 1993, parte alta
        case "gambe", "glutei", "polpacci": return 0.70      // Miller 1993, parte bassa
        case "addome": return 0.85                            // stima, non misura
        // **Anche questa è una stima dichiarata.** Miller non misura la schiena alta, e questi
        // due esercizi non spostano un carico esterno: si solleva il peso delle braccia e del
        // tronco, dove il divario fra i sessi si stringe come sull'endurance del core. Segnato
        // come stima invece di essere spacciato per un dato, come già per l'addome.
        case "dorso": return 0.85                             // stima, non misura
        case "total body": return 0.70                        // movimenti misti: si segue la parte bassa
        default: return 0.80
        }
    }

    /// **Il movimento sostituito, invece del numero dimezzato.**
    ///
    /// Il difetto che questa tabella cura si vedeva nel primo avvio: a una donna in partenza
    /// graduale l'app proponeva *3 push-up*, perché i due sconti si moltiplicavano (55% della
    /// partenza × 55% della parte alta). Tre push-up standard non sono un allenamento, sono un
    /// numero che sembra un errore — e chi non riesce a farne tre neanche li fa.
    ///
    /// La leva giusta in programmazione dell'esercizio non è il conteggio, è la **regressione del
    /// movimento**: stesso gesto, meno peso da spostare. Push-up sulle ginocchia, al muro, o con
    /// le mani su un rialzo. Sono le stesse progressioni che si insegnano a chiunque parta da
    /// zero, uomo o donna: qui le riceve chi statisticamente ne ha bisogno più spesso, e restano
    /// **tutte scambiabili dentro la pausa** — in su e in giù — perché la statistica non sa nulla
    /// della persona che ha davanti.
    public static func regression(for kind: ExerciseKind, sex: Sex?,
                                  chosen: ExerciseKind? = nil) -> ExerciseKind {
        // Una scelta esplicita batte qualunque statistica, in tutte e due le direzioni.
        if let chosen, kind == .pushUp { return chosen }
        guard sex == .female else { return kind }
        switch kind {
        case .pushUp: return .kneePushUp
        case .diamondPushUp: return .kneePushUp
        case .archerPushUp: return .inclinePushUp
        // **Il burpee scala come i push-up, e per la stessa ragione.** Dentro c'è un piegamento a
        // terra, cioè il gesto su cui il divario di Miller è più largo: lo squat thrust è lo
        // stesso ciclo senza quel pezzo. Si scala il movimento, non il numero — e resta
        // scambiabile in su dentro la pausa, come tutte le altre regressioni.
        case .burpee: return .squatThrust
        default: return kind
        }
    }

    /// Il coefficiente sulle ripetizioni, **per esercizio**.
    ///
    /// Sulle regressioni vale 1.0, e non è una svista: il movimento è già stato scalato, e
    /// scontare anche il numero significherebbe scontare due volte la stessa cosa. Dodici push-up
    /// sulle ginocchia sono un allenamento; sette lo sono meno, e tre non lo sono affatto.
    public static func factor(for kind: ExerciseKind, sex: Sex?) -> Double {
        guard sex == .female else { return 1.0 }
        if kind == .kneePushUp || kind == .wallPushUp || kind == .inclinePushUp { return 1.0 }
        return factor(for: kind.muscleGroup, sex: sex)
    }

    /// La riga da mostrare quando l'app deve spiegare perché il tuo numero è quello.
    public static let source =
        "Miller AE, MacDougall JD, Tarnopolsky MA, Sale DG (1993), «Gender differences in strength "
        + "and muscle fiber characteristics», Eur J Appl Physiol 66:254-262 — PMID 8477683"
}
