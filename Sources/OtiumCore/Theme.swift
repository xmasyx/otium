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
                description: "Verde notte e salvia. La corona romana, e un colore che dice riposo invece di allarme."
            )
        case .ardesia:
            return ThemePalette(
                ink: RGB(hex: "#10161B"),
                paper: RGB(hex: "#E9EEF2"),
                accent: RGB(hex: "#93B8CE"),
                accentOnLight: RGB(hex: "#2C5A75"),
                dim: RGB(hex: "#8896A0"),
                name: "Ardesia",
                description: "Blu-grigio profondo, freddo e silenzioso. Per chi lavora di notte."
            )
        case .porpora:
            return ThemePalette(
                ink: RGB(hex: "#151019"),
                paper: RGB(hex: "#EFEAF0"),
                accent: RGB(hex: "#B99BCB"),
                accentOnLight: RGB(hex: "#5C3D70"),
                dim: RGB(hex: "#948A99"),
                name: "Porpora",
                description: "Il colore che a Roma se lo poteva permettere solo chi non doveva lavorare."
            )
        }
    }
}
