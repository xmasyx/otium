#!/usr/bin/env swift
import Cocoa

// Sonda del gesto di scarto della notifica — il caso che il 28 luglio 2026 sembrava "bloccarsi".
//
// Perché esiste. Il gesto non si prova con `swift test`: dipende da come AppKit consegna gli
// eventi di scorrimento a un pannello che non prende mai il fuoco, e soprattutto dal fatto che
// **l'inerzia arriva dopo che hai alzato le dita**. Qui gli eventi si costruiscono a mano, con la
// stessa forma che manda il trackpad.
//
// Due modi, e il primo serve a poter credere al secondo:
//   `controllo` — una rotellata classica, ampia, senza fasi. Se questa non scarta la notifica,
//                 gli eventi sintetici non stanno arrivando affatto (permessi di accessibilità,
//                 puntatore fuori bersaglio) e qualunque risultato dell'altro modo non vuol dire
//                 niente.
//   `inerzia`   — 50 punti con le dita, SOTTO la soglia di 70, poi il resto in inerzia. È lo
//                 schema esatto che prima falliva: il codice decideva su `.ended` e buttava via
//                 la spinta.
//
// Uso: aprire l'app con `--demo-hud=25`, poi `swift Scripts/probe-swipe.swift <modo>`.
// Esce 0 se la notifica se n'è andata, 1 se è rimasta, 2 se non c'era.

let mode = CommandLine.arguments.dropFirst().first ?? "inerzia"

/// La notifica c'è? La sola esistenza basta, e non dipende dalla scala della lista finestre —
/// che **non** vive nello spazio di `NSScreen` (misurato il 26 luglio: 1512 punti elencati 1362).
func hudIsOnScreen() -> Bool {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    return list.contains { w in
        guard (w[kCGWindowOwnerName as String] as? String) == "Otium",
              let b = w[kCGWindowBounds as String] as? [String: CGFloat],
              let width = b["Width"], let height = b["Height"]
        else { return false }
        // Il pannello è largo (contenuto + corsa) e basso; lo schermo coperto è tutt'altra cosa.
        return width > 300 && height < 220
    }
}

func scroll(dx: Int32, phase: Int64, momentum: Int64) {
    guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                          wheelCount: 2, wheel1: 0, wheel2: dx, wheel3: 0) else { return }
    e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
    e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
    e.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
    e.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(dx))
    e.post(tap: .cghidEventTap)
    usleep(16_000)   // un fotogramma a 60 Hz, come il trackpad vero
}

guard hudIsOnScreen() else {
    print("SONDA: nessuna notifica sullo schermo — apri l'app con --demo-hud=25 prima")
    exit(2)
}

// Il bersaglio si calcola in coordinate `NSScreen`, non dalla lista finestre, proprio per non
// ereditarne la scala. La notifica sta in alto a destra dell'area visibile, ancorata a sinistra
// dentro una finestra più larga: un punto a 100 punti dal bordo destro e 45 dall'alto è dentro.
guard let screen = NSScreen.main else { exit(2) }
let v = screen.visibleFrame
let targetNS = CGPoint(x: v.maxX - 100, y: v.maxY - 45)
// `CGWarpMouseCursorPosition` ha l'origine in alto a sinistra, `NSScreen` in basso a sinistra.
let target = CGPoint(x: targetNS.x, y: screen.frame.height - targetNS.y)
CGWarpMouseCursorPosition(target)
usleep(250_000)
print("puntatore su (\(Int(target.x)),\(Int(target.y))) · modo: \(mode)")

if mode == "controllo" {
    // Nessuna fase, un colpo solo, ben oltre la soglia.
    for _ in 0..<10 { scroll(dx: 20, phase: 0, momentum: 0) }
} else {
    // Le dita: 50 punti in tutto, SOTTO la soglia di 70. Da solo non deve bastare.
    scroll(dx: 0, phase: 1, momentum: 0)
    for _ in 0..<5 { scroll(dx: 10, phase: 2, momentum: 0) }
    scroll(dx: 0, phase: 4, momentum: 0)
    // L'inerzia, che arriva dopo: è lei a superare la soglia. Prima veniva scartata.
    scroll(dx: 0, phase: 0, momentum: 1)
    for _ in 0..<6 { scroll(dx: 14, phase: 0, momentum: 2) }
    scroll(dx: 0, phase: 0, momentum: 3)
}

usleep(700_000)

if hudIsOnScreen() {
    print("RISULTATO: FAIL — la notifica è ancora lì")
    exit(1)
} else {
    print("RISULTATO: PASS — la notifica è stata scartata")
    exit(0)
}
