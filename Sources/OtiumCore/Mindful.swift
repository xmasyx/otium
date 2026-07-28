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

    /// Anonima: bella, vera, e senza un padre certo.
    private static func m(_ text: String) -> Phrase {
        Phrase(id: "m:\(text.prefix(28))", kind: .mindful, text: text)
    }

    /// Con la sua tradizione dichiarata.
    private static func t(_ text: String, _ source: String) -> Phrase {
        Phrase(id: "t:\(text.prefix(28))", kind: .mindful, text: text, attribution: source)
    }

    // MARK: - Il corpo, adesso

    static let corpo: [Phrase] = [
        m("Il sangue nelle gambe non risale da solo: sono i muscoli a spingerlo su."),
        m("Le articolazioni si nutrono di movimento, non di riposo."),
        m("Il collo che duole di sera è il collo che di mattina non si è mai girato."),
        m("Alzati come se dovessi guardare fuori dalla finestra. Poi guardaci davvero."),
        m("Espira più a lungo di quanto inspiri: è il modo più corto per calmarsi."),
        m("Gli occhi hanno un muscolo anche loro, e l'hai tenuto contratto per un'ora."),
        m("Guarda qualcosa di lontano. Gli occhi si sono dimenticati che esiste la distanza."),
        m("Sciogli le spalle: le tieni alzate da così tanto che non te ne accorgi più."),
        m("La mandibola stretta è una decisione che stai prendendo senza saperlo. Lasciala andare."),
        m("Se ti accorgi di essere in apnea davanti allo schermo, non sei il solo. Respira."),
    ]

    // MARK: - Presenza

    static let presenza: [Phrase] = [
        m("Ascolta i rumori della stanza. Ci sono da un'ora e non li avevi sentiti."),
        m("Accorgersi di essersi distratti è già essere tornati."),
        m("Chiudi gli occhi per dieci secondi. Non succede niente, ed è la notizia buona."),
        m("Sentire i piedi appoggiati per terra è il modo più veloce di tornare nel corpo."),
        m("Guarda una cosa sola per dieci secondi, senza nominarla."),
        m("Le mani sono contratte sul mouse da un'ora. Aprile."),
    ]

    // MARK: - Costanza e piccoli passi

    static let costanza: [Phrase] = [
        m("Comincia male, ma comincia."),
        m("Fai la versione più piccola possibile: quella si fa anche nei giorni storti."),
        m("La regola dei due minuti: comincia, e vedi se ti fermi davvero dopo."),
    ]

    // MARK: - Lavoro e attenzione

    static let lavoro: [Phrase] = [
        m("La stanchezza non si vede da dentro: si vede dagli errori."),
        m("Quando rileggi la stessa riga tre volte, non è la riga: sei tu."),
        m("Proteggi le tue ore migliori: sono poche, e le stai regalando."),
        m("Fai la cosa difficile per prima, o la penserai tutto il giorno."),
    ]

    // MARK: - Filosofia orientale, senza firma certa

    static let orientale: [Phrase] = [
        t("Prima dell'illuminazione: tagliare legna, portare acqua. Dopo l'illuminazione: tagliare legna, portare acqua.", "detto zen"),
        t("Siedi. Cammina. Non oscillare fra le due.", "detto zen"),
        t("Se sei distratto, non c'è il tè. Se sei presente, tutto è tè.", "detto zen"),
        t("Se hai fretta, siediti dieci minuti. Se hai molta fretta, siediti un'ora.", "detto zen"),
        t("La neve cade, ogni fiocco al suo posto.", "detto zen"),
        t("Il maestro insegna a svuotare la tazza prima di riempirla.", "storia zen"),
        t("Cadi sette volte, rialzati otto.", "proverbio giapponese"),
        t("Anche una polvere accumulata diventa montagna.", "proverbio giapponese"),
        t("Un'ora di mattina vale due di sera.", "proverbio giapponese"),
        t("Il chiodo che sporge riceve il martello: sappi quando sporgere.", "proverbio giapponese"),
        t("La visione senza azione è un sogno a occhi aperti; l'azione senza visione è un incubo.", "proverbio giapponese"),
        t("Il momento migliore per piantare un albero era vent'anni fa. Il secondo migliore è adesso.", "proverbio cinese"),
        t("Non temere di andare piano: temi solo di fermarti.", "proverbio cinese"),
        t("Il maestro nella pentola non fa bollire due volte lo stesso brodo.", "proverbio cinese"),
        t("L'acqua che scorre non marcisce.", "proverbio cinese"),
        t("Un centimetro di tempo è un centimetro d'oro, ma un centimetro d'oro non compra un centimetro di tempo.", "proverbio cinese"),
        t("Chi chiede è sciocco per cinque minuti; chi non chiede resta sciocco per sempre.", "proverbio cinese"),
        t("Un buon libro è un buon amico.", "proverbio cinese"),
        t("La lingua è morbida e resta; i denti sono duri e cadono.", "proverbio cinese"),
        t("Le tigri lasciano la pelle, gli uomini il nome.", "proverbio cinese"),
        t("Chi torna indietro per la strada giusta non ha perso tempo.", "proverbio orientale"),
        t("La montagna non si muove: cambia il sentiero.", "proverbio orientale"),
        m("Il bambù si piega nella tempesta, e per questo la supera."),
        m("Chi corre dietro a due lepri non ne prende nessuna."),
        m("Il loto cresce nel fango e non se ne lamenta."),
        m("La luna si riflette in mille pozzanghere ed è sempre una."),
    ]

    // MARK: - Tempo e impermanenza

    static let tempo: [Phrase] = [
        m("Nessuno ricorda le mail. Tutti ricordano come stavano."),
        m("La cosa che rimandi da tre settimane richiede venti minuti."),
    ]

    // MARK: - Sé, con misura

    static let se: [Phrase] = [
        m("Quando tutto sembra pesante, comincia dal corpo. La testa segue."),
        m("Fatti una domanda semplice: quando ho bevuto l'ultima volta?"),
        m("La forza di volontà si esaurisce. L'ambiente no: cambia quello."),
        m("Lunedì è un giorno come oggi, con meno vantaggio."),
    ]

    // MARK: - Natura e respiro largo

    static let natura: [Phrase] = [
        // La più bella che avessi in mente, e la ragione per cui questo pool esiste: circola
        // ovunque come di Lao Tzu, ma non compare in nessuna traduzione del Tao Te Ching e
        // nessuna fonte autorevole ne indica l'originale. Resta — è bella e c'entra — **senza il
        // nome che non le spetta**.
        m("La natura non ha fretta, eppure tutto si compie."),
        m("Nessun albero cresce solo verso l'alto: prima va giù."),
        m("Anche il campo migliore riposa un anno su tre."),
        m("Il grano cresce di notte, quando nessuno guarda."),
        m("Guarda il cielo: è lì tutto il giorno e non lo alzi mai."),
    ]

    // MARK: - Cominciare, finire, ricominciare

    static let soglie: [Phrase] = [
        m("Metti le scarpe. Il resto viene da sé."),
        m("Finire una cosa piccola rimette in moto tutto il resto."),
        m("Il momento in cui vorresti smettere è di solito appena prima del punto interessante."),
        m("Lascia il lavoro a metà di una frase: domani saprai dove riprendere."),
    ]

    // MARK: - Relazione con lo schermo

    static let schermo: [Phrase] = [
        m("Il feed è progettato per non finire mai. La tua giornata no."),
        m("Se hai aperto il telefono senza motivo, l'hai fatto per abitudine, non per bisogno."),
        m("Guarda un punto lontano: gli occhi ricordano com'era il mondo prima dei quaranta centimetri."),
        m("La finestra è lì da stamattina."),
        m("Non devi rispondere subito. Quasi mai."),
    ]

    // MARK: - Con misura

    static let misura: [Phrase] = [
        m("Se domani non puoi ripeterlo, oggi hai fatto troppo."),
        m("Il riposo è la parte dell'allenamento in cui succedono le cose."),
        m("Il muscolo cresce mentre dormi, non mentre spingi."),
        m("Se ti fa paura cominciare, dimezza. Poi dimezza ancora."),
    ]

    /// Tutto il pool contemplativo.
    public static let all: [Phrase] =
        corpo + presenza + costanza + lavoro + orientale + tempo + se + natura
        + soglie + schermo + misura
}
