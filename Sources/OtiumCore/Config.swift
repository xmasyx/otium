import Foundation

public enum BreakKind: String, Codable, Equatable, Sendable {
    /// 90 secondi: un esercizio, e si torna al lavoro.
    case micro
    /// 5 minuti: sessione intensa e poi lontano dallo schermo.
    case long
}

/// La cadenza — i numeri che vengono dagli studi, non dal gusto.
public struct Cadence: Codable, Equatable, Sendable {
    /// Secondi di **tempo attivo** fra un break e l'altro. Duran 2023 → 30 minuti.
    ///
    /// **I limiti stanno sul campo, non solo nell'`init`.** È la stessa lezione già pagata su
    /// `Settings`: un tetto scritto nel costruttore si scavalca assegnando la proprietà dopo, e
    /// un test l'ha fatto al primo tentativo — `cadence.warningSeconds = 300` su un intervallo da
    /// 60 secondi, e la pausa scattava al primo secondo di lavoro.
    public var intervalSeconds: Double {
        didSet {
            intervalSeconds = max(1, intervalSeconds)
            warningSeconds = min(warningSeconds, intervalSeconds / 2)
        }
    }
    /// Durata del micro-snack. Albulescu 2022 → ben dentro i 10 minuti.
    public var microDurationSeconds: Double
    /// Durata della pausa piena. Galinsky 2000 → 5 minuti.
    public var longDurationSeconds: Double
    /// Ogni quanti break ne arriva uno pieno. 3 → micro, micro, pieno.
    public var longEveryNBreaks: Int
    /// Oltre questa inattività l'orologio si ferma e la pausa diventa "naturale".
    ///
    /// **90 e non 60 dal 2026-08-05**, per mia scelta: *«non dovrebbe essere 60
    /// secondi ma 90 come una vera pausa naturale»*. Un minuto senza toccare niente è un
    /// paragrafo letto, non una pausa, e accreditarlo regalava riposo mai fatto. Il numero da
    /// solo non basta e non era pensato per bastare: le pause fantasma misurate quel giorno
    /// erano da 14 e 18 minuti, e la rete per quelle è `PresenceKind.terminal`.
    public var idleThresholdSeconds: Double
    /// Preavviso prima che lo schermo si copra: serve a chiudere quello che stai facendo.
    ///
    /// Non può superare metà intervallo: da quando il preavviso sta **dentro** l'intervallo, uno
    /// più lungo dell'intervallo stesso non sarebbe un avviso, sarebbe l'attesa.
    public var warningSeconds: Double {
        didSet { warningSeconds = min(max(0, warningSeconds), max(1, intervalSeconds) / 2) }
    }
    /// Quanto dura un rinvio.
    public var postponeSeconds: Double
    /// Quanti rinvii per break. Stretchly ne concede uno: è la scelta giusta.
    public var postponesAllowed: Int

    public init(
        intervalSeconds: Double,
        microDurationSeconds: Double,
        longDurationSeconds: Double,
        longEveryNBreaks: Int,
        idleThresholdSeconds: Double,
        warningSeconds: Double,
        postponeSeconds: Double,
        postponesAllowed: Int
    ) {
        self.intervalSeconds = intervalSeconds
        self.microDurationSeconds = microDurationSeconds
        self.longDurationSeconds = longDurationSeconds
        self.longEveryNBreaks = max(1, longEveryNBreaks)
        self.idleThresholdSeconds = idleThresholdSeconds
        // **Il preavviso non può mangiarsi l'intervallo.** Da quando sta *dentro* i 30 minuti
        // (2026-07-31), un preavviso più lungo dell'intervallo farebbe scattare la pausa al primo
        // secondo di lavoro — e `settings.json` è un file di testo, quindi `warningSeconds: 300`
        // con intervallo a 60 è scrivibile a mano. Il tetto è metà intervallo: sopra, il
        // preavviso non sarebbe più un avviso, sarebbe l'attesa. Trovato da un test scritto per
        // il caso limite, non dall'uso.
        self.warningSeconds = min(max(0, warningSeconds), max(1, intervalSeconds) / 2)
        self.postponeSeconds = postponeSeconds
        self.postponesAllowed = max(0, postponesAllowed)
    }

    public func duration(for kind: BreakKind) -> Double {
        kind == .long ? longDurationSeconds : microDurationSeconds
    }

    /// **Opzione A** — la cadenza scelta il 2026-07-26.
    /// Micro-snack di 90 s ogni 30 minuti di lavoro attivo; ogni terzo break è pieno (≈90 min).
    ///
    /// **Due rinvii dal 2026-08-12**, per mia decisione: *«una pausa breve ogni 30
    /// minuti, una piena ogni 90, che è consigliata, però due rinvii di default»*. Era uno, ed era
    /// l'unico campo che lo teneva fuori dai preset: usava due rinvii da settimane e la finestra
    /// gli rispondeva «personalizzata» per un numero che non viene da nessuno studio, a differenza
    /// dei 30 e dei 90 minuti. Il prezzo, dichiarato: chi ne teneva uno adesso legge
    /// «personalizzata», che è vero e si annulla con un clic sul preset.
    public static let optionA = Cadence(
        intervalSeconds: 30 * 60,
        microDurationSeconds: 90,
        longDurationSeconds: 5 * 60,
        longEveryNBreaks: 3,
        idleThresholdSeconds: 90,
        warningSeconds: 60,
        postponeSeconds: 120,
        postponesAllowed: 2
    )

    /// **Opzione B** — deep work: una sola pausa da 5 minuti ogni 50 di lavoro attivo.
    public static let optionB = Cadence(
        intervalSeconds: 50 * 60,
        microDurationSeconds: 5 * 60,
        longDurationSeconds: 5 * 60,
        longEveryNBreaks: 1,
        idleThresholdSeconds: 90,
        warningSeconds: 60,
        postponeSeconds: 120,
        postponesAllowed: 1
    )

    /// **Opzione C** — protocollo Duran puro: 5 minuti ogni 30. Il più efficace, il più invasivo.
    public static let optionC = Cadence(
        intervalSeconds: 30 * 60,
        microDurationSeconds: 5 * 60,
        longDurationSeconds: 5 * 60,
        longEveryNBreaks: 1,
        idleThresholdSeconds: 90,
        warningSeconds: 60,
        postponeSeconds: 120,
        postponesAllowed: 1
    )
}

/// Cosa succede nelle pause piene: **una scelta sola, tre valori**.
///
/// Erano due interruttori — «proponi il microcircuito» e «comincia già in circuito» — e due
/// interruttori dipendenti producono stati che non esistono: spento il primo, il secondo comanda
/// una cosa che non c'è, e l'interfaccia doveva disabilitarlo per difendersi da sé stessa. Ci
/// ho sbattuto contro il 2026-07-31, e il modello giusto sta in una riga:
/// *«io non voglio una proposta di microcircuito, io voglio cominciare con il microcircuito e la
/// proposta di fare esercizio singolo»*. Sono tre alternative su un asse solo, e su un asse solo
/// non si può scegliere l'impossibile.
public enum CircuitMode: String, Codable, CaseIterable, Sendable {
    /// Solo l'esercizio del turno. Il circuito non viene nemmeno costruito.
    case singolo
    /// Si parte dall'esercizio del turno, il giro completo è lì se lo vuoi.
    case proposto
    /// Si parte dal giro completo, l'esercizio singolo è lì se non ce la fai.
    case subito

    /// **Le tre voci si leggono in fila, quindi devono essere corte.** Erano frasi — «solo
    /// l'esercizio del turno», «comincia in circuito» — e in un menu a tendina una frase è
    /// rumore: il verbo lo dice già il contesto («nelle pause piene»), e quello che cambia fra
    /// le tre è una parola sola. Accorciate su mia indicazione il 2026-07-31. Il
    /// *cosa succede* sta nella riga sotto, che cambia con la voce scelta.
    public var localizedName: String {
        switch self {
        case .singolo:  return L.t("singolo esercizio", "single exercise")
        case .proposto: return L.t("proponi il circuito", "offer the circuit")
        case .subito:   return L.t("circuito", "circuit")
        }
    }

    public var explanation: String {
        switch self {
        case .singolo:
            return L.t("Le pause piene hanno un esercizio solo, come le micro-pause: cambia la durata, non il lavoro.",
                       "Full breaks have a single exercise, like micro-breaks: what changes is the length, not the work.")
        case .proposto:
            return L.t("La pausa piena si apre sull'esercizio del turno, con il giro completo a un clic. Le stazioni valgono i tre quarti delle ripetizioni, o quattro esercizi non stanno in cinque minuti.",
                       "The full break opens on the exercise of the turn, with the whole circuit one click away. Stations count for three quarters of the reps, or four exercises do not fit in five minutes.")
        case .subito:
            return L.t("La pausa piena si apre già sul giro completo — una stazione per famiglia, esplosivo compreso — e dentro la pausa resta «basta così, torno all'esercizio singolo».",
                       "The full break opens straight into the whole circuit — one station per family, explosive included — and inside the break «that's enough, back to the single exercise» stays there.")
        }
    }

    /// Il circuito va costruito? In `singolo` no: preparare quattro stazioni che nessuno vedrà è
    /// lavoro buttato, e un piano che le porta è un piano che mente su cosa offre.
    public var buildsCircuit: Bool { self != .singolo }
    /// Il piano nasce già dentro il giro?
    public var startsActive: Bool { self == .subito }
}

public struct Settings: Codable, Equatable, Sendable {
    public var cadence: Cadence
    /// Data della prima esecuzione: da qui parte la rampa.
    public var startDate: Date
    /// **I limiti stanno sul campo, non nell'`init`.**
    ///
    /// Vivevano solo nel costruttore, e questo lasciava due porte aperte: assegnare la proprietà
    /// dopo, e **decodificare il file**. `settings.json` è un file di testo nella cartella
    /// dell'utente: con `rampStartFactor: -5` scritto a mano le ripetizioni diventavano negative,
    /// e con `exercisePool: []` la rotazione restava senza esercizi. Trovato dall'audit del
    /// 2026-07-29 con impostazioni assurde, non con impostazioni sbagliate.
    public var rampWeeks: Int { didSet { rampWeeks = max(1, rampWeeks) } }
    public var rampStartFactor: Double {
        didSet { rampStartFactor = min(1.0, max(0.1, rampStartFactor)) }
    }
    public var exercisePool: [ExerciseKind] {
        didSet { if exercisePool.isEmpty { exercisePool = [.squat] } }
    }
    public var vigorousPool: [ExerciseKind] {
        didSet { if vigorousPool.isEmpty { vigorousPool = [.jumpingJack] } }
    }
    /// Bersaglio giornaliero di sessioni intense — Stamatakis 2022 → 3.
    public var vigorousDailyTarget: Int
    /// La frase da digitare per esteso per saltare un break. Attrito, non impossibilità.
    public var escapePhrase: String
    /// Da quale versione della spinta si parte. `nil` = **automatica**, cioè quella che l'app
    /// propone in base al sesso dichiarato (`SexCalibration.regression`).
    ///
    /// Esiste perché la statistica sceglie un punto di partenza, non una persona: una donna che
    /// fa già i push-up a terra non deve ricominciare dalle ginocchia, e un uomo che riprende
    /// dopo un infortunio ha lo stesso diritto di partire dal muro. La scelta è dichiarata al
    /// primo avvio e si cambia dalle preferenze.
    public var pushVariant: ExerciseKind?
    /// Le ripetizioni continuano a crescere **oltre** il 100%. Spento di serie: il 100% è il
    /// programma, la crescita è allenamento in più, e si accende rispondendo alla domanda che
    /// l'app fa dopo una settimana passata al 100%.
    public var progressBeyondFull: Bool
    /// Quando sei arrivato al 100%. `nil` quando non ci sei ancora, o quando ci sei arrivato con
    /// la salita e allora si ricava dalla data d'inizio.
    public var fullReachedAt: Date?
    /// La domanda sulla crescita è già stata fatta. Una volta sola, come tutte le altre.
    public var growthAnswered: Bool
    /// Dopo quante settimane di uso l'app **chiede** se vuoi già passare al numero pieno.
    ///
    /// La partenza graduale esiste perché iniziare a quindici squat quando sei fermo da mesi è il
    /// modo di smettere in tre giorni. Ma quattro settimane sono lunghe per chi è già allenato, e
    /// un'app che decide da sola quanto sei in forma sbaglia in una delle due direzioni. Dopo due
    /// settimana lo chiede una volta sola: **una domanda, non una tacca in più sul cursore**.
/// Una e non due: a due settimane si è già all'85% e il salto offerto sarebbe del 15%,
/// troppo poco per meritarsi una finestra. A una si è al 70%, e la domanda ha un senso.
    public var fullPaceOfferWeeks: Int
    /// La domanda è già stata fatta. Una volta sola: un'app che ripropone la stessa scelta ogni
    /// settimana non sta chiedendo, sta insistendo.
    public var fullPaceAnswered: Bool
    /// Il sesso biologico, **solo** per il punto di partenza delle ripetizioni (vedi
    /// `SexCalibration`). `nil` finché non l'hai scelto: è uno dei due inneschi dell'onboarding.
    public var sex: Sex?
    /// La lingua dell'interfaccia. `nil` finché non l'hai scelta: l'altro innesco dell'onboarding.
    public var language: AppLanguage?
    /// Se un microfono è in uso (call), il break si rimanda invece di piombare addosso.
    public var deferWhenMicrophoneActive: Bool
    /// Offri le varianti dentro la pausa (diamond, archer, dip su sedia…). Restano opzionali:
    /// spegnendolo, la pausa propone solo l'esercizio che tocca alla rotazione.
    public var offerVariants: Bool
    /// Proponi il microcircuito nelle pause piene: una stazione per famiglia — gambe, spinta,
    /// addome, esplosivo. **Proposta, non imposizione**: dentro la pausa scegli tu se fare il
    /// giro completo o il solo esercizio del turno.
    public var circuitMode: CircuitMode
    /// Otium riparte da sola a ogni accensione. Diventa `false` quando l'avvio automatico viene
    /// rimosso dalle preferenze, così l'app non se lo rimette da sola al riavvio successivo —
    /// una preferenza che si riscrive addosso all'utente è un difetto, non una comodità.
    public var autoStartAtLogin: Bool
    /// Conta come tempo sedentario anche quando non tocchi niente ma sei lì: video in
    /// riproduzione, documento aperto davanti. Spegnendolo, guardare un film torna a valere
    /// come una pausa — che è comodo e sbagliato.
    public var detectQuietPresence: Bool
    /// Quante volte di fila può rimandare da solo prima di arrendersi e bloccare comunque.
    public var maxAutoDefers: Int
    /// Quanto dura un rinvio automatico per call.
    public var autoDeferSeconds: Double
    /// **Modalità Zen: le pause chiedono un respiro guidato invece di un esercizio.**
    ///
    /// Spenta di serie, e deve restarlo: l'app esiste per il lavoro metabolico, e Zen è il ripiego
    /// per quando quel lavoro non è socialmente possibile. Accenderla da sola sarebbe come decidere
    /// al posto tuo che il tuo ufficio è un open space.
    public var zenMode: Bool
    /// **Il respiro delle micro-pause**, di serie il respiro ciclico.
    ///
    /// Non è la stessa scelta della pausa piena, e la ragione è nei numeri: in 87 secondi utili
    /// entrano otto respiri ciclici e cinque quadrati, e il respiro ciclico agisce **respiro per
    /// respiro** con la sua espirazione lunga, mentre la risonanza vive di aggancio fra due ritmi e
    /// otto cicli sono pochi per farlo. Da dire com'è: a novanta secondi non è validato nessuno dei
    /// tre, quindi questo è un innesco e non una dose.
    public var zenProtocolShort: BreathProtocol
    /// **Il respiro delle pause piene**, di serie la risonanza a sei al minuto.
    ///
    /// **Tolto e rimesso il 2026-08-11.** Era stato tolto, e poi
    /// ho ricostruito da me il motivo per cui stava qui: la prova vagale di Laborde è misurata su
    /// sessioni da cinque minuti in su, cioè esattamente la durata della pausa piena, e nessun
    /// altro protocollo ha quella prova a quella durata. Il nome però resta quello nuovo, perché
    /// «respiro a sei al minuto» costringeva a una divisione per capire cosa fare.
    public var zenProtocolLong: BreathProtocol
    /// **Quanto dura il respiro guidato dentro la pausa**, e non quanto dura la pausa.
    ///
    /// Prima riempiva tutto, quindi cinque minuti su una pausa piena, e l'ho visto
    /// il 2026-08-08 che è troppo. Ha ragione, e gli studi non lo contraddicono: Laborde e colleghi
    /// hanno confrontato sessioni singole da 5, 10, 15 e 20 minuti a sei respiri al minuto e **non
    /// hanno trovato differenze** nell'attività vagale fra le durate; la meta-analisi di Fincham non
    /// trova alcuna correlazione fra durata e dimensione dell'effetto. Il che significa due cose
    /// opposte da tenere insieme: **più lungo non è meglio**, e **sotto i cinque minuti nessuno ha
    /// misurato**, perché cinque è il più corto mai provato.
    ///
    /// Di serie novanta secondi, che è una scelta di comodità dichiarata e non un numero preso da
    /// uno studio. Chi vuole la dose studiata la rimette da qui. Il resto della pausa non sparisce:
    /// diventa riposo con la frase, come nelle pause con esercizio.
    public var zenBreathSeconds: Double
    /// La livrea. Di serie Alloro: verde notte e salvia, non nero e arancione — quello è il
    /// vestito di Sveglia e Timer di Apple.
    public var theme: ThemeName
    /// Il suono del preavviso. Nome di un suono di sistema macOS; stringa vuota = nessun suono.
    public var notificationSound: String
    /// Il suono che chiude una **tenuta** — plank, plank laterale, hollow hold.
    ///
    /// Separato dal preavviso di proposito, ed è la richiesta che l'ha fatto nascere: *«un suono
    /// quando è finito, un suono diverso però»*. Mentre sei sotto sforzo non guardi lo schermo,
    /// quindi la fine te la dice l'orecchio, e un orecchio distingue due suoni solo se sono due.
    public var holdEndSound: String
    /// **Quanto forte suonano**, da 0 (muto) a 1, di serie pieno.
    ///
    /// Sua richiesta, 2026-08-16: *«il livello di volume della notifica, che non dipenda unicamente
    /// dal volume generale del Mac»*. Prima ogni suono usciva al volume di sistema e basta, quindi
    /// alzare la musica alzava anche Otium.
    ///
    /// **È una quota del volume del Mac, non un volume assoluto**, e la differenza va detta a chi
    /// lo sposta: si può stare più piano di quello che stai ascoltando, non più forte. Col Mac muto
    /// non si sente niente comunque, e salire sopra il pieno vorrebbe dire amplificare un campione
    /// già al massimo, cioè distorcerlo.
    public var soundVolume: Double
    /// L'unico posto dove il volume viene limitato: l'init, la decodifica e chi suona chiamano
    /// **questa**, invece di ricopiarsi un `min`/`max` a testa e divergere in silenzio.
    public static func clampSoundVolume(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(1, max(0, value))
    }
    /// Riaprendo l'app entro questo tempo, il conto riprende da dov'era. Di serie vale quanto
    /// una pausa piena (5 min): sotto è un riavvio, sopra è già una pausa vera.
    public var resumeGraceSeconds: Double
    /// **Di serie Otium è attivo sempre**, e la finestra oraria è una cosa che accendi tu.
    ///
    /// Nasceva col contrario, 7→23, e la scelta era ragionevole ma non era una misura: nessuno
    /// studio dice che alle 23:01 stare seduti smetta di far male. Chi lavora la notte veniva
    /// lasciato scoperto proprio nelle ore in cui è più fermo, e per accorgersene doveva
    /// sospettare che una finestra esistesse. Mia richiesta, 2026-08-04:
    /// *«mettiamo di default che è sempre attivo e la possibilità di settare il tempo a
    /// preferenza»*. Il silenzio notturno resta a un interruttore di distanza.
    public var activeHoursAlwaysOn: Bool
    /// Ore di silenzio: fuori da questa finestra Otium non interrompe. Vale solo con
    /// `activeHoursAlwaysOn` spento.
    public var activeFromHour: Int
    public var activeToHour: Int

    public init(
        cadence: Cadence = .optionA,
        startDate: Date = Date(),
        rampWeeks: Int = 3,
        rampStartFactor: Double = 0.55,
        exercisePool: [ExerciseKind] = [.squat, .pushUp, .crunch, .lunge, .benchDip, .plank,
                                        .calfRaise, .gluteBridge, .legRaise,
                                        // **Solo Y-T-W in rotazione, non tutti e due.** Sono
                                        // entrambi «dorso», e nel pool di serie finivano uno
                                        // dietro l'altro: il test che vieta due volte lo stesso
                                        // gruppo di fila l'ha visto subito. Fra i due gira il
                                        // più mirato — tre angoli invece di uno, ed è la
                                        // postura da schermo che serve qui. Il superman resta
                                        // nell'elenco, spuntabile, e **resta offerto come
                                        // sostituzione dentro la pausa** anche da spento: è la
                                        // regola dell'ISC-95, il pool governa il turno e non le
                                        // vie d'uscita. Stessa scelta già fatta per lo split
                                        // squat.
                                        .ytw],   // split squat non c'è: è una variante dell'affondo, non un esercizio a sé in rotazione
        vigorousPool: [ExerciseKind] = [.burpee, .jumpingJack, .mountainClimber, .highKnees],
        vigorousDailyTarget: Int = 3,
        escapePhrase: String = "salto la pausa",   // lingua: ok valore di serie; l'onboarding lo mette in inglese se scegli English
        pushVariant: ExerciseKind? = nil,
        progressBeyondFull: Bool = false,
        fullReachedAt: Date? = nil,
        growthAnswered: Bool = false,
        fullPaceOfferWeeks: Int = 1,
        fullPaceAnswered: Bool = false,
        sex: Sex? = nil,
        language: AppLanguage? = nil,
        deferWhenMicrophoneActive: Bool = true,
        detectQuietPresence: Bool = true,
        offerVariants: Bool = true,
        circuitMode: CircuitMode = .proposto,
        autoStartAtLogin: Bool = true,
        maxAutoDefers: Int = 6,
        autoDeferSeconds: Double = 5 * 60,
        zenMode: Bool = false,
        zenProtocolShort: BreathProtocol = .sospiro,
        zenProtocolLong: BreathProtocol = .risonanza,
        zenBreathSeconds: Double = 90,
        theme: ThemeName = .alloro,
        notificationSound: String = "Tink",
        holdEndSound: String = "Glass",
        soundVolume: Double = 1.0,
        resumeGraceSeconds: Double = 5 * 60,
        activeHoursAlwaysOn: Bool = true,
        activeFromHour: Int = 7,
        activeToHour: Int = 23
    ) {
        self.cadence = cadence
        self.startDate = startDate
        self.rampWeeks = max(1, rampWeeks)
        self.rampStartFactor = min(1.0, max(0.1, rampStartFactor))
        self.exercisePool = exercisePool.isEmpty ? [.squat] : exercisePool
        self.vigorousPool = vigorousPool.isEmpty ? [.jumpingJack] : vigorousPool
        self.vigorousDailyTarget = max(0, vigorousDailyTarget)
        self.escapePhrase = escapePhrase
        self.pushVariant = pushVariant
        self.progressBeyondFull = progressBeyondFull
        self.fullReachedAt = fullReachedAt
        self.growthAnswered = growthAnswered
        self.fullPaceOfferWeeks = max(1, fullPaceOfferWeeks)
        self.fullPaceAnswered = fullPaceAnswered
        self.sex = sex
        self.language = language
        self.deferWhenMicrophoneActive = deferWhenMicrophoneActive
        self.detectQuietPresence = detectQuietPresence
        self.offerVariants = offerVariants
        self.circuitMode = circuitMode
        self.autoStartAtLogin = autoStartAtLogin
        self.maxAutoDefers = max(0, maxAutoDefers)
        self.autoDeferSeconds = autoDeferSeconds
        self.zenMode = zenMode
        self.zenProtocolShort = zenProtocolShort
        self.zenProtocolLong = zenProtocolLong
        self.zenBreathSeconds = max(20, zenBreathSeconds)
        self.theme = theme
        self.notificationSound = notificationSound
        self.holdEndSound = holdEndSound
        self.soundVolume = Settings.clampSoundVolume(soundVolume)
        self.resumeGraceSeconds = max(0, resumeGraceSeconds)
        self.activeHoursAlwaysOn = activeHoursAlwaysOn
        self.activeFromHour = activeFromHour
        self.activeToHour = activeToHour
    }

    /// Quale respiro tocca a questa pausa. **Una domanda, un posto**: prima la scelta era una sola
    /// e la leggeva direttamente `buildPlan`; adesso sono due e la regola che le sceglie sta qui,
    /// dove un test la vede, invece che dentro il motore.
    public func zenProtocol(for kind: BreakKind) -> BreathProtocol {
        kind == .long ? zenProtocolLong : zenProtocolShort
    }

    public var planner: ExercisePlanner {
        ExercisePlanner(pool: exercisePool, vigorousPool: vigorousPool)
    }

    /// Da quando sei al 100%. `nil` se non ci sei ancora.
    ///
    /// Due strade, e la seconda è calcolata invece che memorizzata: o ci sei arrivato **scegliendo**
    /// — al primo avvio o rispondendo alla domanda della settimana — e allora la data è scritta; o
    /// ci sei arrivato **salendo**, e allora è la fine della partenza graduale, che si ricava.
    public func fullPaceSince(now: Date) -> Date? {
        if let fullReachedAt { return fullReachedAt }
        guard rampFactor(now: now) >= 1.0 else { return nil }
        if rampStartFactor >= 1.0 { return startDate }
        return startDate.addingTimeInterval(Double(rampWeeks) * 7 * 24 * 3600)
    }

    /// È il momento di chiedere se vuoi far crescere le ripetizioni oltre il 100%?
    ///
    /// Una settimana **passata al 100%**, non una settimana dall'installazione: la domanda ha
    /// senso solo per chi il programma pieno l'ha già vissuto, e sa cosa vuol dire.
    public func shouldOfferGrowth(now: Date) -> Bool {
        guard !growthAnswered, !progressBeyondFull else { return false }
        guard let since = fullPaceSince(now: now) else { return false }
        return now.timeIntervalSince(since) >= 7 * 24 * 3600
    }

    /// È il momento di chiedere se vuoi già il numero pieno?
    ///
    /// Tre condizioni, e servono tutte. Sono passate abbastanza settimane; non l'hai già
    /// risposto; e **non sei già al numero pieno**, perché chiedere «vuoi passare al pieno» a chi
    /// ci è già arrivato è una domanda senza risposta possibile.
    public func shouldOfferFullPace(now: Date) -> Bool {
        guard !fullPaceAnswered else { return false }
        guard rampFactor(now: now) < 1.0 else { return false }
        return Ramp.weeksElapsed(since: startDate, now: now) >= fullPaceOfferWeeks
    }

    /// Il moltiplicatore di oggi. **Sempre fra 0 e 1**, qualunque cosa dicano i campi: è l'imbuto
    /// da cui passano tutte le ripetizioni proposte, e una cintura qui costa nulla.
    public func rampFactor(now: Date) -> Double {
        min(1.0, max(0.1, Ramp.factor(
            daysElapsed: Ramp.daysElapsed(since: startDate, now: now),
            weeks: rampWeeks,
            startFactor: rampStartFactor
        )))
    }

    /// Le decodifiche vecchie non devono morire quando aggiungo un campo: ogni chiave assente
    /// ricade sul default del `init`, invece di far fallire l'intero file di configurazione.
    /// Le chiavi dei file scritti prima del 2026-07-31, tenute in vita solo per leggerle.
    private enum ChiaviRitirate: String, CodingKey {
        case offerCircuit, startLongInCircuit
        case zenProtocolLegacy = "zenProtocol"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings()
        // **Ricostruita attraverso l'init**, non presa com'è dal file: `Cadence` ha un `Codable`
        // sintetizzato, che i limiti non li conosce. Senza questo giro, i tetti dell'init
        // varrebbero solo per i preset scritti nel codice — cioè proprio per i valori che non
        // hanno bisogno di essere limitati.
        let letta = (try? c.decode(Cadence.self, forKey: .cadence)) ?? d.cadence
        cadence = Cadence(
            intervalSeconds: letta.intervalSeconds,
            microDurationSeconds: letta.microDurationSeconds,
            longDurationSeconds: letta.longDurationSeconds,
            longEveryNBreaks: letta.longEveryNBreaks,
            idleThresholdSeconds: letta.idleThresholdSeconds,
            warningSeconds: letta.warningSeconds,
            postponeSeconds: letta.postponeSeconds,
            postponesAllowed: letta.postponesAllowed
        )
        startDate = (try? c.decode(Date.self, forKey: .startDate)) ?? d.startDate
        rampWeeks = max(1, (try? c.decode(Int.self, forKey: .rampWeeks)) ?? d.rampWeeks)
        // I `didSet` non scattano dentro un inizializzatore: qui i limiti si riapplicano a mano,
        // o il file scritto a mano li scavalcherebbe tutti.
        rampStartFactor = min(1.0, max(0.1, (try? c.decode(Double.self, forKey: .rampStartFactor)) ?? d.rampStartFactor))
        let poolLetto = (try? c.decode([ExerciseKind].self, forKey: .exercisePool)) ?? d.exercisePool
        exercisePool = poolLetto.isEmpty ? d.exercisePool : poolLetto
        let vigorosiLetti = (try? c.decode([ExerciseKind].self, forKey: .vigorousPool)) ?? d.vigorousPool
        vigorousPool = vigorosiLetti.isEmpty ? d.vigorousPool : vigorosiLetti
        vigorousDailyTarget = (try? c.decode(Int.self, forKey: .vigorousDailyTarget)) ?? d.vigorousDailyTarget
        escapePhrase = (try? c.decode(String.self, forKey: .escapePhrase)) ?? d.escapePhrase
        // Assenti nei file scritti prima dell'onboarding: restano nil, e l'app chiede.
        pushVariant = try? c.decode(ExerciseKind.self, forKey: .pushVariant)
        progressBeyondFull = (try? c.decode(Bool.self, forKey: .progressBeyondFull)) ?? d.progressBeyondFull
        fullReachedAt = try? c.decode(Date.self, forKey: .fullReachedAt)
        growthAnswered = (try? c.decode(Bool.self, forKey: .growthAnswered)) ?? d.growthAnswered
        fullPaceOfferWeeks = (try? c.decode(Int.self, forKey: .fullPaceOfferWeeks)) ?? d.fullPaceOfferWeeks
        fullPaceAnswered = (try? c.decode(Bool.self, forKey: .fullPaceAnswered)) ?? d.fullPaceAnswered
        sex = try? c.decode(Sex.self, forKey: .sex)
        language = try? c.decode(AppLanguage.self, forKey: .language)
        deferWhenMicrophoneActive = (try? c.decode(Bool.self, forKey: .deferWhenMicrophoneActive)) ?? d.deferWhenMicrophoneActive
        detectQuietPresence = (try? c.decode(Bool.self, forKey: .detectQuietPresence)) ?? d.detectQuietPresence
        offerVariants = (try? c.decode(Bool.self, forKey: .offerVariants)) ?? d.offerVariants
        // **I file scritti prima portano i due booleani, e non si buttano.** Un'impostazione che
        // sparisce in un aggiornamento è peggio di una che non c'è mai stata: chi aveva spento il
        // circuito se lo ritroverebbe acceso senza sapere perché.
        if let modo = try? c.decode(CircuitMode.self, forKey: .circuitMode) {
            circuitMode = modo
        } else {
            // `CodingKeys` è sintetizzato dalle proprietà **di adesso**, quindi le chiavi vecchie
            // non ci sono più: per leggerle serve un contenitore che le conosca.
            let vecchio = try? decoder.container(keyedBy: ChiaviRitirate.self)
            let offriva = (try? vecchio?.decode(Bool.self, forKey: .offerCircuit)) ?? true
            let subito = (try? vecchio?.decode(Bool.self, forKey: .startLongInCircuit)) ?? false
            circuitMode = (offriva ?? true) ? ((subito ?? false) ? .subito : .proposto) : .singolo
        }
        autoStartAtLogin = (try? c.decode(Bool.self, forKey: .autoStartAtLogin)) ?? d.autoStartAtLogin
        maxAutoDefers = (try? c.decode(Int.self, forKey: .maxAutoDefers)) ?? d.maxAutoDefers
        autoDeferSeconds = (try? c.decode(Double.self, forKey: .autoDeferSeconds)) ?? d.autoDeferSeconds
        // **Assente vuol dire spenta**, che è il default, e qui è anche l'unica lettura sicura: un
        // file scritto prima di questa versione appartiene a qualcuno che si allenava nelle pause.
        zenMode = (try? c.decode(Bool.self, forKey: .zenMode)) ?? d.zenMode
        // **La chiave vecchia non si butta.** `zenProtocol` era una sola per tutte le pause, ed è
        // vissuta poche ore, ma un file scritto in quelle ore esiste: chi l'aveva scelto se lo
        // ritrova su tutte e due, invece di vederlo sparire senza sapere perché.
        let vecchieChiavi = try? decoder.container(keyedBy: ChiaviRitirate.self)
        let unicoVecchio = try? vecchieChiavi?.decode(BreathProtocol.self, forKey: .zenProtocolLegacy)
        zenProtocolShort = (try? c.decode(BreathProtocol.self, forKey: .zenProtocolShort))
            ?? unicoVecchio ?? d.zenProtocolShort
        zenProtocolLong = (try? c.decode(BreathProtocol.self, forKey: .zenProtocolLong))
            ?? unicoVecchio ?? d.zenProtocolLong
        zenBreathSeconds = max(20, (try? c.decode(Double.self, forKey: .zenBreathSeconds)) ?? d.zenBreathSeconds)
        theme = (try? c.decode(ThemeName.self, forKey: .theme)) ?? d.theme
        notificationSound = (try? c.decode(String.self, forKey: .notificationSound)) ?? d.notificationSound
        holdEndSound = (try? c.decode(String.self, forKey: .holdEndSound)) ?? d.holdEndSound
        // Chiave assente nei file scritti prima del 2026-08-16: chi aggiorna ritrova i suoi suoni
        // com'erano, cioè al pieno. Il limite si riapplica qui perché i `didSet` non scattano
        // dentro un inizializzatore e un file scritto a mano scavalcherebbe l'init.
        soundVolume = Settings.clampSoundVolume(
            (try? c.decode(Double.self, forKey: .soundVolume)) ?? d.soundVolume
        )
        resumeGraceSeconds = (try? c.decode(Double.self, forKey: .resumeGraceSeconds)) ?? d.resumeGraceSeconds
        // **Assente vuol dire acceso, di proposito.** Un file scritto prima di questo campo
        // porta una finestra che l'utente non ha quasi mai scelto: era il valore di serie.
        // Ereditarla significherebbe lasciare in piedi il silenzio notturno che la richiesta del
        // 2026-08-04 esiste per togliere. Chi la vuole la riaccende, e resta scritta.
        activeHoursAlwaysOn = (try? c.decode(Bool.self, forKey: .activeHoursAlwaysOn)) ?? d.activeHoursAlwaysOn
        activeFromHour = (try? c.decode(Int.self, forKey: .activeFromHour)) ?? d.activeFromHour
        activeToHour = (try? c.decode(Int.self, forKey: .activeToHour)) ?? d.activeToHour
    }
}

/// Dove vivono configurazione e registro. Niente `~/.pausa`: la convenzione macOS è
/// Application Support, e ci sta anche il backup di Time Machine.
public enum Paths {
    /// Dove vivono i dati quando **non** sono i dati veri: una cartella usa e getta, impostata
    /// all'avvio se l'app parte per una sonda o per una resa.
    ///
    /// Esiste perché una sonda che scrive nel registro, nella rotazione e nei mazzi veri
    /// non sta misurando l'app, la sta modificando. Prima ci si compensava a mano, con un backup
    /// prima e un ripristino dopo, cioè con la disciplina di chi lancia il comando — la garanzia
    /// più fragile che ci sia, e il 2026-07-28 ha ceduto: le sonde hanno riscritto l'avvio
    /// automatico. Con la deviazione qui la sonda è ermetica per costruzione, e per
    /// giunta può girare mentre l'app vera lavora, perché anche il lock dell'istanza unica finisce
    /// nella cartella usa e getta.
    public static var overrideDirectory: URL?

    public static var supportDirectory: URL {
        if let overrideDirectory { return overrideDirectory }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Otium", isDirectory: true)
    }

    public static var settingsFile: URL { supportDirectory.appendingPathComponent("settings.json") }
    public static var ledgerFile: URL { supportDirectory.appendingPathComponent("ledger.jsonl") }
    public static var rotationFile: URL { supportDirectory.appendingPathComponent("rotation.json") }
    /// I mazzi delle frasi: quali sono già uscite e quali restano.
    public static var decksFile: URL { supportDirectory.appendingPathComponent("decks.json") }
    /// Quanto sei avanti su ogni esercizio. Separato dalle impostazioni perché è **stato**,
    /// non configurazione: cresce da solo e non si tocca a mano.
    public static var progressFile: URL { supportDirectory.appendingPathComponent("progress.json") }
    /// Le frasi aggiunte a mano. L'app le legge e non le scrive mai.
    public static var userPhrasesFile: URL { supportDirectory.appendingPathComponent("frasi-mie.json") }

    @discardableResult
    public static func ensureDirectory() -> Bool {
        (try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)) != nil
    }
}

public enum SettingsStore {
    public static func load(from url: URL = Paths.settingsFile) -> Settings {
        guard let data = try? Data(contentsOf: url) else { return Settings() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Settings.self, from: data)) ?? Settings()
    }

    @discardableResult
    public static func save(_ settings: Settings, to url: URL = Paths.settingsFile) -> Bool {
        Paths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(settings) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}


/// Dove vive la rotazione fra un'esecuzione e l'altra.
public enum RotationStore {
    public static func load(from url: URL = Paths.rotationFile) -> EngineSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(EngineSnapshot.self, from: data)
    }

    @discardableResult
    public static func save(_ snapshot: EngineSnapshot, to url: URL = Paths.rotationFile) -> Bool {
        Paths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }
}


/// I suoni di sistema disponibili per il preavviso. Sono quelli che macOS ha già: nessun file
/// audio da spedire con l'app, nessun asset da mantenere.
public enum NotificationSounds {
    public static let names = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]
    public static let silent = ""
}
