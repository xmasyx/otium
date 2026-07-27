import Foundation

public enum ClockEvent: Equatable, Sendable {
    /// C'è input reale: il tempo conta.
    case accumulating
    /// Nessun input, ma sei lì: un video in riproduzione o un documento aperto davanti.
    /// Il tempo conta lo stesso — anzi, è il tempo che conta di più, perché è quello in cui
    /// non ti muovi affatto.
    case quietPresence
    /// Fermo da oltre la soglia: il tempo non conta.
    case idling
    /// Appena rientrato da un'assenza di questa durata.
    case naturalBreak(seconds: Double)
}

/// L'orologio del **tempo attivo**. Non l'orologio a muro.
///
/// È la differenza che separa Otium dai concorrenti: nelle recensioni di Pushscroll il difetto
/// più citato è che sblocca in base all'ora e non all'uso, così basta fermarsi un attimo per
/// trovarsi la schermata addosso. Qui il contatore cammina solo quando cammini tu.
///
/// Logica pura e sorgente di inattività iniettata: tutto quello che sta qui dentro è provabile
/// con `swift test`, senza toccare AppKit.
public struct ActivityClock: Equatable, Sendable {
    /// Secondi di lavoro vero accumulati dall'ultimo azzeramento.
    public private(set) var activeSeconds: Double = 0
    /// Vero mentre l'assenza supera la soglia.
    public private(set) var isIdle: Bool = false
    /// Durata dell'assenza in corso (0 se non c'è).
    public private(set) var currentIdleSeconds: Double = 0
    /// Da quanto stai fermo *ma presente* (video, lettura). Serve a distinguere il rientro da
    /// un'assenza vera dal rientro da un film.
    public private(set) var quietPresenceSeconds: Double = 0
    /// Quanta parte dell'inattività in corso NON va accreditata come pausa.
    private var idleCreditBase: Double = 0

    /// Oltre questa inattività si smette di contare.
    public var idleThreshold: Double
    /// Un salto fra due tick più grande di così non è lavoro: è sospensione del sistema, o un
    /// processo rimasto fermo. Non si accredita mai.
    public var maxCredibleElapsed: Double

    public init(idleThreshold: Double, maxCredibleElapsed: Double = 5) {
        self.idleThreshold = max(1, idleThreshold)
        self.maxCredibleElapsed = max(2, maxCredibleElapsed)
    }

    /// - Parameters:
    ///   - elapsed: secondi di orologio trascorsi da questo tick al precedente.
    ///   - idle: secondi trascorsi dall'ultimo evento di input, letti dal sistema.
    ///   - presenceHolds: sei lì anche senza toccare niente (video, lettura), e il segnale non
    ///     ha ancora superato il suo tetto. Chi decide è il motore, che conosce i tetti; qui
    ///     arriva già come sì o no.
    @discardableResult
    public mutating func tick(elapsed: Double, idle: Double, presenceHolds: Bool = false) -> ClockEvent {
        // Sospensione o sonno: il Mac era chiuso, non stavo lavorando.
        if elapsed > maxCredibleElapsed {
            let gap = elapsed
            isIdle = false
            currentIdleSeconds = 0
            idleCreditBase = 0
            return .naturalBreak(seconds: gap)
        }

        if idle >= idleThreshold {
            // Presenza silenziosa: fermo davanti allo schermo è il caso peggiore, non una pausa.
            if presenceHolds {
                if isIdle {
                    // Rientro dal nulla dentro una presenza: non è stata un'assenza.
                    isIdle = false
                    currentIdleSeconds = 0
                }
                quietPresenceSeconds += max(0, elapsed)
                activeSeconds += max(0, elapsed)
                return .quietPresence
            }
            if !isIdle {
                isIdle = true
                // Il credito da restituire dipende da come ci sono arrivato. Uscendo da una
                // presenza silenziosa, l'assenza vera comincia **adesso**: accreditare tutta
                // l'inattività regalerebbe una pausa lunga a chi ha appena finito un film senza
                // muovere un dito. Nel caso normale l'assenza è cominciata all'ultimo input, e
                // vale tutta.
                idleCreditBase = quietPresenceSeconds > 0 ? idle : 0
                quietPresenceSeconds = 0
                // Fino a un attimo fa credevo fosse lavoro: quei secondi vanno restituiti,
                // altrimenti ogni assenza regala alla giornata un intero periodo di soglia.
                activeSeconds = max(0, activeSeconds - idleThreshold)
            }
            currentIdleSeconds = idle
            return .idling
        }

        quietPresenceSeconds = 0

        if isIdle {
            let completed = max(0, currentIdleSeconds - idleCreditBase)
            isIdle = false
            currentIdleSeconds = 0
            idleCreditBase = 0
            // Il tick del rientro contiene solo la coda di attività davvero avvenuta.
            activeSeconds += min(max(0, elapsed), max(0, idle))
            return .naturalBreak(seconds: completed)
        }

        activeSeconds += max(0, elapsed)
        return .accumulating
    }

    /// Azzera il conteggio: un break è stato preso (imposto o spontaneo).
    public mutating func reset() {
        activeSeconds = 0
    }

    /// Riparte da un valore salvato: serve al ripristino dopo un riavvio dell'app.
    public mutating func seed(activeSeconds seconds: Double) {
        activeSeconds = max(0, seconds)
        isIdle = false
        currentIdleSeconds = 0
        quietPresenceSeconds = 0
    }

    public func fraction(of interval: Double) -> Double {
        guard interval > 0 else { return 0 }
        return min(1.0, activeSeconds / interval)
    }

    public func secondsRemaining(of interval: Double) -> Double {
        max(0, interval - activeSeconds)
    }
}
