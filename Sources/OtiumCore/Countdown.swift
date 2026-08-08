import Foundation

/// Il conto alla rovescia che si legge nella barra dei menu durante il preavviso.
///
/// **Non è il tempo che manca, è una scala di gradini.** Un numero che scorre secondo per secondo
/// nella barra dei menu è rumore: lo leggi con la coda dell'occhio mentre stai facendo altro, e
/// `47` non ti dice niente che `48` non avesse già detto. I gradini invece sono eventi — a 60
/// sai che ci siamo, a 30 che è ora di chiudere la frase, gli ultimi cinque li conti davvero.
///
/// **La scala si adatta al preavviso configurato**, che è un campo in secondi nelle impostazioni
/// avanzate: con un preavviso di 8 secondi i gradini a 60 e a 30 non esistono, e il primo numero
/// che vedi deve essere quello vero, non un 60 che mente.
public enum Countdown {

    /// I gradini nominali, dal preavviso pieno all'ultimo secondo.
    public static let steps: [Int] = [60, 30, 5, 4, 3, 2, 1]

    /// Il numero da scrivere nella barra, dati i secondi che mancano davvero.
    ///
    /// Il gradino mostrato è **il più piccolo che sia ancora maggiore o uguale** a quel che manca,
    /// cioè quello raggiunto per ultimo: a 45 secondi si legge ancora `60s`, e la scritta cambia
    /// nell'istante in cui il gradino successivo viene toccato. Il verso conta: l'altro
    /// arrotondamento farebbe comparire `30s` con 45 secondi ancora in mano, cioè un allarme in
    /// anticipo su un'app il cui unico compito è dirti quando alzarti.
    public static func step(remaining: Double, warningSeconds: Double) -> Int {
        let mancano = max(0, Int(remaining.rounded()))
        guard mancano > 0 else { return 0 }
        let partenza = max(1, Int(warningSeconds.rounded()))
        let scala = ([partenza] + steps).filter { $0 <= partenza }.sorted()
        // Il `?? mancano` non è difensivismo: se il motore avesse più tempo del preavviso da cui
        // è partito, mentire con l'ultimo gradino sarebbe peggio che dire il numero nudo.
        return scala.first { $0 >= mancano } ?? mancano
    }
}
