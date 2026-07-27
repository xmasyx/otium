import XCTest
@testable import OtiumCore

/// Il mazzo delle frasi: casuale **e** senza ripetizioni finché non sono uscite tutte.
///
/// Un generatore seminato, non `SystemRandomNumberGenerator`: un test che dipende dal caso vero
/// fallisce una volta su cento e insegna a ignorarlo.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

final class PhraseDeckTests: XCTestCase {

    private func pool(_ n: Int) -> [Phrase] {
        (0..<n).map { Phrase(id: "p\($0)", kind: .mindful, text: "frase \($0)") }
    }

    /// La proprietà che conta: dentro un giro completo non esce mai due volte la stessa.
    func testNoRepeatUntilTheDeckIsExhausted() {
        var deck = PhraseDeck()
        var rng = SeededGenerator(seed: 42)
        let all = pool(50)

        var seen: [String] = []
        for _ in 0..<50 {
            guard let drawn = deck.draw(from: all, using: &rng) else { return XCTFail("mazzo vuoto") }
            seen.append(drawn.id)
        }
        XCTAssertEqual(Set(seen).count, 50, "una frase è uscita due volte prima della fine del mazzo")
    }

    /// Finito il mazzo si rimescola e si continua, senza fermarsi né saltare.
    func testTheDeckReshufflesAndKeepsGoing() {
        var deck = PhraseDeck()
        var rng = SeededGenerator(seed: 7)
        let all = pool(10)

        var seen: [String] = []
        for _ in 0..<25 { seen.append(deck.draw(from: all, using: &rng)!.id) }
        XCTAssertEqual(seen.count, 25)
        XCTAssertEqual(Set(seen.prefix(10)).count, 10, "primo giro completo")
        XCTAssertEqual(Set(seen.dropFirst(10).prefix(10)).count, 10, "secondo giro completo")
    }

    /// L'unica ripetizione che si nota davvero è quella immediata: al cambio di mazzo la frase
    /// appena vista non deve tornare per prima.
    func testTheLastDrawnDoesNotComeBackFirstAfterReshuffle() {
        let all = pool(6)
        // Più semi, perché il caso può evitare la collisione da solo e nascondere il difetto.
        for seed in UInt64(1)...30 {
            var deck = PhraseDeck()
            var rng = SeededGenerator(seed: seed)
            var seen: [String] = []
            for _ in 0..<12 { seen.append(deck.draw(from: all, using: &rng)!.id) }
            XCTAssertNotEqual(seen[5], seen[6], "seme \(seed): stessa frase a cavallo del rimescolo")
        }
    }

    /// Il corpus cresce a ogni versione: un mazzo salvato ieri non deve rompersi domani.
    func testDeckSurvivesACorpusThatChanges() {
        var deck = PhraseDeck()
        var rng = SeededGenerator(seed: 3)
        let old = pool(10)
        for _ in 0..<4 { _ = deck.draw(from: old, using: &rng) }

        // Metà spariscono, ne arrivano di nuove.
        let updated = Array(old.prefix(5)) + (100..<110).map {
            Phrase(id: "p\($0)", kind: .mindful, text: "nuova \($0)")
        }
        var drawn: [String] = []
        for _ in 0..<15 {
            guard let phrase = deck.draw(from: updated, using: &rng) else {
                return XCTFail("il mazzo si è bloccato dopo l'aggiornamento del corpus")
            }
            drawn.append(phrase.id)
        }
        XCTAssertTrue(drawn.allSatisfy { id in updated.contains { $0.id == id } },
                      "ha restituito una frase che non esiste più")
    }

    func testEmptyPoolDoesNotCrash() {
        var deck = PhraseDeck()
        var rng = SeededGenerator(seed: 1)
        XCTAssertNil(deck.draw(from: [], using: &rng))
    }

    /// I mazzi devono sopravvivere alla chiusura, o ogni riavvio ricomincerebbe da capo e le
    /// prime frasi tornerebbero spesso — il difetto che tutto questo esiste per curare.
    func testDecksPersistAcrossRestarts() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-decks-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        var decks = PhraseDecks()
        var rng = SeededGenerator(seed: 11)
        let all = pool(20)
        var seen: Set<String> = []
        for _ in 0..<8 { seen.insert(decks.breaks.draw(from: all, using: &rng)!.id) }
        XCTAssertTrue(DeckStore.save(decks, to: url))

        var reopened = DeckStore.load(from: url)
        XCTAssertEqual(reopened.breaks.left, 12, "il mazzo riprende da dov'era")
        for _ in 0..<12 { seen.insert(reopened.breaks.draw(from: all, using: &rng)!.id) }
        XCTAssertEqual(seen.count, 20, "nessuna ripetizione a cavallo del riavvio")
    }

    /// Un file assente non è un errore: è il primo avvio.
    func testMissingDeckFileYieldsAFreshDeck() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-nope-\(UUID().uuidString).json")
        XCTAssertEqual(DeckStore.load(from: url).breaks.left, 0)
    }

    // MARK: - Il corpus

    /// Ogni frase mostrata ha una firma, anche quando la firma è «anonimo». Una riga che finisce
    /// a schermo senza niente sotto sembra un errore di impaginazione.
    func testEveryPhraseHasSomeCredit() {
        for phrase in PhraseLibrary.breakPool(includingUser: false) {
            XCTAssertFalse(phrase.text.isEmpty)
            XCTAssertFalse(phrase.credit.isEmpty, "frase senza firma né «anonimo»: \(phrase.text)")
        }
    }

    /// I fatti devono dire da dove vengono: è il patto dell'app con chi la usa.
    func testEveryFactDeclaresASource() {
        XCTAssertGreaterThanOrEqual(Facts.all.count, 40)
        for fact in Facts.all {
            XCTAssertFalse(fact.attribution.isEmpty, "fatto senza fonte: \(fact.text)")
        }
    }

    /// All'avvio si legge una riga sola: dev'essere quella che dà il tono, non un dato clinico.
    func testLaunchPoolHasNoFacts() {
        XCTAssertFalse(PhraseLibrary.launchPool(includingUser: false).contains { $0.kind == .fatto })
        XCTAssertGreaterThanOrEqual(PhraseLibrary.launchPool(includingUser: false).count, 200)
    }

    /// Le frasi aggiunte a mano entrano nel mazzo. È l'unico modo di far crescere il corpus senza
    /// aspettare una versione nuova — e senza chiamare la rete, che questa app non fa.
    func testUserPhrasesAreLoadedFromDisk() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-mie-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try? #"[{"text":"La mia frase."},{"text":"Con firma.","attribution":"Tizio · Opera"}]"#
            .data(using: .utf8)!.write(to: url)

        let mine = PhraseLibrary.userPhrases(at: url)
        XCTAssertEqual(mine.count, 2)
        XCTAssertEqual(mine[0].credit, "anonimo")
        XCTAssertEqual(mine[1].credit, "Tizio · Opera")
    }

    /// Un file scritto male non deve far sparire le frasi dell'app.
    func testBrokenUserFileIsIgnored() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("otium-rotto-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try? "{non è json".data(using: .utf8)!.write(to: url)
        XCTAssertEqual(PhraseLibrary.userPhrases(at: url).count, 0)
    }
}
