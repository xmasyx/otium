import AppKit
import CoreAudio
import Darwin
import IOKit.pwr_mgt
import OtiumCore

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

    public static func current() -> PresenceSignal? {
        if Date().timeIntervalSince(cachedAt) < refreshInterval { return cached }
        cachedAt = Date()
        cached = detect()
        return cached
    }

    /// **La domanda giusta è "cosa hai davanti", non "cosa sta suonando".**
    ///
    /// La prima versione provava l'audio per primo e si fermava lì. Con una scheda di Brave che
    /// suonava dietro, un PDF aperto davanti non veniva mai nemmeno guardato — misurato il
    /// 2026-07-26 sul Mac del principale, che se n'è accorto guardando l'output. Due difetti in
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
    static func detect() -> PresenceSignal? {
        guard let front = NSWorkspace.shared.frontmostApplication else { return nil }
        let classified = PresenceClassifier.classify(
            frontmost: front.bundleIdentifier,
            isPlayingAudio: isPlayingAudio(front),
            document: ReaderApps.isReader(front.bundleIdentifier)
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
            return PresenceSignal(kind: .media, detail: "audio in riproduzione — \(name)")
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
                detail: title.map { "\($0) — \(name)" } ?? "video in riproduzione — \(name)"
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
        return PresenceSignal(kind: .reading, detail: "documento aperto in \(name)")
    }

    /// Il documento aperto dall'app in primo piano, chiesto a `lsof`.
    ///
    /// Argomenti passati come array a `Process`, mai una stringa di shell: il PID viene da
    /// un'API di sistema, ma la regola non ammette eccezioni "tanto questo valore è sicuro".
    static func openDocument(pid: pid_t) -> String? {
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

/// Il LaunchAgent che riavvia Otium se qualcuno la uccide.
///
/// Con il registro delle lezioni davanti: *i plist sopravvivono ai cambi di sistema, i loro
/// bersagli no*. Per questo `state()` non chiede "il plist esiste?" ma "il file che il plist
/// lancia esiste ancora, ed è questo qui?" — un agent che punta a un binario sparito riparte
/// ogni giorno fallendo in silenzio.
public enum LaunchAgent {
    public static let label = "app.otium.mac"

    public static var plistURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    public enum State: Equatable {
        case notInstalled
        /// Installato e puntato al bundle giusto.
        case healthy
        /// Installato ma punta a un eseguibile che non esiste più.
        case danglingTarget(String)
        /// Installato ma punta a un'altra copia di Otium: l'app è stata spostata.
        case pointsElsewhere(String)
    }

    public static func currentExecutable() -> String {
        Bundle.main.executablePath ?? CommandLine.arguments.first ?? ""
    }

    public static func state() -> State {
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = plist as? [String: Any],
              let args = dict["ProgramArguments"] as? [String],
              let target = args.first
        else { return .notInstalled }

        if !FileManager.default.fileExists(atPath: target) { return .danglingTarget(target) }
        let mine = currentExecutable()
        if !mine.isEmpty, target != mine { return .pointsElsewhere(target) }
        return .healthy
    }

    @discardableResult
    public static func install() -> Bool {
        let executable = currentExecutable()
        guard !executable.isEmpty else { return false }
        // `KeepAlive: true` è la trappola, ed è costata un ciclo infinito riprodotto sul banco
        // il 2026-07-27: launchd avvia una copia, quella trova il lock già preso da Otium e
        // esce **pulita** (codice 0), launchd la rilancia perché "keep alive" significa
        // *sempre*, e si riparte — `state = spawn scheduled`, all'infinito.
        //
        // `SuccessfulExit: false` dice l'unica cosa che serve davvero: **rilancia solo se è
        // morta male**. Un'uscita pulita — la copia di troppo, o tu che scegli "Esci da Otium" —
        // resta un'uscita. Un `kill -9` no, e lì riparte, che è il motivo per cui esiste.
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 10,
            "ProcessType": "Interactive",
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict, format: .xml, options: 0
        ) else { return false }

        try? FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        guard (try? data.write(to: plistURL, options: .atomic)) != nil else { return false }
        bootout()
        return run(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    @discardableResult
    public static func uninstall() -> Bool {
        bootout()
        return (try? FileManager.default.removeItem(at: plistURL)) != nil
    }

    @discardableResult
    private static func bootout() -> Bool {
        run(["bootout", "gui/\(getuid())/\(label)"])
    }

    @discardableResult
    private static func run(_ args: [String]) -> Bool {
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
