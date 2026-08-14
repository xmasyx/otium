import AppKit
import Combine
import OtiumCore
import ServiceManagement

/// L'app è stata avviata per **una sonda o una resa**, non per lavorare.
///
/// Serve a una cosa sola, e l'ho pagata sondando: `AppModel.init` tocca com'è configurata la
/// macchina. Il 2026-07-28 le mie sonde su `.build/debug/OtiumApp` hanno riscritto l'avvio
/// automatico dal bundle al binario di sviluppo, che ogni `swift build`
/// sovrascrive. Al login sarebbe partita una copia di lavoro, in silenzio, e nessuno l'avrebbe
/// saputo.
///
/// Da `SMAppService` (2026-08-03) quel guasto preciso non è più possibile — si registra il
/// bundle, e una sonda fuori da un `.app` non ha niente da registrare. **Il guardiano resta**,
/// perché ora `init` fa un'altra cosa che una sonda non deve fare: `migrateLegacyLaunchAgent()`
/// cancella un file dalla `~/Library/LaunchAgents` di chi la lancia.
///
/// Una sonda non deve poter cambiare com'è configurata la macchina che sta misurando.
enum ProbeMode {
    private static let flags = [
        "--orphan-probe", "--sleep-probe", "--radar-probe", "--menu-probe", "--confirm-probe",
        "--flush-probe", "--window-probe", "--snapshot", "--demo-break", "--demo-hud", "--presence",
        "--hotkey-probe", "--policy-probe", "--circuit-probe", "--mostra-ritmo", "--demo-ritmo", "--mostra-crescita", "--demo-crescita", "--lsof-probe", "--mostra-prefs", "--scatta", "--scatta-menu", "--scatta-barra", "--misura-barra", "--segno-zen", "--stats-probe", "--registro-finto", "--cadenza-finta", "--circuito-subito", "--conto-probe",   // lingua: ok nomi di flag da riga di comando, non testo a schermo
    ]

    static var active: Bool {
        CommandLine.arguments.dropFirst().contains { arg in flags.contains { arg.hasPrefix($0) } }
    }
}

/// Interruttori **solo per le sonde**: spengono una rete per volta, per provare che quella sotto
/// regge da sola.
///
/// Esistono per una regola pagata a caro prezzo: una rete mai provata da sola è un'asserzione
/// travestita da verifica. Le tre reti contro lo schermo nero orfano stanno in tre strati diversi
/// — modello, finestra, vista — e provarle tutte insieme dimostrerebbe solo che *almeno una*
/// funziona, cioè la cosa che già sapevamo. Restano `true` sempre, tranne dentro `--orphan-probe`.
enum SafetyNets {
    /// `AppModel.reconcileBlocker()` — lo schermo coperto come funzione della fase.
    static var modelReconcile = true
    /// Il battito di `BlockerController` che si chiede se la sua pausa esiste ancora.
    static var blockerWatchdog = true
}

/// Il collante: fa girare l'orologio, gira gli eventi del motore all'interfaccia e al registro.
/// Tutta la logica vera sta in `OtiumCore` — qui non si decide niente, si collega soltanto.
final class AppModel: ObservableObject {

    @Published private(set) var engine: SessionEngine
    @Published private(set) var summary = DailySummary()
    @Published private(set) var loginItemState: LoginItem.State = .notRegistered
    @Published var escapeText: String = ""
    /// La frase di questa pausa. **Si estrae una volta sola, quando la pausa comincia**, e resta
    /// ferma finché dura: calcolarla dentro la vista significherebbe ripescarla a ogni ridisegno,
    /// e il testo cambierebbe sotto gli occhi mentre lo leggi.
    @Published private(set) var currentPhrase: Phrase?
    @Published private(set) var launchPhrase: Phrase?
    /// Quale periodo mostrano le statistiche. Sta qui e non nella vista perché la finestra si
    /// ricostruisce a ogni apertura.
    @Published var statsPeriod: StatsPeriod = .day
    /// Cosa è successo all'avvio: conto ripreso o ripartito. Si dice, non si fa in silenzio.
    private(set) var resumeOutcome: SessionEngine.Resume?

    /// Con `true` il motore gira ma nessuna finestra si apre: serve a rendere la schermata di
    /// blocco fuori schermo, per guardarla, senza coprire il Mac di nessuno.
    var headless = false
    /// Inattività finta, **solo per le sonde da riga di comando**.
    ///
    /// Serve a una ragione precisa, pagata subito: durante una sonda nessuno tocca la tastiera,
    /// quindi l'inattività vera cresce e il motore chiude la pausa come «naturale» — e la sonda
    /// finisce per misurare *che non c'era nessuno*, invece di quello che le avevo chiesto.
    var idleOverride: Double?

    let ledger: Ledger
    private var timer: Timer?
    private var lastTick = Date()
    /// Tempo attivo non ancora scritto sul registro: si scarica ogni 5 minuti, non a ogni secondo.
    private var pendingActiveSeconds: Double = 0
    private var lastSnapshotSave = Date.distantPast
    private static let activeFlushInterval: Double = 300
    /// Ogni quanto si guarda cosa c'è intorno. Vedi `environmentSample(now:)`.
    private static let environmentSampleInterval: Double = 3
    private var lastEnvironmentSample = Date.distantPast
    private var cachedEnvironment = EngineEnvironment.quiet
    /// Quante volte il radar è stato davvero interrogato. Un contatore, non una stima: senza,
    /// «guardo intorno ogni tre secondi» resta un'affermazione nei commenti.
    private(set) var environmentSamples = 0

    private lazy var blocker = BlockerController(model: self)
    private lazy var hud = WarningHUD()

    /// I mazzi delle frasi, che sopravvivono alla chiusura: senza, ogni riavvio ricomincerebbe da
    /// un mazzo pieno e le prime frasi tornerebbero spesso — proprio il difetto da curare.
    private var decks = DeckStore.load()
    private var rng = SystemRandomNumberGenerator()

    init(settings: Settings = SettingsStore.load(), ledger: Ledger = Ledger()) {
        var s = settings
        // La rampa parte dal primo avvio vero: se il file non esiste ancora, oggi è il giorno 1.
        if !FileManager.default.fileExists(atPath: Paths.settingsFile.path) {
            s.startDate = Date()
            SettingsStore.save(s)
        }
        self.engine = SessionEngine(settings: s)
        self.ledger = ledger
        // La rotazione riprende da dove l'aveva lasciata: senza, ogni riavvio ripropone lo
        // stesso primo esercizio, e sembra che l'app ne conosca uno solo. Va dopo che tutte le
        // proprietà sono inizializzate: Swift non lascia chiamare metodi su `self` prima.
        if let snapshot = RotationStore.load() { resumeOutcome = engine.restore(snapshot) }
        engine.progress = ProgressStore.load()
        // Un avvio in più, subito messo al sicuro: la citazione deve cambiare anche se la
        // sessione finisce senza mai arrivare a una pausa.
        Palette.apply(s.theme, zen: s.zenMode)
        // La lingua prima di qualunque cosa parli: la frase d'avvio, il menu, la schermata.
        // Senza scelta ancora fatta si propone quella del Mac, che l'onboarding conferma.
        L.language = s.language ?? AppLanguage.systemDefault
        engine.countLaunch()
        RotationStore.save(engine.snapshot)
        refreshSummary()
        migrateLegacyLaunchAgent()
        loginItemState = LoginItem.state()
        applyAutoStartPreference()
        launchPhrase = drawPhrase(launch: true)
    }

    /// Fissa la frase della pausa a una precisa, per **fotografarla**.
    ///
    /// Serve perché la frase esce a caso dal mazzo, e una fotografia che dovrebbe provare come va
    /// a capo un testo preciso non si può ottenere rilanciando la sonda finché non esce quello
    /// giusto. Solo sonde: la vita normale continua a pescare.
    func pinPhrase(_ index: Int) {
        let pool = PhraseLibrary.breakPool(includingUser: false)
        guard pool.indices.contains(index) else { return }
        currentPhrase = pool[index]
    }

    /// Pesca dal mazzo giusto e lo mette subito al sicuro su disco.
    ///
    /// Il salvataggio è immediato e non differito: un'app della barra dei menu viene chiusa senza
    /// cerimonie, e un mazzo salvato «più tardi» rimetterebbe in gioco frasi già uscite.
    private func drawPhrase(launch: Bool) -> Phrase? {
        // **In modalità Zen i fatti restano fuori** (vedi `PhraseLibrary.zenPool`): stai
        // rallentando il respiro, e non è il momento di leggere che stare seduti equivale al fumo.
        let pool = launch ? PhraseLibrary.launchPool()
            : (engine.settings.zenMode ? PhraseLibrary.zenPool() : PhraseLibrary.breakPool())
        let phrase = launch
            ? decks.launch.draw(from: pool, using: &rng)
            : decks.breaks.draw(from: pool, using: &rng)
        DeckStore.save(decks)
        return phrase
    }

    /// Il vecchio avvio automatico se ne va da solo, una volta sola, al primo avvio che lo trova.
    ///
    /// Senza questo passaggio un Mac che aveva già Otium si ritroverebbe **due** avvii: il plist
    /// legacy ancora caricato in launchd e la registrazione nuova. Non è teorico, è esattamente
    /// il caso di questa macchina il 2026-08-03.
    private func migrateLegacyLaunchAgent() {
        guard !ProbeMode.active else { return }
        guard LoginItem.legacyAgentInstalled() else { return }
        LoginItem.removeLegacyAgent()
    }

    /// Otium riparte a ogni accensione, senza che tu debba ricordartene.
    ///
    /// Si registra da sola quando la preferenza è accesa e la registrazione non c'è. **Non** si
    /// rimette se l'hai tolta — né dalle preferenze dell'app, né dall'interruttore in
    /// Impostazioni di Sistema, che è il caso `requiresApproval`: quel gesto è tuo e un'app che
    /// rimette da sé ciò che hai appena tolto è un'app che non ti ascolta.
    private func applyAutoStartPreference() {
        guard !ProbeMode.active else { return }
        guard engine.settings.autoStartAtLogin else { return }
        switch loginItemState {
        case .enabled, .requiresApproval, .notFound:
            return
        case .notRegistered:
            LoginItem.enable()
            loginItemState = LoginItem.state()
        }
    }

    // MARK: - Ciclo

    func start() {
        lastTick = Date()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tick() }
        // `.common` o il timer si ferma mentre un menu è aperto — e il tempo, no.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        observeSleep()
    }

    func stop() {
        flushActiveTime()
        RotationStore.save(engine.snapshot)
        timer?.invalidate()
        timer = nil
    }

    /// **Porta la pausa in corso alla fase di riposo, senza aspettare i secondi veri.**
    ///
    /// Serve alle rese. La seconda faccia della pausa — la frase grande, il conto che scende —
    /// esiste solo dopo che l'esercizio è confermato, e `markExerciseDone` rifiuta finché non è
    /// passato il minimo del movimento: senza questo, fotografarla vorrebbe dire stare lì un
    /// minuto e mezzo a ogni resa, che è il modo di non guardarla mai.
    ///
    /// Muove il motore vero con un `tick` vero: una scorciatoia che scavalcasse il minimo
    /// renderebbe una schermata che nella vita non si raggiunge in quel modo.
    func fastForwardToRest() {
        guard engine.phase == .breaking, let plan else { return }
        let now = Date()
        // **In Zen la scorciatoia deve passare per la porta di Zen.** Con `markExerciseDone` la
        // resa scriveva nel registro le ripetizioni di un esercizio che quella pausa non ha mai
        // chiesto, cioè la sonda falsificava proprio la cosa che la modalità esiste per non fare.
        // Trovato guardando la fotografia della fase di riposo il 2026-08-08.
        if plan.isZen {
            _ = engine.tick(elapsed: SessionEngine.breathSeconds(for: plan) + 5, idle: 0, now: now,
                            environment: environmentSample(now: now))
            stopBreath()
            markBreathDone()
            return
        }
        _ = engine.tick(elapsed: plan.exercise.minimumSeconds + 5, idle: 0, now: now,
                        environment: environmentSample(now: now))
        markExerciseDone()
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        let idle = idleOverride ?? IdleProbe.seconds()

        if engine.phase == .working || engine.phase == .warning || engine.phase == .postponed {
            if idle < engine.settings.cadence.idleThresholdSeconds, elapsed <= 5 {
                pendingActiveSeconds += elapsed
            }
        }
        if pendingActiveSeconds >= Self.activeFlushInterval { flushActiveTime() }
        // Lo stato si mette al sicuro ogni 30 s: se l'app viene chiusa di colpo, il ripristino
        // a caldo deve trovare un valore recente, non quello dell'ultima pausa.
        if now.timeIntervalSince(lastSnapshotSave) >= 30 {
            lastSnapshotSave = now
            RotationStore.save(engine.snapshot)
        }

        let events = engine.tick(elapsed: elapsed, idle: idle, now: now,
                                 environment: environmentSample(now: now))
        for event in events { handle(event, now: now) }
        reconcileBlocker()
        objectWillChange.send()
    }

    /// Cosa c'è intorno: microfono in uso, video in riproduzione, documento aperto davanti.
    ///
    /// **Si campiona ogni 3 secondi, non ogni secondo.** È la parte cara del battito — l'app in
    /// primo piano, l'audio, il documento aperto, lo stato degli ingressi audio — mentre il resto
    /// del tick è aritmetica. Tre secondi non tolgono niente a nessuna decisione che ne dipende: i
    /// tetti della presenza si misurano in **minuti** (45 per il video, 15 per la lettura), e la
    /// soglia di inattività dell'orologio in decine di secondi. Un ritardo di tre secondi lì è
    /// invisibile; moltiplicato per un giorno di lavoro sono due letture su tre risparmiate.
    ///
    /// **Tranne durante il preavviso**, dove si torna a ogni secondo. Sono i 60 secondi in cui il
    /// valore non è contabilità ma una decisione presa nell'istante in cui la si legge: se stai
    /// parlando al telefono la pausa si rimanda, e rimandarla su una lettura vecchia di tre
    /// secondi significa deciderlo su com'era il mondo prima.
    private func environmentSample(now: Date) -> EngineEnvironment {
        // Sospesa non decide niente: interrogare il sistema mentre il motore ignora la risposta
        // è lavoro puro, e su un portatile il lavoro puro è batteria.
        guard engine.phase != .paused else { return cachedEnvironment }
        let stantia = now.timeIntervalSince(lastEnvironmentSample) >= Self.environmentSampleInterval
        guard engine.phase == .warning || stantia else { return cachedEnvironment }
        lastEnvironmentSample = now
        environmentSamples += 1
        // **Il microfono si legge sempre, non più solo quando serve a rimandare.** Prima era
        // dietro `deferWhenMicrophoneActive`, e da quando la call è anche un segnale di presenza
        // quella porta chiudeva la cosa sbagliata: chi avesse spento il rinvio avrebbe perso pure
        // il conteggio del tempo in riunione. Chi decide cosa farne resta il motore, che il
        // rinvio lo continua a subordinare all'interruttore.
        let microfono = MicRadar.isInputActive()
        let telecamera = CameraRadar.isCapturing()
        cachedEnvironment = EngineEnvironment(
            microphoneActive: microfono,
            // Il nome del documento si chiede solo nel preavviso, che è l'unico momento in cui
            // finirà davvero sotto gli occhi di qualcuno.
            presence: engine.settings.detectQuietPresence
                ? PresenceRadar.current(includeDocument: engine.phase == .warning,
                                        microphoneActive: microfono,
                                        cameraActive: telecamera)
                : nil
        )
        return cachedEnvironment
    }

    /// **Lo schermo coperto è una funzione della fase, non l'effetto di un evento.**
    ///
    /// Questa riga esiste per un guasto vero, successo due volte (27 e 28 luglio 2026). Il motore
    /// chiude da solo una pausa quando ti allontani troppo a lungo, ed emette `.naturalBreak`;
    /// il gestore di quell'evento era l'unico dei sei a non chiamare `blocker.hide()`. Risultato:
    /// il motore tornava a `working` con `plan` a nil, la vista senza piano non disegnava più
    /// niente, e restava a schermo intero un rettangolo **nero** a livello di schermatura, con
    /// ⌘-Tab, uscita forzata e chiusura di sessione ancora disabilitate. Nessuna via d'uscita
    /// dalla tastiera: entrambe le volte è finita col tasto di accensione.
    ///
    /// La cura non è aggiungere il caso mancante — sarebbe la stessa architettura, con un buco in
    /// meno. È togliere alla lista degli eventi il potere di lasciare uno scudo orfano: dopo ogni
    /// giro, se non stiamo bloccando, lo schermo si libera. Un percorso futuro del motore che
    /// nessuno ha ancora scritto non può più costare un riavvio forzato.
    ///
    /// Vale in una direzione sola. «Non sto bloccando → libera» è una rete; «sto bloccando →
    /// copri» resterebbe la stessa fragilità al contrario, ed è compito di `.breakStarted`.
    private func reconcileBlocker() {
        guard !headless, SafetyNets.modelReconcile else { return }
        if engine.phase != .breaking {
            blocker.hide()
            // **Fuori dalla pausa non esiste una tenuta in corso.** Un conto che sopravvive alla
            // schermata che lo mostrava suonerebbe «finito» a qualcuno tornato a lavorare dieci
            // secondi prima. Sta qui e non nei sei punti che chiudono una pausa, perché una rete
            // sola in fondo regge anche la via d'uscita che qualcuno aggiungerà domani.
            stopHold()
            // Il respiro sta nella stessa rete e per lo stesso motivo: il suo battito suona la
            // fine, e una fine che suona a chi è già tornato a lavorare è peggio del silenzio.
            stopBreath()
        }
    }

    private func handle(_ event: EngineEvent, now: Date) {
        if let entry = Ledger.entry(for: event, now: now) {
            ledger.append(entry)
            refreshSummary()
        }
        // Ogni volta che la rotazione avanza, la si mette al sicuro: un'app che vive nella barra
        // dei menu viene chiusa senza cerimonie, e non c'è un "salva prima di uscire".
        switch event {
        case .breakCompleted, .breakSkipped, .naturalBreak:
            RotationStore.save(engine.snapshot)
        default:
            break
        }
        switch event {
        case .warningStarted(let plan):
            hud.show(
                title: plan.kind == .long ? L.t("Pausa piena fra un minuto", "Full break in one minute")
                          : L.t("Pausa fra un minuto", "Break in one minute"),
                subtitle: upcomingSubtitle(plan),
                sound: settings.notificationSound
            )
        case .deferredBreakDue(let plan):
            // **L'avviso è tutto il punto.** Senza, la pausa arretrata riparte in silenzio e tu
            // scopri il preavviso senza sapere da dove arriva; con, sai che è quella di prima e
            // perché era stata rimandata. Il suono qui ci va: questa non l'hai premuta tu — è
            // proprio il caso che i suoni servono a coprire, qualcosa che comincia mentre stavi
            // facendo altro.
            hud.show(
                title: L.t("Il microfono si è chiuso", "The microphone is free"),
                subtitle: plan.kind == .long
                    ? L.t("la pausa piena rimandata riparte fra un minuto — \(upcomingTarget(plan))",
                          "the deferred full break resumes in one minute — \(upcomingTarget(plan))")
                    : L.t("la pausa rimandata riparte fra un minuto — \(upcomingTarget(plan))",
                          "the deferred break resumes in one minute — \(upcomingTarget(plan))"),
                sound: settings.notificationSound
            )
        case .postponeWarning(let plan):
            // **Muto, per la stessa ragione per cui è muto il rinvio**: la pausa che torna l'hai
            // rimandata tu un minuto fa, quindi non è una sorpresa da coprire con un suono. Sua
            // indicazione, 2026-08-08: *«muto va bene, ho rinviato io la pausa, so che sta
            // arrivando»*. Il pannello resta, e il conto nella barra dei menu con lui.
            hud.show(
                title: plan.kind == .long
                    ? L.t("Pausa piena fra un minuto", "Full break in one minute")
                    : L.t("Pausa fra un minuto", "Break in one minute"),
                subtitle: upcomingSubtitle(plan),
                sound: nil
            )
        case .callWatchdog(let seconds):
            // **Non blocca, avvisa.** È il rovescio del veto: da quando un microfono acceso
            // impedisce la pausa senza limiti, l'unico modo di accorgersi che un'app se l'è
            // dimenticato aperto è che l'app lo dica. Se sei davvero in riunione da quattro ore
            // senza toccare il Mac, questo pannello è comunque l'informazione giusta.
            hud.show(
                title: L.t("Microfono acceso da \(Int(seconds / 3600)) ore",
                           "Microphone on for \(Int(seconds / 3600)) hours"),
                subtitle: L.t("nessuna pausa può partire mentre è in uso — se non sei in call, controlla quale app lo tiene aperto",
                              "no break can start while it is in use — if you are not on a call, check which app is holding it"),
                sound: settings.notificationSound
            )
        case .breakTimeOver:
            // **Solo suono, nessun pannello, e niente si chiude.** Lo schermo è coperto dal
            // blocco, quindi un HUD non lo vedrebbe nessuno; e se sei dall'altra parte della
            // stanza — che è esattamente quello che la pausa piena ti chiede — il suono è l'unica
            // cosa che ti arriva. Stesso suono del preavviso, come chiesto. Dice che il tempo è
            // finito: se l'esercizio manca ancora, la schermata lo dice già da sé.
            previewSound(settings.notificationSound)
        case .breakStarted(let plan):
            hud.hide()
            escapeText = ""
            currentPhrase = drawPhrase(launch: false)
            if !headless { blocker.show(plan: plan) }
            // In Zen il respiro comincia con la pausa: vedi `startBreath`.
            if plan.isZen { startBreath() }
        case .exerciseConfirmed:
            // La riga nel registro l'ha già scritta il mapping qui sopra; qui non c'è niente da
            // mostrare — il conto in alto nella schermata di blocco si aggiorna da solo, perché
            // legge il riassunto appena ricalcolato.
            break
        case .breakCompleted(let plan):
            hud.hide()
            blocker.hide()
            // Il momento che merita di più i complimenti è questo: la pausa l'hai fatta davvero,
            // sotto il blocco, non l'hai dichiarata.
            // Il totale è già comprensivo di questo esercizio: la riga delle ripetizioni è stata
            // scritta alla conferma, non adesso. Sommarlo di nuovo lo mostrerebbe doppio.
            // Il complimento guarda **tutto** il circuito, non l'ultima stazione: un giro che
            // finisce con i crunch resta un giro col fiatone dentro.
            let faticosa = plan.circuitActive
                ? plan.circuit.contains { $0.kind.isVigorous }
                : plan.exercise.kind.isVigorous
            announce(title: Praise.line(at: plan.index, hard: faticosa),
                     subtitle: completionSubtitle(plan),
                     silent: true)
        case .breakSkipped:
            hud.hide()
            blocker.hide()
        case .postponed(let plan):
            blocker.hide()
            // **Muto: l'hai premuto tu.** Il suono avvisa di qualcosa che non ti aspetti, e il
            // rinvio l'hai appena chiesto — la riga che compare basta a dire che e' stato preso.
            // La regola era gia' scritta per la chiusura della pausa (`announce(silent:)`) e qui
            // non era stata applicata. Deciso il 2026-07-31: *«non mi piace il
            // suono quando posticipo la pausa. togliamolo»*.
            hud.show(title: L.t("Rinviata di 2 minuti", "Postponed by 2 minutes"),
                     subtitle: upcomingTarget(plan, capitalized: true), sound: nil)
        case .autoDeferred(let plan, let reason):
            blocker.hide()
            // Muto anche questo, e per un motivo in piu': l'auto-rinvio scatta **mentre sei in
            // call**, cioe' nell'unico momento in cui un suono di sistema non lo senti solo tu.
            hud.show(title: L.t("Pausa rimandata — \(reason)", "Break deferred — \(reason)"),
                     subtitle: upcomingTarget(plan, capitalized: true), sound: nil)
        case .naturalBreak:
            // Arriva da due posti diversi. Mentre lavori è solo contabilità — ti sei alzato da
            // solo, e va bene così. Ma arriva **anche** dalla pausa in corso, quando l'assenza
            // supera la soglia, e lì lo schermo è coperto. A scoprirlo non è questo caso:
            // è `reconcileBlocker()`, che gira dopo ogni giro di eventi. Aggiungere qui un
            // `blocker.hide()` sarebbe la stessa architettura con un buco in meno, e il prossimo
            // evento nuovo ricomincerebbe da capo.
            hud.hide()
        }
    }

    /// Chiudere il coperchio non è lavoro. `NSWorkspace` lo dice prima e meglio del salto fra
    /// due tick, quindi si usano entrambi: la notifica qui, il salto come rete nell'orologio.
    private func observeSleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.flushActiveTime()
        }
        center.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.lastTick = Date()
        }
    }

    private func flushActiveTime() {
        guard pendingActiveSeconds >= 1 else { return }
        ledger.append(LedgerEntry(timestamp: Date(), type: .active, seconds: pendingActiveSeconds))
        pendingActiveSeconds = 0
        refreshSummary()
    }

    func refreshSummary() {
        summary = ledger.summary()
    }

    /// Cosa dire **prima** che la pausa cominci.
    ///
    /// È il gemello mancante di `completionSubtitle`, e mancava dalla parte che conta di più: alla
    /// fine la notifica elencava già tutte le stazioni, all'inizio nominava solo la prima. Con il
    /// circuito acceso di serie il preavviso prometteva «16 squat» e lo schermo si copriva su
    /// quattro esercizi. Visto all'uso il 2026-08-04, prima di una pausa piena.
    ///
    /// **Non elenca le stazioni, dice una parola sola** (sua indicazione, stessa segnalazione): il
    /// pannello del preavviso non deve crescere di quattro righe per dire una cosa che si legge in
    /// tre parole. I nomi restano dove servono, cioè dentro la pausa e nel complimento finale.
    func upcomingSubtitle(_ plan: BreakPlan) -> String {
        // **In Zen il preavviso nominava l'esercizio del turno**, cioè una cosa che quella pausa
        // non ti chiederà mai. Visto all'uso il 2026-08-08: *«mi ha detto che avrei
        // dovuto fare il ponte per i glutei, anche se ho messo la modalità Zen»*. Il piano portava
        // già la risposta giusta (`plan.breath`), erano le tre righe che lo raccontano a non
        // saperlo. Il campo `exercise` resta popolato apposta — vedi la nota in `buildPlan` — e
        // questo è il prezzo di quella scelta: ogni superficie che lo legge deve chiedere prima
        // se la pausa è Zen.
        if let respiro = plan.breath {
            return L.t("Preparati a respirare · \(respiro.localizedName)",
                       "Get ready to breathe · \(respiro.localizedName)")
        }
        guard isCircuitAhead(plan) else { return plan.exercise.label }
        return L.t("Preparati al circuito", "Get ready for the circuit")
    }

    /// Lo stesso fatto quando va **dentro** una frase già scritta, dove «Preparati al circuito»
    /// non entrerebbe: «la pausa piena rimandata riparte fra un minuto — il circuito».
    func upcomingTarget(_ plan: BreakPlan, capitalized: Bool = false) -> String {
        // Una fonte sola: vedi `BreakPlan.demandLabel`, che è il posto dove questa domanda ha un
        // test. Qui resta solo la maiuscola, che dipende da dove finisce la frase.
        let etichetta = plan.demandLabel
        guard capitalized, let prima = etichetta.first else { return etichetta }
        return prima.uppercased() + etichetta.dropFirst()
    }

    /// Quella che sta arrivando è una pausa in circuito?
    ///
    /// Guarda `circuitActive`, non le impostazioni: in modalità «proponi il circuito» il piano
    /// nasce sull'esercizio del turno e il giro è un sì che devi dare tu dentro la pausa. Lì
    /// l'esercizio nominato è quello vero, e annunciare un circuito sarebbe la stessa bugia al
    /// contrario.
    private func isCircuitAhead(_ plan: BreakPlan) -> Bool {
        plan.circuitActive && plan.circuit.count > 1
    }

    /// Cosa dire quando la pausa si chiude.
    ///
    /// **Sul circuito diceva solo l'ultima stazione.** Finivi quattro esercizi e la notifica
    /// annunciava «10 jumping jack», perché il piano tiene *l'esercizio corrente* e alla fine
    /// l'esercizio corrente è l'ultimo: la riga era vera e insieme falsa, nominava un quarto del
    /// lavoro fatto. Visto all'uso il 2026-07-28, subito dopo un giro completo.
    ///
    /// Le stazioni si elencano tutte. Il pannello cresce in altezza da solo, quindi quattro nomi
    /// non tagliano niente — e vedere le quattro righe che hai fatto è metà del premio.
    func completionSubtitle(_ plan: BreakPlan) -> String {
        // Anche il complimento finale nominava l'esercizio mai fatto, e per giunta con il totale
        // delle ripetizioni di oggi accanto: due numeri veri messi insieme a raccontare una cosa
        // falsa. Qui si dice cosa hai fatto davvero.
        if let respiro = plan.breath {
            let quante = summary.zenBreaks
            return L.t("\(respiro.localizedName) · oggi \(quante) pause di respiro",
                       "\(respiro.localizedName) · \(quante) breathing breaks today")
        }
        guard plan.circuitActive, plan.circuit.count > 1 else {
            return L.t("\(plan.exercise.label) · oggi \(summary.totalReps) ripetizioni",
                       "\(plan.exercise.label) · \(summary.totalReps) reps today")
        }
        let stazioni = plan.circuit.map(\.label).joined(separator: " · ")
        return L.t("Circuito completo: \(stazioni) · oggi \(summary.totalReps) ripetizioni",
                   "Full circuit: \(stazioni) · \(summary.totalReps) reps today")
    }

    /// Da chiamare **nel momento in cui apri** il recap o il menu.
    ///
    /// Il tempo attivo si accumula in memoria e finisce nel registro a blocchi di cinque minuti:
    /// scriverne uno al secondo vorrebbe dire 3.600 righe l'ora su un file che va riletto per
    /// intero a ogni ridisegno. Il prezzo era che il numero «davanti al Mac» poteva essere
    /// vecchio di cinque minuti proprio mentre lo guardavi. Qui si paga la scrittura una volta,
    /// quando serve: aprire una finestra è raro, e in quel momento il numero dev'essere esatto.
    func flushForDisplay() {
        flushActiveTime()
        refreshSummary()
    }

    /// Mostra il pannellino di stato. Serve al secondo avvio: cercare Otium quando è già viva
    /// deve produrre una risposta visibile, non silenzio — il silenzio è indistinguibile da
    /// un'app morta, ed è per questo che si finisce col lanciarla due volte.
    /// - Parameter silent: senza suono. Serve al momento in cui **hai appena premuto tu**: il
    ///   suono avvisa di qualcosa che non ti aspetti, e quando chiudi la pausa con un clic non c'è
    ///   niente da avvisare — la riga che compare basta a dire che è stata registrata. Il suono
    ///   resta dov'è utile: il preavviso, che arriva mentre stai facendo altro.
    func announce(title: String, subtitle: String, silent: Bool = false) {
        hud.show(title: title, subtitle: subtitle, sound: silent ? nil : settings.notificationSound)
    }

    /// Le tre finestre che le Preferenze devono poter aprire: le fonti, il registro nel Finder,
    /// la diagnostica.
    ///
    /// **Closure e non selettori.** Le azioni vivono nell'`AppDelegate`, che una vista SwiftUI non
    /// conosce; la via corta sarebbe `NSApp.sendAction(Selector(("showEvidence")), …)`, cioè un
    /// nome di metodo scritto dentro una stringa — che il compilatore non controlla e che si
    /// rompe in silenzio il giorno che il metodo cambia nome. Queste le assegna l'`AppDelegate`
    /// all'avvio, e se un giorno non le assegnasse il pulsante non farebbe niente invece di far
    /// crashare l'app.
    var onShowEvidence: (() -> Void)?
    var onRevealLedger: (() -> Void)?
    var onShowDoctor: (() -> Void)?
    var onReportIssue: (() -> Void)?

    /// Fa sentire un suono senza aspettare la prossima pausa: serve a sceglierlo.
    func previewSound(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: name)?.play()
    }

    // MARK: - La tenuta a tempo

    /// Il conto in corso di una tenuta, se ce n'è uno. `nil` prima di «Pronto» e dopo la fine.
    @Published private(set) var hold: Hold?
    /// L'istante dell'ultimo battito: i suoni si decidono sull'**intervallo** fra due battiti, non
    /// sull'istante, o un battito perso perderebbe il suo suono per sempre.
    private var lastHoldTick: Date?
    private var holdTimer: Timer?

    /// Vero quando l'esercizio di adesso è una tenuta, cioè quando il numero grande è un tempo.
    var exerciseIsTimed: Bool { plan?.exercise.kind.isTimed ?? false }

    /// «Pronto»: parte la preparazione, e da lì in poi non tocchi più niente.
    ///
    /// Il battito è a dieci al secondo e non a uno: un conto alla rovescia mostrato da un timer da
    /// un secondo salta un numero ogni tanto, perché i battiti scivolano rispetto ai secondi veri.
    /// Il numero però non viene dal battito — viene dall'orologio — quindi il battito serve solo a
    /// ridisegnare abbastanza spesso da non far vedere lo scarto.
    func startHold() {
        guard let plan, plan.exercise.kind.isTimed, hold == nil else { return }
        let now = Date()
        hold = Hold(total: Double(plan.exercise.reps),
                    perSide: plan.exercise.kind.isPerSide,
                    startedAt: now)
        lastHoldTick = now
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.holdTick() }
        RunLoop.main.add(t, forMode: .common)
        holdTimer = t
        objectWillChange.send()
    }

    /// **Solo per le rese**: una tenuta cominciata `secondsAgo` secondi fa.
    ///
    /// Serve a fotografare le facce che nella vita si attraversano una volta e durano tre secondi
    /// — la preparazione, l'avviso del cambio lato — senza stare quaranta secondi in plank davanti
    /// alla macchina fotografica. Non fa partire nessun battito: la fase la decide l'orologio, e
    /// per una resa ferma è esattamente quello che serve.
    func seedHoldForSnapshot(secondsAgo: Double) {
        guard let plan, plan.exercise.kind.isTimed else { return }
        hold = Hold(total: Double(plan.exercise.reps),
                    perSide: plan.exercise.kind.isPerSide,
                    startedAt: Date().addingTimeInterval(-secondsAgo))
        objectWillChange.send()
    }

    private func holdTick() {
        guard let hold, let previous = lastHoldTick else { return }
        let now = Date()
        lastHoldTick = now
        for cue in hold.cues(from: previous, to: now) { play(cue) }
        if hold.phase(at: now) == .done {
            stopHold()
            // **Finita la tenuta, l'esercizio è fatto.** Non c'è un pulsante da premere, ed è il
            // punto di tutta questa storia: quando il tempo scade sei ancora a terra.
            markExerciseDone()
        } else {
            objectWillChange.send()
        }
    }

    private func play(_ cue: Hold.Cue) {
        switch cue {
        // Il via e il cambio sono due tocchi secchi: devono dire «adesso», non farsi ascoltare.
        // Il via, il fermati e il riparti sono tre tocchi secchi: devono dire «adesso», non farsi
        // ascoltare. Il secondo lato ha il suo perché i cinque secondi del cambio li passi girato
        // dall'altra parte, e lo schermo da lì non lo vedi.
        case .start, .switchSide, .secondSideStart:
            NSSound(named: "Pop")?.play()   // lingua: ok nome di un suono di sistema
        case .switchWarning:      NSSound(named: "Morse")?.play() // lingua: ok nome di un suono di sistema
        // La fine è l'unico suono che scegli tu, ed è l'unico che devi riconoscere da un'altra
        // stanza mentale: sei sotto sforzo e stai contando i tuoi secondi, non i miei.
        case .end:                previewSound(settings.holdEndSound)
        }
    }

    /// Ferma il conto senza segnare niente. Serve a chi esce dalla pausa a metà tenuta: un timer
    /// che continua a battere dentro un'app che ha cambiato schermata è il modo di far suonare
    /// «finito» a qualcuno che è già tornato a lavorare.
    func stopHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        lastHoldTick = nil
        hold = nil
        objectWillChange.send()
    }

    // MARK: - Il respiro guidato (modalità Zen)

    /// Il respiro in corso, se ce n'è uno. `nil` fuori dalla modalità Zen.
    @Published private(set) var breath: Breath?
    private var lastBreathTick: Date?
    private var breathTimer: Timer?

    /// **Il respiro parte da solo con la pausa, e non ha un «Pronto».**
    ///
    /// Le tenute ce l'hanno perché devi scendere a terra e nessuno può farlo per te. Qui non devi
    /// andare da nessuna parte, quindi un pulsante da premere sarebbe solo un modo per restare
    /// bloccati: senza premerlo `exerciseDone` non diventa mai vero, e «Torna al lavoro» resterebbe
    /// spento per sempre davanti a qualcuno che non ha capito cosa vuoi da lui.
    func startBreath() {
        guard let plan, let protocollo = plan.breath, breath == nil else { return }
        let now = Date()
        breath = Breath(protocollo: protocollo,
                        total: SessionEngine.breathSeconds(for: plan),
                        startedAt: now)
        lastBreathTick = now
        // Dieci battiti al secondo come per le tenute, e qui servono davvero: il cerchio che si
        // gonfia e si sgonfia legge `progress` dentro il passo, e a un battito al secondo si
        // muoverebbe a scatti.
        let t = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.breathTick() }
        RunLoop.main.add(t, forMode: .common)
        breathTimer = t
        objectWillChange.send()
    }

    /// **Solo per le rese**: un respiro cominciato `secondsAgo` secondi fa, senza battito.
    func seedBreathForSnapshot(secondsAgo: Double) {
        guard let plan, let protocollo = plan.breath else { return }
        breath = Breath(protocollo: protocollo,
                        total: SessionEngine.breathSeconds(for: plan),
                        startedAt: Date().addingTimeInterval(-secondsAgo))
        objectWillChange.send()
    }

    private func breathTick() {
        guard let breath, let previous = lastBreathTick else { return }
        let now = Date()
        lastBreathTick = now
        for cue in breath.cues(from: previous, to: now) { play(cue) }
        if breath.phase(at: now) == .done {
            stopBreath()
            markBreathDone()
        } else {
            objectWillChange.send()
        }
    }

    private func play(_ cue: Breath.Cue) {
        switch cue {
        // Il via è lo stesso tocco secco delle tenute: dice «adesso», e non si fa ascoltare.
        // Il via è lo stesso tocco secco delle tenute: dice «adesso», e non si fa ascoltare. La
        // fine non c'è, e il perché sta scritto accanto a `Breath.Cue`.
        case .start: NSSound(named: "Pop")?.play()   // lingua: ok nome di un suono di sistema
        }
    }

    func stopBreath() {
        breathTimer?.invalidate()
        breathTimer = nil
        lastBreathTick = nil
        breath = nil
        objectWillChange.send()
    }

    func markBreathDone() {
        engine.markBreathDone()
        reconcileBlocker()
        objectWillChange.send()
    }

    /// La frase dell'avvio, in alto a destra come tutto il resto.
    func showLaunchQuote() {
        guard let launchPhrase else { return }
        hud.showQuote(launchPhrase)
    }

    /// Le due varianti che restano a schermo quanto dici tu: servono a **provare a mano** il gesto
    /// di scarto, che nessun test automatico può toccare.
    func announceForSeconds(title: String, subtitle: String, seconds: Double) {
        hud.show(title: title, subtitle: subtitle, sound: nil, seconds: seconds)
    }

    func showLaunchPhraseForSeconds(_ phrase: Phrase, seconds: Double) {
        hud.showQuote(phrase, seconds: seconds)
    }

    // MARK: - Azioni

    var canReturnToWork: Bool { engine.canReturnToWork }

    func returnToWork() {
        let events = engine.returnToWork()
        for event in events { handle(event, now: Date()) }
        reconcileBlocker()
        objectWillChange.send()
    }

    func markExerciseDone() {
        let events = engine.markExerciseDone()
        for event in events { handle(event, now: Date()) }
        if !events.isEmpty { ProgressStore.save(engine.progress) }
        reconcileBlocker()
        objectWillChange.send()
    }

    /// «Non tutte, ne ho fatte N.» Il lavoro si conta lo stesso, e la progressione lo sa.
    func markExercisePartial(reps: Int) {
        let events = engine.markExercisePartial(actualReps: reps)
        for event in events { handle(event, now: Date()) }
        if !events.isEmpty { ProgressStore.save(engine.progress) }
        reconcileBlocker()
        objectWillChange.send()
    }

    /// Il movimento più duro da proporre adesso, se ce n'è uno. Vale solo con la crescita accesa:
    /// a chi ha scelto di restare al 100% l'app non propone scale da salire.
    var harderSuggestion: (kind: ExerciseKind, reason: Progression.HarderReason)? {
        guard settings.progressBeyondFull, let plan = engine.plan else { return nil }
        return Progression.suggestHarder(
            kind: plan.exercise.kind,
            reps: plan.exercise.reps,
            progress: engine.progress.progress(for: plan.exercise.kind),
            breakSeconds: plan.duration
        )
    }

    /// Passa al movimento più duro **adesso**, dentro questa pausa. Le ripetizioni ripartono dal
    /// numero di base di quel gesto: è un esercizio nuovo, non lo stesso con un nome diverso.
    func stepUp(to kind: ExerciseKind) {
        engine.swapExercise(to: kind, now: Date(), force: true)
        objectWillChange.send()
    }

    /// Le ripetizioni che l'app proporrebbe oggi per quell'esercizio: è il valore di partenza
    /// sensato quando dichiari una pausa fatta, invece di farti digitare un numero da zero.
    ///
    /// Il livello ci va per la stessa ragione del circuito: «quello che l'app proporrebbe» include
    /// la crescita guadagnata, o il numero suggerito è il tuo di due mesi fa.
    func suggestedReps(for kind: ExerciseKind) -> Int {
        Ramp.reps(for: kind, factor: settings.rampFactor(now: Date()), sex: settings.sex,
                  level: settings.progressBeyondFull ? engine.progress.progress(for: kind).level : 1.0)
    }

    /// Le alternative da mostrare adesso. Vuoto se le hai spente nelle preferenze.
    var variants: [Exercise] {
        settings.offerVariants ? engine.variants(now: Date()) : []
    }

    /// `force` serve alla sola resa: il motore rifiuta una sostituzione fuori dalle varianti
    /// dell'esercizio in corso — ed è giusto così, dentro una pausa vera — ma la sonda deve poter
    /// disegnare **qualunque** esercizio per guardarselo.
    func swapExercise(to kind: ExerciseKind, force: Bool = false) {
        // Cambiare esercizio azzera la tenuta: i secondi di un plank non valgono su un hollow
        // hold, e un conto che continua dopo il cambio conta la cosa sbagliata.
        stopHold()
        engine.swapExercise(to: kind, now: Date(), force: force)
        objectWillChange.send()
    }

    // MARK: - Il microcircuito della pausa piena

    var canStartCircuit: Bool { engine.canStartCircuit }
    var circuitActive: Bool { engine.plan?.circuitActive ?? false }
    var circuit: [Exercise] { engine.plan?.circuit ?? [] }
    var stationIndex: Int { engine.plan?.stationIndex ?? 0 }

    /// Confermare questa stazione porta alla prossima invece di chiudere l'esercizio.
    var moreStationsAhead: Bool {
        guard let plan = engine.plan, plan.circuitActive else { return false }
        return plan.stationIndex + 1 < plan.circuit.count
    }

    func startCircuit() {
        engine.startCircuit()
        objectWillChange.send()
    }

    func leaveCircuit() {
        engine.leaveCircuit()
        objectWillChange.send()
    }

    func postpone() {
        let events = engine.postpone()
        for event in events { handle(event, now: Date()) }
        reconcileBlocker()
        objectWillChange.send()
    }

    func attemptEscape() {
        let events = engine.escape(phrase: escapeText)
        for event in events { handle(event, now: Date()) }
        if !events.isEmpty { escapeText = "" }
        reconcileBlocker()
        objectWillChange.send()
    }

    /// Dichiara di essere già al computer da un po'. Finisce anche nel registro: è tempo
    /// davanti allo schermo, e il totale del giorno deve dirlo.
    func declareTimeAlreadySeated(minutes: Int, mode: SessionEngine.SeatedMode = .total) {
        let before = engine.clock.activeSeconds
        let after = engine.declareTimeAlreadySeated(Double(max(0, minutes)) * 60, mode: mode)
        // Nel registro va **solo la differenza**, e con segno: il totale di oggi davanti al Mac
        // è una somma di righe, quindi correggere all'ingiù significa scriverne una negativa.
        let delta = after - before
        if abs(delta) >= 1 {
            ledger.append(LedgerEntry(timestamp: Date(), type: .active,
                                      seconds: delta, reason: "dichiarato"))
            refreshSummary()
        }
        RotationStore.save(engine.snapshot)
        announce(title: mode == .total ? L.t("Contati \(minutes) minuti in tutto", "Counted \(minutes) minutes in total")
                               : L.t("Aggiunti \(minutes) minuti", "Added \(minutes) minutes"),
                 subtitle: L.t("prossima pausa fra \(minutesToNextBreak) min", "next break in \(minutesToNextBreak) min"))
        objectWillChange.send()
    }

    /// Il totale di oggi davanti al Mac, e il modo di **correggerlo** quando è sbagliato.
    ///
    /// È un numero diverso dal conto per la prossima pausa, e confonderli è esattamente ciò che
    /// è successo: il conto prende il massimo, il totale del giorno somma. Se il totale dice tre
    /// ore e tu ne hai fatte due, qui si rimette a posto — con una riga di correzione, perché il
    /// registro non si riscrive.
    var todayActiveMinutes: Int { Int(summary.activeSeconds / 60) }

    func correctTodayActiveTime(toMinutes minutes: Int) {
        let target = Double(max(0, minutes)) * 60
        let delta = target - summary.activeSeconds
        guard abs(delta) >= 30 else { return }
        ledger.append(LedgerEntry(timestamp: Date(), type: .active,
                                  seconds: delta, reason: "correzione"))
        refreshSummary()
        announce(title: L.t("Totale di oggi corretto", "Today's total corrected"),
                 subtitle: L.t("\(minutes) minuti davanti al Mac", "\(minutes) minutes at the Mac"))
        objectWillChange.send()
    }

    /// Dichiara una pausa già fatta a app chiusa. Conta come pausa, non come ripetizioni:
    /// quante ne hai fatte davvero non lo sappiamo, e inventarle sporcherebbe il registro.
    func recordCompletedBreak(kind: BreakKind, exercise: ExerciseKind? = nil, reps: Int? = nil,
                              minutesAgo: Int = 0) {
        engine.recordCompletedBreak(kind: kind)
        // Cintura sul numero dispari: lo stepper ormai sale di due sugli esercizi a lati alterni,
        // ma il registro è per sempre e una riga sbagliata non si riscrive. Qui non passa.
        let reps = reps.map { r in exercise.map { Ramp.evenIfPerSide(r, for: $0) } ?? r }
        // Registrata all'ora in cui è successa davvero, non a quella del clic: nella cronologia
        // una pausa delle 10:30 deve stare alle 10:30.
        let when = Date().addingTimeInterval(-Double(max(0, minutesAgo)) * 60)
        ledger.append(LedgerEntry(timestamp: when, type: .completed, breakKind: kind,
                                  exercise: exercise, reps: reps, reason: "dichiarata"))
        RotationStore.save(engine.snapshot)
        refreshSummary()
        let cosa = (exercise != nil && reps != nil)
            ? Exercise(kind: exercise!, reps: reps!).label
            : L.t("pausa segnata", "break logged")
        announce(title: Praise.line(at: engine.breakIndex, hard: exercise?.isVigorous ?? false),
                 subtitle: L.t("\(cosa) · prossima fra \(minutesToNextBreak) min", "\(cosa) · next in \(minutesToNextBreak) min"))
        objectWillChange.send()
    }

    /// Toglie l'ultima pausa segnata a mano. Caso vero: la segni, poi arriva davvero, e finisce
    /// contata due volte.
    func undoDeclaredBreak(kind: BreakKind) {
        guard engine.undoDeclaredBreak(kind: kind) else {
            announce(title: L.t("Niente da togliere", "Nothing to remove"), subtitle: L.t("nessuna pausa segnata", "no break logged"))
            return
        }
        ledger.append(LedgerEntry(timestamp: Date(), type: .undo, breakKind: kind,
                                  reason: "tolta a mano"))
        RotationStore.save(engine.snapshot)
        refreshSummary()
        announce(title: L.t("Pausa tolta", "Break removed"), subtitle: L.t("prossima fra \(minutesToNextBreak) min", "next in \(minutesToNextBreak) min"))
        objectWillChange.send()
    }

    /// L'uscita d'emergenza: immediata, contata, visibile nelle statistiche.
    ///
    /// **Non può dipendere dal motore, o non c'è proprio quando serve.** `engine.emergencyExit()`
    /// è guardata da `phase == .breaking || .warning`: se lo schermo è coperto ma il motore non
    /// ha nessuna pausa aperta da chiudere, restituisce una lista vuota e i due Esc non fanno
    /// niente. È esattamente lo stato in cui ci si trovava inchiodati il 27 e 28 luglio. Da qui in
    /// avanti, quando non c'è niente da chiudere lo scudo si smonta comunque: un'uscita
    /// d'emergenza che funziona solo a motore coerente non è un'uscita d'emergenza.
    func emergencyExit() {
        let events = engine.emergencyExit()
        for event in events { handle(event, now: Date()) }
        if events.isEmpty {
            hud.hide()
            blocker.hide()
        }
        reconcileBlocker()
        objectWillChange.send()
    }

    func stats(for period: StatsPeriod) -> PeriodStats {
        Stats.compute(entries: ledger.entries(), period: period)
    }

    func previousStats(for period: StatsPeriod) -> PeriodStats {
        Stats.previous(entries: ledger.entries(), period: period)
    }

    /// La pagina della crescita legge **tutto** il registro, non il periodo scelto: una
    /// progressione guardata dentro la finestra «Oggi» non è una progressione, è un numero.
    func growth() -> GrowthReport {
        Growth.report(entries: ledger.entries(), book: engine.progress, sex: settings.sex)
    }

    var secondsLeftOfBreak: Double { engine.secondsLeftOfBreak }
    var exerciseDone: Bool { engine.exerciseDone }

    /// `kind` esplicito quando l'hai scelto tu dal menu; `nil` lascia decidere al contatore
    /// «ogni terza è piena», che è il comportamento di quando la pausa arriva da sola.
    func forceBreakNow(long: Bool = false, kind: BreakKind? = nil) {
        if engine.phase == .paused { engine.setPaused(false) }
        let chosen: BreakKind? = kind ?? (long ? .long : nil)
        let events = engine.forceBreakNow(now: Date(), kind: chosen)
        for event in events { handle(event, now: Date()) }
        objectWillChange.send()
    }

    func togglePaused() {
        engine.setPaused(engine.phase != .paused)
        if engine.phase == .paused { blocker.hide(); hud.hide() }
        objectWillChange.send()
    }

    /// Il primo avvio non è ancora stato completato: manca la lingua o il sesso.
    var needsOnboarding: Bool { engine.settings.language == nil || engine.settings.sex == nil }

    /// **Il risultato del salvataggio non si butta più.**
    ///
    /// `SettingsStore.save` restituisce un `Bool` che qui veniva scartato, e «Applica» rispondeva
    /// «Preferenze aggiornate» comunque: un verde falso, cioè la stessa classe di difetto già
    /// pagata sul registro, dove un `try?` diceva sempre di sì mentre il disco pieno buttava via
    /// le righe. Scoperto guardando **perché** la modalità Zen non aveva effetto il 2026-08-08:
    /// quel giro l'impostazione sul disco non c'era, e con la vecchia versione non esisteva un solo
    /// modo di accorgersene.
    @discardableResult
    func update(settings: Settings) -> Bool {
        Palette.apply(settings.theme, zen: settings.zenMode)
        L.language = settings.language ?? L.language
        engine.settings = settings
        let scritto = SettingsStore.save(settings)
        objectWillChange.send()
        return scritto
    }

    func enableLoginItem() {
        LoginItem.enable()
        loginItemState = LoginItem.state()
        var s = engine.settings
        s.autoStartAtLogin = true
        update(settings: s)
    }

    func disableLoginItem() {
        LoginItem.disable()
        loginItemState = LoginItem.state()
        // Toglierlo spegne anche la preferenza, o al prossimo avvio se lo rimetterebbe da solo.
        var s = engine.settings
        s.autoStartAtLogin = false
        update(settings: s)
    }

    /// Apre la sezione di Impostazioni di Sistema dove l'interruttore è tuo.
    ///
    /// Serve nel caso `requiresApproval`: l'app **non può** riaccendersi da sé, e l'unica cosa
    /// onesta che può fare è portarti dove si accende.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    // MARK: - Lettura per l'interfaccia

    var settings: Settings { engine.settings }
    var phase: SessionEngine.Phase { engine.phase }
    var plan: BreakPlan? { engine.plan }
    var breakElapsed: Double { engine.timer }
    var canFinishNow: Bool { engine.canFinishNow }
    var secondsUntilCanFinish: Double { engine.secondsUntilCanFinish }
    var canPostpone: Bool { engine.canPostpone }

    var minutesToNextBreak: Int {
        Int((engine.secondsUntilNextBreak / 60).rounded(.up))
    }

    var statusTitle: String {
        switch engine.phase {
        case .paused: return "⏸"
        case .breaking: return "●"
        // **L'unità va detta, o il numero mente.** Nel preavviso c'era un `!`, che non dice
        // niente; e il numero nudo delle altre fasi ha lo stesso difetto al contrario — un `23`
        // da solo può essere qualunque cosa. Scrivere `60` nel preavviso l'ho scartato io
        // stesso, per il motivo giusto: si legge come sessanta minuti. Con la lettera
        // attaccata `47s` e `23m` non si confondono, e il salto fra le due scale si legge per
        // quello che è — il conto è passato ai secondi perché ci siamo.
        // **E il conto non scorre, sale per gradini** (60s, 30s, poi 5-4-3-2-1): un numero che
        // cambia ogni secondo a lato dello schermo è rumore, i gradini sono eventi. La scala vive
        // in `Countdown`, dentro OtiumCore, perché è l'unico posto dove i test la vedono.
        case .warning:
            let gradino = Countdown.step(remaining: engine.timer,
                                         warningSeconds: engine.settings.cadence.warningSeconds)
            return "\(gradino)s"
        // **Durante un rinvio il numero deve essere quello del rinvio.** Diceva `0m` per tutti e
        // due i minuti, e non era un caso limite: leggeva i minuti che mancano all'intervallo, che
        // durante un rinvio è già scaduto per definizione. Adesso dice quanto manca davvero al
        // ritorno, e l'ultimo minuto lo prende in mano il preavviso con la sua scala.
        case .postponed:
            return "\(max(1, Int((engine.timer / 60).rounded(.up))))m"
        case .working: return "\(minutesToNextBreak)m"
        }
    }

    /// Lo studio che giustifica quello che sta succedendo adesso. La citazione è il prodotto:
    /// se l'app ti interrompe, deve saperti dire perché, mentre ti interrompe.
    /// La fonte cambia a ogni pausa e gira **solo su quelle che giustificano qualcosa che sta
    /// succedendo**: sette pause, sette testi, poi ricomincia. Le due voci «non promesso» stanno
    /// nella finestra delle fonti, dove le apri tu.
    var currentStudy: Study {
        guard let plan else { return Evidence.sittingInterval }
        // **In Zen girano solo le fonti di Zen**, per la stessa ragione per cui le voci «non
        // promesso» stanno fuori dal giro: la riga sotto il blocco dice *perché ti sto
        // interrompendo*, e citare il crollo glicemico mentre respiri spiega un lavoro che in
        // questo momento non stai facendo.
        if plan.isZen {
            let list = Evidence.zen
            let i = ((plan.index - 1) % list.count + list.count) % list.count
            return list[i]
        }
        return Evidence.study(forBreak: plan.index)
    }

}
