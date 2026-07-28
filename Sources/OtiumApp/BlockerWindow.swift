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
final class BlockerWindow: NSWindow {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init(screen: NSScreen, content: NSView) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
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
    private var savedPolicy: NSApplication.ActivationPolicy = .accessory
    private var reassertTimer: Timer?
    private var isShowing = false

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
            guard let self, self.isShowing else { return }
            self.rebuildWindows()
        }
    }

    func show(plan: BreakPlan) {
        guard !isShowing else { return }
        isShowing = true
        savedPolicy = NSApp.activationPolicy()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        rebuildWindows()
        NSApp.presentationOptions = Self.kioskOptions

        // Se qualcosa riesce comunque a passare davanti, si torna davanti. Ogni due secondi,
        // che è abbastanza per essere ostinati e poco per pesare.
        let t = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self, self.isShowing else { return }
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
            self.windows.first?.makeKeyAndOrderFront(nil)
        }
        RunLoop.main.add(t, forMode: .common)
        reassertTimer = t
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        reassertTimer?.invalidate()
        reassertTimer = nil
        NSApp.presentationOptions = []
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        NSApp.setActivationPolicy(savedPolicy == .regular ? .regular : .accessory)
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
                    "schermo \(screen.frame) → finestra \(window.frame)\n".data(using: .utf8)!
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
            size: NSSize(width: 380, height: 132),
            sound: nil,
            seconds: seconds
        )
    }

    func show(title: String, subtitle: String, sound: String? = "Tink", seconds: Double = 8) {
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

    private func present(_ content: NSView, size: NSSize, sound: String?, seconds: Double) {
        hide()
        guard let screen = NSScreen.main else { return }
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

        let t = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in self?.hide() }
        RunLoop.main.add(t, forMode: .common)
        dismissTimer = t
    }

    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
