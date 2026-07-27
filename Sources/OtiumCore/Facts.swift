import Foundation

/// Fatti brevi, uno per pausa.
///
/// **La regola che governa questo file, e che va letta prima di aggiungerci una riga.** Una fonte
/// precisa — autore, rivista, anno — si scrive **solo** quando è davvero quella. Dove il fatto è
/// consolidato ma la citazione puntuale non la conosco con certezza, l'attribuzione dice cos'è:
/// «consenso di fisiologia dell'esercizio», «linee guida OMS». Una citazione inventata bene è più
/// dannosa di nessuna citazione: è esattamente il difetto che l'app rimprovera ai concorrenti che
/// si dichiarano *science-backed* senza uno studio.
///
/// Gli studi **portanti** — quelli che giustificano i parametri della cadenza — non stanno qui:
/// stanno in `Evidence`, con link e tutto, e si aprono dal menu. Qui ci sono le briciole che
/// riempiono i secondi della pausa.
public enum Facts {

    private static func f(_ text: String, _ source: String) -> Phrase {
        Phrase(id: "f:\(text.prefix(28))", kind: .fatto, text: text, attribution: source)
    }

    // MARK: - Stare seduti

    static let sedentarieta: [Phrase] = [
        f("Cinque minuti di movimento leggero ogni mezz'ora abbassano il picco glicemico dopo il pasto di quasi il 60%.",
          "Duran et al., Med Sci Sports Exerc, 2023"),
        f("Interrompere la seduta con tre minuti di squat ogni 45 minuti batte una camminata unica da mezz'ora, sul controllo glicemico.",
          "Gao et al., Scand J Med Sci Sports, 2024"),
        f("Chi sta seduto oltre otto ore al giorno senza attività fisica ha un rischio di mortalità paragonabile a quello del fumo e dell'obesità.",
          "Ekelund et al., The Lancet, 2016"),
        f("Sessanta-settantacinque minuti di attività moderata al giorno annullano l'eccesso di rischio dovuto a molte ore da seduti.",
          "Ekelund et al., The Lancet, 2016"),
        f("Interrompere spesso il tempo seduto si associa a girovita e trigliceridi migliori, a parità di ore totali sedute.",
          "Healy et al., Diabetes Care, 2008"),
        f("Non è quanto stai seduto in totale: è quanto a lungo lo stai **di fila**.",
          "consenso della ricerca sul comportamento sedentario"),
        f("Restare seduti a lungo riduce l'attività della lipoproteina lipasi, l'enzima che ripulisce i grassi dal sangue.",
          "fisiologia dell'inattività, letteratura consolidata"),
        f("Un muscolo inattivo smette di catturare glucosio anche quando l'insulina c'è: è la resistenza da immobilità.",
          "consenso di fisiologia dell'esercizio"),
        f("Le pause in piedi contano poco se resti fermo: è la contrazione muscolare a fare il lavoro, non la posizione.",
          "consenso di fisiologia dell'esercizio"),
        f("La scrivania in piedi da sola non basta: cambia il carico, non l'immobilità.",
          "dichiarazione di consenso su sedentarietà e lavoro d'ufficio, Buckley et al., 2015"),
        f("Il sangue nelle gambe risale grazie alla pompa muscolare del polpaccio: senza contrazioni, ristagna.",
          "fisiologia cardiovascolare, nozione di base"),
        f("Ore di immobilità aumentano il rischio di trombosi venosa: è lo stesso meccanismo della sindrome da classe economica.",
          "medicina vascolare, consenso"),
        f("Anche due minuti di camminata ogni mezz'ora migliorano la risposta glicemica rispetto al restare seduti.",
          "letteratura sull'interruzione del tempo sedentario"),
        f("Il dispendio energetico di chi si muove spesso senza allenarsi può superare quello di chi si allena e poi sta fermo tutto il giorno.",
          "Levine, ricerca sulla termogenesi non da esercizio (NEAT)"),
        f("Piccoli movimenti frequenti — alzarsi, camminare, agitarsi — spiegano differenze di centinaia di calorie al giorno fra persone simili.",
          "Levine, ricerca sulla termogenesi non da esercizio (NEAT)"),
    ]

    // MARK: - Muoversi poco e spesso

    static let movimento: [Phrase] = [
        f("Tre sessioni quotidiane di 1-2 minuti di attività vigorosa nella vita normale si associano a circa il 40% di mortalità in meno.",
          "Stamatakis et al., Nature Medicine, 2022"),
        f("Non serve allenarsi in senso stretto per avere benefici cardiovascolari: servono momenti duri, brevi e ripetuti.",
          "Stamatakis et al., Nature Medicine, 2022"),
        f("Salire le scale è uno degli esercizi più intensi che si possano fare senza attrezzatura né spogliatoio.",
          "consenso di fisiologia dell'esercizio"),
        f("Il beneficio maggiore, in termini di rischio, si ha passando da zero movimento a poco movimento — non da molto a moltissimo.",
          "curve dose-risposta dell'attività fisica, letteratura consolidata"),
        f("Le linee guida chiedono 150 minuti a settimana di attività moderata: sono poco più di venti minuti al giorno.",
          "linee guida OMS sull'attività fisica, 2020"),
        f("Le stesse linee guida raccomandano di rinforzare i muscoli almeno due volte a settimana. Quasi nessuno lo fa.",
          "linee guida OMS sull'attività fisica, 2020"),
        f("Il muscolo scheletrico è il più grande organo di smaltimento del glucosio del corpo.",
          "fisiologia metabolica, nozione di base"),
        f("Contrarre le gambe attiva trasportatori del glucosio anche senza insulina: è una via indipendente.",
          "fisiologia dell'esercizio, meccanismo GLUT4"),
        f("La forza delle gambe negli adulti predice l'autonomia in età avanzata meglio di molti esami del sangue.",
          "geriatria, letteratura su forza e funzione"),
        f("La forza di presa della mano è uno dei predittori di mortalità più semplici e robusti che esistano.",
          "studi prospettici su forza di presa e mortalità"),
        f("La massa muscolare persa dopo i trent'anni si riprende a qualunque età con il sovraccarico: il muscolo risponde sempre.",
          "consenso su sarcopenia e allenamento di forza"),
        f("L'osso si costruisce dove viene caricato: senza carico si disfa, con carico si ispessisce.",
          "legge di Wolff, ortopedia"),
        f("Il tendine si adatta più lentamente del muscolo: per questo la progressione graduale non è prudenza, è biologia.",
          "fisiologia del tessuto connettivo"),
        f("Un allenamento breve ripetuto più volte al giorno può produrre adattamenti simili a una sessione unica equivalente.",
          "letteratura sugli exercise snacks"),
        f("Bastano pochi minuti al giorno di esercizio intenso frazionato per migliorare la capacità cardiorespiratoria in poche settimane.",
          "letteratura sugli exercise snacks"),
        f("La capacità aerobica è uno dei più forti predittori di longevità misurabili in laboratorio.",
          "epidemiologia della fitness cardiorespiratoria"),
    ]

    // MARK: - Testa, occhi, attenzione

    static let mente: [Phrase] = [
        f("Il calo di attenzione dopo un'ora sullo stesso compito sparisce se lo si interrompe brevemente con un'attività diversa.",
          "Ariga & Lleras, Cognition, 2011"),
        f("Le micro-pause sotto i dieci minuti riducono la fatica e alzano il vigore, ma dopo lavoro cognitivo intenso non bastano a recuperare la prestazione.",
          "Albulescu et al., PLOS ONE, 2022"),
        f("Le pause decise in anticipo battono quelle prese quando capita: stesso lavoro, stesso sforzo, meno tempo.",
          "Biwer et al., Br J Educ Psychol, 2023"),
        f("Cinque minuti di pausa ogni ora riducono i disturbi muscoloscheletrici senza far calare la produttività misurata.",
          "Galinsky et al., Ergonomics, 2000"),
        f("Davanti a uno schermo si sbatte le palpebre molto meno del normale: è la causa principale dell'occhio secco da computer.",
          "oftalmologia, letteratura su frequenza di ammiccamento e videoterminali"),
        f("Guardare lontano rilassa il muscolo ciliare, che tenendo il fuoco da vicino resta contratto per ore.",
          "ottica fisiologica, nozione di base"),
        f("La regola 20-20-20 è ovunque, ma un confronto diretto fra intervalli diversi non ha trovato differenze su sintomi e lettura.",
          "Johnson & Rosenfield, letteratura optometrica, 2023"),
        f("Guardare qualcosa di naturale — anche solo dalla finestra — recupera l'attenzione meglio di guardare un altro schermo.",
          "teoria del ripristino dell'attenzione, Kaplan"),
        f("La memoria di lavoro ha una capacità piccolissima: è il collo di bottiglia di quasi tutto quello che chiami «concentrazione»."
          , "psicologia cognitiva, consenso"),
        f("Cambiare compito costa un tempo di riorientamento che non si recupera: il multitasking è un cambio rapido, non un parallelismo.",
          "psicologia cognitiva, letteratura sul task switching"),
        f("Dopo un'interruzione, tornare al livello di concentrazione precedente richiede parecchi minuti.",
          "ricerca sulle interruzioni nel lavoro d'ufficio"),
        f("Il sonno consolida quello che hai imparato durante il giorno: studiare di più togliendo ore di sonno è un cattivo affare.",
          "neuroscienze del sonno, consenso"),
        f("La privazione di sonno peggiora i tempi di reazione in modo paragonabile a un tasso alcolico rilevante.",
          "medicina del sonno, studi su veglia prolungata e prestazione"),
        f("Un breve esercizio aerobico migliora l'umore in modo misurabile già dopo pochi minuti.",
          "psicologia dell'esercizio, meta-analisi su umore e attività acuta"),
        f("Che novanta secondi di squat ti rendano più lucido subito dopo non è dimostrato: Otium interrompe per ragioni metaboliche, non per promesse cognitive.",
          "revisioni sull'esercizio acuto e funzioni esecutive, esito inconcludente"),
        f("La sensazione di essere concentrati e l'esserlo davvero si scollano quando sei stanco: la prima resiste, la seconda no.",
          "psicologia della metacognizione, consenso"),
    ]

    // MARK: - Schiena, collo, respiro

    static let posturaFatti: [Phrase] = [
        f("Non esiste una postura giusta: esiste il cambio di postura. Il carico statico è il problema, non l'angolo.",
          "ergonomia occupazionale, consenso"),
        f("Il disco intervertebrale si nutre per diffusione, e la diffusione dipende dal movimento.",
          "biomeccanica del rachide, nozione di base"),
        f("La pressione sui dischi lombari da seduti è maggiore che in piedi.",
          "biomeccanica del rachide, misurazioni classiche di Nachemson"),
        f("Il dolore lombare cronico correla più con l'immobilità e la paura del movimento che con i reperti radiologici.",
          "medicina muscoloscheletrica, consenso"),
        f("Molte alterazioni viste in risonanza — protrusioni, degenerazione — sono comuni anche in chi non ha alcun dolore.",
          "studi di imaging su popolazione asintomatica"),
        f("Il collo in avanti moltiplica il carico sui muscoli cervicali: pochi centimetri pesano come chili.",
          "biomeccanica cervicale"),
        f("Respirare con il diaframma abbassa la frequenza cardiaca; respirare alto e corto la alza.",
          "fisiologia respiratoria, nozione di base"),
        f("Un'espirazione più lunga dell'inspirazione attiva la risposta parasimpatica: è il modo più rapido di calmarsi.",
          "fisiologia autonomica, consenso"),
        f("Molte persone davanti allo schermo trattengono il respiro senza accorgersene, soprattutto mentre leggono email.",
          "osservazione documentata come «apnea da schermo», letteratura divulgativa"),
        f("Il pavimento pelvico e il diaframma lavorano insieme: respirare male irrigidisce entrambi.",
          "fisioterapia, consenso"),
    ]

    // MARK: - Abitudini

    static let abitudini: [Phrase] = [
        f("Un'abitudine nuova richiede in media un paio di mesi per diventare automatica, con enormi differenze fra persone.",
          "Lally et al., Eur J Soc Psychol, 2010"),
        f("Saltare un giorno singolo non compromette la formazione di un'abitudine.",
          "Lally et al., Eur J Soc Psychol, 2010"),
        f("Legare un comportamento nuovo a un momento fisso della giornata funziona meglio della sola buona intenzione.",
          "letteratura sulle implementation intentions, Gollwitzer"),
        f("Scrivere quando e dove farai una cosa aumenta molto la probabilità che la farai davvero.",
          "letteratura sulle implementation intentions, Gollwitzer"),
        f("Rendere un comportamento più facile da iniziare conta più che aumentare la motivazione.",
          "scienze comportamentali applicate, consenso"),
        f("Gli avvisi che arrivano al momento giusto funzionano; quelli che arrivano sempre diventano rumore e si ignorano.",
          "ricerca sulle notifiche e l'affaticamento da allarme"),
        f("Un obiettivo troppo grande produce meno azione di uno ridicolmente piccolo.",
          "scienze comportamentali applicate, consenso"),
        f("Misurare un comportamento tende a cambiarlo, anche senza altri interventi.",
          "effetto della auto-osservazione, psicologia comportamentale"),
    ]

    // MARK: - Il corpo che nessuno guarda

    static let corpoSilenzioso: [Phrase] = [
        f("Il sistema linfatico non ha una pompa propria: si muove con la contrazione dei muscoli e il respiro.",
          "fisiologia, nozione di base"),
        f("Il cervello è circa il 2% del peso corporeo e consuma circa un quinto dell'energia a riposo.",
          "neurofisiologia, nozione di base"),
        f("La disidratazione lieve basta a peggiorare umore e attenzione, ben prima che venga sete.",
          "letteratura su idratazione e prestazione cognitiva"),
        f("La sete è un segnale tardivo: quando arriva, il calo è già cominciato.",
          "fisiologia dei fluidi, consenso"),
        f("Il picco di temperatura corporea nel pomeriggio coincide con il momento in cui la forza è massima.",
          "cronobiologia dell'esercizio, consenso"),
        f("La luce del mattino negli occhi è il segnale più forte per regolare l'orologio biologico.",
          "cronobiologia, consenso"),
        f("Guardare uno schermo luminoso a tarda sera ritarda l'inizio del sonno.",
          "medicina del sonno, letteratura sulla luce serale"),
        f("Il caffè ha un'emivita di diverse ore: quello delle sedici è ancora in circolo a mezzanotte.",
          "farmacologia della caffeina, nozione di base"),
        f("L'attività fisica regolare è uno dei pochi interventi con effetto documentato su sonno, umore e metabolismo insieme.",
          "medicina preventiva, consenso"),
        f("Camminare dopo il pasto abbassa la glicemia postprandiale più che camminare a digiuno.",
          "letteratura su attività postprandiale e glicemia"),
        f("Anche due minuti di cammino dopo mangiato hanno un effetto misurabile sulla glicemia.",
          "meta-analisi su brevi camminate postprandiali"),
        f("Il freddo e il caldo si adattano; l'immobilità no: il corpo non impara mai a starci bene.",
          "fisiologia dell'adattamento, consenso"),
        f("Il respiro è l'unica funzione autonoma che puoi guidare a piacere: è la porta di servizio del sistema nervoso.",
          "fisiologia autonomica, nozione di base"),
        f("Alzarsi in piedi cambia immediatamente la distribuzione del sangue e la frequenza cardiaca.",
          "fisiologia cardiovascolare, nozione di base"),
        f("Il corpo umano è fatto per stare in piedi, camminare e accovacciarsi: la sedia ha meno di duecento anni di storia diffusa.",
          "antropologia della postura, consenso"),
        f("Accovacciarsi profondamente è un movimento naturale che si perde con il disuso, non con l'età.",
          "letteratura su mobilità articolare e disuso"),
    ]

    /// Tutti i fatti brevi.
    public static let all: [Phrase] =
        sedentarieta + movimento + mente + posturaFatti + abitudini + corpoSilenzioso
}
