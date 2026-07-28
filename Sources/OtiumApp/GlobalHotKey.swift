import AppKit
import Carbon.HIToolbox

/// Una scorciatoia che funziona **da qualunque app**, senza chiedere permessi.
///
/// Il vincolo di Otium è zero permessi di sistema, e qui si vede: la via moderna
/// (`NSEvent.addGlobalMonitorForEvents`) pretende il Monitoraggio input in Impostazioni, cioè
/// esattamente il permesso che l'app ha promesso di non chiedere. `RegisterEventHotKey` è vecchia
/// — è Carbon — ma è l'unica che registra un tasto globale **senza** chiedere niente a nessuno.
///
/// **Quello che una scorciatoia globale porta con sé, detto qui e non nascosto:** il tasto viene
/// tolto a tutte le altre app. ⌃S in un terminale è XOFF, il tasto che congela l'output, e in
/// Emacs è la ricerca incrementale. Da quando questa registrazione è viva, in quelle due situazioni
/// ⌃S apre le statistiche invece di fare quello che facevano prima. È una scelta del principale
/// (2026-07-28), e si cambia da una sola costante in `AppDelegate`.
final class GlobalHotKey {

    /// La registrazione è per processo, e il gestore C non può catturare `self`: gli si passa
    /// l'identificatore, e qui si ritrova cosa fare.
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextIdentifier: UInt32 = 1
    private static var handlerInstalled = false

    private let identifier: UInt32
    private var reference: EventHotKeyRef?

    /// `nil` se il tasto è già di qualcun altro: un fallimento silenzioso qui sarebbe una
    /// scorciatoia che non c'è e nessuno lo sa, cioè il difetto che ⌘S aveva già.
    init?(keyCode: UInt32, carbonModifiers: UInt32, action: @escaping () -> Void) {
        Self.installHandlerIfNeeded()
        identifier = Self.nextIdentifier
        Self.nextIdentifier += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F_54_4D_5A), id: identifier)  // 'OTMZ'
        let status = RegisterEventHotKey(
            keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr, let ref else { return nil }
        reference = ref
        Self.actions[identifier] = action
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        Self.actions[identifier] = nil
    }

    /// Il ponte con Carbon: un gestore solo per tutto il processo, che smista sull'identificatore.
    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &id
                )
                guard status == noErr else { return status }
                DispatchQueue.main.async { GlobalHotKey.actions[id.id]?() }
                return noErr
            },
            1, &spec, nil, nil
        )
    }

    /// Serve alla sonda: fa scattare il gestore senza premere niente, per provare che il ponte
    /// con Carbon è cablato. **Non** prova che il sistema consegni il tasto — quello lo prova
    /// solo un dito, o un evento sintetico posato sul tap di sistema.
    func fireForProbe() {
        Self.actions[identifier]?()
    }
}
