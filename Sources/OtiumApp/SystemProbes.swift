import AppKit
import CoreAudio
import CoreMediaIO
import Darwin
import IOKit.pwr_mgt
import OtiumCore
import ServiceManagement

/// Da quanto non tocchi niente. È l'unico ingrediente che serve per misurare il tempo attivo,
/// e non richiede **nessun** permesso: né Accessibilità, né Registrazione schermo, né Input
/// Monitoring. È la ragione per cui Otium non compare in Impostazioni → Privacy.
public enum IdleProbe {
    /// `~0` è `kCGAnyInputEventType`: qualunque evento di input umano — tastiera, mouse, trackpad.
    private static let anyInput = CGEventType(rawValue: ~0)!

    public static func seconds() -> Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}

/// Il radar delle call: c'è un ingresso audio in funzione da qualche parte nel sistema?
///
/// Legge `kAudioDevicePropertyDeviceIsRunningSomewhere`, che dice *se* un dispositivo è in uso
/// senza aprire nessuno stream — quindi niente permesso microfono, e nessun byte di audio
/// letto. Serve a una cosa sola: non coprire lo schermo mentre stai parlando con un cliente.
public enum MicRadar {

    public static func isInputActive() -> Bool {
        for device in inputDevices() where isRunningSomewhere(device) {
            return true
        }
        return false
    }

    private static func inputDevices() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        ) == noErr else { return [] }

        return ids.filter { hasInputStreams($0) }
    }

    private static func hasInputStreams(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else {
            return false
        }
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: 16)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, buffer) == noErr else {
            return false
        }
        let list = buffer.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(list).contains { $0.mNumberChannels > 0 }
    }

    private static func isRunningSomewhere(_ device: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else {
            return false
        }
        return running != 0
    }
}

/// Il radar delle videochiamate: una telecamera sta riprendendo?
///
/// È il gemello esatto di `MicRadar`, su `kCMIODevicePropertyDeviceIsRunningSomewhere`, e come
/// quello **non chiede nessun permesso**: dice *se* un dispositivo è in uso, non cosa inquadra, e
/// nessuno stream viene aperto. Otium continua a non comparire in Privacy → Telecamera, che è
/// l'invariante su cui è costruita tutta l'app.
///
/// Perché serve accanto al microfono: il microfono da solo non distingue «seduto in riunione» da
/// «in piedi che cammina con gli AirPods». La telecamera accesa sì — quello è sempre qualcuno
/// seduto davanti allo schermo, ed è il segnale forte.
public enum CameraRadar {

    public static func isCapturing() -> Bool {
        for device in devices() where isRunningSomewhere(device) {
            return true
        }
        return false
    }

    private static func devices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, &size
        ) == noErr, size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        var ids = [CMIOObjectID](repeating: 0, count: count)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &address, 0, nil, size, &used, &ids
        ) == noErr else { return [] }
        return ids
    }

    private static func isRunningSomewhere(_ device: CMIOObjectID) -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var running: UInt32 = 0
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &used, &running
        ) == noErr else { return false }
        return running != 0
    }
}

/// Il radar della presenza: perché sei davanti al Mac pur non toccando niente.
///
/// Due strati, entrambi **senza alcun permesso**:
/// 1. chi tiene sveglio lo schermo (video in riproduzione), letto per processo e non come flag;
/// 2. quale app è in primo piano e quale documento tiene aperto (`lsof` sui tuoi processi).
public enum PresenceRadar {

    /// Ogni quanto rileggere. `lsof` costa qualche decina di millisecondi: a 1 Hz sarebbe uno
    /// spreco, ogni 8 secondi è invisibile e abbastanza pronto.
    private static let refreshInterval: TimeInterval = 8
    private static var cached: PresenceSignal?
    private static var cachedAt: Date = .distantPast
    /// Quante volte è stato davvero lanciato `lsof`. Un contatore e non una stima: senza,
    /// «adesso gira solo nel preavviso» resta un'affermazione nei commenti.
    public private(set) static var documentLookups = 0

    /// Solo per le sonde: azzera cache e contatore, così la misura parte da zero.
    public static func resetForProbe() {
        cached = nil
        cachedAt = .distantPast
        documentLookups = 0
    }

    /// - Parameter includeDocument: vedi `detect(includeDocument:)`. La cache non distingue fra
    ///   una lettura col documento e una senza, e va bene così: il dettaglio in più non cambia il
    ///   verdetto, e un secondo campione appena chiesto il primo sarebbe solo un altro `lsof`.
    public static func current(
        includeDocument: Bool = false,
        microphoneActive: Bool = false,
        cameraActive: Bool = false
    ) -> PresenceSignal? {
        // La call scavalca la cache: vedi `PresenceClassifier.call`.
        if let inCall = PresenceClassifier.call(microphoneActive: microphoneActive,
                                                cameraActive: cameraActive) {
            return inCall
        }
        if Date().timeIntervalSince(cachedAt) < refreshInterval { return cached }
        cachedAt = Date()
        cached = detect(includeDocument: includeDocument)
        return cached
    }

    /// **La domanda giusta è "cosa hai davanti", non "cosa sta suonando".**
    ///
    /// La prima versione provava l'audio per primo e si fermava lì. Con una scheda di Brave che
    /// suonava dietro, un PDF aperto davanti non veniva mai nemmeno guardato — misurato il
    /// 2026-07-26 sul Mac di sviluppo, e me ne sono accorto guardando l'output. Due difetti in
    /// uno: la lettura restava invisibile, e la musica di sottofondo bastava a dichiarare "sta
    /// guardando un video", col tetto largo dei 45 minuti, anche mentre nessuno era in stanza.
    ///
    /// Ora si parte dall'app in primo piano e la si classifica. L'audio non è più un segnale a
    /// sé: è la **conferma** che il player davanti a te sta davvero riproducendo qualcosa.
    /// Raccoglie i fatti dal sistema e li passa al classificatore, che vive nel nucleo ed è
    /// provato ramo per ramo. Qui non si decide niente.
    ///
    /// Il rischio del ramo "browser che non suona = lettura" — browser lasciato davanti mentre
    /// esci — è limitato due volte: dal tetto dei 15 minuti, e dal fatto che una pausa scattata
    /// a scrivania vuota si scioglie da sola e si registra come naturale. L'errore opposto non
    /// ha rete: leggere un articolo lungo verrebbe contato come assenza, e ti regalerebbe pause
    /// mai fatte — cioè il difetto che questo radar esiste per uccidere.
    /// - Parameter includeDocument: chiedere **quale** documento è aperto costa un processo
    ///   esterno (`lsof`), misurato in ~31 ms e 0,03 s di CPU a chiamata. La cache da 8 secondi
    ///   lo teneva già a bada — la prima stima dell'audit, «ogni tre secondi», era sbagliata e
    ///   l'ha corretta il codice — ma 0,03 s ogni 8 fanno comunque circa lo 0,4% di un core, tre
    ///   volte quello che l'app consuma in tutto (0,13% misurato), e per giunta solo mentre hai
    ///   davanti Anteprima o Word.
    ///
    ///   E non serviva a decidere niente: la classificazione di un'app da lettura è `.reading`
    ///   **con o senza** il nome del documento — guarda `PresenceClassifier`, il ramo è lo stesso.
    ///   Il nome serve solo alla riga che compare nella schermata di blocco, cioè una volta ogni
    ///   mezz'ora e non venti volte al minuto. Trovato durante l'audit del 2026-07-28.
    static func detect(
        includeDocument: Bool = false,
        microphoneActive: Bool = false,
        cameraActive: Bool = false
    ) -> PresenceSignal? {
        if let inCall = PresenceClassifier.call(microphoneActive: microphoneActive,
                                                cameraActive: cameraActive) {
            return inCall
        }
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let classified = PresenceClassifier.classify(
            frontmost: front.bundleIdentifier,
            isPlayingAudio: isPlayingAudio(front),
            document: includeDocument && ReaderApps.isReader(front.bundleIdentifier)
                ? openDocument(pid: front.processIdentifier) : nil,
            appName: front.localizedName ?? "un'app"
        )
        // Ultima rete: un player che tiene sveglio lo schermo pur non essendo in primo piano
        // (a schermo intero su un altro spazio, per esempio). Non tutti lo fanno — i browser
        // Chromium mai — ma quando c'è, è un segnale onesto.
        return classified ?? detectMedia()
    }

    /// Sta suonando **quest'app**? Confronto per bundle e non per PID: chi produce l'audio è un
    /// processo helper, e la risoluzione restituisce l'app che lo possiede.
    static func isPlayingAudio(_ app: NSRunningApplication) -> Bool {
        guard let identifier = app.bundleIdentifier else { return false }
        for object in audioProcessObjects() {
            guard isRunningOutput(object), let pid = audioProcessPID(object) else { continue }
            if owningApplication(pid: pid)?.bundleIdentifier == identifier { return true }
        }
        return false
    }

    // MARK: - Strato 0: chi sta suonando (il segnale che funziona davvero)

    /// Quale app sta producendo audio, attribuita al processo.
    ///
    /// È il segnale primario per il video, e ci è voluto un guasto per scoprirlo: Brave — come
    /// ogni browser Chromium — **non alza alcuna asserzione sullo schermo** mentre riproduce un
    /// video (misurato il 2026-07-26: nell'elenco completo delle asserzioni c'erano solo
    /// `caffeinate`, `powerd` e WindowServer, con YouTube in riproduzione). L'audio invece si
    /// vede sempre.
    ///
    /// Il secondo inciampo, dentro il primo: il processo che suona è
    /// `Brave Browser Helper.app`, un helper annidato dentro `Brave Browser.app`. Per il sistema
    /// non è un'applicazione — `NSRunningApplication(processIdentifier:)` risponde `nil` — quindi
    /// va risalito il percorso dell'eseguibile fino al bundle `.app` più esterno.
    static func detectAudio() -> PresenceSignal? {
        for object in audioProcessObjects() {
            guard isRunningOutput(object), let pid = audioProcessPID(object) else { continue }
            guard let app = owningApplication(pid: pid),
                  MediaPlayers.isPlayer(app.bundleIdentifier)
            else { continue }
            let name = app.localizedName ?? app.bundleIdentifier ?? "un player"
            return PresenceSignal(kind: .media,
                                  detail: L.t("audio in riproduzione — \(name)",
                                              "audio playing — \(name)"))
        }
        return nil
    }

    /// Da un PID qualsiasi all'app che lo possiede, helper annidati compresi.
    static func owningApplication(pid: pid_t) -> NSRunningApplication? {
        if let direct = NSRunningApplication(processIdentifier: pid) { return direct }
        guard let path = executablePath(pid: pid),
              let appPath = outermostAppBundle(in: path),
              let identifier = Bundle(path: appPath)?.bundleIdentifier
        else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
    }

    /// Il `.app` più **esterno** nel percorso: `/Applications/Brave Browser.app/Contents/…/
    /// Brave Browser Helper.app/Contents/MacOS/…` deve dare Brave, non l'helper.
    static func outermostAppBundle(in path: String) -> String? {
        guard let range = path.range(of: ".app/") else {
            return path.hasSuffix(".app") ? path : nil
        }
        return String(path[path.startIndex..<range.lowerBound]) + ".app"
    }

    static func executablePath(pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func audioProcessObjects() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr, size > 0 else { return [] }

        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        ) == noErr else { return [] }
        return ids
    }

    private static func isRunningOutput(_ object: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &running) == noErr
        else { return false }
        return running != 0
    }

    private static func audioProcessPID(_ object: AudioObjectID) -> pid_t? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &pid) == noErr,
              pid > 0 else { return nil }
        return pid
    }

    // MARK: - Strato 1: chi tiene sveglio lo schermo

    /// Legge le asserzioni **per processo**, non il flag globale.
    ///
    /// Il flag globale `PreventUserIdleDisplaySleep` lo può alzare chiunque; durante lo sviluppo
    /// girava un `caffeinate` lanciato da Claude Code. Guardare il flag e non il proprietario
    /// significa scambiare uno strumento da riga di comando per un film — e bloccare lo schermo
    /// di qualcuno che non c'è. Contano solo i player in elenco: uno sconosciuto non conta, e il
    /// peggio che capita è comportarsi come prima.
    static func detectMedia() -> PresenceSignal? {
        var assertions: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
              let byProcess = assertions?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return nil }

        for (pidNumber, list) in byProcess {
            let pid = pid_t(truncating: pidNumber)
            let holdsDisplay = list.contains { entry in
                (entry[kIOPMAssertionTypeKey as String] as? String) == (kIOPMAssertionTypePreventUserIdleDisplaySleep as String)
            }
            guard holdsDisplay,
                  let app = NSRunningApplication(processIdentifier: pid),
                  MediaPlayers.isPlayer(app.bundleIdentifier)
            else { continue }

            let name = app.localizedName ?? app.bundleIdentifier ?? "un player"
            let title = list.compactMap { $0[kIOPMAssertionNameKey as String] as? String }
                .first { !$0.isEmpty && $0.count < 80 }
            return PresenceSignal(
                kind: .media,
                detail: title.map { "\($0) — \(name)" }
                    ?? L.t("video in riproduzione — \(name)", "video playing — \(name)")
            )
        }
        return nil
    }

    // MARK: - Strato 2: cosa stai leggendo

    static func detectReading() -> PresenceSignal? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              ReaderApps.isReader(app.bundleIdentifier)
        else { return nil }

        let name = app.localizedName ?? "un lettore"
        if let document = openDocument(pid: app.processIdentifier) {
            return PresenceSignal(kind: .reading, detail: "\(document) — \(name)")
        }
        return PresenceSignal(kind: .reading,
                              detail: L.t("documento aperto in \(name)",
                                          "document open in \(name)"))
    }

    /// Il documento aperto dall'app in primo piano, chiesto a `lsof`.
    ///
    /// Argomenti passati come array a `Process`, mai una stringa di shell: il PID viene da
    /// un'API di sistema, ma la regola non ammette eccezioni "tanto questo valore è sicuro".
    static func openDocument(pid: pid_t) -> String? {
        documentLookups += 1
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-p", String(pid), "-Fn"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n") where line.hasPrefix("n/") {
            let path = String(line.dropFirst())
            guard ReadingDocument.isReadable(path) else { continue }
            // I file di supporto dell'app non sono quello che stai leggendo.
            if path.contains("/Library/") || path.contains("/System/") || path.contains(".app/") {
                continue
            }
            return (path as NSString).lastPathComponent
        }
        return nil
    }
}


/// L'avvio automatico, affidato a `SMAppService` invece che a un LaunchAgent scritto a mano.
///
/// **Perché è cambiato, il 2026-08-03.** La versione precedente scriveva un plist in
/// `~/Library/LaunchAgents` e lo caricava con `launchctl`. Funzionava, ma macOS lo cataloga come
/// *legacy agent*: nel registro degli elementi in background (`sfltool dumpbtm`) il record esce
/// `Type: legacy agent (0x10008)`, `Parent Identifier: Unknown Developer`, finisce nella sezione
/// «Consenti in background» e **non compare fra le app di «Apri al login»**, che è dove
/// sono andato a cercarlo senza trovarlo.
///
/// **La colpa non era della firma**, ed è la prova che ha chiuso il caso: Kalamos è firmata allo
/// stesso modo, senza Team ID e con `Developer Name: (null)`, e usa questa API. È l'API a decidere
/// la categoria, non il certificato.
///
/// **L'avviso «Attività app in background» non c'entra con questa scelta, e la riga che diceva il
/// contrario era una diagnosi sbagliata** (corretta il 2026-08-04). Non tornava «dopo ogni
/// ricostruzione del bundle»: tornava a ogni login perché LaunchServices aveva registrate, sotto
/// `app.otium.mac`, due copie usa-e-getta dell'app in cartelle temporanee ormai cancellate. A ogni
/// login le ripassa, non le trova, e annuncia l'app come disinstallata; il gestore degli elementi
/// in background ricalcola il record e rispunta l'avviso. Provato nel log unificato: due annunci
/// alle 11:10:30, esattamente quante erano le copie morte, e l'agente della notifica due secondi
/// dopo. Riparato togliendole dal registro con `lsregister -u <percorso>`, senza toccare una riga
/// di questo file. **Il probe, se ricapita:** `lsregister -dump`, elencare i `path:` che finiscono
/// in `.app` e cercare quelli che sul disco non esistono più.
///
/// **Cosa si perde, dichiarato:** il `KeepAlive` che rilanciava Otium dopo un `kill -9`. Scelto
/// il 2026-08-03, con due fatti davanti: la via d'uscita facile («Esci da Otium», uscita pulita)
/// non era coperta comunque, quindi l'anti-imbroglio sprangava una finestra lasciando aperta la
/// porta; e i rapporti di crash in `~/Library/Logs/DiagnosticReports` erano zero. Resta il
/// ripristino a caldo di `SessionEngine.restore()`, che è il vero paracadute: riaperta entro la
/// finestra di grazia, l'app riprende il conto da dov'era.
///
/// **Cosa si guadagna, oltre alla categoria giusta:** non c'è più un percorso da tenere allineato.
/// `SMAppService.mainApp` registra *il bundle*, non un eseguibile scritto dentro un plist, quindi
/// gli stati «punta a un file che non esiste più» e «punta a un'altra copia» **non possono più
/// esistere** — e con loro sparisce la logica che li riparava.
public enum LoginItem {
    /// L'etichetta del vecchio agent. Vive ancora qui per una ragione sola: toglierlo dai Mac
    /// che ce l'hanno già.
    public static let legacyLabel = "app.otium.mac"   // lingua: ok identificativo launchd, non un testo

    public enum State: Equatable {
        /// Mai registrato: Otium non riparte da sola.
        case notRegistered
        /// Registrato e acceso.
        case enabled
        /// Registrato, ma spento da te in Impostazioni di Sistema. **L'app non prova a
        /// riaccenderlo**: quell'interruttore è tuo, e un'app che rimette ciò che hai appena
        /// tolto è un'app che non ascolta.
        case requiresApproval
        /// macOS non ha un bundle da registrare. È il caso del binario di sviluppo lanciato da
        /// `.build/`, che non sta dentro un `.app`.
        case notFound
    }

    public static func state() -> State {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        case .notRegistered: return .notRegistered
        // Uno stato che oggi non esiste non è «sano»: lo si tratta come non registrato, che è la
        // risposta che si auto-corregge, perché registrare di nuovo è idempotente. Dichiarato qui
        // invece che lasciato al ramo muto.
        @unknown default: return .notRegistered
        }
    }

    /// **Quale copia farà partire macOS**, che non è la domanda a cui risponde `state()`.
    ///
    /// `SMAppService.mainApp.status` cerca un record per l'**identificativo** del bundle e dice
    /// se c'è. Non dice *quale* cartella quel record contiene, e le due cose divergono: il
    /// registro segue l'ultima copia aperta, quindi basta aprire una volta un `Otium.app`
    /// scompattato in una cartella temporanea perché l'avvio al login resti agganciato lì.
    ///
    /// **Il caso vero, il 2026-08-14.** Il record puntava a
    /// `/private/var/folders/…/T/tmp.9i98uuXsau/unpacked/Otium.app`, cancellata da giorni. Al
    /// login macOS apriva un percorso inesistente e taceva; `status` rispondeva `.enabled` e il
    /// doctor scriveva «attivo». Nel log unificato di quel boot non c'è una riga che nomini
    /// Otium: non è partita perché nessuno ci ha provato, e nessun controllo se n'è accorto.
    ///
    /// **Perché un sottoprocesso.** Il registro degli elementi in background non ha un'API
    /// pubblica di lettura: `sfltool dumpbtm` è l'unica strada. È l'eccezione dichiarata alla
    /// regola «un fatto leggibile dal sistema non si va a cercare fuori», perché qui il sistema
    /// non lo espone.
    ///
    /// **`nil` vuol dire non misurabile, mai sano.** Se `sfltool` manca, esce male o cambia
    /// formato, questa torna `nil` e chi chiama lo riporta come tale invece di dedurne che va
    /// tutto bene. Il ramo muto è il guasto che questa funzione esiste per togliere.
    ///
    /// **Va chiamata PRIMA di `state()`, e non è una preferenza.** Leggere
    /// `SMAppService.mainApp.status` riscrive il record sul bundle che chiede: misurato lo stesso
    /// giorno isolando la lettura in `--agent-status`, eseguito da una copia in `/tmp` il record
    /// è passato dalla generazione 33 su `/Applications` alla 34 su quella copia, mentre un
    /// `--version` dalla stessa copia non lo muove. Chiamata dopo, questa funzione risponde
    /// sempre «sei tu», cioè misura l'effetto della domanda invece dello stato che precedeva.
    public static func registeredBundleURL() -> URL? {
        let tool = "/usr/bin/sfltool"
        guard FileManager.default.isExecutableFile(atPath: tool) else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["dumpbtm"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }

        // **Due secondi e poi si molla, perché `sfltool` si pianta davvero.**
        //
        // Successo il 2026-08-14, mentre provavo questa stessa funzione: dopo qualche decina di
        // interrogazioni `sfltool dumpbtm` ha smesso di rispondere, a riga di comando come da
        // qui, e `--doctor` è rimasto appeso per sempre invece di riferire. Un diagnostico che si
        // pianta è peggio di uno che dice «non lo so»: si usa quando qualcosa è già rotto, e in
        // quel momento deve rispondere comunque.
        //
        // Il ramo di scadenza non tocca il buffer letto dall'altra coda: sul percorso buono è il
        // semaforo a garantire l'ordine, su quello di scadenza il dato non si guarda proprio.
        final class Buffer: @unchecked Sendable { var dati: Data? }
        let buffer = Buffer()
        let letto = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            buffer.dati = pipe.fileHandleForReading.readDataToEndOfFile()
            letto.signal()
        }
        guard letto.wait(timeout: .now() + .seconds(2)) == .success else {
            process.terminate()
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let data = buffer.dati,
              let dump = String(data: data, encoding: .utf8) else { return nil }

        let cercato = Bundle.main.bundleIdentifier ?? legacyLabel

        // Dentro un record `URL:` precede `Bundle Identifier:`, quindi si tiene l'ultimo URL
        // visto e lo si restituisce quando l'identificativo combacia. Se combacia un altro
        // identificativo, l'URL tenuto da parte si butta: appartiene a quel record, non al
        // prossimo, e riportarlo avanti farebbe rispondere il percorso di un'altra app.
        var ultimoURL: URL?
        for riga in dump.split(separator: "\n", omittingEmptySubsequences: false) {
            let linea = riga.trimmingCharacters(in: .whitespaces)
            if linea.hasPrefix("URL:") {
                let valore = linea.dropFirst("URL:".count).trimmingCharacters(in: .whitespaces)
                ultimoURL = URL(string: valore)
            } else if linea.hasPrefix("Bundle Identifier:") {
                let valore = linea.dropFirst("Bundle Identifier:".count).trimmingCharacters(in: .whitespaces)
                if valore == cercato { return ultimoURL }
                ultimoURL = nil
            }
        }
        return nil
    }

    /// Registra l'avvio al login. `false` se macOS rifiuta, e il motivo va nel log invece di
    /// sparire: un fallimento silenzioso qui è indistinguibile da un successo.
    @discardableResult
    public static func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            NSLog("Otium: avvio al login non registrato — \(error.localizedDescription)")   // lingua: ok riga di log, non testo a schermo
            return false
        }
    }

    @discardableResult
    public static func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            return true
        } catch {
            NSLog("Otium: avvio al login non rimosso — \(error.localizedDescription)")   // lingua: ok riga di log, non testo a schermo
            return false
        }
    }

    // MARK: - Il vecchio agent, da togliere una volta sola

    public static var legacyPlistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(legacyLabel).plist")
    }

    public static func legacyAgentInstalled() -> Bool {
        FileManager.default.fileExists(atPath: legacyPlistURL.path)
    }

    /// Toglie il vecchio agent: prima lo scarica da launchd, poi cancella il plist.
    ///
    /// L'ordine non è indifferente. Cancellare il file senza `bootout` lascia il job **caricato**
    /// fino al prossimo login, quindi launchd continuerebbe a rilanciare la copia vecchia
    /// *accanto* a quella registrata qui, e il registro degli elementi in background
    /// continuerebbe a mostrare l'elemento legacy che è tutta la ragione di questo cambiamento.
    @discardableResult
    public static func removeLegacyAgent() -> Bool {
        guard legacyAgentInstalled() else { return false }
        launchctl(["bootout", "gui/\(getuid())/\(legacyLabel)"])
        return (try? FileManager.default.removeItem(at: legacyPlistURL)) != nil
    }

    @discardableResult
    private static func launchctl(_ args: [String]) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
