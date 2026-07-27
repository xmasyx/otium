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
        m("Il corpo tiene il conto di ogni ora in cui l'hai dimenticato."),
        m("Non stai perdendo tempo: stai restituendo sangue alle gambe."),
        m("Due minuti in piedi cancellano quaranta minuti di immobilità. È un cambio che conviene."),
        m("La schiena non si lamenta subito. Si lamenta fra dieci anni, e allora è tardi."),
        m("Muoviti prima di avere male: il dolore è un messaggero che arriva sempre in ritardo."),
        m("Il sangue nelle gambe non risale da solo: sono i muscoli a spingerlo su."),
        m("Sedersi è comodo per il minuto, caro per il decennio."),
        m("Un corpo fermo raffredda anche la testa."),
        m("Le articolazioni si nutrono di movimento, non di riposo."),
        m("Il collo che duole di sera è il collo che di mattina non si è mai girato."),
        m("Alzati come se dovessi guardare fuori dalla finestra. Poi guardaci davvero."),
        m("Respira dal naso, lentamente. Il resto del corpo ubbidisce al respiro."),
        m("Tre respiri lunghi valgono più di dieci minuti di buoni propositi."),
        m("Espira più a lungo di quanto inspiri: è il modo più corto per calmarsi."),
        m("Gli occhi hanno un muscolo anche loro, e l'hai tenuto contratto per un'ora."),
        m("Guarda qualcosa di lontano. Gli occhi si sono dimenticati che esiste la distanza."),
        m("La forza non si costruisce nelle ore lunghe, ma nei minuti ripetuti."),
        m("Il muscolo che usi adesso è il muscolo che avrai fra vent'anni."),
        m("Non serve un'ora di palestra: serve non stare fermi otto ore."),
        m("Le gambe sono il motore della circolazione. Accendilo ogni tanto."),
        m("Sciogli le spalle: le tieni alzate da così tanto che non te ne accorgi più."),
        m("La mandibola stretta è una decisione che stai prendendo senza saperlo. Lasciala andare."),
        m("Se ti accorgi di essere in apnea davanti allo schermo, non sei il solo. Respira."),
        m("Il corpo non distingue la fretta vera da quella immaginata. Tu sì."),
        m("Muoversi poco e spesso batte muoversi molto e raramente."),
        m("La postura perfetta non esiste. La postura successiva sì."),
        m("Il miglior esercizio è quello che fai davvero."),
        m("Chi si allena a pezzetti si allena comunque."),
        m("Un minuto di fatica adesso è un'ora di lucidità dopo."),
        m("Il cuore accelera per un minuto e ti ringrazia per un giorno."),
    ]

    // MARK: - Presenza

    static let presenza: [Phrase] = [
        m("Sei qui. È già più di quanto facessi un minuto fa."),
        m("Fai una cosa sola, e falla come se fosse l'unica."),
        m("L'attenzione è l'unica moneta che spendi senza accorgertene."),
        m("Dove va la tua attenzione, va la tua vita."),
        m("Non c'è nulla da raggiungere in questi novanta secondi. È il punto."),
        m("La fretta è un modo di essere altrove mentre sei qui."),
        m("Ascolta i rumori della stanza. Ci sono da un'ora e non li avevi sentiti."),
        m("Il presente è l'unico posto in cui puoi effettivamente fare qualcosa."),
        m("La mente che vaga non è rotta: è così che è fatta. Riportala, e basta."),
        m("Riportare l'attenzione mille volte è la pratica, non il fallimento della pratica."),
        m("Accorgersi di essersi distratti è già essere tornati."),
        m("Non giudicare il pensiero che arriva: guardalo passare, come un'auto dalla finestra."),
        m("Se stai pensando alla prossima cosa, non stai facendo questa."),
        m("Fermarsi non è perdere il ritmo: è sentire di che ritmo si trattava."),
        m("Il silenzio non è vuoto: è pieno di quello che avevi smesso di ascoltare."),
        m("Chiudi gli occhi per dieci secondi. Non succede niente, ed è la notizia buona."),
        m("Ogni volta che torni al respiro, la tua attenzione diventa un po' più tua."),
        m("La quiete non è assenza di rumore, è assenza di reazione al rumore."),
        m("Sentire i piedi appoggiati per terra è il modo più veloce di tornare nel corpo."),
        m("Non devi svuotare la mente. Devi solo smettere di rincorrerla."),
        m("Fai una pausa dalla pausa: non pensare nemmeno a come sta andando."),
        m("Lo schermo può aspettare novanta secondi. Ha aspettato per tutta la storia dell'universo."),
        m("Nessuna notifica è mai stata così urgente quanto sembrava."),
        m("Guarda una cosa sola per dieci secondi, senza nominarla."),
        m("Il tuo respiro non ha bisogno che tu lo controlli. Solo che tu lo noti."),
        m("Ogni pausa è un piccolo ritorno a casa."),
        m("La calma è una decisione che prendi con il corpo, non con la testa."),
        m("Le mani sono contratte sul mouse da un'ora. Aprile."),
        m("Non stai interrompendo il lavoro: stai interrompendo l'inerzia."),
        m("Anche la macchina più veloce si ferma per fare benzina."),
    ]

    // MARK: - Costanza e piccoli passi

    static let costanza: [Phrase] = [
        m("Meglio poco tutti i giorni che tanto una volta ogni tanto."),
        m("Le cose grandi si fanno con la noia delle cose piccole ripetute."),
        m("La costanza è più rara del talento, e vale di più."),
        m("Non contano le giornate perfette: contano quelle in cui non hai smesso."),
        m("Salta un giorno e non succede niente. Salta due e comincia una nuova abitudine."),
        m("Non è la forza a costruire un'abitudine, ma la ripetizione senza dramma."),
        m("La motivazione arriva dopo il primo movimento, non prima."),
        m("Comincia male, ma comincia."),
        m("Fai la versione più piccola possibile: quella si fa anche nei giorni storti."),
        m("Un'abitudine che sopravvive ai giorni brutti è l'unica che sopravvive."),
        m("Il progresso non si vede da un giorno all'altro, si vede da un anno all'altro."),
        m("Chi migliora dell'uno per cento al giorno non se ne accorge mai. Gli altri sì."),
        m("Non puntare al record: punta a non saltare."),
        m("La disciplina è ricordarsi cosa vuoi davvero quando vuoi anche altro."),
        m("Le scuse sono creative quanto le idee. Sceglile con lo stesso criterio."),
        m("Se aspetti di averne voglia, aspetterai per sempre."),
        m("Fare la cosa quando non hai voglia è la cosa."),
        m("Il momento perfetto è una scusa con l'orologio."),
        m("La regola dei due minuti: comincia, e vedi se ti fermi davvero dopo."),
        m("Ogni volta che scegli il piccolo sforzo, ti stai dicendo chi sei."),
        m("Il carattere è la somma delle volte in cui hai fatto la cosa noiosa."),
        m("Nessuno si allena una volta e diventa forte. Nessuno si allena sempre e resta debole."),
        m("La linea retta è più veloce, ma la linea che percorri davvero è meglio."),
        m("Non ti serve più tempo: ti serve smettere di aspettare il momento buono."),
        m("Un passo alla volta è comunque un passo più di zero."),
        m("Chi va piano non va lontano: ci va chi non si ferma."),
        m("La costanza batte l'intensità su ogni orizzonte più lungo di una settimana."),
        m("Le grandi decisioni si prendono una volta; le piccole, ogni giorno. Sono queste a decidere."),
        m("Ripetere non è tornare indietro: è scavare più a fondo nello stesso punto."),
        m("Fai oggi la cosa che il te di fra un anno ti ringrazierà di aver fatto."),
    ]

    // MARK: - Lavoro e attenzione

    static let lavoro: [Phrase] = [
        m("Il lavoro fatto bene ha bisogno di pause quanto di ore."),
        m("La stanchezza non si vede da dentro: si vede dagli errori."),
        m("Quando rileggi la stessa riga tre volte, non è la riga: sei tu."),
        m("Non stai risolvendo il problema: lo stai fissando. Sono due cose diverse."),
        m("Le soluzioni migliori arrivano quando ti alzi, non quando insisti."),
        m("Il cervello lavora anche mentre cammini. Anzi: soprattutto."),
        m("Chi non stacca mai non pensa mai: esegue e basta."),
        m("Fermarsi al momento giusto fa risparmiare l'ora che avresti perso a sbagliare."),
        m("L'urgenza è quasi sempre un'illusione condivisa."),
        m("Fare di più non è fare meglio, e spesso è il contrario."),
        m("La qualità dell'ultima ora dipende da come hai speso la penultima."),
        m("Concentrarsi non è tendersi: è togliere il resto."),
        m("Il lavoro profondo ha bisogno di silenzio prima che di tempo."),
        m("Una cosa alla volta non è lentezza: è l'unico modo in cui funziona la mente."),
        m("Il multitasking è cambiare compito in fretta e pagare il dazio ogni volta."),
        m("Se non sai qual è la cosa più importante, tutto sembra importante."),
        m("Finire una cosa vale più che cominciarne tre."),
        m("Il progetto che non finisci ti costa energia anche quando non ci pensi."),
        m("Il perfetto è il modo elegante di non consegnare."),
        m("Meglio fatto che perfetto, se il perfetto significa mai."),
        m("Ogni interruzione costa più del tempo che dura."),
        m("Proteggi le tue ore migliori: sono poche, e le stai regalando."),
        m("Non sei in ritardo: hai solo cominciato a contare dal punto sbagliato."),
        m("Fai la cosa difficile per prima, o la penserai tutto il giorno."),
        m("La lista lunga è un modo di rimandare che sembra organizzazione."),
        m("Se un'attività non ha un prossimo passo concreto, non è un'attività: è un desiderio."),
        m("Chiudere il computer è una decisione professionale, non una resa."),
        m("Il riposo fa parte del mestiere, come l'affilatura fa parte del tagliare."),
        m("Un'ora lucida vale tre ore stanche, e costa un terzo."),
        m("Nessuno ha mai fatto il lavoro della vita restando incollato alla sedia."),
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
        m("Il fiume non ha fretta e arriva comunque al mare."),
        m("Il bambù si piega nella tempesta, e per questo la supera."),
        m("Sii come l'acqua: prende la forma di ciò che la contiene e scava la roccia."),
        m("La goccia scava la pietra non per la forza, ma perché continua a cadere."),
        m("Chi corre dietro a due lepri non ne prende nessuna."),
        m("La calma è la forma più economica di forza."),
        m("Il vuoto nella stanza è ciò che la rende abitabile."),
        m("Fra lo stimolo e la risposta c'è uno spazio: quello spazio si allarga con l'esercizio."),
        m("Vuota la tazza, o non ci starà nulla di nuovo."),
        m("Non spingere il fiume: scorre da solo."),
        m("Il loto cresce nel fango e non se ne lamenta."),
        m("La luna si riflette in mille pozzanghere ed è sempre una."),
        m("Chi ha imparato ad aspettare non ha più bisogno di correre."),
        m("La strada la fa il camminare, non la mappa."),
        m("La perfezione non è quando non c'è più niente da aggiungere, ma quando non c'è più niente da togliere."),
        m("Il maestro e il principiante fanno lo stesso gesto: il maestro ci mette meno sforzo."),
        m("Quello che resisti, persiste."),
        m("Il pesce è l'ultimo a scoprire l'acqua."),
        m("Non puoi calmare le onde, ma puoi imparare a stare sulla tavola."),
    ]

    // MARK: - Tempo e impermanenza

    static let tempo: [Phrase] = [
        m("Il tempo passa comunque: l'unica scelta è come."),
        m("Un'ora persa non torna, ma la prossima non è ancora persa."),
        m("Il giorno è fatto di momenti come questo, non di quelli che immagini."),
        m("Nessuno ricorda le mail. Tutti ricordano come stavano."),
        m("Fra dieci anni, questa scadenza non esisterà. Il tuo corpo sì."),
        m("Rimandare non è guadagnare tempo: è pagarlo con gli interessi."),
        m("Tutto passa: anche questa fatica, anche questa noia, anche questa fretta."),
        m("Il momento in cui ti fermi è già diverso dal momento in cui hai deciso di fermarti."),
        m("La giornata non si allunga: si sceglie."),
        m("Non hai poco tempo: hai troppe cose che non contano."),
        m("La cosa che rimandi da tre settimane richiede venti minuti."),
        m("Ogni istante è nuovo. Anche questo, anche dopo mille pause uguali."),
        m("La vita è quello che succede mentre aspetti il momento buono."),
        m("Nessun giorno torna, e nessun giorno è l'ultimo finché non lo è."),
        m("Il futuro si costruisce con quello che fai adesso, non con quello che progetti adesso."),
        m("Il passato è finito, il futuro non è arrivato: resta un istante largo così, ed è tutto."),
        m("Le stagioni non si affrettano e arrivano tutte."),
        m("Anche la giornata più lunga finisce."),
        m("Ciò che è cominciato finirà: è una minaccia solo se te ne dimentichi."),
        m("Il tempo che dedichi a stare bene non è tolto al lavoro: è quello che lo rende possibile."),
    ]

    // MARK: - Sé, con misura

    static let se: [Phrase] = [
        m("Trattati come tratteresti qualcuno di cui ti importa."),
        m("Non devi meritarti il riposo: ti serve, e basta."),
        m("La severità con te stesso non è disciplina: spesso è solo paura."),
        m("Chiedersi troppo e non fare nulla sono la stessa malattia."),
        m("Il confronto è il modo più rapido di rovinarsi una giornata buona."),
        m("Guarda dove eri un anno fa, non dove è arrivato qualcun altro."),
        m("La versione di ieri di te aveva meno informazioni. Sii gentile con lei."),
        m("Sbagliare fa parte del metodo, non è un'interruzione del metodo."),
        m("Chi non sbaglia mai sta lavorando su cose troppo facili."),
        m("Un giorno storto non cancella un mese buono."),
        m("Perdonare a te stesso una giornata è ciò che ti permette di averne cento."),
        m("Non sei il tuo umore di adesso."),
        m("La stanchezza mente: dice che sei incapace, mentre stai solo cedendo."),
        m("Quando tutto sembra pesante, comincia dal corpo. La testa segue."),
        m("Se non riesci a pensare, non è un problema di pensiero: è un problema di sangue."),
        m("Fatti una domanda semplice: quando ho bevuto l'ultima volta?"),
        m("Meriti la stessa cura che daresti a uno strumento di lavoro costoso. Sei quello strumento."),
        m("Nessuno vince facendo a meno del sonno: si vince nonostante."),
        m("Il modo in cui passi le giornate è il modo in cui passi la vita."),
        m("Cambiare abitudine non è cambiare persona: è cambiare pratica."),
        m("La forza di volontà si esaurisce. L'ambiente no: cambia quello."),
        m("Se una cosa è troppo difficile da iniziare, è troppo grande. Riducila."),
        m("La prossima versione di te sta cominciando adesso, non lunedì."),
        m("Lunedì è un giorno come oggi, con meno vantaggio."),
        m("Puoi essere ambizioso e gentile con te stesso. È anzi l'unico modo per durare."),
        m("Il tuo corpo non è il nemico da domare: è la casa in cui vivrai per sempre."),
        m("Nessuna app ti renderà disciplinato: può solo ricordartelo. Il resto sei tu."),
        m("Fatti un favore che il te di stasera noterà."),
        m("Sii esigente sugli obiettivi e paziente sui tempi."),
        m("Non serve sentirsi motivati: serve avere deciso prima."),
    ]

    // MARK: - Natura e respiro largo

    static let natura: [Phrase] = [
        // La più bella che avessi in mente, e la ragione per cui questo pool esiste: circola
        // ovunque come di Lao Tzu, ma non compare in nessuna traduzione del Tao Te Ching e
        // nessuna fonte autorevole ne indica l'originale. Resta — è bella e c'entra — **senza il
        // nome che non le spetta**.
        m("La natura non ha fretta, eppure tutto si compie."),
        m("Il seme non discute con la stagione."),
        m("Nessun albero cresce solo verso l'alto: prima va giù."),
        m("Il vento non si vede, ma sposta le navi."),
        m("Il mare è calmo in superficie e vivo sotto: puoi essere entrambi."),
        m("La montagna si sale guardando i piedi, non la cima."),
        m("Ogni cima vista da vicino è una salita normale."),
        m("La radice cresce nel buio e regge tutto."),
        m("Il fiume conosce la strada perché la scava."),
        m("La marea torna sempre: non serve rincorrerla."),
        m("Il fuoco ha bisogno di spazio fra i legni, o si spegne."),
        m("L'inverno non è un errore dell'anno."),
        m("Anche il campo migliore riposa un anno su tre."),
        m("Il grano cresce di notte, quando nessuno guarda."),
        m("La pioggia non chiede il permesso e non serba rancore."),
        m("Nessun temporale è mai durato una settimana."),
        m("L'alba arriva senza che nessuno la solleciti."),
        m("Guarda il cielo: è lì tutto il giorno e non lo alzi mai."),
        m("Le nuvole passano, il cielo resta."),
        m("Il sole non insiste: si alza e basta."),
        m("Anche la pietra più dura è stata modellata dall'acqua più docile."),
    ]

    // MARK: - Cominciare, finire, ricominciare

    static let soglie: [Phrase] = [
        m("Cominciare è la parte difficile; il resto è già in discesa."),
        m("Il primo minuto costa quanto tutti gli altri messi insieme."),
        m("Metti le scarpe. Il resto viene da sé."),
        m("Non decidere se farlo: decidi solo di iniziare."),
        m("Nessuno si è mai pentito di aver fatto la pausa."),
        m("Il pentimento arriva sempre per le cose non fatte, quasi mai per quelle fatte male."),
        m("Finire una cosa piccola rimette in moto tutto il resto."),
        m("Chiudi ciò che hai aperto: le cose a metà pesano anche da chiuse."),
        m("Un lavoro finito male è comunque più utile di uno perfetto immaginato."),
        m("Ricominciare non è tornare al punto di partenza: è ripartire con la strada già vista."),
        m("Ogni volta che riprendi dopo un'interruzione, diventi un po' più bravo a riprendere."),
        m("La ripresa è una competenza, e si allena come le altre."),
        m("Il momento in cui vorresti smettere è di solito appena prima del punto interessante."),
        m("Chi comincia dieci cose non ne finisce nessuna; chi ne comincia una la finisce quasi sempre."),
        m("Il progetto giusto è quello a cui puoi tornare domani senza rileggere tutto."),
        m("Lascia il lavoro a metà di una frase: domani saprai dove riprendere."),
        m("Quello che non riesci a spiegare in una riga, non l'hai ancora capito."),
        m("Ogni fine è un pezzo di energia che torna disponibile."),
        m("Le cose importanti raramente sono urgenti, e per questo si rimandano per anni."),
        m("La prossima azione concreta è sempre più piccola di quanto pensi."),
    ]

    // MARK: - Relazione con lo schermo

    static let schermo: [Phrase] = [
        m("Lo schermo non ha una fine: sei tu a doverla mettere."),
        m("Una notifica è la richiesta di attenzione di qualcun altro, non la tua priorità."),
        m("Il feed è progettato per non finire mai. La tua giornata no."),
        m("Non stai riposando se stai guardando un altro schermo."),
        m("Il riposo vero somiglia alla noia, e per questo si evita."),
        m("La stanchezza da schermo non si toglie con più schermo."),
        m("Se hai aperto il telefono senza motivo, l'hai fatto per abitudine, non per bisogno."),
        m("Guarda un punto lontano: gli occhi ricordano com'era il mondo prima dei quaranta centimetri."),
        m("La finestra è lì da stamattina."),
        m("Una stanza silenziosa è uno strumento di lavoro, non un lusso."),
        m("La quantità di informazione che potresti leggere è infinita: la tua attenzione no."),
        m("Non devi rispondere subito. Quasi mai."),
        m("Ogni cosa che leggi occupa spazio in una stanza che è piccola."),
        m("Il rumore digitale si è preso il posto che una volta era della noia, e la noia serviva."),
        m("Le idee arrivano quando smetti di cercarle."),
    ]

    // MARK: - Con misura

    static let misura: [Phrase] = [
        m("Fai meno, ma fallo tutti i giorni."),
        m("Un carico che puoi sostenere per un anno vale più di uno che regge una settimana."),
        m("L'entusiasmo dei primi giorni è il peggior consigliere sul volume."),
        m("Chi parte troppo forte si ferma per infortunio, non per pigrizia."),
        m("La progressione lenta è l'unica che non torna indietro."),
        m("Se domani non puoi ripeterlo, oggi hai fatto troppo."),
        m("Il dolore che resta il giorno dopo non è un traguardo: è un conto."),
        m("Ascolta la spalla che tira: è un'informazione, non una debolezza."),
        m("Fermarsi quando fa male non è arrendersi, è saper contare."),
        m("Meglio una serie in meno oggi che tre settimane ferme dopo."),
        m("Il riposo è la parte dell'allenamento in cui succedono le cose."),
        m("Il muscolo cresce mentre dormi, non mentre spingi."),
        m("Non serve sudare per avere fatto qualcosa di utile."),
        m("La versione facile fatta è infinitamente meglio della versione dura saltata."),
        m("Se ti fa paura cominciare, dimezza. Poi dimezza ancora."),
    ]

    /// Tutto il pool contemplativo.
    public static let all: [Phrase] =
        corpo + presenza + costanza + lavoro + orientale + tempo + se + natura
        + soglie + schermo + misura
}
