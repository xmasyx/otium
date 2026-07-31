import AppKit
import Combine
import OtiumCore

/// L'app è stata avviata per **una sonda o una resa**, non per lavorare.
///
/// Serve a una cosa sola, e l'ho pagata sondando: `applyAutoStartPreference()` gira dentro
/// `AppModel.init` e reinstalla l'avvio automatico quando questo punta a **un'altra copia**
/// dell'app. Il caso per cui esiste è giusto (ricostruisci l'app altrove e l'avvio automatico
/// resta appeso al nulla), ma vale anche per una sonda lanciata dal terminale: il 2026-07-28 le
/// mie sonde su `.build/debug/OtiumApp` hanno riscritto l'avvio automatico del principale dal
/// bundle al binario di sviluppo, che ogni `swift build` sovrascrive. Al login sarebbe partita
/// una copia di lavoro, in silenzio, e nessuno l'avrebbe saputo.
///
/// Una sonda non deve poter cambiare com'è configurata la macchina che sta misurando.
enum ProbeMode {
    private static let flags = [
        "--orphan-probe", "--sleep-probe", "--radar-probe", "--menu-probe", "--confirm-probe",
        "--flush-probe", "--window-probe", "--snapshot", "--demo-break", "--demo-hud", "--presence",
        "--hotkey-probe", "--policy-probe", "--circuit-probe", "--mostra-ritmo", "--demo-ritmo", "--mostra-crescita", "--demo-crescita", "--lsof-probe", "--mostra-prefs", "--scatta", "--stats-probe", "--registro-finto", "--cadenza-finta", "--circuito-subito",   // lingua: ok nomi di flag da riga di comando, non testo a schermo
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
    @Published private(set) var launchAgentState: LaunchAgent.State = .notInstalled
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
        Palette.apply(s.theme)
        // La lingua prima di qualunque cosa parli: la frase d'avvio, il menu, la schermata.
        // Senza scelta ancora fatta si propone quella del Mac, che l'onboarding conferma.
        L.language = s.language ?? AppLanguage.systemDefault
        engine.countLaunch()
        RotationStore.save(engine.snapshot)
        refreshSummary()
        launchAgentState = LaunchAgent.state()
        applyAutoStartPreference()
        launchPhrase = drawPhrase(launch: true)
    }

    /// Pesca dal mazzo giusto e lo mette subito al sicuro su disco.
    ///
    /// Il salvataggio è immediato e non differito: un'app della barra dei menu viene chiusa senza
    /// cerimonie, e un mazzo salvato «più tardi» rimetterebbe in gioco frasi già uscite.
    private func drawPhrase(launch: Bool) -> Phrase? {
        let pool = launch ? PhraseLibrary.launchPool() : PhraseLibrary.breakPool()
        let phrase = launch
            ? decks.launch.draw(from: pool, using: &rng)
            : decks.breaks.draw(from: pool, using: &rng)
        DeckStore.save(decks)
        return phrase
    }

    /// Otium riparte a ogni accensione, senza che tu debba ricordartene.
    ///
    /// Si installa da sola quando la preferenza è accesa e l'avvio automatico non c'è o punta a
    /// un'altra copia — il caso vero è ricostruire l'app in un'altra cartella e ritrovarsi un
    /// LaunchAgent che punta al nulla. **Non** si reinstalla se l'hai tolto dalle preferenze:
    /// quel gesto spegne anche la preferenza, e un'app che si rimette da sola ciò che hai appena
    /// rimosso è un'app che non ti ascolta.
    private func applyAutoStartPreference() {
        guard !ProbeMode.active else { return }
        guard engine.settings.autoStartAtLogin else { return }
        switch launchAgentState {
        case .healthy:
            return
        case .notInstalled, .danglingTarget, .pointsElsewhere:
            LaunchAgent.install()
            launchAgentState = LaunchAgent.state()
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
        cachedEnvironment = EngineEnvironment(
            microphoneActive: engine.settings.deferWhenMicrophoneActive ? MicRadar.isInputActive() : false,
            // Il nome del documento si chiede solo nel preavviso, che è l'unico momento in cui
            // finirà davvero sotto gli occhi di qualcuno.
            presence: engine.settings.detectQuietPresence
                ? PresenceRadar.current(includeDocument: engine.phase == .warning) : nil
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
        if engine.phase != .breaking { blocker.hide() }
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
                subtitle: plan.exercise.label,
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
                    ? L.t("la pausa piena rimandata riparte fra un minuto — \(plan.exercise.label)",
                          "the deferred full break resumes in one minute — \(plan.exercise.label)")
                    : L.t("la pausa rimandata riparte fra un minuto — \(plan.exercise.label)",
                          "the deferred break resumes in one minute — \(plan.exercise.label)"),
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
            // non era stata applicata. Chiesto dal principale il 2026-07-31: *«non mi piace il
            // suono quando posticipo la pausa. togliamolo»*.
            hud.show(title: L.t("Rinviata di 2 minuti", "Postponed by 2 minutes"),
                     subtitle: plan.exercise.label, sound: nil)
        case .autoDeferred(let plan, let reason):
            blocker.hide()
            // Muto anche questo, e per un motivo in piu': l'auto-rinvio scatta **mentre sei in
            // call**, cioe' nell'unico momento in cui un suono di sistema non lo senti solo tu.
            hud.show(title: L.t("Pausa rimandata — \(reason)", "Break deferred — \(reason)"),
                     subtitle: plan.exercise.label, sound: nil)
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

    /// Cosa dire quando la pausa si chiude.
    ///
    /// **Sul circuito diceva solo l'ultima stazione.** Finivi quattro esercizi e la notifica
    /// annunciava «10 jumping jack», perché il piano tiene *l'esercizio corrente* e alla fine
    /// l'esercizio corrente è l'ultimo: la riga era vera e insieme falsa, nominava un quarto del
    /// lavoro fatto. Segnalato dal principale il 2026-07-28, subito dopo un giro completo.
    ///
    /// Le stazioni si elencano tutte. Il pannello cresce in altezza da solo, quindi quattro nomi
    /// non tagliano niente — e vedere le quattro righe che hai fatto è metà del premio.
    func completionSubtitle(_ plan: BreakPlan) -> String {
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

    /// Fa sentire un suono senza aspettare la prossima pausa: serve a sceglierlo.
    func previewSound(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: name)?.play()
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
    func suggestedReps(for kind: ExerciseKind) -> Int {
        Ramp.reps(for: kind, factor: settings.rampFactor(now: Date()), sex: settings.sex)
    }

    /// Le alternative da mostrare adesso. Vuoto se le hai spente nelle preferenze.
    var variants: [Exercise] {
        settings.offerVariants ? engine.variants(now: Date()) : []
    }

    /// `force` serve alla sola resa: il motore rifiuta una sostituzione fuori dalle varianti
    /// dell'esercizio in corso — ed è giusto così, dentro una pausa vera — ma la sonda deve poter
    /// disegnare **qualunque** esercizio per guardarselo.
    func swapExercise(to kind: ExerciseKind, force: Bool = false) {
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

    var secondsLeftOfBreak: Double { engine.secondsLeftOfBreak }
    var exerciseDone: Bool { engine.exerciseDone }

    func forceBreakNow(long: Bool = false) {
        if engine.phase == .paused { engine.setPaused(false) }
        let events = engine.forceBreakNow(now: Date(), kind: long ? .long : nil)
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

    func update(settings: Settings) {
        Palette.apply(settings.theme)
        L.language = settings.language ?? L.language
        engine.settings = settings
        SettingsStore.save(settings)
        objectWillChange.send()
    }

    func installLaunchAgent() {
        LaunchAgent.install()
        launchAgentState = LaunchAgent.state()
        var s = engine.settings
        s.autoStartAtLogin = true
        update(settings: s)
    }

    func removeLaunchAgent() {
        LaunchAgent.uninstall()
        launchAgentState = LaunchAgent.state()
        // Toglierlo spegne anche la preferenza, o al prossimo avvio se lo rimetterebbe da solo.
        var s = engine.settings
        s.autoStartAtLogin = false
        update(settings: s)
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
        // da solo può essere qualunque cosa. Scrivere `60` nel preavviso l'ha scartato il
        // principale stesso, per il motivo giusto: si legge come sessanta minuti. Con la lettera
        // attaccata `47s` e `23m` non si confondono, e il salto fra le due scale si legge per
        // quello che è — il conto è passato ai secondi perché ci siamo.
        case .warning: return "\(max(0, Int(engine.timer.rounded())))s"
        case .postponed, .working: return "\(minutesToNextBreak)m"
        }
    }

    /// Lo studio che giustifica quello che sta succedendo adesso. La citazione è il prodotto:
    /// se l'app ti interrompe, deve saperti dire perché, mentre ti interrompe.
    /// La fonte cambia a ogni pausa e gira **solo su quelle che giustificano qualcosa che sta
    /// succedendo**: sette pause, sette testi, poi ricomincia. Le due voci «non promesso» stanno
    /// nella finestra delle fonti, dove le apri tu.
    var currentStudy: Study {
        guard let plan else { return Evidence.sittingInterval }
        return Evidence.study(forBreak: plan.index)
    }

}
