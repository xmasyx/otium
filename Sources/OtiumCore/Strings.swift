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
