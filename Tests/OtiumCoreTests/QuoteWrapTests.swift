import Testing
import Foundation
import AppKit
@testable import OtiumCore

/// Dove va a capo una frase.
///
/// **Ogni prova qui gira su tutto il mazzo, non su un esempio.** Un caso costruito a mano prova
/// che l'impaginatore sa fare quel caso; il mazzo intero prova che non ne rompe nessuno degli
/// altri, ed è la seconda domanda quella che conta quando il corpus cresce a ogni versione.
///
/// **E dal 2026-09-06 gira su tutte le taglie di Mac, non su tre colonne fisse.** Finché le
/// colonne erano costanti scritte nel codice, misurarle una volta bastava. Adesso le calcola la
/// scala della macchina, e un verde ottenuto sul 16" di casa non direbbe niente su un portatile
/// stretto o su un monitor da studio: la spazzata è la sola forma di prova che regge alla
/// riparazione. L'elenco delle taglie vive in `Schermo.taglieDiProva`, non ricopiato qui — un
/// elenco ricopiato nel test è l'incidente del 2026-08-05, la sonda che riscrive la logica che
/// deve misurare.
struct QuoteWrapTests {

    private var mazzo: [Phrase] { PhraseLibrary.breakPool(includingUser: false) }

    /// Le tre superfici per ognuna delle taglie: è la popolazione su cui gira quasi tutto.
    private var superfici: [(nome: String, colonna: QuoteWrap.Colonna)] {
        Schermo.taglieDiProva.flatMap { taglia in
            QuoteWrap.colonne(su: taglia.schermo).map { ("\($0.nome) · \(taglia.nome)", $0) }
        }
    }

    /// La sola fase di riposo, su tutte le taglie.
    private var riposi: [(nome: String, colonna: QuoteWrap.Colonna)] {
        Schermo.taglieDiProva.map { ($0.nome, QuoteWrap.riposo(su: $0.schermo)) }
    }

    // MARK: - La scala

    /// **La prova di parità, ed è la più importante delle nuove.**
    ///
    /// Sullo schermo di riferimento la scala vale 1 e ogni misura deve tornare **identica** ai
    /// numeri scelti guardando la pagina per settimane: colonna 1000, corpo 40, corpo ridotto 30,
    /// esercizio 620/18, pannello 470 di scatola e 416 di colonna. Se questo test diventa rosso,
    /// la riparazione ha spostato il disegno invece di renderlo trasportabile — che è esattamente
    /// la cosa che non deve succedere.
    @Test func sulloSchermoDiRiferimentoNienteCambia() {
        let s = Schermo.riferimento
        #expect(s.scala == 1)
        let riposo = QuoteWrap.riposo(su: s)
        #expect(riposo.larghezza == 1000)
        #expect(riposo.corpoBase == 40)
        #expect(riposo.corpoRidotto?.corpo == 30)
        #expect(riposo.corpoRidotto?.oltre == 95)
        let esercizio = QuoteWrap.esercizio(su: s)
        #expect(esercizio.larghezza == 620)
        #expect(esercizio.corpoBase == 18)
        let pannello = QuoteWrap.Pannello.geometria(su: s)
        #expect(pannello.scatola == 470)
        #expect(pannello.respiro == 18)
        #expect(pannello.barra == 4)
        #expect(pannello.stacco == 14)
        #expect(pannello.colonna == 416)
        #expect(QuoteWrap.pannello(su: s).corpoBase == 15)
    }

    /// La scala cresce con lo schermo, ma non oltre i limiti dichiarati.
    ///
    /// Il polo che conta è il **monotòno**: uno schermo più grande non può produrre una pagina
    /// più piccola. Un rapporto scritto al contrario per sbaglio passerebbe qualunque controllo
    /// sui singoli valori e si vedrebbe solo a occhio, su una macchina che non abbiamo.
    @Test func laScalaCresceConLoSchermoESiFermaAiLimiti() {
        var precedente: CGFloat = 0
        for taglia in Schermo.taglieDiProva {
            let scala = taglia.schermo.scala
            #expect(scala >= Schermo.scalaMinima && scala <= Schermo.scalaMassima,
                    "\(taglia.nome): scala \(scala) fuori dai limiti")
            #expect(scala >= precedente, "\(taglia.nome): la scala è scesa su uno schermo più grande")
            precedente = scala
        }
        // I due estremi: uno schermo assurdamente piccolo e uno assurdamente grande finiscono
        // sul limite invece di produrre un corpo illeggibile o una riga lunga una parete.
        #expect(Schermo(larghezza: 640, altezza: 400).scala == Schermo.scalaMinima)
        #expect(Schermo(larghezza: 8000, altezza: 5000).scala == Schermo.scalaMassima)
    }

    /// **La colonna sta dentro lo schermo, margini compresi, su ogni taglia.**
    ///
    /// È il difetto che la scala potrebbe introdurre e i test sui tagli non vedrebbero: le righe
    /// sarebbero giuste per la colonna, e la colonna troppo larga per la macchina. Il margine è
    /// quello vero della pagina (48 punti di riferimento, scalati), contato da tutte e due le
    /// parti.
    @Test func laColonnaStaDentroLoSchermo() {
        for taglia in Schermo.taglieDiProva {
            let s = taglia.schermo
            let margini = s.misura(48) * 2
            for colonna in QuoteWrap.colonne(su: s) {
                #expect(colonna.larghezza + margini <= s.larghezza,
                        "\(taglia.nome) · \(colonna.nome): \(colonna.larghezza) + \(margini) > \(s.larghezza)")
            }
        }
    }

    // MARK: - I tagli

    /// **Il polo negativo, e viene prima di tutto.**
    ///
    /// Se il testo grezzo — cioè quello che `Text` impagina da solo — risultasse pulito, i test
    /// verdi qui sotto non direbbero niente: misurerebbero un difetto che non esiste. Questo test
    /// è quello che si rompe per primo il giorno che il giudizio smette di giudicare.
    @Test func ilTestoGrezzoHaDifettiSuOgniColonna() {
        for (nome, colonna) in superfici {
            let difetti = mazzo.flatMap { p -> [QuoteWrap.Difetto] in
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                return QuoteWrap.difetti(
                    QuoteWrap.naturalLines(p.displayText, width: colonna.larghezza, font: font))
            }
            #expect(difetti.count > 0, "colonna \(nome): l'avido non produce difetti, il giudizio non sta giudicando")
        }
        // Il caso «Dopo» è quello da cui è nata la regola: deve esistere almeno su una superficie,
        // non necessariamente su tutte — è la larghezza a decidere dove cade il taglio dell'avido,
        // e pretenderlo ovunque significherebbe pretendere che ogni schermo rompa la stessa frase
        // nello stesso punto.
        let tutti = superfici.flatMap { (_, colonna) in
            mazzo.flatMap { p -> [QuoteWrap.Difetto] in
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                return QuoteWrap.difetti(
                    QuoteWrap.naturalLines(p.displayText, width: colonna.larghezza, font: font))
            }
        }
        #expect(tutti.contains(.apertura), "manca il caso «Dopo», che è quello da cui è nata la regola")
    }

    /// **Esiste una disposizione senza difetti con lo stesso numero di righe?**
    ///
    /// La cerca per esaurimento: tutte le spezzature in cui ogni riga ci sta nella colonna. Con
    /// due o tre righe e una ventina di parole lo spazio è minuscolo, e la risposta è certa invece
    /// che stimata.
    ///
    /// Serve a separare le due cose che il test di prima confondeva: **un impaginatore che
    /// sbaglia** e **un testo che a una certa larghezza non ha nessuna disposizione pulita**. Il
    /// secondo caso esiste davvero, e non era visibile finché le colonne erano tre: a una certa
    /// larghezza una frase entra in due righe invece che in tre, e a due righe il taglio sul punto
    /// fermo lascerebbe la seconda riga più larga della colonna. Non è un difetto riparabile
    /// spostando il taglio: o si aggiunge una riga — e l'altezza della pagina è vincolata — o si
    /// riscrive la frase.
    private func esisteDisposizionePulita(_ testo: String, larghezza: CGFloat,
                                          font: NSFont, righe: Int) -> Bool {
        let parole = QuoteWrap.words(testo)
        guard righe > 0, parole.count >= righe else { return false }
        let m = QuoteWrap.Measurer(words: parole, font: font)
        var trovata = false
        func cerca(da i: Int, rimaste: Int, costruite: [String]) {
            if trovata { return }
            guard rimaste > 0 else {
                if i == parole.count, QuoteWrap.difetti(costruite).isEmpty { trovata = true }
                return
            }
            var j = i + 1
            while j <= parole.count - (rimaste - 1) {
                // La larghezza cresce con le parole: appena sfora, tutte le spezzature più lunghe
                // sforano a loro volta.
                guard m.width(i, j) <= larghezza else { break }
                cerca(da: j, rimaste: rimaste - 1,
                      costruite: costruite + [parole[i..<j].joined(separator: " ")])
                j += 1
            }
        }
        cerca(da: 0, rimaste: righe, costruite: [])
        return trovata
    }

    /// **Il polo positivo: nessun difetto EVITABILE.**
    ///
    /// La formulazione di prima — «zero difetti» — era vera sulle tre colonne fisse e si è
    /// scoperta falsa in generale il 2026-09-06, alla prima corsa della spazzata: sul pannello di
    /// un 27" una frase entra in due righe e a due righe non esiste taglio pulito. Pretendere zero
    /// difetti lì sarebbe pretendere l'impossibile, e l'unico modo di far tornare verde il test
    /// sarebbe stato togliere quella superficie dalla misura, cioè spegnere il controllo.
    ///
    /// Quindi la domanda giusta: **quando una disposizione pulita esiste, è quella scelta.**
    @Test func lImpaginazioneNonLasciaDifettiEvitabili() {
        var inevitabili: [String] = []
        for (nome, colonna) in superfici {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let righe = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                let difetti = QuoteWrap.difetti(righe)
                guard !difetti.isEmpty else { continue }
                let pulita = esisteDisposizionePulita(p.displayText, larghezza: colonna.larghezza,
                                                      font: font, righe: righe.count)
                #expect(!pulita,
                        "\(nome) · esisteva una disposizione pulita e non è stata scelta · \(difetti.map(\.rawValue)) · \(righe.joined(separator: " | "))")
                if !pulita { inevitabili.append("\(nome) · \(righe.joined(separator: " | "))") }
            }
        }
        // **Quanti sono i casi senza scampo: uno, contato.** Il numero non è scelto, è quello
        // misurato il 2026-09-06 sulle sette taglie per tutte e tre le superfici — 21 colonne per
        // 129 frasi — e l'unico caso è la frase sulla pausa programmata sul pannello di un 27".
        // Se cresce, qualcuno ha aggiunto una frase che a una certa larghezza non si può
        // impaginare pulita: va riscritta, non lasciata passare in silenzio.
        #expect(inevitabili.count <= 1,
                "casi senza disposizione pulita: \(inevitabili.count)\n\(inevitabili.joined(separator: "\n"))")
    }

    /// **Il vincolo che rende sicura tutta l'operazione.** Stesso numero di righe dell'avido,
    /// sempre: l'altezza del blocco non cambia, e le misure già fatte con `--misura` restano vere.
    @Test func ilNumeroDiRigheNonCambiaMai() {
        for (nome, colonna) in superfici {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let avido = QuoteWrap.naturalLines(p.displayText, width: colonna.larghezza, font: font)
                let scelto = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                #expect(avido.count == scelto.count,
                        "\(nome) · \(avido.count) → \(scelto.count) · \(p.displayText)")
            }
        }
    }

    /// Nessuna riga esce dalla colonna. Un a-capo scritto a mano che sfora verrebbe rimandato a
    /// capo da `Text`, e l'impaginazione tornerebbe casuale proprio dove l'abbiamo decisa.
    @Test func nessunaRigaSforaLaColonna() {
        for (nome, colonna) in superfici {
            for p in mazzo {
                let corpo = colonna.corpo(p.localizedText)
                let font = QuoteWrap.serif(corpo)
                for riga in QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font) {
                    let parole = QuoteWrap.words(riga)
                    guard parole.count > 1 else { continue }   // una parola sola non ha alternative
                    let m = QuoteWrap.Measurer(words: parole, font: font)
                    #expect(m.width(0, parole.count) <= colonna.larghezza,
                            "\(nome) · riga fuori colonna: \(riga)")
                }
            }
        }
    }

    /// Nessuna parola persa, nessuna aggiunta: impaginare tocca gli spazi, mai il testo.
    @Test func lImpaginazioneNonToccaIlTesto() {
        for (nome, colonna) in superfici {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let righe = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                #expect(righe.joined(separator: " ") == QuoteWrap.words(p.displayText).joined(separator: " "),
                        "\(nome) · testo alterato: \(p.displayText)")
            }
        }
    }

    /// Ripassare una frase già impaginata non la cambia. Serve perché la vista ci passa a ogni
    /// ridisegno, e un impaginatore non idempotente accumulerebbe a-capo a ogni giro.
    @Test func impaginareDueVolteDaLoStessoRisultato() {
        for (nome, colonna) in riposi {
            for p in mazzo {
                let corpo = colonna.corpo(p.localizedText)
                let una = QuoteWrap.wrapped(p.displayText, width: colonna.larghezza, size: corpo)
                let due = QuoteWrap.wrapped(una, width: colonna.larghezza, size: corpo)
                #expect(una == due, "\(nome) · non idempotente: \(p.displayText)")
            }
        }
    }

    /// **Nessuna frase supera le tre righe nella fase di riposo.**
    ///
    /// Esiste perché il cancello sulla lunghezza (`testNoPhraseOverflowsTheScreenInEitherLanguage`,
    /// 145 caratteri) copre `Quotes` e `Mindful` e **non** `Facts`: il 2026-08-07 una riga da 146
    /// caratteri ci è passata attraverso senza che niente dicesse niente, e altre quattro erano lì
    /// da prima. Il numero di caratteri era comunque la domanda sbagliata — il corpo scende a 30
    /// punti sopra i 95, quindi la lunghezza non dice l'altezza. Questa la dice: tre righe è quanto
    /// il mazzo produce oggi ed è quanto è stato **guardato** a schermo. Oltre, nessuno ha ancora
    /// guardato, e il test si rompe apposta per farlo guardare.
    ///
    /// **Su tutte le taglie, dal 2026-09-06.** Colonna e corpo crescono insieme, quindi il numero
    /// di righe di una frase non dovrebbe dipendere dalla macchina: questo test è anche il
    /// controllo che quella proprietà valga davvero, e non solo sulla carta.
    @Test func nessunaFraseSuperaLeTreRigheNelRiposo() {
        for (nome, colonna) in riposi {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let righe = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                #expect(righe.count <= 3,
                        "\(nome) · \(righe.count) righe — mai guardate a schermo: \(p.displayText)")
            }
        }
    }

    /// Il caso che ha aperto la regola, per nome. Vale come documentazione eseguibile: se un
    /// giorno qualcuno cambia i pesi del costo, questo dice cosa si stava cercando di ottenere.
    ///
    /// Resta ancorato allo **schermo di riferimento**: è un caso storico, e un caso storico si
    /// riproduce sulle misure in cui è successo.
    @Test func ilCasoDopo() {
        let testo = "«Prima dell'illuminazione: tagliare legna, portare acqua. Dopo l'illuminazione: tagliare legna, portare acqua.»"
        let colonna = QuoteWrap.riposo(su: .riferimento)
        let font = QuoteWrap.serif(colonna.corpo(testo))
        let avido = QuoteWrap.naturalLines(testo, width: colonna.larghezza, font: font)
        let scelto = QuoteWrap.lines(testo, width: colonna.larghezza, font: font)
        #expect(avido.first?.hasSuffix("Dopo") == true, "il difetto originale non si riproduce più")
        #expect(scelto.count == 2)
        #expect(scelto.first?.hasSuffix("acqua.") == true, "il taglio non cade sul punto fermo")
        #expect(scelto.last?.hasPrefix("Dopo") == true)
    }

    /// I confini di periodo si riconoscono, le abbreviazioni no. Senza questa distinzione
    /// «ecc. qualcosa» sembrerebbe un periodo nuovo e il taglio scapperebbe dove non c'è.
    @Test func ilPuntoFermoNonSiConfondeConLAbbreviazione() {
        #expect(QuoteWrap.chiudePeriodo("acqua."))
        #expect(QuoteWrap.chiudePeriodo("acqua.»"))
        #expect(QuoteWrap.chiudePeriodo("davvero?"))
        #expect(!QuoteWrap.chiudePeriodo("acqua"))
        #expect(QuoteWrap.apreP("Dopo"))
        #expect(QuoteWrap.apreP("«Prima"))
        #expect(!QuoteWrap.apreP("dopo"))
        // «ecc.» chiude solo se quello che segue comincia in maiuscolo: qui non segue niente di
        // maiuscolo, quindi non è un periodo nuovo e la coppia non scatta.
        #expect(!QuoteWrap.apreP("qualcosa"))
    }
}
