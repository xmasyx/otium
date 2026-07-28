import Foundation

/// Le due lingue, scritte una accanto all'altra dove servono.
///
/// **Perché coppie in linea e non una tabella di chiavi.** Con due lingue, una tabella
/// `"menu.stats" → [it, en]` aggiunge un livello di indirezione che si può sbagliare in silenzio:
/// una chiave scritta male dà una stringa vuota o il nome della chiave a schermo, e nessun
/// compilatore lo vede. Con `L.t("Statistiche…", "Statistics…")` la traduzione sta dove si usa, il
/// compilatore pretende entrambe, e cercare una frase nel codice la trova. Se un giorno le lingue
/// diventano cinque questa scelta va rovesciata — con due, l'indirezione costa più di quanto rende.
public enum L {

    /// La lingua corrente. La imposta l'app all'avvio leggendo le impostazioni, e la cambia
    /// l'onboarding o le preferenze. Non è `@Published`: le viste si ricostruiscono comunque a
    /// ogni apertura, e la schermata di blocco nasce quando la pausa comincia.
    public static var language: AppLanguage = .italian

    /// Italiano e inglese della stessa frase.
    public static func t(_ italian: String, _ english: String) -> String {
        language == .italian ? italian : english
    }

    /// Come sopra, per i testi con un valore dentro.
    public static func t(_ italian: @autoclosure () -> String,
                         _ english: @autoclosure () -> String,
                         interpolated: Bool) -> String {
        _ = interpolated
        return language == .italian ? italian() : english()
    }

    /// Plurale corretto nelle due lingue: in italiano lo zero vuole il plurale e l'uno il
    /// singolare, esattamente come in inglese — ma le desinenze no, e sbagliarle fa sembrare
    /// fatta male anche la parte fatta bene (difetto reale, corretto il 2026-07-28).
    public static func plural(_ count: Int,
                              it singular: String, _ plural: String,
                              en singularEN: String, _ pluralEN: String) -> String {
        language == .italian
            ? "\(count) \(count == 1 ? singular : plural)"
            : "\(count) \(count == 1 ? singularEN : pluralEN)"
    }
}

/// L'articolo davanti a un numero, in italiano.
///
/// «Oggi fai il 85%» è sbagliato: ottantacinque comincia per vocale, quindi vuole l'elisione —
/// «l'85%». Non è un dettaglio da correggere a mano frase per frase, perché la frase la scrive
/// il codice e il numero cambia ogni settimana: una stringa che va bene al 50% e sbaglia all'85%
/// è un errore che compare da solo, quando nessuno sta guardando.
///
/// Il dominio sono le percentuali e i conteggi piccoli, cioè 0-100: lì i numeri che si leggono
/// cominciando per vocale sono uno, otto, undici, diciotto e tutti gli ottanta.
public enum ItalianNumber {

    public static func startsWithVowel(_ n: Int) -> Bool {
        let m = abs(n)
        if m == 1 || m == 8 || m == 11 || m == 18 { return true }
        return (80...89).contains(m)
    }

    /// «il 50» · «l'85»
    public static func il(_ n: Int) -> String { startsWithVowel(n) ? "l'\(n)" : "il \(n)" }

    /// «al 50» · «all'85»
    public static func al(_ n: Int) -> String { startsWithVowel(n) ? "all'\(n)" : "al \(n)" }
}
