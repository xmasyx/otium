import XCTest
@testable import OtiumCore

/// Il contrasto della livrea, calcolato invece che guardato.
///
/// Audit del 2026-07-28/29. Un tema si cambia con due valori esadecimali e sembra sempre bello a
/// chi lo sceglie, di giorno, su un monitor buono. La soglia no: **WCAG AA vuole 4,5:1 per il
/// testo normale e 3:1 per quello grande**, e sotto quella riga qualcuno smette di leggere.
///
/// Qui non si guarda: si calcola. La formula è quella ufficiale — luminanza relativa con la
/// correzione gamma, e `(L+0,05)/(l+0,05)`.
final class ContrastTests: XCTestCase {

    /// Luminanza relativa secondo WCAG 2.
    private func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    private func ratio(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Il colore che si vede davvero quando ne stendi uno sopra un altro con un'opacità.
    private func blend(_ fg: RGB, over bg: RGB, alpha: Double) -> RGB {
        // Spezzato in tre righe: il compilatore non ce la fa a inferire i tipi di un'unica
        // espressione con nove operazioni, e lo dice con un errore che sembra un altro problema.
        let r: Double = fg.r * alpha + bg.r * (1 - alpha)
        let g: Double = fg.g * alpha + bg.g * (1 - alpha)
        let b: Double = fg.b * alpha + bg.b * (1 - alpha)
        return RGB(r, g, b)
    }

    /// **Ogni tema regge la soglia su ogni coppia che l'app usa davvero.**
    func testEveryThemeMeetsWcagOnTheCombinationsWeUse() {
        for tema in ThemeName.allCases {
            let p = tema.palette
            let coppie: [(String, RGB, RGB, Double)] = [
                ("testo principale sulla schermata di blocco", p.paper, p.ink, 4.5),
                ("numeri e titoli in accento", p.accent, p.ink, 3.0),
                ("testo secondario", p.dim, p.ink, 4.5),
                ("accento su finestra chiara", p.accentOnLight, RGB(hex: "#FFFFFF"), 4.5),
                ("bianco sopra l'accento scuro", RGB(hex: "#FFFFFF"), p.accentOnLight, 4.5),
                ("testo scuro sopra l'accento chiaro", p.ink, p.accent, 4.5),
            ]
            for (nome, fg, bg, soglia) in coppie {
                let r = ratio(fg, bg)
                XCTAssertGreaterThanOrEqual(
                    r, soglia,
                    String(format: "%@ · %@: %.2f:1, sotto la soglia %.1f", tema.rawValue, nome, r, soglia)
                )
            }
        }
    }

    /// **Il testo secondario non regge l'opacità, e il codice non deve provarci.**
    ///
    /// `dim` è già il colore più tenue che resta leggibile: 6,03:1 su alloro, poco sopra la
    /// soglia. Stenderlo al 55% lo porta a 2,67:1, cioè fuori. L'audit ne ha trovati cinque
    /// punti, tutti su testo da 11 punti — la dimensione che ha più bisogno di contrasto, non
    /// meno. La gerarchia si fa con corpo e peso, non con la trasparenza.
    func testDimTextCannotAffordOpacity() {
        for tema in ThemeName.allCases {
            let p = tema.palette
            XCTAssertGreaterThanOrEqual(ratio(p.dim, p.ink), 4.5,
                                        "\(tema.rawValue): il secondario da solo è già sotto")
            // La prova che l'opacità lo affonda: se questa passasse, la regola non servirebbe.
            XCTAssertLessThan(ratio(blend(p.dim, over: p.ink, alpha: 0.65), p.ink), 4.5,
                              "\(tema.rawValue): se il 65% reggesse, questa regola sarebbe inutile")
        }
    }

    /// Nessun testo nel codice usa `dim` con un'opacità sopra. È il guardiano che impedisce al
    /// difetto di tornare: la misura qui sopra dice *quanto* sarebbe sbagliato, questa dice *dove*.
    func testNoSourceFileDimsTheAlreadyDim() throws {
        let files = ["Sources/OtiumApp/Views.swift", "Sources/OtiumApp/OnboardingView.swift",
                     "Sources/OtiumApp/PaceCheckInView.swift", "Sources/OtiumApp/GrowthCheckInView.swift"]
        for f in files {
            guard let src = try? String(contentsOf: URL(fileURLWithPath: f), encoding: .utf8) else { continue }
            XCTAssertFalse(src.contains("Palette.dim.opacity("),
                           "\(f) stende un'opacità su un colore già al minimo leggibile")
        }
    }
}

/// Nessuna stringa visibile resta in una lingua sola.
///
/// Audit del 2026-07-29, asse contenuti. La traduzione di un'app non finisce quando le schermate
/// principali parlano inglese: finisce quando **nessuna** stringa che può finire sotto gli occhi
/// di qualcuno è rimasta indietro. Le sedici trovate stavano nei due pannelli di dichiarazione e
/// nelle intestazioni delle statistiche, cioè in superfici che si aprono di rado — che è
/// esattamente il posto dove una traduzione mancante sopravvive per mesi.
final class NoUntranslatedStringsTests: XCTestCase {

    /// Le due sole stringhe italiane ammesse: sono testi di **sonda**, non interfaccia. La prima
    /// è il campione della resa della notifica, la seconda la demo del pannello. Dichiarate qui
    /// per nome, così restare in italiano è una scelta e non una dimenticanza.
    private let ammesse = ["Otium è già attiva", "Pausa fra un minuto"]

    func testNoUserFacingStringIsLeftUntranslated() throws {
        let parole = try! NSRegularExpression(
            pattern: "\\b(il|la|le|lo|gli|un|una|del|della|che|non|per|con|sono|hai|puoi|questa|questo|dei|delle|come|già|anche|ogni|quando|dove|solo)\\b",
            options: .caseInsensitive)
        let mostra = try! NSRegularExpression(
            pattern: "Text\\(|title:|subtitle:|label|Button\\(|Toggle\\(|Picker\\(|Section\\(|announce")
        let letterale = try! NSRegularExpression(pattern: "\"((?:[^\"\\\\]|\\\\.){8,})\"")

        var trovate: [String] = []
        let dir = URL(fileURLWithPath: "Sources/OtiumApp")
        for file in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        where file.pathExtension == "swift" {
            guard let src = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for (n, riga) in src.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let s = String(riga)
                let trim = s.trimmingCharacters(in: .whitespaces)
                if trim.hasPrefix("//") || s.contains("L.t(") { continue }
                if s.contains("italianName") || s.contains("englishName") { continue }
                let range = NSRange(s.startIndex..., in: s)
                guard mostra.firstMatch(in: s, range: range) != nil else { continue }
                for m in letterale.matches(in: s, range: range) {
                    guard let r = Range(m.range(at: 1), in: s) else { continue }
                    let testo = String(s[r])
                    if ammesse.contains(testo) || testo.hasPrefix("--") { continue }
                    let tr = NSRange(testo.startIndex..., in: testo)
                    let haItaliano = parole.firstMatch(in: testo, range: tr) != nil
                        || testo.rangeOfCharacter(from: CharacterSet(charactersIn: "àèéìòù")) != nil
                    if haItaliano {
                        trovate.append("\(file.lastPathComponent):\(n + 1)  \(testo.prefix(60))")
                    }
                }
            }
        }
        XCTAssertTrue(trovate.isEmpty,
                      "\(trovate.count) stringhe visibili non passano da L.t:\n" + trovate.joined(separator: "\n"))
    }
}
