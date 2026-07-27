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
            if !headless { blocker.show(plan: plan) }
        case .breakCompleted(let plan):
            hud.hide()
            blocker.hide()
            // Il momento che merita di più i complimenti è questo: la pausa l'hai fatta davvero,
            // sotto il blocco, non l'hai dichiarata.
            announce(title: Praise.line(at: plan.index, hard: plan.exercise.kind.isVigorous),
                     subtitle: "\(plan.exercise.label) · oggi \(summary.totalReps + plan.exercise.reps) ripetizioni")
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
    func announce(title: String, subtitle: String) {
        hud.show(title: title, subtitle: subtitle, sound: settings.notificationSound)
    }

    /// Fa sentire un suono senza aspettare la prossima pausa: serve a sceglierlo.
    func previewSound(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: name)?.play()
    }

    /// La citazione dell'avvio, in alto a destra come tutto il resto.
    func showLaunchQuote() {
        hud.showQuote(engine.launchQuote)
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
    func declareTimeAlreadySeated(minutes: Int) {
        let seconds = Double(max(0, minutes)) * 60
        let before = engine.clock.activeSeconds
        let after = engine.declareTimeAlreadySeated(seconds)
        let added = max(0, after - before)
        if added > 0 {
            ledger.append(LedgerEntry(timestamp: Date(), type: .active,
                                      seconds: added, reason: "dichiarato"))
            refreshSummary()
        }
        RotationStore.save(engine.snapshot)
        announce(title: "Contati \(minutes) minuti già seduto",
                 subtitle: "prossima pausa fra \(minutesToNextBreak) min")
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
        let cosa = (exercise != nil && reps != nil) ? "\(reps!) \(exercise!.italianName)" : "pausa segnata"
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
    }

    func removeLaunchAgent() {
        LaunchAgent.uninstall()
        launchAgentState = LaunchAgent.state()
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
    /// La fonte cambia a ogni pausa: gira su tutte, comprese le due che dichiarano quello che
    /// l'app **non** promette. Nove pause, nove testi diversi, poi ricomincia.
    var currentStudy: Study {
        guard let plan else { return Evidence.sittingInterval }
        return Evidence.study(forBreak: plan.index)
    }

    var launchQuote: Quote { engine.launchQuote }
    var breakQuote: Quote { engine.breakQuote }

    /// La fonte in mostra dichiara un limite invece di giustificare una scelta?
    var isCurrentStudyADisclaimer: Bool {
        Evidence.disclaimers.contains { $0.id == currentStudy.id }
    }
}
