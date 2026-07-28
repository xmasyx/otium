import XCTest
@testable import OtiumCore

/// Le reti della seconda lingua.
///
/// L'inglese di Otium non è una traduzione dell'interfaccia con le frasi lasciate indietro: è la
/// stessa app in un'altra lingua, e la promessa del mese senza ripetizioni deve valere in tutte e
/// due. Questi test sono il modo in cui quella frase smette di essere un'intenzione.
///
/// Tre falsificatori distinti, perché tre sono i modi veri di rompere questa cosa:
/// 1. una citazione entra senza inglese e a schermo esce in italiano dentro l'app inglese;
/// 2. un'opera nuova non ha la traduzione del titolo e la firma esce mezza italiana;
/// 3. l'id del mazzo segue la lingua, e cambiare lingua azzera la rotazione **in silenzio**.
final class QuoteLanguageTests: XCTestCase {

    override func tearDown() {
        L.language = .italian
        super.tearDown()
    }

    // MARK: - Copertura

    /// Quante citazioni non hanno ancora l'inglese. Durante la migrazione questo test è il
    /// contatore: fallisce dicendo **quante** ne restano e **quali**, invece di lasciare che il
    /// lavoro sembri finito perché compila.
    func testEveryQuoteHasAnEnglishText() {
        let senza = Quotes.all.filter { $0.textEN.trimmingCharacters(in: .whitespaces).isEmpty }
        let esempi = senza.prefix(5).map { "\($0.author): \($0.text.prefix(40))…" }.joined(separator: "\n  ")
        XCTAssertTrue(senza.isEmpty,
                      "\(senza.count) citazioni su \(Quotes.all.count) non hanno l'inglese. Prime:\n  \(esempi)")
    }

    /// Lo stesso per il pool contemplativo.
    func testEveryMindfulPhraseHasAnEnglishText() {
        let pool = Mindful.all
        let senza = pool.filter { $0.textEN.trimmingCharacters(in: .whitespaces).isEmpty }
        let esempi = senza.prefix(5).map { String($0.text.prefix(40)) + "…" }.joined(separator: "\n  ")
        XCTAssertTrue(senza.isEmpty,
                      "\(senza.count) frasi mindful su \(pool.count) non hanno l'inglese. Prime:\n  \(esempi)")
    }

    // MARK: - I nomi

    /// Ogni segmento di titolo che non sia un numero deve avere la sua voce in `QuoteNames`.
    ///
    /// È la rete che rende sicura la tabella: aggiungere una citazione con un'opera nuova e
    /// scordarsi la traduzione fa cadere questo test, non uscire «Essays, Della speditezza».
    func testEveryWorkSegmentHasATranslation() {
        var mancanti: Set<String> = []
        for q in Quotes.all {
            for segmento in QuoteNames.translatableSegments(of: q.work)
            where !QuoteNames.hasWorkTranslation(segmento, author: q.author) {
                mancanti.insert("\(q.author) — \(segmento)")
            }
        }
        XCTAssertTrue(mancanti.isEmpty,
                      "segmenti d'opera senza traduzione:\n  \(mancanti.sorted().joined(separator: "\n  "))")
    }

    /// «Pensieri» è tre opere diverse, e una tabella a chiave nuda le fonderebbe in silenzio.
    /// Questo è il test negativo di quella scelta: se qualcuno togliesse lo scoping per autore,
    /// due di queste tre righe diventerebbero uguali e il test cadrebbe.
    func testSameItalianTitleResolvesPerAuthor() {
        XCTAssertEqual(QuoteNames.workEN("Pensieri, IV, 3", author: "Marco Aurelio"), "Meditations, IV, 3")
        XCTAssertEqual(QuoteNames.workEN("Pensieri, 139", author: "Pascal"), "Pensées, 139")
        XCTAssertEqual(QuoteNames.workEN("Pensieri, XXVIII", author: "Leopardi"), "Thoughts, XXVIII")
    }

    /// I numeri e i numeri romani non si traducono, e non devono nemmeno essere cercati.
    func testNumbersPassThroughUntouched() {
        XCTAssertEqual(QuoteNames.workEN("Lettere a Lucilio, 82", author: "Seneca"), "Letters to Lucilius, 82")
        XCTAssertEqual(QuoteNames.workEN("Bhagavad Gita, II, 47", author: "Bhagavad Gita"), "Bhagavad Gita, II, 47")
        XCTAssertTrue(QuoteNames.isNumeric("XXV"))
        XCTAssertTrue(QuoteNames.isNumeric("1758"))
        XCTAssertFalse(QuoteNames.isNumeric("Walden"))
    }

    // MARK: - Il mazzo

    /// **L'id non cambia con la lingua.**
    ///
    /// Il falsificatore è preciso: se l'id derivasse dal testo mostrato, cambiare lingua darebbe
    /// a ogni citazione un'identità nuova, il mazzo le tratterebbe come frasi mai viste e la
    /// rotazione ripartirebbe da zero — senza un errore, senza niente a schermo che lo dica.
    func testDeckIdentityIsStableAcrossLanguages() {
        L.language = .italian
        let inItaliano = Quotes.all.map(\.phrase.id)
        L.language = .english
        let inInglese = Quotes.all.map(\.phrase.id)
        XCTAssertEqual(inItaliano, inInglese,
                       "gli id del mazzo cambiano con la lingua: la rotazione si azzererebbe a ogni cambio")
    }

    /// La promessa del mese senza ripetizioni vale in inglese quanto in italiano.
    func testMonthWithoutRepeatsHoldsInEnglishToo() {
        L.language = .english
        let pool = PhraseLibrary.breakPool(includingUser: false)
        let month = (8 * 60) / 30 * 30
        XCTAssertGreaterThanOrEqual(pool.count, month,
                                    "in inglese il pool è \(pool.count), ne servono \(month)")
    }

    /// Cambiare lingua cambia davvero quello che si legge. Senza questo, tutti i test qui sopra
    /// passerebbero anche con un `L.t` che restituisce sempre l'italiano.
    func testSwitchingLanguageChangesTheRenderedText() {
        guard let campione = Quotes.all.first(where: { !$0.textEN.isEmpty && $0.textEN != $0.text }) else {
            return XCTFail("nessuna citazione con un inglese diverso dall'italiano: non c'è niente da provare")
        }
        L.language = .italian
        XCTAssertEqual(campione.localizedText, campione.text)
        L.language = .english
        XCTAssertEqual(campione.localizedText, campione.textEN)
    }
}
