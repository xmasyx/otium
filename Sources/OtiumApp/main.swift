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
        // Non durante le sonde: la frase d'avvio **sostituisce** il pannello che si sta provando,
        // e la sonda finirebbe per misurare una superficie diversa da quella che ha chiesto.
        if !CommandLine.arguments.contains(where: { $0.hasPrefix("--snapshot") || $0.hasPrefix("--demo-hud") }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.model.showLaunchQuote()
            }
        }

        runDemoIfRequested()
        runHudDemoIfRequested()
        renderSnapshotIfRequested()
        runWindowProbeIfRequested()
        runConfirmProbeIfRequested()
        runFlushProbeIfRequested()
        runOrphanProbeIfRequested()
        runSleepProbeIfRequested()
        runMenuProbeIfRequested()
        runRadarProbeIfRequested()

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

        // Per guardare le finestre normali come le vedi tu di sera, e per confrontare le livree
        // senza cambiare le impostazioni del Mac.
        // Senza uno dei due flag il render eredita l'aspetto del Mac in quel momento: di sera
        // «senza --dark» non significa chiaro, significa scuro lo stesso.
        if CommandLine.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else if CommandLine.arguments.contains("--light") {
            NSApp.appearance = NSAppearance(named: .aqua)
        }
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--theme=") }),
           let name = arg.split(separator: "=", maxSplits: 1).last.map(String.init),
           let theme = ThemeName(rawValue: name) {
            Palette.apply(theme)
        }

        let long = CommandLine.arguments.contains("--long")
        // Il timer va fermato **prima**: girando, leggerebbe l'inattività di un Mac che nessuno
        // sta toccando e chiuderebbe il break come pausa naturale, lasciando una schermata vuota.
        model.stop()
        model.headless = true
        // `--orfana` rende di proposito la schermata **senza piano**: è lo stato che il 27 e il 28
        // luglio 2026 era un rettangolo nero muto, e l'unico modo di sapere com'è adesso è
        // guardarlo. Un `if let` senza `else` non si vede leggendo il codice: si vede nei pixel.
        if !CommandLine.arguments.contains("--orfana") {
            model.forceBreakNow(long: long)
        }

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
        case "hud":
            // La frase più lunga che l'app sappia dire, quella che si tagliava. La misura è
            // quella **naturale** del contenuto: se torna a essere 84 punti, il testo sta su una
            // riga; se cresce, è andato a capo. Il numero è già una risposta, l'immagine è la prova.
            let testo = CommandLine.arguments.first { $0.hasPrefix("--testo=") }?
                .split(separator: "=", maxSplits: 1).last.map(String.init)
                ?? "prossima pausa fra 30 min di lavoro attivo"
            let hud = NSHostingView(rootView: HUDView(
                title: "Otium è già attiva",
                subtitle: testo
            ))
            size = hud.fittingSize
            host = hud
        case "menu":
            size = NSSize(width: 280, height: 260)
            host = NSHostingView(rootView: MenuPanel(model: model).frame(width: size.width))
        case "declare":
            size = NSSize(width: 420, height: 330)
            host = NSHostingView(rootView: DeclareBreakView(model: model, onDone: {}).frame(width: size.width, height: size.height))
        case "seated":
            size = NSSize(width: 460, height: 420)
            host = NSHostingView(rootView: DeclareSeatedView(model: model, onDone: {}).frame(width: size.width, height: size.height))
        case "stats":
            StatsView.expandGroupsForSnapshot = CommandLine.arguments.contains("--expanded")
            size = NSSize(width: 620, height: 1400)
            host = NSHostingView(rootView: StatsView(model: model).frame(width: size.width, height: size.height))
        case "prefs":
            // **La misura deve essere quella vera della vista** (`.frame(width: 520, height: 620)`).
            // Con 900 il modulo restava centrato in un host più alto e lo snapshot mostrava una
            // fascia vuota di ~140 punti in cima: sembrava un difetto di layout dell'app, ed era
            // un difetto della sonda. Sondato il 2026-07-28.
            size = NSSize(width: 520, height: 620)
            host = NSHostingView(rootView: PrefsView(model: model).frame(width: size.width, height: size.height))
        default:
            size = NSSize(width: 1440, height: 900)
            host = NSHostingView(rootView: BreakView(model: model).frame(width: size.width, height: size.height))
        }
        // Lo sfondo della finestra nell'app vera lo mette AppKit, non la vista: senza, uno
        // snapshot in modalità scura esce bianco su bianco — testo chiaro su niente.
        if surface != "break" {
            host.wantsLayer = true
            // `.cgColor` risolve un colore dinamico contro l'aspetto *corrente del thread*, non
            // contro quello che ho appena messo su NSApp: senza questo, in chiaro lo sfondo
            // resterebbe quello del buio.
            let appearance = NSApp.appearance ?? NSApp.effectiveAppearance
            appearance.performAsCurrentDrawingAppearance {
                host.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
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

    /// `--demo-hud[=secondi]` — fa comparire una notifica e la lascia lì, per provarla a mano.
    ///
    /// Il gesto di scarto non si può provare con `swift test`: dipende da come AppKit consegna il
    /// mouse a un pannello che non prende il fuoco, e quello si vede solo su una notifica vera.
    private func runHudDemoIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--demo-hud") })
        else { return }
        let seconds = arg.split(separator: "=").last.flatMap { Double($0) } ?? 60
        let quote = CommandLine.arguments.contains("--quote")
        if quote, let phrase = model.launchPhrase {
            model.showLaunchPhraseForSeconds(phrase, seconds: seconds)
        } else {
            model.announceForSeconds(title: "Pausa fra un minuto", subtitle: "12 affondi",
                                     seconds: seconds)
        }
        let killswitch = Timer(timeInterval: seconds + 2, repeats: false) { _ in NSApp.terminate(nil) }
        RunLoop.main.add(killswitch, forMode: .common)
    }

    /// `--confirm-probe` — le ripetizioni finiscono nel registro **alla conferma**?
    ///
    /// I test coprono il motore e la traduzione in righe di registro; questa sonda copre il pezzo
    /// che `swift test` non può toccare: il collante dell'app, cioè che l'evento arrivi davvero
    /// alla penna. Gira **senza coprire lo schermo** (modello headless) e **su un registro usa e
    /// getta**, o proverebbe una cosa vera sporcando i dati veri con ripetizioni mai fatte.
    private func runConfirmProbeIfRequested() {
        guard CommandLine.arguments.contains("--confirm-probe") else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-sonda-\(UUID().uuidString).jsonl")
        var s = Settings(exercisePool: [.calfRaise], vigorousPool: [.jumpingJack])
        s.startDate = Date()   // rampa al minimo: l'attesa della sonda resta corta
        s.cadence.longEveryNBreaks = 99

        let probe = AppModel(settings: s, ledger: Ledger(url: url))
        probe.headless = true
        // Durante la sonda nessuno tocca la tastiera: senza questo il motore leggerebbe
        // l'inattività vera e chiuderebbe la pausa come «naturale» prima della conferma.
        probe.idleOverride = 0
        probe.start()
        probe.forceBreakNow()

        guard let plan = probe.plan else { print("nessuna pausa"); NSApp.terminate(nil); return }
        let attesa = plan.exercise.minimumSeconds + 2
        print("esercizio: \(plan.exercise.label) — tempo minimo \(Int(plan.exercise.minimumSeconds)) s")
        print("righe nel registro prima della conferma: \(probe.ledger.entries().count)")

        DispatchQueue.main.asyncAfter(deadline: .now() + attesa) {
            probe.markExerciseDone()
            let righe = probe.ledger.entries()
            print("righe dopo la conferma: \(righe.count)")
            for r in righe {
                print("  \(r.type.rawValue) · \(r.exercise?.rawValue ?? "—") · \(r.reps.map(String.init) ?? "—")")
            }
            let ok = righe.contains { $0.type == .exerciseDone && $0.reps == plan.exercise.reps }
            let pausaAncoraAperta = probe.phase == .breaking
            print("pausa ancora aperta: \(pausaAncoraAperta ? "sì" : "no")")
            print(ok && pausaAncoraAperta
                  ? "RISULTATO: contate alla conferma, a pausa ancora aperta"
                  : "RISULTATO: NON contate alla conferma")
            try? FileManager.default.removeItem(at: url)
            NSApp.terminate(nil)
        }
    }

    /// `--flush-probe` — aprire il recap scrive davvero il tempo non ancora registrato?
    ///
    /// Deterministica di proposito: con inattività finta a zero il modello accumula secondi veri,
    /// e la sonda confronta il registro prima e dopo `flushForDisplay()`. Sull'app vera la stessa
    /// prova sarebbe ambigua — se in quel momento non stai toccando il Mac non c'è niente da
    /// scrivere, e «nessuna riga nuova» significherebbe insieme «funziona» e «non funziona».
    private func runFlushProbeIfRequested() {
        guard CommandLine.arguments.contains("--flush-probe") else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-flush-\(UUID().uuidString).jsonl")
        let probe = AppModel(settings: Settings(), ledger: Ledger(url: url))
        probe.headless = true
        probe.idleOverride = 0
        probe.start()
        print("righe prima: \(probe.ledger.entries().count) — accumulo 4 secondi di lavoro")

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            let prima = probe.ledger.entries().count
            probe.flushForDisplay()
            let righe = probe.ledger.entries()
            let scritte = righe.filter { $0.type == .active }
            print("righe prima dello svuotamento: \(prima)")
            print("righe dopo: \(righe.count)")
            for r in scritte { print(String(format: "  active · %.0f s", r.seconds ?? 0)) }
            let ok = scritte.count == 1 && (scritte.first?.seconds ?? 0) >= 3 && (scritte.first?.seconds ?? 0) < 300
            print(ok ? "RISULTATO: l'apertura scrive il tempo parziale, senza aspettare i 5 minuti"
                     : "RISULTATO: l'apertura NON scrive niente")
            try? FileManager.default.removeItem(at: url)
            NSApp.terminate(nil)
        }
    }

    /// `--orphan-probe` — quando la pausa la chiude il **motore**, lo schermo si libera davvero?
    ///
    /// È la sonda dell'incidente del 27 e 28 luglio 2026. Ti allontani mentre la schermata di
    /// blocco è aperta, il motore supera la soglia d'assenza e chiude la pausa da solo come
    /// «naturale» — e la finestra restava lì. Nera, perché senza `plan` la vista non disegna
    /// niente; senza uscita, perché l'uscita d'emergenza è guardata dalla fase del motore, che nel
    /// frattempo è tornata a `working`; e inchiodata, perché le opzioni chiosco erano ancora
    /// attive. Due volte è finita col tasto di accensione.
    ///
    /// `swift test` non può vederlo: il difetto non sta nel motore — che fa la cosa giusta — ma
    /// nel collante fra motore e finestre. La prova è lo stato reale di AppKit dopo il tick.
    ///
    /// Copre lo schermo per davvero, per ~5 secondi. Deve: una sonda che non lo copre proverebbe
    /// un'altra cosa. Due reti, e sono indipendenti: il guardiano gira su un **thread staccato**,
    /// quindi scatta anche se il run loop principale si inchioda, ed `exit()` porta via con sé
    /// finestre e chiosco; poi lo smontaggio esplicito prima di ogni uscita ordinata.
    private func runOrphanProbeIfRequested() {
        guard CommandLine.arguments.contains("--orphan-probe") else { return }

        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 20)
            FileHandle.standardError.write("sonda: guardiano scattato\n".data(using: .utf8)!)
            exit(3)
        }

        // Quale rete si spegne. Provate tutte insieme, le tre reti dimostrerebbero soltanto che
        // *almeno una* funziona: per sapere se reggono da sole vanno tolte una per volta.
        SafetyNets.modelReconcile = !CommandLine.arguments.contains("--senza-rete-modello")
            && !CommandLine.arguments.contains("--senza-reti")
        SafetyNets.blockerWatchdog = !CommandLine.arguments.contains("--senza-reti")
        let attesa = !SafetyNets.modelReconcile && !SafetyNets.blockerWatchdog
        print("rete del modello: \(SafetyNets.modelReconcile ? "accesa" : "SPENTA")")
        print("battito della finestra: \(SafetyNets.blockerWatchdog ? "acceso" : "SPENTO")")
        print(attesa
              ? "atteso: schermo ANCORA coperto (controllo negativo), poi liberato dall'uscita d'emergenza"
              : "atteso: schermo liberato")

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-orfana-\(UUID().uuidString).jsonl")
        var s = Settings(exercisePool: [.calfRaise], vigorousPool: [.jumpingJack])
        s.startDate = Date()
        // Micro-pausa: soglia d'assenza 210 s invece di 420, e la sonda resta corta.
        s.cadence.longEveryNBreaks = 99

        let probe = AppModel(settings: s, ledger: Ledger(url: url))
        probe.idleOverride = 0
        probe.start()
        probe.forceBreakNow()

        func scudi() -> Int { NSApp.windows.filter { $0 is BlockerWindow && $0.isVisible }.count }
        func smonta() {
            NSApp.presentationOptions = []
            for w in NSApp.windows where w is BlockerWindow { w.orderOut(nil) }
            try? FileManager.default.removeItem(at: url)
        }

        print("fase all'apertura: \(probe.phase.rawValue) — finestre di blocco visibili: \(scudi())")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let soglia = probe.plan.map { SessionEngine.absentThreshold(for: $0) } ?? 210
            probe.idleOverride = soglia + 10
            print(String(format: "inattività finta: %.0f s (soglia d'assenza %.0f)", soglia + 10, soglia))
        }

        // A 7 secondi il motore ha chiuso da un pezzo e il battito da 2 s ha avuto tre giri.
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            let fase = probe.phase
            let rimaste = scudi()
            let chiosco = NSApp.presentationOptions
            print("fase dopo l'assenza: \(fase.rawValue)")
            print("finestre di blocco ancora visibili: \(rimaste)")
            print("opzioni chiosco ancora attive: \(chiosco.rawValue)")

            guard attesa else {
                let ok = fase != .breaking && rimaste == 0 && chiosco.isEmpty
                print(ok
                      ? "RISULTATO: PASS — la pausa chiusa dal motore libera lo schermo"
                      : "RISULTATO: FAIL — schermo ancora coperto a pausa chiusa (il nero senza uscita)")
                smonta()
                exit(ok ? 0 : 1)
            }

            // Controllo negativo: senza reti il guasto deve ricomparire, o le reti non stavano
            // reggendo niente. E poi l'ultima via d'uscita, quella che deve funzionare **proprio
            // qui**: due Esc, cioè `emergencyExit()`, con il motore che non ha niente da chiudere.
            let guastoRiprodotto = rimaste > 0
            print(guastoRiprodotto
                  ? "controllo negativo: guasto riprodotto, le reti erano davvero portanti"
                  : "controllo negativo FALLITO: senza reti lo schermo si libera lo stesso — le reti non provano niente")
            probe.emergencyExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let dopo = scudi()
                let chioscoDopo = NSApp.presentationOptions
                print("dopo l'uscita d'emergenza — finestre: \(dopo), chiosco: \(chioscoDopo.rawValue)")
                let ok = guastoRiprodotto && dopo == 0 && chioscoDopo.isEmpty
                print(ok
                      ? "RISULTATO: PASS — l'uscita d'emergenza smonta lo scudo anche a motore già chiuso"
                      : "RISULTATO: FAIL — nemmeno l'uscita d'emergenza libera lo schermo")
                smonta()
                exit(ok ? 0 : 1)
            }
        }
    }

    /// `--radar-probe` — il radar viene davvero interrogato ogni 3 secondi, e ogni secondo durante
    /// il preavviso?
    ///
    /// Conta le interrogazioni vere, non le stima. Il polo di controllo è dentro la sonda stessa e
    /// non serve un secondo binario: il preavviso **è** il percorso non rallentato, quindi se il
    /// rallentamento non funzionasse le due fasi darebbero lo stesso ritmo, ed è esattamente la
    /// condizione che fa fallire la sonda.
    private func runRadarProbeIfRequested() {
        guard CommandLine.arguments.contains("--radar-probe") else { return }
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 40)
            FileHandle.standardError.write("sonda: guardiano scattato\n".data(using: .utf8)!)
            exit(3)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-radar-\(UUID().uuidString).jsonl")
        let probe = AppModel(settings: Settings(), ledger: Ledger(url: url))
        probe.headless = true
        probe.idleOverride = 0
        probe.start()
        let lavoro = 12.0, preavviso = 5.0

        DispatchQueue.main.asyncAfter(deadline: .now() + lavoro) {
            let aCampioni = probe.environmentSamples
            let aRitmo = Double(aCampioni) / lavoro
            print(String(format: "fase working: %d interrogazioni in %.0f s → %.2f/s",
                         aCampioni, lavoro, aRitmo))

            // Spinta oltre l'intervallo: il prossimo battito entra nel preavviso, dove si torna
            // a guardare a ogni secondo perché lì il valore decide se la pausa parte o si rimanda.
            probe.declareTimeAlreadySeated(minutes: Int(probe.settings.cadence.intervalSeconds / 60) + 1)

            DispatchQueue.main.asyncAfter(deadline: .now() + preavviso) {
                let bCampioni = probe.environmentSamples - aCampioni
                let bRitmo = Double(bCampioni) / preavviso
                print("fase: \(probe.phase.rawValue)")
                print(String(format: "fase warning: %d interrogazioni in %.0f s → %.2f/s",
                             bCampioni, preavviso, bRitmo))
                let ok = probe.phase == .warning
                    && aRitmo < 0.45 && aRitmo > 0.2          // ~1 ogni 3 s, non 1 al secondo
                    && bRitmo >= aRitmo * 2                    // il preavviso torna al ritmo pieno
                print(String(format: "risparmio in lavoro normale: %.0f%% delle interrogazioni",
                             100 * (1 - aRitmo)))
                print(ok
                      ? "RISULTATO: PASS — 1 interrogazione ogni 3 s lavorando, ogni secondo nel preavviso"
                      : "RISULTATO: FAIL — il ritmo non è quello dichiarato")
                try? FileManager.default.removeItem(at: url)
                exit(ok ? 0 : 1)
            }
        }
    }

    /// `--menu-probe` — quali scorciatoie **promette** il menu, e quali ne ha davvero?
    ///
    /// Nasce dal ⌘S su «Statistiche…»: una combinazione mostrata accanto a una voce si legge come
    /// una scorciatoia di sistema, e qui non poteva esserlo — il menu di uno status item non è il
    /// menu principale, e l'app non registra nessun tasto globale. La sonda stampa quello che il
    /// menu dichiara e lo confronta con quello che l'app può mantenere.
    private func runMenuProbeIfRequested() {
        guard CommandLine.arguments.contains("--menu-probe") else { return }
        let menu = statusItem.menu
        print("menu principale dell'app: \(NSApp.mainMenu == nil ? "nessuno" : "presente")")
        var promesse: [String] = []
        for item in menu?.items ?? [] where !item.keyEquivalent.isEmpty {
            let mods = item.keyEquivalentModifierMask
            let simboli = (mods.contains(.command) ? "⌘" : "")
                + (mods.contains(.control) ? "⌃" : "")
                + (mods.contains(.option) ? "⌥" : "")
                + (mods.contains(.shift) ? "⇧" : "")
            print("  «\(item.title)» → \(simboli.isEmpty ? "(nuda) " : simboli)\(item.keyEquivalent.uppercased())")
            if mods.contains(.command), item.action != #selector(NSApplication.terminate(_:)) {
                promesse.append(item.title)
            }
        }
        let ok = promesse.isEmpty
        print(ok
              ? "RISULTATO: PASS — nessuna voce promette una scorciatoia globale che l'app non ha"
              : "RISULTATO: FAIL — promettono ⌘ senza poterlo mantenere: \(promesse.joined(separator: ", "))")
        NSApp.terminate(nil)
        exit(ok ? 0 : 1)
    }

    /// `--sleep-probe` — mentre il Mac dorme o lo schermo è bloccato, lo scudo si toglie di mezzo
    /// e poi torna?
    ///
    /// Cosa prova e cosa **non** prova, detto subito: prova la mia logica di sospensione e
    /// ripresa, sollecitata con le stesse notifiche che manda il sistema (`com.apple.screenIsLocked`
    /// e la sua gemella), postate qui a mano. Non prova che macOS le mandi davvero — quello è
    /// comportamento documentato del sistema, non codice mio, e una sonda che addormenta il Mac
    /// per verificarlo costerebbe più di quanto vale.
    private func runSleepProbeIfRequested() {
        guard CommandLine.arguments.contains("--sleep-probe") else { return }

        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 20)
            FileHandle.standardError.write("sonda: guardiano scattato\n".data(using: .utf8)!)
            exit(3)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-sonno-\(UUID().uuidString).jsonl")
        var s = Settings(exercisePool: [.calfRaise], vigorousPool: [.jumpingJack])
        s.startDate = Date()
        s.cadence.longEveryNBreaks = 99
        let probe = AppModel(settings: s, ledger: Ledger(url: url))
        probe.idleOverride = 0
        probe.start()
        probe.forceBreakNow()

        func scudi() -> Int { NSApp.windows.filter { $0 is BlockerWindow && $0.isVisible }.count }
        func manda(_ nome: String) {
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name(nome), object: nil, userInfo: nil, deliverImmediately: true
            )
        }

        let apertura = (scudi(), NSApp.presentationOptions.rawValue)
        print("a pausa aperta — finestre: \(apertura.0), chiosco: \(apertura.1)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { manda("com.apple.screenIsLocked") }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let bloccato = (scudi(), NSApp.presentationOptions.rawValue, probe.phase)
            print("a schermo bloccato — finestre: \(bloccato.0), chiosco: \(bloccato.1), fase: \(bloccato.2.rawValue)")
            manda("com.apple.screenIsUnlocked")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let ripreso = (scudi(), NSApp.presentationOptions.rawValue)
                print("a schermo sbloccato — finestre: \(ripreso.0), chiosco: \(ripreso.1)")
                let ok = apertura.0 == 1
                    && bloccato.0 == 0 && bloccato.1 == 0     // tolto di mezzo, chiosco smontato
                    && bloccato.2 == .breaking                 // ma la pausa NON è stata condonata
                    && ripreso.0 == 1 && ripreso.1 == apertura.1
                print(ok
                      ? "RISULTATO: PASS — lo scudo si ritira al blocco schermo e torna allo sblocco, pausa intatta"
                      : "RISULTATO: FAIL — la sospensione non si comporta come dichiarato")
                NSApp.presentationOptions = []
                for w in NSApp.windows where w is BlockerWindow { w.orderOut(nil) }
                try? FileManager.default.removeItem(at: url)
                exit(ok ? 0 : 1)
            }
        }
    }

    /// `--window-probe=<superficie>` — costruisce una finestra e **misura** se ci sta nello schermo.
    ///
    /// Esiste per lo stesso motivo di `--snapshot`: il difetto delle fonti — finestra più alta del
    /// monitor, fondo fuori dallo schermo — non si vede in uno screenshot del contenuto, perché il
    /// contenuto era giusto. Si vede solo confrontando l'altezza della finestra con l'area
    /// visibile, ed è quello che stampa questa sonda. Una misura, non un'impressione.
    private func runWindowProbeIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--window-probe=") }),
              let surface = arg.split(separator: "=", maxSplits: 1).last.map(String.init)
        else { return }

        let content: NSView
        switch surface {
        case "prefs":
            content = NSHostingView(rootView: PrefsView(model: model))
        case "stats":
            let view = NSHostingView(rootView: StatsView(model: model))
            view.frame = NSRect(x: 0, y: 0, width: 620, height: 680)
            content = view
        default:
            let view = NSHostingView(rootView: EvidenceView())
            view.frame = NSRect(x: 0, y: 0, width: 640, height: 620)
            content = view
        }

        let visible = (NSScreen.main ?? NSScreen.screens.first)!.visibleFrame
        let wanted = content.fittingSize
        let window = makeWindow(title: "sonda", content: content)
        let frame = window.frame

        print("superficie: \(surface)")
        print(String(format: "area visibile dello schermo: %.0f × %.0f", visible.width, visible.height))
        print(String(format: "altezza che il contenuto chiederebbe: %.0f", wanted.height))
        print(String(format: "finestra costruita: %.0f × %.0f a y=%.0f", frame.width, frame.height, frame.minY))
        let fits = frame.height <= visible.height && frame.minY >= visible.minY - 1
        print(fits ? "STA NELLO SCHERMO" : "ESCE DALLO SCHERMO")
        print("ridimensionabile: \(window.styleMask.contains(.resizable) ? "sì" : "no")")
        NSApp.terminate(nil)
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
        // **Niente ⌘ in questo menu, ed è una questione di onestà, non di gusto.**
        //
        // Questo non è il menu principale di un'app in primo piano: è il menu di uno status item,
        // e Otium non registra nessuna scorciatoia di sistema (nessun `RegisterEventHotKey`,
        // nessun monitor globale — verificato sul sorgente il 2026-07-28). Le sue combinazioni
        // valgono **solo mentre il menu è aperto**. Scriverci accanto ⌘S significava promettere
        // una scorciatoia globale che non esiste, e prendersi per giunta il tasto di Salva:
        // segnalato dal principale, che se l'è trovato addosso in un'altra app.
        //
        // Restano lettere nude, che a menu aperto funzionano davvero e non promettono niente
        // altrove. ⌘Q su «Esci» sopravvive perché lì il simbolo non si legge come una promessa:
        // si legge come «questa è la voce che chiude», ed è la convenzione di ogni menu su macOS.
        let stats = NSMenuItem(title: "Statistiche…", action: #selector(showStats), keyEquivalent: "s")
        stats.keyEquivalentModifierMask = []
        menu.addItem(stats)
        menu.addItem(NSMenuItem(title: "Da dove vengono questi numeri…", action: #selector(showEvidence), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Apri il registro", action: #selector(revealLedger), keyEquivalent: ""))
        let prefs = NSMenuItem(title: "Preferenze…", action: #selector(showPrefs), keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = []
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Esci da Otium", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != nil && item.target == nil {
            if item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        }
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.flushForDisplay()
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
        // Il tempo attivo non ancora scritto va nel registro **adesso**: la finestra lo legge da
        // lì, e deve trovarci anche l'ultimo minuto.
        model.flushForDisplay()
        // **Contenuto nuovo a ogni apertura.** Una finestra nascosta non ridisegna: riaprendola
        // mostrava per un istante i numeri di quando l'avevi chiusa, e poi si aggiornava sotto
        // gli occhi al primo battito. Segnalato guardandolo succedere il 2026-07-27.
        let view = NSHostingView(rootView: StatsView(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 620, height: 680)
        if statsWindow == nil {
            statsWindow = makeWindow(title: "Otium — statistiche", content: view)
        } else {
            statsWindow?.contentView = view
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

    /// Una finestra che ci sta **dentro lo schermo**, e che si può ridimensionare.
    ///
    /// Difetto segnalato il 2026-07-27 sulle fonti: `fittingSize` di una `ScrollView` è l'altezza
    /// del contenuto **srotolato** — qui oltre 3000 punti — quindi la finestra nasceva più alta
    /// del monitor, veniva centrata, e il fondo restava fuori dallo schermo. Lo scorrimento
    /// arrivava in fondo al contenuto e sembrava comunque tagliato, perché tagliata era la
    /// finestra. Senza `.resizable` non si poteva nemmeno rimediare a mano.
    ///
    /// Il tetto è l'area **visibile** (`visibleFrame`: già al netto di barra dei menu e Dock),
    /// con un margine perché una finestra alta esattamente quanto lo schermo tocca i bordi.
    private func makeWindow(title: String, content: NSView) -> NSWindow {
        let wanted = content.frame.size.width > 0 ? content.frame.size : content.fittingSize
        let requested = wanted.width > 0 ? wanted : NSSize(width: 560, height: 560)
        let limit = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size
            ?? NSSize(width: 1200, height: 800)
        let size = NSSize(
            width: min(requested.width, limit.width - 40),
            height: min(requested.height, limit.height - 40)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
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

// **Prima di qualunque altra cosa**, perché il lock dell'istanza unica e il primo `AppModel`
// vengono dopo: se questa esecuzione è una sonda o una resa, i dati veri non si toccano.
if ProbeMode.active {
    Paths.overrideDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("otium-sonda-\(UUID().uuidString)", isDirectory: true)
    Paths.ensureDirectory()
}

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
