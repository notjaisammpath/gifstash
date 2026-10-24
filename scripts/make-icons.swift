#!/usr/bin/env swift
// Renders the app icon and every iMessage App Icon size from one drawing.
// Run from the repo root:  swift scripts/make-icons.swift
// Output is opaque PNG (App Store Connect rejects icons with alpha).

import AppKit
import CoreGraphics
import CoreText

let violet = CGColor(srgbRed: 0.42, green: 0.22, blue: 0.95, alpha: 1)
let magenta = CGColor(srgbRed: 0.93, green: 0.25, blue: 0.62, alpha: 1)
let ink = CGColor(srgbRed: 0.07, green: 0.05, blue: 0.14, alpha: 1)

func render(width: Int, height: Int, to path: String) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    )!
    let w = CGFloat(width), h = CGFloat(height)

    // Diagonal violet → magenta background.
    let gradient = CGGradient(colorsSpace: space, colors: [violet, magenta] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: w, y: 0), options: [])

    // Soft highlight in the upper left.
    let glow = CGGradient(
        colorsSpace: space,
        colors: [CGColor(gray: 1, alpha: 0.28), CGColor(gray: 1, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        glow, startCenter: CGPoint(x: w * 0.25, y: h * 0.85), startRadius: 0,
        endCenter: CGPoint(x: w * 0.25, y: h * 0.85), endRadius: max(w, h) * 0.7, options: []
    )

    // A white card with a bookmark notch, holding the "GIF" wordmark.
    let unit = min(w, h)
    let cardW = unit * 0.62, cardH = unit * 0.62
    let card = CGRect(x: (w - cardW) / 2, y: (h - cardH) / 2 - unit * 0.02, width: cardW, height: cardH)
    let radius = unit * 0.13

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -unit * 0.025), blur: unit * 0.06,
                  color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Bookmark ribbon hanging from the card's top-right.
    let ribbonW = cardW * 0.18, ribbonH = cardH * 0.30
    let rx = card.maxX - radius * 0.6 - ribbonW, ry = card.maxY
    let ribbon = CGMutablePath()
    ribbon.move(to: CGPoint(x: rx, y: ry))
    ribbon.addLine(to: CGPoint(x: rx + ribbonW, y: ry))
    ribbon.addLine(to: CGPoint(x: rx + ribbonW, y: ry - ribbonH))
    ribbon.addLine(to: CGPoint(x: rx + ribbonW / 2, y: ry - ribbonH * 0.72))
    ribbon.addLine(to: CGPoint(x: rx, y: ry - ribbonH))
    ribbon.closeSubpath()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.addPath(ribbon)
    ctx.setFillColor(magenta)
    ctx.fillPath()
    ctx.restoreGState()

    // "GIF" wordmark.
    let font = CTFontCreateWithName("SFProRounded-Black" as CFString, cardH * 0.36, nil)
    let fallback = NSFont.systemFont(ofSize: cardH * 0.36, weight: .black)
    let useFont: CTFont = (CTFontCopyPostScriptName(font) as String).contains("Rounded")
        ? font
        : (fallback.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: cardH * 0.36) } ?? fallback) as CTFont
    let attrs: [NSAttributedString.Key: Any] = [
        .font: useFont,
        .foregroundColor: ink,
        .kern: -cardH * 0.01,
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "GIF", attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(
        x: card.midX - bounds.width / 2 - bounds.minX,
        y: card.midY - bounds.height / 2 - bounds.minY - cardH * 0.04
    )
    CTLineDraw(line, ctx)

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let appIcons = "Resources/Assets.xcassets/AppIcon.appiconset"
render(width: 1024, height: 1024, to: "\(appIcons)/AppIcon-1024.png")

let messages = "Sources/MessagesExtension/Assets.xcassets/iMessage App Icon.stickersiconset"
let sizes: [(String, Int, Int)] = [
    ("29x29@2x", 58, 58), ("29x29@3x", 87, 87),
    ("60x45@2x", 120, 90), ("60x45@3x", 180, 135),
    ("67x50@2x", 134, 100), ("74x55@2x", 148, 110),
    ("27x20@2x", 54, 40), ("27x20@3x", 81, 60),
    ("32x24@2x", 64, 48), ("32x24@3x", 96, 72),
    ("1024x768", 1024, 768), ("1024x1024", 1024, 1024),
]
for (name, w, h) in sizes {
    render(width: w, height: h, to: "\(messages)/icon-\(name).png")
}
print("Wrote \(sizes.count + 1) icons")
