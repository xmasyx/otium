#!/usr/bin/env swift
// Sonda: mentre Otium sta bloccando, la finestra copre davvero ogni schermo?
//
// Uso: swift Scripts/probe-blocker.swift        (con Otium in esecuzione e in blocco)
//
// ── Perché questo file non è tre righe ────────────────────────────────────────────────────
//
// 1. Niente `screencapture`: senza il permesso Registrazione schermo restituisce un'immagine
//    **nera** invece di un errore, e un nero non si distingue da una finestra che non ha
//    disegnato niente. Una sonda che confonde "non posso vedere" con "non c'è" è peggio di
//    nessuna sonda.
//
// 2. `kCGWindowBounds` NON vive nello stesso spazio di `NSScreen.frame` né di `CGDisplayBounds`.
//    Misurato su questo Mac il 2026-07-26: una finestra che AppKit dichiara 1512×982 viene
//    elencata come 1362×884 @ (75,49), e una finestra di controllo da 400×300 come 361×271 —
//    lo stesso fattore, applicato attorno al centro dello schermo. Confrontando i numeri grezzi
//    si dichiara rotta un'app sana (successo il 2026-07-26, tre volte di fila).
//
// Quindi la sonda si **tara da sola**: costruisce una finestra che sa essere esattamente grande
// quanto lo schermo, si legge nella stessa lista, e usa quei numeri come metro per Otium. Il
// fattore di conversione non viene supposto: viene misurato ogni volta, su questa macchina,
// con questa configurazione di schermi.

import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

func bounds(ownedBy pid: Int32?, ownerName: String?) -> [(CGRect, Int)] {
    guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return [] }
    return list.compactMap { window in
        if let pid, (window[kCGWindowOwnerPID as String] as? Int32) != pid { return nil }
        if let ownerName, (window[kCGWindowOwnerName as String] as? String) != ownerName { return nil }
        guard let b = window[kCGWindowBounds as String] as? [String: Any],
              let w = b["Width"] as? Double, let h = b["Height"] as? Double,
              let x = b["X"] as? Double, let y = b["Y"] as? Double,
              w >= 10, h >= 10
        else { return nil }
        let layer = window[kCGWindowLayer as String] as? Int ?? 0
        return (CGRect(x: x, y: y, width: w, height: h), layer)
    }
}

// ── Taratura: una finestra per schermo, grande quanto lo schermo, invisibile.
var calibrators: [NSWindow] = []
for screen in NSScreen.screens {
    let w = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    w.setFrame(screen.frame, display: false)
    w.alphaValue = 0.01          // presente per il server grafico, invisibile per gli occhi
    w.ignoresMouseEvents = true
    w.level = .normal            // sotto il blocco: non deve coprirlo mentre lo misuro
    w.backgroundColor = .black
    w.orderFrontRegardless()
    calibrators.append(w)
}
RunLoop.main.run(until: Date().addingTimeInterval(1.2))

let reference = bounds(ownedBy: ProcessInfo.processInfo.processIdentifier, ownerName: nil)
    .map(\.0)
    .sorted { $0.width * $0.height > $1.width * $1.height }
for w in calibrators { w.orderOut(nil) }

print("schermi: \(NSScreen.screens.count)")
for (i, s) in NSScreen.screens.enumerated() {
    print(String(format: "  schermo %d secondo AppKit: %.0fx%.0f", i, s.frame.width, s.frame.height))
}
guard reference.count >= NSScreen.screens.count, let unit = reference.first else {
    print("RISULTATO: FAIL — taratura non riuscita (nessuna finestra di riferimento elencata)")
    exit(2)
}
for (i, r) in reference.prefix(NSScreen.screens.count).enumerated() {
    print(String(format: "  schermo %d, metro misurato: %.0fx%.0f @ (%.0f,%.0f)", i, r.width, r.height, r.minX, r.minY))
}

let shielding = Int(CGShieldingWindowLevel())
let otium = bounds(ownedBy: nil, ownerName: "Otium")
print("livello di schermatura: \(shielding)")
print("finestre di Otium elencate: \(otium.count)")

var covered = Set<Int>()
for (rect, layer) in otium {
    let match = reference.prefix(NSScreen.screens.count).firstIndex {
        abs($0.width - rect.width) < 2 && abs($0.height - rect.height) < 2
            && abs($0.minX - rect.minX) < 2 && abs($0.minY - rect.minY) < 2
    }
    if let match, layer >= shielding { covered.insert(match) }
    print(String(
        format: "  %.0fx%.0f @ (%.0f,%.0f) livello %d — %@ · %@",
        rect.width, rect.height, rect.minX, rect.minY, layer,
        match != nil ? "grande quanto lo schermo" : "NON grande quanto lo schermo",
        layer >= shielding ? "sopra la schermatura" : "sotto la schermatura"
    ))
}
_ = unit

let ok = covered.count == NSScreen.screens.count && !NSScreen.screens.isEmpty
print("RISULTATO: \(ok ? "PASS" : "FAIL") — \(covered.count)/\(NSScreen.screens.count) schermi coperti a livello di schermatura")
exit(ok ? 0 : 1)
