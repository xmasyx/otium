import Foundation

/// Una riga di complimenti, breve e variabile.
///
/// Il messaggio dopo una pausa segnata diceva «il conto non si tocca»: una nota tecnica,
/// giusta la prima volta e rumore dalla seconda in poi. Chi ha appena fatto otto squat non ha
/// bisogno di sapere come funziona il contatore, ha bisogno che qualcuno se ne accorga.
///
/// Variabili di proposito: un complimento sempre uguale smette di essere un complimento e
/// diventa carta da parati.
///
/// **Sta in un file suo dal 2026-07-29, e non è una questione di ordine.** Finché viveva in
/// fondo a `Quotes.swift` era coperto dall'esenzione che quel file ha come tabella bilingue,
/// cioè la guardia della lingua non lo guardava — proprio il difetto che il principale ha
/// visto. Qui dentro invece la guardia lo legge, e un ritorno dell'errore diventa rosso.
/// **Erano solo italiane, e uscivano così anche nell'app inglese.** Segnalato dal principale il
/// 2026-07-29, subito dopo una pausa da cinque minuti: gli esercizi sopra erano in inglese e il
/// complimento sotto no. Nessuna traduzione mancava per distrazione: mancava la *forma* che
/// costringe a scriverla, perché una riga qui è un dato di un `enum` e non una `Text` nella vista,
/// e nessuno guarda i dati quando cerca le stringhe da tradurre. Ora la coppia è il tipo:
/// aggiungerne una senza inglese non compila.
public enum Praise {
    public static let afterBreak: [(it: String, en: String)] = [
        ("Bel lavoro.", "Nice work."),
        ("Fatto.", "Done."),
        ("Così si fa.", "That's how it's done."),
        ("Una in più.", "One more in the bank."),
        ("Ottimo.", "Excellent."),
        ("Sei stato di parola.", "You kept your word."),
        ("Bravo.", "Well done."),
        ("Segnata, e meritata.", "Logged, and earned."),
        ("Detto e fatto.", "Said and done."),
        ("Questa è disciplina.", "That's discipline."),
        ("Un'altra nel conto.", "Another one on the count."),
        ("Preciso.", "Right on."),
        ("Non era scontato, e l'hai fatta.", "It wasn't a given, and you did it."),
        ("Il corpo ringrazia.", "Your body thanks you."),
        ("Puntuale.", "Right on time."),
    ]
    public static let afterHardOne: [(it: String, en: String)] = [
        ("Quella era la parte dura.", "That was the hard part."),
        ("Col fiatone, come deve essere.", "Out of breath, exactly as it should be."),
        ("La più faticosa della giornata, fatta.", "The hardest one of the day, done."),
        ("Bel fegato.", "That took guts."),
        ("Quella costava, e l'hai pagata.", "That one cost something, and you paid it."),
        ("Cuore a mille, ed è il punto.", "Heart pounding, and that's the point."),
        ("La più scomoda, tolta di mezzo.", "The most uncomfortable one, out of the way."),
    ]

    public static func line(at index: Int, hard: Bool = false) -> String {
        let list = hard ? afterHardOne : afterBreak
        let riga = list[((index % list.count) + list.count) % list.count]
        return L.t(riga.it, riga.en)
    }

    /// Tutte le coppie, per il test che pretende l'inglese su ognuna.
    public static var allPairs: [(it: String, en: String)] { afterBreak + afterHardOne }
}
