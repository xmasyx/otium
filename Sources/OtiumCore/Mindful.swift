import Foundation

/// Il pool contemplativo: presenza, filosofia orientale, sviluppo personale.
///
/// **Perché esiste separato dalle citazioni.** Il pool `Quotes` ha una regola dura — opera
/// identificabile o niente — e quella regola, presa da sola, buttava via decine di frasi belle e
/// vere solo perché nessuno sa più chi le ha dette per primo. Qui vivono quelle: **anonime**, che
/// è la verità, invece che firmate a caso, che è una bugia comoda. Dove la tradizione È la fonte
/// — un proverbio zen, un detto giapponese — la tradizione viene dichiarata come tale.
///
/// Sono la parte che rende un mese di pause senza ripetizioni un fatto e non una promessa: una
/// pausa ogni mezz'ora fa ~16 riprese al giorno, ~480 al mese, e nessun corpus di sole citazioni
/// verificate arriva lì restando onesto.
public enum Mindful {

    /// Anonima: bella, vera, e senza un padre certo — nelle due lingue.
    ///
    /// **L'inglese non ha valore di default, ed è una scelta.** Finché ce l'aveva, una frase
    /// poteva entrare monca e se ne accorgeva solo il test; adesso non compila. Il ponte di
    /// migrazione è stato tolto il 2026-07-28, appena chiusa l'ultima delle 73: una rete che
    /// resta accesa dopo aver finito il suo lavoro è una rete che un giorno lascerà passare
    /// qualcosa, perché nessuno la guarda più.
    private static func m(_ text: String, _ en: String) -> Phrase {
        Phrase(id: "m:\(text.prefix(28))", kind: .mindful, text: text, textEN: en)
    }

    /// Con la sua tradizione dichiarata, nelle due lingue.
    private static func t(_ text: String, _ en: String, _ source: String, _ sourceEN: String) -> Phrase {
        Phrase(id: "t:\(text.prefix(28))", kind: .mindful, text: text, textEN: en,
               attribution: source, attributionEN: sourceEN)
    }

    // MARK: - Il corpo, adesso

    static let corpo: [Phrase] = [
        m("Il sangue nelle gambe non risale da solo: sono i muscoli a spingerlo su.", "Blood doesn't climb out of your legs on its own — your muscles push it up."),
        m("Le articolazioni si nutrono di movimento, non di riposo.", "Joints feed on movement, not on rest."),
        m("Il collo che duole di sera è il collo che di mattina non si è mai girato.", "The neck that aches at night is the neck that never turned all morning."),
        m("Alzati come se dovessi guardare fuori dalla finestra. Poi guardaci davvero.", "Stand up as if you were going to look out of the window. Then actually look."),
        m("Espira più a lungo di quanto inspiri: è il modo più corto per calmarsi.", "Breathe out longer than you breathe in: it's the shortest way to calm down."),
        m("Gli occhi hanno un muscolo anche loro, e l'hai tenuto contratto per un'ora.", "Your eyes have a muscle too, and you've held it clenched for an hour."),
        m("Guarda qualcosa di lontano. Gli occhi si sono dimenticati che esiste la distanza.", "Look at something far away. Your eyes have forgotten that distance exists."),
        m("Sciogli le spalle: le tieni alzate da così tanto che non te ne accorgi più.", "Drop your shoulders: you've held them up so long you no longer notice."),
        m("La mandibola stretta è una decisione che stai prendendo senza saperlo. Lasciala andare.", "A clenched jaw is a decision you're making without knowing it. Let it go."),
        m("Se ti accorgi di essere in apnea davanti allo schermo, non sei il solo. Respira.", "If you catch yourself holding your breath at the screen, you're not the only one. Breathe."),
    ]

    // MARK: - Presenza

    static let presenza: [Phrase] = [
        m("Ascolta i rumori della stanza. Ci sono da un'ora e non li avevi sentiti.", "Listen to the sounds of the room. They've been there an hour and you hadn't heard them."),
        m("Accorgersi di essersi distratti è già essere tornati.", "Noticing that you drifted off is already being back."),
        m("Chiudi gli occhi per dieci secondi. Non succede niente, ed è la notizia buona.", "Close your eyes for ten seconds. Nothing happens, and that's the good news."),
        m("Sentire i piedi appoggiati per terra è il modo più veloce di tornare nel corpo.", "Feeling your feet on the floor is the fastest way back into your body."),
        m("Guarda una cosa sola per dieci secondi, senza nominarla.", "Look at one thing for ten seconds without naming it."),
        m("Le mani sono contratte sul mouse da un'ora. Aprile.", "Your hands have been clamped on the mouse for an hour. Open them."),
    ]

    // MARK: - Costanza e piccoli passi

    static let costanza: [Phrase] = [
        m("Comincia male, ma comincia.", "Start badly, but start."),
        m("Fai la versione più piccola possibile: quella si fa anche nei giorni storti.", "Do the smallest possible version: that one gets done even on bad days."),
        m("La regola dei due minuti: comincia, e vedi se ti fermi davvero dopo.", "The two-minute rule: begin, then see whether you really stop."),
    ]

    // MARK: - Lavoro e attenzione

    static let lavoro: [Phrase] = [
        m("La stanchezza non si vede da dentro: si vede dagli errori.", "Tiredness can't be seen from the inside: it shows up in the mistakes."),
        m("Quando rileggi la stessa riga tre volte, non è la riga: sei tu.", "When you read the same line three times, it isn't the line: it's you."),
        m("Proteggi le tue ore migliori: sono poche, e le stai regalando.", "Guard your best hours: there are few of them, and you're giving them away."),
        m("Fai la cosa difficile per prima, o la penserai tutto il giorno.", "Do the hard thing first, or you'll think about it all day."),
    ]

    // MARK: - Filosofia orientale, senza firma certa

    static let orientale: [Phrase] = [
        t("Prima dell'illuminazione: tagliare legna, portare acqua. Dopo l'illuminazione: tagliare legna, portare acqua.", "Before enlightenment: chop wood, carry water. After enlightenment: chop wood, carry water.", "detto zen", "Zen saying"),
        t("Siedi. Cammina. Non oscillare fra le due.", "Sit. Walk. Don't wobble between the two.", "detto zen", "Zen saying"),
        t("Se sei distratto, non c'è il tè. Se sei presente, tutto è tè.", "If you are distracted, there is no tea. If you are present, everything is tea.", "detto zen", "Zen saying"),
        t("Se hai fretta, siediti dieci minuti. Se hai molta fretta, siediti un'ora.", "If you are in a hurry, sit for ten minutes. If you are in a great hurry, sit for an hour.", "detto zen", "Zen saying"),
        t("La neve cade, ogni fiocco al suo posto.", "The snow falls, each flake in its place.", "detto zen", "Zen saying"),
        t("Il maestro insegna a svuotare la tazza prima di riempirla.", "The master teaches you to empty the cup before filling it.", "storia zen", "Zen story"),
        t("Cadi sette volte, rialzati otto.", "Fall down seven times, get up eight.", "proverbio giapponese", "Japanese proverb"),
        t("Anche una polvere accumulata diventa montagna.", "Even dust, piled up, becomes a mountain.", "proverbio giapponese", "Japanese proverb"),
        t("Un'ora di mattina vale due di sera.", "One hour in the morning is worth two in the evening.", "proverbio giapponese", "Japanese proverb"),
        t("Il chiodo che sporge riceve il martello: sappi quando sporgere.", "The nail that sticks out gets hammered: know when to stick out.", "proverbio giapponese", "Japanese proverb"),
        t("La visione senza azione è un sogno a occhi aperti; l'azione senza visione è un incubo.", "Vision without action is a daydream; action without vision is a nightmare.", "proverbio giapponese", "Japanese proverb"),
        t("Il momento migliore per piantare un albero era vent'anni fa. Il secondo migliore è adesso.", "The best time to plant a tree was twenty years ago. The second best is now.", "proverbio cinese", "Chinese proverb"),
        t("Non temere di andare piano: temi solo di fermarti.", "Do not fear going slowly: fear only standing still.", "proverbio cinese", "Chinese proverb"),
        t("Il maestro nella pentola non fa bollire due volte lo stesso brodo.", "A good cook does not boil the same broth twice.", "proverbio cinese", "Chinese proverb"),
        t("L'acqua che scorre non marcisce.", "Running water never goes stale.", "proverbio cinese", "Chinese proverb"),
        t("Un centimetro di tempo è un centimetro d'oro, ma un centimetro d'oro non compra un centimetro di tempo.", "An inch of time is an inch of gold, but an inch of gold will not buy an inch of time.", "proverbio cinese", "Chinese proverb"),
        t("Chi chiede è sciocco per cinque minuti; chi non chiede resta sciocco per sempre.", "He who asks is a fool for five minutes; he who never asks stays a fool forever.", "proverbio cinese", "Chinese proverb"),
        t("Un buon libro è un buon amico.", "A good book is a good friend.", "proverbio cinese", "Chinese proverb"),
        t("La lingua è morbida e resta; i denti sono duri e cadono.", "The tongue is soft and remains; the teeth are hard and fall out.", "proverbio cinese", "Chinese proverb"),
        t("Le tigri lasciano la pelle, gli uomini il nome.", "Tigers leave their skin behind, men their name.", "proverbio cinese", "Chinese proverb"),
        t("Chi torna indietro per la strada giusta non ha perso tempo.", "Turning back onto the right road is not lost time.", "proverbio orientale", "Eastern proverb"),
        t("La montagna non si muove: cambia il sentiero.", "The mountain does not move: change the path.", "proverbio orientale", "Eastern proverb"),
        m("Il bambù si piega nella tempesta, e per questo la supera.", "Bamboo bends in the storm, and that is how it comes through it."),
        m("Chi corre dietro a due lepri non ne prende nessuna.", "Chase two hares and you catch neither."),
        m("Il loto cresce nel fango e non se ne lamenta.", "The lotus grows in the mud and does not complain about it."),
        m("La luna si riflette in mille pozzanghere ed è sempre una.", "The moon is reflected in a thousand puddles and is always one moon."),
    ]

    // MARK: - Tempo e impermanenza

    static let tempo: [Phrase] = [
        m("Nessuno ricorda le mail. Tutti ricordano come stavano.", "Nobody remembers the emails. Everybody remembers how they felt."),
        m("La cosa che rimandi da tre settimane richiede venti minuti.", "The thing you've been putting off for three weeks takes twenty minutes."),
    ]

    // MARK: - Sé, con misura

    static let se: [Phrase] = [
        m("Quando tutto sembra pesante, comincia dal corpo. La testa segue.", "When everything feels heavy, start with the body. The head follows."),
        m("Fatti una domanda semplice: quando ho bevuto l'ultima volta?", "Ask yourself a simple question: when did I last drink some water?"),
        m("La forza di volontà si esaurisce. L'ambiente no: cambia quello.", "Willpower runs out. Your surroundings don't: change those."),
        m("Lunedì è un giorno come oggi, con meno vantaggio.", "Monday is a day like today, with less of a head start."),
    ]

    // MARK: - Natura e respiro largo

    static let natura: [Phrase] = [
        // La più bella che avessi in mente, e la ragione per cui questo pool esiste: circola
        // ovunque come di Lao Tzu, ma non compare in nessuna traduzione del Tao Te Ching e
        // nessuna fonte autorevole ne indica l'originale. Resta — è bella e c'entra — **senza il
        // nome che non le spetta**.
        m("La natura non ha fretta, eppure tutto si compie.", "Nature is not in a hurry, and yet everything gets done."),
        m("Nessun albero cresce solo verso l'alto: prima va giù.", "No tree grows only upward: first it goes down."),
        m("Anche il campo migliore riposa un anno su tre.", "Even the best field lies fallow one year in three."),
        m("Il grano cresce di notte, quando nessuno guarda.", "Wheat grows at night, when nobody is watching."),
        m("Guarda il cielo: è lì tutto il giorno e non lo alzi mai.", "Look at the sky: it's there all day and you never look up."),
    ]

    // MARK: - Cominciare, finire, ricominciare

    static let soglie: [Phrase] = [
        m("Metti le scarpe. Il resto viene da sé.", "Put your shoes on. The rest follows by itself."),
        m("Finire una cosa piccola rimette in moto tutto il resto.", "Finishing one small thing sets everything else moving again."),
        m("Il momento in cui vorresti smettere è di solito appena prima del punto interessante.", "The moment you want to quit is usually just before the interesting part."),
        m("Lascia il lavoro a metà di una frase: domani saprai dove riprendere.", "Stop work in the middle of a sentence: tomorrow you'll know where to pick up."),
    ]

    // MARK: - Relazione con lo schermo

    static let schermo: [Phrase] = [
        m("Il feed è progettato per non finire mai. La tua giornata no.", "The feed is designed never to end. Your day isn't."),
        m("Se hai aperto il telefono senza motivo, l'hai fatto per abitudine, non per bisogno.", "If you opened your phone for no reason, that was habit, not need."),
        m("Guarda un punto lontano: gli occhi ricordano com'era il mondo prima dei quaranta centimetri.", "Look at a distant point: your eyes remember the world before it shrank to arm's length."),
        m("La finestra è lì da stamattina.", "The window has been there since this morning."),
        m("Non devi rispondere subito. Quasi mai.", "You don't have to reply right away. Almost never."),
    ]

    // MARK: - Con misura

    static let misura: [Phrase] = [
        m("Se domani non puoi ripeterlo, oggi hai fatto troppo.", "If you can't repeat it tomorrow, you did too much today."),
        m("Il riposo è la parte dell'allenamento in cui succedono le cose.", "Rest is the part of training where things actually happen."),
        m("Il muscolo cresce mentre dormi, non mentre spingi.", "Muscle grows while you sleep, not while you push."),
        m("Se ti fa paura cominciare, dimezza. Poi dimezza ancora.", "If starting scares you, halve it. Then halve it again."),
    ]

    /// Tutto il pool contemplativo.
    public static let all: [Phrase] =
        corpo + presenza + costanza + lavoro + orientale + tempo + se + natura
        + soglie + schermo + misura
}
