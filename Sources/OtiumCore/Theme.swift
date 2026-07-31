import Foundation

/// Un colore, in componenti, senza dipendere da SwiftUI: il nucleo non conosce l'interfaccia.
public struct RGB: Equatable, Sendable, Codable {
    public let r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { (self.r, self.g, self.b) = (r, g, b) }

    /// Da `#RRGGBB`, perché una palette si legge meglio in esadecimale che in decimali.
    public init(hex: String) {
        var v: UInt64 = 0
        Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
        r = Double((v >> 16) & 0xFF) / 255
        g = Double((v >> 8) & 0xFF) / 255
        b = Double(v & 0xFF) / 255
    }
}

/// I colori delle **finestre normali**: preferenze, statistiche, primo avvio, fonti.
///
/// Sono un'altra cosa dalla livrea. La livrea veste la schermata di blocco, che è una stanza buia
/// per costruzione e resta scura a qualunque ora; queste sono finestre che stanno in mezzo alle
/// altre finestre del Mac, e devono seguire l'aspetto di sistema come fanno tutte.
///
/// **Prima qui non c'era niente**, cioè c'era `windowBackgroundColor`: il grigio di serie, il
/// colore del «nessuno ha deciso niente». Adesso ci sono due facce, e sono le stesse di Kalamos,
/// presa per presa: le due app sono sue e devono leggersi come sorelle, non come due prodotti
/// comprati in due negozi diversi.
///
/// - **Carta** (giorno) è la livrea di Kalamos, scelta lì contro dei mockup: una carta più gialla
///   sembrava datata, una quasi bianca smetteva di essere carta.
/// - **Inchiostro** (sera) è la proposta scura della stessa sessione, ed era stata scelta proprio
///   perché è la famiglia della schermata di blocco di Otium. Non è il **seppia**, che era una
///   terza livrea *chiara* — carta invecchiata, inchiostro bruno — sconsigliata allora e non
///   ripresa qui.
///
/// L'accento non sta in questa tabella: resta quello della livrea, e lo dà `accentOnWindow`. Una
/// carta comune e un accento personale sono esattamente la differenza fra due sorelle e due copie.
public struct SurfacePalette: Equatable, Sendable {
    /// Il fondo della finestra.
    public let paper: RGB
    /// Ogni bordo rialzato: lo stesso foglio, un tono più in là.
    public let edge: RGB
    /// Le schede dentro la finestra: un gruppo di impostazioni, un riquadro di statistiche.
    public let card: RGB
    /// Il testo principale.
    public let text: RGB
    /// Il testo secondario.
    public let dim: RGB
    /// Le righe di separazione.
    public let rule: RGB
    public let name: String
}

public enum Surface {
    /// Giorno: la carta di Kalamos.
    public static let giorno = SurfacePalette(
        paper: RGB(hex: "#FAF7F0"),
        edge: RGB(hex: "#F4F0E7"),
        card: RGB(hex: "#FFFFFF"),
        text: RGB(hex: "#1E2B3A"),
        // Il tenue di Kalamos è l'inchiostro al 62%, che su carta vale #6C757F. Qui è scritto
        // pieno invece che con l'opacità: un colore trasparente steso sopra una scheda bianca e
        // sopra la carta dà due grigi diversi, e il testo secondario non deve cambiare colore a
        // seconda di cosa ha sotto.
        dim: RGB(hex: "#5C6672"),
        rule: RGB(hex: "#D9D3C7"),
        name: "Carta"
    )

    /// Sera: Inchiostro. Fondo d'inchiostro, testo avorio, e le righe che restano visibili al buio.
    public static let sera = SurfacePalette(
        paper: RGB(hex: "#141A22"),
        edge: RGB(hex: "#10151C"),
        card: RGB(hex: "#1A222C"),
        text: RGB(hex: "#EFE7D6"),
        dim: RGB(hex: "#9AA3AE"),
        rule: RGB(hex: "#263140"),
        name: "Inchiostro"
    )

    public static let both: [SurfacePalette] = [giorno, sera]
}

public struct ThemePalette: Equatable, Sendable {
    /// Il fondo della schermata di blocco.
    public let ink: RGB
    /// Il testo principale.
    public let paper: RGB
    /// L'accento: intestazioni, progresso, pulsante di conferma.
    public let accent: RGB
    /// L'accento nelle finestre normali, che devono reggere anche su sfondo chiaro.
    public let accentOnLight: RGB
    /// Il testo secondario.
    public let dim: RGB
    public let name: String
    public let description: String
}

/// Le livree disponibili.
///
/// **Perché non l'arancione su nero.** È esattamente la livrea di Sveglia, Timer e Promemoria di
/// Apple: su un Mac quell'accostamento non dice "Otium", dice "sistema operativo". Un'app che
/// vuole un'identità non può vestirsi come una funzione di serie — e per giunta l'arancione è il
/// colore dell'allarme, mentre qui il messaggio è l'opposto: fermati, non scattare.
public enum ThemeName: String, Codable, CaseIterable, Sendable {
    /// L'alloro: la corona romana, e un verde che dice riposo invece di allarme.
    case alloro
    /// Ardesia: blu-grigio profondo, freddo e silenzioso. Per chi lavora di notte.
    case ardesia
    /// Porpora: il colore che a Roma si poteva permettere solo chi non doveva lavorare.
    case porpora

    public var palette: ThemePalette {
        switch self {
        case .alloro:
            return ThemePalette(
                ink: RGB(hex: "#0E1512"),          // verde notte, non nero
                paper: RGB(hex: "#ECEFE9"),
                accent: RGB(hex: "#8FC2A4"),       // salvia luminosa
                accentOnLight: RGB(hex: "#2F6B4F"),
                dim: RGB(hex: "#8A968F"),
                name: "Alloro",
                description: L.t("Verde notte e salvia. La corona romana, e un colore che dice riposo invece di allarme.",
                                 "Night green and sage. The Roman crown, and a colour that says rest instead of alarm.")
            )
        case .ardesia:
            return ThemePalette(
                ink: RGB(hex: "#10161B"),
                paper: RGB(hex: "#E9EEF2"),
                accent: RGB(hex: "#93B8CE"),
                accentOnLight: RGB(hex: "#2C5A75"),
                dim: RGB(hex: "#8896A0"),
                name: "Ardesia",
                description: L.t("Blu-grigio profondo, freddo e silenzioso. Per chi lavora di notte.",
                                 "Deep blue-grey, cold and quiet. For people who work at night.")
            )
        case .porpora:
            return ThemePalette(
                ink: RGB(hex: "#151019"),
                paper: RGB(hex: "#EFEAF0"),
                accent: RGB(hex: "#B99BCB"),
                accentOnLight: RGB(hex: "#5C3D70"),
                dim: RGB(hex: "#948A99"),
                name: "Porpora",
                description: L.t("Il colore che a Roma se lo poteva permettere solo chi non doveva lavorare.",
                                 "The colour that in Rome only those who did not have to work could afford.")
            )
        }
    }
}
