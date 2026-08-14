import Foundation
import CoreText
#if canImport(AppKit)
import AppKit
#endif

/// Dove va a capo una frase quando è lei la pagina.
///
/// **Il difetto che ha aperto questo file** (segnalato dal principale il 2026-08-07, schermata di
/// pausa): la frase zen andava a capo dopo «Dopo», che è la **prima parola del secondo periodo**.
/// Il taglio cadeva nel punto di massima coesione del testo — fra un soggetto e il suo verbo —
/// mentre un centimetro prima c'era il punto fermo, cioè il punto di minima. Non è un difetto del
/// testo né della larghezza: `Text` riempie la riga e basta, e riempire non è impaginare.
///
/// **La regola, in tre righe meccaniche:**
///
/// 1. una riga non finisce con una parola che **apre** un periodo nuovo, e non comincia con la
///    parola che ne **chiude** uno;
/// 2. l'ultima riga non porta una parola sola;
/// 3. le righe restano bilanciate, e il taglio preferisce i confini forti — punto fermo, poi
///    virgola, due punti, punto e virgola.
///
/// **Il vincolo che rende tutto questo sicuro: il numero di righe non cambia mai.** L'avido decide
/// quante righe servono, e qui si sceglie soltanto *dove* metterle. Una riga in più cambierebbe
/// l'altezza del blocco, e l'altezza di questa pagina è già misurata e vincolata (`--misura`).
/// Quindi l'impaginazione è, per costruzione, neutra sull'altezza.
///
/// **Perché i tagli si scrivono nel testo invece di lasciarli calcolare a SwiftUI.** Un `Text` non
/// espone i propri tagli e non accetta suggerimenti: l'unico modo di deciderli è consegnargli le
/// righe già fatte. Vale finché la colonna renderizzata è larga **almeno** quanto quella su cui i
/// tagli sono stati calcolati, ed è vero per costruzione — le tre superfici hanno larghezze fisse
/// (1000, 620, 470) e lo schermo Mac più stretto in circolazione ne lascia 1184.
public enum QuoteWrap {

    // MARK: - Le tre colonne

    /// Una superficie che mostra una frase: quanto è larga la colonna e con che corpo.
    ///
    /// **Stanno qui, in `OtiumCore`, e non nelle viste che le usano**, perché il test deve
    /// giudicare le stesse tre colonne che si vedono. Ricopiate nel test, il giorno che una
    /// larghezza cambia il test continuerebbe a promuovere l'impaginazione di ieri — è
    /// l'incidente del 2026-08-05, la sonda che riscrive la logica che deve misurare.
    public struct Colonna: Sendable {
        public let nome: String
        public let larghezza: CGFloat
        public let corpoBase: CGFloat
        /// Il corpo ridotto e la lunghezza oltre la quale scatta. `nil` dove il corpo è fisso.
        public let corpoRidotto: (corpo: CGFloat, oltre: Int)?

        public func corpo(_ testo: String) -> CGFloat {
            guard let r = corpoRidotto, testo.count > r.oltre else { return corpoBase }
            return r.corpo
        }
    }

    /// La fase di riposo: la frase è la pagina, 1000 punti di colonna.
    public static let riposo = Colonna(nome: "riposo", larghezza: 1000, corpoBase: 40,   // lingua: ok nome di sonda, non va a schermo
                                       corpoRidotto: (corpo: 30, oltre: 95))
    /// La frase durante l'esercizio, in sordina sotto il conteggio.
    public static let esercizio = Colonna(nome: "esercizio", larghezza: 620, corpoBase: 18,   // lingua: ok nome di sonda, non va a schermo
                                          corpoRidotto: nil)
    /// La geometria del pannello della frase d'avvio, **in un posto solo**.
    ///
    /// **Perché sta qui e non nella vista** (2026-08-14, segnalato dal principale con una
    /// fotografia). La colonna era scritta come `470 - 36 - 4 - 14` qui, e la scatola era
    /// costruita a mano nella vista con gli stessi numeri: due copie della stessa aritmetica, e
    /// la copia nella vista aveva **uno spazio in più**. L'`HStack` conteneva barretta, testo e
    /// uno `Spacer`, cioè **tre** elementi e quindi **due** intervalli da 14, mentre il conto qui
    /// ne sottraeva uno solo. La colonna dichiarata era 416, quella disegnata 402.
    ///
    /// **Come si presentava, ed è il motivo per cui nessun controllo lo prendeva.** Le righe
    /// erano giuste per 416 e `Text` le riceveva già tagliate, quindi `--tagli` diceva zero
    /// difetti; poi a schermo la riga da 405,9 punti non ci stava in 402 e SwiftUI la spezzava di
    /// nuovo. Il risultato erano **tre** righe visibili dove ne erano state calcolate due, con il
    /// taglio nel punto peggiore, che è esattamente il difetto che `QuoteWrap` esiste per
    /// togliere. La sonda misurava la cosa giusta con il righello sbagliato.
    ///
    /// Adesso i quattro numeri stanno qui e la vista li legge: non può più esistere una seconda
    /// aritmetica che diverge in silenzio. Lo `Spacer` è stato tolto, e la sua funzione (tenere
    /// il testo a sinistra) la fa un `frame(maxWidth:alignment:)`, che non aggiunge intervalli.
    public enum Pannello {
        public static let scatola: CGFloat = 470
        public static let respiro: CGFloat = 18
        public static let barra: CGFloat = 4
        public static let stacco: CGFloat = 14
        /// Quel che resta per il testo, ed è **la stessa sottrazione** che disegna la scatola.
        public static let colonna: CGFloat = scatola - respiro * 2 - barra - stacco
    }

    /// Il pannello della frase d'avvio. La larghezza viene da `Pannello`, mai riscritta a mano.
    public static let pannello = Colonna(nome: "pannello", larghezza: Pannello.colonna,
                                         corpoBase: 15, corpoRidotto: nil)

    public static let colonne: [Colonna] = [riposo, esercizio, pannello]

    // MARK: - Il carattere

    /// Lo stesso carattere che disegna la frase a schermo.
    ///
    /// Misurare con un carattere diverso da quello che si vede è il modo classico di produrre una
    /// sonda che risponde a una domanda più debole di quella che le è stata fatta: i tagli
    /// sarebbero giusti per un testo che non esiste.
    public static func serif(_ size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size)
        guard let descriptor = base.fontDescriptor.withDesign(.serif),
              let font = NSFont(descriptor: descriptor, size: size)
        else { return base }
        return font
    }

    // MARK: - L'ingresso

    /// Le righe scelte, in ordine.
    public static func lines(_ text: String, width: CGFloat, font: NSFont) -> [String] {
        let words = Self.words(text)
        guard words.count > 1 else { return words.isEmpty ? [] : [text] }
        let m = Measurer(words: words, font: font)
        let greedy = greedyBreaks(words: words, width: width, m: m)
        guard greedy.count > 1 else { return [words.joined(separator: " ")] }
        let chosen = balancedBreaks(words: words, width: width, lineCount: greedy.count, m: m) ?? greedy
        return chosen.map { words[$0].joined(separator: " ") }
    }

    /// Quanto misura davvero una riga, con il carattere che la disegna.
    ///
    /// Diagnostica, non decide niente: serve a `--tagli --verboso` per far vedere **quanto vicina
    /// al bordo** sta ogni riga. Una riga che riempie la colonna al 99,9% supera ogni controllo e
    /// poi a schermo va a capo lo stesso, perché chi disegna non è chi ha misurato.
    public static func larghezzaRiga(_ riga: String, font: NSFont) -> CGFloat {
        let attr = NSAttributedString(string: riga, attributes: [.font: font])
        return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attr), nil, nil, nil))
    }

    /// La frase con i tagli dentro, pronta da dare a `Text`.
    ///
    /// Idempotente: un testo già impaginato torna identico, perché i separatori vengono rimossi
    /// prima di ricominciare. Serve, perché la stessa frase passa di qui a ogni ridisegno.
    public static func wrapped(_ text: String, width: CGFloat, size: CGFloat) -> String {
        lines(text, width: width, font: serif(size)).joined(separator: "\n")
    }

    /// I tagli che farebbe `Text` da solo: è il **prima** della fotografia, e il polo negativo dei
    /// test.
    public static func naturalLines(_ text: String, width: CGFloat, font: NSFont) -> [String] {
        let words = Self.words(text)
        guard !words.isEmpty else { return [] }
        let m = Measurer(words: words, font: font)
        return greedyBreaks(words: words, width: width, m: m).map { words[$0].joined(separator: " ") }
    }

    // MARK: - I difetti, nominati uno per uno

    public enum Difetto: String, Sendable {
        /// La riga finisce con la prima parola di un periodo nuovo — il caso «Dopo».
        case apertura = "riga che finisce aprendo un periodo"   // lingua: ok referto di sonda, non va a schermo
        /// La riga comincia con l'ultima parola del periodo precedente.
        case coda = "riga che comincia con la coda del periodo"   // lingua: ok referto di sonda, non va a schermo
        /// L'ultima riga porta una parola sola.
        case vedova = "ultima riga di una parola sola"
    }

    /// Cosa c'è che non va in una impaginazione data. Vuoto vuol dire che va bene.
    ///
    /// Sta qui e non nei test perché **il test e la vista devono giudicare la stessa cosa**: se il
    /// giudizio fosse ricopiato nel test, il giorno che cambia la regola i due divergerebbero in
    /// silenzio, che è esattamente l'incidente del 2026-08-05 sugli elenchi del compendio.
    public static func difetti(_ righe: [String]) -> [Difetto] {
        guard righe.count > 1 else { return [] }
        var out: [Difetto] = []
        let parole = righe.map { Self.words($0) }
        for (i, riga) in parole.enumerated() {
            guard let prima = riga.first, let ultima = riga.last else { continue }
            let ultimaRiga = (i == parole.count - 1)

            // **Apertura.** La riga finisce con la prima parola di un periodo nuovo: il punto
            // fermo è rimasto una parola indietro, dentro la riga. È il caso «Dopo».
            if !ultimaRiga {
                let precedente = riga.count >= 2 ? riga[riga.count - 2] : parole[i - 1].last
                if let precedente, chiudePeriodo(precedente), apreP(ultima) { out.append(.apertura) }
            }

            // **Coda.** La riga comincia con la parola che chiude il periodo precedente: il punto
            // fermo è scivolato una parola avanti, oltre l'a-capo. È lo specchio dell'apertura.
            if i > 0, riga.count > 1, chiudePeriodo(prima),
               let precedente = parole[i - 1].last, !chiudePeriodo(precedente) {
                out.append(.coda)
            }

            if ultimaRiga, riga.count == 1 { out.append(.vedova) }
        }
        return out
    }

    // MARK: - Le parole

    /// Le parole, senza gli a-capo già inseriti. È qui che l'idempotenza è garantita.
    static func words(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\u{2028}" || $0 == "\t" })
            .map(String.init)
    }

    /// La parola chiude un periodo: punto, esclamativo, interrogativo o puntini, anche seguiti da
    /// una chiusura di caporali, virgolette o parentesi.
    static func chiudePeriodo(_ word: String) -> Bool {
        var s = Substring(word)
        while let last = s.last, "»\"')]”’".contains(last) { s = s.dropLast() }
        guard let last = s.last else { return false }
        return ".!?…".contains(last)
    }

    /// La parola apre un periodo: comincia con una maiuscola o con i caporali.
    ///
    /// La maiuscola serve a non prendere per punto fermo le abbreviazioni («ecc.», «es.»), che in
    /// italiano sono seguite da minuscola. Senza questo controllo il taglio scapperebbe dove non
    /// c'è nessun periodo nuovo.
    static func apreP(_ word: String) -> Bool {
        var s = Substring(word)
        while let first = s.first, "«\"'([“‘".contains(first) { s = s.dropFirst() }
        guard let first = s.first else { return false }
        return first.isUppercase
    }

    /// La parola chiude una proposizione: virgola, due punti, punto e virgola, lineetta.
    static func chiudeInciso(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return ",;:—–".contains(last)
    }

    /// Parola breve di servizio: preposizione, articolo, congiunzione. In italiano una riga non ci
    /// finisce sopra.
    static func brevissima(_ word: String) -> Bool {
        let nuda = word.filter { $0.isLetter }
        return nuda.count > 0 && nuda.count <= 2 && nuda.count == word.count
    }

    // MARK: - La misura

    /// Le larghezze, misurate una volta sola per intervallo di parole.
    ///
    /// La somma delle larghezze delle singole parole **non** è la larghezza della riga: crenatura e
    /// legature esistono, e su una riga di trenta parole l'errore è visibile. Quindi si misura
    /// l'intervallo intero, e lo si ricorda.
    final class Measurer {
        private let words: [String]
        private let font: NSFont
        private var cache: [Int: CGFloat] = [:]

        init(words: [String], font: NSFont) {
            self.words = words
            self.font = font
        }

        func width(_ from: Int, _ to: Int) -> CGFloat {
            let key = from * 1000 + to
            if let hit = cache[key] { return hit }
            let s = words[from..<to].joined(separator: " ")
            let attr = NSAttributedString(string: s, attributes: [.font: font])
            let line = CTLineCreateWithAttributedString(attr)
            let w = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
            cache[key] = w
            return w
        }
    }

    // MARK: - I tagli

    /// L'avido: riempi la riga finché ci sta. È quello che fa `Text` da solo, e serve a due cose —
    /// stabilire **quante** righe servono, e fare da polo negativo ai test.
    static func greedyBreaks(words: [String], width: CGFloat, m: Measurer) -> [Range<Int>] {
        var out: [Range<Int>] = []
        var start = 0
        while start < words.count {
            var end = start + 1
            while end < words.count, m.width(start, end + 1) <= width { end += 1 }
            out.append(start..<end)
            start = end
        }
        return out
    }

    /// La scelta: fra tutte le impaginazioni con **lo stesso numero di righe**, quella che costa
    /// meno.
    ///
    /// Programmazione dinamica su un problema minuscolo (quaranta parole, cinque righe): il costo
    /// esatto si può calcolare, e stimarlo con un'euristica sarebbe più codice e meno verità.
    static func balancedBreaks(words: [String], width: CGFloat, lineCount: Int, m: Measurer) -> [Range<Int>]? {
        let n = words.count
        guard lineCount > 1, lineCount <= n else { return nil }

        // best[k][i] = costo minimo per impaginare words[i..<n] in esattamente k righe.
        var best = Array(repeating: Array(repeating: Double.infinity, count: n + 1), count: lineCount + 1)
        var cut = Array(repeating: Array(repeating: -1, count: n + 1), count: lineCount + 1)
        best[0][n] = 0

        for k in 1...lineCount {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in (i + 1)...n {
                    let resto = best[k - 1][j]
                    guard resto.isFinite else { continue }
                    let c = cost(words: words, from: i, to: j, width: width, m: m,
                                 isLast: k == 1, isFirst: i == 0)
                    guard c.isFinite else { continue }
                    let total = c + resto
                    if total < best[k][i] {
                        best[k][i] = total
                        cut[k][i] = j
                    }
                }
            }
        }

        guard best[lineCount][0].isFinite else { return nil }
        var out: [Range<Int>] = []
        var i = 0
        var k = lineCount
        while k > 0 {
            let j = cut[k][i]
            guard j > i else { return nil }
            out.append(i..<j)
            i = j
            k -= 1
        }
        return out
    }

    /// Quanto costa una riga. I numeri sono relativi fra loro e non hanno unità: contano gli ordini
    /// di grandezza, ed è per questo che sono raggruppati qui invece di essere sparsi nel calcolo.
    private static func cost(words: [String], from i: Int, to j: Int, width: CGFloat,
                             m: Measurer, isLast: Bool, isFirst: Bool) -> Double {
        let w = m.width(i, j)
        if w > width {
            // Una parola sola più larga della colonna non ha alternative: si accetta, cara.
            return (j - i == 1) ? 100_000 : .infinity
        }

        var c = 0.0

        // **Bilanciamento.** Sull'ultima riga non si paga lo spazio avanzato: un blocco centrato
        // con l'ultima riga più corta è la forma normale, non un difetto.
        if !isLast {
            let slack = Double((width - w) / width)
            c += slack * slack * 1000
        }

        let ultima = words[j - 1]
        let prima = words[i]

        // **La vedova.** Una parola sola sull'ultima riga è il difetto più visibile di tutti,
        // perché è l'ultima cosa che l'occhio trova.
        if isLast, j - i == 1 { c += 6000 }

        if !isLast {
            // **Il caso «Dopo».** La riga finisce con la prima parola di un periodo nuovo.
            if j >= 2, chiudePeriodo(words[j - 2]), apreP(ultima) { c += 6000 }
            // Il confine forte: tagliare sul punto fermo è la scelta giusta quando c'è.
            if chiudePeriodo(ultima) { c -= 600 }
            else if chiudeInciso(ultima) { c -= 150 }
            // Una riga non finisce su «e», «di», «il».
            if brevissima(ultima) { c += 400 }
        }

        // **La coda.** La riga comincia con l'ultima parola del periodo precedente, cioè il
        // periodo è finito una parola dopo l'a-capo. È lo specchio del caso «Dopo».
        if !isFirst, chiudePeriodo(prima), j - i > 1 { c += 900 }

        return c
    }
}
