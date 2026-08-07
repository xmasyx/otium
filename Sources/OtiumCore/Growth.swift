import Foundation

/// **La crescita, letta dal registro invece che raccontata.**
///
/// Il moltiplicatore della progressione (`ProgressBook`) dice *dove sei arrivato*, e da solo è un
/// numero senza storia: 105% non racconta se ci sei arrivato ieri o due settimane fa, né quante
/// ripetizioni erano diventate. Il registro invece ha ogni conferma con la sua data e il suo
/// numero, e quella è la storia. Qui le due cose si incontrano.
///
/// Chiesta dal principale il 2026-08-04: *«sarebbe carino far vedere, quando uno attiva
/// l'incremento oltre il 100%, come quei numeri stanno aumentando … e dato che comunque li stai
/// registrando, mostrami il miglioramento ad oggi»*.
///
/// Sta nel nucleo e non nella vista perché è aritmetica su dati, e l'aritmetica si prova.
/// Una conferma, con l'informazione che la rende confrontabile o no con le altre.
public struct GrowthSession: Equatable, Sendable {
    public let reps: Int
    public let date: Date
    /// **Era una stazione di circuito.** Un circuito distribuisce il volume su quattro esercizi,
    /// quindi ogni stazione porta molto meno di un esercizio singolo (`circuitFactor`). Metterle
    /// nella stessa serie del singolo fa scendere la riga senza che tu abbia fatto niente di
    /// meno: è il difetto del 2026-08-04, *«perché l'archer è sceso? io ho sempre completato»*.
    /// Aveva ragione: l'archer passava da 6 in singolo a 4 in circuito, e la pagina lo leggeva
    /// come un calo.
    public let circuit: Bool
    /// **Quanto ne era stato prescritto per QUESTA conferma**, circuito compreso. È il numero che
    /// rende confrontabili due giornate diverse: un circuito chiede il 75% del volume di un
    /// esercizio singolo, quindi 4 in circuito e 6 da solo possono essere lo stesso risultato.
    public let base: Int

    public init(reps: Int, date: Date, circuit: Bool, base: Int) {
        self.reps = reps
        self.date = date
        self.circuit = circuit
        self.base = base
    }

    /// Dove sei rispetto a quello che era prescritto per questa conferma.
    public var percent: Int {
        guard base > 0 else { return 100 }
        return Int((Double(reps) / Double(base) * 100).rounded())
    }
}

public struct GrowthLine: Equatable, Sendable {
    public let kind: ExerciseKind
    /// Il moltiplicatore oltre il 100%: 1.0 = ancora al pieno di partenza.
    public let level: Double
    /// Ogni conferma, in ordine di tempo. È la riga che si disegna: **tutte**, perché il lavoro
    /// fatto in circuito è lavoro fatto, e nasconderlo sarebbe un altro modo di mentire.
    public let all: [GrowthSession]
    /// Solo i singoli: è la serie su cui si misura l'andamento, perché è l'unica in cui i numeri
    /// sono confrontabili fra loro.
    public var singles: [GrowthSession] { all.filter { !$0.circuit } }
    /// Le ripetizioni nell'ordine in cui sono state fatte, per il disegno.
    public var sessions: [Int] { all.map(\.reps) }
    public let firstReps: Int
    public let lastReps: Int
    public let bestReps: Int
    public let totalReps: Int
    public let lastDone: Date
    /// Le ripetizioni **del pieno**, cioè il 100% prescritto per questo esercizio: nessuna rampa,
    /// nessuna crescita. È lo zero contro cui si misura tutto il resto.
    public let baseReps: Int

    /// Quanto sei cresciuto **come lo hai vissuto**: dalla prima conferma all'ultima.
    ///
    /// Non è il moltiplicatore. Il moltiplicatore è la promessa dell'app, questo è quello che è
    /// successo davvero — e i due possono divergere, perché fra la prima volta e l'ultima ci sono
    /// anche la rampa iniziale e i cambi di variante. Quando divergono, quello vero è questo.
    /// **Dove sei rispetto al pieno, non rispetto a dove sei partito.**
    ///
    /// Correzione del principale, 2026-08-04: *«il 100% di partenza per i push-up era 8, quindi
    /// se adesso ne faccio 8 sono a livello base, non ho un incremento»*. Misurare dalla prima
    /// conferma era doppiamente sbagliato: la prima conferma cadeva dentro la rampa, quindi
    /// tornare al pieno si leggeva come un miglioramento, e ogni esercizio aveva uno zero
    /// diverso. Il pieno è lo stesso metro per tutti, ed è il metro che l'app usa per proporre.
    ///
    /// **Ogni conferma si misura sulla propria prescrizione**, quindi anche i circuiti contano:
    /// escluderli avrebbe lasciato senza numero metà degli esercizi di chi il circuito lo usa.
    public var percentOfBase: Int? {
        all.last?.percent
    }

    /// Quanto sei salito **oltre** il pieno. Zero quando sei esattamente al pieno, negativo sotto.
    public var overFullPercent: Int? { percentOfBase.map { $0 - 100 } }

    /// Cresciuto **davvero**: l'ultima conferma batte la prima.
    ///
    /// **Non è `level > 1`, e la differenza è il difetto del 2026-08-04.** Il moltiplicatore
    /// della progressione si applica alle ripetizioni *di base*, che nel frattempo cambiano da
    /// sole — la rampa dei primi giorni parte al 55% e sale, e ogni variante ha il suo carico.
    /// Risultato a schermo: `archer push-up 6 → 4` con la pastiglia «110%», e `crunch 11 → 20`
    /// con «105%». Il principale li ha letti uno accanto all'altro: *«perché Archer mi dice 110%
    /// ma passa da 6 a 4? Crunch sono quasi al 200%, non è un incremento del 5%»*. Aveva ragione:
    /// due numeri sulla stessa riga che si contraddicono sono un numero sbagliato, non due punti
    /// di vista.
    public var grown: Bool { (overFullPercent ?? 0) > 0 }

    /// Il moltiplicatore raggiunto dalla progressione. Resta nel dato perché è lo stato del
    /// motore, ma **non finisce più su una riga accanto alle ripetizioni**: lì mentiva.
    public var levelPercent: Int { Int((level * 100).rounded()) }
}

public struct GrowthReport: Equatable, Sendable {
    /// Una riga per esercizio davvero fatto almeno una volta. Mai una riga per un esercizio che
    /// non hai mai toccato: una tabella piena di zeri non è una storia, è un catalogo.
    public let lines: [GrowthLine]
    public let totalReps: Int
    public let sessions: Int
    public let firstDay: Date?
    public let lastDay: Date?

    public var grownCount: Int { lines.filter(\.grown).count }
    /// Quante righe hanno almeno una conferma singola, cioè misurabile.
    public var measuredCount: Int { lines.filter { $0.percentOfBase != nil }.count }

    /// Giorni in cui hai confermato almeno un esercizio. Non il calendario fra la prima e
    /// l'ultima: i giorni saltati non sono giorni di allenamento, e contarli gonfierebbe la media.
    public let activeDays: Int
}

public enum Growth {

    /// - Parameters:
    ///   - entries: il registro intero. Si guardano solo le conferme (`exerciseDone`), perché
    ///     sono l'unico evento in cui il numero di ripetizioni è **fatto**, non proposto.
    ///   - book: la progressione, per il moltiplicatore raggiunto.
    ///   - sex: serve al **pieno**, perché la prescrizione al 100% è calibrata (Miller 1993).
    public static func report(entries: [LedgerEntry], book: ProgressBook,
                              sex: Sex? = nil) -> GrowthReport {
        let done = entries
            .filter { $0.type == .exerciseDone }
            .filter { $0.exercise != nil && ($0.reps ?? 0) > 0 }
            .sorted { $0.timestamp < $1.timestamp }

        // **Quali conferme appartengono a un circuito.** Il registro non lo scrive su ogni
        // conferma, ma lo si ricava: le conferme fra due chiusure di pausa stanno nella stessa
        // pausa, e una pausa con più di una conferma è un circuito — quattro stazioni invece di
        // un esercizio. La chiusura con `reason: "circuito"` è la conferma esplicita quando c'è.
        var inCircuito = Set<Date>()
        var pausaCorrente: [LedgerEntry] = []
        func chiudiPausa(_ chiusura: LedgerEntry?) {
            let esplicito = chiusura?.reason == "circuito"
            if pausaCorrente.count > 1 || (esplicito && !pausaCorrente.isEmpty) {
                for e in pausaCorrente { inCircuito.insert(e.timestamp) }
            }
            pausaCorrente = []
        }
        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            switch entry.type {
            case .exerciseDone where (entry.reps ?? 0) > 0 && entry.exercise != nil:
                pausaCorrente.append(entry)
            case .completed, .skipped, .natural:
                chiudiPausa(entry)
            default:
                break
            }
        }
        chiudiPausa(nil)

        var perKind: [ExerciseKind: [LedgerEntry]] = [:]
        for entry in done {
            perKind[entry.exercise!, default: []].append(entry)
        }

        let lines: [GrowthLine] = perKind.map { kind, rows in
            let pieno = Ramp.reps(for: kind, factor: 1.0, sex: sex)
            let circuitoVecchio = Ramp.reps(for: kind, factor: ExercisePlanner.legacyCircuitFactor, sex: sex)
            let circuitoOggi = Ramp.reps(for: kind, factor: ExercisePlanner.circuitFactor, sex: sex)
            let serie = rows.map { riga -> GrowthSession in
                let circuito = inCircuito.contains(riga.timestamp)
                // La prescrizione è quella **di quel giorno**: le stazioni fatte prima del
                // 2026-08-04 valevano tre quarti, e rileggerle col metro di oggi le farebbe
                // sembrare un calo mai avvenuto.
                let prescritto = circuito
                    ? (riga.timestamp < ExercisePlanner.circuitFactorChangedOn ? circuitoVecchio : circuitoOggi)
                    : pieno
                return GrowthSession(reps: riga.reps!, date: riga.timestamp,
                                     circuit: circuito, base: prescritto)
            }
            let reps = serie.map(\.reps)
            let singoli = serie.filter { !$0.circuit }
            return GrowthLine(
                kind: kind,
                level: book.progress(for: kind).level,
                all: serie,
                firstReps: (singoli.first ?? serie.first!).reps,
                lastReps: (singoli.last ?? serie.last!).reps,
                bestReps: reps.max()!,
                totalReps: reps.reduce(0, +),
                lastDone: rows.last!.timestamp,
                baseReps: pieno
            )
        }
        // Chi è salito di più sta in cima, poi chi ha fatto più lavoro. L'ordine è quello della
        // domanda che la pagina risponde: «dove sto migliorando?».
        // Chi ha un andamento misurabile sta sopra chi non ce l'ha: una riga che dice «non lo so»
        // in cima alla pagina sposterebbe l'attenzione sul buco invece che sul lavoro.
        .sorted {
            switch ($0.percentOfBase, $1.percentOfBase) {
            case let (a?, b?) where a != b: return a > b
            case (.some, .none): return true
            case (.none, .some): return false
            default: return $0.totalReps > $1.totalReps
            }
        }

        var giorni = Set<DateComponents>()
        var calendario = Calendar.current
        calendario.timeZone = .current
        for entry in done {
            giorni.insert(calendario.dateComponents([.year, .month, .day], from: entry.timestamp))
        }

        return GrowthReport(
            lines: lines,
            totalReps: done.reduce(0) { $0 + $1.reps! },
            sessions: done.count,
            firstDay: done.first?.timestamp,
            lastDay: done.last?.timestamp,
            activeDays: giorni.count
        )
    }
}
