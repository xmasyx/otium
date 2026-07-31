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

// MARK: - ISC-117 — mai due dello stesso tipo di fila

/// **Il mazzo era già mescolato, e la lamentela era comunque giusta.**
///
/// Sondato sul file vivo il 2026-07-31, le dodici estrazioni successive erano `q m q q t f m f q
/// q m q`: casuale davvero. Ma il caso fa grappoli, e quattro fatti consecutivi — normalissimi in
/// 480 estrazioni — uno se li vive tutti nella stessa mattina e conclude che l'app dia solo studi.
final class PhraseKindSpreadTests: XCTestCase {

    /// Le proporzioni **vere**, contate sul mazzo vivo del principale il 2026-07-31:
    /// 87 citazioni, 67 fatti, 35 mindful, 18 voce.
    private func poolFinto() -> [Phrase] {
        var out: [Phrase] = []
        for i in 0..<87 { out.append(Phrase(id: "q:\(i)", kind: .citazione, text: "cit \(i)")) }
        for i in 0..<67 { out.append(Phrase(id: "f:\(i)", kind: .fatto, text: "fatto \(i)")) }
        for i in 0..<35 { out.append(Phrase(id: "m:\(i)", kind: .mindful, text: "mind \(i)")) }
        for i in 0..<18 { out.append(Phrase(id: "t:\(i)", kind: .voce, text: "voce \(i)")) }
        return out
    }

    /// **La regola vale dove si vive, e il primo test che ho scritto asseriva di più.**
    ///
    /// Pretendeva zero ripetizioni su tutto il mazzo, con un pool inventato di 40 fatti su 56:
    /// verso il fondo restano per forza solo fatti, e nessuno scambio può inventare un tipo che
    /// non c'è più — è scritto anche nel codice, ed è la scelta giusta (meglio un tipo ripetuto
    /// che uno schermo vuoto). Qui la promessa è quella vera: **nei primi tre quarti del mazzo**,
    /// cioè oltre trecento pause, due dello stesso tipo di fila non escono. Il fondo del mazzo
    /// resta un caso limite dichiarato, non una garanzia.
    func testNeverTwoOfTheSameKindInARowWhileItMatters() {
        let pool = poolFinto()
        let quante = pool.count * 3 / 4
        for seme in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seme)
            var deck = PhraseDeck()
            var tipi: [Phrase.Kind] = []
            for _ in 0..<quante {
                guard let p = deck.draw(from: pool, using: &rng) else { break }
                tipi.append(p.kind)
            }
            for (a, b) in zip(tipi, tipi.dropFirst()) {
                XCTAssertNotEqual(a, b, "seme \(seme): due \(a) di fila")
            }
        }
    }

    /// **Il polo che rende il test una prova.** Senza la regola, con lo stesso pool e gli stessi
    /// venti semi, i grappoli ci sono eccome: è la misura di quanto il caso puro sembri non
    /// casuale, ed è la ragione per cui il principale se n'è accorto.
    func testWithoutTheRuleTheClustersAreThere() {
        let pool = poolFinto()
        var grappoli = 0
        for seme in UInt64(1)...20 {
            var rng = SeededGenerator(seed: seme)
            var ids = pool.map(\.id).shuffled(using: &rng)
            let byID = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
            ids = Array(ids.prefix(pool.count * 3 / 4))
            let tipi = ids.compactMap { byID[$0]?.kind }
            grappoli += zip(tipi, tipi.dropFirst()).filter { $0 == $1 }.count
        }
        XCTAssertGreaterThan(grappoli, 100,
                             "un mescolamento uniforme fa grappoli: se qui fossero zero, il test sopra non proverebbe niente")
    }

    /// **Lo scambio non deve costare la garanzia grossa**, che è quella per cui non rivedi la
    /// stessa frase per centinaia di pause. Portare avanti una carta non è rimescolare il mazzo.
    func testTheSwapDoesNotCauseRepeats() {
        let pool = poolFinto()
        var rng = SeededGenerator(seed: 7)
        var deck = PhraseDeck()
        var viste: [String] = []
        for _ in 0..<pool.count {
            guard let p = deck.draw(from: pool, using: &rng) else { break }
            viste.append(p.id)
        }
        XCTAssertEqual(Set(viste).count, viste.count, "nessuna frase due volte prima del rimescolo")
        XCTAssertEqual(viste.count, pool.count, "e il mazzo si svuota tutto")
    }

    /// Il caso limite onesto: se restano solo frasi dello stesso tipo, esce quella che c'è. Meglio
    /// un tipo ripetuto che una pausa senza niente a schermo.
    func testASingleKindPoolStillDraws() {
        let pool = (0..<5).map { Phrase(id: "f:\($0)", kind: .fatto, text: "solo fatti \($0)") }
        var rng = SeededGenerator(seed: 3)
        var deck = PhraseDeck()
        for _ in 0..<5 {
            XCTAssertNotNil(deck.draw(from: pool, using: &rng))
        }
    }
}
