import Foundation

/// Perché sei davanti al Mac pur non toccando niente.
///
/// Senza questa distinzione l'app fa l'opposto di quello che serve: guardare un film o leggere un
/// PDF è **immobilità perfetta**, cioè esattamente il sessione intensa sedentario che Duran 2023 e Gao 2024
/// misurano — e la versione precedente lo trattava come una pausa ben fatta, accreditandola.
public enum PresenceKind: String, Codable, Equatable, Sendable {
    /// Un player sta tenendo sveglio lo schermo: video in riproduzione.
    case media
    /// In primo piano c'è un'app da lettura, con un documento aperto.
    case reading
    /// In primo piano c'è un terminale o un editor di codice: stai leggendo l'output.
    ///
    /// **È il caso più frequente della mia giornata, ed era l'unico invisibile.** Un
    /// agente che gira per minuti si guarda a mani ferme, e fino al 2026-08-05 l'app leggeva
    /// quell'immobilità come assenza: cinque pause mai fatte accreditate in una mattina, due
    /// delle quali da 14 e 18 minuti. Visto dopo due ore senza un'interruzione:
    /// *«ero al PC in realtà, quindi credo che non mi abbia visto»*.
    ///
    /// Il tetto è **il più stretto dei quattro**, e il numero è suo (2026-08-05): *«mettiamo che
    /// su iTerm 5 minuti di idle sono accettabili»*. Cinque minuti coprono la lettura di un output
    /// lungo e non coprono il caffè, che è esattamente dove passa il confine.
    case terminal
    /// Una call in corso: un microfono è in uso, o la telecamera sta riprendendo.
    ///
    /// **È il caso che mancava, e mancava proprio dove pesa di più.** Una riunione di due ore
    /// senza toccare il trackpad è la seduta più lunga della giornata, e fino al 2026-08-04
    /// l'app la leggeva come assenza: il contatore si fermava al primo minuto di silenzio e il
    /// tempo di quella riunione non è mai esistito. Visto dopo esserci stato
    /// dentro: *«Otium ha smesso di monitorare il tempo che ero davanti allo schermo»*.
    case call
}

public struct PresenceSignal: Equatable, Sendable {
    public let kind: PresenceKind
    /// Cosa è stato riconosciuto, in chiaro: "Netflix — Safari", "relazione.pdf — Anteprima".
    /// Finisce nella schermata di blocco: se l'app decide di interromperti perché crede che tu
    /// stia guardando un video, deve dirti **cosa** ha visto, così puoi darle torto.
    public let detail: String

    public init(kind: PresenceKind, detail: String) {
        self.kind = kind
        self.detail = detail
    }
}

/// Quanto a lungo un segnale di presenza vale, senza **un solo** input.
///
/// Un segnale che non scade non è un segnale: basterebbe lasciare un PDF aperto e andare a pranzo
/// per far contare il pranzo come lavoro. I due numeri sono diversi perché i due comportamenti lo
/// sono — un film senza toccare niente per 45 minuti è normale, leggere senza mai scrollare per
/// un quarto d'ora no.
/// **La call è l'unica eccezione, ed è voluta.** Un tetto sulla call riporterebbe esattamente il
/// difetto che questa versione ripara: a riunione ancora aperta il contatore si fermerebbe di
/// nuovo, e chi ci sta dentro tre ore vedrebbe contata solo la prima. Mia decisione,
/// 2026-08-04: *«non deve smettere di contare, se sono in call continuo a contare quanto tempo
/// sono stato al computer»*. Il prezzo, dichiarato: un microfono lasciato aperto mentre esci di
/// casa accumula ore che non hai passato seduto. È il motivo per cui esiste il richiamo delle 4
/// ore (`callWatchdogSeconds`), che è l'unica rete rimasta al posto del tetto.
public enum PresenceCap {
    public static let media: Double = 45 * 60
    public static let reading: Double = 15 * 60
    /// Più stretto della lettura, e non per simmetria. Un terminale resta in primo piano da solo
    /// per ore, mentre un PDF davanti implica almeno che qualcuno l'abbia aperto per leggerlo: il
    /// falso positivo «terminale acceso, scrivania vuota» è il più facile dei quattro da innescare,
    /// quindi paga il tetto più corto. Cinque minuti è un numero mio, non una stima.
    public static let terminal: Double = 5 * 60
    public static let call: Double = .infinity

    public static func seconds(for kind: PresenceKind) -> Double {
        switch kind {
        case .media: return media
        case .reading: return reading
        case .terminal: return terminal
        case .call: return call
        }
    }

    /// Il tetto come si scrive a schermo. **Non è cosmesi:** `Int(Double.infinity)` in Swift non
    /// ritorna un numero grande, fa terminare il processo — e le due sonde di `--radar` lo
    /// facevano proprio così, dividendo il tetto per 60 e convertendolo a intero.
    public static func label(for kind: PresenceKind) -> String {
        let cap = seconds(for: kind)
        guard cap.isFinite else { return L.t("senza tetto", "no cap") }
        return L.t("tetto \(Int(cap / 60))′", "cap \(Int(cap / 60))′")
    }
}

/// Le estensioni che contano come "documento da leggere", nell'ordine in cui le hai elencate.
public enum ReadingDocument {
    public static let extensions: Set<String> = [
        "pdf", "doc", "docx", "pages", "md", "markdown", "txt", "rtf", "epub", "key", "odt",
    ]

    public static func isReadable(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return !ext.isEmpty && extensions.contains(ext)
    }
}

/// Chi può tenere sveglio lo schermo e contare come "sto guardando qualcosa".
///
/// È un elenco chiuso **di proposito**. L'asserzione di sistema è un flag globale e chiunque può
/// alzarlo: durante lo sviluppo girava un `caffeinate` lanciato da Claude Code. Guardare il flag
/// e non chi lo tiene significa contare come film qualunque strumento tenga sveglio il Mac. Se un
/// player non è in elenco, il peggio che succede è tornare al comportamento di prima; se ci
/// finisse un daemon, l'app inizierebbe a bloccare lo schermo di qualcuno che non c'è.
public enum MediaPlayers {
    public static let bundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",          // Arc
        "com.apple.TV",
        "com.apple.QuickTimePlayerX",
        "com.colliderli.iina",
        "org.videolan.vlc",
        "com.netflix.Netflix",
        "tv.plex.desktop",
        "com.apple.Preview",                   // presentazioni a schermo intero
    ]
    // Fuori di proposito: Spotify e Musica. Da quando il segnale è l'**audio**, un'app di sola
    // musica in elenco significherebbe che la musica di sottofondo mentre sei in cucina conta
    // come "sei davanti allo schermo". Un browser che suona può essere una scheda di musica —
    // falso positivo accettato, e comunque limitato dal tetto dei 45 minuti.

    public static func isPlayer(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
    }
}

/// I browser. Hanno doppia natura, e per questo stanno in un elenco a parte: se suonano stai
/// guardando un video (tetto 45′), se non suonano stai leggendo una pagina (tetto 15′).
public enum Browsers {
    public static let bundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
        "company.thebrowser.Browser",
    ]

    public static func isBrowser(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
    }
}

/// La decisione: dati i fatti raccolti dal sistema, cosa stai facendo?
///
/// Sta qui, nel nucleo, e non nel livello che parla con macOS, per una ragione precisa: finché
/// la classificazione viveva insieme alla raccolta dei fatti, nessun test poteva raggiungerla, e
/// infatti il primo ordine di priorità era sbagliato — l'audio veniva provato per primo, così una
/// scheda che suonava dietro copriva il PDF che avevi davanti. Separati i due, ogni ramo si prova.
public enum PresenceClassifier {

    /// Il segnale della call, da solo. **Sta a parte perché non passa dalla cache**: le due sonde
    /// che lo alimentano — microfono e telecamera — costano microsecondi, mentre il resto della
    /// classificazione costa un `lsof` e viene riletto ogni 8 secondi. Con la call dentro quella
    /// cache, riattaccare il telefono resterebbe invisibile per otto secondi proprio nel momento
    /// in cui l'app deve decidere se coprirti lo schermo.
    ///
    /// La telecamera vince sul microfono perché è il segnale più forte: chi ha la telecamera
    /// accesa è seduto davanti allo schermo, mentre col solo microfono potrebbe camminare.
    public static func call(microphoneActive: Bool, cameraActive: Bool) -> PresenceSignal? {
        if cameraActive {
            return PresenceSignal(kind: .call,
                                  detail: L.t("videochiamata in corso", "video call in progress"))
        }
        if microphoneActive {
            return PresenceSignal(kind: .call,
                                  detail: L.t("microfono in uso", "microphone in use"))
        }
        return nil
    }

    /// - Parameters:
    ///   - frontmost: bundle identifier dell'app in primo piano.
    ///   - isPlayingAudio: quell'app sta producendo audio adesso.
    ///   - document: il documento che tiene aperto, se riconosciuto.
    ///   - appName: come chiamarla nel messaggio.
    ///   - microphoneActive: un dispositivo d'ingresso audio è in funzione.
    ///   - cameraActive: una telecamera sta riprendendo.
    public static func classify(
        frontmost: String?,
        isPlayingAudio: Bool,
        document: String?,
        appName: String,
        microphoneActive: Bool = false,
        cameraActive: Bool = false
    ) -> PresenceSignal? {
        // **La call passa per prima, e l'ordine è tutto.** Chi è in riunione su Meet ha un
        // browser in primo piano, quindi senza questo ramo la classificazione direbbe «pagina
        // web», tetto 15 minuti — e a riunione ancora aperta smetterebbe di contare. La call ha
        // il tetto infinito, quindi deve vincere su qualunque altro segnale, non perdere.
        if let inCall = call(microphoneActive: microphoneActive, cameraActive: cameraActive) {
            return inCall
        }
        if ReaderApps.isReader(frontmost) {
            return PresenceSignal(
                kind: .reading,
                detail: document.map { "\($0) — \(appName)" }
                    ?? L.t("documento aperto in \(appName)", "document open in \(appName)")
            )
        }
        if MediaPlayers.isPlayer(frontmost), isPlayingAudio {
            return PresenceSignal(kind: .media,
                                  detail: L.t("video in riproduzione — \(appName)",
                                              "video playing — \(appName)"))
        }
        // Un browser davanti che non suona: stai leggendo una pagina. Tetto stretto.
        if Browsers.isBrowser(frontmost) {
            return PresenceSignal(kind: .reading,
                                  detail: L.t("pagina web — \(appName)", "web page — \(appName)"))
        }
        // Un terminale o un editor davanti: stai leggendo quello che sta uscendo. Ultimo dei
        // rami perché è il più permissivo per identificatore — non chiede audio né documento,
        // basta l'app in primo piano — e il tetto più corto è la contropartita.
        if TerminalApps.isTerminal(frontmost) {
            return PresenceSignal(kind: .terminal,
                                  detail: L.t("terminale — \(appName)", "terminal — \(appName)"))
        }
        return nil
    }
}

/// Terminali ed editor di codice: le app in cui "fermo" significa "sto leggendo l'output".
///
/// Elenco chiuso come gli altri tre, e per la stessa ragione: qui il segnale è **solo** l'app in
/// primo piano, senza una seconda conferma tipo l'audio per i player o il documento aperto per i
/// lettori. Con un elenco aperto, qualunque app non riconosciuta diventerebbe presenza.
public enum TerminalApps {
    public static let bundleIdentifiers: Set<String> = [
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "com.mitchellh.ghostty",
        "dev.warp.Warp-Stable",
        "org.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
        // Editor di codice: leggere un diff è lo stesso gesto che leggere un output.
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92",       // Cursor
        "com.apple.dt.Xcode",
        "dev.zed.Zed",
        "com.jetbrains.intellij",
        "com.sublimetext.4",
    ]

    public static func isTerminal(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
    }
}

/// Le app in cui "fermo" significa "sto leggendo", non "me ne sono andato".
public enum ReaderApps {
    public static let bundleIdentifiers: Set<String> = [
        "com.apple.Preview",
        "com.apple.iBooksX",
        "com.adobe.Reader",
        "com.adobe.Acrobat.Pro",
        "net.sourceforge.skim-app.skim",
        "com.readdle.PDFExpert-Mac",
        "com.apple.iWork.Pages",
        "com.apple.iWork.Keynote",
        "com.microsoft.Word",
        "com.apple.TextEdit",
        "com.apple.Notes",
        "md.obsidian",
        "pro.writer.mac",                      // iA Writer
        "com.literatureandlatte.scrivener3",
        "abnerworks.Typora",
        "com.brettterpstra.marked2",
        "com.devon-technologies.think3",
    ]

    public static func isReader(_ bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return bundleIdentifiers.contains(bundleIdentifier)
    }
}
