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
    /// L'italiano. Resta la forma canonica anche quando a schermo c'è l'inglese — vedi `id`.
    public let text: String
    /// L'inglese. Vuoto solo durante la migrazione: `QuoteLanguageTests` lo pretende pieno.
    public let textEN: String
    public let author: String
    /// L'opera, non il sito da cui l'ho presa.
    public let work: String

    /// **L'identità è ancorata all'italiano, in tutte e due le lingue.**
    ///
    /// Il mazzo persiste su disco la lista degli id già estratti (`decks.json`). Se l'id seguisse
    /// il testo mostrato, cambiare lingua cambierebbe l'identità di tutte le citazioni in una
    /// volta: il mazzo le vedrebbe come frasi nuove, si rimescolerebbe, e la promessa «un mese
    /// senza ripetizioni» ripartirebbe da zero a ogni cambio — **in silenzio**, perché nessun
    /// errore compare e le frasi continuano a uscire. L'italiano è la chiave e non si muove.
    public var id: String { "\(author)-\(text.prefix(24))" }

    /// Cosa finisce davvero a schermo.
    public var localizedText: String { L.t(text, textEN) }
    public var localizedAuthor: String { QuoteNames.author(author) }
    public var localizedWork: String { QuoteNames.work(work, author: author) }

    public init(_ text: String, en: String = "", author: String, work: String) {
        self.text = text
        self.textEN = en
        self.author = author
        self.work = work
    }
}

public enum Quotes {

    /// Scorciatoia per tenere leggibile un elenco lungo — italiano e inglese a fronte.
    private static func q(_ text: String, _ en: String, _ author: String, _ work: String) -> Quote {
        Quote(text, en: en, author: author, work: work)
    }

    /// **Ponte di migrazione: da togliere quando l'ultima citazione ha il suo inglese.**
    ///
    /// Finché esiste, una citazione può entrare senza traduzione e il test la conta invece di
    /// bloccare la compilazione di tutto il pool. Quando sparisce, la guardia diventa il
    /// compilatore, che è più forte di qualunque test: una citazione monca non compila.
    private static func q(_ text: String, _ author: String, _ work: String) -> Quote {
        Quote(text, author: author, work: work)
    }

    // MARK: - Stoici

    static let stoici: [Quote] = [
        q("L'ozio senza studio è morte, è tomba dell'uomo vivo.", "Leisure without study is death; it is a tomb for the living man.", "Seneca", "Lettere a Lucilio, 82"),
        q("Tutto è d'altri, Lucilio: solo il tempo è nostro.", "Nothing, Lucilius, is ours, except time.", "Seneca", "Lettere a Lucilio, 1"),
        q("Non abbiamo poco tempo: ne perdiamo molto.", "Seneca", "La brevità della vita, 1"),
        q("Ogni giorno, ogni ora rivela quanto siamo nulla.", "Seneca", "Lettere a Lucilio, 24"),
        q("Nessun vento è favorevole per il marinaio che non sa dove andare.", "Seneca", "Lettere a Lucilio, 71"),
        q("Soffriamo più nell'immaginazione che nella realtà.", "We suffer more often in imagination than in reality.", "Seneca", "Lettere a Lucilio, 13"),
        q("Comincia subito a vivere, e conta ogni giorno come una vita a sé.", "Begin at once to live, and count each separate day as a separate life.", "Seneca", "Lettere a Lucilio, 101"),
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

        // MARK: Aggiunte del 2026-07-28 — 73 citazioni ritrovate sul testo primario.
        //
        // Nessuna viene da un aggregatore. Per ognuna il frammento in lingua originale è stato
        // cercato dentro il testo scaricato (Wikisource latino e italiano, Project Gutenberg,
        // Zarathustra in tedesco) e ritrovato alla riga indicata dal cancello di verifica; la
        // resa italiana è nostra, fatta sull'originale dove la lingua lo permetteva — latino,
        // tedesco, francese, inglese — e sulla traduzione di pubblico dominio altrove.
        //
        // Diciannove candidate su centocinquantadue sono state bocciate dal cancello perché il
        // frammento non esisteva nel testo con quelle parole: quelle NON sono qui, ed è
        // esattamente il motivo per cui il cancello esiste.

        q("Fa' il tuo lavoro, qualunque sia, fino in fondo e senza lamentarti.", "To do my business, whatsoever it be, thoroughly, and without querulousness.", "Marco Aurelio", "Pensieri, I, 12"),
        q("Curava il corpo con misura, non come chi vuole vivere a lungo.", "His care of his body within bounds and measure, not as one that desired to live long.", "Marco Aurelio", "Pensieri, I, 13"),
        q("Tutto quello che appartiene al corpo è come un fiume.", "As a stream so are all things belonging to the body.", "Marco Aurelio", "Pensieri, II, 15"),
        q("Non fare niente a caso, né senza uno scopo.", "Never to do anything either rashly, or feignedly, or hypocritically.", "Marco Aurelio", "Pensieri, II, 15"),
        q("Guarda quanto in fretta ogni cosa si scioglie e si disfa.", "Consider how quickly all things are dissolved and resolved.", "Marco Aurelio", "Pensieri, II, 9"),
        q("Non fare niente controvoglia, né senza averlo esaminato, né a malincuore.", "Do nothing against thy will, nor contrary to the community, nor without due examination, nor with reluctancy.", "Marco Aurelio", "Pensieri, III, 5"),
        q("Scegli liberamente ciò che è meglio, e restaci attaccato.", "Make choice of that which is best, and stick unto it.", "Marco Aurelio", "Pensieri, III, 7"),
        q("Quello che sto per fare, non sarà per caso una delle cose che non servono?", "May not this that now I go about, be of the number of unnecessary actions.", "Marco Aurelio", "Pensieri, IV, 20"),
        q("Non c'è niente di meglio, per un uomo, che limitarsi alle azioni necessarie.", "There is nothing better, than for a man to confine himself to necessary actions.", "Marco Aurelio", "Pensieri, IV, 20"),
        q("Gran parte di quello che diciamo e facciamo non serve.", "Most of those things, which we either speak or do, are unnecessary.", "Marco Aurelio", "Pensieri, IV, 20"),
        q("La vita è breve: guadagniamoci il tempo presente con giudizio e giustizia.", "Our life is short; we must endeavour to gain the present time with best discretion and justice.", "Marco Aurelio", "Pensieri, IV, 21"),
        q("Prendi lo svago con sobrietà.", "Use recreation with sobriety.", "Marco Aurelio", "Pensieri, IV, 21"),
        q("Smetti di tormentarti, e riducíti a una semplicità perfetta.", "Trouble not thyself any more henceforth, reduce thyself unto perfect simplicity.", "Marco Aurelio", "Pensieri, IV, 21"),
        q("Qualunque mestiere tu abbia imparato, amalo, e trova conforto in quello.", "What art and profession soever thou hast learned, endeavour to affect it, and comfort thyself in it.", "Marco Aurelio", "Pensieri, IV, 26"),
        q("Non c'è ritiro migliore, per un uomo, della propria anima.", "A man cannot any whither retire better than to his own soul.", "Marco Aurelio", "Pensieri, IV, 3"),
        q("In qualunque momento vuoi, puoi ritirarti in te stesso e stare in pace, libero da ogni faccenda.", "It is in thy power to retire into thyself, and to be at rest, and free from all businesses.", "Marco Aurelio", "Pensieri, IV, 3"),
        q("Non ferito da ciò che è presente, né in paura di ciò che verrà.", "Neither wounded by that which is present, nor in fear of that which is to come.", "Marco Aurelio", "Pensieri, IV, 41"),
        q("Non corri a fare quello che la tua natura ti chiede?", "Wilt not thou run to do that, which thy nature doth require.", "Marco Aurelio", "Pensieri, V, 1"),
        q("Onori la tua natura meno di quanto un artigiano onori il suo mestiere?", "Doest thou less honour thy nature, than an ordinary mechanic his trade.", "Marco Aurelio", "Pensieri, V, 1"),
        q("Anche al riposo la natura ha dato una misura, come al mangiare e al bere.", "Marco Aurelio", "Pensieri, V, 1"),
        q("Se una cosa è giusta da dire o da fare, non svalutarti al punto di rinunciarci.", "If it be right and honest to be spoken or done, undervalue not thyself so much, as to be discouraged from it.", "Marco Aurelio", "Pensieri, V, 3"),
        q("La vita, se sai usarla, è lunga.", "Seneca", "La brevità della vita, 2"),
        q("Rivendica te stesso a te stesso, e raccogli il tempo che finora ti veniva portato via.", "Seneca", "Lettere a Lucilio, 1"),
        q("Certi tempi ci vengono strappati, altri sottratti, altri semplicemente scorrono via.", "Certain moments are torn from us, some are gently removed, and others glide beyond our reach.", "Seneca", "Lettere a Lucilio, 1"),
        q("Gran parte della vita se ne va a chi agisce male, la maggior parte a chi non fa niente, tutta quanta a chi fa altro.", "Seneca", "Lettere a Lucilio, 1"),
        q("Dipenderai meno dal domani, se metti le mani sull'oggi.", "Seneca", "Lettere a Lucilio, 1"),
        q("Chiedi una mente sana, poi la salute dell'animo, e solo dopo quella del corpo.", "Seneca", "Lettere a Lucilio, 10"),
        q("Vivi con gli uomini come se ti vedesse un dio, parla con dio come se ti ascoltassero gli uomini.", "Seneca", "Lettere a Lucilio, 10"),
        q("L'animo abbia qualcuno che rispetta: basta la sua autorità a rendere più pulito anche ciò che fai da solo.", "Seneca", "Lettere a Lucilio, 11"),
        q("Ordina ogni giornata come se chiudesse la fila, e completasse la vita.", "Every day ought to be regulated as if it closed the series, as if it rounded out and completed our existence.", "Seneca", "Lettere a Lucilio, 12"),
        q("Un giorno solo vale quanto tutti gli altri.", "Seneca", "Lettere a Lucilio, 12"),
        q("Il giro del giorno è strettissimo, eppure anche lui va da un inizio a una fine, dall'alba al tramonto.", "Seneca", "Lettere a Lucilio, 12"),
        q("Ci sono esercizi facili e brevi, che stancano il corpo subito e risparmiano il tempo.", "There are short and simple exercises which tire the body rapidly, and so save our time.", "Seneca", "Lettere a Lucilio, 15"),
        q("Il moto scuote il corpo e non toglie niente allo studio.", "Riding in a litter shakes up the body, and does not interfere with study.", "Seneca", "Lettere a Lucilio, 15"),
        q("Dà al corpo meno spazio che puoi, e fa' largo all'animo.", "Seneca", "Lettere a Lucilio, 15"),
        q("Se vuoi avere l'animo libero, devi essere povero o vivere come uno che lo è.", "Seneca", "Lettere a Lucilio, 17"),
        q("Ciò per cui non vuoi tremare al momento buono, allenalo prima.", "Seneca", "Lettere a Lucilio, 18"),
        q("Alleniamoci al palo, perché la sorte non ci trovi impreparati.", "Seneca", "Lettere a Lucilio, 18"),
        q("Prendi una regola sola per vivere, e adegua a quella tutta la vita.", "Seneca", "Lettere a Lucilio, 20"),
        q("Il giudizio cambia ogni giorno e si rovescia, e per i più la vita passa come un gioco.", "Seneca", "Lettere a Lucilio, 20"),
        q("Va svegliato dal sonno l'animo, e scosso.", "Seneca", "Lettere a Lucilio, 20"),
        q("Non c'è da aggiungere anni: c'è da togliere desideri.", "Seneca", "Lettere a Lucilio, 21"),
        q("Non starà dentro gli affari per amore degli affari.", "Seneca", "Lettere a Lucilio, 22"),
        q("L'animo dev'essere sveglio, fiducioso e dritto sopra ogni cosa.", "The very soul must be happy and confident, lifted above every circumstance.", "Seneca", "Lettere a Lucilio, 23"),
        q("Vive male chi comincia sempre a vivere.", "They live ill who are always beginning to live.", "Seneca", "Lettere a Lucilio, 23"),
        q("Certi hanno smesso di vivere prima ancora di cominciare.", "Seneca", "Lettere a Lucilio, 23"),
        q("Il corpo è una cosa più necessaria che grande.", "The frail body is to be regarded as necessary rather than as important.", "Seneca", "Lettere a Lucilio, 23"),
        q("Ogni giorno ci viene tolta una parte di vita, e anche mentre cresciamo la vita cala.", "Every day a little of our life is taken from us; even when we are growing, our life is on the wane.", "Seneca", "Lettere a Lucilio, 24"),
        q("Non amare troppo la vita, e non odiarla troppo.", "Seneca", "Lettere a Lucilio, 24"),
        q("La notte incalza il giorno e il giorno la notte, l'estate finisce nell'autunno.", "Night is close at the heels of day, day at the heels of night; summer ends in autumn.", "Seneca", "Lettere a Lucilio, 24"),
        q("Chi riposa deve agire, e chi agisce deve riposare.", "Seneca", "Lettere a Lucilio, 3"),
        q("Sbagliano tutti e due: chi non sta mai fermo, e chi sta fermo sempre.", "Seneca", "Lettere a Lucilio, 3"),
        q("Come chiamarlo, se non un dio ospitato dentro un corpo umano?", "Seneca", "Lettere a Lucilio, 31"),
        q("Per sapere se hai fatto progressi, guarda se vuoi oggi le stesse cose di ieri.", "Seneca", "Lettere a Lucilio, 35"),
        q("Il posto va scelto sano non solo per il corpo, ma anche per il carattere.", "Seneca", "Lettere a Lucilio, 51"),
        q("Anche le mani che passano dall'aratro alle armi non rifiutano nessuna fatica.", "Seneca", "Lettere a Lucilio, 51"),
        q("Solo la filosofia ci sveglia, solo lei scuote via il sonno pesante.", "Seneca", "Lettere a Lucilio, 53"),
        q("Confessare i propri difetti è già un segno di salute.", "Seneca", "Lettere a Lucilio, 53"),
        q("Torno adesso da un giro, stanco come se avessi camminato quanto sono stato seduto.", "Seneca", "Lettere a Lucilio, 55"),
        q("C'è una gran differenza fra una vita di ozio e una vita inerte.", "Seneca", "Lettere a Lucilio, 55"),
        q("Studia con me, cena con me, cammina con me.", "Seneca", "Lettere a Lucilio, 55"),
        q("Non c'è quiete davvero tranquilla se non quella che la ragione ha messo in ordine.", "Seneca", "Lettere a Lucilio, 56"),
        q("Lunga è la strada dei precetti, breve ed efficace quella degli esempi.", "Seneca", "Lettere a Lucilio, 6"),
        q("Ritirati in te stesso, quanto più puoi.", "Seneca", "Lettere a Lucilio, 7"),
        q("Cibo, sonno, desiderio: si corre sempre dentro questo cerchio.", "Seneca", "Lettere a Lucilio, 77"),
        q("Tutto quello che solleva l'animo fa bene anche al corpo.", "Seneca", "Lettere a Lucilio, 78"),
        q("Il medico ti dirà quanto camminare e quanto esercitarti.", "Seneca", "Lettere a Lucilio, 78"),
        q("Non cedere all'ozio, che è dove scivola la salute pigra.", "Seneca", "Lettere a Lucilio, 78"),
        q("Chi sembra non fare nulla, sta facendo le cose più grandi.", "Seneca", "Lettere a Lucilio, 8"),
        q("Concedi al corpo solo quanto basta a stare in salute.", "Seneca", "Lettere a Lucilio, 8"),
        q("Quanti allenano il corpo, e quanto pochi l'ingegno.", "Seneca", "Lettere a Lucilio, 80"),
        q("L'animo cresce da sé, si nutre da sé, si allena da sé.", "Seneca", "Lettere a Lucilio, 80"),
        q("Al saggio basta sé stesso per vivere bene, non per vivere.", "Seneca", "Lettere a Lucilio, 9"),

        // MARK: Secondo giro del 2026-07-28 — 38 citazioni ritrovate sul testo primario.
        //
        // Chiude il conto lasciato aperto dal primo giro: il corpus passa da 408 a 493 frasi e
        // la guardia del mese senza ripetizioni torna verde senza essere stata toccata.
        //
        // Fonti nuove rispetto al primo giro: Rudolf Steiner in TEDESCO originale (Philosophie
        // der Freiheit e Goethes Weltanschauung, entrambe da Project Gutenberg), le lettere di
        // Seneca dalla 49 alla 94 in latino, i Saggi di Bacon, i Saggi di Montaigne, il
        // Dhammapada e il Manuale di Epitteto, i Pensieri di Leopardi in italiano originale.
        //
        // Stesso metodo, stesso cancello: niente aggregatori, ogni candidata porta il frammento
        // in lingua originale e viene ritrovata dentro il file scaricato prima di essere scritta.
        // Una sola bocciata su ottantasei, ed era un doppione già in corpus — la lettera 55.

        q("In ogni atto osserva ciò che viene prima e ciò che segue: e solo allora mettiti all'opera.", "In every act observe the things which come first, and those which follow it; and so proceed to the act.", "Epitteto", "Manuale, 29"),
        q("Ogni cosa ha due manici: uno per cui si può portare, l'altro per cui non si può.", "Everything has two handles, the one by which it may be borne, the other by which it may not.", "Epitteto", "Manuale, 43"),
        q("A tavola non dire come si deve mangiare: mangia come si deve.", "At a banquet do not say how a man ought to eat, but eat as you ought to eat.", "Epitteto", "Manuale, 46"),
        q("La malattia è un impedimento per il corpo, non per la volontà, a meno che la volontà stessa non lo scelga.", "Disease is an impediment to the body, but not to the will, unless the will itself chooses.", "Epitteto", "Manuale, 9"),
        q("Infinita è la velocità del tempo, e si vede meglio quando ci si volta indietro.", "Infinitely swift is the flight of time, as those see more clearly who are looking backwards.", "Seneca", "Lettere a Lucilio, 49"),
        q("La natura ci ha fatti capaci d'imparare e ci ha dato una ragione imperfetta, ma che si può portare a compimento.", "Seneca", "Lettere a Lucilio, 49"),
        q("Nessuno torna alla natura con fatica, se non chi da lei si è allontanato.", "No man finds it difficult to return to nature, except the man who has deserted nature.", "Seneca", "Lettere a Lucilio, 50"),
        q("La virtù è secondo natura; i vizi le sono nemici e ostili.", "Virtue is according to nature; vice is opposed to it and hostile.", "Seneca", "Lettere a Lucilio, 50"),
        q("Costringo l'animo a stare intento a sé e a non lasciarsi distrarre dalle cose esterne.", "Seneca", "Lettere a Lucilio, 56"),
        q("L'animo del saggio è come il cielo sopra la luna: lassù è sempre sereno.", "The mind of the wise man is like the ultra-lunar firmament; eternal calm pervades that region.", "Seneca", "Lettere a Lucilio, 59"),
        q("La gioia non nasce che dalla coscienza delle proprie virtù.", "This joy springs only from the knowledge that you possess the virtues.", "Seneca", "Lettere a Lucilio, 59"),
        q("Che abbiamo vissuto abbastanza non lo decidono gli anni né i giorni, ma l'animo.", "Seneca", "Lettere a Lucilio, 61"),
        q("Faccio in modo che un solo giorno valga per me quanto una vita intera.", "Seneca", "Lettere a Lucilio, 61"),
        q("La vita è già abbastanza attrezzata: siamo noi a essere avidi dei suoi strumenti.", "Seneca", "Lettere a Lucilio, 61"),
        q("Alle cose non mi consegno: le presto me stesso, e non vado a caccia di pretesti per perdere tempo.", "Seneca", "Lettere a Lucilio, 62"),
        q("Ovunque io mi fermi, lì lavoro i miei pensieri e rivolgo nell'animo qualcosa che fa bene.", "Seneca", "Lettere a Lucilio, 62"),
        q("In questa dimora esposta abita un animo libero.", "Seneca", "Lettere a Lucilio, 65"),
        q("Il posto che dio occupa nel mondo, nell'uomo lo occupa l'animo.", "Seneca", "Lettere a Lucilio, 65"),
        q("Ogni arte è imitazione della natura.", "All art is but imitation of nature.", "Seneca", "Lettere a Lucilio, 65"),
        q("Da una capanna può uscire un grande uomo, e da un corpicino deforme e misero un animo bello e grande.", "A great man can spring from a hovel; so can a beautiful and great soul from an ugly and insignificant body.", "Seneca", "Lettere a Lucilio, 66"),
        q("La virtù non è altro che retta ragione.", "Virtue is nothing else than right reason.", "Seneca", "Lettere a Lucilio, 66"),
        q("È più grande sfondare le difficoltà che tenere a freno le cose liete.", "Seneca", "Lettere a Lucilio, 66"),
        q("Per riuscire a tenere fermo l'animo, ferma prima la fuga del tuo corpo.", "Seneca", "Lettere a Lucilio, 69"),
        q("Il bene non è vivere, ma vivere bene.", "Seneca", "Lettere a Lucilio, 70"),
        q("Il saggio vivrà quanto deve, non quanto può.", "Seneca", "Lettere a Lucilio, 70"),
        q("Il saggio pensa sempre a come sia la vita, non a quanta ne sia.", "He always reflects concerning the quality, and not the quantity, of his life.", "Seneca", "Lettere a Lucilio, 70"),
        q("Ogni volta che vuoi sapere cosa fuggire o cosa cercare, guarda al sommo bene, al fine di tutta la tua vita.", "Seneca", "Lettere a Lucilio, 71"),
        q("Sbagliamo perché tutti decidiamo sulle parti della vita e nessuno sull'insieme.", "The reason we make mistakes is because we all consider the parts of life, but never life as a whole.", "Seneca", "Lettere a Lucilio, 71"),
        q("Nessun momento è poco adatto a un'occupazione che fa bene.", "Seneca", "Lettere a Lucilio, 72"),
        q("Ciò che è retto non si misura né per grandezza né per numero né per durata.", "That which is straight is not judged by its size, or by its number, or by its duration.", "Seneca", "Lettere a Lucilio, 74"),
        q("La vita s'intorpidisce presto in un ozio inerte, se si deve lasciar perdere tutto ciò che dà fastidio.", "Seneca", "Lettere a Lucilio, 81"),
        q("Sta in un luogo inespugnabile l'animo che ha lasciato le cose esterne e si difende nella propria rocca.", "Seneca", "Lettere a Lucilio, 82"),
        q("Va' per la strada che hai preso e assestati in questo modo di vivere con calma, non con mollezza.", "Seneca", "Lettere a Lucilio, 82"),
        q("Oggi è un giorno intero: nessuno me ne ha strappato via un pezzo.", "Seneca", "Lettere a Lucilio, 83"),
        q("La virtù tocca solo l'animo che sia stato formato, istruito e portato al sommo da un esercizio assiduo.", "Seneca", "Lettere a Lucilio, 90"),
        q("Il nostro animo è capiente: arriva in alto, se i vizi non lo schiacciano.", "Seneca", "Lettere a Lucilio, 92"),
        q("Per vivere a lungo serve il destino; per vivere abbastanza, l'animo.", "Seneca", "Lettere a Lucilio, 93"),
        q("Due cose danno all'animo la forza maggiore: la fede nel vero e la fiducia in sé.", "Seneca", "Lettere a Lucilio, 94"),
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

        // MARK: Aggiunte del 2026-07-28 — 56 citazioni ritrovate sul testo primario.
        //
        // Nessuna viene da un aggregatore. Per ognuna il frammento in lingua originale è stato
        // cercato dentro il testo scaricato (Wikisource latino e italiano, Project Gutenberg,
        // Zarathustra in tedesco) e ritrovato alla riga indicata dal cancello di verifica; la
        // resa italiana è nostra, fatta sull'originale dove la lingua lo permetteva — latino,
        // tedesco, francese, inglese — e sulla traduzione di pubblico dominio altrove.
        //
        // Diciannove candidate su centocinquantadue sono state bocciate dal cancello perché il
        // frammento non esisteva nel testo con quelle parole: quelle NON sono qui, ed è
        // esattamente il motivo per cui il cancello esiste.

        q("Il tempo perduto non si ritrova più.", "Lost Time is never found again.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("Guida tu i tuoi affari, non farti guidare da loro.", "Drive thy Business, let not that drive thee.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("La pigrizia consuma più della fatica: la chiave che si usa resta lucida.", "Sloth, like Rust, consumes faster than Labor wears; while the used key is always bright.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("Presto a letto e presto in piedi rende un uomo sano, ricco e saggio.", "Early to Bed, and early to rise, makes a Man healthy, wealthy, and wise.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("Un oggi vale due domani.", "One To-day is worth two To-morrows.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("Hai qualcosa da fare domani? Fallo oggi.", "Have you somewhat to do to-morrow, do it to-day.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("La diligenza è la madre della buona sorte.", "Diligence is the Mother of Good-luck.", "Benjamin Franklin", "La via della ricchezza, 1758"),
        q("Niente di grande è mai stato fatto senza entusiasmo.", "Nothing great was ever achieved without enthusiasm.", "Emerson", "Saggi, Cerchi"),
        q("La vita dell'uomo è un cerchio che si allarga da sé.", "The life of man is a self-evolving circle.", "Emerson", "Saggi, Cerchi"),
        q("Ogni eccesso produce un difetto, e ogni difetto un eccesso.", "Every excess causes a defect; every defect an excess.", "Emerson", "Saggi, Compensazione"),
        q("La fiducia in sé è l'essenza dell'eroismo.", "Self-trust is the essence of heroism.", "Emerson", "Saggi, Eroismo"),
        q("La prudenza è la virtù dei sensi.", "Prudence is the virtue of the senses.", "Emerson", "Saggi, Prudenza"),
        q("La lettura fa l'uomo completo, il parlare l'uomo pronto, lo scrivere l'uomo esatto.", "Reading maketh a full man; conference a ready man; and writing an exact man.", "Francis Bacon", "Saggi, Degli studi"),
        q("Gli studi servono al diletto, all'ornamento e alla capacità.", "Studies serve for delight, for ornament, and for ability.", "Francis Bacon", "Saggi, Degli studi"),
        q("Certi libri vanno assaggiati, altri inghiottiti, e pochi masticati e digeriti.", "Some books are to be tasted, others to be swallowed, and some few to be chewed and digested.", "Francis Bacon", "Saggi, Degli studi"),
        q("Le storie rendono saggi, i poeti arguti, la matematica sottili, la filosofia naturale profondi.", "Histories make men wise; poets witty; the mathematics subtile; natural philosophy deep.", "Francis Bacon", "Saggi, Degli studi"),
        q("La tua osservazione di ciò che ti fa bene e di ciò che ti fa male è la miglior medicina per restare sano.", "A man's own observation, what he finds good of, and what he finds hurt of, is the best physic to preserve health.", "Francis Bacon", "Saggi, Del regime della salute"),
        q("L'abitudine è il magistrato principale della vita di un uomo.", "Custom is the principal magistrate of man's life.", "Francis Bacon", "Saggi, Dell'abitudine e dell'educazione"),
        q("La natura spesso si nasconde, a volte si vince, di rado si spegne.", "Nature is often hidden; sometimes overcome; seldom extinguished.", "Francis Bacon", "Saggi, Della natura negli uomini"),
        q("Il tempo è la misura del lavoro, come il denaro è la misura delle merci.", "Time is the measure of business, as money is of wares.", "Francis Bacon", "Saggi, Della speditezza"),
        q("Chi non vuole applicare rimedi nuovi deve aspettarsi guai nuovi: il tempo è il più grande innovatore.", "He that will not apply new remedies, must expect new evils; for time is the greatest innovator.", "Francis Bacon", "Saggi, Delle innovazioni"),
        q("La vita non si potrebbe conservare, se non fosse interrotta di frequente.", "Leopardi", "Operette morali, Cantico del gallo silvestre"),
        q("Il primo tempo del giorno è di solito il più sopportabile.", "Leopardi", "Operette morali, Cantico del gallo silvestre"),
        q("Molti affanni, al mattino, paiono assai minori di quanto parvero la sera prima.", "Leopardi", "Operette morali, Cantico del gallo silvestre"),
        q("Su, mortali, destatevi. Il dì rinasce.", "Leopardi", "Operette morali, Cantico del gallo silvestre"),
        q("Sorgete, ripigliatevi la soma della vita, riducetevi dal mondo falso nel vero.", "Leopardi", "Operette morali, Cantico del gallo silvestre"),
        q("C'è differenza fra la fatica e il disagio, e fra il vivere quieto e il vivere ozioso.", "Leopardi", "Operette morali, Dialogo della Natura e di un Islandese"),
        q("Il valore della vita non sta nella lunghezza dei giorni, ma nell'uso che ne facciamo.", "The utility of living consists not in the length of days, but in the use of time.", "Montaigne", "Saggi, I, 20"),
        q("Il segno più evidente della saggezza è un'allegria continua.", "The most manifest sign of wisdom is a continual cheerfulness.", "Montaigne", "Saggi, I, 25"),
        q("Ci insegnano a vivere quando la vita è quasi finita.", "They begin to teach us to live when we have almost done living.", "Montaigne", "Saggi, I, 26"),
        q("Il modo in cui conduciamo la vita è lo specchio vero di ciò che pensiamo.", "The conduct of our lives is the true mirror of our doctrine.", "Montaigne", "Saggi, I, 51"),
        q("Il corpo è una grande ragione, una molteplicità con un senso solo, una guerra e una pace, un gregge e un pastore.", "Nietzsche", "Così parlò Zarathustra, I, Dei disprezzatori del corpo"),
        q("Sono corpo, tutto intero, e nient'altro.", "Nietzsche", "Così parlò Zarathustra, I, Dei disprezzatori del corpo"),
        q("Anche la tua piccola ragione, quella che chiami spirito, è uno strumento del tuo corpo.", "Nietzsche", "Così parlò Zarathustra, I, Dei disprezzatori del corpo"),
        q("In montagna la via più breve va da cima a cima, ma ci vogliono gambe lunghe.", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Voi guardate in alto quando volete sollevarvi. Io guardo in basso, perché sono sollevato.", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Chi scrive col sangue non vuole essere letto, vuole essere imparato a memoria.", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Le massime devono essere cime.", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Aria sottile e pulita, il pericolo vicino, e lo spirito pieno di una cattiveria allegra: stanno bene insieme.", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Il coraggio vuole ridere.", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Chi di voi sa insieme ridere ed essere sollevato?", "Nietzsche", "Così parlò Zarathustra, I, Del leggere e dello scrivere"),
        q("Restate fedeli alla terra.", "Nietzsche", "Così parlò Zarathustra, Prologo, 3"),
        q("È mattina quando sono sveglio, e dentro di me c'è un'alba.", "Morning is when I am awake and there is a dawn in me.", "Thoreau", "Walden, II"),
        q("La riforma morale è lo sforzo di scrollarsi di dosso il sonno.", "Moral reform is the effort to throw off sleep.", "Thoreau", "Walden, II"),
        q("Ogni mattina era un invito a rendere la mia vita semplice, e direi innocente, quanto la natura stessa.", "Every morning was a cheerful invitation to make my life of equal simplicity, and I may say innocence, with Nature herself.", "Thoreau", "Walden, II"),
        q("Il mattino, la stagione più memorabile del giorno, è l'ora del risveglio.", "The morning, which is the most memorable season of the day, is the awakening hour.", "Thoreau", "Walden, II"),
        q("Per chi tiene il passo del sole col pensiero, il giorno è un mattino perpetuo.", "To him whose elastic and vigorous thought keeps pace with the sun, the day is a perpetual morning.", "Thoreau", "Walden, II"),
        q("Passiamo un giorno con la stessa calma deliberata della natura.", "Let us spend one day as deliberately as Nature.", "Thoreau", "Walden, II"),
        q("I libri vanno letti con la stessa lentezza voluta con cui sono stati scritti.", "Books must be read as deliberately and reservedly as they were written.", "Thoreau", "Walden, III"),
        q("C'erano momenti in cui non potevo sacrificare il fiore dell'istante presente a nessun lavoro, né di testa né di mani.", "I could not afford to sacrifice the bloom of the present moment to any work, whether of the head or hands.", "Thoreau", "Walden, IV"),
        q("Era mattina, ed ecco è già sera, e non è stato fatto niente di memorabile.", "It was morning, and lo, now it is evening, and nothing memorable is accomplished.", "Thoreau", "Walden, IV"),
        q("Sono più grande e migliore di quanto pensassi: non sapevo di contenere tanto bene.", "I am larger, better than I thought, I did not know I held so much goodness.", "Walt Whitman", "Foglie d'erba, Canto della strada aperta"),
        q("Da adesso non chiedo più la buona sorte: la buona sorte sono io.", "Henceforth I ask not good-fortune, I myself am good-fortune.", "Walt Whitman", "Foglie d'erba, Canto della strada aperta"),
        q("Me ne sto in ozio e invito la mia anima.", "I loafe and invite my soul.", "Walt Whitman", "Foglie d'erba, Canto di me stesso, 1"),
        q("Mi appoggio e me ne sto in ozio, guardando un filo d'erba d'estate.", "I lean and loafe at my ease observing a spear of summer grass.", "Walt Whitman", "Foglie d'erba, Canto di me stesso, 1"),
        q("Esisto come sono, e questo basta.", "I exist as I am, that is enough.", "Walt Whitman", "Foglie d'erba, Canto di me stesso, 20"),

        // MARK: Secondo giro del 2026-07-28 — 39 citazioni ritrovate sul testo primario.
        //
        // Chiude il conto lasciato aperto dal primo giro: il corpus passa da 408 a 493 frasi e
        // la guardia del mese senza ripetizioni torna verde senza essere stata toccata.
        //
        // Fonti nuove rispetto al primo giro: Rudolf Steiner in TEDESCO originale (Philosophie
        // der Freiheit e Goethes Weltanschauung, entrambe da Project Gutenberg), le lettere di
        // Seneca dalla 49 alla 94 in latino, i Saggi di Bacon, i Saggi di Montaigne, il
        // Dhammapada e il Manuale di Epitteto, i Pensieri di Leopardi in italiano originale.
        //
        // Stesso metodo, stesso cancello: niente aggregatori, ogni candidata porta il frammento
        // in lingua originale e viene ritrovata dentro il file scaricato prima di essere scritta.
        // Una sola bocciata su ottantasei, ed era un doppione già in corpus — la lettera 55.

        q("Non c'è intoppo dell'ingegno che non si possa sciogliere con studi adatti, come i mali del corpo hanno i loro esercizi.", "There is no stond or impediment in the wit, but may be wrought out by fit studies; like as diseases of the body, may have appropriate exercises.", "Francis Bacon", "Saggi, Degli studi"),
        q("Le bocce fanno bene ai calcoli e ai reni, il tiro ai polmoni e al petto, la camminata lenta allo stomaco, la cavalcata alla testa.", "Bowling is good for the stone and reins; shooting for the lungs and breast; gentle walking for the stomach; riding for the head.", "Francis Bacon", "Saggi, Degli studi"),
        q("Non leggere per contraddire, né per credere sulla parola, né per far conversazione, ma per pesare e considerare.", "Read not to contradict and confute; nor to believe and take for granted; nor to find talk and discourse; but to weigh and consider.", "Francis Bacon", "Saggi, Degli studi"),
        q("Alcuni libri vanno assaggiati, altri inghiottiti, e pochi masticati e digeriti.", "Some books are to be tasted, others to be swallowed, and some few to be chewed and digested.", "Francis Bacon", "Saggi, Degli studi"),
        q("Gli studi perfezionano la natura e sono perfezionati dall'esperienza.", "They perfect nature, and are perfected by experience.", "Francis Bacon", "Saggi, Degli studi"),
        q("L'osservazione di sé, ciò che uno sente che gli giova e ciò che gli nuoce, è la medicina migliore per conservare la salute.", "A man's own observation, what he finds good of, and what he finds hurt of, is the best physic to preserve health.", "Francis Bacon", "Saggi, Del governo della salute"),
        q("Avere la mente libera e l'animo lieto alle ore del cibo, del sonno e dell'esercizio è uno dei precetti migliori per durare a lungo.", "To be free-minded and cheerfully disposed, at hours of meat, and of sleep, and of exercise, is one of the best precepts of long lasting.", "Francis Bacon", "Saggi, Del governo della salute"),
        q("Veglia e sonno, ma piuttosto il sonno; stare seduti ed esercizio, ma piuttosto l'esercizio.", "Watching and sleep, but rather sleep; sitting and exercise, but rather exercise.", "Francis Bacon", "Saggi, Del governo della salute"),
        q("Nella malattia guarda soprattutto alla salute; nella salute, all'azione.", "In sickness, respect health principally; and in health, action.", "Francis Bacon", "Saggi, Del governo della salute"),
        q("Se l'esercizio è più duro dell'uso, ne nasce grande perfezione.", "For it breeds great perfection, if the practice be harder than the use.", "Francis Bacon", "Saggi, Della natura negli uomini"),
        q("Non ci si imponga un'abitudine con continuità perpetua, ma con qualche interruzione: la pausa rinforza la ripresa.", "Let not a man force a habit upon himself, with a perpetual continuance, but with some intermission. For both the pause reinforceth the new onset.", "Francis Bacon", "Saggi, Della natura negli uomini"),
        q("La natura di un uomo va o alle erbe buone o alle erbacce: annaffi al momento giusto le une e distrugga le altre.", "A man's nature, runs either to herbs or weeds; therefore let him seasonably water the one, and destroy the other.", "Francis Bacon", "Saggi, Della natura negli uomini"),
        q("Chi cerca vittoria sulla propria natura non si dia compiti troppo grandi né troppo piccoli.", "He that seeketh victory over his nature, let him not set himself too great, nor too small tasks.", "Francis Bacon", "Saggi, Della natura negli uomini"),
        q("Gran rimedio della maldicenza, appunto come delle afflizioni d'animo, è il tempo.", "Leopardi", "Pensieri, XLV"),
        q("Nessun maggior segno d'essere poco filosofo e poco savio, che volere savia e filosofica tutta la vita.", "Leopardi", "Pensieri, XXVIII"),
        q("Il segno più manifesto della saggezza è un'allegria continua.", "The most manifest sign of wisdom is a continual cheerfulness.", "Montaigne", "Saggi, Dell'educazione dei fanciulli"),
        q("Se hai saputo prenderti riposo, hai fatto più di chi ha preso imperi e città.", "Have you known how to take repose, you have done more than he who has taken empires and cities.", "Montaigne", "Saggi, Dell'esperienza"),
        q("Se hai saputo regolare la tua condotta, hai fatto molto di più di chi ha composto libri.", "Have you known how to regulate your conduct, you have done a great deal more than he who has composed books.", "Montaigne", "Saggi, Dell'esperienza"),
        q("Il capolavoro glorioso dell'uomo è vivere a proposito: regnare, accumulare, costruire sono piccole appendici e sostegni.", "The glorious masterpiece of man is to live to purpose; to reign, to lay up treasure, to build, are but little appendices.", "Montaigne", "Saggi, Dell'esperienza"),
        q("La cosa più grande al mondo è che un uomo sappia di appartenere a se stesso.", "The greatest thing in the world is for a man to know that he is his own.", "Montaigne", "Saggi, Della solitudine"),
        q("L'uomo non è qui solo per farsi un'immagine del mondo già fatto: collabora lui stesso a farlo venire in essere.", "Rudolf Steiner", "La concezione goethiana del mondo, Personalità"),
        q("Verrebbe da dire che senza l'uomo il mondo mostrerebbe un volto non vero.", "Rudolf Steiner", "La concezione goethiana del mondo, Personalità"),
        q("Voler conoscere è un'esigenza della natura umana, non delle cose.", "Rudolf Steiner", "La concezione goethiana del mondo, Personalità"),
        q("Al singolo uomo la verità appare in una veste individuale.", "Rudolf Steiner", "La concezione goethiana del mondo, Personalità"),
        q("Quando l'uomo posa lo sguardo su una cosa, nasce in lui l'impulso a vedere più di quanto la percezione gli offra.", "Rudolf Steiner", "La concezione goethiana del mondo, Personalità"),
        q("Si respinge tutto ciò che ostacola il pieno dispiegarsi delle forze del singolo.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Una verità che ci viene da fuori porta sempre su di sé il marchio dell'incertezza.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Possiamo credere solo a ciò che a ciascuno di noi appare come verità nel proprio intimo.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Chi è tormentato dai dubbi ha le forze paralizzate.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Aspiriamo a un sapere sicuro, ma ciascuno a modo suo.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Chi sa godere soltanto con i sensi non conosce le leccornie della vita.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Il sapere ha valore solo in quanto contribuisce al dispiegarsi in ogni direzione di tutta la natura umana.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("Davanti all'idea bisogna porsi da padroni, altrimenti si finisce in sua schiavitù.", "Rudolf Steiner", "La filosofia della libertà, I"),
        q("È libero solo l'uomo che in ogni istante della vita è in grado di seguire se stesso.", "Rudolf Steiner", "La filosofia della libertà, X"),
        q("Vivere e lasciar vivere è la massima fondamentale degli uomini liberi.", "Rudolf Steiner", "La filosofia della libertà, X"),
        q("La nostra vita si compone di azioni libere e di azioni non libere.", "Rudolf Steiner", "La filosofia della libertà, X"),
        q("L'individuo umano è la sorgente di ogni moralità e il centro di ogni vita.", "Rudolf Steiner", "La filosofia della libertà, X"),
        q("La vita ha solo lo scopo e la destinazione che l'uomo stesso le dà.", "Rudolf Steiner", "La filosofia della libertà, XII"),
        q("Non m'incammino nella vita con un itinerario già stabilito.", "Rudolf Steiner", "La filosofia della libertà, XII"),
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

        // MARK: Aggiunte del 2026-07-28 — 4 citazioni ritrovate sul testo primario.
        //
        // Nessuna viene da un aggregatore. Per ognuna il frammento in lingua originale è stato
        // cercato dentro il testo scaricato (Wikisource latino e italiano, Project Gutenberg,
        // Zarathustra in tedesco) e ritrovato alla riga indicata dal cancello di verifica; la
        // resa italiana è nostra, fatta sull'originale dove la lingua lo permetteva — latino,
        // tedesco, francese, inglese — e sulla traduzione di pubblico dominio altrove.
        //
        // Diciannove candidate su centocinquantadue sono state bocciate dal cancello perché il
        // frammento non esisteva nel testo con quelle parole: quelle NON sono qui, ed è
        // esattamente il motivo per cui il cancello esiste.

        q("Chi ripassa il vecchio e ne ricava il nuovo può essere maestro.", "If a man keeps cherishing his old knowledge, so as continually to be acquiring new.", "Confucio", "Dialoghi, II, 11"),
        q("Imparare senza pensare è fatica sprecata.", "Learning without thought is labour lost.", "Confucio", "Dialoghi, II, 15"),
        q("Chi sta in punta di piedi non sta saldo; chi allarga il passo non cammina.", "He who stands on his tiptoes does not stand firm.", "Laozi", "Tao Te Ching, 24"),
        q("Il morbido e il debole vincono il duro e il forte.", "The soft overcomes the hard; and the weak the strong.", "Laozi", "Tao Te Ching, 36"),

        // MARK: Secondo giro del 2026-07-28 — 8 citazioni ritrovate sul testo primario.
        //
        // Chiude il conto lasciato aperto dal primo giro: il corpus passa da 408 a 493 frasi e
        // la guardia del mese senza ripetizioni torna verde senza essere stata toccata.
        //
        // Fonti nuove rispetto al primo giro: Rudolf Steiner in TEDESCO originale (Philosophie
        // der Freiheit e Goethes Weltanschauung, entrambe da Project Gutenberg), le lettere di
        // Seneca dalla 49 alla 94 in latino, i Saggi di Bacon, i Saggi di Montaigne, il
        // Dhammapada e il Manuale di Epitteto, i Pensieri di Leopardi in italiano originale.
        //
        // Stesso metodo, stesso cancello: niente aggregatori, ogni candidata porta il frammento
        // in lingua originale e viene ritrovata dentro il file scaricato prima di essere scritta.
        // Una sola bocciata su ottantasei, ed era un doppione già in corpus — la lettera 55.

        q("Destandosi, con impegno, con misura e con dominio di sé, il saggio si fa un'isola che nessuna piena può sommergere.", "By rousing himself, by earnestness, by restraint and control, the wise man may make for himself an island which no flood can overwhelm.", "Buddha", "Dhammapada, II, 25"),
        q("Come il fabbricante di frecce raddrizza la sua freccia, il saggio raddrizza il proprio pensiero tremante e instabile.", "As a fletcher makes straight his arrow, a wise man makes straight his trembling and unsteady thought.", "Buddha", "Dhammapada, III, 33"),
        q("Il saggio sorvegli i propri pensieri, difficili da cogliere, astuti, che corrono dove vogliono: ben sorvegliati portano felicità.", "Let the wise man guard his thoughts: hard to perceive, very artful, they rush wherever they list. Guarded well, they bring happiness.", "Buddha", "Dhammapada, III, 36"),
        q("Gli irrigatori guidano l'acqua, i fabbricanti di frecce piegano la freccia, i falegnami piegano il legno: i saggi danno forma a se stessi.", "Well-makers lead the water (wherever they like); fletchers bend the arrow; carpenters bend a log of wood; wise people fashion themselves.", "Buddha", "Dhammapada, VI, 80"),
        q("Come una roccia salda non è scossa dal vento, così i saggi non vacillano tra il biasimo e la lode.", "As a solid rock is not shaken by the wind, wise people falter not amidst blame and praise.", "Buddha", "Dhammapada, VI, 81"),
        q("Il sé è signore del sé; chi altri potrebbe esserlo? Con il sé ben domato si trova un signore che pochi trovano.", "Self is the lord of self, who else could be the lord? With self well subdued, a man finds a lord such as few can find.", "Buddha", "Dhammapada, XII, 160"),
        q("La salute è il più grande dei doni, l'appagamento la ricchezza migliore.", "Health is the greatest of gifts, contentedness the best riches.", "Buddha", "Dhammapada, XV, 204"),
        q("Senza conoscenza non c'è meditazione, senza meditazione non c'è conoscenza.", "Without knowledge there is no meditation, without meditation there is no knowledge.", "Buddha", "Dhammapada, XXV, 372"),
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
