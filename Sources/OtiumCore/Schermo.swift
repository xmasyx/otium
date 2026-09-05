import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// La macchina su cui l'app sta girando, e la scala che ne deriva.
///
/// **Il difetto che ha aperto questo file** (visto all'uso il 2026-09-06, fotografia della
/// schermata di pausa su un 16"): la pagina era disegnata con numeri fissi — colonna 1000, corpo
/// 40, molla di 140, margine di 48 — e quei numeri erano giusti per lo schermo su cui erano stati
/// scelti e per nessun altro. Su un monitor esterno grande la stessa pagina occupa una frazione
/// sempre più piccola della superficie e il testo sembra rimpicciolire; su un portatile stretto
/// arriva a toccare i bordi. In tutto il percorso che disegna la frase non c'era **nemmeno una
/// lettura dello schermo**: l'app non sapeva dove stava girando.
///
/// **La regola di casa che governa la riparazione:** se un fatto è leggibile dal sistema non si
/// chiede a nessuno e non si suppone — si legge. La dimensione dello schermo lo è.
///
/// ## Perché una scala sola, e non una misura per ogni elemento
///
/// La pagina è già armonica: i rapporti fra colonna, corpo, interlinea, molla e margini sono stati
/// scelti guardandola e correggendola per settimane. Riscalare ogni elemento per conto suo
/// romperebbe proprio quei rapporti. Qui si moltiplica **tutto per lo stesso numero**, quindi la
/// pagina su uno schermo diverso è la stessa pagina, più grande o più piccola.
///
/// ## Perché la scala nasce dal lato più stretto
///
/// `min(larghezza, altezza)` rispetto allo schermo di riferimento. Prendere solo la larghezza
/// funziona finché qualcuno non attacca un monitor lungo e basso: lì il testo crescerebbe in
/// orizzontale mentre l'altezza per contenerlo non c'è, e le righe uscirebbero sotto. Il lato più
/// stretto è l'unico che non può mentire su nessuna delle due dimensioni.
///
/// ## Perché la scala ha un limite in alto, e non è pigrizia
///
/// Una riga di testo non migliora crescendo. Oltre i settanta-settantacinque caratteri l'occhio
/// perde il punto in cui la riga ricomincia e la lettura peggiora, ed è un fatto di tipografia,
/// non di gusto: su un 27" la colonna smette di allargarsi e la pagina resta leggibile invece di
/// diventare un manifesto. In basso il limite serve all'opposto: sotto una certa taglia il corpo
/// diventerebbe illeggibile, e allora è meglio che il testo tocchi i margini.
public struct Schermo: Sendable, Equatable {
    public let larghezza: CGFloat
    public let altezza: CGFloat

    public init(larghezza: CGFloat, altezza: CGFloat) {
        self.larghezza = larghezza
        self.altezza = altezza
    }

    /// **Lo schermo su cui questa pagina è stata disegnata**, in punti: il 16" del principale,
    /// misurato il 2026-09-06. Tutti i numeri di riferimento sparsi nel disegno (1000, 620, 470,
    /// 140, 48) sono i valori giusti **qui**, e per questo la scala vale esattamente 1 su questa
    /// macchina: chi lavora sul 16" non vede cambiare niente, ed è la prova più semplice che la
    /// riparazione non ha spostato la pagina, l'ha solo resa trasportabile.
    public static let riferimento = Schermo(larghezza: 1728, altezza: 1117)

    /// Sotto questa scala il corpo del testo scende sotto la soglia di leggibilità comoda.
    /// Nessun Mac in circolazione ci arriva (il più stretto, 1280×800 punti, sta a 0,72): serve
    /// contro le risoluzioni strane e contro i monitor di fortuna.
    public static let scalaMinima: CGFloat = 0.62
    /// Oltre questa scala la riga diventa troppo lunga per essere letta comodamente. Un 5K da 27"
    /// (2560×1440) sta a 1,29 e quindi non la tocca; la tocca uno schermo da studio.
    public static let scalaMassima: CGFloat = 1.45

    /// Quante volte questa macchina è lo schermo di riferimento, dal lato più stretto.
    public var scala: CGFloat {
        let grezza = min(larghezza / Self.riferimento.larghezza,
                         altezza / Self.riferimento.altezza)
        return min(max(grezza, Self.scalaMinima), Self.scalaMassima)
    }

    /// Una misura del disegno, portata su questa macchina.
    ///
    /// **Arrotondata al punto intero**, sempre. Una colonna a 1002,24 punti e un corpo a 39,7 si
    /// disegnano lo stesso, ma i tagli di riga vengono calcolati su un numero e verificati su un
    /// altro appena qualcuno rifà il conto altrove: l'arrotondamento qui dentro toglie in partenza
    /// la possibilità che esistano due versioni della stessa misura.
    public func misura(_ riferimento: CGFloat) -> CGFloat {
        (riferimento * scala).rounded()
    }

    // MARK: - Quello che il sistema dice

    /// Lo schermo su cui disegnare **adesso**.
    ///
    /// È una copia tenuta da parte e non una lettura a ogni accesso, per due motivi. Il primo è
    /// che le viste la leggono decine di volte per pagina e `NSScreen` non è gratis. Il secondo è
    /// più importante: se ogni lettura andasse al sistema, una pagina disegnata mentre l'utente
    /// stacca il monitor userebbe due schermi diversi nella stessa passata. Qui il valore cambia
    /// in un punto solo, quando il sistema annuncia che la scrivania è cambiata.
    public private(set) nonisolated(unsafe) static var attuale: Schermo = riferimento

    /// Rilegge il sistema. Torna `true` se qualcosa è davvero cambiato, così chi osserva ridisegna
    /// solo quando serve.
    @discardableResult
    public static func rileggi() -> Bool {
        let nuovo = daSistema()
        guard nuovo != attuale else { return false }
        attuale = nuovo
        return true
    }

    /// **Il fallback è il riferimento, non un numero inventato.** Senza schermo (una corsa dei
    /// test, un processo senza sessione grafica) la pagina si disegna com'è sempre stata: è
    /// l'unico valore di cui sappiamo con certezza che produce una pagina sana.
    public static func daSistema() -> Schermo {
        #if canImport(AppKit)
        if let cornice = (NSScreen.main ?? NSScreen.screens.first)?.frame, cornice.width > 0 {
            return Schermo(larghezza: cornice.width, altezza: cornice.height)
        }
        #endif
        return riferimento
    }

    /// Per i test e per le sonde: impone uno schermo senza chiedere niente al sistema.
    public static func imponi(_ schermo: Schermo) { attuale = schermo }

    /// Le taglie vere dei Mac, dalla più stretta alla più larga, in punti.
    ///
    /// **Sta nel nucleo e non nel test** per la stessa ragione per cui ci stanno le colonne: un
    /// elenco ricopiato nel test invecchia da solo, e il giorno che se ne aggiunge una il test
    /// continuerebbe a promuovere la pagina di ieri. Da qui la leggono sia la spazzata dei test
    /// sia la sonda `--misura`.
    public static let taglieDiProva: [(nome: String, schermo: Schermo)] = [
        // **In ordine di scala crescente, non di pollici.** Il 14" Pro ha di serie più punti del
        // 15" Air (1512×982 contro 1470×956), quindi «più grande» in pollici e «più grande» in
        // punti non sono lo stesso ordine: l'elenco segue i punti, che sono ciò su cui si disegna.
        ("MacBook Air 13\" (1280×800)", Schermo(larghezza: 1280, altezza: 800)),
        ("MacBook Air 15\" (1470×956)", Schermo(larghezza: 1470, altezza: 956)),
        ("MacBook Pro 14\" (1512×982)", Schermo(larghezza: 1512, altezza: 982)),
        ("MacBook Pro 16\" (1728×1117)", riferimento),
        ("MacBook Pro 16\" più spazio (2056×1329)", Schermo(larghezza: 2056, altezza: 1329)),   // lingua: ok etichetta di sonda, non va a schermo
        ("Studio Display 27\" (2560×1440)", Schermo(larghezza: 2560, altezza: 1440)),
        ("Pro Display XDR (3008×1692)", Schermo(larghezza: 3008, altezza: 1692)),
    ]
}
