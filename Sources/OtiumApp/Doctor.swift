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

        func intestazione(_ etichetta: String, _ valore: String) {
            lines.append("\(etichetta.padding(toLength: max(etichetta.count, 10), withPad: " ", startingAt: 0)) \(valore)")
        }

        // ── Quale copia sta parlando, e quale girerà al prossimo avvio
        let versione = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let eseguibile = Bundle.main.executablePath ?? CommandLine.arguments.first ?? "?"
        intestazione(L.t("versione", "version"), versione)
        intestazione(L.t("sistema", "system"), "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        intestazione(L.t("binario", "binary"), Self.senzaNome(eseguibile))
        intestazione(L.t("dati", "data"), Self.senzaNome(Paths.supportDirectory.path))
        lines.append("")

        // ── La cartella dei dati: senza scrittura qui, l'app conta e non registra
        riga(L.t("cartella dei dati", "data folder"), cartellaScrivibile())

        // ── I cinque file di stato, uno per uno. Il caso che conta davvero è il file
        // ESISTENTE ma non scrivibile: da lì nasceva la perdita del registro.
        for (nome, url, obbligatorio) in [
            (L.t("registro", "ledger"), Paths.ledgerFile, true),
            (L.t("impostazioni", "settings"), Paths.settingsFile, true),
            (L.t("rotazione", "rotation"), Paths.rotationFile, false),
            (L.t("mazzi delle frasi", "phrase decks"), Paths.decksFile, false),
            (L.t("progressione", "progression"), Paths.progressFile, false),
        ] {
            riga(nome, statoFile(url, obbligatorio: obbligatorio))
        }

        // ── Righe illeggibili: il registro sopravvive, ma i numeri sarebbero più bassi del vero
        riga(L.t("integrità del registro", "ledger integrity"), integritaRegistro())

        // ── Due istanze contano lo stesso tempo due volte
        riga(L.t("istanza unica", "single instance"), istanzaUnica())

        // ── L'avvio automatico, il controllo per cui questo comando esiste
        riga(L.t("avvio automatico", "automatic startup"), avvioAutomatico())

        // ── Il residuo della vecchia via, che ne farebbe partire due
        riga(L.t("vecchio LaunchAgent", "old LaunchAgent"), vecchioAgent())

        // ── Le due risposte del primo avvio
        riga(L.t("primo avvio", "first launch"), primoAvvio())

        // ── La scorciatoia globale
        riga(L.t("scorciatoia ⌃S", "⌃S shortcut"), scorciatoia())

        if !fixes.isEmpty {
            lines.append("")
            lines.append(L.t("Da fare:", "To do:"))
            for f in fixes { lines.append("  · \(f)") }
        }
        lines.append("")
        lines.append(failures == 0
                     ? L.t("Tutto a posto.", "Everything is fine.")
                     : L.plural(failures,
                                it: "controllo da sistemare.", "controlli da sistemare.",
                                en: "check to fix.", "checks to fix."))
        return (lines.joined(separator: "\n"), failures)
    }

    /// **La lingua la sceglie chi chiama, non questo metodo.**
    ///
    /// La risoluzione vive in `impostaLinguaDaTerminale()`, accanto agli altri comandi da riga di
    /// comando: è la stessa regola dell'app — impostazioni, altrimenti la lingua del Mac — e
    /// tenerla in un posto solo evita che due percorsi rispondano in due lingue diverse. Scritta
    /// qui dentro, per giunta, ignorerebbe `--inglese`, che è il modo di guardare l'altra lingua
    /// senza toccare le impostazioni vere.
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
            return .fail(L.t("non esiste e non si è potuta creare",
                             "does not exist and could not be created"),
                         fix: L.t("controlla i permessi di ~/Library/Application Support",
                                  "check the permissions of ~/Library/Application Support"))
        }
        guard FileManager.default.isWritableFile(atPath: dir.path) else {
            return .fail(L.t("esiste ma non è scrivibile", "exists but is not writable"),
                         fix: "chmod u+w \"\(dir.path)\"")
        }
        return .ok(L.t("scrivibile", "writable"))
    }

    /// **Esistente e non scrivibile è il caso peggiore**, e non si vede da fuori: l'app continua a
    /// contare e crede di registrare. È il difetto trovato dall'audit del 2026-07-28.
    private static func statoFile(_ url: URL, obbligatorio: Bool) -> Verdict {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else {
            return obbligatorio
                ? .warn(L.t("non c'è ancora (si crea al primo uso)",
                            "not there yet (created on first use)"))
                : .ok(L.t("non c'è ancora", "not there yet"))
        }
        let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
        guard fm.isReadableFile(atPath: url.path) else {
            return .fail(L.t("non leggibile", "not readable"),
                         fix: "chmod u+r \"\(url.path)\"")
        }
        guard fm.isWritableFile(atPath: url.path) else {
            return .fail(L.t("NON SCRIVIBILE: l'app conta e non registra",
                             "NOT WRITABLE: the app counts but does not record"),
                         fix: "chmod u+w \"\(url.path)\"")
        }
        let dimensione = L.plural(size, it: "byte", "byte", en: "byte", "bytes")
        return .ok(L.t("\(dimensione), leggibile e scrivibile",
                       "\(dimensione), readable and writable"))
    }

    private static func integritaRegistro() -> Verdict {
        let ledger = Ledger(url: Paths.ledgerFile)
        let righe = ledger.entries()
        let rotte = ledger.unreadableLines
        if rotte == 0 {
            let conteggio = L.plural(righe.count, it: "riga", "righe", en: "line", "lines")
            return .ok(L.t("\(conteggio), nessuna illeggibile",
                           "\(conteggio), none unreadable"))
        }
        let buone = L.plural(righe.count,
                             it: "riga buona", "righe buone",
                             en: "good line", "good lines")
        let illeggibili = L.plural(rotte,
                                   it: "riga illeggibile", "righe illeggibili",
                                   en: "unreadable line", "unreadable lines")
        return .warn(L.t("\(buone), \(illeggibili) — le statistiche le escludono",
                         "\(buone), \(illeggibili) — statistics exclude them"))
    }

    private static func istanzaUnica() -> Verdict {
        let altre = NSRunningApplication
            .runningApplications(withBundleIdentifier: SingleInstance.bundleIdentifier)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        switch altre.count {
        case 0: return .ok(L.t("nessun'altra copia in esecuzione", "no other copy is running"))
        case 1: return .ok(L.t("una copia viva, com'è giusto", "one live copy, as expected"))
        default: return .fail(L.t("\(altre.count) copie vive: contano lo stesso tempo più volte",
                                  "\(altre.count) live copies: they count the same time more than once"),
                              fix: L.t("pkill -f 'Otium.app/Contents/MacOS/Otium' e riapri l'app",
                                       "pkill -f 'Otium.app/Contents/MacOS/Otium' and reopen the app"))
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
                return .warn(L.t("registrato, ma quale copia non è misurabile: sfltool non ha risposto",
                                 "registered, but its copy cannot be determined: sfltool did not respond"))
            }
            let dove = registrato.standardizedFileURL
            guard FileManager.default.fileExists(atPath: dove.path) else {
                // Il guasto vero del 2026-08-14: il record puntava a una copia scompattata in
                // `/var/folders/`, cancellata da giorni. Al login macOS apriva un percorso
                // inesistente e taceva. Leggendo lo stato qui sopra il record è già tornato su
                // questa copia, quindi la riga dice che cosa ho trovato e che cosa ho rimesso.
                return .fail(L.t("puntava a una copia che non esiste più: \(senzaNome(dove.path)) — riportato su questa",
                                 "pointed to a copy that no longer exists: \(senzaNome(dove.path)) — reset to this one"),
                             fix: L.t("nessuno: è già a posto, ma tieni una sola Otium sul disco perché non ricapiti",
                                      "none: it is already fixed, but keep only one Otium on disk to prevent it happening again"))
            }
            // Dal binario di sviluppo il confronto non ha senso (non sta dentro un `.app`), e
            // rispondere «divergono» sarebbe un falso rosso: lì si riporta solo dove puntava.
            let mio = Bundle.main.bundleURL.standardizedFileURL
            if dentroUnBundle, dove.path != mio.path {
                return .fail(L.t("al login partiva un'altra copia: \(senzaNome(dove.path)) — adesso parte questa",
                                 "another copy launched at login: \(senzaNome(dove.path)) — now this one launches"),
                             fix: L.t("tieni una sola Otium sul disco: cancella le copie fuori da /Applications",
                                      "keep only one Otium on disk: delete copies outside /Applications"))
            }
            return .ok(L.t("attivo: macOS avvia \(senzaNome(dove.path))",
                           "active: macOS launches \(senzaNome(dove.path))"))
        case .notRegistered:
            return .warn(L.t("non registrato: Otium non riparte da sola all'accensione",
                             "not registered: Otium does not restart automatically at login"))
        case .requiresApproval:
            return .fail(L.t("registrato ma spento in Impostazioni di Sistema",
                             "registered but disabled in System Settings"),
                         fix: L.t("Impostazioni di Sistema ▸ Generali ▸ Elementi login ed estensioni ▸ riaccendi Otium",
                                  "System Settings ▸ General ▸ Login Items & Extensions ▸ turn Otium back on"))
        case .notFound:
            guard dentroUnBundle else {
                return .warn(L.t("non misurabile da qui: stai eseguendo il binario di sviluppo, fuori da un .app",
                                 "cannot be measured from here: you are running the development binary, outside an .app"))
            }
            return .fail(L.t("macOS non riconosce questo bundle come registrabile",
                             "macOS does not recognize this bundle as registerable"),
                         fix: L.t("sposta Otium.app in /Applications e riaprila",
                                  "move Otium.app to /Applications and reopen it"))
        }
    }

    /// Il vecchio LaunchAgent non deve essere sopravvissuto alla migrazione.
    ///
    /// *I plist sopravvivono ai cambi di sistema, i loro bersagli no.* Se è ancora lì, launchd
    /// lancia la copia vecchia **oltre** a quella registrata da `SMAppService`: due Otium che
    /// contano lo stesso tempo, e l'avviso «Attività app in background» che continua a tornare.
    private static func vecchioAgent() -> Verdict {
        guard LoginItem.legacyAgentInstalled() else {
            return .ok(L.t("nessun residuo del vecchio avvio automatico",
                           "no remnants of the old automatic startup"))
        }
        return .fail(L.t("il vecchio LaunchAgent è ancora installato: \(LoginItem.legacyPlistURL.path)",
                         "the old LaunchAgent is still installed: \(LoginItem.legacyPlistURL.path)"),
                     fix: L.t("apri Otium.app una volta — lo toglie da sola — oppure: launchctl bootout gui/$(id -u)/\(LoginItem.legacyLabel) && rm \(LoginItem.legacyPlistURL.path)",
                              "open Otium.app once — it removes it automatically — or run: launchctl bootout gui/$(id -u)/\(LoginItem.legacyLabel) && rm \(LoginItem.legacyPlistURL.path)"))
    }

    private static func primoAvvio() -> Verdict {
        let s = SettingsStore.load()
        switch (s.language, s.sex) {
        case (nil, _), (_, nil):
            return .warn(L.t("non completato: l'app lo chiederà al prossimo avvio",
                             "not completed: the app will ask at the next launch"))
        case (let lingua?, let sesso?):
            let ritmo = s.rampFactor(now: Date())
            let quota = Int((ritmo * 100).rounded())
            let crescita = s.progressBeyondFull
                ? L.t("crescita accesa", "growth on")
                : L.t("ferma al 100%", "stopped at 100%")
            return .ok(L.t("\(lingua.nativeName), \(sesso.rawValue), oggi al \(quota)%, \(crescita)",
                           "\(lingua.nativeName), \(sesso.rawValue), today at \(quota)%, \(crescita)"))
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
            ? .ok(L.t("registrabile: apre le statistiche da qualunque app",
                      "registerable: opens statistics from any app"))
            : .warn(L.t("il sistema l'ha rifiutata (codice \(esito)): la scorciatoia globale non è attiva",
                        "the system rejected it (code \(esito)): the global shortcut is not active"))
    }
}
