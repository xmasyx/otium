import AppKit
import Carbon.HIToolbox
import OtiumCore

/// Autodiagnosi: `Otium --doctor`.
///
/// Risponde all'unica domanda che conta quando «non funziona»: **quale** delle cose da cui Otium
/// dipende è rotta, e con quale comando si aggiusta.
///
/// Volutamente autonomo. Legge il disco direttamente e non tocca `AppModel`: gira prima che
/// esista uno stato dell'app, e non può essere rotto dalla stessa configurazione sbagliata che
/// deve riportare. Per la stessa ragione **non passa da `ProbeMode`**: deve guardare i file veri,
/// non una cartella usa e getta, o direbbe che va tutto bene guardando altrove.
///
/// Esce con 0 quando ogni controllo **obbligatorio** passa, con 1 altrimenti. Gli stati — avvio
/// automatico assente, onboarding non fatto, crescita spenta — si riportano e non fanno mai
/// fallire: sono scelte, non guasti.
///
/// La ragione per cui esiste, con una data: il 2026-07-28 le mie sonde hanno dirottato l'avvio
/// automatico su `.build/debug/OtiumApp`, un binario che ogni `swift build`
/// sovrascrive. Al login sarebbe partita una copia di lavoro, in silenzio, e l'ho scoperto per
/// caso mezz'ora dopo. Un `--doctor` lo diceva in due secondi.
enum Doctor {

    private enum Verdict {
        case ok(String)
        case warn(String)
        case fail(String, fix: String)

        var mark: String {
            switch self {
            case .ok: return "✅"
            case .warn: return "⚠️ "
            case .fail: return "❌"
            }
        }
        var detail: String {
            switch self {
            case .ok(let d), .warn(let d), .fail(let d, _): return d
            }
        }
    }

    /// **Il nome di chi segnala fuori dal referto.**
    ///
    /// Questo testo nasce per essere incollato in una segnalazione pubblica — lo dice il README e
    /// lo propone il pulsante «Segnala un problema…» — e conteneva la cartella home due volte,
    /// cioè il nome dell'utente. Una funzione che si usa quando qualcosa è già andato storto non
    /// deve chiedere in cambio anche il nome, quindi la home diventa `~` prima di uscire.
    ///
    /// **Prefisso e non regex.** `/Users/[^/]+` sembra equivalente e non lo è: la home vera la
    /// conosce il sistema, mentre il modello indovinato sbaglia su chi ce l'ha altrove, e quel
    /// caso fallirebbe in silenzio proprio dove il silenzio costa il nome.
    static func senzaNome(_ percorso: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard !home.isEmpty, percorso.hasPrefix(home) else { return percorso }
        return "~" + percorso.dropFirst(home.count)
    }

    /// Il rapporto come testo, più quanti controlli **obbligatori** sono falliti.
    static func report() -> (text: String, failures: Int) {
        var lines: [String] = ["Otium — doctor", ""]
        var failures = 0
        var fixes: [String] = []

        func riga(_ titolo: String, _ v: Verdict) {
            lines.append("\(v.mark) \(titolo.padding(toLength: max(titolo.count, 28), withPad: " ", startingAt: 0))  \(v.detail)")
            if case .fail(_, let fix) = v { failures += 1; fixes.append(fix) }
        }

        // ── Quale copia sta parlando, e quale girerà al prossimo avvio
        let versione = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let eseguibile = Bundle.main.executablePath ?? CommandLine.arguments.first ?? "?"
        lines.append("versione   \(versione)")
        lines.append("sistema    macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        lines.append("binario    \(Self.senzaNome(eseguibile))")
        lines.append("dati       \(Self.senzaNome(Paths.supportDirectory.path))")
        lines.append("")

        // ── La cartella dei dati: senza scrittura qui, l'app conta e non registra
        riga("cartella dei dati", cartellaScrivibile())

        // ── I cinque file di stato, uno per uno. Il caso che conta davvero è il file
        // ESISTENTE ma non scrivibile: da lì nasceva la perdita del registro.
        for (nome, url, obbligatorio) in [
            ("registro", Paths.ledgerFile, true),
            ("impostazioni", Paths.settingsFile, true),
            ("rotazione", Paths.rotationFile, false),
            ("mazzi delle frasi", Paths.decksFile, false),
            ("progressione", Paths.progressFile, false),
        ] {
            riga(nome, statoFile(url, obbligatorio: obbligatorio))
        }

        // ── Righe illeggibili: il registro sopravvive, ma i numeri sarebbero più bassi del vero
        riga("integrità del registro", integritaRegistro())

        // ── Due istanze contano lo stesso tempo due volte
        riga("istanza unica", istanzaUnica())

        // ── L'avvio automatico, il controllo per cui questo comando esiste
        riga("avvio automatico", avvioAutomatico())

        // ── Il residuo della vecchia via, che ne farebbe partire due
        riga("vecchio LaunchAgent", vecchioAgent())

        // ── Le due risposte del primo avvio
        riga("primo avvio", primoAvvio())

        // ── La scorciatoia globale
        riga("scorciatoia ⌃S", scorciatoia())

        if !fixes.isEmpty {
            lines.append("")
            lines.append("Da fare:")
            for f in fixes { lines.append("  · \(f)") }
        }
        lines.append("")
        lines.append(failures == 0
                     ? "Tutto a posto."
                     : "\(failures) controll\(failures == 1 ? "o" : "i") da sistemare.")
        return (lines.joined(separator: "\n"), failures)
    }

    static func run() -> Int32 {
        let r = report()
        print(r.text)
        return r.failures == 0 ? 0 : 1
    }

    // MARK: - I controlli

    private static func cartellaScrivibile() -> Verdict {
        let dir = Paths.supportDirectory
        Paths.ensureDirectory()
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
            return .fail("non esiste e non si è potuta creare",
                         fix: "controlla i permessi di ~/Library/Application Support")
        }
        guard FileManager.default.isWritableFile(atPath: dir.path) else {
            return .fail("esiste ma non è scrivibile",
                         fix: "chmod u+w \"\(dir.path)\"")
        }
        return .ok("scrivibile")
    }

    /// **Esistente e non scrivibile è il caso peggiore**, e non si vede da fuori: l'app continua a
    /// contare e crede di registrare. È il difetto trovato dall'audit del 2026-07-28.
    private static func statoFile(_ url: URL, obbligatorio: Bool) -> Verdict {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return obbligatorio
                ? .warn("non c'è ancora (si crea al primo uso)")
                : .ok("non c'è ancora")
        }
        let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
        guard fm.isReadableFile(atPath: url.path) else {
            return .fail("non leggibile", fix: "chmod u+r \"\(url.path)\"")
        }
        guard fm.isWritableFile(atPath: url.path) else {
            return .fail("NON SCRIVIBILE: l'app conta e non registra",
                         fix: "chmod u+w \"\(url.path)\"")
        }
        return .ok("\(size) byte, leggibile e scrivibile")
    }

    private static func integritaRegistro() -> Verdict {
        let ledger = Ledger(url: Paths.ledgerFile)
        let righe = ledger.entries()
        let rotte = ledger.unreadableLines
        if rotte == 0 { return .ok("\(righe.count) righe, nessuna illeggibile") }
        return .warn("\(righe.count) righe buone, \(rotte) illeggibili — le statistiche le escludono")
    }

    private static func istanzaUnica() -> Verdict {
        let altre = NSRunningApplication
            .runningApplications(withBundleIdentifier: SingleInstance.bundleIdentifier)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        switch altre.count {
        case 0: return .ok("nessun'altra copia in esecuzione")
        case 1: return .ok("una copia viva, com'è giusto")
        default: return .fail("\(altre.count) copie vive: contano lo stesso tempo più volte",
                              fix: "pkill -f 'Otium.app/Contents/MacOS/Otium' e riapri l'app")
        }
    }

    /// **La domanda giusta non è «il file c'è», è «macOS lo farà partire».**
    ///
    /// Da quando l'avvio automatico passa da `SMAppService` (2026-08-03) non c'è più un percorso
    /// da confrontare: si registra il bundle, non un eseguibile scritto dentro un plist. Sparisce
    /// così tutta la classe di guasti che questa sonda cercava — bersaglio inesistente, bersaglio
    /// dentro `.build/` — e restano due domande vere: **è registrato?** e **l'hai spento tu?**
    ///
    /// **Correzione del 2026-08-14: le domande vere erano tre, e la terza mancava.** Registrare
    /// il bundle toglie il percorso dal *plist*, non dal *record*: quel record contiene comunque
    /// una cartella, e il registro la aggiorna seguendo l'ultima copia aperta. Aperta una volta
    /// una copia scompattata in `/var/folders/`, l'avvio al login è rimasto agganciato lì; poi
    /// la cartella temporanea è sparita, e al login macOS ha aperto un percorso inesistente
    /// senza dire niente. `status` continuava a rispondere `.enabled`, e questa riga scriveva
    /// «attivo» leggendo il nome del bundle **che stava girando**, cioè un'altra cosa da quella
    /// che le veniva chiesta. Adesso la terza domanda è esplicita: **quale copia?**
    ///
    /// Il doctor si lancia quasi sempre dal terminale, cioè dal binario di sviluppo, che non sta
    /// dentro un `.app`: lì lo stato è `notFound` e la risposta onesta è «non misurabile da qui»,
    /// non «rotto». È la stessa trappola già pagata: una sonda che risponde a una domanda più
    /// debole di quella che le hai fatto.
    private static func avvioAutomatico() -> Verdict {
        let dentroUnBundle = Bundle.main.bundleURL.pathExtension == "app"

        // **L'ordine di queste due righe è il controllo, non uno stile.**
        //
        // Misurato il 2026-08-14: **leggere `SMAppService.mainApp.status` riscrive il record**,
        // e lo fa puntare al bundle che sta chiedendo. Provato isolando la lettura in
        // `--agent-status`, che non registra niente: eseguito da una copia in `/tmp` il record è
        // passato dalla generazione 33, su `/Applications`, alla 34 su quella copia. Un
        // `--version` dalla stessa copia non lo muove, quindi è la lettura dello stato a farlo.
        //
        // La conseguenza è che una sonda scritta nell'ordine naturale non può essere rossa: il
        // gesto di chiedere «dove punta?» sposta la risposta su di sé, e ogni copia si vede
        // sempre registrata. È la sonda che diventa la mutazione. Si legge prima il record, poi
        // si interroga lo stato, e la divergenza torna osservabile.
        let primaDiChiedere = LoginItem.registeredBundleURL()

        switch LoginItem.state() {
        case .enabled:
            guard let registrato = primaDiChiedere else {
                return .warn("registrato, ma quale copia non è misurabile: sfltool non ha risposto")
            }
            let dove = registrato.standardizedFileURL
            guard FileManager.default.fileExists(atPath: dove.path) else {
                // Il guasto vero del 2026-08-14: il record puntava a una copia scompattata in
                // `/var/folders/`, cancellata da giorni. Al login macOS apriva un percorso
                // inesistente e taceva. Leggendo lo stato qui sopra il record è già tornato su
                // questa copia, quindi la riga dice che cosa ho trovato e che cosa ho rimesso.
                return .fail("puntava a una copia che non esiste più: \(senzaNome(dove.path)) — riportato su questa",
                             fix: "nessuno: è già a posto, ma tieni una sola Otium sul disco perché non ricapiti")
            }
            // Dal binario di sviluppo il confronto non ha senso (non sta dentro un `.app`), e
            // rispondere «divergono» sarebbe un falso rosso: lì si riporta solo dove puntava.
            let mio = Bundle.main.bundleURL.standardizedFileURL
            if dentroUnBundle, dove.path != mio.path {
                return .fail("al login partiva un'altra copia: \(senzaNome(dove.path)) — adesso parte questa",
                             fix: "tieni una sola Otium sul disco: cancella le copie fuori da /Applications")
            }
            return .ok("attivo: macOS avvia \(senzaNome(dove.path))")
        case .notRegistered:
            return .warn("non registrato: Otium non riparte da sola all'accensione")
        case .requiresApproval:
            return .fail("registrato ma spento in Impostazioni di Sistema",
                         fix: "Impostazioni di Sistema ▸ Generali ▸ Elementi login ed estensioni ▸ riaccendi Otium")
        case .notFound:
            guard dentroUnBundle else {
                return .warn("non misurabile da qui: stai eseguendo il binario di sviluppo, fuori da un .app")
            }
            return .fail("macOS non riconosce questo bundle come registrabile",
                         fix: "sposta Otium.app in /Applications e riaprila")
        }
    }

    /// Il vecchio LaunchAgent non deve essere sopravvissuto alla migrazione.
    ///
    /// *I plist sopravvivono ai cambi di sistema, i loro bersagli no.* Se è ancora lì, launchd
    /// lancia la copia vecchia **oltre** a quella registrata da `SMAppService`: due Otium che
    /// contano lo stesso tempo, e l'avviso «Attività app in background» che continua a tornare.
    private static func vecchioAgent() -> Verdict {
        guard LoginItem.legacyAgentInstalled() else {
            return .ok("nessun residuo del vecchio avvio automatico")
        }
        return .fail("il vecchio LaunchAgent è ancora installato: \(LoginItem.legacyPlistURL.path)",
                     fix: "apri Otium.app una volta — lo toglie da sola — oppure: launchctl bootout gui/$(id -u)/\(LoginItem.legacyLabel) && rm \(LoginItem.legacyPlistURL.path)")
    }

    private static func primoAvvio() -> Verdict {
        let s = SettingsStore.load()
        switch (s.language, s.sex) {
        case (nil, _), (_, nil):
            return .warn("non completato: l'app lo chiederà al prossimo avvio")
        case (let lingua?, let sesso?):
            let ritmo = s.rampFactor(now: Date())
            let quota = Int((ritmo * 100).rounded())
            let crescita = s.progressBeyondFull ? "crescita accesa" : "ferma al 100%"
            return .ok("\(lingua.nativeName), \(sesso.rawValue), oggi al \(quota)%, \(crescita)")
        }
    }

    /// Registrare due volte lo stesso tasto riesce, quindi questa prova dice se il tasto è
    /// **registrabile**, non se è tuo. È già l'informazione utile: se fallisce, qualcuno lo tiene
    /// in un modo che esclude gli altri.
    private static func scorciatoia() -> Verdict {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4F_54_44_43), id: 9_999)   // 'OTDC'
        let esito = RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(controlKey), id,
                                        GetApplicationEventTarget(), 0, &ref)
        if let ref { UnregisterEventHotKey(ref) }
        return esito == noErr
            ? .ok("registrabile: apre le statistiche da qualunque app")
            : .warn("il sistema l'ha rifiutata (codice \(esito)): la scorciatoia globale non è attiva")
    }
}
