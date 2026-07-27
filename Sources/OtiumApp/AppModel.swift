import AppKit
import Combine
import OtiumCore

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
    /// Cosa è successo all'avvio: conto ripreso o ripartito. Si dice, non si fa in silenzio.
    private(set) var resumeOutcome: SessionEngine.Resume?

    /// Con `true` il motore gira ma nessuna finestra si apre: serve a rendere la schermata di
    /// blocco fuori schermo, per guardarla, senza coprire il Mac di nessuno.
    var headless = false

    let ledger: Ledger
    private var timer: Timer?
    private var lastTick = Date()
    /// Tempo attivo non ancora scritto sul registro: si scarica ogni 5 minuti, non a ogni secondo.
    private var pendingActiveSeconds: Double = 0
    private var lastSnapshotSave = Date.distantPast
    private static let activeFlushInterval: Double = 300

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
        // Un avvio in più, subito messo al sicuro: la citazione deve cambiare anche se la
        // sessione finisce senza mai arrivare a una pausa.
        Palette.apply(s.theme)
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

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTick)
        lastTick = now
        let idle = IdleProbe.seconds()

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

        let environment = EngineEnvironment(
            microphoneActive: engine.settings.deferWhenMicrophoneActive ? MicRadar.isInputActive() : false,
            presence: engine.settings.detectQuietPresence ? PresenceRadar.current() : nil
        )
        let events = engine.tick(elapsed: elapsed, idle: idle, now: now, environment: environment)
        for event in events { handle(event, now: now) }
        objectWillChange.send()
    }

    private func handle(_ event: EngineEvent, now: Date) {
        if let entry = Ledger.entry(for: event, now: now) {
            ledger.append(entry)
            refreshSummary()
        }
        // Le stazioni del circuito, una riga ciascuna. Non contano come pause — quattro stazioni
        // sono una pausa sola — ma le ripetizioni sono vere e devono comparire nel totale.
        // A pausa chiusa la stazione in corso è confermata; a pausa saltata no: si accredita solo
        // quello che risulta fatto.
        switch event {
        case .breakCompleted(let plan):
            logStations(plan.allStationsDone(currentConfirmed: true), now: now)
        case .breakSkipped(let plan, _):
            logStations(plan.allStationsDone(currentConfirmed: false), now: now)
        default:
            break
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
                title: plan.kind == .long ? "Pausa piena fra un minuto" : "Pausa fra un minuto",
                subtitle: plan.exercise.label,
                sound: settings.notificationSound
            )
        case .breakStarted(let plan):
            hud.hide()
            escapeText = ""
            currentPhrase = drawPhrase(launch: false)
            if !headless { blocker.show(plan: plan) }
        case .breakCompleted(let plan):
            hud.hide()
            blocker.hide()
            // Il momento che merita di più i complimenti è questo: la pausa l'hai fatta davvero,
            // sotto il blocco, non l'hai dichiarata.
            announce(title: Praise.line(at: plan.index, hard: plan.exercise.kind.isVigorous),
                     subtitle: "\(plan.exercise.label) · oggi \(summary.totalReps + plan.exercise.reps) ripetizioni",
                     silent: true)
        case .breakSkipped:
            hud.hide()
            blocker.hide()
        case .postponed(let plan):
            blocker.hide()
            hud.show(title: "Rinviata di 2 minuti", subtitle: plan.exercise.label)
        case .autoDeferred(let plan, let reason):
            blocker.hide()
            hud.show(title: "Pausa rimandata — \(reason)", subtitle: plan.exercise.label)
        case .naturalBreak:
            break
        }
    }

    private func logStations(_ stations: [Exercise], now: Date) {
        guard !stations.isEmpty else { return }
        for station in stations {
            ledger.append(LedgerEntry(timestamp: now, type: .circuitStation,
                                      exercise: station.kind, reps: station.reps,
                                      reason: "stazione"))
        }
        refreshSummary()
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
        objectWillChange.send()
    }

    func markExerciseDone() {
        let events = engine.markExerciseDone()
        for event in events { handle(event, now: Date()) }
        objectWillChange.send()
    }

    /// Le ripetizioni che l'app proporrebbe oggi per quell'esercizio: è il valore di partenza
    /// sensato quando dichiari una pausa fatta, invece di farti digitare un numero da zero.
    func suggestedReps(for kind: ExerciseKind) -> Int {
        Ramp.reps(for: kind, factor: settings.rampFactor(now: Date()))
    }

    /// Le alternative da mostrare adesso. Vuoto se le hai spente nelle preferenze.
    var variants: [Exercise] {
        settings.offerVariants ? engine.variants(now: Date()) : []
    }

    func swapExercise(to kind: ExerciseKind) {
        engine.swapExercise(to: kind, now: Date())
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
        objectWillChange.send()
    }

    func attemptEscape() {
        let events = engine.escape(phrase: escapeText)
        for event in events { handle(event, now: Date()) }
        if !events.isEmpty { escapeText = "" }
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
        announce(title: mode == .total ? "Contati \(minutes) minuti in tutto" : "Aggiunti \(minutes) minuti",
                 subtitle: "prossima pausa fra \(minutesToNextBreak) min")
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
        announce(title: "Totale di oggi corretto",
                 subtitle: "\(minutes) minuti davanti al Mac")
        objectWillChange.send()
    }

    /// Dichiara una pausa già fatta a app chiusa. Conta come pausa, non come ripetizioni:
    /// quante ne hai fatte davvero non lo sappiamo, e inventarle sporcherebbe il registro.
    func recordCompletedBreak(kind: BreakKind, exercise: ExerciseKind? = nil, reps: Int? = nil,
                              minutesAgo: Int = 0) {
        engine.recordCompletedBreak(kind: kind)
        // Registrata all'ora in cui è successa davvero, non a quella del clic: nella cronologia
        // una pausa delle 10:30 deve stare alle 10:30.
        let when = Date().addingTimeInterval(-Double(max(0, minutesAgo)) * 60)
        ledger.append(LedgerEntry(timestamp: when, type: .completed, breakKind: kind,
                                  exercise: exercise, reps: reps, reason: "dichiarata"))
        RotationStore.save(engine.snapshot)
        refreshSummary()
        let cosa = (exercise != nil && reps != nil)
            ? Exercise(kind: exercise!, reps: reps!).label
            : "pausa segnata"
        announce(title: Praise.line(at: engine.breakIndex, hard: exercise?.isVigorous ?? false),
                 subtitle: "\(cosa) · prossima fra \(minutesToNextBreak) min")
        objectWillChange.send()
    }

    /// Toglie l'ultima pausa segnata a mano. Caso vero: la segni, poi arriva davvero, e finisce
    /// contata due volte.
    func undoDeclaredBreak(kind: BreakKind) {
        guard engine.undoDeclaredBreak(kind: kind) else {
            announce(title: "Niente da togliere", subtitle: "nessuna pausa segnata")
            return
        }
        ledger.append(LedgerEntry(timestamp: Date(), type: .undo, breakKind: kind,
                                  reason: "tolta a mano"))
        RotationStore.save(engine.snapshot)
        refreshSummary()
        announce(title: "Pausa tolta", subtitle: "prossima fra \(minutesToNextBreak) min")
        objectWillChange.send()
    }

    /// L'uscita d'emergenza: immediata, contata, visibile nelle statistiche.
    func emergencyExit() {
        let events = engine.emergencyExit()
        for event in events { handle(event, now: Date()) }
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

    func update(settings: Settings) {
        Palette.apply(settings.theme)
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
        case .warning: return "!"
        case .postponed, .working: return "\(minutesToNextBreak)"
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
