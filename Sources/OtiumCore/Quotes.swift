import Foundation

/// Una riga da leggere all'avvio. Non un fortune cookie: il nome dell'app viene da qui.
///
/// **Regola di ammissione: solo citazioni con un'opera identificabile.** La più bella che avevo
/// in mente — «la natura non ha fretta, eppure tutto si compie», ovunque attribuita a Lao Tzu —
/// è stata **scartata dopo verifica**: non compare nel Tao Te Ching in nessuna traduzione, è una
/// parafrasi moderna circolata sui social. Un'app che chiede di essere creduta sulle fonti degli
/// studi non può sbagliare una citazione: il criterio è lo stesso, e vale anche quando la frase
/// suona perfetta.
public struct Quote: Equatable, Sendable, Identifiable {
    public let text: String
    public let author: String
    /// L'opera, non il sito da cui l'ho presa.
    public let work: String

    public var id: String { "\(author)-\(text.prefix(24))" }

    public init(_ text: String, author: String, work: String) {
        self.text = text
        self.author = author
        self.work = work
    }
}

public enum Quotes {

    public static let all: [Quote] = [
        Quote("L'ozio senza studio è morte, è tomba dell'uomo vivo.",
              author: "Seneca", work: "Lettere a Lucilio, 82"),
        Quote("Tutto è d'altri, Lucilio: solo il tempo è nostro.",
              author: "Seneca", work: "Lettere a Lucilio, 1"),
        Quote("Non abbiamo poco tempo: ne perdiamo molto.",
              author: "Seneca", work: "La brevità della vita, 1"),
        Quote("In nessun luogo è chi è dappertutto.",
              author: "Seneca", work: "Lettere a Lucilio, 2"),
        Quote("Non sono le cose a turbare gli uomini, ma le opinioni che essi ne hanno.",
              author: "Epitteto", work: "Manuale, 5"),
        Quote("Fa' ogni cosa come se fosse l'ultima della tua vita.",
              author: "Marco Aurelio", work: "Pensieri, II"),
        Quote("Se soffri per qualcosa di esterno, non è quella cosa a turbarti, ma il tuo giudizio su di essa.",
              author: "Marco Aurelio", work: "Pensieri, VIII"),
        Quote("L'anima prende il colore dei suoi pensieri.",
              author: "Marco Aurelio", work: "Pensieri, V"),
        Quote("Al mattino, quando ti alzi controvoglia, ricorda: mi sveglio per fare il lavoro di un essere umano.",
              author: "Marco Aurelio", work: "Pensieri, V"),
        Quote("Otium cum dignitate — il riposo che non toglie nulla alla dignità.",
              author: "Cicerone", work: "Pro Sestio, 98"),
        Quote("Chi ha un perché abbastanza forte può sopportare quasi ogni come.",
              author: "Nietzsche", work: "Crepuscolo degli idoli, Massime e strali 12"),
        Quote("La vita è ciò che i nostri pensieri la fanno diventare.",
              author: "Marco Aurelio", work: "Pensieri, IV"),
        // Cercata due volte. Circola ovunque come di Lao Tzu, ma non compare in nessuna
        // traduzione del capitolo 64 del Tao Te Ching, e nessuna fonte autorevole ne indica
        // l'originale. Resta — è bella e c'entra — ma **senza il nome che non le spetta**.
        Quote("La natura non ha fretta, eppure tutto si compie.",
              author: "anonimo", work: "attribuita a Lao Tzu, ma assente dal Tao Te Ching"),
    ]

    /// La citazione dell'avvio numero `index`. Deterministica: gira in tondo, non a caso, così
    /// non ne salta nessuna e non ne ripete due di fila.
    public static func quote(at index: Int) -> Quote {
        guard !all.isEmpty else {
            return Quote("Alzati.", author: "Otium", work: "")
        }
        let i = ((index % all.count) + all.count) % all.count
        return all[i]
    }
}


/// Una riga di complimenti, breve e variabile.
///
/// Il messaggio dopo una pausa segnata diceva «il conto non si tocca»: una nota tecnica, giusta
/// la prima volta e rumore dalla seconda in poi. Chi ha appena fatto otto squat non ha bisogno
/// di sapere come funziona il contatore, ha bisogno che qualcuno se ne accorga.
///
/// Variabili di proposito: un complimento sempre uguale smette di essere un complimento e
/// diventa carta da parati.
public enum Praise {
    public static let afterBreak = [
        "Bel lavoro.", "Fatto.", "Così si fa.", "Una in più.",
        "Ottimo.", "Sei stato di parola.", "Bravo.", "Segnata, e meritata.",
    ]
    public static let afterHardOne = [
        "Quella era la parte dura.", "Col fiatone, come deve essere.",
        "La più faticosa della giornata, fatta.", "Bel fegato.",
    ]

    public static func line(at index: Int, hard: Bool = false) -> String {
        let list = hard ? afterHardOne : afterBreak
        return list[((index % list.count) + list.count) % list.count]
    }
}
