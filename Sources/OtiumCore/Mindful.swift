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

    /// **La voce dell'app**: righe scritte per Otium, che non citano nessuno.
    ///
    /// Stavano dentro `m(…)` e uscivano a schermo con i caporali e «anonimo» sotto, cioè
    /// travestite da massima di cui si è perso l'autore. Il 2026-07-29 l'autore ha deciso di
    /// smettere di spacciarle per citazioni invece di buttarle: sono buone righe, il difetto era
    /// la veste. Vedi `Phrase.Kind.voce`.
    ///
    /// **L'`id` resta `m:`** e non diventa `v:`: cambiarlo azzererebbe queste frasi nel mazzo di
    /// chi ha l'app installata, e rivedrebbe subito quaranta righe già viste. La veste cambia,
    /// l'identità no.
    private static func v(_ text: String, _ en: String) -> Phrase {
        Phrase(id: "m:\(text.prefix(28))", kind: .voce, text: text, textEN: en)
    }

    /// Con la sua tradizione dichiarata, nelle due lingue.
    private static func t(_ text: String, _ en: String, _ source: String, _ sourceEN: String) -> Phrase {
        Phrase(id: "t:\(text.prefix(28))", kind: .mindful, text: text, textEN: en,
               attribution: source, attributionEN: sourceEN)
    }

    // MARK: - Il corpo, adesso

    static let corpo: [Phrase] = [
        v("Il collo che duole la sera è quello che durante il giorno non si è mai mosso.", "The neck that aches at night is the one that never moved all day."),
        v("Alzati come per guardare dalla finestra. Poi fallo davvero.", "Stand up as if to look out of the window. Then actually do it."),
        v("Espira più a lungo di quanto inspiri. È la via più breve alla calma.", "Breathe out longer than you breathe in. It's the shortest way to calm down."),
        v("Anche gli occhi hanno un muscolo, e lo tieni contratto da un'ora.", "Your eyes have a muscle too, and you've been clenching it for an hour."),
        v("Guarda qualcosa di lontano. I tuoi occhi si sono dimenticati che la distanza esiste.", "Look at something far away. Your eyes have forgotten that distance exists."),
        v("Sciogli le spalle. Le tieni contratte da tanto che non te ne accorgi più.", "Drop your shoulders. You've held them clenched so long you no longer notice."),
        // Rimessa il 2026-08-01: la logica era rovesciata
        // nella versione affermativa («il muscolo che **usi** adesso è quello che avrai»): vera
        // anche quella, ma è la perdita a mordere, non la conservazione.
        v("Il muscolo che non usi adesso è quello che non avrai fra vent'anni.", "The muscle you don't use now is the one you won't have in twenty years."),
        v("La mandibola contratta è una decisione che stai prendendo senza saperlo. Lasciala andare.", "A clenched jaw is a decision you're making without knowing it. Let it go."),
        v("Se ti accorgi di essere in apnea davanti allo schermo, non sei il solo. Respira.", "If you catch yourself holding your breath at the screen, you're not the only one. Breathe."),
    ]

    // MARK: - Presenza

    static let presenza: [Phrase] = [
        v("Ascolta i rumori della stanza. Ci sono da un'ora e non li sentivi.", "Listen to the sounds of the room. They've been there an hour and you hadn't heard them."),
        v("Accorgersi di essersi distratti è già essere tornati.", "Noticing that you drifted off is already being back."),
        // L'italiano non traduce l'inglese, e qui apposta: «ed è la buona notizia» era il calco
        // di *that's the good news* — commentava la frase invece di lasciarla lavorare. «E va
        // bene così» accetta e basta, che è il registro di tutto il gruppo. In inglese la chiusa
        // originale è inglese vero e resta.
        v("Chiudi gli occhi per dieci secondi. Non succede niente, e va bene così.", "Close your eyes for ten seconds. Nothing happens, and that's the good news."),
        v("Sentire i piedi appoggiati per terra è il modo più veloce di tornare nel corpo.", "Feeling your feet on the floor is the fastest way back into your body."),
        v("Guarda una cosa sola per dieci secondi, senza nominarla.", "Look at one thing for ten seconds without naming it."),
        v("Le mani sono contratte sul mouse da un'ora. Aprile.", "Your hands have been clamped on the mouse for an hour. Open them."),
    ]

    // MARK: - Costanza e piccoli passi

    static let costanza: [Phrase] = [
        v("Comincia male, ma comincia.", "Start badly, but start."),
        v("Fai la versione più piccola. Quella riesce anche nei giorni storti.", "Do the smallest version. That one gets done even on bad days."),
        v("Comincia dicendoti «solo due minuti». Difficile che ti fermi lì.", "Begin by telling yourself it's just two minutes. You almost never stop there."),
    ]

    // MARK: - Lavoro e attenzione

    static let lavoro: [Phrase] = [
        v("La stanchezza non si vede da dentro, si vede dagli errori.", "Tiredness can't be seen from the inside: it shows up in the mistakes."),
        v("Quando rileggi la stessa riga tre volte, non è la riga, sei tu.", "When you read the same line three times, it isn't the line: it's you."),
        v("Proteggi le tue ore migliori. Sono poche e le stai sprecando.", "Guard your best hours. There are few of them, and you're wasting them."),
        v("Fai la cosa difficile per prima, o la penserai tutto il giorno.", "Do the hard thing first, or you'll think about it all day."),
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
        t("Non temere di andare piano, temi solo di fermarti.", "Do not fear going slowly: fear only standing still.", "proverbio cinese", "Chinese proverb"),
        t("Un buon cuoco non fa bollire due volte lo stesso brodo.", "A good cook does not boil the same broth twice.", "proverbio cinese", "Chinese proverb"),
        t("L'acqua che scorre non marcisce.", "Running water never goes stale.", "proverbio cinese", "Chinese proverb"),
        t("Un centimetro di tempo è un centimetro d'oro, ma un centimetro d'oro non compra un centimetro di tempo.", "An inch of time is an inch of gold, but an inch of gold will not buy an inch of time.", "proverbio cinese", "Chinese proverb"),
        t("Chi chiede è sciocco per cinque minuti; chi non chiede resta sciocco per sempre.", "He who asks is a fool for five minutes; he who never asks stays a fool forever.", "proverbio cinese", "Chinese proverb"),
        t("Un buon libro è un buon amico.", "A good book is a good friend.", "proverbio cinese", "Chinese proverb"),
        t("La lingua è morbida e resta; i denti sono duri e cadono.", "The tongue is soft and remains; the teeth are hard and fall out.", "proverbio cinese", "Chinese proverb"),
        t("Le tigri lasciano la pelle, gli uomini il nome.", "Tigers leave their skin behind, men their name.", "proverbio cinese", "Chinese proverb"),
        t("Chi torna indietro per la strada giusta non ha perso tempo.", "Turning back onto the right road is not lost time.", "proverbio orientale", "Eastern proverb"),
        t("La montagna non si muove, cambia il sentiero.", "The mountain does not move: change the path.", "proverbio orientale", "Eastern proverb"),
        // Al posto del bambù, che nel proverbio giapponese non c'è: quello che non si spezza
        // sotto la neve è il **salice** (柳に雪折れなし). Sostituito il 2026-07-29, e con la
        // tradizione dichiarata invece che anonimo.
        t("Il salice non si spezza sotto la neve.", "No snow ever breaks the willow.", "proverbio giapponese", "Japanese proverb"),
        m("Chi corre dietro a due lepri non ne prende nessuna.", "Chase two hares and you catch neither."),
        m("La luna si riflette in mille pozzanghere ed è sempre una.", "The moon is reflected in a thousand puddles and is always one moon."),
    ]

    // MARK: - Tempo e impermanenza

    // «Nessuno ricorda le mail. Tutti ricordano come stavano.» tolta il 2026-08-01 (nota 22).
    static let tempo: [Phrase] = [
        v("La cosa che rimandi da tre settimane ti prende venti minuti.", "The thing you've been putting off for three weeks takes twenty minutes."),
    ]

    // MARK: - Sé, con misura

    static let se: [Phrase] = [
        v("Quando tutto sembra pesante, comincia dal corpo. La testa segue.", "When everything feels heavy, start with the body. The head follows."),
        v("Una domanda semplice: quando hai bevuto l'ultima volta?", "A simple question: when did you last drink something?"),
        v("La forza di volontà si esaurisce. L'ambiente no, cambia quello.", "Willpower runs out. Your surroundings don't, so change those."),
        // «Lunedì è un giorno come oggi, solo più tardi.» tolta il 2026-08-01 (nota 27).
    ]

    // MARK: - Natura e respiro largo

    static let natura: [Phrase] = [
        // La più bella che avessi in mente, e la ragione per cui questo pool esiste: circola
        // ovunque come di Lao Tzu, ma non compare in nessuna traduzione del Tao Te Ching e
        // nessuna fonte autorevole ne indica l'originale. Resta — è bella e c'entra — **senza il
        // nome che non le spetta**.
        m("La natura non ha fretta, eppure tutto si compie.", "Nature is not in a hurry, and yet everything gets done."),
        m("Anche il campo migliore riposa un anno su tre.", "Even the best field lies fallow one year in three."),
        m("Il grano cresce di notte, quando nessuno guarda.", "Wheat grows at night, when nobody is watching."),
        v("Guarda il cielo. È lì tutto il giorno e tu non alzi mai la testa.", "Look at the sky. It's up there all day and you never lift your head."),
    ]

    // MARK: - Cominciare, finire, ricominciare

    static let soglie: [Phrase] = [
        v("Metti le scarpe. Il resto viene da sé.", "Put your shoes on. The rest follows by itself."),
        v("Finire una cosa piccola rimette in moto tutto il resto.", "Finishing one small thing sets everything else moving again."),
        v("Il momento in cui vorresti smettere è quasi sempre poco prima del successo.", "The moment you want to quit is almost always just before it works."),
        v("Lascia il lavoro a metà di una frase, domani saprai dove riprendere.", "Stop work in the middle of a sentence, and tomorrow you'll know where to pick up."),
    ]

    // MARK: - Relazione con lo schermo

    static let schermo: [Phrase] = [
        v("Il feed è progettato per non finire mai. La tua giornata no.", "The feed is designed never to end. Your day isn't."),
        v("Se hai aperto il telefono senza motivo, l'hai fatto per abitudine, non per bisogno.", "If you opened your phone for no reason, that was habit, not need."),
        v("Guarda un punto lontano. Gli occhi ricordano com'era il mondo prima che fosse ridotto alla portata di quaranta centimetri.", "Look at a distant point. Your eyes remember the world before it shrank to forty centimetres."),
        v("La finestra è lì da stamattina.", "The window has been there since this morning."),
        v("Non devi rispondere subito. Quasi mai.", "You don't have to reply right away. Almost never."),
    ]

    // MARK: - Con misura

    static let misura: [Phrase] = [
        v("Il riposo è la parte dell'allenamento in cui succede tutto.", "Rest is the part of training where everything happens."),
        v("Il muscolo cresce mentre dormi, non mentre spingi.", "Muscle grows while you sleep, not while you push."),
        v("Se ti fa paura cominciare, dimezza. Poi dimezza ancora.", "If starting scares you, halve it. Then halve it again."),
    ]

    /// Tutto il pool contemplativo.
    public static let all: [Phrase] =
        corpo + presenza + costanza + lavoro + orientale + tempo + se + natura
        + soglie + schermo + misura
}
