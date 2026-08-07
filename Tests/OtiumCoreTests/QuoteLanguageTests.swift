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

    /// **Nessuna frase deborda dallo schermo, in nessuna delle due lingue.**
    ///
    /// Il limite di 145 caratteri esisteva solo dentro `verifica-citazioni.ts`, cioè fuori
    /// dall'app: proteggeva quello che entrava dal cancello e niente altro. Una frase scritta a
    /// mano nel sorgente, o un inglese più lungo del suo italiano — e l'inglese lo è spesso —
    /// non incontrava nessuna guardia fino allo schermo, dove il difetto si vede solo se quella
    /// frase capita di uscire durante una pausa. Che è il modo più lento di scoprirlo.
    func testNoPhraseOverflowsTheScreenInEitherLanguage() {
        let limite = 145
        var lunghe: [String] = []
        for q in Quotes.all {
            if q.text.count > limite { lunghe.append("IT \(q.text.count) — \(q.author): \(q.text.prefix(50))…") }
            if q.textEN.count > limite { lunghe.append("EN \(q.textEN.count) — \(q.author): \(q.textEN.prefix(50))…") }
        }
        for p in Mindful.all {
            if p.text.count > limite { lunghe.append("IT \(p.text.count) — \(p.text.prefix(50))…") }
            if p.textEN.count > limite { lunghe.append("EN \(p.textEN.count) — \(p.textEN.prefix(50))…") }
        }
        XCTAssertTrue(lunghe.isEmpty,
                      "frasi oltre \(limite) caratteri:\n  \(lunghe.joined(separator: "\n  "))")
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

    // MARK: - Il complimento di fine pausa

    /// **Il difetto vero del 2026-07-29**, quello che il principale ha visto: pausa finita con
    /// l'app in inglese, esercizi in inglese, e il complimento sotto in italiano.
    func testPraiseIsWrittenInTheLanguageInUse() {
        L.language = .english
        for indice in 0..<Praise.afterBreak.count {
            let riga = Praise.line(at: indice)
            XCTAssertEqual(riga, Praise.afterBreak[indice].en,
                           "con l'app in inglese la riga \(indice) esce «\(riga)»")
        }
        for indice in 0..<Praise.afterHardOne.count {
            let riga = Praise.line(at: indice, hard: true)
            XCTAssertEqual(riga, Praise.afterHardOne[indice].en,
                           "con l'app in inglese la riga dura \(indice) esce «\(riga)»")
        }
        L.language = .italian
        XCTAssertEqual(Praise.line(at: 0), Praise.afterBreak[0].it)
    }

    /// Nessuna coppia con l'inglese vuoto o copiato dall'italiano: un ripiego silenzioso qui
    /// riporterebbe lo stesso difetto, solo più difficile da vedere.
    func testEveryPraiseLineHasARealEnglish() {
        let rotte = Praise.allPairs.filter {
            $0.en.trimmingCharacters(in: .whitespaces).isEmpty || $0.en == $0.it
        }
        XCTAssertTrue(rotte.isEmpty,
                      "\(rotte.count) complimenti senza un inglese vero: \(rotte.map(\.it))")
    }
}

// MARK: - ISC-119 — la precisione delle fonti non deve scendere

/// **Il corpus delle citazioni è verificato, e questo test serve a tenerlo tale.**
///
/// Misurato il 2026-07-31 su richiesta del principale, che ricordava bene: 336 citazioni, 34
/// autori, **zero senza opera dichiarata** — e non per disciplina, perché due test già lo
/// impongono (opera obbligatoria, niente «attribuito a», niente URL al posto dell'opera). Il
/// 2026-07-28 e il 29 due revisioni avevano già tolto le inventate e i doppioni, con il verdetto
/// scritto accanto a ognuna.
///
/// Quello che nessun test proteggeva era il **grado** di precisione: «Lettere a Lucilio, 82» e
/// «Lettere a Lucilio» passano tutti e due, e la differenza fra i due è tutta la differenza fra
/// una citazione che si può controllare e una che va creduta.
final class QuoteSourcePrecisionTests: XCTestCase {

    /// Un riferimento **puntuale**: un numero, un romano, o il nome del capitolo dopo il titolo.
    private func èPuntuale(_ opera: String) -> Bool {
        if opera.rangeOfCharacter(from: .decimalDigits) != nil { return true }
        if opera.range(of: #"\b[IVXL]+\b"#, options: .regularExpression) != nil { return true }
        // «Saggi, Compensazione» — il saggio dentro la raccolta è localizzazione quanto un numero.
        return opera.contains(",")
    }

    /// **Un cricchetto, non un divieto.** Un libro breve citato per intero è legittimo; una deriva
    /// verso il titolo nudo no. La soglia è quella misurata oggi, arrotondata in giù: può solo
    /// salire.
    func testTheShareOfPreciseReferencesNeverDrops() {
        let totali = Quotes.all.count
        let puntuali = Quotes.all.filter { èPuntuale($0.work) }.count
        let quota = Double(puntuali) / Double(totali)
        XCTAssertGreaterThanOrEqual(quota, 0.94,
            "il 2026-07-31 erano \(puntuali)/\(totali): una citazione nuova può essere meno precisa, il corpus no")
    }

    /// I due autori su cui gli apocrifi girano di più hanno il riferimento più stretto di tutti,
    /// ed è giusto che sia un test a dirlo: sono quelli dove una frase inventata passerebbe.
    func testTheApocryphaProneAuthorsCarryChapterAndVerse() {
        for autore in ["Buddha", "Laozi", "Epitteto", "Marco Aurelio"] {
            let loro = Quotes.all.filter { $0.author == autore }
            XCTAssertFalse(loro.isEmpty, "\(autore) non è più nel corpus: aggiorna il test")
            for q in loro {
                // **Anche i numeri romani sono numeri.** La prima versione cercava solo cifre e
                // bocciava «Pensieri, IV»: sedici rossi che accusavano il corpus di un difetto
                // che era del test. I libri di Marco Aurelio e i capitoli di Epitteto si citano
                // in romano da sempre.
                let haNumero = q.work.rangeOfCharacter(from: .decimalDigits) != nil
                let haRomano = q.work.range(of: #"\b[IVXL]+\b"#, options: .regularExpression) != nil
                XCTAssertTrue(haNumero || haRomano,
                              "\(autore) senza capitolo e verso: \(q.text)")
            }
        }
    }

    // MARK: - L'italiano non è inglese ricalcato

    /// Il difetto che l'ha fatto nascere: «ma **vogli** che vadano come vanno», cioè
    /// `but wish the things which happen` tradotto parola per parola. `vogli` è un imperativo
    /// che in italiano vivo non esiste più, e a schermo si legge come una lingua straniera.
    /// Segnalato dal principale il 2026-08-04.
    ///
    /// Non è un controllo di stile generico: è l'elenco chiuso delle forme che quel modo di
    /// tradurre produce, e cresce solo quando se ne trova un'altra sul campo.
    func testNoItalianTextUsesDeadImperatives() {
        let morte = ["vogli ", "vogli.", "vogli,", "sappilo che", "fa' che tu"]
        var trovate: [String] = []
        for testo in Quotes.all.map({ $0.text }) + Mindful.all.map({ $0.text }) {
            let minuscolo = testo.lowercased()
            for forma in morte where minuscolo.contains(forma) {
                trovate.append("«\(forma.trimmingCharacters(in: .whitespaces))» in: \(testo.prefix(60))…")
            }
        }
        XCTAssertTrue(trovate.isEmpty,
                      "forme morte trovate:\n  " + trovate.joined(separator: "\n  "))
    }

    /// Epitteto VIII, la riga che ha aperto il caso: deve venire dall'edizione italiana, non
    /// dall'inglese. Il polo positivo è preciso, così se qualcuno la riscrive a mano il test lo dice.
    func testEpictetusEightComesFromThePublishedItalianEdition() {
        let epitteto = Quotes.all.first { $0.work.contains("Manuale, 8") }
        XCTAssertNotNil(epitteto)
        XCTAssertTrue(epitteto!.text.contains("la tua vita scorrerà serena"),
                      "atteso il finale dell'edizione pubblicata, trovato: \(epitteto!.text)")
        XCTAssertFalse(epitteto!.text.contains("vogli"))
    }

}
