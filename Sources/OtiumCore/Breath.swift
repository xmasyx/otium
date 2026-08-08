import Foundation

/// **La modalità Zen: in ufficio non ci si allena, ma si respira.**
///
/// Chiesta dal principale il 2026-08-08 con la ragione dentro la richiesta: *«in ufficio magari non
/// ci si può allenare»*. La pausa resta, il blocco resta, la frase resta; cambia solo il lavoro
/// richiesto, che da contrazione muscolare diventa respiro guidato.
///
/// **Quello che questa modalità NON fa, ed è scritto qui perché non si perda.** Respirare non
/// contrae niente, quindi il lavoro metabolico su cui è costruita l'app — glicemia, lipoproteina
/// lipasi, cattura del glucosio — in Zen mode non c'è. Le frasi dell'app lo dicono già a chiare
/// lettere («è la contrazione muscolare a fare il lavoro, non la posizione»). Questa è la pausa che
/// puoi fare in open space davanti a dei colleghi, non il pareggio di quella vera.
///
/// **I tre protocolli e da dove vengono** — le fonti stanno in `Evidence`, con i link:
/// - `sospiro` è il vincitore dell'unico confronto testa a testa (Balban 2023): 5 minuti al giorno
///   per 28 giorni, e batte box breathing, iperventilazione ciclica **e** la meditazione mindfulness
///   su umore e frequenza respiratoria. È il default per questo, non per gusto.
/// - `risonanza` è il respiro lento a 6 al minuto, la frequenza di risonanza che massimizza la
///   variabilità cardiaca a mediazione vagale (Laborde 2022, 223 studi).
/// - `quadrato` è il box breathing, uno degli altri bracci di Balban: funziona, meno del sospiro.
public enum BreathProtocol: String, Codable, CaseIterable, Sendable {
    case sospiro
    case risonanza
    case quadrato

    /// Un passo del ciclo, con la sua durata in secondi.
    public struct Step: Equatable, Sendable {
        public enum Action: String, Equatable, Sendable {
            case inspira
            /// La seconda inspirazione corta del sospiro ciclico, sopra la prima. È l'ingrediente
            /// che distingue il protocollo vincente dagli altri due, quindi ha un caso suo invece
            /// di essere una seconda `inspira` di seguito: a schermo va detta in modo diverso, o
            /// sembra un errore di ripetizione.
            case ancora
            case trattieni
            case espira
            /// **La pausa a polmoni vuoti, fra un'espirazione e l'inspirazione dopo.**
            ///
            /// Chiesta dal principale il 2026-08-08 con l'istinto giusto e una motivazione che va
            /// corretta: *«non dovrebbe esserci una pausa, anche se breve, tra espirazione ed
            /// inspirazione?»*. **Fisiologicamente no**, o meglio non serve: Laborde e colleghi
            /// (Sustainability, 2021) hanno provato proprio questo, sei al minuto con e senza pause
            /// da 0,4 s fra le fasi, e le pause **non** aggiungono attività vagale. Quello che la
            /// aggiunge è l'espirazione lunga, che qui c'è già.
            ///
            /// La pausa resta lo stesso, e per un motivo diverso da quello fisiologico: **una guida
            /// che salta dall'espirazione all'inspirazione senza un istante di stacco si segue
            /// male**. Il respiro spontaneo quella pausa ce l'ha, e senza, l'animazione chiede di
            /// invertire il verso nello stesso fotogramma in cui hai finito di svuotare. È una
            /// scelta di ergonomia dichiarata, non un numero preso da uno studio.
            case pausa
        }

        public let action: Action
        public let seconds: Double

        public init(_ action: Action, _ seconds: Double) {
            self.action = action
            self.seconds = max(0.5, seconds)
        }

        public var localizedName: String {
            switch action {
            case .inspira:   return L.t("Inspira", "Breathe in")
            // **Resta «Ancora un po' d'aria», per sua decisione del 2026-08-08.** Aveva chiesto
            // cosa significasse e io l'avevo cambiata in «Un altro sorso»: la domanda però era sul
            // gesto, non sulla parola, e saputo il gesto la parola gli andava bene. Il gesto, per
            // chi legge questo file dopo, è quello che il paper descrive senza ambiguità: *«once
            // their lungs were expanded, to inhale again once more to maximally fill their lungs»*,
            // cioè un **secondo atto sopra polmoni già pieni**, non il seguito del primo. Ed è
            // esattamente ciò che l'alone disegna, con il gradino da 82% a 100%.
            case .ancora:    return L.t("Ancora un po' d'aria", "A little more air")
            case .trattieni: return L.t("Trattieni", "Hold")
            case .espira:    return L.t("Espira, lentamente", "Breathe out, slowly")
            // Non «trattieni»: lì i polmoni sono pieni e stai facendo forza per tenerli così, qui
            // sono vuoti e non stai facendo niente. Sono due gesti diversi e vogliono due parole.
            case .pausa:     return L.t("Aspetta", "Wait")
            }
        }
    }

    /// **I secondi dei passi sono un'implementazione, non un dato degli studi, e va detto.**
    ///
    /// Gli studi fissano due cose: la *forma* del protocollo (dove sta l'enfasi, quanti tempi) e la
    /// *dose* (cinque minuti al giorno). I secondi esatti di ogni fase, per il sospiro ciclico, il
    /// paper non li prescrive: descrive doppia inspirazione nasale ed espirazione lunga dalla bocca.
    /// Qui sono scelti perché il ciclo resti sotto i dieci secondi e chiunque riesca a seguirlo, e
    /// se un giorno uscisse una misura vera si cambiano **solo qui**.
    ///
    /// La risonanza è l'eccezione: 5 dentro e 5 fuori **sono** il parametro, perché sei respiri al
    /// minuto è esattamente ciò che la letteratura misura. Quel numero non si tocca per estetica.
    /// **La pausa a vuoto sta DENTRO i dieci secondi, non sopra.**
    ///
    /// Per la risonanza è un vincolo, non una preferenza: sei respiri al minuto vuol dire un ciclo
    /// da dieci secondi esatti, e appiccicare mezzo secondo in fondo lo porterebbe a 5,7 al minuto,
    /// cioè fuori dal parametro che tutta la letteratura misura. Quindi l'inspirazione scende a 4,5
    /// e la pausa si ricava lì, che è anche il verso giusto: lo stesso studio che dice che le pause
    /// non aggiungono niente dice che l'espirazione più lunga **sì**, e così l'espirazione resta la
    /// fase più lunga delle due.
    ///
    /// Anche il respiro ciclico esce a dieci secondi tondi, e non è una simmetria cercata: era già
    /// a nove, e un secondo di stacco a polmoni vuoti è il minimo che si percepisca.
    public var cycle: [Step] {
        switch self {
        case .sospiro:
            return [Step(.inspira, 2), Step(.ancora, 1), Step(.espira, 6), Step(.pausa, 1)]
        case .risonanza:
            return [Step(.inspira, 4.5), Step(.espira, 5), Step(.pausa, 0.5)]
        case .quadrato:
            // Il quadrato la pausa ce l'ha già, e si chiama trattenimento: dopo l'espirazione
            // trattieni a vuoto per quattro secondi, che è la stessa cosa in grande.
            return [Step(.inspira, 4), Step(.trattieni, 4), Step(.espira, 4), Step(.trattieni, 4)]
        }
    }

    public var cycleSeconds: Double { cycle.reduce(0) { $0 + $1.seconds } }

    /// Quanti respiri al minuto, arrotondati: è il numero che dice cosa stai facendo davvero.
    public var breathsPerMinute: Int { Int((60 / cycleSeconds).rounded()) }

    public var localizedName: String {
        switch self {
        case .sospiro:   return L.t("respiro ciclico", "cyclic sighing")
        case .risonanza: return L.t("respiro a sei al minuto", "six breaths a minute")
        case .quadrato:  return L.t("respiro quadrato", "box breathing")
        }
    }

    /// Cosa fa, e su cosa si appoggia. Una riga, come le spiegazioni di `CircuitMode`.
    public var explanation: String {
        switch self {
        case .sospiro:
            return L.t("Due inspirazioni dal naso, la seconda corta sopra la prima, e una lunga espirazione dalla bocca. È l'unico protocollo che in un confronto diretto ha battuto anche la meditazione, su umore e frequenza respiratoria.",
                       "Two inhales through the nose, the second a short one on top of the first, then a long exhale through the mouth. It is the only protocol that beat even meditation head to head, on mood and respiratory rate.")
        case .risonanza:
            return L.t("Cinque secondi dentro e cinque fuori, cioè sei respiri al minuto. È la frequenza a cui il cuore e il respiro entrano in fase, e la variabilità cardiaca sale di più.",
                       "Five seconds in and five out, that is six breaths a minute. It is the rate at which heart and breath fall into phase, and heart rate variability rises the most.")
        case .quadrato:
            return L.t("Quattro tempi uguali: dentro, trattieni, fuori, trattieni. Il più facile da ricordare, e infatti è il più diffuso. Funziona, meno del sospiro.",
                       "Four equal counts: in, hold, out, hold. The easiest to remember, which is why it is everywhere. It works, less well than the sigh.")
        }
    }

    /// Con quale studio risponde alla domanda «da dove viene questo numero».
    public var studyID: String {
        switch self {
        case .sospiro, .quadrato: return "balban-2023"
        case .risonanza:          return "laborde-2022"
        }
    }
}

/// Il respiro guidato di una pausa: **un valore puro, come `Hold`**.
///
/// Stessa forma e per la stessa ragione: nessun timer, nessuna vista, nessun suono. Si passa `now`
/// e si chiede in che punto del ciclo sei. Cinque minuti di respiro si provano in un millesimo, e i
/// casi che nella vita capitano una volta al mese — l'ultimo ciclo, il confine esatto fra due
/// passi — qui capitano a ogni corsa.
///
/// **Il tempo si legge dall'orologio, non si accumula**, per la stessa ragione scritta in `Hold`:
/// un contatore che scala a ogni battito perde decimi, e qui i decimi si sommano su decine di cicli.
public struct Breath: Equatable, Sendable {

    /// I secondi fra «Pronto» e il primo respiro guidato: il tempo di sistemarsi sulla sedia.
    /// Tre e non cinque come nelle tenute — non devi scendere a terra, devi solo smettere di
    /// digitare.
    public static let prepareSeconds: Double = 3

    public let protocollo: BreathProtocol
    /// Quanto dura il respiro guidato, senza la preparazione.
    public let total: Double
    public let startedAt: Date

    public init(protocollo: BreathProtocol, total: Double, startedAt: Date) {
        self.protocollo = protocollo
        self.total = max(1, total)
        self.startedAt = startedAt
    }

    /// **Il respiro finisce a fine respiro**, non a fine cronometro.
    ///
    /// Novanta secondi diviso un ciclo da dieci fanno nove tondi, ma con i tre secondi per
    /// sistemarsi il conto usciva a 8,x e l'ultimo respiro veniva tagliato a metà espirazione.
    /// Segnalato da lui il 2026-08-08: *«l'esercizio si interrompe all'improvviso»*. Qui i secondi
    /// richiesti scendono al multiplo intero di ciclo più vicino verso il basso, mai sotto uno.
    ///
    /// **Sta qui e non in `init` perché il motore e la vista devono ottenere lo stesso numero.**
    /// Se arrotondasse `Breath` per conto suo, il cancello di `markBreathDone` scatterebbe più
    /// tardi della fine dell'animazione e resteresti fermo davanti a un pulsante spento.
    public static func wholeCycles(_ seconds: Double, of protocollo: BreathProtocol) -> Double {
        let ciclo = protocollo.cycleSeconds
        return max(ciclo, (seconds / ciclo).rounded(.down) * ciclo)
    }

    public enum Phase: Equatable, Sendable {
        /// Ti stai sistemando. `secondsLeft` scende da 3 a 1.
        case preparing(secondsLeft: Int)
        /// Stai respirando. `step` è il passo in corso, `secondsLeft` quanto manca a quel passo,
        /// `progress` va da 0 a 1 **dentro il passo** — serve al disegno che si espande e si
        /// contrae, che senza una frazione continua andrebbe a scatti di un secondo.
        ///
        /// **`stepIndex` è la posizione del passo nel ciclo, e non è un doppione di `step`.** Nel
        /// respiro quadrato i due `trattieni` sono lo stesso passo e vanno disegnati su **due lati
        /// diversi** del quadrato: senza l'indice, l'animazione del box breathing non si può fare,
        /// perché la vista non ha modo di sapere se sta trattenendo dopo l'inspirazione o dopo
        /// l'espirazione.
        case breathing(step: BreathProtocol.Step, stepIndex: Int, secondsLeft: Int,
                       progress: Double, cycle: Int)
        case done
    }

    /// I momenti che meritano un suono. **Sono due soli, ed è una scelta.**
    ///
    /// La tentazione è suonare a ogni cambio di passo, che in un sospiro ciclico vuol dire un suono
    /// ogni due o tre secondi per cinque minuti: cento suoni. Sarebbe la cosa più fastidiosa mai
    /// messa in questa app, e in ufficio — cioè esattamente dove questa modalità serve — anche la
    /// più imbarazzante. Il ritmo lo dà l'occhio, il suono dice solo quando comincia e quando
    /// finisce.
    public enum Cue: String, Equatable, Sendable, CaseIterable {
        case start
        case end
    }

    public var breathStart: Date { startedAt.addingTimeInterval(Self.prepareSeconds) }
    public var endsAt: Date { breathStart.addingTimeInterval(total) }

    /// Quanti cicli completi entrano nel tempo previsto. È il numero che si mostra prima di
    /// cominciare: «venti respiri» dice cosa ti aspetta meglio di «cinque minuti».
    public var plannedCycles: Int {
        max(1, Int(total / protocollo.cycleSeconds))
    }

    public func phase(at now: Date) -> Phase {
        if now >= endsAt { return .done }
        if now < breathStart {
            // `ceil` e non `round`, stessa ragione di `Hold`: a 2,2 secondi dalla fine il numero da
            // mostrare è 3, perché il terzo secondo non è ancora passato.
            return .preparing(secondsLeft: max(1, Int(ceil(breathStart.timeIntervalSince(now)))))
        }

        let elapsed = now.timeIntervalSince(breathStart)
        let cycle = protocollo.cycle
        let cycleSeconds = protocollo.cycleSeconds
        let cycleIndex = Int(elapsed / cycleSeconds)
        var offset = elapsed - Double(cycleIndex) * cycleSeconds

        for (indice, step) in cycle.enumerated() {
            if offset < step.seconds {
                let left = step.seconds - offset
                return .breathing(
                    step: step,
                    stepIndex: indice,
                    secondsLeft: max(1, Int(ceil(left))),
                    progress: min(1, max(0, offset / step.seconds)),
                    cycle: cycleIndex + 1
                )
            }
            offset -= step.seconds
        }

        // Irraggiungibile finché `cycleSeconds` è la somma dei passi, e lo è per costruzione. Ma un
        // ramo muto qui sarebbe indistinguibile da un ramo mai eseguito: si ricade sull'ultimo
        // passo invece di restituire uno stato che la vista non saprebbe disegnare.
        let ultimo = cycle[cycle.count - 1]
        return .breathing(step: ultimo, stepIndex: cycle.count - 1, secondsLeft: 1,
                          progress: 1, cycle: cycleIndex + 1)
    }

    /// Quanti secondi mancano alla fine di tutto: è il numero grande della schermata.
    public func secondsLeft(at now: Date) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    /// I suoni attraversati fra due istanti. Estremo sinistro escluso, destro incluso: chiamandola
    /// a ogni battito con `(precedente, adesso)` ogni suono esce **una volta sola**.
    public func cues(from: Date, to: Date) -> [Cue] {
        guard to > from else { return [] }
        var out: [Cue] = []
        func crossed(_ instant: Date) -> Bool { instant > from && instant <= to }
        if crossed(breathStart) { out.append(.start) }
        if crossed(endsAt) { out.append(.end) }
        return out
    }
}
