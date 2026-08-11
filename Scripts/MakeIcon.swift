#!/usr/bin/env swift
// Genera l'icona di Otium: il 30 in salvia su verde notte, con la frase
// «otium cum dignitate» in Optima nelle taglie grandi.
//
// Perché prende la taglia come argomento invece di essere ridotta con sips:
// la frase sotto i 256 px non esiste più, diventa una riga sporca. L'icona
// quindi si DISEGNA a ogni taglia, e sotto la soglia la frase non viene
// scritta affatto. Un `.icns` ammette arte diversa per taglia, ed è
// esattamente il caso in cui serve.
//
// Uso: swift Scripts/MakeIcon.swift <output.png> [lato in px, default 1024]

import AppKit
import CoreText

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let px: CGFloat = CommandLine.arguments.count > 2
    ? CGFloat(Double(CommandLine.arguments[2]) ?? 1024) : 1024

// La frase sotto questa soglia non è leggibile: misurato il 2026-08-02 e
// riconfermato sul provino a 128 px del 2026-08-11.
let SOGLIA_FRASE: CGFloat = 256

func hex(_ s: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: s.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
    return NSColor(calibratedRed: CGFloat((v >> 16) & 0xFF)/255,
                   green: CGFloat((v >> 8) & 0xFF)/255,
                   blue: CGFloat(v & 0xFF)/255, alpha: 1)
}
// Livrea Alloro, gli stessi valori di Sources/OtiumCore/Theme.swift
let inchiostro = hex("#0E1512")     // verde notte
let salvia     = hex("#8FC2A4")

// Griglia icona macOS, in proporzione: piastra 824/1024, raggio 185,4/1024
let inset  = px * (100.0/1024.0)
let side   = px - inset*2
let raggio = px * (185.4/1024.0)
let plate  = NSRect(x: inset, y: inset, width: side, height: side)

/// Il 30 come tracciato, così la posa non dipende dalle metriche di riga.
func contorno(_ size: CGFloat) -> CGPath {
    let attr = NSAttributedString(string: "30", attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .black), .kern: size * -0.05])
    let out = CGMutablePath()
    for run in (CTLineGetGlyphRuns(CTLineCreateWithAttributedString(attr)) as! [CTRun]) {
        let a = CTRunGetAttributes(run) as NSDictionary
        guard let f = a[kCTFontAttributeName as String] else { continue }
        let ct = f as! CTFont
        let n = CTRunGetGlyphCount(run)
        var gl = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRangeMake(0, n), &gl)
        CTRunGetPositions(run, CFRangeMake(0, n), &pos)
        for i in 0..<n {
            guard let gp = CTFontCreatePathForGlyph(ct, gl[i], nil) else { continue }
            out.addPath(gp, transform: CGAffineTransform(translationX: pos[i].x, y: pos[i].y))
        }
    }
    return out
}

let img = NSImage(size: NSSize(width: px, height: px))
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
NSGraphicsContext.current?.imageInterpolation = .high
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: plate, xRadius: raggio, yRadius: raggio).addClip()
inchiostro.setFill(); NSBezierPath(rect: plate).fill()

// Larghezza 1,14 della piastra e bordo superiore a filo: le spalle del 3 e
// dello 0 appoggiano sui due angoli, il vuoto resta sotto per la frase.
var corpo = px * 0.4
for _ in 0..<60 {
    let k = (side * 1.14) / max(contorno(corpo).boundingBox.width, 1)
    corpo *= k
    if abs(k - 1) < 0.0005 { break }
}
let path = contorno(corpo)
let bb = path.boundingBox
var t = CGAffineTransform(translationX: plate.midX - bb.midX, y: plate.maxY - bb.maxY)
salvia.setFill()
if let m = path.copy(using: &t) { ctx.addPath(m); ctx.fillPath() }

if px >= SOGLIA_FRASE {
    let frase = "otium cum dignitate"
    var fs = px * 0.06
    for _ in 0..<40 {
        guard let f = NSFont(name: "Optima-Regular", size: fs) else { break }
        let a = NSAttributedString(string: frase, attributes: [.font: f, .kern: fs*0.13])
        let k = (side * 0.74) / max(a.size().width, 1)
        fs *= k
        if abs(k - 1) < 0.001 { break }
    }
    if let f = NSFont(name: "Optima-Regular", size: fs) {
        let a = NSAttributedString(string: frase, attributes: [
            .font: f, .kern: fs*0.13, .foregroundColor: salvia])
        a.draw(at: NSPoint(x: plate.midX - a.size().width/2, y: plate.minY + side*0.145))
    }
}
NSGraphicsContext.restoreGraphicsState()
img.unlockFocus()

// Si scrive esattamente `px` per lato: NSImage lavora in punti, il rappresentante
// va costruito in pixel o su schermo Retina uscirebbe il doppio.
guard let tiff = img.tiffRepresentation,
      let src = NSBitmapImageRep(data: tiff) else { exit(1) }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
src.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try? png.write(to: URL(fileURLWithPath: outputPath))
