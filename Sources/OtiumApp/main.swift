import AppKit
import Carbon.HIToolbox
import SwiftUI
import OtiumCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {

    private let model = AppModel()
    private var statusItem: NSStatusItem!
    private var prefsWindow: NSWindow?
    private var evidenceWindow: NSWindow?
    private var statsWindow: NSWindow?
    private var seatedWindow: NSWindow?
    private var declareWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var paceWindow: NSWindow?
    private var growthWindow: NSWindow?
    private var doctorWindow: NSWindow?
    private var refreshTimer: Timer?
    /// L'ultima scritta consegnata alla barra: serve a non riscriverla identica ogni secondo.
    private var lastStatusTitle: String?
    /// La voce «Modalità Zen» del menu, tenuta per riferimento e non ritrovata per titolo: il
    /// titolo è tradotto e cambierebbe con la lingua, il riferimento no.
    private weak var zenItem: NSMenuItem?
    private var statsHotKey: GlobalHotKey?

    /// La scorciatoia globale delle statistiche, scelta dal principale il 2026-07-28: **⌃S**.
    /// Una costante sola perché cambiarla resti un gesto, non una caccia nel file.
    /// Prezzo dichiarato in `GlobalHotKey`: ⌃S smette di arrivare alle altre app (XOFF nei
    /// terminali, ricerca incrementale in Emacs).
    private static let statsHotKeyCode = UInt32(kVK_ANSI_S)
    private static let statsHotKeyModifiers = UInt32(controlKey)

    func applicationDidFinishLaunching(_ notification: Notification) {
        Paths.ensureDirectory()

        // **`--dark` e `--light` valgono per ogni sonda, non solo per la resa fuori schermo.**
        //
        // Stavano dentro `renderSnapshotIfRequested`, quindi `--mostra-prefs --dark` apriva la
        // finestra vera con l'aspetto del Mac in quel momento e ignorava il flag in silenzio. È
        // proprio la coppia che serve guardare adesso, perché la resa fuori schermo la barra
        // laterale non la disegna: la sonda deve poter mostrare la sera anche di giorno.
        if CommandLine.arguments.contains("--dark") {
            NSApp.appearance = NSAppearance(named: .darkAqua)
        } else if CommandLine.arguments.contains("--light") {
            NSApp.appearance = NSAppearance(named: .aqua)
        }

        // Le tre voci passate dal menu alle Preferenze restano azioni dell'`AppDelegate`: qui si
        // dice al modello come chiamarle. Il perché non sono selettori scritti a mano sta su
        // `AppModel.onShowEvidence`. Prima del menu e della vista, o le Preferenze aperte subito
        // troverebbero tre pulsanti muti.
        model.onShowEvidence = { [weak self] in self?.showEvidence() }
        model.onRevealLedger = { [weak self] in self?.revealLedger() }
        model.onShowDoctor = { [weak self] in self?.showDoctor() }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem.menu = buildMenu()
        updateStatusTitle()

        model.start()

        // Da qualunque app, senza permessi. Se il tasto è già di qualcun altro non si finge che
        // vada: si dice, perché una scorciatoia che non c'è e nessuno lo sa è il difetto che ⌘S
        // aveva già.
        if !ProbeMode.active {
            statsHotKey = GlobalHotKey(keyCode: Self.statsHotKeyCode,
                                       carbonModifiers: Self.statsHotKeyModifiers) { [weak self] in
                self?.showStats()
            }
            if statsHotKey == nil {
                FileHandle.standardError.write(
                    "Otium: ⌃S è già di un'altra app, la scorciatoia globale non è attiva\n"
                        .data(using: .utf8)!
                )
            }
        }

        // Il primo avvio chiede due cose e poi sparisce. Non durante le sonde: una finestra
        // modale in mezzo a una misura misura la finestra.
        // `--mostra-onboarding` la riapre anche a scelte già fatte. **Non è una funzione
        // dell'app**: è lo strumento per guardarla mentre la si disegna, e non ha nessun
        // corrispettivo nell'interfaccia — il primo avvio deve restare una cosa che succede una
        // volta sola, non una voce di menu che nessuno userà mai due volte.
        if (model.needsOnboarding || CommandLine.arguments.contains("--mostra-onboarding")),
           !ProbeMode.active {
            showOnboarding()
        } else if model.settings.shouldOfferGrowth(now: Date()) || CommandLine.arguments.contains("--mostra-crescita"),
                  !ProbeMode.active {
            showGrowthCheckIn()
        } else if model.settings.shouldOfferFullPace(now: Date()) || CommandLine.arguments.contains("--mostra-ritmo"),
                  !ProbeMode.active {
            // **Mai insieme all'onboarding.** Chi ha appena installato l'app non ha due settimane
            // di uso alle spalle, e due finestre al primo avvio sono una in più di quelle che
            // qualcuno legge.
            showPaceCheckIn()
        }


        // **Ogni secondo, non ogni cinque.** Con cinque secondi di passo gli ultimi cinque del
        // preavviso non si vedono proprio: la barra ne mostrerebbe uno a caso e salterebbe gli
        // altri quattro. Il costo si paga solo quando c'è qualcosa di nuovo da scrivere, perché
        // `updateStatusTitle` esce senza toccare AppKit se la scritta non è cambiata — e per
        // ventitré minuti su ventiquattro non cambia.
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.updateStatusTitle() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t

        // Una riga da leggere mentre l'app si mette in ascolto. Cambia a ogni avvio.
        // Non durante le sonde: la frase d'avvio **sostituisce** il pannello che si sta provando,
        // e la sonda finirebbe per misurare una superficie diversa da quella che ha chiesto.
        // `--scatta-menu` sta qui per una ragione vista sullo schermo: la frase d'avvio compare
        // dopo sei decimi in un pannello suo, e **chiude il menu** che la sonda ha appena aperto.
        // Il primo scatto era venuto buono per fortuna di tempi, il secondo mostrava la frase e
        // nessun menu.
        if !CommandLine.arguments.contains(where: {
            $0.hasPrefix("--snapshot") || $0.hasPrefix("--demo-hud") || $0.hasPrefix("--scatta-menu")
                || $0.hasPrefix("--segno-zen")
        }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.model.showLaunchQuote()
            }
        }

        // `--zen-acceso` accende la modalità nella cartella usa e getta della sonda: serve a
        // guardare la barra e il menu **come li vede chi l'ha accesa**, che con le impostazioni di
        // serie non si vedrebbero mai.
        if CommandLine.arguments.contains("--zen-acceso"), ProbeMode.active {
            var s = model.settings
            s.zenMode = true
            model.update(settings: s)
            statusItem.menu = buildMenu()
            updateStatusTitle()
        }

        runDemoIfRequested()
        runHudDemoIfRequested()
        renderSnapshotIfRequested()
        captureWindowIfRequested()
        runWindowProbeIfRequested()
        runConfirmProbeIfRequested()
        runFlushProbeIfRequested()
        runOrphanProbeIfRequested()
        runSleepProbeIfRequested()
        runMenuProbeIfRequested()
        captureMenuIfRequested()
        captureBarIfRequested()
        runHotKeyProbeIfRequested()
        runPolicyProbeIfRequested()
        runCircuitProbeIfRequested()
        runStatsPeriodProbeIfRequested()
        runPaceDemoIfRequested()
        runGrowthDemoIfRequested()
        runPrefsDemoIfRequested()
        runLsofProbeIfRequested()
        runRadarProbeIfRequested()
        runCountdownProbeIfRequested()

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
            ? L.t("sospesa, riprendila dal menu", "paused, resume it from the menu")
            : L.t("prossima pausa fra \(model.minutesToNextBreak) min di lavoro attivo", "next break in \(model.minutesToNextBreak) min of active work")
        model.announce(title: L.t("Otium è già attiva", "Otium is already running"), subtitle: subtitle)
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
        // `--inglese` vale per ogni superficie, non solo per l'onboarding: la schermata di
        // blocco in inglese è quella che si vede ogni mezz'ora, ed è l'unica prova che la
        // traduzione sia arrivata dove conta.
        if CommandLine.arguments.contains("--inglese") { L.language = .english }
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
        // `--zen[=protocollo]` fotografa la **modalità Zen**, che altrimenti si vedrebbe solo
        // accendendola nelle preferenze vere. Va prima di `forceBreakNow`, perché è `buildPlan` a
        // decidere se il piano porta un respiro, e un piano già costruito non cambia idea.
        // Siamo dentro `ProbeMode`, quindi queste impostazioni vivono nella cartella usa e getta.
        if let zenArg = CommandLine.arguments.first(where: { $0.hasPrefix("--zen") }) {
            var s = model.settings
            s.zenMode = true
            if let nome = zenArg.split(separator: "=", maxSplits: 1).dropFirst().first.map(String.init),
               let p = BreathProtocol(rawValue: nome) {
                s.zenProtocolShort = p
                s.zenProtocolLong = p
            }
            model.update(settings: s)
        }
        // `--orfana` rende di proposito la schermata **senza piano**: è lo stato che il 27 e il 28
        // luglio 2026 era un rettangolo nero muto, e l'unico modo di sapere com'è adesso è
        // guardarlo. Un `if let` senza `else` non si vede leggendo il codice: si vede nei pixel.
        if !CommandLine.arguments.contains("--orfana") {
            model.forceBreakNow(long: long)
            // `--esercizio=<nome>` rende la pausa con l'esercizio che si vuole **guardare**.
            // Senza, la resa mostra sempre quello che tocca alla rotazione, e un esercizio nuovo
            // — le cui istruzioni sono il prodotto, perche' nessuno sa cosa sia un Y-T-W — si
            // vedrebbe solo per caso, dopo aver lanciato la sonda finche' non esce.
            if let nome = CommandLine.arguments.first(where: { $0.hasPrefix("--esercizio=") })?
                .split(separator: "=", maxSplits: 1).last.map(String.init),
               let kind = ExerciseKind(rawValue: nome) {
                model.swapExercise(to: kind, force: true)
            }
            // `--fatto` fotografa la **seconda faccia** della pausa: esercizio confermato, la
            // frase che prende la pagina, il conto che scende. Senza, la resa mostra sempre e
            // solo il primo minuto e mezzo, cioè metà della schermata che l'app disegna.
            if CommandLine.arguments.contains("--fatto") { model.fastForwardToRest() }
            // `--frase=<n>` fissa quale frase disegnare: senza, la fotografia mostra quella che
            // esce dal mazzo, e una prova sull'impaginazione di un testo preciso diventa una
            // caccia. L'indice è quello che stampa `--tagli`.
            if let n = CommandLine.arguments.first(where: { $0.hasPrefix("--frase=") })?
                .split(separator: "=", maxSplits: 1).last.flatMap({ Int($0) }) {
                model.pinPhrase(n)
            }
            // `--tenuta-da=<secondi>` rende una tenuta **gia' cominciata**: e' l'unico modo di
            // guardare la preparazione e l'avviso del cambio lato, che durano tre secondi e nella
            // vita passano mentre hai la faccia sul pavimento.
            if let secondi = CommandLine.arguments.first(where: { $0.hasPrefix("--tenuta-da=") })?
                .split(separator: "=", maxSplits: 1).last.flatMap({ Double($0) }) {
                model.seedHoldForSnapshot(secondsAgo: secondi)
            }
            // `--respiro-da=<secondi>` è il gemello di `--tenuta-da` per la modalità Zen: il
            // cerchio passa da minimo a massimo in nove secondi, quindi ogni fase del ciclo dura
            // meno di un'inquadratura. Senza questo si potrebbe fotografare solo la preparazione.
            if let secondi = CommandLine.arguments.first(where: { $0.hasPrefix("--respiro-da=") })?
                .split(separator: "=", maxSplits: 1).last.flatMap({ Double($0) }) {
                model.seedBreathForSnapshot(secondsAgo: secondi)
            }
        }

        // Quale schermata rendere: la pausa di default, ma anche le due superfici che finora
        // non aveva mai guardato nessuno.
        let surface = CommandLine.arguments.first { $0.hasPrefix("--surface=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init) ?? "break"
        // `--surface=provino --misura` non disegna un file: stampa quanto è ALTA ogni frase nella
        // larghezza vera della pausa. Su 492 frasi guardare ogni immagine costa un pomeriggio e
        // non si rifà mai; l'altezza dice in un colpo quali vanno a capo, e quelle si guardano.
        // Il numero è già una risposta, l'immagine resta la prova.
        //
        // `--riposo` misura la **fase di riposo** invece della vecchia collocazione: lì la frase
        // è la pagina, gira a 40 punti e scende a 30 sopra i 95 caratteri, e la domanda «la più
        // lunga ci sta?» ha una risposta sola, che è un numero. Stimarla sarebbe indistinguibile
        // dal non averla misurata.
        if surface == "provino", CommandLine.arguments.contains("--misura") {
            let riposo = CommandLine.arguments.contains("--riposo")
            for (i, p) in PhraseLibrary.breakPool().enumerated() {
                let v = riposo
                    ? NSHostingView(rootView: RestQuote(phrase: p).frame(width: RestQuote.width))
                    : NSHostingView(rootView: QuoteBlock(phrase: p).frame(width: 760))
                print("\(i)\t\(Int(v.fittingSize.height))\t\(p.localizedText.count)\t\(p.localizedText)")
            }
            NSApp.terminate(nil)
            return
        }

        let size: NSSize
        let host: NSView
        switch surface {
        case "provino":
            // **Il provino delle frasi.** `--da=<n> --quante=<n>`, e ogni frase esce nella
            // tipografia vera della pausa perché disegna `QuoteBlock`, la stessa vista che
            // usa `BreakView`.
            //
            // Serve perché il cancello delle citazioni risponde a una domanda più debole di
            // quella che conta: prova che il testo *esiste* nella fonte, non come *suona*
            // mentre stai lì a contare i secondi. Guardarle una per una lanciando l'app 411
            // volte costa venti minuti e nessuno lo fa due volte; qui è una corsa sola.
            let numero = { (arg: String) -> Int? in
                CommandLine.arguments.first { $0.hasPrefix(arg) }?
                    .split(separator: "=", maxSplits: 1).last.flatMap { Int($0) }
            }
            let pool = PhraseLibrary.breakPool()
            let da = max(0, numero("--da=") ?? 0)
            let quante = max(1, numero("--quante=") ?? 25)
            let fette = Array(pool.dropFirst(da).prefix(quante))
            let colonna = VStack(alignment: .center, spacing: 30) {
                ForEach(Array(fette.enumerated()), id: \.element.id) { coppia in
                    HStack(alignment: .top, spacing: 14) {
                        // L'ordinale serve a ritrovare la riga nel sorgente dopo averla vista
                        // storta. Tenuto scialbo di proposito: deve essere leggibile e non
                        // deve entrare nel giudizio su come sta la frase.
                        Text("\(da + coppia.offset)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.dim.opacity(0.5))
                            .frame(width: 34, alignment: .trailing)
                        QuoteBlock(phrase: coppia.element)
                    }
                }
            }
            .padding(.vertical, 34)
            .frame(width: 760)
            .background(Palette.ink)
            let v = NSHostingView(rootView: colonna)
            size = NSSize(width: 760, height: v.fittingSize.height)
            host = v
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
            // `--titolo=` perche' il pannello ha due righe e la sonda ne sapeva guardare una:
            // l'avviso della pausa rimandata ha il titolo corto e il sottotitolo lungo, cioe'
            // esattamente la combinazione che va a capo.
            let titolo = CommandLine.arguments.first { $0.hasPrefix("--titolo=") }?
                .split(separator: "=", maxSplits: 1).last.map(String.init)
                ?? "Otium è già attiva"   // lingua: ok sonda di sviluppo (--surface=hud), non la vede nessun utente
            let hud = NSHostingView(rootView: HUDView(title: titolo, subtitle: testo))
            size = hud.fittingSize
            host = hud
        case "onboarding":
            // Il primo avvio si guarda nelle due lingue: è la prima cosa che vede chi installa
            // l'app, e l'unica schermata che non ha una seconda occasione.
            if CommandLine.arguments.contains("--inglese") { L.language = .english }
            let scelto: Sex? = CommandLine.arguments.contains("--donna") ? .female
                : CommandLine.arguments.contains("--uomo") ? .male : nil
            // `--passo=2` rende la pagina della modalità Zen, che nell'app si vede solo dopo
            // aver premuto Avanti.
            let passo = CommandLine.arguments.contains("--passo=2") ? 2 : 1
            let ob = NSHostingView(rootView: OnboardingView(model: model, onDone: {},
                                                            preselectedSex: scelto,
                                                            initialStep: passo))
            size = NSSize(width: 540, height: ob.fittingSize.height)
            host = ob
        case "crescita":
            let g = NSHostingView(rootView: GrowthCheckInView(model: model, onDone: {}))
            size = NSSize(width: 520, height: g.fittingSize.height)
            host = g
        case "ritmo":
            // `--giorni=N` simula un'installazione di N giorni fa: la finestra ha senso solo
            // dentro la partenza graduale, e a giorno zero mostrerebbe una percentuale che nella
            // vita vera non si vede mai.
            if let g = CommandLine.arguments.first(where: { $0.hasPrefix("--giorni=") })?
                .split(separator: "=", maxSplits: 1).last.flatMap({ Int($0) }) {
                var sim = model.settings
                sim.startDate = Date().addingTimeInterval(-Double(g) * 24 * 3600)
                sim.rampStartFactor = 0.55
                sim.fullPaceAnswered = false
                model.update(settings: sim)
            }
            let pace = NSHostingView(rootView: PaceCheckInView(model: model, onDone: {}))
            size = NSSize(width: 480, height: pace.fittingSize.height)
            host = pace
        case "menu":
            // L'altezza la detta il contenuto, come nel menu vero: un 260 scritto a mano qui
            // avrebbe **riprodotto** la fascia vuota invece di mostrarla sparita.
            let menu = NSHostingView(rootView: MenuPanel(model: model).frame(width: 280))
            size = NSSize(width: 280, height: menu.fittingSize.height)
            host = menu
        case "declare":
            size = NSSize(width: 420, height: 330)
            host = NSHostingView(rootView: DeclareBreakView(model: model, onDone: {}).frame(width: size.width, height: size.height))
        case "seated":
            size = NSSize(width: 460, height: 420)
            host = NSHostingView(rootView: DeclareSeatedView(model: model, onDone: {}).frame(width: size.width, height: size.height))
        case "stats":
            StatsView.expandGroupsForSnapshot = CommandLine.arguments.contains("--expanded")
            if let pagina = CommandLine.arguments.first(where: { $0.hasPrefix("--pagina=") })?
                .split(separator: "=", maxSplits: 1).last
                .flatMap({ StatsView.Page(rawValue: String($0)) }) {
                StatsView.initialPageForSnapshot = pagina
            }
            // La pagina della crescita è alta la metà del riepilogo: renderla a 1400 lascerebbe
            // ottocento punti di carta vuota sotto, che in una fotografia si legge come un
            // difetto di layout e non come una sonda tarata male.
            size = NSSize(width: 620,
                          height: StatsView.initialPageForSnapshot == .allenamento ? 700 : 1400)
            host = NSHostingView(rootView: StatsView(model: model).frame(width: size.width, height: size.height))
        case "prefs":
            // **La misura deve essere quella vera della vista** (`.frame` in fondo a `PrefsView`).
            // Con 900 il modulo restava centrato in un host piu alto e lo snapshot mostrava una
            // fascia vuota di ~140 punti in cima: sembrava un difetto di layout dell'app, ed era
            // un difetto della sonda. Sondato il 2026-07-28, e riallineato il 2026-07-31 quando
            // le preferenze sono passate alla barra laterale (760x580).
            //
            // `--voce=<nome>` sceglie quale pannello rendere: con sei voci, una sonda che sa
            // guardarne una sola guarda un sesto dell'interfaccia e chiama verde il resto.
            let voce = CommandLine.arguments.first { $0.hasPrefix("--voce=") }?
                .split(separator: "=", maxSplits: 1).last
                .flatMap { PrefsView.Section(rawValue: String($0)) } ?? .profilo
            size = NSSize(width: 760, height: 580)
            host = NSHostingView(rootView: PrefsView(model: model, initialSection: voce)
                                    .frame(width: size.width, height: size.height))
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
                // **Lo stesso fondo delle finestre vere**, non più il grigio di sistema. Una
                // sonda che rende un colore che l'app non usa risponde a una domanda che non ho
                // fatto: qui la resa deve essere la finestra, carta o inchiostro che sia.
                host.layer?.backgroundColor = Palette.windowPaperNS.cgColor
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

    /// `--stats-probe` — le statistiche riaperte ripartono da oggi?
    ///
    /// La riga che lo fa è una assegnazione sola dentro `showStats()`, ed è esattamente il tipo
    /// di riga che si crede senza guardare. Qui si mette il periodo su «mese», come se l'avessi
    /// lasciato lì ieri sera, si apre la finestra come la apre il menu, e si stampa cosa mostra.
    /// Stampa `day` se la riparazione tiene, `month` se qualcuno la toglie fra un anno.
    private func runStatsPeriodProbeIfRequested() {
        guard CommandLine.arguments.contains("--stats-probe") else { return }
        model.statsPeriod = .month
        let prima = model.statsPeriod.rawValue
        showStats()
        print("prima: \(prima) → dopo l'apertura: \(model.statsPeriod.rawValue)")
        NSApp.terminate(nil)
    }

    /// `--scatta=<file.png>` — fotografa la **finestra vera**, quella che si è appena aperta.
    ///
    /// È la coppia mancante di `--snapshot`. La resa fuori schermo disegna una vista che non ha
    /// finestra, e lì una barra laterale di sistema non ha né il materiale né la colonna: esce
    /// bianca e vuota, cioè la sonda non arriva dove serve guardare. Questa aspetta che la
    /// finestra sia sullo schermo e ne copia il contenuto, quindi vede quello che vedi tu,
    /// materiali e livrea compresi.
    ///
    /// Va in coppia con una delle sonde che aprono una finestra — `--mostra-prefs`,
    /// `--mostra-crescita`, `--mostra-ritmo`, `--mostra-onboarding` — e con `--dark` o `--light`
    /// per guardare l'altra faccia senza cambiare le impostazioni del Mac.
    private func captureWindowIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--scatta=") }),
              let path = arg.split(separator: "=", maxSplits: 1).last.map(String.init)
        else { return }

        // Due secondi: la finestra si apre, SwiftUI fa il primo giro di layout, i materiali di
        // sistema si risolvono. Sotto il secondo la barra laterale esce a metà.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // **La finestra, non il primo pannello che passa.** `keyWindow` qui è una lotteria:
            // la frase d'avvio compare dopo sei decimi in un pannello che non prende il fuoco, e
            // a seconda di come cade la corsa la sonda fotografava quello — quando ci riusciva.
            // Una finestra con la barra del titolo è l'unica cosa che `--mostra-*` apre.
            guard let window = NSApp.windows.first(where: {
                $0.isVisible && $0.styleMask.contains(.titled) && $0.contentView != nil
            })
            else {
                FileHandle.standardError.write("scatta: nessuna finestra da fotografare\n".data(using: .utf8)!)
                NSApp.terminate(nil); return
            }

            // **`cacheDisplay` non basta, e il motivo è la ragione per cui questa sonda esiste.**
            // Copia quello che le viste disegnano da sé; i materiali di sistema — la barra
            // laterale, i vetri smerigliati — li compone il server delle finestre, non la vista,
            // quindi da lì escono bianchi e vuoti. È lo stesso buco della resa fuori schermo, un
            // passo più in là. `screencapture -l` invece fotografa la finestra **sullo schermo**,
            // cioè l'unica immagine che risponde alla domanda «com'è venuta».
            let scatto = Process()
            scatto.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            scatto.arguments = ["-x", "-o", "-l\(window.windowNumber)", path]
            try? scatto.run()
            scatto.waitUntilExit()
            print(path)
            NSApp.terminate(nil)
        }
    }

    /// `--scatta-menu=<file.png>` — fotografa il **menu della barra aperto**, che è l'unica
    /// superficie dell'app che nessuna resa fuori schermo sa disegnare: lo compone il server delle
    /// finestre quando lo apri, e `--scatta` non lo vede perché non è una finestra dell'app.
    ///
    /// Serve alla regola che dice di guardare la **pagina intera** dopo averne toccato una voce:
    /// una spunta giusta in mezzo a voci sbagliate resta un menu sbagliato, e il difetto sta nella
    /// relazione fra le righe, non nella riga.
    ///
    /// Lo scatto lo fa un processo esterno perché aprire il menu **blocca** questo: `performClick`
    /// non ritorna finché il menu è aperto. Lo stesso processo poi chiude l'app, così l'uscita non
    /// dipende da un run loop che sta girando dentro il tracking del menu.
    ///
    /// Con `--zen-acceso` la modalità Zen parte accesa: serve a guardare **la spunta**, che con le
    /// impostazioni di serie non si disegnerebbe mai.
    private func captureMenuIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--scatta-menu=") }),
              let path = arg.split(separator: "=", maxSplits: 1).last.map(String.init)
        else { return }

        // **La regione si calcola tardi, non subito.** A fine avvio la finestra del pulsante nella
        // barra ha ancora frame zero, e `screencapture` riceveva un rettangolo fuori da ogni
        // schermo — risponde «does not intersect any displays» e non scatta niente. Ritagliare
        // invece di prendere lo schermo intero serve a non portarsi dietro la scrivania di chi
        // lancia la sonda.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            let finestra = self.statusItem.button?.window?.frame ?? .zero
            let altezzaSchermo = NSScreen.main?.frame.height ?? 900
            // Il menu si apre **a destra** del pulsante e si allarga fin dove serve: ancorare il
            // ritaglio al bordo destro dello schermo è l'unico modo di prenderlo tutto. Il primo
            // giro l'aveva tagliato a metà, e mezza pagina non risponde alla domanda per cui la
            // sonda esiste.
            let larghezzaSchermo = NSScreen.main?.frame.width ?? 1440
            let larghezza = 460
            let x = Int(max(0, min(finestra.minX - 40, larghezzaSchermo - CGFloat(larghezza))))
            let y = Int(max(0, altezzaSchermo - finestra.maxY))
            let regione = "\(x),\(y),\(larghezza),680"

            let pid = ProcessInfo.processInfo.processIdentifier
            let esterno = Process()
            esterno.executableURL = URL(fileURLWithPath: "/bin/sh")
            esterno.arguments = ["-c",
                                 "sleep 1.5; /usr/sbin/screencapture -x -o -R\(regione) '\(path)'; kill \(pid)"]
            try? esterno.run()

            // Apre il menu e non torna finché resta aperto: da qui comanda il processo esterno,
            // che scatta e chiude.
            self.statusItem.button?.performClick(nil)
        }
    }

    /// `--scatta-barra=<file.png>` — fotografa **solo la propria voce nella barra**, senza aprire
    /// niente.
    ///
    /// Serve a scegliere un simbolo guardandolo. Lanciare più istanze insieme e fotografare tutta
    /// la barra sembrava più furbo e non lo è: l'ordine con cui gli status item si dispongono
    /// dipende da chi parte per primo, quindi in una foto sola non sai più quale segno è quale. Una
    /// istanza per volta, ritagliata sul proprio rettangolo, toglie l'ambiguità.
    private func captureBarIfRequested() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--scatta-barra=") }),
              let path = arg.split(separator: "=", maxSplits: 1).last.map(String.init)
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, let finestra = self.statusItem.button?.window?.frame else {
                NSApp.terminate(nil); return
            }
            let altezzaSchermo = NSScreen.main?.frame.height ?? 900
            let x = Int(max(0, finestra.minX - 12))
            let y = Int(max(0, altezzaSchermo - finestra.maxY))
            let w = Int(finestra.width + 24)
            let h = Int(min(finestra.height, 40))

            let scatto = Process()
            scatto.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            scatto.arguments = ["-x", "-o", "-R\(x),\(y),\(w),\(h)", path]
            try? scatto.run()
            scatto.waitUntilExit()
            print(path)
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
        // `--lunga` pesca la frase **più lunga del mazzo** invece di una a caso.
        //
        // La domanda a cui deve rispondere è «una frase lunga viene tagliata?», e una pescata a
        // caso non risponde: se esce corta si vede una scatola sana e si conclude che va tutto
        // bene. Il caso peggiore va **scelto**, non sperato.
        let piuLunga = CommandLine.arguments.contains("--lunga")
        let scelta = piuLunga
            ? PhraseLibrary.launchPool().max { $0.localizedText.count < $1.localizedText.count }
            : model.launchPhrase
        // `--circuito` mostra il preavviso **vero** di una pausa piena in circuito, costruito dal
        // motore e scritto da `upcomingSubtitle`. Serve a guardare la riga che il principale ha
        // visto sbagliata il 2026-08-04: una stringa giusta in un test può ancora entrare storta
        // nel pannello, e il pannello si guarda.
        let circuito = CommandLine.arguments.contains("--circuito")
        if quote, let phrase = scelta {
            model.showLaunchPhraseForSeconds(phrase, seconds: seconds)
        } else if circuito {
            var s = Settings()
            s.startDate = Date()
            s.circuitMode = .subito
            let finto = AppModel(settings: s, ledger: Ledger(url: FileManager.default
                .temporaryDirectory.appendingPathComponent("otium-demo-\(UUID().uuidString).jsonl")))
            finto.headless = true
            finto.forceBreakNow(long: true)
            let riga = finto.plan.map { finto.upcomingSubtitle($0) } ?? "?"
            model.announceForSeconds(title: L.t("Pausa piena fra un minuto", "Full break in one minute"),
                                     subtitle: riga, seconds: seconds)
        } else {
            model.announceForSeconds(title: "Pausa fra un minuto", subtitle: "12 affondi",   // lingua: ok sonda di sviluppo (--demo-hud)
                                     seconds: seconds)
        }
        // **Il margine è largo di proposito.** Con `seconds + 2` l'app moriva subito dopo la
        // scadenza nominale, e una sonda che verifica il passaggio del mouse — che la notifica la
        // tiene VIVA oltre quella scadenza — misurava la morte del processo invece del
        // comportamento. Successo davvero il 2026-08-11: due poli entrambi «SPARITO», e il difetto
        // era nella sonda. Trenta secondi lasciano spazio per osservare, e la sonda a mano non se
        // ne accorge.
        let killswitch = Timer(timeInterval: seconds + 30, repeats: false) { _ in NSApp.terminate(nil) }
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

    /// `--conto-probe` — nella barra dei menu si leggono davvero 60s, 30s, 5, 4, 3, 2, 1?
    ///
    /// **Legge il titolo dell'elemento nella barra, non il modello.** È la differenza che conta:
    /// il numero giusto calcolato da `Countdown` non serve a niente se il timer che lo consegna ad
    /// AppKit gira ogni cinque secondi, ed è esattamente com'era fino a oggi — gli ultimi cinque
    /// secondi non sarebbero mai comparsi. Una sonda sul modello avrebbe detto PASS lo stesso.
    ///
    /// Il polo negativo è la lunghezza della sequenza: un conto che scorre al secondo produce
    /// sessanta scritte diverse invece di sette, e la sonda fallisce.
    private func runCountdownProbeIfRequested() {
        guard CommandLine.arguments.contains("--conto-probe") else { return }
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 120)
            FileHandle.standardError.write("sonda: guardiano scattato\n".data(using: .utf8)!)
            exit(3)
        }

        model.headless = true          // la pausa in fondo al preavviso non copre lo schermo
        model.idleOverride = 0         // nessuno tocca la tastiera durante una sonda
        var s = model.settings
        s.cadence.intervalSeconds = 120
        s.cadence.warningSeconds = 60
        model.update(settings: s)
        model.declareTimeAlreadySeated(minutes: 2)   // il prossimo battito entra nel preavviso

        var viste: [String] = []
        let campionatore = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let titolo = self?.statusItem.button?.title else { return }
            if viste.last != titolo { viste.append(titolo) }
        }
        RunLoop.main.add(campionatore, forMode: .common)

        DispatchQueue.main.asyncAfter(deadline: .now() + 64) {
            campionatore.invalidate()
            print("scritte lette nella barra: \(viste.joined(separator: " → "))")
            let conto = viste.filter { $0.hasSuffix("s") }
            let attese = ["60s", "30s", "5s", "4s", "3s", "2s", "1s"]
            let inOrdine = conto.filter(attese.contains) == attese
            let ok = inOrdine && conto.count <= attese.count + 1   // + l'eventuale 0s a filo di pausa
            print(ok
                  ? "RISULTATO: PASS — la barra mostra i sette gradini, in ordine"
                  : "RISULTATO: FAIL — attesi \(attese), letti \(conto)")
            exit(ok ? 0 : 1)
        }
    }

    /// `--demo-ritmo` — la domanda delle due settimane, **come la vede chi ci è dentro**.
    ///
    /// Simula un'installazione di due settimane fa ancora in partenza graduale, che è l'unico
    /// stato in cui quella finestra compare nella vita vera. Gira dentro `ProbeMode`, quindi i
    /// dati veri del principale non li tocca: se premi un pulsante, la scelta finisce in una
    /// cartella usa e getta. È il motivo per cui una demo può essere premuta davvero.
    private func runPaceDemoIfRequested() {
        guard CommandLine.arguments.contains("--demo-ritmo") else { return }
        let giorni = CommandLine.arguments.first { $0.hasPrefix("--giorni=") }?
            .split(separator: "=", maxSplits: 1).last.flatMap { Int($0) } ?? 14

        var s = Settings()
        s.startDate = Date().addingTimeInterval(-Double(giorni) * 24 * 3600)
        s.sex = .male
        s.language = model.settings.language ?? .italian
        L.language = s.language ?? .italian

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-demo-\(UUID().uuidString).jsonl")
        let finto = AppModel(settings: s, ledger: Ledger(url: url))
        print("installazione simulata di \(giorni) giorni fa")
        // Anche la diagnostica passa dalla regola dell'articolo: una sonda che stampa «al 85%»
        // mentre la finestra che misura dice «all'85%» è una sonda che si contraddice.
        print("oggi sarebbe \(ItalianNumber.al(Int(s.rampFactor(now: Date()) * 100)))% delle ripetizioni piene")
        print("la domanda comparirebbe: \(s.shouldOfferFullPace(now: Date()) ? "sì" : "no")")

        let hosting = NSHostingView(rootView: PaceCheckInView(model: finto) { NSApp.terminate(nil) })
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: hosting.fittingSize.height)
        let w = makeWindow(title: L.t("Otium", "Otium"), content: hosting)
        present(w)
        paceWindow = w
        // Una demo che resta aperta per sempre diventa una finestra dimenticata.
        let killswitch = Timer(timeInterval: 600, repeats: false) { _ in NSApp.terminate(nil) }
        RunLoop.main.add(killswitch, forMode: .common)
    }

    /// `--lsof-probe` — durante il lavoro normale l'app lancia processi esterni?
    ///
    /// Nato dall'audit: chiedere quale documento hai aperto costa un `lsof`, ed era l'operazione
    /// più cara che Otium facesse. Adesso si chiede solo nel preavviso. La sonda conta i lanci
    /// veri in tutte e due le fasi, invece di fidarsi del ramo `if`.
    private func runLsofProbeIfRequested() {
        guard CommandLine.arguments.contains("--lsof-probe") else { return }
        Thread.detachNewThread {
            Thread.sleep(forTimeInterval: 60)
            FileHandle.standardError.write("sonda: guardiano scattato\n".data(using: .utf8)!)
            exit(3)
        }
        var s = Settings()
        s.startDate = Date()
        s.detectQuietPresence = true
        s.cadence.intervalSeconds = 12          // il preavviso arriva presto
        s.cadence.warningSeconds = 8
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-lsof-\(UUID().uuidString).jsonl")
        let probe = AppModel(settings: s, ledger: Ledger(url: url))
        probe.headless = true
        probe.idleOverride = 0
        PresenceRadar.resetForProbe()
        probe.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 11) {
            let lavorando = PresenceRadar.documentLookups
            print("fase \(probe.phase.rawValue) dopo 11 s — lanci di lsof: \(lavorando)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                let dopo = PresenceRadar.documentLookups
                print("fase \(probe.phase.rawValue) dopo altri 10 s — lanci totali: \(dopo)")
                // Il preavviso può non essere raggiunto se l'app in primo piano non è da lettura:
                // in quel caso `lsof` non serve comunque, e la sonda misura solo il primo polo.
                // **Controllo del contatore.** Un contatore fermo a zero non prova niente se non
                // sa contare: prima di credere allo zero, si chiama `lsof` a mano e si pretende
                // che il numero si muova. È lo stesso principio del test negativo.
                _ = PresenceRadar.openDocument(pid: ProcessInfo.processInfo.processIdentifier)
                let dopoLaProva = PresenceRadar.documentLookups
                print("controllo del contatore — dopo una chiamata diretta: \(dopoLaProva)")

                let contatoreVivo = dopoLaProva == dopo + 1
                let ok = lavorando == 0 && contatoreVivo
                if !contatoreVivo { print("  il contatore non conta: lo zero qui sopra non vale niente") }
                print(ok
                      ? "RISULTATO: PASS — lavorando non lancia nessun processo esterno, e il contatore lo sa vedere"
                      : "RISULTATO: FAIL — \(lavorando) lanci di lsof durante il lavoro normale")
                try? FileManager.default.removeItem(at: url)
                exit(ok ? 0 : 1)
            }
        }
    }

    /// `--demo-crescita` — la domanda della settimana al 100%, come la vede chi ci è dentro.
    /// Ermetica come `--demo-ritmo`: premere un pulsante non tocca i dati veri.
    private func runGrowthDemoIfRequested() {
        guard CommandLine.arguments.contains("--demo-crescita") else { return }
        var s = Settings()
        s.startDate = Date().addingTimeInterval(-40 * 24 * 3600)
        s.rampStartFactor = 1.0
        s.fullReachedAt = Date().addingTimeInterval(-8 * 24 * 3600)
        s.sex = model.settings.sex
        s.language = model.settings.language ?? .italian
        L.language = s.language ?? .italian

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-crescita-\(UUID().uuidString).jsonl")
        let finto = AppModel(settings: s, ledger: Ledger(url: url))
        print("al 100% da 8 giorni · la domanda comparirebbe: \(s.shouldOfferGrowth(now: Date()) ? "sì" : "no")")

        let hosting = NSHostingView(rootView: GrowthCheckInView(model: finto) { NSApp.terminate(nil) })
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: hosting.fittingSize.height)
        let w = makeWindow(title: L.t("Otium", "Otium"), content: hosting)
        present(w)
        growthWindow = w
        let killswitch = Timer(timeInterval: 600, repeats: false) { _ in NSApp.terminate(nil) }
        RunLoop.main.add(killswitch, forMode: .common)
    }

    /// `--circuit-probe` — alla fine di un circuito la notifica dice **tutto** il giro?
    ///
    /// Il difetto era reale e visto dal principale: quattro stazioni fatte, e il banner ne
    /// nominava una. La sonda costruisce una pausa piena col circuito attraverso il motore vero e
    /// legge la riga che finirebbe nella notifica, invece di fidarsi del codice che la compone.
    private func runCircuitProbeIfRequested() {
        guard CommandLine.arguments.contains("--circuit-probe") else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-circuito-\(UUID().uuidString).jsonl")
        var s = Settings()
        s.startDate = Date()
        let probe = AppModel(settings: s, ledger: Ledger(url: url))
        probe.headless = true
        probe.idleOverride = 0
        probe.start()
        probe.forceBreakNow(long: true)
        guard probe.canStartCircuit else { print("nessun circuito proponibile"); exit(2) }
        probe.startCircuit()
        guard let plan = probe.plan, plan.circuitActive else { print("circuito non attivo"); exit(2) }

        let riga = probe.completionSubtitle(plan)
        print("stazioni del circuito: \(plan.circuit.count)")
        for e in plan.circuit { print("  · \(e.label)") }
        print("riga della notifica: \(riga)")

        // Ogni stazione dev'essere nominata: se ne manca anche una, la notifica sta raccontando
        // meno di quello che hai fatto — che è esattamente il difetto.
        let mancanti = plan.circuit.filter { !riga.contains($0.kind.localizedName) }
        let ok = mancanti.isEmpty && plan.circuit.count > 1
        for m in mancanti { print("  MANCA: \(m.label)") }
        print(ok
              ? "RISULTATO: PASS — la notifica nomina tutte le stazioni del circuito"
              : "RISULTATO: FAIL — la notifica racconta meno del giro che hai fatto")

        let primaOk = probePreavvisoDelCircuito(url: url)
        try? FileManager.default.removeItem(at: url)
        exit(ok && primaOk ? 0 : 1)
    }

    /// La seconda metà della stessa sonda: **prima** della pausa, il preavviso parla del circuito?
    ///
    /// Il difetto era il gemello di quello sopra, e più caro: con il circuito acceso di serie il
    /// preavviso prometteva un esercizio solo — «16 squat» — e lo schermo si copriva su quattro.
    /// Segnalato dal principale il 2026-08-04, prima di una pausa piena.
    ///
    /// Due poli, perché uno solo non misura niente: **acceso di serie** deve nominare il circuito,
    /// e **proposto** deve nominare l'esercizio del turno, dove il circuito è un sì che devi dare
    /// tu dentro la pausa e annunciarlo sarebbe la stessa bugia al contrario.
    private func probePreavvisoDelCircuito(url: URL) -> Bool {
        func riga(_ modo: CircuitMode) -> (String, BreakPlan)? {
            var s = Settings()
            s.startDate = Date()
            s.circuitMode = modo
            let probe = AppModel(settings: s, ledger: Ledger(url: url))
            probe.headless = true
            probe.idleOverride = 0
            probe.start()
            probe.forceBreakNow(long: true)
            guard let plan = probe.plan else { return nil }
            return (probe.upcomingSubtitle(plan), plan)
        }

        guard let (acceso, pianoAcceso) = riga(.subito), let (proposto, pianoProposto) = riga(.proposto) else {
            print("preavviso: nessun piano costruito"); return false
        }
        print("preavviso col circuito acceso: \(acceso)")
        print("preavviso col circuito proposto: \(proposto)")

        // Non «contiene la parola giusta»: **non deve essere il nome di una stazione sola**, che
        // era esattamente il difetto.
        let accesoOk = pianoAcceso.circuitActive && acceso != pianoAcceso.exercise.label
        let propostoOk = !pianoProposto.circuitActive && proposto == pianoProposto.exercise.label
        if !accesoOk { print("  FAIL: col circuito acceso il preavviso nomina una stazione sola") }
        if !propostoOk { print("  FAIL: col circuito proposto il preavviso non nomina l'esercizio del turno") }
        print(accesoOk && propostoOk
              ? "RISULTATO: PASS — il preavviso dice quello che poi arriva"
              : "RISULTATO: FAIL — il preavviso promette una cosa diversa da quella che arriva")
        return accesoOk && propostoOk
    }

    /// `--policy-probe` — dopo aver aperto e chiuso una finestra, Otium torna un'app della barra
    /// dei menu?
    ///
    /// Sospetto nato leggendo `present(_:)`: mette l'app in `.regular` per far comparire una
    /// finestra vera, e **nessuno la rimette mai in `.accessory`**. Un'app dichiarata `LSUIElement`
    /// che dopo le preferenze resta per sempre nel Dock, con la sua barra dei menu, non è più
    /// l'app che dice di essere.
    private func runPolicyProbeIfRequested() {
        guard CommandLine.arguments.contains("--policy-probe") else { return }
        // **Le Preferenze, non le Statistiche.** La sonda apriva la finestra che nessuno lascia
        // aperta; quella che il principale tiene davanti mentre lavora e' questa, ed e' quella su
        // cui ha visto l'icona. Una sonda che prova una finestra diversa da quella del difetto
        // risponde a una domanda piu' debole di quella che le hai fatto.
        let allAvvio = NSApp.activationPolicy()
        showPrefs()
        let conFinestra = NSApp.activationPolicy()

        // **Il fuoco si legge dopo, non subito.** `activate` e `makeKeyAndOrderFront` chiedono al
        // sistema; la risposta arriva al giro dopo. Letto sulla stessa riga, `isKeyWindow` dice
        // sempre `false` e la sonda accuserebbe il codice di un difetto che e' suo — e' lo stesso
        // motivo per cui `windowWillClose` decide al giro dopo.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
        let haIlFuoco = self?.prefsWindow?.isKeyWindow ?? false
        self?.prefsWindow?.close()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let dopo = NSApp.activationPolicy()
            func nome(_ p: NSApplication.ActivationPolicy) -> String {
                p == .regular ? "regular (nel Dock)" : p == .accessory ? "accessory (barra dei menu)" : "prohibited"
            }
            print("all'avvio: \(nome(allAvvio))")
            print("con le preferenze aperte: \(nome(conFinestra))")
            print("la finestra prende il fuoco: \(haIlFuoco ? "si" : "NO")")
            print("dopo averle chiuse: \(nome(dopo))")
            let ok = allAvvio == .accessory && conFinestra == .accessory && dopo == .accessory && haIlFuoco
            print(ok
                  ? "RISULTATO: PASS — mai nel Dock, e la finestra si usa lo stesso"
                  : "RISULTATO: FAIL — l'icona compare nel Dock, o la finestra non prende il fuoco")
            exit(ok ? 0 : 1)
        }
        }
    }

    /// `--hotkey-probe` — ⌃S è davvero registrato a livello di sistema, e il ponte con Carbon
    /// porta alla finestra giusta?
    ///
    /// Si legge a due poli, e il polo interessante è il fallimento: **con Otium viva la
    /// registrazione deve fallire**, perché il tasto è già suo. È la prova che l'app vera lo tiene
    /// davvero, non un'asserzione sul fatto che ci abbia provato. Con Otium ferma deve riuscire.
    private func runHotKeyProbeIfRequested() {
        guard CommandLine.arguments.contains("--hotkey-probe") else { return }
        var arrivato = false
        let hotkey = GlobalHotKey(keyCode: Self.statsHotKeyCode,
                                  carbonModifiers: Self.statsHotKeyModifiers) { arrivato = true }

        if let hotkey {
            print("registrazione di ⌃S: RIUSCITA (nessun'altra app lo teneva)")
            hotkey.fireForProbe()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("il gestore è arrivato: \(arrivato ? "sì" : "no")")
                print(arrivato
                      ? "RISULTATO: PASS — tasto registrato e ponte con Carbon cablato"
                      : "RISULTATO: FAIL — registrato ma il gestore non scatta")
                exit(arrivato ? 0 : 1)
            }
        } else {
            // Chi lo tiene? Se Otium è viva, lo tiene lei — ed è esattamente ciò che si voleva.
            let viva = NSRunningApplication
                .runningApplications(withBundleIdentifier: SingleInstance.bundleIdentifier)
                .contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            print("registrazione di ⌃S: FALLITA (il tasto è già di qualcuno)")
            print("Otium è viva: \(viva ? "sì" : "no")")
            print(viva
                  ? "RISULTATO: PASS — ⌃S è tenuto dall'Otium in esecuzione, quindi è vivo"
                  : "RISULTATO: FAIL — ⌃S è di un'altra app, la scorciatoia non sarà attiva")
            exit(viva ? 0 : 1)
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

        // **La spunta della modalità Zen, e ha due poli.** Non basta che il clic accenda: la
        // stessa impostazione si gira anche dalle Preferenze, quindi la sonda cambia lo stato
        // **alle spalle del menu** e chiede al menu di riaprirsi. Il giorno in cui la
        // risincronizzazione sparisse, quella riga diventerebbe rossa da sola; senza quel polo,
        // il verde direbbe solo «il mio clic funziona», che è la domanda più debole.
        var zenOk = zenItem != nil && zenItem?.state == .off && !model.settings.zenMode
        print("zen · spenta di serie: \(zenOk ? "sì" : "NO")")
        toggleZen()
        let acceso = model.settings.zenMode && zenItem?.state == .on
        print("zen · un clic la accende, spunta compresa: \(acceso ? "sì" : "NO")")
        toggleZen()
        let spento = !model.settings.zenMode && zenItem?.state == .off
        print("zen · un altro clic la spegne: \(spento ? "sì" : "NO")")
        var fuori = model.settings
        fuori.zenMode = true
        model.update(settings: fuori)
        let primaDiRiaprire = zenItem?.state == .on
        if let menu { menuWillOpen(menu) }
        let riallineata = zenItem?.state == .on
        print("zen · cambiata dalle Preferenze, la spunta si allinea riaprendo il menu: "
              + "\(riallineata ? "sì" : "NO") (prima di riaprire era \(primaDiRiaprire ? "già on" : "off"))")
        // **Il segno nella barra, e il polo che conta è l'aggiornamento immediato.** Il titolo non
        // cambia quando giri la modalità, quindi la scorciatoia che salta le riscritture inutili
        // farebbe comparire il vento al battito dopo. Qui si guarda subito, senza aspettare un
        // secondo: se ricomparisse quella scorciatoia, questa riga diventerebbe rossa.
        updateStatusTitle()
        let segnoAcceso = statusItem.button?.image != nil
        toggleZen()
        let segnoSpento = statusItem.button?.image == nil && !model.settings.zenMode
        toggleZen()
        let segnoTornato = statusItem.button?.image != nil && model.settings.zenMode
        print("zen · con la modalità accesa la barra porta il segno: \(segnoAcceso ? "sì" : "NO")")
        print("zen · spegnendola il segno sparisce subito: \(segnoSpento ? "sì" : "NO")")
        print("zen · riaccendendola torna subito: \(segnoTornato ? "sì" : "NO")")

        zenOk = zenOk && acceso && spento && riallineata && segnoAcceso && segnoSpento && segnoTornato
        print(zenOk
              ? "RISULTATO ZEN: PASS — spunta e segno nella barra dicono sempre quello che fa il motore"
              : "RISULTATO ZEN: FAIL")

        NSApp.terminate(nil)
        exit(ok && zenOk ? 0 : 1)
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
        let window = makeWindow(title: "sonda", content: content)   // lingua: ok sonda di sviluppo (--window-probe)
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

    /// **Il simbolo di Zen nella barra, in un posto solo.**
    ///
    /// Il nome sta qui e non sparso nel codice perché è una scelta di gusto, e una scelta di gusto
    /// si cambia guardandola: `--segno-zen=<nome>` la sovrascrive per una sonda, così i candidati
    /// si mettono fianco a fianco nella barra vera invece di discuterli a parole. Con `char:` si
    /// disegna un carattere qualunque, per i segni che SF Symbols non ha, come lo yin e lo yang.
    static let zenSymbolDefault = "leaf"

    private static func segnoZen() -> NSImage? {
        let nome = CommandLine.arguments
            .first { $0.hasPrefix("--segno-zen=") }?
            .split(separator: "=", maxSplits: 1).last.map(String.init) ?? zenSymbolDefault
        let descrizione = L.t("Modalità Zen attiva", "Zen mode on")

        if nome.hasPrefix("char:") {
            let testo = String(nome.dropFirst(5))
            // Il carattere si disegna a mano: un `NSImage` da testo, con la stessa altezza di un
            // simbolo di sistema, e da modello come gli altri per seguire chiaro e scuro.
            let font = NSFont.systemFont(ofSize: 13)
            let attributi: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let misura = (testo as NSString).size(withAttributes: attributi)
            let img = NSImage(size: NSSize(width: ceil(misura.width), height: ceil(misura.height)))
            img.lockFocus()
            (testo as NSString).draw(at: .zero, withAttributes: attributi)
            img.unlockFocus()
            img.isTemplate = true
            img.accessibilityDescription = descrizione
            return img
        }

        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        let segno = NSImage(systemSymbolName: nome, accessibilityDescription: descrizione)?
            .withSymbolConfiguration(config)
        segno?.isTemplate = true
        return segno
    }

    private func updateStatusTitle() {
        let titolo = model.statusTitle
        let zen = model.settings.zenMode
        // **La chiave del confronto porta anche Zen, non solo la scritta.** Girando la modalità i
        // minuti non cambiano, quindi con il solo titolo l'uscita anticipata si mangiava il segno:
        // sarebbe comparso un minuto dopo, quando il numero cambia da sé.
        let chiave = "\(titolo)|\(zen)"
        guard chiave != lastStatusTitle else { return }
        lastStatusTitle = chiave
        statusItem.button?.title = titolo

        // **Il segno di Zen sta nella barra, non solo dentro il menu** (sua richiesta,
        // 2026-08-09). La modalità decide che cosa ti chiede la prossima pausa, e se per saperlo
        // devi aprire il menu lo stato resta nascosto proprio a chi l'ha appena girato. Un simbolo
        // e non una lettera, perché accanto a un numero di minuti un carattere qualunque si legge
        // come parte del numero. Da modello, così segue il chiaro e lo scuro della barra da sé.
        if zen {
            statusItem.button?.image = Self.segnoZen()
            statusItem.button?.imagePosition = .imageLeading
        } else {
            statusItem.button?.image = nil
            statusItem.button?.imagePosition = .noImage
        }

        let base = model.phase == .paused
            ? L.t("Otium sospesa", "Otium paused")
            : L.t("Prossima pausa fra \(model.minutesToNextBreak) minuti di lavoro attivo",
                  "Next break in \(model.minutesToNextBreak) minutes of active work")
        statusItem.button?.toolTip = zen
            ? base + L.t(" · modalità Zen attiva", " · Zen mode on")
            : base
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let panel = NSMenuItem()
        let hosting = NSHostingView(rootView: MenuPanel(model: model))
        // **L'altezza la detta il contenuto, non una costante.** Erano 260 punti scritti a mano
        // contro un pannello che ne occupa una sessantina di meno: sotto «sessioni intense»
        // restava una fascia vuota grande quanto tre voci di menu, e sembrava che mancasse
        // qualcosa. Segnalato dal principale il 2026-07-31 guardando il menu aperto. Stessa cura
        // gia' applicata alla notifica il 28 luglio, e stesso motivo: una costante scritta a mano
        // scommette sull'altezza del contenuto, e la scommessa si perde al primo cambiamento.
        hosting.frame = NSRect(origin: .zero,
                               size: NSSize(width: 280, height: hosting.fittingSize.height))
        panel.view = hosting
        menu.addItem(panel)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L.t("Sospendi", "Pause"), action: #selector(togglePause), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L.t("Fai una pausa adesso", "Take a break now"), action: #selector(breakNow), keyEquivalent: ""))

        // **La modalità Zen si accende da qui, oltre che dalle Preferenze** (sua richiesta,
        // 2026-08-09). Sta accanto a «Fai una pausa adesso» perché risponde alla stessa domanda —
        // che cosa succede alla prossima pausa — e perché è la decisione che si prende quando la
        // situazione cambia sotto di te: arriva qualcuno, sei in ufficio, non puoi metterti a
        // terra. Aprire una finestra di preferenze per una decisione di quel tipo è una porta di
        // troppo. Le tre scelte di dettaglio (i due protocolli e la durata) restano nelle
        // Preferenze: si decidono una volta, non a ogni pausa.
        let zen = NSMenuItem(title: L.t("Modalità Zen", "Zen mode"), action: #selector(toggleZen), keyEquivalent: "")
        zen.state = model.settings.zenMode ? .on : .off
        menu.addItem(zen)
        zenItem = zen

        // Due pannelli invece di due sottomenu: servono due informazioni per volta (quale
        // esercizio, quante ripetizioni), e un menu sa fare una domanda sola.
        menu.addItem(NSMenuItem(title: L.t("Sono già al computer da…", "I've been at the computer for…"), action: #selector(showSeated), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: L.t("Ho già fatto una pausa…", "I already took a break…"), action: #selector(showDeclare), keyEquivalent: ""))
        let undo = NSMenuItem(title: L.t("Togli l'ultima pausa segnata", "Remove the last logged break"), action: nil, keyEquivalent: "")
        let undoMenu = NSMenu()
        let um = NSMenuItem(title: L.t("micro-pausa", "micro-break"), action: #selector(undoMicro), keyEquivalent: "")
        let ul = NSMenuItem(title: L.t("pausa piena", "full break"), action: #selector(undoLong), keyEquivalent: "")
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
        let stats = NSMenuItem(title: L.t("Statistiche…", "Statistics…"), action: #selector(showStats), keyEquivalent: "s")
        stats.keyEquivalentModifierMask = []
        menu.addItem(stats)
        // **Le fonti, il registro e la diagnostica sono passati nelle Preferenze → Avanzate**
        // (2026-07-31, sua richiesta). Un menu di barra di stato e' la lista delle cose che fai
        // spesso: quelle tre si aprono una volta ogni tanto, e in piu' due su tre avevano bisogno
        // di una riga di spiegazione che in un menu non ci sta. Restano raggiungibili, con
        // accanto il testo che dice cosa sono.
        let prefs = NSMenuItem(title: L.t("Preferenze…", "Preferences…"), action: #selector(showPrefs), keyEquivalent: ",")
        prefs.keyEquivalentModifierMask = []
        menu.addItem(prefs)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L.t("Esci da Otium", "Quit Otium"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        for item in menu.items where item.action != nil && item.target == nil {
            if item.action != #selector(NSApplication.terminate(_:)) { item.target = self }
        }
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.flushForDisplay()
        if let item = menu.items.first(where: { $0.title == L.t("Sospendi", "Pause") || $0.title == L.t("Riprendi", "Resume") }) {
            item.title = model.phase == .paused ? L.t("Riprendi", "Resume") : L.t("Sospendi", "Pause")
        }
        if let hosting = menu.items.first?.view as? NSHostingView<MenuPanel> {
            hosting.rootView = MenuPanel(model: model)
        }
        // La spunta si rilegge a ogni apertura, non solo quando è il menu a cambiarla: la stessa
        // impostazione si gira anche dalle Preferenze, e un segno di spunta che descrive lo stato
        // di mezz'ora fa è peggio di nessun segno.
        zenItem?.state = model.settings.zenMode ? .on : .off
    }

    /// **Accende e spegne la modalità Zen scrivendo sul disco subito**, come fa l'interruttore
    /// nelle Preferenze: qui non c'è nessun «Applica» dietro cui nascondersi, e la pausa che
    /// arriva fra due minuti deve già essere quella giusta.
    ///
    /// Un salvataggio fallito si dice, perché `update` cambia comunque l'impostazione viva e la
    /// differenza si vede solo al prossimo avvio: la pausa di oggi è quella che vedi, quella di
    /// domani no.
    @objc private func toggleZen() {
        var s = model.settings
        s.zenMode.toggle()
        let scritto = model.update(settings: s)
        zenItem?.state = model.settings.zenMode ? .on : .off
        // Il segno nella barra si aggiorna adesso, non al prossimo battito del secondo.
        updateStatusTitle()
        if !scritto {
            model.announce(
                title: L.t("Non sono riuscito a salvare le preferenze",
                           "I could not save the preferences"),
                subtitle: L.t("La modalità Zen vale adesso, ma al prossimo avvio torna com'era.",
                              "Zen mode applies now, but it will revert on the next launch.")
            )
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

    /// La finestra del primo avvio. Chiuderla senza rispondere non salva niente: al prossimo
    /// avvio la domanda torna, perché senza risposta l'app non sa da che numero partire.
    private func showOnboarding() {
        let hosting = NSHostingView(rootView: OnboardingView(model: model) { [weak self] in
            self?.onboardingWindow?.close()
            self?.onboardingWindow = nil
            self?.statusItem.menu = self?.buildMenu()
            self?.updateStatusTitle()
            self?.model.announce(
                title: L.t("Otium è attiva", "Otium is running"),
                subtitle: L.t("La trovi nella barra dei menu, in alto a destra.",
                              "You'll find it in the menu bar, top right.")
            )
        })
        hosting.frame = NSRect(x: 0, y: 0, width: 540, height: hosting.fittingSize.height)
        onboardingWindow = makeWindow(title: L.t("Benvenuto in Otium", "Welcome to Otium"),
                                      content: hosting)
        present(onboardingWindow)
    }

    /// La domanda delle due settimane. Vive come l'onboarding: una finestra vera, non una
    /// notifica — a una notifica non si risponde, e questa è una domanda.
    private func showPaceCheckIn() {
        let hosting = NSHostingView(rootView: PaceCheckInView(model: model) { [weak self] in
            self?.paceWindow?.close()
            self?.paceWindow = nil
            self?.updateStatusTitle()
        })
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: hosting.fittingSize.height)
        paceWindow = makeWindow(title: L.t("Otium", "Otium"), content: hosting)
        present(paceWindow)
    }

    private func showGrowthCheckIn() {
        let hosting = NSHostingView(rootView: GrowthCheckInView(model: model) { [weak self] in
            self?.growthWindow?.close()
            self?.growthWindow = nil
            self?.updateStatusTitle()
        })
        hosting.frame = NSRect(x: 0, y: 0, width: 520, height: hosting.fittingSize.height)
        growthWindow = makeWindow(title: L.t("Otium", "Otium"), content: hosting)
        present(growthWindow)
    }

    @objc private func showSeated() {
        seatedWindow = makeWindow(title: L.t("Sono già al computer da…", "I've been at the computer for…"),
                                  content: NSHostingView(rootView: DeclareSeatedView(model: model) { [weak self] in
                                      self?.seatedWindow?.close(); self?.seatedWindow = nil
                                      self?.updateStatusTitle()
                                  }))
        present(seatedWindow)
    }

    @objc private func showDeclare() {
        declareWindow = makeWindow(title: L.t("Ho già fatto una pausa…", "I already took a break…"),
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
        // **Si riparte sempre da oggi** (2026-07-31, sua richiesta). Il periodo vive nel modello
        // proprio per sopravvivere alla chiusura della finestra, ed era una comodità immaginata:
        // chi riapre le statistiche vuole sapere come va *adesso*, non ritrovare il mese che
        // stava guardando ieri sera. Il mese resta a un clic; la giornata la ridà la finestra.
        model.statsPeriod = .day
        // **Contenuto nuovo a ogni apertura.** Una finestra nascosta non ridisegna: riaprendola
        // mostrava per un istante i numeri di quando l'avevi chiusa, e poi si aggiornava sotto
        // gli occhi al primo battito. Segnalato guardandolo succedere il 2026-07-27.
        let view = NSHostingView(rootView: StatsView(model: model))
        view.frame = NSRect(x: 0, y: 0, width: 620, height: 680)
        if statsWindow == nil {
            statsWindow = makeWindow(title: L.t("Otium — statistiche", "Otium — statistics"), content: view)
        } else {
            statsWindow?.contentView = view
        }
        present(statsWindow)
    }

    /// La diagnostica in finestra. **Stesso `Doctor.report()` del comando**, così i due non
    /// possono raccontare cose diverse.
    @objc private func showDoctor() {
        let rapporto = Doctor.report()
        let testo = NSTextView(frame: NSRect(x: 0, y: 0, width: 560, height: 380))
        testo.string = rapporto.text
        testo.isEditable = false
        testo.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        testo.textContainerInset = NSSize(width: 16, height: 16)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 560, height: 380))
        scroll.documentView = testo
        scroll.hasVerticalScroller = true
        doctorWindow = makeWindow(title: L.t("Otium — diagnostica", "Otium — diagnostics"),
                                  content: scroll)
        present(doctorWindow)
    }

    @objc private func revealLedger() {
        NSWorkspace.shared.activateFileViewerSelecting([model.ledger.fileURL])
    }

    @objc private func showEvidence() {
        if evidenceWindow == nil {
            let view = NSHostingView(rootView: EvidenceView())
            view.frame = NSRect(x: 0, y: 0, width: 640, height: 620)
            evidenceWindow = makeWindow(title: L.t("Otium — le fonti", "Otium — the sources"), content: view)
        }
        present(evidenceWindow)
    }

    /// `--mostra-prefs` — le preferenze **nella finestra vera**, non nella resa fuori schermo.
    ///
    /// Esiste per un difetto della sonda scoperto il 2026-07-31: `--surface=prefs` disegna in un
    /// `NSHostingView` senza finestra, e li una barra laterale di sistema non ha ne il materiale
    /// ne la colonna — usciva bianca e vuota. Una resa che non sa disegnare la vista non puo
    /// dire se la vista e giusta: dice solo che la sonda non arriva. Questa apre la finestra come
    /// la apre il menu, dentro `ProbeMode`, quindi lo screenshot e quello che vedrebbe chiunque.
    private func runPrefsDemoIfRequested() {
        guard CommandLine.arguments.contains("--mostra-prefs") else { return }
        // `--voce=<nome>`: apre gia sul pannello da guardare, o si guarda un sesto
        // dell'interfaccia e si chiama verde il resto.
        let voce = CommandLine.arguments.first { $0.hasPrefix("--voce=") }?
            .split(separator: "=", maxSplits: 1).last
            .flatMap { PrefsView.Section(rawValue: String($0)) } ?? .profilo
        prefsWindow = makeWindow(title: L.t("Preferenze di Otium", "Otium Preferences"),
                                 content: NSHostingView(rootView: PrefsView(model: model, initialSection: voce)))
        present(prefsWindow)
    }

    @objc private func showPrefs() {
        if prefsWindow == nil {
            prefsWindow = makeWindow(title: L.t("Preferenze di Otium", "Otium Preferences"), content: NSHostingView(rootView: PrefsView(model: model)))
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
        // La carta di giorno, l'inchiostro di sera. Il colore è dinamico, quindi la finestra
        // cambia da sola quando il Mac passa allo scuro: non si legge l'aspetto adesso.
        window.backgroundColor = Palette.windowPaperNS
        // Senza questa riga la barra del titolo resta bianca di sistema sopra un corpo di carta,
        // e si vede la giuntura: una finestra con due fondi diversi non sembra una scelta, sembra
        // un pezzo non finito. Trasparente, prende il colore della finestra e il foglio è uno solo.
        window.titlebarAppearsTransparent = true
        window.contentView = content
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        window.center()
        return window
    }

    /// **Aprire una finestra non deve portare l'app nel Dock.**
    ///
    /// Qui c'era `setActivationPolicy(.regular)`, e faceva esattamente quello: apri le Preferenze,
    /// e per tutto il tempo che restano aperte Otium compare nel Dock con la sua icona. Il 28
    /// luglio avevo curato la meta' peggiore del difetto — ci restava **per sempre** — lasciando
    /// in piedi la premessa, cioe' che una finestra valga un posto nel Dock. Il principale l'ha
    /// visto il 2026-07-31 e la sua frase e' la specifica: *«e' ricomparsa l'icona
    /// dell'applicazione nel dock. Non dovrebbe.»*
    ///
    /// Un'app `.accessory` le finestre le mostra e il fuoco lo prende: `activate` +
    /// `makeKeyAndOrderFront` bastano, e il campo di testo delle Preferenze scrive. Quello che
    /// perde e' il posto in ⌘Tab e la barra dei menu propria — cioe' esattamente le due cose che
    /// `LSUIElement` dichiara di non volere.
    ///
    /// **Il blocco della pausa resta l'eccezione, e resta com'e'.** Li' `.regular` serve davvero
    /// (finestra a schermo intero in modalita' chiosco che deve prendersi il controllo) e la
    /// politica precedente viene salvata e rimessa alla chiusura. E' anche il pezzo che ha
    /// prodotto lo schermo nero senza uscita: non si tocca per un'icona.
    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// **Aprire una finestra la porta nel Dock; chiuderla la deve riportare nella barra.**
    ///
    /// Difetto trovato cercando, non usando (2026-07-28, `--policy-probe`): `present(_:)` metteva
    /// l'app in `.regular` per far comparire una finestra vera, e nessuno la rimetteva mai in
    /// `.accessory`. Bastava aprire le preferenze una volta e Otium restava per sempre nel Dock,
    /// con la sua barra dei menu — cioè smetteva di essere l'app della barra di stato che
    /// `LSUIElement` dichiara. Silenzioso, permanente, e invisibile finché non lo si misura.
    func windowWillClose(_ notification: Notification) {
        // La notifica arriva **prima** che la finestra sparisca: la decisione va presa al giro
        // dopo, quando `isVisible` dice la verità e non l'intenzione.
        DispatchQueue.main.async { [weak self] in self?.restoreAccessoryPolicyIfIdle() }
    }

    private func restoreAccessoryPolicyIfIdle() {
        // Durante una pausa la politica è del blocco, che se la riprende da solo alla chiusura:
        // metterci mano qui vorrebbe dire due padroni per la stessa impostazione.
        guard model.phase != .breaking else { return }
        // **Tutte e nove, non cinque.** Ne mancavano quattro — diagnostica, primo avvio, ritmo,
        // crescita — e una finestra fuori dall'elenco fa dire «non c'e' piu' niente aperto» a
        // schermo pieno di roba. Trovato con un grep sulle variabili di finestra il 2026-07-31,
        // mentre cercavo l'icona nel Dock: non era la causa di quella, era il suo vicino di casa.
        let ancoraAperte = [prefsWindow, evidenceWindow, statsWindow, seatedWindow, declareWindow,
                            doctorWindow, onboardingWindow, paceWindow, growthWindow]
            .compactMap { $0 }
            .contains { $0.isVisible }
        guard !ancoraAperte else { return }
        NSApp.setActivationPolicy(.accessory)
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

    // `--registro-finto` semina una giornata gia cominciata, e serve a **guardare** i rami che
    // il registro vuoto non fa mai vedere. Il caso vivo: la riga in alto a destra ha due forme,
    // e con zero ripetizioni ne esce sempre e solo una. Sta qui, prima del primo `AppModel`,
    // perche il riassunto si legge dal disco: seminarlo dopo vorrebbe dire scriverlo e sperare
    // che qualcuno rilegga. Dentro `ProbeMode`, quindi nella cartella usa e getta.
    // `--cadenza-finta` porta la cadenza fuori dai preset, che e' l'unico modo di **guardare** la
    // riga «personalizzata»: con le impostazioni di serie quel ramo non si disegna mai.
    // `--circuito-subito`: rende la pausa piena **come la vede chi ha acceso l'impostazione**.
    // Senza, la sonda gira coi valori di serie e disegna sempre e solo la proposta.
    if arguments.contains("--circuito-subito") {
        var s = Settings()
        s.circuitMode = .subito
        SettingsStore.save(s)
    }

    if arguments.contains("--cadenza-finta") {
        var s = Settings()
        s.cadence.warningSeconds = 45
        s.cadence.postponesAllowed = 3
        SettingsStore.save(s)
    }

    if arguments.contains("--registro-finto") {
        let ledger = Ledger()
        let ora = Date()
        for (kind, reps) in [(ExerciseKind.crunch, 15), (.squat, 12), (.crunch, 11), (.pushUp, 8)] {
            _ = ledger.append(LedgerEntry(timestamp: ora.addingTimeInterval(-3600),
                                          type: .exerciseDone, exercise: kind, reps: reps))
        }
        _ = ledger.append(LedgerEntry(timestamp: ora.addingTimeInterval(-3500),
                                      type: .completed, breakKind: .micro))
    }

    // `--crescita-finta` semina **una decina di giorni** di conferme, che è l'unico modo di
    // guardare la pagina della crescita: nella cartella usa e getta il registro nasce vuoto, e
    // una pagina che disegna una storia su un registro vuoto mostra per sempre soltanto il suo
    // ramo «non c'è ancora niente». I numeri salgono di poco e non tutti, perché una progressione
    // in cui tutto sale sempre è un grafico finto e non farebbe vedere il caso che conta.
    if arguments.contains("--crescita-finta") {
        let ledger = Ledger()
        let giorno: TimeInterval = 24 * 3600
        let storia: [(ExerciseKind, [Int])] = [
            (.pushUp,      [8, 8, 9, 9, 10, 10, 11]),
            (.squat,       [10, 11, 11, 12, 13, 13]),
            (.crunch,      [12, 12, 13, 14, 15]),
            (.plank,       [30, 30, 35, 40, 45]),
            (.gluteBridge, [10, 11, 11]),
            (.calfRaise,   [15, 15, 15, 15]),
            (.burpee,      [5, 6]),
        ]
        var progresso = ProgressBook()
        for (kind, serie) in storia {
            for (i, reps) in serie.enumerated() {
                let quando = Date().addingTimeInterval(-giorno * Double(serie.count - i))
                _ = ledger.append(LedgerEntry(timestamp: quando, type: .exerciseDone,
                                              exercise: kind, reps: reps))
                // **Ogni conferma chiude la sua pausa.** Senza, stanno tutte nella stessa e la
                // lettura le classifica come circuito: la sonda mostrerebbe un ramo che nei dati
                // veri non c'è, ed è il modo in cui una semina finta smette di somigliare al vero.
                _ = ledger.append(LedgerEntry(timestamp: quando.addingTimeInterval(60),
                                              type: .completed, breakKind: .micro))
            }
            // Il moltiplicatore sale solo dove la serie è davvero salita: la pagina mette la
            // pastiglia accanto alla riga cresciuta, e con tutte le pastiglie accese non si
            // vedrebbe se la mette al posto giusto.
            if let primo = serie.first, let ultimo = serie.last, ultimo > primo {
                progresso.byExercise[kind.rawValue] =
                    ExerciseProgress(level: ultimo >= primo + 4 ? 1.1025 : 1.05, streak: 1)
            }
        }
        ProgressStore.save(progresso)
    }
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
        let verdict = PresenceRadar.detect(microphoneActive: MicRadar.isInputActive(),
                                           cameraActive: CameraRadar.isCapturing())
            .map { "\($0.kind.rawValue) · \(PresenceCap.label(for: $0.kind)) · \($0.detail)" }
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
    print("telecamera in uso: \(CameraRadar.isCapturing() ? "sì (videochiamata)" : "no")")
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
    if let p = PresenceRadar.detect(microphoneActive: MicRadar.isInputActive(),
                                    cameraActive: CameraRadar.isCapturing()) {
        print("→ presenza: \(p.kind.rawValue) · \(p.detail) · \(PresenceCap.label(for: p.kind))")
    } else {
        print("→ presenza: nessuna — fermo qui significherebbe assente")
    }
    exit(0)
}
// `--doctor` **prima di tutto**, e fuori da ProbeMode: deve leggere i file veri, non una
// cartella usa e getta, o direbbe che va tutto bene guardando altrove. E prima del lock
// dell'istanza unica, perché il caso in cui serve di più è proprio «ce n'è già una viva».
if arguments.contains("--doctor") {
    exit(Doctor.run())
}

if arguments.contains("--version") {
    print("Otium \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
    exit(0)
}

if arguments.contains("--agent-status") {
    print(LoginItem.state())
    if LoginItem.legacyAgentInstalled() {
        print("residuo: il vecchio LaunchAgent è ancora installato in \(LoginItem.legacyPlistURL.path)")
    }
    exit(0)
}
if arguments.contains("--install-agent") {
    let ok = LoginItem.enable()
    print(ok ? "registrato" : "registrazione fallita")
    print(LoginItem.state())
    exit(ok ? 0 : 1)
}
if arguments.contains("--remove-agent") {
    let ok = LoginItem.disable()
    print(ok ? "rimosso" : "rimozione fallita (forse non era registrato)")
    print(LoginItem.state())
    exit(ok ? 0 : 1)
}
// La migrazione a mano, per il caso in cui l'app non venga aperta: `--doctor` la segnala, questo
// la esegue. Da sola l'app la fa al primo avvio.
if arguments.contains("--remove-legacy-agent") {
    guard LoginItem.legacyAgentInstalled() else {
        print("nessun vecchio LaunchAgent da togliere")
        exit(0)
    }
    let ok = LoginItem.removeLegacyAgent()
    print(ok ? "vecchio LaunchAgent rimosso: \(LoginItem.legacyPlistURL.path)" : "rimozione fallita")
    exit(ok ? 0 : 1)
}

// `--tagli` stampa **dove va a capo** ogni frase del mazzo, sulle tre colonne vere, prima
// e dopo l'impaginazione. È la sonda che ha aperto ISC-199: prima diceva che la frase zen
// chiudeva la riga su «Dopo», cioè aprendo il secondo periodo.
//
// Ha due poli per costruzione: la colonna `avido` è il comportamento di `Text` lasciato a
// sé, e deve mostrare difetti; la colonna `scelto` è quella che si vede, e non deve
// mostrarne. Se un giorno l'avido risultasse pulito, il verde non direbbe più niente.
if CommandLine.arguments.contains("--tagli") {
    let verboso = CommandLine.arguments.contains("--verboso")
    var totali: [String: (Int, Int)] = [:]
    for colonna in QuoteWrap.colonne {
        let nome = colonna.nome
        var difettiAvido = 0, difettiScelto = 0
        for (i, p) in PhraseLibrary.breakPool(includingUser: false).enumerated() {
            let w = colonna.larghezza
            let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
            let avido = QuoteWrap.naturalLines(p.displayText, width: w, font: font)
            let scelto = QuoteWrap.lines(p.displayText, width: w, font: font)
            let da = QuoteWrap.difetti(avido), ds = QuoteWrap.difetti(scelto)
            difettiAvido += da.count
            difettiScelto += ds.count
            let righeDiverse = avido.count != scelto.count
            if !da.isEmpty || !ds.isEmpty || righeDiverse || verboso {
                print("\n[\(nome) #\(i)] avido \(avido.count) righe \(da.map(\.rawValue)) · scelto \(scelto.count) righe \(ds.map(\.rawValue))")
                for r in avido { print("  avido  | \(r)") }
                for r in scelto { print("  scelto | \(r)") }
            }
        }
        totali[nome] = (difettiAvido, difettiScelto)
    }
    print("\n=== TAGLI ===")
    for colonna in QuoteWrap.colonne {
        let (a, s) = totali[colonna.nome] ?? (0, 0)
        print("\(colonna.nome)\tavido: \(a) difetti\tscelto: \(s) difetti")
    }
    exit(0)
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
