#!/usr/bin/env swift
// Genera l'icona di Otium: quadrante scuro, anello ambra quasi chiuso, due barre di pausa.
// Uso: swift Scripts/MakeIcon.swift <output.png>

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

let size = 1024.0
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// Fondo
let inset = size * 0.06
let bg = NSBezierPath(
    roundedRect: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
    xRadius: size * 0.22,
    yRadius: size * 0.22
)
NSColor(calibratedWhite: 0.09, alpha: 1.0).setFill()
bg.fill()

// Anello: il tempo che scorre, quasi pieno.
let center = CGPoint(x: size / 2, y: size / 2)
let radius = size * 0.30
let ring = NSBezierPath()
ring.appendArc(
    withCenter: NSPoint(x: center.x, y: center.y),
    radius: radius,
    startAngle: 90,
    endAngle: -170,
    clockwise: true
)
NSColor(calibratedRed: 0.96, green: 0.62, blue: 0.16, alpha: 1.0).setStroke()
ring.lineWidth = size * 0.055
ring.lineCapStyle = .round
ring.stroke()

// Le due barre della pausa.
let barWidth = size * 0.075
let barHeight = size * 0.26
let gap = size * 0.055
for dx in [-(gap / 2 + barWidth), gap / 2] {
    let bar = NSBezierPath(
        roundedRect: NSRect(
            x: center.x + dx,
            y: center.y - barHeight / 2,
            width: barWidth,
            height: barHeight
        ),
        xRadius: barWidth / 2.4,
        yRadius: barWidth / 2.4
    )
    NSColor(calibratedWhite: 0.97, alpha: 1.0).setFill()
    bar.fill()
}

image.unlockFocus()
_ = ctx

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write("icona: codifica PNG fallita\n".data(using: .utf8)!)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print(outputPath)
} catch {
    FileHandle.standardError.write("icona: scrittura fallita — \(error)\n".data(using: .utf8)!)
    exit(1)
}
