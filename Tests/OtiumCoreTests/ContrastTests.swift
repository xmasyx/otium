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

    /// **Ogni livrea in tutte e due le vesti: normale e Zen.**
    ///
    /// Aggiunto il 2026-08-08 con la modalità Zen, che sposta l'accento di ogni livrea verso il
    /// freddo. Un accento nuovo scelto a occhio passa la revisione e fallisce sotto AA — è la
    /// regola già scritta per le tre livree, e sarebbe stata una beffa aggiungere tre colori
    /// esattamente sotto al cancello costruito per fermarli. Le prove qui sotto girano su questa
    /// lista invece che su `ThemeName.allCases`, così una veste nuova entra nel cancello per
    /// costruzione e non perché qualcuno si è ricordato di aggiungerla.
    private var tutteLeVesti: [(String, ThemePalette)] {
        ThemeName.allCases.flatMap { tema in
            [(tema.rawValue, tema.palette), ("\(tema.rawValue) zen", tema.zenPalette)]
        }
    }

    /// **Ogni tema regge la soglia su ogni coppia che l'app usa davvero.**
    func testEveryThemeMeetsWcagOnTheCombinationsWeUse() {
        for (tema, p) in tutteLeVesti {
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
                    String(format: "%@ · %@: %.2f:1, sotto la soglia %.1f", tema, nome, r, soglia)
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
        for (tema, p) in tutteLeVesti {
            XCTAssertGreaterThanOrEqual(ratio(p.dim, p.ink), 4.5,
                                        "\(tema): il secondario da solo è già sotto")
            // La prova che l'opacità lo affonda: se questa passasse, la regola non servirebbe.
            XCTAssertLessThan(ratio(blend(p.dim, over: p.ink, alpha: 0.65), p.ink), 4.5,
                              "\(tema): se il 65% reggesse, questa regola sarebbe inutile")
        }
    }

    /// **Le due facce delle finestre normali reggono la soglia.**
    ///
    /// Aggiunto il 2026-07-31, quando le finestre sono passate dal grigio di sistema alla carta di
    /// Kalamos di giorno e all'inchiostro la sera. Un fondo scelto a mano toglie di mezzo la
    /// garanzia che veniva gratis con i colori di sistema: quelli il contrasto lo tengono loro, e
    /// una carta crema con sopra un testo scelto da me no. Qui si calcola, invece di guardare una
    /// resa e dire che si legge bene.
    func testBothWindowFacesMeetWcag() {
        for faccia in Surface.both {
            let coppie: [(String, RGB, RGB, Double)] = [
                ("testo principale sulla carta", faccia.text, faccia.paper, 4.5),
                ("testo principale su una scheda", faccia.text, faccia.card, 4.5),
                ("testo secondario sulla carta", faccia.dim, faccia.paper, 4.5),
                ("testo secondario su una scheda", faccia.dim, faccia.card, 4.5),
                ("testo principale sul bordo", faccia.text, faccia.edge, 4.5),
            ]
            for (nome, fg, bg, soglia) in coppie {
                let r = ratio(fg, bg)
                XCTAssertGreaterThanOrEqual(
                    r, soglia,
                    String(format: "%@ · %@: %.2f:1, sotto la soglia %.1f", faccia.name, nome, r, soglia)
                )
            }
        }
    }

    /// **Il polo che rende una prova il verde qui sopra.**
    ///
    /// Le tre misure nuove sono passate al primo colpo, e un cancello che non ha mai detto di no
    /// è indistinguibile da un cancello che non guarda. Qui si scambiano le due facce — il testo
    /// avorio della sera messo sulla carta del giorno, e l'inchiostro del giorno sull'inchiostro
    /// della sera — cioè esattamente lo sbaglio che si fa mettendo un fondo nuovo e dimenticando
    /// il testo. Devono cadere tutte e due, o la misura sopra non sta misurando niente.
    func testMixingTheTwoFacesWouldFail() {
        XCTAssertLessThan(ratio(Surface.sera.text, Surface.giorno.paper), 4.5,
                          "avorio su carta: se questo passasse, la soglia non discrimina")
        XCTAssertLessThan(ratio(Surface.giorno.text, Surface.sera.paper), 4.5,
                          "inchiostro su inchiostro: idem")
    }

    /// **L'accento della livrea si vede su tutte e due le facce.**
    ///
    /// È la coppia che il disegno nuovo poteva rompere in silenzio: la livrea resta quella scelta
    /// anche nelle finestre, quindi ogni accento finisce sia sulla carta sia sull'inchiostro. Tre
    /// livree per due facce fanno sei combinazioni, e nessuna di queste è stata guardata a occhio.
    ///
    /// Le soglie sono quelle del testo grande e degli elementi d'interfaccia (3:1): l'accento qui
    /// fa i titoli, le barre e i pulsanti, non i paragrafi.
    func testEveryLiveryAccentWorksOnBothWindowFaces() {
        for (tema, p) in tutteLeVesti {
            let giorno = ratio(p.accentOnLight, Surface.giorno.paper)
            XCTAssertGreaterThanOrEqual(
                giorno, 4.5,
                String(format: "%@ · accento sulla carta: %.2f:1", tema, giorno)
            )
            let sera = ratio(p.accent, Surface.sera.paper)
            XCTAssertGreaterThanOrEqual(
                sera, 3.0,
                String(format: "%@ · accento sull'inchiostro: %.2f:1", tema, sera)
            )
            // Il testo **sopra** un riempimento d'accento: il pulsante pieno delle finestre.
            XCTAssertGreaterThanOrEqual(ratio(Surface.giorno.paper, p.accentOnLight), 4.5,
                                        "\(tema): la carta sopra l'accento di giorno")
            XCTAssertGreaterThanOrEqual(ratio(Surface.sera.paper, p.accent), 4.5,
                                        "\(tema): l'inchiostro sopra l'accento di sera")
        }
    }

    /// **Le righe di separazione si vedono, e non gridano.**
    ///
    /// Una riga che non si vede non separa niente, e una riga troppo marcata trasforma un modulo
    /// in una tabella. Il minimo qui non è WCAG — le righe non sono testo — è la soglia sotto la
    /// quale su questo schermo la riga sparisce.
    func testRulesAreVisibleOnTheirOwnGround() {
        for faccia in Surface.both {
            let r = ratio(faccia.rule, faccia.paper)
            XCTAssertGreaterThanOrEqual(r, 1.15, "\(faccia.name): la riga sparisce nel fondo")
            XCTAssertLessThan(r, 4.5, "\(faccia.name): la riga è più forte del testo secondario")
        }
    }

    /// **Il selettore di sistema a segmenti è bandito, e questo è il guardiano.**
    ///
    /// `.pickerStyle(.segmented)` prende dal `tint` il colore della casella scelta ma decide da
    /// sé il colore del testo, e sceglie il bianco. Con la livrea di notte quel bianco finisce
    /// sulla salvia chiara: **1,9:1**, cioè un testo che non si legge. Visto dal principale il
    /// 2026-07-31 sui selettori Lingua e Sesso — *«la scritta è bianca e si vede poco»*.
    ///
    /// Non è riparabile tingendo meglio: il colore che manca è quello che il controllo non lascia
    /// toccare. La cura è `SegmentedChoice`, che disegna la casella e sa che testo metterci. Il
    /// test guarda il **codice** e non i colori, perché il difetto non sta in una coppia
    /// sbagliata: sta nell'usare un controllo che la coppia non te la fa scegliere.
    func testTheSystemSegmentedPickerIsNotUsedAnywhere() throws {
        let app = Self.packageRoot.appendingPathComponent("Sources/OtiumApp")
        let files = try FileManager.default.contentsOfDirectory(at: app, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 5, "non ho letto i sorgenti: il verde non direbbe niente")

        for file in files {
            let src = try String(contentsOf: file, encoding: .utf8)
            for (n, riga) in src.components(separatedBy: .newlines).enumerated() {
                let codice = riga.trimmingCharacters(in: .whitespaces)
                // I commenti possono nominarlo: è lì che si spiega perché è bandito.
                guard !codice.hasPrefix("//") else { continue }
                XCTAssertFalse(
                    codice.contains(".pickerStyle(.segmented)"),
                    "\(file.lastPathComponent):\(n + 1) usa il selettore di sistema, che scrive bianco sull'accento — usa SegmentedChoice")
            }
        }
    }

    private static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // OtiumCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // radice del pacchetto
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

// Qui viveva `NoUntranslatedStringsTests`, la prima guardia della lingua (audit del 2026-07-28).
// Tolta il 2026-07-29 perché `LanguageLintTests` fa la stessa cosa meglio, e **due guardie sullo
// stesso invariante sono peggio di una**: quella verde di solito è la più debole, e il suo verde
// si legge come se avesse guardato tutto.
//
// Cosa faceva peggio, per non rifarlo:
//   - leggeva `Sources/OtiumApp` per **percorso relativo**, quindi con una directory di lavoro
//     diversa non leggeva niente e passava lo stesso — un verde che voleva dire «non ho guardato»;
//   - saltava tutta la riga se conteneva `L.t(` da qualunque parte;
//   - lavorava per righe, quindi un costruttore a capo le sfuggiva;
//   - guardava solo `OtiumApp`, e il difetto che ha aperto la sessione stava in `OtiumCore`;
//   - teneva le eccezioni in una lista dentro il test, lontano dalle righe che le richiedono.
// Il sostituto risale a `#filePath`, fallisce se legge meno di 5.000 righe, tiene la pila delle
// chiamate, copre entrambi i bersagli e vuole le eccezioni scritte accanto al codice.
