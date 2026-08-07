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
        /// Un fatto, con la sua fonte o dichiarato come consenso scientifico.
        case fatto
        /// **La voce dell'app.** Righe scritte per Otium, non citazioni di nessuno.
        ///
        /// Esiste perché fino al 2026-07-29 stavano nel pool anonimo e uscivano a schermo dentro
        /// i caporali con «anonimo» sotto: vestite da aforisma di cui si è perso l'autore, mentre
        /// un autore non c'è mai stato. «Le mani sono contratte sul mouse da un'ora. Aprile.» non
        /// è una massima orientale, è l'app che ti parla, e presentarla così era la stessa bugia
        /// che il pool firmato vieta — solo più difficile da vedere, perché non c'era nessun nome
        /// sbagliato da controllare.
        ///
        /// Restano `mindful` **anonime** solo le frasi che qualcuno ha davvero detto e di cui non
        /// sappiamo chi: quelle tengono i caporali e la firma «anonimo».
        case voce
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

    /// Come la frase si legge a schermo: i caporali ci sono per tutti tranne la voce dell'app,
    /// che non cita nessuno.
    ///
    /// Sta qui e non nelle viste perché le superfici che mostrano una frase sono tre, e la
    /// regola dei caporali stava scritta tre volte: il giorno che cambia, ne cambierebbe una.
    public var displayText: String {
        kind == .voce ? localizedText : "«\(localizedText)»"
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
    /// Il tipo dell'ultima uscita, per non darne due uguali di fila. Assente nei mazzi salvati
    /// prima del 2026-07-31: vale `nil`, e la regola comincia a valere dall'estrazione dopo.
    public private(set) var lastKind: Phrase.Kind?

    public init(remaining: [String] = [], lastDrawn: String? = nil, lastKind: Phrase.Kind? = nil) {
        self.remaining = remaining
        self.lastDrawn = lastDrawn
        self.lastKind = lastKind
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

        // **Mai due dello stesso tipo di fila.**
        //
        // Il mazzo era già mescolato davvero — sondato il 2026-07-31 sul file vivo, le dodici
        // successive erano `q m q q t f m f q q m q` — ma un mescolamento uniforme produce
        // grappoli, ed è così che nasce l'impressione che l'app «dia solo studi»: quattro fatti
        // consecutivi sono normalissimi in 480 estrazioni, e li vivi tutti in una mattina.
        // Segnalato dal principale, che aveva torto sul meccanismo e ragione su quello che
        // vedeva.
        //
        // Qui il grappolo si rompe: se il tipo è lo stesso dell'ultima uscita, si cerca più giù
        // la prima di tipo diverso e la si porta avanti. **Solo uno scambio, non un
        // rimescolamento**: l'ordine resta quello estratto a caso, e la garanzia di non ripetersi
        // per 480 pause resta intatta. Se in fondo al mazzo restano solo frasi dello stesso tipo,
        // esce quella che c'è — meglio un tipo ripetuto che una pausa senza niente.
        if let precedente = lastKind, phrase.kind == precedente,
           let scambio = remaining.lastIndex(where: { byID[$0]?.kind != precedente }) {
            remaining.append(id)
            let diverso = remaining.remove(at: scambio)
            lastDrawn = diverso
            lastKind = byID[diverso]?.kind
            return byID[diverso]
        }

        lastDrawn = id
        lastKind = phrase.kind
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
