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
public enum PresenceCap {
    public static let media: Double = 45 * 60
    public static let reading: Double = 15 * 60

    public static func seconds(for kind: PresenceKind) -> Double {
        switch kind {
        case .media: return media
        case .reading: return reading
        }
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

    /// - Parameters:
    ///   - frontmost: bundle identifier dell'app in primo piano.
    ///   - isPlayingAudio: quell'app sta producendo audio adesso.
    ///   - document: il documento che tiene aperto, se riconosciuto.
    ///   - appName: come chiamarla nel messaggio.
    public static func classify(
        frontmost: String?,
        isPlayingAudio: Bool,
        document: String?,
        appName: String
    ) -> PresenceSignal? {
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
        return nil
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
