#!/usr/bin/env swift

import AppKit
import Foundation

let arguments = CommandLine.arguments

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { data.append(contentsOf: $0) }
}

func assembleICNS(iconsetPath: String, outputPath: String) throws {
    let chunks: [(type: String, filename: String)] = [
        ("icp4", "icon_16x16.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("icp5", "icon_32x32.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic08", "icon_256x256.png"),
        ("ic14", "icon_256x256@2x.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
    ]

    var body = Data()
    for chunk in chunks {
        let pngURL = URL(fileURLWithPath: iconsetPath).appendingPathComponent(chunk.filename)
        let pngData = try Data(contentsOf: pngURL)
        body.append(chunk.type.data(using: .ascii)!)
        appendUInt32(UInt32(pngData.count + 8), to: &body)
        body.append(pngData)
    }

    var icns = Data("icns".utf8)
    appendUInt32(UInt32(body.count + 8), to: &icns)
    icns.append(body)
    try icns.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
}

if arguments.count == 4, arguments[1] == "--assemble-icns" {
    do {
        try assembleICNS(iconsetPath: arguments[2], outputPath: arguments[3])
        exit(0)
    } catch {
        fputs("Unable to assemble the ICNS fallback: \(error)\n", stderr)
        exit(1)
    }
}

guard arguments.count == 2 else {
    fputs("Usage: swift scripts/make-icon.swift <output.png>\n", stderr)
    exit(2)
}

let pixelSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create the icon drawing context.\n", stderr)
    exit(1)
}

bitmap.size = NSSize(width: pixelSize, height: pixelSize)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
context.imageInterpolation = .high

let backgroundRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 205, yRadius: 205)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
NSColor(calibratedRed: 0.08, green: 0.45, blue: 0.92, alpha: 1).setFill()
backgroundPath.fill()

NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.42, blue: 0.96, alpha: 1),
    NSColor(calibratedRed: 0.03, green: 0.76, blue: 0.68, alpha: 1),
])!
gradient.draw(in: backgroundPath, angle: -48)

let highlightPath = NSBezierPath(roundedRect: backgroundRect.insetBy(dx: 7, dy: 7), xRadius: 198, yRadius: 198)
NSColor.white.withAlphaComponent(0.16).setStroke()
highlightPath.lineWidth = 10
highlightPath.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 500, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
]
let glyph = NSString(string: "한")
let glyphBounds = glyph.boundingRect(
    with: NSSize(width: 760, height: 600),
    options: [.usesLineFragmentOrigin, .usesFontLeading],
    attributes: textAttributes
)
let glyphRect = NSRect(
    x: 132,
    y: 512 - glyphBounds.height / 2 + 20,
    width: 760,
    height: glyphBounds.height
)
glyph.draw(with: glyphRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: textAttributes)

if let symbol = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Checkmark") {
    let configuration = NSImage.SymbolConfiguration(pointSize: 176, weight: .bold)
    let configuredSymbol = symbol.withSymbolConfiguration(configuration) ?? symbol
    let symbolRect = NSRect(x: 728, y: 104, width: 184, height: 184)
    let symbolPixels = 184

    if let symbolBitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: symbolPixels,
        pixelsHigh: symbolPixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let symbolContext = NSGraphicsContext(bitmapImageRep: symbolBitmap) {
        let localRect = NSRect(x: 0, y: 0, width: symbolPixels, height: symbolPixels)
        symbolBitmap.size = localRect.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = symbolContext
        symbolContext.cgContext.clear(localRect)
        configuredSymbol.draw(
            in: localRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        symbolContext.cgContext.setBlendMode(.sourceIn)
        symbolContext.cgContext.setFillColor(NSColor.white.cgColor)
        symbolContext.cgContext.fill(localRect)
        NSGraphicsContext.restoreGraphicsState()

        let tintedSymbol = NSImage(size: localRect.size)
        tintedSymbol.addRepresentation(symbolBitmap)
        tintedSymbol.draw(in: symbolRect)
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode the icon as PNG.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
do {
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Unable to write \(outputURL.path): \(error)\n", stderr)
    exit(1)
}
