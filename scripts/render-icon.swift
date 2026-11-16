import AppKit
import Foundation

let destination = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 210, yRadius: 210)
        NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.29, blue: 0.39, alpha: 1),
                   ending: NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.18, alpha: 1))!.draw(in: background, angle: -55)
        let book = NSBezierPath(roundedRect: NSRect(x: 255, y: 230, width: 514, height: 602), xRadius: 54, yRadius: 54)
        NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.86, alpha: 1).setFill(); book.fill()
        NSColor(calibratedRed: 0.84, green: 0.65, blue: 0.35, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 255, y: 230, width: 54, height: 602), xRadius: 24, yRadius: 24).fill()
        NSColor(calibratedRed: 0.18, green: 0.32, blue: 0.39, alpha: 0.38).setFill()
        for (y, width) in [(670, 300), (600, 300), (530, 210)] {
            NSBezierPath(roundedRect: NSRect(x: 365, y: y, width: width, height: 19), xRadius: 9, yRadius: 9).fill()
        }
        NSColor(calibratedRed: 0.28, green: 0.75, blue: 0.67, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 185, y: 165, width: 654, height: 95), xRadius: 45, yRadius: 45).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}
