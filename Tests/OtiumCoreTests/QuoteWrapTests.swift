import Testing
import Foundation
@testable import OtiumCore

/// Dove va a capo una frase.
///
/// **Ogni prova qui gira su tutto il mazzo, non su un esempio.** Un caso costruito a mano prova
/// che l'impaginatore sa fare quel caso; il mazzo intero prova che non ne rompe nessuno degli
/// altri, ed è la seconda domanda quella che conta quando il corpus cresce a ogni versione.
struct QuoteWrapTests {

    private var mazzo: [Phrase] { PhraseLibrary.breakPool(includingUser: false) }

    /// **Il polo negativo, e viene prima di tutto.**
    ///
    /// Se il testo grezzo — cioè quello che `Text` impagina da solo — risultasse pulito, i test
    /// verdi qui sotto non direbbero niente: misurerebbero un difetto che non esiste. Questo test
    /// è quello che si rompe per primo il giorno che il giudizio smette di giudicare.
    @Test func ilTestoGrezzoHaDifettiSuOgniColonna() {
        for colonna in QuoteWrap.colonne {
            let difetti = mazzo.flatMap { p -> [QuoteWrap.Difetto] in
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                return QuoteWrap.difetti(
                    QuoteWrap.naturalLines(p.displayText, width: colonna.larghezza, font: font))
            }
            #expect(difetti.count > 0, "colonna \(colonna.nome): l'avido non produce difetti, il giudizio non sta giudicando")
            #expect(difetti.contains(.apertura), "colonna \(colonna.nome): manca il caso «Dopo», che è quello da cui è nata la regola")
        }
    }

    /// Il polo positivo: sulle stesse frasi, impaginate, zero difetti.
    @Test func lImpaginazioneNonLasciaDifetti() {
        for colonna in QuoteWrap.colonne {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let righe = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                let difetti = QuoteWrap.difetti(righe)
                #expect(difetti.isEmpty,
                        "\(colonna.nome) · \(difetti.map(\.rawValue)) · \(righe.joined(separator: " | "))")
            }
        }
    }

    /// **Il vincolo che rende sicura tutta l'operazione.** Stesso numero di righe dell'avido,
    /// sempre: l'altezza del blocco non cambia, e le misure già fatte con `--misura` restano vere.
    @Test func ilNumeroDiRigheNonCambiaMai() {
        for colonna in QuoteWrap.colonne {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let avido = QuoteWrap.naturalLines(p.displayText, width: colonna.larghezza, font: font)
                let scelto = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                #expect(avido.count == scelto.count,
                        "\(colonna.nome) · \(avido.count) → \(scelto.count) · \(p.displayText)")
            }
        }
    }

    /// Nessuna riga esce dalla colonna. Un a-capo scritto a mano che sfora verrebbe rimandato a
    /// capo da `Text`, e l'impaginazione tornerebbe casuale proprio dove l'abbiamo decisa.
    @Test func nessunaRigaSforaLaColonna() {
        for colonna in QuoteWrap.colonne {
            for p in mazzo {
                let corpo = colonna.corpo(p.localizedText)
                let font = QuoteWrap.serif(corpo)
                for riga in QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font) {
                    let parole = QuoteWrap.words(riga)
                    guard parole.count > 1 else { continue }   // una parola sola non ha alternative
                    let m = QuoteWrap.Measurer(words: parole, font: font)
                    #expect(m.width(0, parole.count) <= colonna.larghezza,
                            "\(colonna.nome) · riga fuori colonna: \(riga)")
                }
            }
        }
    }

    /// Nessuna parola persa, nessuna aggiunta: impaginare tocca gli spazi, mai il testo.
    @Test func lImpaginazioneNonToccaIlTesto() {
        for colonna in QuoteWrap.colonne {
            for p in mazzo {
                let font = QuoteWrap.serif(colonna.corpo(p.localizedText))
                let righe = QuoteWrap.lines(p.displayText, width: colonna.larghezza, font: font)
                #expect(righe.joined(separator: " ") == QuoteWrap.words(p.displayText).joined(separator: " "),
                        "\(colonna.nome) · testo alterato: \(p.displayText)")
            }
        }
    }

    /// Ripassare una frase già impaginata non la cambia. Serve perché la vista ci passa a ogni
    /// ridisegno, e un impaginatore non idempotente accumulerebbe a-capo a ogni giro.
    @Test func impaginareDueVolteDaLoStessoRisultato() {
        let colonna = QuoteWrap.riposo
        for p in mazzo {
            let corpo = colonna.corpo(p.localizedText)
            let una = QuoteWrap.wrapped(p.displayText, width: colonna.larghezza, size: corpo)
            let due = QuoteWrap.wrapped(una, width: colonna.larghezza, size: corpo)
            #expect(una == due, "non idempotente: \(p.displayText)")
        }
    }

    /// Il caso che ha aperto la regola, per nome. Vale come documentazione eseguibile: se un
    /// giorno qualcuno cambia i pesi del costo, questo dice cosa si stava cercando di ottenere.
    @Test func ilCasoDopo() {
        let testo = "«Prima dell'illuminazione: tagliare legna, portare acqua. Dopo l'illuminazione: tagliare legna, portare acqua.»"
        let colonna = QuoteWrap.riposo
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
