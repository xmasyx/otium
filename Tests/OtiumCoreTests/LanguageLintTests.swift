import XCTest
@testable import OtiumCore

/// **La rete che mancava alla seconda lingua.**
///
/// Il 2026-07-29 il principale ha finito una pausa da cinque minuti con l'app in inglese e si è
/// visto il complimento finale in italiano. Non era una traduzione dimenticata: era una **classe**
/// di stringhe che nessuna guardia guardava. I test della lingua che esistevano pretendevano
/// l'inglese sulle citazioni e sui fatti, cioè sui dati che entrano dal cancello; le stringhe
/// scritte a mano dentro le viste non le controllava niente, e si scoprivano una alla volta
/// aprendo l'app in inglese e guardando. Che è il modo più lento di scoprirle.
///
/// Questo test legge il sorgente come farebbe un revisore: cerca i costruttori che finiscono a
/// schermo (`Text`, `Button`, `Label`, `Picker`, `Stepper`, `LabeledContent`, `Link`, e gli
/// argomenti `title:`/`subtitle:`) e pretende che ogni testo là dentro passi da `L.t`.
///
/// **Il lettore non lavora per righe, lavora sull'annidamento**, e questa non è eleganza: sono due
/// falle vere, trovate dall'audit cross-vendor (Gemini 3.1 Pro) sulla prima versione, che le
/// leggeva una riga per volta.
///   1. *Amnistia di riga.* Bastava che da qualche parte nella riga comparisse `L.t(` per far
///      saltare **tutta** la riga: `Text("italiano") + Text(L.t("a", "b"))` passava intero.
///   2. *Costruttore a capo.* `Text(` su una riga e la stringa su quella dopo: la riga della
///      stringa non somiglia a un costruttore, e la stringa spariva dal controllo.
/// Nessuna delle due si vedeva nel sorgente di oggi, perché oggi le righe sono scritte in un
/// modo solo. È esattamente il tipo di guardia che regge finché nessuno cambia stile — cioè che
/// smetterà di reggere senza dirlo. Ora ogni stringa sa da quali chiamate è racchiusa, e la
/// decisione dipende da quelle, non da dove capita l'a capo.
///
/// **L'eccezione si dichiara nel sorgente, non qui.** Una riga marcata `// lingua: ok <motivo>` è
/// saltata: serve per i nomi propri («Otium»), per le sonde di sviluppo che nessun utente vede, e
/// per i nomi dei simboli. Il motivo sta accanto alla riga che lo richiede, dove lo legge chi la
/// modifica — una lista di eccezioni in fondo a un test è un posto dove le eccezioni invecchiano
/// senza che nessuno se ne accorga.
final class LanguageLintTests: XCTestCase {

    /// Le chiamate il cui contenuto arriva agli occhi di qualcuno.
    private static let costruttori: Set<String> = [
        "Text", "Label", "Button", "Section", "Toggle", "Stepper", "LabeledContent",
        "Picker", "Link", "Menu", "TextField", "navigationTitle", "accessibilityLabel", "help",
        // **Aiutanti di questo progetto**, non di SwiftUI. Il testo può arrivare a schermo
        // passando di qui invece che dentro una `Text`, e allora nel sorgente non somiglia a
        // niente: è così che «interruzione», «ripetizione» e «davanti al Mac» sono rimaste
        // italiane fino al 2026-07-29. Un aiutante che disegna testo va in questa lista.
        "tile",
    ]
    /// Gli argomenti con nome che portano testo a schermo anche fuori da quei costruttori.
    private static let etichetteVisibili: Set<String> = ["title", "subtitle", "message", "placeholder"]
    /// Le **proprietà** che portano testo a schermo: `button.toolTip = "…"` non è una chiamata,
    /// quindi la pila non lo vede. Era il suggerimento della barra dei menu, italiano fino al
    /// 2026-07-29 — l'unico posto dell'app che si legge senza aprire niente.
    private static let proprietaVisibili: Set<String> = [
        "toolTip", "title", "stringValue", "placeholderString", "label",
    ]
    /// Quello che dentro una chiamata visibile NON è testo da tradurre: simboli SF, suoni di
    /// sistema, chiavi, formati.
    private static let etichetteMute: Set<String> = [
        "systemImage", "systemName", "named", "forName", "withIdentifier", "key", "format", "value",
    ]
    /// Le chiamate che rendono una stringa già tradotta.
    ///
    /// `plural` è l'aiutante locale di `StatsView`, e ci sta **solo perché prende entrambe le
    /// lingue nella firma**. Se un giorno quella firma tornasse monolingue, l'amnistia qui
    /// diventerebbe un buco silenzioso: per questo c'è un test che guarda la firma, non la buona
    /// volontà di chi la modifica.
    private static let tradotte: Set<String> = ["L.t", "L.plural", "plural"]

    private struct Rilievo {
        let riga: Int
        let testo: String
    }

    // MARK: - Il test

    func testNoUserFacingStringEscapesTheTranslationGate() throws {
        let sources = Self.packageRoot().appendingPathComponent("Sources")
        var colpevoli: [String] = []
        var righeLette = 0

        for url in try Self.swiftFiles(in: sources) {
            let testo = try String(contentsOf: url, encoding: .utf8)
            righeLette += testo.components(separatedBy: "\n").count
            for r in Self.scan(testo) {
                colpevoli.append("\(url.lastPathComponent):\(r.riga)  \(r.testo)")
            }
        }

        // Se il lettore non legge niente, il verde non vuol dire «tutto tradotto»: vuol dire
        // «non ho guardato». Un test che passa a vuoto è il difetto che questo test esiste per
        // non avere.
        XCTAssertGreaterThan(righeLette, 5000, "il lettore non ha trovato il sorgente")

        XCTAssertTrue(colpevoli.isEmpty, """
            \(colpevoli.count) stringhe a schermo non passano da L.t. \
            Traducile con L.t("…", "…"), oppure marca la riga con `// lingua: ok <motivo>` se \
            davvero non va tradotta:
              \(colpevoli.joined(separator: "\n  "))
            """)
    }

    /// **Il test negativo del test.** Una guardia mai messa alla prova è un'asserzione travestita
    /// da verifica. I casi 4 e 5 sono le due falle che l'audit cross-vendor ha trovato nella
    /// prima versione: erano verdi, e non dovevano esserlo.
    func testTheLintActuallyCatchesWhatItClaimsTo() {
        // 1 — la riga esatta che il principale ha visto il 2026-07-29.
        XCTAssertEqual(Self.scan(#"Text("La più faticosa della giornata, fatta.")"#).count, 1,
                       "non vede una riga non tradotta")

        // 2 — la stessa, tradotta: deve passare.
        XCTAssertTrue(Self.scan(#"Text(L.t("La più faticosa", "The hardest one"))"#).isEmpty,
                      "boccia una riga tradotta bene")

        // 3 — l'esenzione dichiarata nel sorgente.
        XCTAssertTrue(Self.scan(#"Text("Otium")   // lingua: ok nome proprio"#).isEmpty,
                      "ignora l'esenzione dichiarata")

        // 4 — **amnistia di riga**: un `L.t` da una parte non assolve la stringa nuda dall'altra.
        XCTAssertEqual(Self.scan(#"Text("italiano nudo") + Text(L.t("tradotta", "translated"))"#).count, 1,
                       "un L.t altrove nella riga fa passare una stringa non tradotta")

        // 5 — **costruttore a capo**: la stringa sta su una riga che non somiglia a niente.
        let aCapo = """
        Text(
            "Questa riga da sola non sembra un costruttore"
        )
        """
        XCTAssertEqual(Self.scan(aCapo).count, 1, "non vede una stringa sotto il costruttore a capo")
        XCTAssertEqual(Self.scan(aCapo).first?.riga, 2, "riporta la riga sbagliata")

        // 6 — i nomi dei simboli e dei suoni non sono testo.
        XCTAssertTrue(Self.scan(#"Label(L.t("Fonti", "Sources"), systemImage: "book.closed")"#).isEmpty,
                      "chiede di tradurre il nome di un simbolo")

        // 7 — i commenti non finiscono a schermo, nemmeno quando contengono codice d'esempio.
        XCTAssertTrue(Self.scan(#"// esempio: Text("una riga italiana")"#).isEmpty,
                      "legge dentro un commento")
        XCTAssertTrue(Self.scan("/*\nText(\"dentro un blocco\")\n*/").isEmpty,
                      "legge dentro un commento a blocchi")

        // 8 — fuori da una chiamata visibile una stringa non riguarda nessuno.
        XCTAssertTrue(Self.scan(#"let chiave = "una stringa qualsiasi italiana""#).isEmpty,
                      "boccia una stringa che non va a schermo")

        // 9 — l'interpolazione da sola non è testo da tradurre.
        XCTAssertTrue(Self.scan(##"Text("\(reps) s")"##).isEmpty,
                      "chiede di tradurre un numero")

        // 10 — **assegnazione a una proprietà visibile**: non è una chiamata, e la pila non basta.
        XCTAssertEqual(Self.scan(#"statusItem.button?.toolTip = "Prossima pausa fra poco""#).count, 1,
                       "non vede il testo assegnato a una proprietà a schermo")

        // 11 — **assegnazione attraverso un ternario a capo**: è la forma vera del suggerimento
        //      della barra dei menu, e la correzione del rilievo sui confini d'istruzione
        //      l'aveva resa invisibile per mezz'ora.
        let ternario = """
        statusItem.button?.toolTip = model.phase == .paused
            ? "Otium sospesa"
            : "Prossima pausa fra poco"
        """
        XCTAssertEqual(Self.scan(ternario).count, 2, "non vede il testo assegnato tramite ternario a capo")

        // 12 — ma una riga nuova, dopo un'assegnazione conclusa, non eredita niente.
        let dopo = """
        button.toolTip = qualcosa
        print("una riga italiana di sonda")
        """
        XCTAssertTrue(Self.scan(dopo).isEmpty, "attribuisce a toolTip una stringa di due righe dopo")

        // 13 — **parentesi dentro una stringa annidata in un'interpolazione**: il conto dei
        //      livelli non deve chiudersi lì, o da quel punto in poi il lettore legge storto.
        // La prima riga non deve produrre rilievi da sola — è tutta interpolazione — quindi
        //      l'unico rilievo atteso è la riga dopo: se il lettore si perdesse, non la vedrebbe.
        let annidata = ##"""
        Text("\(fmt(")"))")
        Text("una riga italiana rimasta indietro")
        """##
        let rilievi = Self.scan(annidata)
        XCTAssertEqual(rilievi.count, 1, "si perde dopo una stringa annidata dentro un'interpolazione")
        XCTAssertEqual(rilievi.first?.riga, 2, "riprende la lettura sulla riga sbagliata")

        // 14 — **stringhe dentro un'interpolazione**: sono codice, e il codice va letto. Un
        //      ternario in linea nascondeva due etichette a schermo.
        //      L'involucro non ha lettere proprie, quindi i due rilievi attesi sono solo i suoi.
        let interne = Self.scan(##"Text("\(attivo ? "acceso adesso" : "spento adesso")")"##)
        XCTAssertEqual(interne.count, 2, "non legge le stringhe dentro un'interpolazione")

        // 15 — e quelle interne, se sono tradotte, restano innocenti.
        XCTAssertTrue(Self.scan(##"Text("\(attivo ? L.t("acceso", "on") : L.t("spento", "off"))")"##).isEmpty,
                      "boccia un ternario tradotto dentro un'interpolazione")

        // 16 — un confronto non è un'assegnazione.
        XCTAssertTrue(Self.scan(#"if item.title == "una voce qualsiasi italiana" { return }"#).isEmpty,
                      "scambia un confronto per un'assegnazione")
    }

    /// **L'amnistia concessa a `plural` deve restare meritata.**
    ///
    /// Il lettore lascia passare le stringhe dentro `plural(…)` perché quell'aiutante prende sia
    /// l'italiano sia l'inglese. È l'unica assunzione del lettore che vive fuori dal lettore, e
    /// senza questo test si romperebbe in silenzio: basterebbe che qualcuno semplificasse la
    /// firma per riaprire il buco senza che niente diventi rosso.
    func testThePluralHelperStillTakesBothLanguages() throws {
        let views = Self.packageRoot()
            .appendingPathComponent("Sources/OtiumApp/Views.swift")
        let testo = try String(contentsOf: views, encoding: .utf8)
        XCTAssertTrue(testo.contains("private func plural(_ n: Int, it one: String, _ many: String,"),
                      "la firma di `plural` è cambiata: l'amnistia del lettore della lingua non è più meritata")
        XCTAssertTrue(testo.contains("en oneEN: String, _ manyEN: String) -> String"),
                      "`plural` non prende più l'inglese, ma il lettore continua ad assolverlo")
    }

    // MARK: - Lo strato dei dati

    /// **Il difetto del 2026-07-29 non stava in una vista: stava in un dato.**
    ///
    /// `Praise` era un `enum` con 22 righe italiane, e il lettore qui sopra — che guarda chi
    /// racchiude una stringa — non l'avrebbe mai visto, perché lì attorno non c'è nessuna `Text`.
    /// L'audit cross-vendor l'ha detto senza girarci intorno: *«il linter non prende la classe di
    /// difetti che dichiara di risolvere»*. Aveva ragione, e questo test è la risposta.
    ///
    /// Qui la domanda è un'altra: **c'è prosa italiana dentro `OtiumCore` che nessuno ha
    /// accoppiato a un inglese?** Chi risponde è l'italiano stesso — accenti, o due parole
    /// comuni nella stessa stringa.
    ///
    /// **Quello che questo test NON può fare, e nessun erede lessicale potrà.** Non c'è analisi
    /// del flusso: un testo composto a pezzi (`let a = "Il conto "; let b = a + parola`) o
    /// costruito da una funzione che non nomina niente di italiano passa, e passerebbe anche con
    /// un parser perfetto — servirebbe un albero sintattico e la propagazione dei valori, cioè
    /// SwiftSyntax e una dipendenza in più su un'app che non ne ha nessuna. Rilievo dell'audit
    /// cross-vendor, accettato: la cura è cercare la **prosa** ovunque, che intercetta il caso
    /// realistico — la frase scritta per intero in un posto solo — e lasciare scritto qui che il
    /// caso patologico resta scoperto.
    ///
    /// **Il limite, detto qui e non scoperto fra sei mesi.** Indovinare la lingua di una stringa
    /// di due o tre parole non si può fare: «Bel lavoro.» non contiene nessuna parola che tradisca
    /// l'italiano, e nessuna euristica onesta la riconoscerà. Questo test prende la **prosa** —
    /// una frase intera, con accenti o parole di servizio — che è dove stavano le fughe vere
    /// (`Stats.insights`, `ThemePalette.description`). Per le righe corte la guardia è un'altra e
    /// sta accanto al tipo che le possiede: `testEveryPraiseLineHasARealEnglish` pretende che ogni
    /// complimento abbia un inglese diverso dall'italiano, e vale anche su «Bel lavoro.». Le due
    /// insieme coprono la classe; una sola no.
    ///
    /// **Le esenzioni sono file interi, e sono sei.** Non è pigrizia: in questi file il secondo
    /// idioma vive in un *campo gemello* (`textEN`, `claimEN`, `englishName`) o sono tabelle di
    /// traduzione, cioè l'italiano nudo è la forma giusta. Ognuno ha già il proprio test che
    /// pretende l'inglese, e sono elencati qui con il motivo perché un'esenzione senza motivo è
    /// il posto dove il prossimo difetto si nasconde.
    private static let fileBilingui: [String: String] = [
        "Quotes.swift": "ogni Quote porta textEN accanto — testEveryQuoteHasAnEnglishText",
        "Mindful.swift": "ogni Phrase porta textEN — testEveryMindfulPhraseHasAnEnglishText",
        "Facts.swift": "l'aiutante f() prende testo e fonte nelle due lingue",
        "Evidence.swift": "ogni Study porta claimEN e governsEN",
        "QuoteNames.swift": "è la tabella di traduzione italiano → inglese: le chiavi sono italiane",
        "Exercise.swift": "italianName ed englishName sono due funzioni gemelle",
        // Righe da terminale, non interfaccia: le legge chi lancia una sonda o `--doctor`.
        "main.swift": "sonde da riga di comando: stampano su stdout, non a schermo",
        "Doctor.swift": "referto da terminale (`Otium --doctor`)",
    ]

    func testNoItalianProseHidesInTheDataLayer() throws {
        // **Tutto `Sources`, non solo `OtiumCore`.** Il rilievo che ha allargato questo test è il
        // terzo dell'audit cross-vendor: una stringa messa prima in una variabile e usata dopo
        // (`let msg = "…"; Text(msg)`) sfugge al lettore delle viste, perché lì attorno non c'è
        // nessun costruttore. Cercare la prosa la ritrova comunque, ovunque stia.
        let sorgenti = Self.packageRoot().appendingPathComponent("Sources")
        var colpevoli: [String] = []
        var fileLetti = 0

        for url in try Self.swiftFiles(in: sorgenti) {
            guard Self.fileBilingui[url.lastPathComponent] == nil else { continue }
            fileLetti += 1
            let testo = try String(contentsOf: url, encoding: .utf8)
            for r in Self.scanProsa(testo) {
                colpevoli.append("\(url.lastPathComponent):\(r.riga)  \(r.testo)")
            }
        }

        XCTAssertGreaterThan(fileLetti, 5, "il lettore non ha trovato OtiumCore")
        XCTAssertTrue(colpevoli.isEmpty, """
            \(colpevoli.count) frasi italiane in OtiumCore senza un inglese accanto. \
            Passale da L.t("…", "…"), mettile in coppia, o marca la riga con \
            `// lingua: ok <motivo>`:
              \(colpevoli.joined(separator: "\n  "))
            """)
    }

    /// **Il test negativo dello strato dei dati.** Il caso 1 è `Praise` com'era davvero il
    /// 2026-07-29: se questo non fosse rosso, il test qui sopra non proverebbe niente.
    func testTheDataLayerLintCatchesThePraiseDefect() {
        // 1 — com'era: righe italiane in un elenco, senza nessun inglese accanto. Due frasi
        //     italiane che si toccano NON sono una coppia bilingue, ed è il caso che il primo
        //     tentativo di questo lettore scambiava per tale.
        let comeEra = #"    static let righe = ["Non era scontato: l'hai fatta.", "La più faticosa della giornata, fatta."]"#
        XCTAssertEqual(Self.scanProsa(comeEra).count, 2, "non vede il difetto che ha aperto la sessione")

        // 2 — com'è: coppie (it, en) affiancate.
        let comeE = #"        ("Non era scontato: l'hai fatta.", "It wasn't a given: you did it."),"#
        XCTAssertTrue(Self.scanProsa(comeE).isEmpty, "boccia una coppia scritta bene")

        // 3 — dentro L.t va bene comunque.
        XCTAssertTrue(Self.scanProsa(#"return L.t("Il conto sale solo quando lavori", "…")"#).isEmpty,
                      "boccia una stringa già tradotta")

        // 4 — un identificativo non è prosa.
        XCTAssertTrue(Self.scanProsa(#"static let label = "app.otium.mac""#).isEmpty,
                      "scambia un identificativo per una frase")

        // 5 — l'inglese non riguarda questo test.
        XCTAssertTrue(Self.scanProsa(#"let s = "The count only rises while you work""#).isEmpty,
                      "boccia una stringa inglese")

        // 6 — **un'etichetta corta messa in una variabile**: troppo breve per indovinarne la
        //     lingua, e fuori da ogni costruttore. Sfuggiva a tutte e due le guardie.
        XCTAssertEqual(Self.scanProsa(#"let etichetta = "Invia""#).count, 1,
                       "un'etichetta corta in una variabile sfugge a tutte e due le guardie")
        XCTAssertTrue(Self.scanProsa(#"let label = "Send""#).isEmpty, "boccia un'etichetta inglese")

        // 7 — **la variabile intermedia**, cioè il buco che il lettore delle viste non può
        //     vedere: la stringa nasce lontano dal costruttore che la disegnerà.
        let intermedia = """
        let messaggio = "Il conto sale solo mentre tocchi la tastiera"
        Text(messaggio)
        """
        XCTAssertEqual(Self.scanProsa(intermedia).count, 1,
                       "una stringa messa prima in una variabile sfugge a tutte e due le guardie")
    }

    /// Le parole che tradiscono l'italiano. Ne servono **due** nella stessa stringa, o un accento:
    /// con una sola, «per» dentro «Half per leg» basterebbe a far scattare la guardia.
    private static let spieItaliane: Set<String> = [
        "il", "lo", "la", "le", "gli", "un", "una", "del", "della", "dei", "delle", "che", "non",
        "per", "con", "sono", "hai", "pausa", "pause", "esercizio", "minuti", "secondi", "oggi",
        "ripetizioni", "questo", "questa", "quando", "come", "più", "puoi", "devi", "tuo", "tua",
        "sei", "era", "corpo", "giornata", "conto", "frase", "studio", "studi", "numero", "numeri",
        "tempo", "giorno", "giorni", "volta", "volte", "nel", "nella", "alla", "allo", "sul",
        "sulla", "ogni", "anche", "solo", "già", "fatto", "fatta", "bravo", "ottimo",
    ]

    /// Le etichette corte che un'interfaccia italiana usa di sicuro. Servono perché indovinare la
    /// lingua di una parola sola non si può: «Invia» non ha accenti e non contiene parole di
    /// servizio, quindi senza questo elenco `let b = "Invia"; Button(b)` sfuggirebbe a **tutte e
    /// due** le guardie. Rilievo dell'audit cross-vendor, 2026-07-29. L'elenco è per forza
    /// incompleto: copre quello che un'app di questo tipo scrive davvero, non l'italiano.
    private static let etichetteCorte: Set<String> = [
        "sì", "no", "ok", "invia", "salva", "annulla", "chiudi", "apri", "fatto", "fatta",
        "avanti", "indietro", "conferma", "elimina", "modifica", "aggiungi", "togli", "rinvia",
        "riprendi", "sospendi", "emergenza", "impostazioni", "preferenze", "statistiche", "fonti",
        "esci", "torna", "prossima", "oggi", "settimana", "mese", "minuti", "secondi", "ripetizioni",
    ]

    private static func sembraItaliano(_ testo: String) -> Bool {
        let nudo = testo.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?:…"))
            .lowercased()
        if etichetteCorte.contains(nudo) { return true }
        if testo.contains(where: { "àèéìòùÀÈÉÌÒÙ".contains($0) }) { return true }
        let parole = testo.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        return parole.filter(spieItaliane.contains).count >= 2
    }

    /// Come `scan`, ma la domanda è «questa stringa è prosa italiana senza gemello?» invece di
    /// «questa stringa finisce a schermo?».
    private static func scanProsa(_ testo: String) -> [Rilievo] {
        scan(testo, prosa: true)
    }

    /// C'è una gemella affiancata, **e non è italiana**?
    ///
    /// Il «non è italiana» non è un dettaglio: senza, `["Bel lavoro.", "Ottimo."]` — cioè `Praise`
    /// com'era — verrebbe scambiato per una coppia bilingue proprio perché le due frasi si
    /// toccano. Un elenco di frasi italiane e una coppia (it, en) hanno la stessa forma; a
    /// distinguerli è solo la lingua della seconda.
    private static func gemellaStranieraDopo(_ index: Int, in c: [Character]) -> Bool {
        var j = index
        while j < c.count, c[j] == " " || c[j] == "\n" { j += 1 }
        guard j < c.count, c[j] == "," else { return false }
        j += 1
        while j < c.count, c[j] == " " || c[j] == "\n" { j += 1 }
        guard j < c.count, c[j] == "\"" else { return false }
        return !sembraItaliano(contenutoDa(j, in: c))
    }

    private static func gemellaStranieraPrima(_ index: Int, in c: [Character]) -> Bool {
        var j = index - 1
        while j >= 0, c[j] == " " || c[j] == "\n" { j -= 1 }
        guard j >= 0, c[j] == "," else { return false }
        j -= 1
        while j >= 0, c[j] == " " || c[j] == "\n" { j -= 1 }
        guard j >= 0, c[j] == "\"" else { return false }
        // Si risale alla virgoletta d'apertura di quella stringa.
        var k = j - 1
        while k >= 0, !(c[k] == "\"" && (k == 0 || c[k - 1] != "\\")) { k -= 1 }
        guard k >= 0 else { return false }
        return !sembraItaliano(contenutoDa(k, in: c))
    }

    /// Il testo di una stringa che comincia all'indice dato, senza consumare lo scanner.
    private static func contenutoDa(_ index: Int, in c: [Character]) -> String {
        var j = index + 1
        var t = ""
        while j < c.count, c[j] != "\"" {
            if c[j] == "\\" { j += 2; continue }
            t.append(c[j])
            j += 1
        }
        return t
    }

    // MARK: - Il lettore

    /// Legge il sorgente **carattere per carattere**, tenendo la pila delle chiamate aperte: ogni
    /// stringa sa così da chi è racchiusa, indipendentemente da dove cadano gli a capo.
    ///
    /// **Un lettore solo per due domande.** Ne erano due, copiati uno dall'altro, e le correzioni
    /// dell'audit andavano applicate a mano su entrambi: due parser che devono restare uguali per
    /// disciplina sono un difetto in attesa, e il primo giro di correzioni ne ha già toccato uno
    /// solo. Cambia la domanda finale, non la lettura.
    ///   - `prosa: false` → «questa stringa finisce a schermo senza passare da `L.t`?»
    ///   - `prosa: true`  → «questa stringa è prosa italiana senza un inglese accanto?»
    private static func scan(_ testo: String, prosa: Bool = false,
                             pilaIniziale: [String] = [], primaRiga: Int = 1) -> [Rilievo] {
        let c = Array(testo)
        var out: [Rilievo] = []
        var pila: [String] = pilaIniziale
        var i = 0
        var riga = primaRiga
        let esenti = righeEsenti(testo, da: primaRiga)

        func avanza(_ n: Int = 1) {
            for _ in 0..<n where i < c.count {
                if c[i] == "\n" { riga += 1 }
                i += 1
            }
        }

        /// Legge una stringa dalla virgoletta d'apertura, saltando le fughe e le interpolazioni —
        /// dove possono esserci parentesi e altre virgolette che non chiudono niente.
        ///
        /// Sta **dentro** `scan` e non accanto: prendendo `i` per riferimento mentre `avanza` lo
        /// cattura, Swift vede due accessi sovrapposti alla stessa variabile e il test muore di
        /// segnale 6 invece di fallire. Pagato subito, la prima volta che è girato.
        // I pezzi di codice trovati dentro le interpolazioni, da rileggere a lettura finita.
        var interpolazioni: [(String, [String], Int)] = []

        func leggiStringa() -> String {
            avanza(1)   // la virgoletta d'apertura
            var testo = ""
            while i < c.count {
                if c[i] == "\\", i + 1 < c.count {
                    if c[i + 1] == "(" {
                        // Interpolazione: si salta fino alla parentesi che chiude, contando i
                        // livelli **e saltando le stringhe annidate**. Senza l'ultima parte una
                        // parentesi dentro una stringa interna chiuderebbe il conto in anticipo,
                        // e da lì in poi il lettore leggerebbe il codice come testo e il testo
                        // come codice. Rilievo dell'audit cross-vendor, 2026-07-29.
                        avanza(2)
                        let daQui = i, rigaDaQui = riga
                        var livello = 1
                        while i < c.count, livello > 0 {
                            if c[i] == "\"" {
                                avanza(1)
                                while i < c.count, c[i] != "\"" {
                                    if c[i] == "\\" { avanza(2); continue }
                                    avanza(1)
                                }
                                avanza(1)
                                continue
                            }
                            if c[i] == "(" { livello += 1 }
                            if c[i] == ")" { livello -= 1 }
                            avanza(1)
                        }
                        // **Dentro un'interpolazione c'è codice, e nel codice ci sono stringhe.**
                        // Saltarle serviva solo a non sbagliare il conto delle parentesi; poi però
                        // sparivano dal controllo, e `Text("Info: \(x ? "sì" : "no")")` nascondeva
                        // due etichette. Rilievo dell'audit cross-vendor: adesso quel pezzo si
                        // rilegge da capo, con la stessa pila di chi lo racchiude.
                        let dentro = String(c[daQui..<max(daQui, i - 1)])
                        interpolazioni.append((dentro, pila, rigaDaQui))
                        testo += "\u{FFFC}"   // segnaposto: un valore, non delle lettere
                        continue
                    }
                    avanza(2)                 // fuga qualsiasi
                    continue
                }
                if c[i] == "\"" { avanza(1); break }
                testo.append(c[i])
                avanza(1)
            }
            return testo
        }

        while i < c.count {
            // Commento di riga.
            if c[i] == "/", i + 1 < c.count, c[i + 1] == "/" {
                while i < c.count, c[i] != "\n" { avanza() }
                continue
            }
            // Commento a blocchi.
            if c[i] == "/", i + 1 < c.count, c[i + 1] == "*" {
                avanza(2)
                while i + 1 < c.count, !(c[i] == "*" && c[i + 1] == "/") { avanza() }
                avanza(2)
                continue
            }
            // Stringa.
            if c[i] == "\"" {
                let rigaInizio = riga
                let etichetta = etichettaPrimaDi(i, in: c)
                let proprietaAssegnata = proprietaPrimaDi(i, in: c)
                let gemellaPrima = gemellaStranieraPrima(i, in: c)
                let contenuto = leggiStringa()
                guard !pila.contains(where: { tradotte.contains($0) }) else { continue }
                guard !esenti.contains(rigaInizio) else { continue }

                if prosa {
                    // Una coppia affiancata — `("Bel lavoro.", "Nice work.")` — è già bilingue.
                    guard !gemellaPrima, !gemellaStranieraDopo(i, in: c) else { continue }
                    guard sembraItaliano(contenuto) else { continue }
                } else {
                    guard !etichetteMute.contains(etichetta ?? "") else { continue }
                    let visibile = pila.contains(where: { costruttori.contains($0) })
                        || etichetteVisibili.contains(etichetta ?? "")
                        || proprietaVisibili.contains(proprietaAssegnata ?? "")
                    guard visibile, haDueLettere(contenuto) else { continue }
                }
                out.append(Rilievo(riga: rigaInizio, testo: "\"\(contenuto)\""))
                continue
            }
            // Apertura di chiamata: il nome è l'identificatore che sta subito prima.
            if c[i] == "(" {
                pila.append(nomeChiamataPrimaDi(i, in: c))
                avanza()
                continue
            }
            if c[i] == ")" {
                if !pila.isEmpty { pila.removeLast() }
                avanza()
                continue
            }
            avanza()
        }
        for (codice, pilaEsterna, rigaInizio) in interpolazioni {
            out += scan(codice, prosa: prosa, pilaIniziale: pilaEsterna, primaRiga: rigaInizio)
        }
        return out.sorted { $0.riga < $1.riga }
    }

    /// L'identificatore che precede una parentesi aperta: `L.t(` → «L.t», `Text(` → «Text»,
    /// `if (` → stringa vuota.
    private static func nomeChiamataPrimaDi(_ index: Int, in c: [Character]) -> String {
        var j = index - 1
        // Spazi, tabulazioni **e a capo**: `Text\n(…)` è Swift valido, e saltando i soli spazi il
        // nome della chiamata si perdeva — cioè proprio il caso multi-riga che questo lettore
        // esiste per non sbagliare. Rilievo dell'audit cross-vendor, 2026-07-29.
        while j >= 0, c[j] == " " || c[j] == "\n" || c[j] == "\t" { j -= 1 }
        var nome = ""
        while j >= 0, c[j].isLetter || c[j].isNumber || c[j] == "_" || c[j] == "." {
            nome.insert(c[j], at: nome.startIndex)
            j -= 1
        }
        return nome
    }

    /// La proprietà a cui questa stringa viene assegnata: `button?.toolTip = "…"` → «toolTip».
    ///
    /// Un `==` non è un'assegnazione: confrontare una stringa con una costante non la porta a
    /// schermo, e scambiare le due cose riempirebbe il rapporto di rilievi falsi.
    private static func proprietaPrimaDi(_ index: Int, in c: [Character]) -> String? {
        // Si risale fino all'inizio dell'istruzione, non solo di un carattere: il suggerimento
        // della barra dei menu era assegnato **attraverso un ternario**, quindi prima della
        // stringa non c'era un `=` ma un `?`. Guardare un carattere indietro l'avrebbe mancato, e
        // il verde avrebbe voluto dire «non ho guardato lì».
        //
        // Risalire tanto è sicuro perché la decisione la prende la lista `proprietaVisibili`: un
        // `let chiave = …` risale allo stesso modo e non trova un nome che conta.
        var j = index - 1
        var uguale = -1
        while j >= 0 {
            let ch = c[j]
            if ch == "{" || ch == "}" || ch == ";" { return nil }
            // **In Swift l'a capo chiude l'istruzione**, a meno che la riga finisca appesa a un
            // operatore. Senza questo, una `print("…")` due righe sotto un `toolTip = …` veniva
            // attribuita a quel `toolTip`: falsi positivi a raffica, e per giunta convincenti.
            // Rilievo dell'audit cross-vendor, 2026-07-29.
            if ch == "\n", !istruzioneContinua(j, in: c) { return nil }
            if ch == "=" {
                if j > 0, ["=", "!", "<", ">", "+"].contains(String(c[j - 1])) { j -= 2; continue }
                if j + 1 < c.count, c[j + 1] == "=" { j -= 1; continue }
                uguale = j
                break
            }
            j -= 1
        }
        guard uguale > 0 else { return nil }
        j = uguale - 1
        while j >= 0, c[j] == " " { j -= 1 }
        var percorso = ""
        while j >= 0, c[j].isLetter || c[j].isNumber || c[j] == "_" || c[j] == "." || c[j] == "?" {
            percorso.insert(c[j], at: percorso.startIndex)
            j -= 1
        }
        let ultimo = percorso.split(separator: ".").last.map(String.init)
        return (ultimo?.isEmpty ?? true) ? nil : ultimo
    }

    /// La riga che finisce a questo a capo resta aperta su quella dopo?
    ///
    /// Si guardano **tutti e due i lati**, perché un'espressione si spezza in due modi e il
    /// secondo è quello vero di questo sorgente:
    ///
    ///     statusItem.button?.toolTip = model.phase == .paused     ← finisce con `.paused`
    ///         ? L.t("Otium sospesa", …)                           ← comincia con `?`
    ///
    /// Guardando solo la fine della riga sopra, quel suggerimento tornerebbe invisibile — cioè si
    /// riaprirebbe il buco che l'aveva fatto trovare.
    private static func istruzioneContinua(_ index: Int, in c: [Character]) -> Bool {
        var j = index - 1
        while j >= 0, c[j] == " " || c[j] == "\t" { j -= 1 }
        if j >= 0, "=?:,(+-&|.".contains(c[j]) { return true }
        var k = index + 1
        while k < c.count, c[k] == " " || c[k] == "\t" { k += 1 }
        return k < c.count && "?:,+&|.".contains(c[k])
    }

    /// L'etichetta dell'argomento a cui appartiene questa stringa: `systemImage: "x"` → «systemImage».
    private static func etichettaPrimaDi(_ index: Int, in c: [Character]) -> String? {
        var j = index - 1
        while j >= 0, c[j] == " " || c[j] == "\n" { j -= 1 }
        guard j >= 0, c[j] == ":" else { return nil }
        j -= 1
        var nome = ""
        while j >= 0, c[j].isLetter || c[j].isNumber || c[j] == "_" {
            nome.insert(c[j], at: nome.startIndex)
            j -= 1
        }
        return nome.isEmpty ? nil : nome
    }

    /// **Due** lettere di fila: sotto questa soglia è un simbolo, un'unità o un numero — «·»,
    /// «→», «s», «%» — e tradurlo non vuol dire niente.
    ///
    /// Erano tre fino al 2026-07-29, e l'audit cross-vendor ha fatto notare che tre lasciava
    /// passare «Sì», «No», «Ok»: parole corte, comunissime in un'interfaccia, e diverse nelle due
    /// lingue. Abbassata a due, il sorgente ha prodotto un solo rilievo nuovo — «vs», che si
    /// scrive uguale in italiano e in inglese, ed è esentato sul posto.
    private static func haDueLettere(_ testo: String) -> Bool {
        var consecutive = 0
        for ch in testo {
            consecutive = ch.isLetter ? consecutive + 1 : 0
            if consecutive >= 2 { return true }
        }
        return false
    }

    private static func righeEsenti(_ testo: String, da prima: Int = 1) -> Set<Int> {
        var out: Set<Int> = []
        for (n, riga) in testo.components(separatedBy: "\n").enumerated() where riga.contains("lingua: ok") {
            out.insert(n + prima)
        }
        return out
    }

    // MARK: - Attrezzi

    private static func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // OtiumCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // radice del pacchetto
    }

    private static func swiftFiles(in dir: URL) throws -> [URL] {
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }
}
