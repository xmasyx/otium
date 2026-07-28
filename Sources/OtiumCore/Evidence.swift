import Foundation

/// Le fonti. Ogni parametro di Otium deve poter rispondere "da dove viene questo numero".
///
/// Non è documentazione: l'app mostra queste voci accanto ai parametri che governano, e il
/// README le ripubblica. Il concorrente più caro (Exercise Snacks, 49,99 £/anno) si dichiara
/// "science-backed" senza citare un solo studio; qui la citazione è il prodotto.
public struct Study: Identifiable, Equatable, Sendable {
    public let id: String
    public let claim: String
    public let citation: String
    public let year: Int
    public let url: String
    /// Cosa governa, in una riga: il parametro che questo studio giustifica.
    public let governs: String
    /// Le stesse due righe in inglese. **La citazione non si traduce**: è il titolo vero
    /// dell'articolo, ed è già in inglese — tradurlo renderebbe la fonte non ritrovabile, che è
    /// l'unica cosa che una citazione deve saper fare.
    public let claimEN: String
    public let governsEN: String

    public init(id: String, claim: String, citation: String, year: Int, url: String,
                governs: String, claimEN: String = "", governsEN: String = "") {
        self.id = id
        self.claim = claim
        self.citation = citation
        self.year = year
        self.url = url
        self.governs = governs
        self.claimEN = claimEN.isEmpty ? claim : claimEN
        self.governsEN = governsEN.isEmpty ? governs : governsEN
    }

    public var localizedClaim: String { L.t(claim, claimEN) }
    public var localizedGoverns: String { L.t(governs, governsEN) }
}

public enum Evidence {

    /// I 30 minuti fra un break e l'altro.
    public static let sittingInterval = Study(
        id: "duran-2023",
        claim: "In un crossover randomizzato su quattro dosi diverse, l'unica che ha davvero "
             + "abbassato i picchi glicemici (−58%) è stata 5 minuti di movimento ogni 30 minuti. "
             + "Dosi minori hanno abbassato la pressione ma non la glicemia.",
        citation: "Duran et al., «Breaking Up Prolonged Sitting to Improve Cardiometabolic Risk: "
                + "Dose-Response Analysis of a Randomized Crossover Trial», Med Sci Sports Exerc",
        year: 2023,
        url: "https://pubmed.ncbi.nlm.nih.gov/36728338/",
        governs: "Intervallo fra i break: 30 minuti di tempo attivo.",
        claimEN: "In a randomised crossover trial of four different doses, the only one that genuinely "
             + "flattened glucose spikes (−58%) was 5 minutes of movement every 30 minutes. "
             + "Smaller doses lowered blood pressure but not blood sugar.",
        governsEN: "Interval between breaks: 30 minutes of active time."
    )

    /// Perché squat e non una camminata.
    public static let squatsBeatWalking = Study(
        id: "gao-2024",
        claim: "18 uomini in sovrappeso, 8,5 ore seduti. Interrompere con 3 minuti di squat ogni "
             + "45 minuti ha battuto una singola camminata da 30 minuti, con circa il doppio del "
             + "beneficio glicemico (7,9 contro 10,2 mmol/L/h del controllo). Il meccanismo è "
             + "l'attivazione di quadricipiti e glutei, non i passi.",
        citation: "Gao, Li, Finni & Pesola, «Enhanced muscle activity during interrupted sitting "
                + "improves glycemic control in overweight and obese men», Scand J Med Sci Sports",
        year: 2024,
        url: "https://pubmed.ncbi.nlm.nih.gov/38629807/",
        governs: "La scelta degli esercizi di forza a corpo libero invece di «alzati e cammina».",
        claimEN: "18 overweight men, 8.5 hours seated. Breaking it up with 3 minutes of squats every "
             + "45 minutes beat a single 30-minute walk, with roughly twice the glycaemic "
             + "benefit (7.9 against 10.2 mmol/L/h for the control). The mechanism is quadriceps "
             + "and glute activation, not the steps.",
        governsEN: "Choosing bodyweight strength exercises instead of «get up and walk»."
    )

    /// I 5 minuti della pausa piena.
    public static let hourlyBreaks = Study(
        id: "galinsky-2000",
        claim: "Sul campo, aggiungere 5 minuti di pausa ogni ora ha ridotto disturbi "
             + "muscoloscheletrici e affaticamento visivo senza alcuna perdita di produttività "
             + "misurata. Il follow-up del 2007 con esercizi di stretching lo conferma.",
        citation: "Galinsky et al., «A field study of supplementary rest breaks for data-entry "
                + "operators», Ergonomics 43(5); follow-up in Am J Ind Med 50(7), 2007",
        year: 2000,
        url: "https://pubmed.ncbi.nlm.nih.gov/10877480/",
        governs: "La pausa piena da 5 minuti.",
        claimEN: "In the field, adding 5 minutes of break every hour reduced musculoskeletal discomfort "
             + "and eye strain with no measured loss of productivity. The 2007 follow-up with "
             + "stretching exercises confirms it.",
        governsEN: "The 5-minute full break."
    )

    /// Perché le micro-pause sono corte, e perché la pausa piena esiste comunque.
    public static let microBreaks = Study(
        id: "albulescu-2022",
        claim: "Meta-analisi di 22 studi: le micro-pause (≤10 minuti) riducono la fatica e alzano "
             + "il vigore. Avvertenza degli autori, presa sul serio qui: dopo lavoro cognitivo "
             + "molto impegnativo 10 minuti non bastano a recuperare la performance — per questo "
             + "ogni 90 minuti la pausa è piena e lontana dallo schermo.",
        citation: "Albulescu et al., «Give me a break! A systematic review and meta-analysis on "
                + "the efficacy of micro-breaks for increasing well-being and performance», PLOS ONE 17(8)",
        year: 2022,
        url: "https://pubmed.ncbi.nlm.nih.gov/36044424/",
        governs: "I 90 secondi del micro-snack, e l'esistenza della pausa piena ogni 90 minuti.",
        claimEN: "Meta-analysis of 22 studies: micro-breaks (≤10 minutes) reduce fatigue and raise vigour. "
             + "A caveat from the authors, taken seriously here: after very demanding cognitive "
             + "work 10 minutes are not enough to recover performance — which is why every 90 "
             + "minutes the break is full, and away from the screen.",
        governsEN: "The 90 seconds of the micro-snack, and why a full break exists every 90 minutes."
    )

    /// La sessione intensa della pausa piena.
    public static let vilpa = Study(
        id: "stamatakis-2022",
        claim: "25.241 adulti non sportivi seguiti per 7 anni con accelerometro: tre sessioni intense "
             + "quotidiani da 1-2 minuti di attività vigorosa nella vita normale si associano a "
             + "circa il 40% di mortalità in meno. Non serve allenarsi: servono tre minuti duri.",
        citation: "Stamatakis et al., «Association of wearable device-measured vigorous "
                + "intermittent lifestyle physical activity with mortality», Nature Medicine 28",
        year: 2022,
        url: "https://pubmed.ncbi.nlm.nih.gov/36482104/",
        governs: "I 60-90 secondi vigorosi della pausa piena, e il bersaglio di 3 sessioni al giorno.",
        claimEN: "25,241 non-exercising adults followed for 7 years with accelerometers: three daily "
             + "1-2 minute bouts of vigorous activity in ordinary life are associated with about "
             + "40% lower mortality. You do not need to train: you need three hard minutes.",
        governsEN: "The 60-90 vigorous seconds of the full break, and the target of 3 bouts a day."
    )

    /// Ciò che Otium NON implementa, e perché. La stessa onestà, girata al contrario.
    public static let twentyTwentyTwenty = Study(
        id: "johnson-2023",
        claim: "NON IMPLEMENTATA. La regola 20-20-20 (ogni 20 minuti, 20 secondi, a 6 metri) è in "
             + "quasi tutte le app concorrenti. In un trial del 2023 che ha confrontato pause di "
             + "20 secondi a intervalli di 5, 10 e 20 minuti, non è emersa alcuna differenza su "
             + "sintomi, velocità e accuratezza di lettura. I tre «20» furono scelti perché "
             + "memorabili, non perché ottimizzati. Otium non costruisce un timer per gli occhi: "
             + "la pausa motoria li riposa comunque.",
        citation: "Johnson & Rosenfield, sul valore terapeutico della regola 20-20-20 "
                + "(discusso in Optometry Advisor / Ophthalmic Physiol Opt)",
        year: 2023,
        url: "https://pubmed.ncbi.nlm.nih.gov/36473088/",
        governs: "Una funzione deliberatamente assente.",
        claimEN: "NOT IMPLEMENTED. The 20-20-20 rule (every 20 minutes, 20 seconds, at 20 feet) is in "
             + "almost every competing app. In a 2023 trial comparing 20-second breaks at 5, 10 "
             + "and 20 minute intervals, no difference emerged in symptoms, reading speed or "
             + "accuracy. The three «20»s were chosen because they are memorable, not because they "
             + "were optimised. Otium does not build a timer for your eyes: the movement break "
             + "rests them anyway.",
        governsEN: "A feature deliberately absent."
    )


    /// La domanda del principale: c'entra anche la concentrazione, o solo il fisico?
    public static let systematicBreaks = Study(
        id: "biwer-2023",
        claim: "Confronto diretto fra pause decise in anticipo e pause prese quando capita. "
             + "Chi si autoregolava faceva sessioni più lunghe e pause più lunghe, e riportava "
             + "più stanchezza e più distrazione, meno concentrazione e meno motivazione. Con le "
             + "pause sistematiche lo stesso lavoro veniva completato con lo stesso sforzo "
             + "mentale, in meno tempo. È la parte del metodo Pomodoro che regge alla prova: "
             + "che le pause siano imposte, non contrattate.",
        citation: "Biwer, Wiradhany, oude Egbrink & de Bruin, «Understanding effort regulation: "
                + "Comparing 'Pomodoro' breaks and self-regulated breaks», Br J Educ Psychol",
        year: 2023,
        url: "https://pubmed.ncbi.nlm.nih.gov/36859717/",
        governs: "Perché la pausa la decide l'app e non tu, al momento.",
        claimEN: "A direct comparison between breaks decided in advance and breaks taken whenever. Those "
             + "who self-regulated worked in longer stretches and took longer breaks, and reported "
             + "more tiredness and more distraction, less focus and less motivation. With "
             + "systematic breaks the same work was completed with the same mental effort, in less "
             + "time. It is the part of the Pomodoro method that survives testing: that breaks are "
             + "imposed, not negotiated.",
        governsEN: "Why the app decides the break and not you, in the moment."
    )

    /// Perché una pausa che ti fa fare qualcosa d'altro batte una pausa passiva.
    public static let goalHabituation = Study(
        id: "ariga-lleras-2011",
        claim: "Il calo di attenzione dopo un'ora sullo stesso compito non è una batteria che si "
             + "scarica: è il cervello che smette di considerare attivo l'obiettivo. Chi ha "
             + "interrotto brevemente il compito con un'attività diversa non ha avuto alcun "
             + "calo; chi non l'ha fatto è peggiorato regolarmente. La pausa funziona perché "
             + "disattiva e riattiva l'obiettivo, non perché ti fa riposare.",
        citation: "Ariga & Lleras, «Brief and rare mental breaks keep you focused: deactivation "
                + "and reactivation of task goals preempt vigilance decrements», Cognition 118(3)",
        year: 2011,
        url: "https://pubmed.ncbi.nlm.nih.gov/21211793/",
        governs: "Perché la pausa ti fa fare un esercizio invece di lasciarti guardare il muro.",
        claimEN: "The drop in attention after an hour on the same task is not a battery running down: it "
             + "is the brain no longer treating the goal as active. People who briefly interrupted "
             + "the task with a different activity showed no decline at all; those who did not got "
             + "steadily worse. The break works because it deactivates and reactivates the goal, "
             + "not because it rests you.",
        governsEN: "Why the break makes you do an exercise instead of letting you stare at the wall."
    )

    /// La seconda cosa che Otium NON promette.
    public static let exerciseAndCognition = Study(
        id: "cognition-caveat-2024",
        claim: "NON PROMESSA. Che 90 secondi di squat migliorino il lavoro subito dopo non è "
             + "dimostrato. Le meta-analisi sull'esercizio acuto trovano un effetto piccolo ma "
             + "positivo sulle funzioni esecutive per sforzi più lunghi, mentre per durate sotto i "
             + "10 minuti almeno una revisione riporta un effetto negativo nell'immediato, e "
             + "l'effetto delle micro-pause motorie sulla cognizione resta dichiarato "
             + "inconcludente. Otium interrompe per ragioni metaboliche e di fatica, non perché "
             + "ti renda più intelligente nei dieci minuti successivi.",
        // Il nome era sbagliato: il lavoro puntato dal link è di Garrett, Chak e Bullock, non di
        // Ludyga. Verificato su PubMed il 2026-07-28 (PMID 39242965).
        citation: "Garrett, Chak & Bullock, «A systematic review and Bayesian meta-analysis "
                + "provide evidence for an effect of acute physical activity on cognition», "
                + "Communications Psychology 2, 2024",
        year: 2024,
        url: "https://pubmed.ncbi.nlm.nih.gov/39242965/",
        governs: "Una promessa che l'app si rifiuta di fare.",
        claimEN: "NOT PROMISED. That 90 seconds of squats improve the work right afterwards is not "
             + "established. Meta-analyses of acute exercise find a small but positive effect on "
             + "executive function for longer efforts, while for durations under 10 minutes at "
             + "least one review reports a negative immediate effect, and the effect of movement "
             + "micro-breaks on cognition is explicitly reported as inconclusive. Otium interrupts "
             + "for metabolic and fatigue reasons, not because it makes you smarter in the next "
             + "ten minutes.",
        governsEN: "A promise the app refuses to make."
    )

    /// Tutte le fonti, nell'ordine in cui hanno senso da leggere.
    public static let all: [Study] = [
        sittingInterval, squatsBeatWalking, hourlyBreaks, microBreaks, vilpa,
        systematicBreaks, goalHabituation,
        twentyTwentyTwenty, exerciseAndCognition,
    ]

    /// Le fonti che dichiarano cosa l'app **non** fa e non promette.
    public static let disclaimers: [Study] = [twentyTwentyTwenty, exerciseAndCognition]

    /// La fonte da mostrare alla pausa numero `breakIndex`.
    ///
    /// **Solo quelle che giustificano qualcosa che sta succedendo.** Le due voci «non promesso»
    /// finivano nel giro e capitavano addosso a metà pausa: *«Non promesso: una funzione
    /// deliberatamente assente — Johnson & Rosenfield, regola 20-20-20»*, mentre stai facendo i
    /// push-up. Sono oneste e stanno in piedi, ma lì rispondono a una domanda che nessuno ha
    /// fatto: la riga sotto il blocco esiste per dire **perché ti sto interrompendo**, e una
    /// funzione che non c'è non interrompe nessuno. Restano dove hanno senso, nella finestra
    /// «Da dove vengono questi numeri», che si apre quando sei tu a volerle leggere.
    ///
    /// Deterministica, così non se ne perde nessuna e non se ne ripetono due di fila.
    public static func study(forBreak breakIndex: Int) -> Study {
        let list = implemented
        let i = ((breakIndex - 1) % list.count + list.count) % list.count
        return list[i]
    }

    /// Le fonti che giustificano una funzione presente (esclusa quella che ne giustifica l'assenza).
    public static let implemented: [Study] = all.filter { s in !disclaimers.contains { $0.id == s.id } }
}
