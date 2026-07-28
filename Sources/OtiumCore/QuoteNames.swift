import Foundation

/// I nomi degli autori e i titoli delle opere, nelle due lingue.
///
/// **Perché una tabella qui e non una coppia in linea come per la UI.** `Strings.swift` spiega
/// che con due lingue la coppia in linea batte la tabella di chiavi, e per la UI è vero: ogni
/// frase è unica, e l'indirezione costerebbe più di quanto rende. Qui il rapporto è rovesciato.
/// «Lettere a Lucilio» compare in 44 citazioni e «Seneca» in 99: scriverne la traduzione accanto
/// a ognuna vuol dire 143 copie della stessa parola, che è il modo in cui due copie finiscono per
/// non essere più uguali. Molti-a-uno vuole una tabella.
///
/// **Il rischio della tabella — la chiave sbagliata che non fallisce — è chiuso da un test**, non
/// dalla buona volontà: `QuoteNamesTests` pretende che ogni autore e ogni segmento di titolo
/// presente nei pool abbia una voce qui. Aggiungere una citazione con un'opera nuova e scordarsi
/// la traduzione fa fallire la suite, non uscire una riga a metà in italiano.
///
/// **I titoli si traducono a segmenti, non interi.** Un'opera si scrive «Titolo, libro, numero»
/// — «Lettere a Lucilio, 82», «Saggi, Degli studi», «Bhagavad Gita, II, 47». Tradurre la stringa
/// intera vorrebbe dire ~200 voci, quasi tutte varianti dello stesso titolo con un numero diverso.
/// A segmenti ne bastano ~70: i numeri e i numeri romani passano intatti, e restano da tradurre
/// solo i titoli veri e i nomi dei capitoli.
public enum QuoteNames {

    // MARK: - Autori

    /// Solo chi cambia davvero. Un nome che in inglese si scrive uguale non entra qui: la ricerca
    /// ricade sull'originale, che è già giusto, e la tabella resta corta abbastanza da leggersi.
    private static let authors: [String: String] = [
        "Cicerone": "Cicero",
        "Confucio": "Confucius",
        "Epitteto": "Epictetus",
        "Marco Aurelio": "Marcus Aurelius",
        "Sunzi": "Sun Tzu",
        "Laozi": "Laozi",
        "Buddha": "the Buddha",
    ]

    /// Il nome dell'autore in inglese, **senza guardare la lingua corrente**. Serve a chi
    /// costruisce le due versioni insieme, come `Quote.phrase`, che le prepara entrambe una volta
    /// sola e lascia decidere alla vista.
    public static func authorEN(_ italian: String) -> String {
        authors[italian] ?? italian
    }

    /// Il nome dell'autore nella lingua corrente.
    public static func author(_ italian: String) -> String {
        L.language == .italian ? italian : authorEN(italian)
    }

    // MARK: - Titoli e capitoli

    /// I segmenti che cambiano. La chiave può essere scoped all'autore — `"Marco Aurelio|Pensieri"`
    /// — perché **«Pensieri» è tre opere diverse**: le *Meditationes* di Marco Aurelio, le *Pensées*
    /// di Pascal e i *Pensieri* di Leopardi. Una tabella a chiave nuda le avrebbe fuse in silenzio,
    /// ed è il difetto che questa forma esiste per impedire.
    private static let works: [String: String] = [
        // — scoped, dove lo stesso titolo italiano è opere diverse
        "Marco Aurelio|Pensieri": "Meditations",
        "Pascal|Pensieri": "Pensées",
        "Leopardi|Pensieri": "Thoughts",

        // — Seneca
        "Lettere a Lucilio": "Letters to Lucilius",
        "La brevità della vita": "On the Shortness of Life",

        // — greci e romani
        "Manuale": "Enchiridion",
        "Discorsi": "Discourses",
        "De natura deorum": "De natura deorum",
        "De senectute": "De senectute",
        "Pro Sestio": "Pro Sestio",
        "Tusculanae disputationes": "Tusculanae disputationes",
        "Lettere a Varrone (Ad familiares": "Letters to Varro (Ad familiares",

        // — saggisti
        "Saggi": "Essays",
        "Degli studi": "Of Studies",
        "Del governo della salute": "Of Regiment of Health",
        "Del regime della salute": "Of Regiment of Health",
        "Dell'abitudine e dell'educazione": "Of Custom and Education",
        "Della natura negli uomini": "Of Nature in Men",
        "Della speditezza": "Of Dispatch",
        "Delle innovazioni": "Of Innovations",
        "Dell'educazione dei fanciulli": "Of the Education of Children",
        "Dell'esperienza": "Of Experience",
        "Della solitudine": "Of Solitude",
        "Cerchi": "Circles",
        "Compensazione": "Compensation",
        "Eroismo": "Heroism",
        "Prudenza": "Prudence",

        // — tedeschi
        "La filosofia della libertà": "The Philosophy of Freedom",
        "La concezione goethiana del mondo": "Goethe's World View",
        "Personalità": "Personality",
        "Così parlò Zarathustra": "Thus Spoke Zarathustra",
        "Prologo": "Prologue",
        "Dei disprezzatori del corpo": "On the Despisers of the Body",
        "Del leggere e dello scrivere": "On Reading and Writing",
        "Crepuscolo degli idoli": "Twilight of the Idols",
        "Massime e strali 12": "Maxims and Arrows 12",
        "Massime e strali 34": "Maxims and Arrows 34",
        "Al di là del bene e del male": "Beyond Good and Evil",
        "La gaia scienza": "The Gay Science",
        "Ecce homo (dal motto di Pindaro)": "Ecce Homo (after Pindar's motto)",
        "Aforismi sulla saggezza del vivere": "Aphorisms on the Wisdom of Life",
        "Alla ricerca di un significato della vita": "Man's Search for Meaning",
        "Alla ricerca di un significato della vita (citando Nietzsche)":
            "Man's Search for Meaning (quoting Nietzsche)",

        // — italiani e francesi
        "Operette morali": "Small Moral Works",
        "Cantico del gallo silvestre": "Canticle of the Wild Rooster",
        "Dialogo della Natura e di un Islandese": "Dialogue Between Nature and an Icelander",
        "Lettere provinciali": "The Provincial Letters",
        "Terre des hommes": "Wind, Sand and Stars",

        // — inglesi e americani
        "Walden": "Walden",
        "Lettere a H. Blake": "Letters to H. Blake",
        "Foglie d'erba": "Leaves of Grass",
        "Canto di me stesso": "Song of Myself",
        "Canto della strada aperta": "Song of the Open Road",
        "La via della ricchezza": "The Way to Wealth",
        "Poor Richard's Almanack": "Poor Richard's Almanack",
        "Principi di psicologia": "The Principles of Psychology",
        "Dovunque tu vada": "Wherever You Go",
        "ci sei già": "There You Are",

        // — orientali
        "Tao Te Ching": "Tao Te Ching",
        "Dhammapada": "Dhammapada",
        "Dialoghi": "Analects",
        "Bhagavad Gita": "Bhagavad Gita",
        "Katha Upanishad": "Katha Upanishad",
        "Zhuangzi": "Zhuangzi",
        "L'arte della guerra": "The Art of War",
        "Il profeta": "The Prophet",
        "I figli": "On Children",
        "Il lavoro": "On Work",
        "Mente zen": "Zen Mind",
        "mente di principiante": "Beginner's Mind",
        "Il libro dei cinque anelli": "The Book of Five Rings",
        "Il libro dell'acqua": "The Water Book",
        "Lo stretto sentiero verso il profondo Nord": "The Narrow Road to the Deep North",
        "Sulle tracce degli antichi (Oi no kobumi)": "The Records of a Travel-Worn Satchel (Oi no kobumi)",
        "Shōbōgenzō": "Shōbōgenzō",
        "Genjōkōan": "Genjōkōan",
        "Gakudō yōjinshū": "Gakudō yōjinshū",

        // — altri
        "Etica": "Ethics",
        "Trattato politico": "Political Treatise",
        "Diari": "Journals",
        "Lettera a Jette": "Letter to Jette",
    ]

    /// Un segmento che non va tradotto perché non è una parola ma un **riferimento**: «82», «IV»,
    /// «prop. 67», «1758», «IX)», «IV A 164».
    ///
    /// Si guarda token per token, e un token vale come riferimento se è tutto cifre, tutto lettere
    /// romane, una singola maiuscola (il marcatore di sezione in «IV A 164», il codice dei diari
    /// di Kierkegaard) o la sigla `prop.`. La punteggiatura di coda si toglie prima: «IX)» chiude
    /// la parentesi aperta nel segmento precedente — «Lettere a Varrone (Ad familiares, IX)» — e
    /// senza questo passaggio il test lo chiedeva come se fosse un titolo da tradurre.
    ///
    /// **Perché a token e non con una lista.** Una lista di riferimenti noti si dimentica di
    /// aggiornare, e il modo in cui fallisce è mite: il segmento risulta «da tradurre», il test
    /// diventa rosso e qualcuno aggiunge una voce inutile alla tabella. La forma, invece, vale
    /// anche per i riferimenti che non ho ancora visto.
    static func isNumeric(_ segment: String) -> Bool {
        let s = segment.trimmingCharacters(in: CharacterSet(charactersIn: " ().,;:"))
        if s.isEmpty { return true }
        if s.hasPrefix("prop.") { return true }
        let romanChars = CharacterSet(charactersIn: "IVXLCDM")
        return s.split(separator: " ").allSatisfy { token in
            if token.allSatisfy(\.isNumber) { return true }
            if token.count == 1, token.first!.isUppercase { return true }
            return token.unicodeScalars.allSatisfy { romanChars.contains($0) }
        }
    }

    /// L'opera in inglese, segmento per segmento, **senza guardare la lingua corrente**.
    public static func workEN(_ italian: String, author: String = "") -> String {
        italian
            .components(separatedBy: ", ")
            .map { segment -> String in
                if isNumeric(segment) { return segment }
                if !author.isEmpty, let scoped = works["\(author)|\(segment)"] { return scoped }
                return works[segment] ?? segment
            }
            .joined(separator: ", ")
    }

    /// L'opera nella lingua corrente.
    public static func work(_ italian: String, author: String = "") -> String {
        L.language == .italian ? italian : workEN(italian, author: author)
    }

    /// I segmenti di un titolo che pretendono una traduzione. Il test li chiede al corpus e
    /// verifica che ognuno la trovi: è la rete che rende sicura la tabella.
    public static func translatableSegments(of work: String) -> [String] {
        work.components(separatedBy: ", ").filter { !isNumeric($0) }
    }

    /// Esiste una traduzione per questo segmento? Solo per il test.
    public static func hasWorkTranslation(_ segment: String, author: String) -> Bool {
        works["\(author)|\(segment)"] != nil || works[segment] != nil
    }

    /// Esiste una traduzione (o un nome identico) per questo autore? Solo per il test.
    /// Un autore che si scrive uguale in inglese è legittimo: `authors` tiene solo chi cambia.
    public static func isKnownAuthor(_ italian: String) -> Bool {
        authors[italian] != nil || !italian.isEmpty
    }
}
