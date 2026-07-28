import Foundation

/// Una riga da leggere: una citazione, un pensiero, un fatto.
///
/// Tre famiglie in un tipo solo perché il mazzo deve poterle mescolare insieme. La regola di
/// ammissione resta quella delle citazioni — **mai attribuire una frase a chi non l'ha detta** —
/// ma smette di essere una regola di *esclusione*: una frase bella senza fonte tracciabile entra
/// come **anonima**, invece di sparire o di prendersi un autore che non le spetta.
public struct Phrase: Equatable, Sendable, Identifiable {

    public enum Kind: String, Codable, Sendable {
        /// Ha un'opera identificabile. È il pool più severo.
        case citazione
        /// Pensiero mindful, filosofia orientale, sviluppo personale. Può essere anonimo.
        case mindful
        /// Un fatto, con la sua fonte o dichiarato come consenso.
        case fatto
    }

    public let id: String
    public let kind: Kind
    /// L'italiano. **L'`id` non deriva da qui a caso: deriva dall'italiano apposta.** Vedi la
    /// nota su `Quote.id` — un id che seguisse la lingua mostrata azzererebbe il mazzo a ogni
    /// cambio, senza un errore che lo dica.
    public let text: String
    /// L'inglese. Vuoto durante la migrazione; per i pool già convertiti il test lo pretende.
    public let textEN: String
    /// Chi l'ha detta e dove — «Seneca · Lettere a Lucilio, 82». Vuota quando non esiste una
    /// fonte tracciabile: allora si mostra «anonimo», che è la verità.
    public let attribution: String
    /// La stessa firma in inglese. Vuota quando la firma non c'è, o non è ancora tradotta.
    public let attributionEN: String

    public init(id: String, kind: Kind, text: String, textEN: String = "",
                attribution: String = "", attributionEN: String = "") {
        self.id = id
        self.kind = kind
        self.text = text
        self.textEN = textEN
        self.attribution = attribution
        self.attributionEN = attributionEN
    }

    /// Il testo nella lingua corrente. Ricade sull'italiano se l'inglese non c'è ancora: meglio
    /// una frase nella lingua sbagliata che uno schermo vuoto durante una pausa.
    public var localizedText: String {
        L.language == .italian || textEN.isEmpty ? text : textEN
    }

    /// Cosa scrivere sotto la frase. Mai vuoto: una riga senza firma sembra un errore di
    /// impaginazione, «anonimo» sembra quello che è.
    public var credit: String {
        attribution.isEmpty ? "anonimo" : attribution
    }

    /// La firma nella lingua corrente, con lo stesso ripiego del testo.
    public var localizedCredit: String {
        if L.language == .italian { return credit }
        if !attributionEN.isEmpty { return attributionEN }
        return attribution.isEmpty ? "anonymous" : attribution
    }
}

public extension Quote {
    /// Una citazione verificata, vista come frase del mazzo.
    var phrase: Phrase {
        Phrase(id: "q:\(id)", kind: .citazione,
               text: text, textEN: textEN,
               attribution: "\(author) · \(work)",
               attributionEN: "\(QuoteNames.authorEN(author)) · \(QuoteNames.workEN(work, author: author))")
    }
}

/// Il mazzo: si estrae **senza rimettere dentro**.
///
/// La rotazione deterministica di prima aveva un difetto che si vede solo vivendoci: con
/// quattordici citazioni e l'indice dell'avvio, le frasi tornavano nello stesso ordine, sempre.
/// Il caso puro però ripete — con 500 frasi estratte a caso, la probabilità di rivederne una
/// entro il mese è alta, ed è esattamente la sensazione che si voleva togliere.
///
/// Un mazzo mescolato risolve entrambe: ordine imprevedibile, e **nessuna ripetizione finché non
/// sono uscite tutte**. Quando finisce si rimescola, con l'unica cura che l'ultima uscita non
/// torni prima in cima: due uguali di fila sono l'unica ripetizione che si nota davvero.
///
/// Gli identificativi sono stringhe e non posizioni di proposito: il corpus cresce a ogni
/// versione dell'app, e un mazzo di indici tornerebbe a puntare a frasi diverse dopo un
/// aggiornamento. Gli id spariti si scartano, quelli nuovi entrano al prossimo rimescolo.
public struct PhraseDeck: Codable, Equatable, Sendable {
    public private(set) var remaining: [String]
    public private(set) var lastDrawn: String?

    public init(remaining: [String] = [], lastDrawn: String? = nil) {
        self.remaining = remaining
        self.lastDrawn = lastDrawn
    }

    /// Quante ne restano prima di rimescolare: è il numero che dice «non vedrai una ripetizione
    /// per ancora tante estrazioni».
    public var left: Int { remaining.count }

    public mutating func draw<G: RandomNumberGenerator>(from pool: [Phrase], using generator: inout G) -> Phrase? {
        guard !pool.isEmpty else { return nil }
        let byID = Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        // Le frasi tolte da un aggiornamento non devono bloccare il mazzo.
        remaining = remaining.filter { byID[$0] != nil }
        if remaining.isEmpty { reshuffle(pool: pool, using: &generator) }

        guard let id = remaining.popLast(), let phrase = byID[id] else { return nil }
        lastDrawn = id
        return phrase
    }

    private mutating func reshuffle<G: RandomNumberGenerator>(pool: [Phrase], using generator: inout G) {
        var ids = pool.map(\.id).shuffled(using: &generator)
        // Si estrae dal fondo: l'ultima dell'array è la prossima a uscire.
        if ids.count > 1, ids.last == lastDrawn {
            ids.swapAt(ids.count - 1, 0)
        }
        remaining = ids
    }
}

/// I due mazzi che sopravvivono alla chiusura dell'app.
public struct PhraseDecks: Codable, Equatable, Sendable {
    public var launch = PhraseDeck()
    public var breaks = PhraseDeck()
    public init() {}
}

public enum DeckStore {
    public static func load(from url: URL = Paths.decksFile) -> PhraseDecks {
        guard let data = try? Data(contentsOf: url),
              let decks = try? JSONDecoder().decode(PhraseDecks.self, from: data)
        else { return PhraseDecks() }
        return decks
    }

    @discardableResult
    public static func save(_ decks: PhraseDecks, to url: URL = Paths.decksFile) -> Bool {
        Paths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(decks) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}

/// Tutto quello che si può leggere, e da dove pesca ogni schermata.
public enum PhraseLibrary {

    /// Le tue, aggiunte a mano. Un file che l'app **legge e non scrive mai**: è il solo modo di
    /// far crescere il corpus senza aspettare una versione nuova, e senza chiamare la rete —
    /// che questa app non fa e non farà (ISC-29).
    ///
    /// Formato: `[{"text": "…", "attribution": "Autore · Opera"}]`, l'attribuzione è facoltativa.
    public static func userPhrases(at url: URL = Paths.userPhrasesFile) -> [Phrase] {
        struct Row: Decodable { let text: String; let attribution: String? }
        guard let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([Row].self, from: data)
        else { return [] }
        return rows.enumerated().compactMap { index, row in
            let text = row.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return Phrase(id: "mie:\(index)-\(text.prefix(24))", kind: .mindful, text: text,
                          attribution: row.attribution ?? "")
        }
    }

    /// Il pool delle pause: tutto. Una pausa ogni mezz'ora sono ~16 al giorno, e mescolare le tre
    /// famiglie è ciò che porta il mazzo oltre il mese senza ripetizioni.
    public static func breakPool(includingUser: Bool = true) -> [Phrase] {
        Quotes.all.map(\.phrase) + Mindful.all + Facts.all + (includingUser ? userPhrases() : [])
    }

    /// Il pool dell'avvio: niente fatti scientifici. All'avvio si legge una riga sola, e deve
    /// essere quella che dà il tono alla giornata, non un dato.
    public static func launchPool(includingUser: Bool = true) -> [Phrase] {
        Quotes.all.map(\.phrase) + Mindful.all + (includingUser ? userPhrases() : [])
    }
}
