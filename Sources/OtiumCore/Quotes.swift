import Foundation

/// Una riga da leggere. Non un fortune cookie: il nome dell'app viene da qui.
///
/// **Regola di ammissione di questo pool: solo citazioni con un'opera identificabile.** La più
/// bella che avevo in mente — «la natura non ha fretta, eppure tutto si compie», ovunque
/// attribuita a Lao Tzu — è stata **scartata dopo verifica**: non compare nel Tao Te Ching in
/// nessuna traduzione, è una parafrasi moderna circolata sui social. Un'app che chiede di essere
/// creduta sulle fonti degli studi non può sbagliare una citazione: il criterio è lo stesso, e
/// vale anche quando la frase suona perfetta.
///
/// Le frasi belle **senza** fonte tracciabile non si buttano più: vivono in `Mindful`, dove
/// compaiono come anonime. Perdere l'autore è onesto; inventarlo no.
///
/// **Revisione del 2026-07-28, aperta da un errore che il principale ha visto a schermo** («toglie
/// il giudizio» invece di «togli»). Rilette tutte, e tolte queste, con la fonte del verdetto:
/// - *«Non c'è nulla fuori di te…»*, Musashi — **inventata**: viene dalla riscrittura di Steve
///   Kaufman del 1994, venduta da Tuttle come se fosse il testo di Musashi. Nel Go Rin No Sho non
///   c'è.
/// - *«Non fare nulla che non serva»*, Musashi — non collocabile in nessuno dei 21 precetti del
///   Dokkōdō, ed era per giunta citata come se il Dokkōdō fosse un capitolo del Libro dei cinque
///   anelli, che sono due opere diverse.
/// - *«La salute non è tutto…»*, Schopenhauer — attribuita per la prima volta un secolo dopo la
///   sua morte, mai trovata nelle opere (che sono digitalizzate da tempo). La formula «X non è
///   tutto, ma senza X…» gira dall'Ottocento con parole diverse. Resta l'altra, quella dei nove
///   decimi, che è sua davvero.
/// - *«Le cose che contano di più…»*, Goethe — non è nelle sue opere: al massimo un riporto di
///   seconda mano, e comunque non in *Massime e riflessioni*, che era l'opera dichiarata qui.
/// - *«La felicità non è qualcosa di pronto»*, Dalai Lama — nessuna pagina, solo aggregatori di
///   citazioni. Il sito da cui l'hai presa non è un'opera.
/// Tolti anche cinque doppioni: lo stesso passo compariva due volte con parole diverse (Seneca
/// due volte, Epitteto, Confucio, Franklin).
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

    /// Scorciatoia per tenere leggibile un elenco lungo.
    private static func q(_ text: String, _ author: String, _ work: String) -> Quote {
        Quote(text, author: author, work: work)
    }

    // MARK: - Stoici

    static let stoici: [Quote] = [
        q("L'ozio senza studio è morte, è tomba dell'uomo vivo.", "Seneca", "Lettere a Lucilio, 82"),
        q("Tutto è d'altri, Lucilio: solo il tempo è nostro.", "Seneca", "Lettere a Lucilio, 1"),
        q("Non abbiamo poco tempo: ne perdiamo molto.", "Seneca", "La brevità della vita, 1"),
        q("Ogni giorno, ogni ora rivela quanto siamo nulla.", "Seneca", "Lettere a Lucilio, 24"),
        q("Nessun vento è favorevole per il marinaio che non sa dove andare.", "Seneca", "Lettere a Lucilio, 71"),
        q("Soffriamo più nell'immaginazione che nella realtà.", "Seneca", "Lettere a Lucilio, 13"),
        q("Comincia subito a vivere, e conta ogni giorno come una vita a sé.", "Seneca", "Lettere a Lucilio, 101"),
        q("Rimandare è la più grande perdita di tempo: porta via il giorno di oggi.", "Seneca", "La brevità della vita, 9"),
        q("Vivere è la cosa che si impara per tutta la vita.", "Seneca", "La brevità della vita, 7"),
        q("Fa' che il corpo obbedisca all'animo senza fatica.", "Seneca", "Lettere a Lucilio, 15"),
        q("Esercitare il corpo con poco, e tornare presto alla mente: è questo il modo.", "Seneca", "Lettere a Lucilio, 15"),
        q("Chi è ovunque non è da nessuna parte: la vita dispersa è la più povera.", "Seneca", "Lettere a Lucilio, 2"),
        q("Non c'è bonaccia peggiore di quella dell'animo che non sa dove tende.", "Seneca", "Lettere a Lucilio, 95"),

        q("Fa' ogni cosa come se fosse l'ultima della tua vita.", "Marco Aurelio", "Pensieri, II"),
        q("Se soffri per qualcosa di esterno, non è quella cosa a turbarti, ma il tuo giudizio su di essa.", "Marco Aurelio", "Pensieri, VIII"),
        q("L'anima prende il colore dei suoi pensieri.", "Marco Aurelio", "Pensieri, V"),
        q("Al mattino, quando ti alzi controvoglia, ricorda: mi sveglio per fare il lavoro di un essere umano.", "Marco Aurelio", "Pensieri, V"),
        q("La vita è ciò che i nostri pensieri la fanno diventare.", "Marco Aurelio", "Pensieri, IV"),
        q("Non perdere altro tempo a discutere come dovrebbe essere un uomo buono. Sii buono.", "Marco Aurelio", "Pensieri, X"),
        q("Guarda dentro: dentro è la sorgente del bene, e può zampillare sempre, se scavi.", "Marco Aurelio", "Pensieri, VII"),
        q("Ciò che ostacola l'azione fa avanzare l'azione. Ciò che sta sulla strada diventa la strada.", "Marco Aurelio", "Pensieri, V"),
        q("Hai potere sulla tua mente, non sugli eventi esterni. Renditene conto e troverai la forza.", "Marco Aurelio", "Pensieri, VIII"),
        q("Ogni ora decidi con fermezza di fare ciò che hai per le mani, con dignità semplice.", "Marco Aurelio", "Pensieri, II"),
        q("Presto avrai dimenticato tutto; presto tutti avranno dimenticato te.", "Marco Aurelio", "Pensieri, VII"),
        q("Non agire come se dovessi vivere diecimila anni.", "Marco Aurelio", "Pensieri, IV"),
        q("La perfezione del carattere è vivere ogni giorno come fosse l'ultimo, senza smania e senza torpore.", "Marco Aurelio", "Pensieri, VII"),
        q("Il tuo dovere è restare uomo giusto, come il masso a cui l'onda si rompe intorno.", "Marco Aurelio", "Pensieri, IV"),
        q("Togli il giudizio, e avrai tolto il «sono stato danneggiato».", "Marco Aurelio", "Pensieri, IV, 7"),

        q("Non sono le cose a turbare gli uomini, ma le opinioni che essi ne hanno.", "Epitteto", "Manuale, 5"),
        q("Alcune cose dipendono da noi, altre no.", "Epitteto", "Manuale, 1"),
        q("Non chiedere che le cose vadano come vuoi tu: vogli che vadano come vanno, e starai bene.", "Epitteto", "Manuale, 8"),
        q("Ricordati che sei un attore in un dramma scelto dall'autore.", "Epitteto", "Manuale, 17"),
        q("Se vuoi migliorare, accetta di sembrare sciocco riguardo alle cose esterne.", "Epitteto", "Manuale, 13"),
        q("Non dire mai di nulla «l'ho perso», ma «l'ho restituito».", "Epitteto", "Manuale, 11"),
        q("Non è chi ti insulta a offenderti, ma il tuo giudizio che quello sia un insulto.", "Epitteto", "Manuale, 20"),
        q("Delle cose del corpo prendi solo quanto basta all'uso: cibo, bevanda, vestito, casa.", "Epitteto", "Manuale, 33"),
        q("Prima decidi chi vuoi essere, poi fa' quello che devi fare.", "Epitteto", "Discorsi, III"),
        q("Nessuno è libero se non è padrone di sé.", "Epitteto", "Discorsi, IV"),

        q("Otium cum dignitate — il riposo che non toglie nulla alla dignità.", "Cicerone", "Pro Sestio, 98"),
        q("Vivere è pensare.", "Cicerone", "Tusculanae disputationes, V"),
        q("Il giardino e la biblioteca: se hai questi, hai tutto quello che serve.", "Cicerone", "Lettere a Varrone (Ad familiares, IX)"),
        q("Nessuno è così vecchio da non credere di poter vivere ancora un anno.", "Cicerone", "De senectute, 24"),
        q("Il tempo distrugge le finzioni dell'opinione, e conferma i giudizi della natura.", "Cicerone", "De natura deorum, II"),
    ]

    // MARK: - Filosofia occidentale

    static let occidentali: [Quote] = [
        q("Chi ha un perché abbastanza forte può sopportare quasi ogni come.", "Nietzsche", "Crepuscolo degli idoli, Massime e strali 12"),
        q("Bisogna avere ancora un caos dentro di sé per partorire una stella danzante.", "Nietzsche", "Così parlò Zarathustra, Prologo"),
        q("Diventa ciò che sei.", "Nietzsche", "Ecce homo (dal motto di Pindaro)"),
        q("Solo i pensieri che vengono camminando hanno valore.", "Nietzsche", "Crepuscolo degli idoli, Massime e strali 34"),
        q("Chi combatte con i mostri deve guardarsi dal non diventarlo.", "Nietzsche", "Al di là del bene e del male, 146"),
        q("Il segreto per raccogliere dall'esistenza la massima fecondità è vivere pericolosamente.", "Nietzsche", "La gaia scienza, 283"),

        q("Tutta l'infelicità degli uomini deriva da una cosa sola: non saper restare in riposo in una stanza.", "Pascal", "Pensieri, 139"),
        q("Il cuore ha le sue ragioni che la ragione non conosce.", "Pascal", "Pensieri, 277"),
        q("Ho scritto una lettera lunga perché non ho avuto il tempo di scriverne una breve.", "Pascal", "Lettere provinciali, XVI"),

        q("La vita che ci è data è breve, ma la memoria di una vita ben spesa è eterna.", "Montaigne", "Saggi, I"),
        q("La più grande cosa del mondo è saper appartenere a sé stessi.", "Montaigne", "Saggi, I, 39"),

        q("L'uomo libero a nulla pensa meno che alla morte, e la sua saggezza è meditazione della vita.", "Spinoza", "Etica, IV, prop. 67"),
        q("Non ridere, non piangere, non detestare: comprendere.", "Spinoza", "Trattato politico, I"),

        q("La maggior parte degli uomini conduce vite di quieta disperazione.", "Thoreau", "Walden, I"),
        q("Andai nei boschi perché volevo vivere deliberatamente, affrontare solo i fatti essenziali della vita.", "Thoreau", "Walden, II"),
        q("Semplifica, semplifica.", "Thoreau", "Walden, II"),
        q("Non basta essere occupati: anche le formiche lo sono. La domanda è: di che cosa siamo occupati?", "Thoreau", "Lettere a H. Blake"),
        q("Il costo di una cosa è la quantità di vita che devi scambiare per averla.", "Thoreau", "Walden, I"),

        q("Fa' la cosa e avrai il potere.", "Emerson", "Saggi, Compensazione"),

        q("Nove decimi della nostra felicità dipendono dalla salute.", "Schopenhauer", "Aforismi sulla saggezza del vivere, II"),

        // **Recuperate dal pool anonimo il 2026-07-28.** Non erano frasi senza padre: erano
        // citazioni a cui la firma era stata tolta strada facendo, che è l'errore opposto a
        // inventare un autore ma resta un errore.
        q("Sembra che la perfezione sia raggiunta non quando non c'è più niente da aggiungere, ma quando non c'è più niente da togliere.", "Antoine de Saint-Exupéry", "Terre des hommes, III"),
        q("Non puoi fermare le onde, ma puoi imparare a fare surf.", "Jon Kabat-Zinn", "Dovunque tu vada, ci sei già"),
        q("La vita può essere capita solo all'indietro, ma va vissuta in avanti.", "Kierkegaard", "Diari, IV A 164"),
        q("Soprattutto, non perdere il desiderio di camminare.", "Kierkegaard", "Lettera a Jette, 1847"),

        q("Ama la vita? Allora non sprecare il tempo, perché è la materia di cui la vita è fatta.", "Benjamin Franklin", "Poor Richard's Almanack, 1746"),

        q("L'uomo può essere privato di tutto, tranne di una cosa: la scelta del proprio atteggiamento.", "Viktor Frankl", "Alla ricerca di un significato della vita"),
        q("Chi ha un perché per vivere può sopportare quasi ogni come.", "Viktor Frankl", "Alla ricerca di un significato della vita (citando Nietzsche)"),

        q("L'abitudine è il volano della società, il suo agente conservatore più prezioso.", "William James", "Principi di psicologia, IV"),
        q("L'arte di essere saggi è l'arte di sapere cosa trascurare.", "William James", "Principi di psicologia, XXII"),
    ]

    // MARK: - Oriente

    static let orientali: [Quote] = [
        q("Un viaggio di mille miglia comincia con un passo.", "Laozi", "Tao Te Ching, 64"),
        q("Chi conosce gli altri è sapiente; chi conosce sé stesso è illuminato.", "Laozi", "Tao Te Ching, 33"),
        q("Chi vince gli altri ha forza; chi vince sé stesso è potente.", "Laozi", "Tao Te Ching, 33"),
        q("Chi sa di avere abbastanza è ricco.", "Laozi", "Tao Te Ching, 33"),
        q("Il Tao di cui si può parlare non è l'eterno Tao.", "Laozi", "Tao Te Ching, 1"),
        q("La suprema bontà è come l'acqua: giova a tutte le cose e non contende.", "Laozi", "Tao Te Ching, 8"),
        q("Trenta raggi convergono nel mozzo, ma è il vuoto al centro che fa girare la ruota.", "Laozi", "Tao Te Ching, 11"),
        q("Chi sa non parla; chi parla non sa.", "Laozi", "Tao Te Ching, 56"),
        q("Agisci senza sforzare, opera senza affannarti.", "Laozi", "Tao Te Ching, 63"),
        q("Affronta il difficile finché è facile; fa' la grande cosa finché è piccola.", "Laozi", "Tao Te Ching, 63"),
        q("L'albero che riempie le braccia nasce da un germoglio sottile.", "Laozi", "Tao Te Ching, 64"),
        q("Il grande quadrato non ha angoli; il grande talento matura tardi.", "Laozi", "Tao Te Ching, 41"),
        q("Ritirarsi a opera compiuta è la via del cielo.", "Laozi", "Tao Te Ching, 9"),
        q("Chi si mette in punta di piedi non sta ritto a lungo.", "Laozi", "Tao Te Ching, 24"),
        q("Chi sa accontentarsi non si disonora; chi sa fermarsi non corre pericolo.", "Laozi", "Tao Te Ching, 44"),

        q("Il pesce dimentica la rete quando è nel fiume; l'uomo dimentica le parole quando ha il senso.", "Zhuangzi", "Zhuangzi, XXVI"),
        q("La calma perfetta dell'uomo saggio è specchio del cielo e della terra.", "Zhuangzi", "Zhuangzi, XIII"),
        q("Chi guarda il proprio riflesso nell'acqua corrente non lo vede: solo l'acqua ferma riflette.", "Zhuangzi", "Zhuangzi, V"),

        q("Chi impara senza pensare è perduto; chi pensa senza imparare è in pericolo.", "Confucio", "Dialoghi, II, 15"),
        q("Quando vedi una persona di valore, cerca di eguagliarla; quando ne vedi una senza, guarda dentro di te.", "Confucio", "Dialoghi, IV, 17"),
        q("L'uomo superiore chiede a sé stesso; l'uomo comune chiede agli altri.", "Confucio", "Dialoghi, XV, 20"),
        q("A quindici anni volsi la mente allo studio; a trenta stavo ritto.", "Confucio", "Dialoghi, II, 4"),
        q("Errare e non correggersi: questo è errare davvero.", "Confucio", "Dialoghi, XV, 30"),

        q("Tutto ciò che siamo è il risultato di ciò che abbiamo pensato.", "Buddha", "Dhammapada, I, 1"),
        q("L'odio non si placa con l'odio: si placa con il non odio.", "Buddha", "Dhammapada, I, 5"),
        q("Meglio una sola parola che porta pace, che mille parole vuote.", "Buddha", "Dhammapada, VIII, 100"),
        q("Chi vince sé stesso è più grande di chi vince mille uomini in battaglia.", "Buddha", "Dhammapada, VIII, 103"),
        q("Non trascurare il proprio bene per quello altrui, per quanto grande.", "Buddha", "Dhammapada, XII, 166"),
        q("Come la pioggia penetra una casa mal coperta, così la passione penetra una mente non allenata.", "Buddha", "Dhammapada, I, 13"),
        q("La mente è difficile da domare, veloce, si posa dove vuole: domarla è bene.", "Buddha", "Dhammapada, III, 35"),
        q("Goccia a goccia si riempie il secchio.", "Buddha", "Dhammapada, IX, 122"),
        q("Il risvegliato può solo indicare la via: siamo noi a doverla percorrere.", "Buddha", "Dhammapada, XX, 276"),

        q("Il tuo diritto è all'azione, mai ai suoi frutti.", "Bhagavad Gita", "Bhagavad Gita, II, 47"),
        q("Meglio il proprio dovere fatto male che quello altrui fatto bene.", "Bhagavad Gita", "Bhagavad Gita, III, 35"),
        q("Lo yoga non è per chi mangia troppo né per chi digiuna, non per chi dorme troppo né per chi veglia.", "Bhagavad Gita", "Bhagavad Gita, VI, 16"),
        q("Chi è moderato nel mangiare e nel riposo, nel lavoro e nel sonno, per lui lo yoga scioglie ogni pena.", "Bhagavad Gita", "Bhagavad Gita, VI, 17"),

        q("Non seguire le orme degli antichi: cerca ciò che essi cercavano.", "Matsuo Bashō", "Sulle tracce degli antichi (Oi no kobumi)"),
        q("Ogni giorno è un viaggio, e il viaggio stesso è casa.", "Matsuo Bashō", "Lo stretto sentiero verso il profondo Nord"),

        q("Nella mente del principiante ci sono molte possibilità; in quella dell'esperto, poche.", "Shunryu Suzuki", "Mente zen, mente di principiante"),
        q("Quando fai qualcosa, devi bruciarti completamente, come un buon falò.", "Shunryu Suzuki", "Mente zen, mente di principiante"),

        q("Studiare la via del Buddha è studiare sé stessi; studiare sé stessi è dimenticare sé stessi.", "Dōgen", "Shōbōgenzō, Genjōkōan"),
        q("Il tempo vola più veloce di una freccia: non sprecare un istante.", "Dōgen", "Gakudō yōjinshū"),

        q("Percepisci ciò che l'occhio non vede.", "Miyamoto Musashi", "Il libro dei cinque anelli, Il libro dell'acqua"),

        q("Chi conosce il nemico e conosce sé stesso non sarà in pericolo in cento battaglie.", "Sunzi", "L'arte della guerra, III"),
        q("La suprema arte della guerra è sottomettere il nemico senza combattere.", "Sunzi", "L'arte della guerra, III"),

        q("Il lavoro è amore reso visibile.", "Kahlil Gibran", "Il profeta, Il lavoro"),
        q("I vostri figli non sono figli vostri: sono i figli e le figlie della vita.", "Kahlil Gibran", "Il profeta, I figli"),

        q("Alzati, svegliati, e non fermarti finché la meta non è raggiunta.", "Katha Upanishad", "Katha Upanishad, I, 3, 14"),
        q("Come un uomo si spoglia di vesti logore e ne indossa di nuove, così l'anima lascia il corpo.", "Bhagavad Gita", "Bhagavad Gita, II, 22"),
    ]

    /// Tutte le citazioni verificate. `Mindful` tiene quelle senza fonte tracciabile.
    public static let all: [Quote] = stoici + occidentali + orientali
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
        "Detto e fatto.", "Questa è disciplina.", "Un'altra nel conto.", "Preciso.",
        "Non era scontato: l'hai fatta.", "Il corpo ringrazia.", "Puntuale.",
    ]
    public static let afterHardOne = [
        "Quella era la parte dura.", "Col fiatone, come deve essere.",
        "La più faticosa della giornata, fatta.", "Bel fegato.",
        "Quella costava, e l'hai pagata.", "Cuore a mille: è il punto.",
        "La più scomoda, tolta di mezzo.",
    ]

    public static func line(at index: Int, hard: Bool = false) -> String {
        let list = hard ? afterHardOne : afterBreak
        return list[((index % list.count) + list.count) % list.count]
    }
}
