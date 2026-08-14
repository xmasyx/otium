import AppKit
import SwiftUI
import OtiumCore

extension Notification.Name {
    static let otiumEscapePressed = Notification.Name("app.otium.escPressed")
}

/// La finestra che copre lo schermo.
///
/// Onestà su cosa può e non può fare: da High Sierra nessuna finestra può stare sopra il lock
/// screen di sistema, e un processo si può sempre uccidere da un altro Mac. Questo non è un
/// lucchetto — è attrito forte, che è esattamente il punto: *"già il richiamo permette di essere
/// in condizione di scelta"*.
///
/// **È un `NSPanel` non-attivante, e non è un dettaglio: è l'unica classe che entra nello Space
/// di un'altra app a schermo intero.** Misurato il 2026-08-03 sul Mac di sviluppo (macOS 26)
/// con iTerm a schermo intero nativo: la vecchia `NSWindow`, alzata dopo
/// `setActivationPolicy(.regular)` + `activate(ignoringOtherApps:)`, **non entrava in quello
/// Space** — zero pixel sullo schermo, e il server grafico non la elencava nemmeno fra le
/// finestre on-screen — mentre l'app si prendeva comunque il primo piano senza attivarsi
/// davvero (`isActive == false`, nessuna finestra key). Il battito da 2 s ripeteva la rapina
/// ogni due secondi: chi scriveva vedeva il testo bloccarsi, tornare, ribloccarsi.
/// Sette combinazioni di livello e `collectionBehavior` provate, tutte a zero: il colpevole non
/// erano i flag della finestra, era la coppia policy+activate. Questa configurazione — pannello
/// non-attivante, nessun cambio di policy, nessun `activate` — copre il 100% dello schermo e
/// riceve i tasti (`isActive == true`, key sì), col chiosco intatto (`presentationOptions` 490).
final class BlockerWindow: NSPanel {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen, content: NSView) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // **Un `NSPanel` di suo sparisce quando l'app perde il fuoco.** Su uno scudo che deve
        // restare inchiodato è esattamente il difetto opposto a quello che stiamo curando, e
        // non si vedrebbe finché un'altra app non prende il fuoco per un istante.
        hidesOnDeactivate = false
        // Un pannello «solo se serve» rinuncia a diventare key quando pensa di non averne
        // bisogno; qui i tasti servono sempre — i due Esc dell'uscita d'emergenza li riceve lui.
        becomesKeyOnlyIfNeeded = false
        isFloatingPanel = false
        isOpaque = true
        hasShadow = false
        backgroundColor = NSColor(calibratedWhite: 0.05, alpha: 1.0)
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
        contentView = content
        setFrame(screen.frame, display: true)
    }

    /// AppKit può "aggiustare" la cornice di una finestra perché resti dentro l'area visibile.
    /// Su questo Mac non lo fa (misurato: la finestra esce 1512×982 esatti, con e senza questa
    /// riga), ma la garanzia costa zero e dipenderebbe altrimenti da una scelta di sistema che
    /// non controllo. Resta come cintura, non come cura di un guasto osservato.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// ISC-18 — niente Esc, niente ⌘W, ⌘Q, ⌘H, ⌘M. La scorciatoia che chiude tutto è
    /// il difetto principale delle app di pausa: qui non esiste.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if ["q", "w", "h", "m", "`"].contains(key) { return true }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Esc non chiude più "di proposito niente": ora è l'uscita d'emergenza, **in due tempi**.
    /// Il primo Esc avvisa, il secondo esce — e l'uscita viene contata e finisce nelle
    /// statistiche. Un tasto solo sarebbe troppo facile da premere per sbaglio; due Esc no.
    override func cancelOperation(_ sender: Any?) {
        NotificationCenter.default.post(name: .otiumEscapePressed, object: nil)
    }
}

/// Uno schermo può essere collegato mentre il blocco è già su: la finestra deve arrivare
/// anche lì, o basta un secondo monitor per rendere l'app decorativa.
final class BlockerController {

    private unowned let model: AppModel
    private var windows: [BlockerWindow] = []
    private var reassertTimer: Timer?
    private var isShowing = false
    /// Il blocco è **in corso ma tolto di mezzo**, perché il Mac dorme o lo schermo è bloccato.
    /// Diverso da `!isShowing`: quella pausa esiste ancora e va rimessa su al risveglio.
    private var suspended = false

    /// La combinazione chiosco documentata in TN2062: Dock e barra dei menu spariscono,
    /// ⌘-Tab ed Exposé non commutano, uscita forzata e chiusura di sessione sono disabilitate.
    private static let kioskOptions: NSApplication.PresentationOptions = [
        .hideDock,
        .hideMenuBar,
        .disableProcessSwitching,
        .disableForceQuit,
        .disableSessionTermination,
        .disableHideApplication,
    ]

    init(model: AppModel) {
        self.model = model
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isShowing, !self.suspended else { return }
            self.rebuildWindows()
        }
        observeSystemState()
    }

    /// **Mentre il Mac dorme o lo schermo è bloccato, lo scudo si toglie di mezzo.**
    ///
    /// Non è la causa dell'incidente del 27-28 luglio — quella era una pausa chiusa che lasciava
    /// la finestra orfana — ma è la stessa ferita, un passo più in là. Una finestra a livello di
    /// schermatura, che ogni due secondi si rimette davanti e riattiva l'app, mentre la schermata
    /// di accesso possiede lo schermo, è la ricetta classica del risveglio nero: due padroni per
    /// la stessa superficie, con l'uscita forzata disabilitata da uno dei due.
    ///
    /// Al risveglio la pausa torna, se è ancora la sua ora. Sospendere non è condonare: chiudere
    /// il coperchio non deve diventare il modo di saltare l'esercizio.
    private func observeSystemState() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspendForSystem()
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.resumeAfterSystem()
            }
        }
        // Il blocco schermo non passa da NSWorkspace: è una notifica distribuita di sistema, e
        // senza questa il caso più comune — ⌃⌘Q, o il coperchio chiuso e riaperto — resterebbe
        // scoperto.
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.suspendForSystem() }
        distributed.addObserver(
            forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main
        ) { [weak self] _ in self?.resumeAfterSystem() }
    }

    private func suspendForSystem() {
        guard isShowing, !suspended else { return }
        suspended = true
        NSApp.presentationOptions = []
        for window in windows { window.orderOut(nil) }
    }

    private func resumeAfterSystem() {
        guard isShowing, suspended else { return }
        suspended = false
        // Nel frattempo la pausa può essere finita: allora non si rimette su niente.
        guard model.phase == .breaking else { hide(); return }
        rebuildWindows()
        NSApp.presentationOptions = Self.kioskOptions
    }

    /// **Nessun `setActivationPolicy(.regular)`, nessun `activate(ignoringOtherApps:)`.**
    ///
    /// Erano lì per «prendersi il controllo», e su macOS 26 fanno il contrario: l'attivazione a
    /// comando non viene più concessa a un'app che non è già davanti, e il solo effetto rimasto
    /// è spostare il primo piano su Otium — senza attivarla e senza portare lo scudo nello Space
    /// dove sei tu, se quello Space appartiene a un'app a schermo intero. Il fuoco lo prende il
    /// pannello con `makeKeyAndOrderFront`, che funziona anche da app `.accessory`: misurato
    /// `isActive == true` e finestra key sopra iTerm a schermo intero. Vedi `BlockerWindow`.
    func show(plan: BreakPlan) {
        guard !isShowing else { return }
        isShowing = true
        suspended = false
        rebuildWindows()
        NSApp.presentationOptions = Self.kioskOptions

        // Se qualcosa riesce comunque a passare davanti, si torna davanti. Ogni due secondi,
        // che è abbastanza per essere ostinati e poco per pesare.
        //
        // Lo stesso battito è anche la **rete indipendente** sullo scudo orfano: prima di
        // rimettersi davanti, il blocco si chiede se la pausa che lo giustifica esiste ancora. È
        // deliberatamente ridondante con `AppModel.reconcileBlocker()` — vive in un altro strato,
        // e nell'incidente del 27-28 luglio è proprio lo strato di sopra ad aver dimenticato di
        // chiamare `hide()`. Se dimenticasse di nuovo, il nero durerebbe due secondi invece che
        // fino al tasto di accensione.
        //
        // **Si rimette davanti la finestra, non si riattiva l'app.** La riga di prima chiamava
        // `NSApp.activate` a ogni giro, ed è quella che sotto un'app a schermo intero produceva
        // il conflitto ogni due secondi: scrivi, ti si blocca, scrivi, ti si blocca. Il fuoco
        // ora si recupera per la via che funziona — e si riprende anche se per qualche motivo
        // il pannello avesse perso lo stato di key, che è il modo in cui questo difetto si
        // ripresenterebbe.
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, self.isShowing else { return }
            if SafetyNets.blockerWatchdog, self.model.phase != .breaking { self.hide(); return }
            guard !self.suspended else { return }
            guard let front = self.windows.first else { return }
            front.orderFrontRegardless()
            if !front.isKeyWindow { front.makeKeyAndOrderFront(nil) }
        }
        RunLoop.main.add(t, forMode: .common)
        reassertTimer = t
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        suspended = false
        reassertTimer?.invalidate()
        reassertTimer = nil
        NSApp.presentationOptions = []
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        // Niente da rimettere a posto: la pausa non tocca più la politica di attivazione, quindi
        // non c'è più nessun `savedPolicy` da ripristinare. L'app resta quella della barra di
        // stato dall'inizio alla fine.
    }

    private func rebuildWindows() {
        for window in windows { window.orderOut(nil) }
        windows.removeAll()

        for screen in NSScreen.screens {
            let view = NSHostingView(rootView: BreakView(model: model).frame(
                width: screen.frame.width, height: screen.frame.height
            ))
            let window = BlockerWindow(screen: screen, content: view)
            window.orderFrontRegardless()
            windows.append(window)
            if ProcessInfo.processInfo.environment["OTIUM_DEBUG"] != nil {
                FileHandle.standardError.write(
                    "schermo \(screen.frame) → finestra \(window.frame)\n".data(using: .utf8)!   // lingua: ok traccia di debug su stderr (OTIUM_DEBUG)
                )
            }
        }
        windows.first?.makeKeyAndOrderFront(nil)

        if ProcessInfo.processInfo.environment["OTIUM_DEBUG"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                for w in self?.windows ?? [] {
                    FileHandle.standardError.write("dopo 3 s: \(w.frame)\n".data(using: .utf8)!)
                }
            }
        }
    }
}

/// Il preavviso: un pannello piccolo, in basso a destra, che non ruba il fuoco.
///
/// Volutamente NON una notifica di sistema: quella richiederebbe un permesso, e il vincolo di
/// design è zero permessi. Un pannello proprio non chiede niente a nessuno.
final class WarningHUD {

    private var panel: NSPanel?
    private var dismissTimer: Timer?

    /// La frase dell'avvio: stesso angolo delle altre notifiche, pannello un po' più alto
    /// perché una riga di Seneca non sta in due righe da barra dei menu.
    func showQuote(_ phrase: Phrase, seconds: Double = 12) {
        present(
            NSHostingView(rootView: Dismissible(onDismiss: { [weak self] in self?.hide() }) {
                QuoteHUDView(phrase: phrase)
            }),
            // 132 erano un'altezza scritta a mano che una frase di due righe non riempiva: la
            // scatola sembrava vuota e grossa il doppio del necessario. Adesso 92 è solo il
            // **minimo** — `present` prende comunque il massimo fra questo e l'altezza vera del
            // contenuto, quindi una frase lunga alza il pannello invece di essere tagliata.
            // La larghezza viene da `QuoteWrap.Pannello`: la scatola e la colonna del testo devono
            // nascere dallo stesso numero, o tornano a divergere come il 2026-08-14.
            size: NSSize(width: QuoteWrap.Pannello.scatola, height: 92),
            sound: nil,
            seconds: seconds
        )
    }

    func show(title: String, subtitle: String, sound: String? = "Tink", seconds: Double = 8) {  // lingua: ok "Tink" è il nome di un suono di sistema, non un testo
        present(
            NSHostingView(rootView: Dismissible(onDismiss: { [weak self] in self?.hide() }) {
                HUDView(title: title, subtitle: subtitle)
            }),
            size: NSSize(width: 320, height: 84),
            sound: (sound?.isEmpty ?? true) ? nil : sound,
            seconds: seconds
        )
    }

    /// Il gesto vero delle notifiche di macOS: **due dita sul trackpad**, senza premere.
    ///
    /// Non è un trascinamento. Un trascinamento è pulsante premuto e mouse che si muove, e
    /// SwiftUI lo intercetta con `DragGesture`; due dita che scorrono sono eventi di
    /// **scorrimento**, che a `DragGesture` non arrivano mai. Misurato il 2026-07-27 con due
    /// sonde sulla notifica vera: il trascinamento la scartava già, lo scorrimento la lasciava
    /// lì. È questo che rendeva il gesto «non implementato» per chi usa il trackpad come con le
    /// notifiche di sistema — cioè sempre.
    ///
    /// Sta in AppKit e non in SwiftUI perché lo scorrimento orizzontale su una vista non
    /// scorrevole SwiftUI non lo espone: `scrollWheel(with:)` è l'unico punto in cui l'evento
    /// esiste davvero.
    private final class ScrollDismissView: NSView {
        var onDismiss: (() -> Void)?
        /// Quanto è stato spostato finora, in punti, verso destra.
        private var travelled: CGFloat = 0
        private let threshold: CGFloat = 70
        private let fadeOver: CGFloat = 220
        private var card: NSView? { subviews.first }

        /// Vero da quando la notifica sta uscendo di scena: dopo, ogni evento è rumore.
        private var dismissing = false
        /// Il ritorno indietro programmato, che l'inerzia in arrivo annulla.
        private var snapBack: DispatchWorkItem?

        /// **L'inerzia arriva DOPO che hai alzato le dita, ed è la ragione per cui il gesto
        /// sembrava incepparsi.**
        ///
        /// La prima versione decideva su `.ended`, cioè nell'istante esatto in cui le dita si
        /// staccano dal trackpad. Un colpetto veloce e corto sposta poco mentre lo tocchi — è la
        /// spinta che arriva dopo a portarlo lontano — quindi la notifica seguiva il dito, si
        /// fermava di botto e tornava al suo posto mentre il sistema la stava ancora spingendo.
        /// Gli eventi di inerzia c'erano, li scartava il ramo `default`.
        ///
        /// Ora le tre sorgenti dello stesso movimento — le dita, l'inerzia, la rotella classica
        /// senza fase — muovono tutte la stessa cosa, e la decisione arriva quando si è fermato
        /// davvero tutto.
        override func scrollWheel(with event: NSEvent) {
            guard !dismissing else { return }
            let phase = event.phase, momentum = event.momentumPhase

            if phase == .began {
                cancelSnapBack()
                travelled = 0
            }

            // Il verso è quello che il sistema chiama "destra" con le impostazioni dell'utente:
            // si somma il delta così com'è, senza correggerlo, o l'inversione dello scorrimento
            // naturale ribalterebbe il gesto senza dirlo.
            if phase == .changed || momentum == .changed || (phase == [] && momentum == []) {
                cancelSnapBack()
                // Solo verso destra, come le notifiche di sistema: a sinistra non si muove.
                travelled = max(0, travelled + event.scrollingDeltaX)
                apply(travelled, animated: false)
                if travelled > threshold { flyOut() }
                return
            }

            if phase == .ended || phase == .cancelled || momentum == .ended || momentum == .cancelled {
                scheduleSnapBack()
            }
        }

        /// Il ritorno non è immediato: fra l'ultimo evento delle dita e il primo dell'inerzia
        /// passa un battito, e chiudere la partita in mezzo è proprio il difetto che c'era.
        private func scheduleSnapBack() {
            cancelSnapBack()
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.dismissing else { return }
                self.travelled = 0
                self.apply(0, animated: true)
            }
            snapBack = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        private func cancelSnapBack() {
            snapBack?.cancel()
            snapBack = nil
        }

        private func flyOut() {
            guard !dismissing else { return }
            dismissing = true
            cancelSnapBack()
            apply(bounds.width, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.onDismiss?()
            }
        }

        private func apply(_ x: CGFloat, animated: Bool) {
            guard let card else { return }
            let alpha = Double(1 - min(1, x / fadeOver))
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    card.animator().setFrameOrigin(NSPoint(x: x, y: card.frame.origin.y))
                    card.animator().alphaValue = alpha
                }
            } else {
                // Durata zero esplicita: mentre insegui il dito ogni animazione implicita è un
                // ritardo, e un ritardo su un gesto si legge come scatto.
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0
                card.setFrameOrigin(NSPoint(x: x, y: card.frame.origin.y))
                card.alphaValue = alpha
                NSAnimationContext.endGrouping()
            }
        }
    }

    private func present(_ content: NSView, size richiesta: NSSize, sound: String?, seconds: Double) {
        hide()
        guard let screen = NSScreen.main else { return }
        // **La misura la detta il contenuto, non una costante.** L'altezza passata è un minimo:
        // se il testo va a capo il pannello si alza, invece di tagliarlo. Una costante scritta a
        // mano qui è una scommessa sulla lunghezza di ogni frase futura, e si perde in silenzio.
        let size = NSSize(
            width: richiesta.width,
            height: max(richiesta.height, ceil(content.fittingSize.height))
        )
        // In alto a destra, dove macOS mette le sue notifiche: è lì che l'occhio le cerca.
        // `visibleFrame` esclude già la barra dei menu, quindi il suo bordo alto è il posto giusto.
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - size.width - 16 - 0,
            y: screen.visibleFrame.maxY - size.height - 12
        )
        // La finestra è più larga del pannello: mentre scorre via deve avere spazio dove
        // andare, altrimenti il gesto lo taglia al bordo e sembra rotto.
        let travel: CGFloat = 460
        let p = NSPanel(
            contentRect: NSRect(origin: NSPoint(x: origin.x, y: origin.y),
                                size: NSSize(width: size.width + travel, height: size.height)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // Il contenuto resta ancorato a sinistra dentro la finestra allargata; il contenitore
        // ascolta lo scorrimento a due dita, che a SwiftUI non arriva.
        let host = ScrollDismissView(frame: NSRect(x: 0, y: 0, width: size.width + travel, height: size.height))
        host.onDismiss = { [weak self] in self?.hide() }
        content.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        host.addSubview(content)
        p.contentView = host
        p.orderFrontRegardless()
        panel = p

        if let sound { NSSound(named: sound)?.play() }

        // **Il puntatore sopra la scheda tiene viva la notifica**, come fanno quelle di macOS.
        // Deciso il 2026-08-11: una frase di tre righe non si legge in dodici
        // secondi mentre stai facendo altro, e il gesto che tutti provano è appoggiarci il mouse.
        //
        // **Perché si guarda dove sta il mouse invece di usare `NSTrackingArea`.** La prima
        // versione installava un'area di tracciamento e non funzionava: sonda a due poli del
        // 2026-08-11, col mouse fermo sopra la notifica spariva lo stesso. Otium vive nella barra
        // dei menu e il pannello è `.nonactivatingPanel`, quindi entrata e uscita del mouse non
        // gli vengono consegnate quando l'app non è in primo piano — cioè sempre. Leggere
        // `NSEvent.mouseLocation` non dipende da nessuna consegna di eventi.
        scadenza = Date().addingTimeInterval(seconds)
        let cardInSchermo = NSRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
        let vigile = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            if cardInSchermo.contains(NSEvent.mouseLocation) {
                self.scadenza = Date().addingTimeInterval(Self.graziaDopoIlPuntatore)
            } else if let s = self.scadenza, Date() >= s {
                self.hide()
            }
        }
        RunLoop.main.add(vigile, forMode: .common)
        dismissTimer = vigile
    }

    /// Quanto resta in vita dopo che il puntatore se n'è andato. Corto di proposito: chi ci ha
    /// appoggiato il mouse ha già letto, e rimettere i dodici secondi pieni terrebbe in mezzo
    /// allo schermo una notifica che ha finito il suo lavoro.
    private static let graziaDopoIlPuntatore: Double = 4
    private var scadenza: Date?

    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        scadenza = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
