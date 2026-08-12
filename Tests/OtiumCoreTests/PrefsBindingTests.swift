import XCTest

/// **La regola del 2026-08-12, resa meccanica: un interruttore si applica da solo, tutto il resto
/// passa da «Applica».**
///
/// Parole sue: *«il toggle non deve richiedere l'applica, quando metto il toggle sono sicuro che è
/// come dico io»*, e nello stesso turno il verso opposto per i menu di Zen, *«dato che non è un
/// toggle, deve darmi l'applico»*.
///
/// **Perché un test sul sorgente e non sul comportamento.** Il legame fra un comando e il suo
/// campo vive dentro `PrefsView`, che sta nel bersaglio eseguibile: nessun test può costruire quella
/// vista, e nessuna sonda a schermo distingue «l'interruttore ha scritto sul disco» da «l'ho girato
/// e poi ho premuto Applica». Quello che si può controllare, e che è esattamente ciò che si rompe,
/// è **come sono scritti i legami**: `vivo(…)` scrive subito, `$draft.…` aspetta il pulsante.
///
/// La forma è quella di `LanguageLintTests`, che legge i sorgenti da settimane per la stessa
/// ragione: una classe di difetti che nessun test di comportamento vede.
final class PrefsBindingTests: XCTestCase {

    private static func views() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // OtiumCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // radice del pacchetto
            .appendingPathComponent("Sources/OtiumApp/Views.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Nessun interruttore aspetta «Applica». `draft` esiste solo dentro `PrefsView`, quindi la
    /// regola si può scrivere senza dover ritagliare il pezzo di file giusto.
    func testNoToggleWaitsForTheApplyButton() throws {
        let sorgente = try Self.views()
        XCTAssertFalse(sorgente.contains("isOn: $draft."),
                       "un interruttore legato alla bozza è un interruttore che aspetta «Applica»")
    }

    /// Il verso opposto, che è la metà che si dimentica: niente che **non** sia un interruttore
    /// scrive sul disco a ogni passaggio. Attraversando un menu a tendina si tocca ogni voce in
    /// mezzo, e ognuna diventerebbe la cadenza di quel momento.
    func testOnlyTogglesWriteImmediately() throws {
        let sorgente = try Self.views()
        for legame in ["selection: vivo(", "value: vivo(", "text: vivo("] {
            XCTAssertFalse(sorgente.contains(legame),
                           "\(legame) — solo gli interruttori si applicano da soli")
        }
    }

    /// **Il polo positivo, senza il quale i due test qui sopra passerebbero su un file vuoto.**
    /// Gli interruttori della finestra sono sette: crescita oltre il 100%, varianti nella pausa,
    /// Zen, microfono, video e lettura, orario personalizzato, più le caselle degli esercizi, che
    /// passano da `binding(for:)`.
    func testTheTogglesAreActuallyWiredLive() throws {
        let sorgente = try Self.views()
        let vivi = sorgente.components(separatedBy: "isOn: vivo(").count - 1
        XCTAssertGreaterThanOrEqual(vivi, 5, "gli interruttori vivi sono spariti dal sorgente")
        XCTAssertTrue(sorgente.contains("private func vivo<V>"), "l'aiutante non c'è più")
    }

    /// Le caselle degli esercizi sono interruttori come gli altri, ma il legame passa da un
    /// aiutante: senza questa riga potrebbero tornare alla bozza senza che nessun controllo se ne
    /// accorga, perché nel sorgente non si legge `isOn: $draft.`.
    func testTheExerciseCheckboxesWriteThroughTheLiveHelper() throws {
        let sorgente = try Self.views()
        guard let inizio = sorgente.range(of: "private func binding(for kind: ExerciseKind)"),
              let fine = sorgente.range(of: "private func poolKeyPath") else {
            return XCTFail("gli aiutanti delle caselle non si trovano più")
        }
        let corpo = sorgente[inizio.lowerBound..<fine.lowerBound]
        XCTAssertTrue(corpo.contains("vivo(pool)"), "la casella scrive nella bozza invece che sul disco")
    }
}
