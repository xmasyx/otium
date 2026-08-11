// Sonda a due poli sul passaggio del mouse sulla notifica.
//
//   ./.build/release/OtiumApp --demo-hud=5 &   poi:
//   swift Scripts/probe-hover.swift --sopra   -> deve stampare ANCORA LI
//   swift Scripts/probe-hover.swift           -> deve stampare SPARITO
//
// Il polo positivo è quello che conta e i primi due tentativi lo davano rosso a
// torto: con `--demo-hud=N` l'app si autoterminava a N+2 secondi, quindi la
// sonda misurava la morte del processo invece della scadenza della notifica.
// Il margine ora è N+30. Se un domani torna stretto, questa sonda torna a
// mentire nello stesso identico modo.
import AppKit

func pannello() -> CGRect? {
    guard let l = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return nil }
    for w in l {
        let owner = (w[kCGWindowOwnerName as String] as? String) ?? ""
        guard owner.contains("Otium") else { continue }
        let b = w[kCGWindowBounds as String] as! [String: CGFloat]
        guard b["Height"]! < 220, b["Width"]! > 600 else { continue }
        return CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
    }
    return nil
}

let sopra = CommandLine.arguments.contains("--sopra")
guard let r = pannello() else { print("NESSUN PANNELLO"); exit(2) }
// la scheda è la parte SINISTRA della finestra: il resto è la corsa per lo scarto
let punto = sopra ? CGPoint(x: r.minX + 100, y: r.minY + r.height / 2)
                  : CGPoint(x: 30, y: 900)
CGWarpMouseCursorPosition(punto)
print("mouse \(sopra ? "SOPRA" : "LONTANO") · pannello \(Int(r.width))x\(Int(r.height)) a \(Int(r.minX)),\(Int(r.minY))")
Thread.sleep(forTimeInterval: 11)
print(pannello() == nil ? "SPARITO" : "ANCORA LI")
