#!/usr/bin/swift
//
// Renders the layer images for HubDrop's Icon Composer file.
//
//     swift Scripts/make-icon.swift
//
// Writes one 1024 pixel PNG per layer into HubDrop/AppIcon.icon/Assets. The
// bundle's icon.json stacks them into groups and turns on Liquid Glass, so
// the layers here are flat shapes with no highlights or shadows of their
// own. The system renders the glass, depth, dark and mono variants, and
// every size from these layers at build time.
//
// Motif: the same idea as Xcode's Device Hub icon, since HubDrop is a
// companion to it. A faint blueprint grid, three translucent glass device
// shapes (phone, tablet, Vision Pro), and a blue plus badge in the bottom
// right that echoes the photo.badge.plus glyph in the menu bar. The
// geometry and colours are HubDrop's own.

import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repoRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = repoRoot.appendingPathComponent("HubDrop/AppIcon.icon/Assets", isDirectory: true)

/// Icon Composer layers span the whole 1024 point icon; the system applies
/// the rounded mask. All geometry below is in that space.
let canvas: CGFloat = 1024

let rgb = CGColorSpaceCreateDeviceRGB()

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [r, g, b, a])!
}

/// Fills `path` with a top-to-bottom gradient.
func fill(_ path: CGPath, top: CGColor, bottom: CGColor, in context: CGContext) {
    let bounds = path.boundingBoxOfPath
    context.saveGState()
    context.addPath(path)
    context.clip()
    let gradient = CGGradient(colorsSpace: rgb, colors: [top, bottom] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: bounds.midX, y: bounds.maxY),
        end: CGPoint(x: bounds.midX, y: bounds.minY),
        options: []
    )
    context.restoreGState()
}

/// A Vision Pro silhouette: a fully rounded wide shape with a concave nose
/// notch in the bottom edge. Built counterclockwise in y-up coordinates.
func visorPath(in rect: CGRect) -> CGPath {
    let r = rect.height * 0.45
    let notchRadius = rect.height * 0.33
    let notchDrop = rect.height * 0.09 // how far the notch circle's centre sits below the edge
    let notchCenter = CGPoint(x: rect.midX, y: rect.minY - notchDrop)
    let halfChord = (notchRadius * notchRadius - notchDrop * notchDrop).squareRoot()
    let edgeAngle = atan2(notchDrop, halfChord)

    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX - halfChord, y: rect.minY))
    path.addArc(center: notchCenter, radius: notchRadius, startAngle: .pi - edgeAngle, endAngle: edgeAngle, clockwise: true)
    path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r), radius: r)
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - r, y: rect.maxY), radius: r)
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - r), radius: r)
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + r, y: rect.minY), radius: r)
    path.closeSubpath()
    return path
}

// MARK: - Layers

/// Blueprint grid, six cells across. Drawn in one colour; icon.json sets its opacity.
func drawGrid(in context: CGContext) {
    context.setStrokeColor(color(0.45, 0.65, 0.95))
    context.setLineWidth(4)
    let cell = canvas / 6
    for i in 1..<6 {
        let offset = CGFloat(i) * cell
        context.move(to: CGPoint(x: offset, y: 0))
        context.addLine(to: CGPoint(x: offset, y: canvas))
        context.move(to: CGPoint(x: 0, y: offset))
        context.addLine(to: CGPoint(x: canvas, y: offset))
    }
    context.strokePath()
}

func drawTablet(in context: CGContext) {
    let path = CGPath(roundedRect: CGRect(x: 248, y: 410, width: 572, height: 422), cornerWidth: 60, cornerHeight: 60, transform: nil)
    fill(path, top: color(0.62, 0.88, 1.0), bottom: color(0.36, 0.74, 0.98), in: context)
}

func drawPhone(in context: CGContext) {
    let path = CGPath(roundedRect: CGRect(x: 136, y: 224, width: 274, height: 472), cornerWidth: 54, cornerHeight: 54, transform: nil)
    fill(path, top: color(0.22, 0.60, 1.0), bottom: color(0.04, 0.38, 0.95), in: context)
}

func drawVisor(in context: CGContext) {
    let path = visorPath(in: CGRect(x: 398, y: 248, width: 522, height: 286))
    fill(path, top: color(0.60, 0.46, 1.0), bottom: color(0.40, 0.26, 0.95), in: context)
}

/// Blue disc with a white plus. One layer so the glass treats it as a single
/// raised element.
func drawBadge(in context: CGContext) {
    let center = CGPoint(x: 835, y: 189)
    let radius: CGFloat = 146
    let disc = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
    fill(disc, top: color(0.30, 0.66, 1.0), bottom: color(0.08, 0.40, 0.95), in: context)

    let arm: CGFloat = 80
    context.setStrokeColor(color(1, 1, 1))
    context.setLineCap(.round)
    context.setLineWidth(42)
    context.move(to: CGPoint(x: center.x - arm, y: center.y))
    context.addLine(to: CGPoint(x: center.x + arm, y: center.y))
    context.move(to: CGPoint(x: center.x, y: center.y - arm))
    context.addLine(to: CGPoint(x: center.x, y: center.y + arm))
    context.strokePath()
}

// MARK: - Output

func render(_ draw: (CGContext) -> Void) -> CGImage {
    let pixels = Int(canvas)
    let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: rgb,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setShouldAntialias(true)
    draw(context)
    return context.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

let layers: [(name: String, draw: (CGContext) -> Void)] = [
    ("grid", drawGrid),
    ("tablet", drawTablet),
    ("phone", drawPhone),
    ("visor", drawVisor),
    ("badge", drawBadge),
]

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for layer in layers {
    let url = outputDirectory.appendingPathComponent("\(layer.name).png")
    try write(render(layer.draw), to: url)
    print("wrote \(url.lastPathComponent)")
}
