import AppKit
import SwiftUI
import OtiumCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var prefsWindow: NSWindow?
    private var evidenceWindow: NSWindow?
    private var statsWindow: NSWindow?
    private var seatedWindow: NSWindow?
    private var declareWindow: NSWindow?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Paths.ensureDirectory()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem.menu = buildMenu()
        updateStatusTitle()

        model.start()

        let t = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in self?.updateStatusTitle() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t

        // Una riga da leggere mentre l'app si mette in ascolto. Cambia a ogni avvio.
        if !CommandLine.arguments.contains(where: { $0.hasPrefix("--snapshot") }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.model.showLaunchQuote()
            }
        }

        runDemoIfRequested()
        renderSnapshotIfRequested()

        // Il secondo avvio non apre niente di nuovo: chiede a questa istanza di farsi vedere.
        // Su un'app della barra dei menu "farsi vedere" significa dire come sta, altrimenti
        // l'utente clicca e non succede nulla — che è indistinguibile da un'app morta.
        SingleInstance.observe(
            onPing: { [weak self] in self?.announcePresence() },
            onBreak: { [weak self] in self?.breakNow() }
        )
    }

    /// Un pannello che dice a che punto è il conto. È la risposta al secondo avvio.
    private func announcePresence() {
        model.refreshSummary()
        let subtitle = model.phase == .paused
            ? "sospesa — riprendila dal menu"
            : "prossima pausa fra \(model.minutesToNextBreak) min di lavoro attivo"
        model.announce(title: "Otium è già attiva", subtitle: subtitle)
        updateStatusTitle()
    }

    /// `--snapshot=<file.png>` — disegna la schermata di blocco **fuori schermo** e la salva.
    ///
    /// Esiste per una ragione precisa: `screencapture` senza il permesso Registrazione schermo
    /// restituisce un'immagine nera, e un nero non si distingue da una finestra che non ha
    /// disegnato niente. Rendendo la vista da dentro l'app la domanda diventa la sua: *questa
    /// schermata, disegnata, com'è fatta?* — e la risposta è un'immagine vera, guardabile.
    private func renderSnapshotIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--snapshot=") }),
              let path = arg.split(separator: "=", maxSplits: 1).last.map(String.init)
        else { return }

        let long = CommandLine.arguments.contains("--long")
        // Il timer va fermato **prima**: girando, leggerebbe l'inattività di un Mac che nessuno
        // sta toccando e chiuderebbe il break come pausa naturale, lasciando una schermata vuota.
        model.stop()
        model.headless = true
        model.forceBreakNow(long: long)

        // Quale schermata rendere: la pausa di default, ma anche le due superfici che finora
        // non aveva mai guardato nessuno.
        let surface = CommandLine.arguments.first { $0.hasPrefix("--surface=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init) ?? "break"
        let size: NSSize
        let host: NSView
        switch surface {
        case "evidence":
            size = NSSize(width: 640, height: 3200)   // alta: si vuole vedere tutta, non scorrerla
            host = NSHostingView(rootView: EvidenceView().frame(width: size.width, height: size.height))
        case "declare":
            size = NSSize(width: 420, height: 330)
            host = NSHostingView(rootView: DeclareBreakView(model: model, onDone: {}).frame(width: size.width, height: size.height))
        case "seated":
            size = NSSize(width: 460, height: 420)
            host = NSHostingView(rootView: DeclareSeatedView(model: model, onDone: {}).frame(width: size.width, height: size.height))
        case "stats":
            size = NSSize(width: 620, height: 1400)
            host = NSHostingView(rootView: StatsView(model: model).frame(width: size.width, height: size.height))
        case "prefs":
            size = NSSize(width: 520, height: 900)
            host = NSHostingView(rootView: PrefsView(model: model).frame(width: size.width, height: size.height))
        default:
            size = NSSize(width: 1440, height: 900)
            host = NSHostingView(rootView: BreakView(model: model).frame(width: size.width, height: size.height))
        }
        host.frame = NSRect(origin: .zero, size: size)

        // SwiftUI non disegna nello stesso giro di run loop in cui lo si costruisce: si lascia
        // respirare, poi si cattura. Senza questa attesa esce un rettangolo vuoto.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                FileHandle.standardError.write("snapshot: nessuna rappresentazione\n".data(using: .utf8)!)
                NSApp.terminate(nil); return
            }
            host.cacheDisplay(in: host.bounds, to: rep)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
                print(path)
            }
            NSApp.terminate(nil)
        }
    }

    /// `--demo-break[=secondi]` — apre subito la schermata di blocco e **si spegne da solo**
    /// allo scadere (20 s di default).
    ///
    /// L'auto-spegnimento non è una comodità: durante il blocco l'app disabilita l'uscita
    /// forzata e la commutazione fra applicazioni, quindi una demo che dipendesse da qualcuno
    /// che la chiude a mano sarebbe il modo perfetto di lasciare un Mac inchiodato. Il timer è
    /// armato **prima** che lo schermo si copra, non dopo.
    private func runDemoIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--demo-break") })
        else { return }

        let seconds = arg.split(separator: "=").last.flatMap { Double($0) } ?? 20
        let killswitch = Timer(timeInterval: max(5, seconds), repeats: false) { _ in
            NSApp.presentationOptions = []
            NSApp.terminate(nil)
        }
        RunLoop.main.add(killswitch, forMode: .common)
        model.forceBreakNow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private func updateStatusTitle() {
        statusItem.button?.title = model.statusTitle
        statusItem.button?.toolTip = model.phase == .paused
            ? "Otium sospesa"
            : "Prossima pausa fra \(model.minutesToNextBreak) minuti di lavoro attivo"
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let panel = NSMenuItem()
        let hosting = NSHostingView(rootView: MenuPanel(model: model))
        hosting.frame = NSRect(x: 0, y: 0, width: 280, height: 260)
        panel.view = hosting
        menu.addItem(panel)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sospendi", action: #selector(togglePause), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Fai una pausa adesso", action: #selector(breakNow), keyEquivalent: ""))

        // Due pannelli invece di due sottomenu: servono due informazioni per volta (quale
        // esercizio, quante ripetizioni), e un menu sa fare una domanda sola.
        menu.addItem(NSMenuItem(title: "Sono già al computer da…", action: #selector(showSeated), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Ho già fatto una pausa…", action: #selector(showDeclare), keyEquivalent: ""))
        let undo = NSMenuItem(title: "Togli l'ultima pausa segnata", action: nil, keyEquivalent: "")
        let undoMenu = NSMenu()
        let um = NSMenuItem(title: "micro-pausa", action: #selector(undoMicro), keyEquivalent: "")
        let ul = NSMenuItem(title: "pausa piena", action: #selector(undoLong), keyEquivalent: "")
        for item in [um, ul] { item.target = self; undoMenu.addItem(item) }
        undo.submenu = undoMenu
        menu.addItem(undo)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Statistiche…", action: #selector(showStats), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Da dove vengono questi numeri…", action: #selector(showEvidence), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Apri il registro", action: #selector(revealLedger), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferenze…", action: #selector(showPrefs), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esci da Otium", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != nil && item.target == nil {
            if item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        }
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.refreshSummary()
        if let item = menu.items.first(where: { $0.title == "Sospendi" || $0.title == "Riprendi" }) {
            item.title = model.phase == .paused ? "Riprendi" : "Sospendi"
        }
        if let hosting = menu.items.first?.view as? NSHostingView<MenuPanel> {
            hosting.rootView = MenuPanel(model: model)
        }
    }

    @objc private func togglePause() {
        model.togglePaused()
        updateStatusTitle()
    }

    /// Utile la prima volta, per vedere com'è fatta la schermata senza aspettare mezz'ora.
    @objc private func breakNow() {
        model.forceBreakNow()
        updateStatusTitle()
    }

    @objc private func showSeated() {
        seatedWindow = makeWindow(title: "Sono già al computer da…",
                                  content: NSHostingView(rootView: DeclareSeatedView(model: model) { [weak self] in
                                      self?.seatedWindow?.close(); self?.seatedWindow = nil
                                      self?.updateStatusTitle()
                                  }))
        present(seatedWindow)
    }

    @objc private func showDeclare() {
        declareWindow = makeWindow(title: "Ho già fatto una pausa…",
                                   content: NSHostingView(rootView: DeclareBreakView(model: model) { [weak self] in
                                       self?.declareWindow?.close(); self?.declareWindow = nil
                                       self?.updateStatusTitle()
                                   }))
        present(declareWindow)
    }

    @objc private func undoMicro() { model.undoDeclaredBreak(kind: .micro); updateStatusTitle() }
    @objc private func undoLong() { model.undoDeclaredBreak(kind: .long); updateStatusTitle() }

    @objc private func showStats() {
        if statsWindow == nil {
            let view = NSHostingView(rootView: StatsView(model: model))
            view.frame = NSRect(x: 0, y: 0, width: 620, height: 680)
            statsWindow = makeWindow(title: "Otium — statistiche", content: view)
        }
        present(statsWindow)
    }

    @objc private func revealLedger() {
        NSWorkspace.shared.activateFileViewerSelecting([model.ledger.fileURL])
    }

    @objc private func showEvidence() {
        if evidenceWindow == nil {
            let view = NSHostingView(rootView: EvidenceView())
            view.frame = NSRect(x: 0, y: 0, width: 640, height: 620)
            evidenceWindow = makeWindow(title: "Otium — le fonti", content: view)
        }
        present(evidenceWindow)
    }

    @objc private func showPrefs() {
        if prefsWindow == nil {
            prefsWindow = makeWindow(title: "Preferenze di Otium", content: NSHostingView(rootView: PrefsView(model: model)))
        }
        present(prefsWindow)
    }

    private func makeWindow(title: String, content: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: content.fittingSize.width > 0
                ? NSRect(origin: .zero, size: content.fittingSize)
                : NSRect(x: 0, y: 0, width: 560, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

// Comandi che non aprono l'interfaccia: si eseguono e si esce. Servono anche a provare il
// percorso reale dell'avvio automatico, invece di provare `launchctl` e sperare che il codice
// dell'app faccia la stessa cosa.
let arguments = CommandLine.arguments
if arguments.contains("--presence"), let watchArg = arguments.first(where: { $0.hasPrefix("--watch") }) {
    // La sonda a colpo singolo aveva un difetto di **protocollo**, non di codice: per lanciarla
    // devi mettere a fuoco il terminale, quindi l'app da leggere non può mai essere in primo
    // piano. Una sonda che distrugge ciò che vuole misurare non misura niente. Questa campiona
    // nel tempo: la lanci, vai su Anteprima o su un video, torni, e leggi cosa ha visto.
    let seconds = watchArg.split(separator: "=").last.flatMap { Double($0) } ?? 60
    print("guardo per \(Int(seconds)) s — passa pure ad altre app, campiono ogni 2 s\n")
    var elapsed = 0.0
    var last = "—"
    while elapsed < seconds {
        let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
        // Tutti gli strati a ogni campione, non solo quello che vince. Stampare il solo verdetto
        // nascondeva la lettura dietro un audio di sottofondo, e sembrava che il PDF non venisse
        // riconosciuto: era il verdetto a coprirlo, non il radar a mancarlo.
        // Le colonne sono gli **ingressi veri** del classificatore, non altri strati: mostrare
        // diagnostica che risponde a una domanda diversa dal verdetto è come si perde un'ora
        // a cercare un guasto che non c'è.
        let app = NSWorkspace.shared.frontmostApplication
        let plays = app.map { PresenceRadar.isPlayingAudio($0) } ?? false
        let document = app.flatMap { a in
            ReaderApps.isReader(a.bundleIdentifier) ? PresenceRadar.openDocument(pid: a.processIdentifier) : nil
        } ?? "—"
        let verdict = PresenceRadar.detect()
            .map { "\($0.kind.rawValue) · tetto \(Int(PresenceCap.seconds(for: $0.kind) / 60))′ · \($0.detail)" }
            ?? "nessuna presenza"
        let line = "\(front) | suona: \(plays ? "sì" : "no") | doc: \(document) | → \(verdict)"
        if line != last {
            print(String(format: "[%3.0f s] %@", elapsed, line as NSString))
            last = line
        }
        RunLoop.main.run(until: Date().addingTimeInterval(2))
        elapsed += 2
    }
    print("\nfine.")
    exit(0)
}
if arguments.contains("--presence") {
    // Cosa vede il radar in questo istante. Serve a provarlo sul vivo: apri un PDF, avvia un
    // video, e chiedi all'app cosa ha riconosciuto — invece di fidarsi che lo riconosca.
    let idle = IdleProbe.seconds()
    print(String(format: "inattività: %.0f s", idle))
    print("microfono in uso: \(MicRadar.isInputActive() ? "sì (call)" : "no")")
    if let audio = PresenceRadar.detectAudio() {
        print("audio: \(audio.detail)")
    } else {
        print("audio: nessun player riconosciuto sta suonando")
    }
    if let media = PresenceRadar.detectMedia() {
        print("schermo tenuto sveglio da: \(media.detail)")
    } else {
        print("schermo tenuto sveglio da: nessuno (normale sui browser Chromium)")
    }
    if let reading = PresenceRadar.detectReading() {
        print("lettura: \(reading.detail)")
    } else {
        let front = NSWorkspace.shared.frontmostApplication
        print("lettura: no — in primo piano c'è \(front?.localizedName ?? "?") "
            + "(\(front?.bundleIdentifier ?? "?"))")
    }
    if let p = PresenceRadar.detect() {
        print("→ presenza: \(p.kind.rawValue) · \(p.detail) · tetto \(Int(PresenceCap.seconds(for: p.kind) / 60)) min")
    } else {
        print("→ presenza: nessuna — fermo qui significherebbe assente")
    }
    exit(0)
}
if arguments.contains("--agent-status") {
    print(LaunchAgent.state())
    exit(0)
}
if arguments.contains("--install-agent") {
    let ok = LaunchAgent.install()
    print(ok ? "installato: \(LaunchAgent.plistURL.path)" : "installazione fallita")
    print(LaunchAgent.state())
    exit(ok ? 0 : 1)
}
if arguments.contains("--remove-agent") {
    let ok = LaunchAgent.uninstall()
    print(ok ? "rimosso" : "rimozione fallita (forse non era installato)")
    print(LaunchAgent.state())
    exit(ok ? 0 : 1)
}

// Da qui in giù si apre l'interfaccia: prima ci si assicura di essere l'unica istanza.
// Cercare "Otium" da Spotlight una seconda volta deve **svegliare** quella che c'è, non
// avviarne un'altra che conta il tempo in parallelo.
if !SingleInstance.acquire() {
    SingleInstance.wakeExisting(requestBreak: arguments.contains("--demo-break"))
    print("Otium è già in esecuzione — la trovi nella barra dei menu.")
    exit(0)
}

let delegate = AppDelegate()
let app = NSApplication.shared
app.delegate = delegate
// Accessoria: vive nella barra dei menu, non nel Dock. Diventa "regular" solo quando serve
// una finestra vera (preferenze, fonti) o durante un blocco.
app.setActivationPolicy(.accessory)
app.run()
