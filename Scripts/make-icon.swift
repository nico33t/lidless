// Renders the Lidless app icon at 1024×1024.
// Usage: swift Scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
else { fatalError("bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations)!
}

// macOS icon grid: 824 pt body centred in 1024, continuous corners.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(bodyPath)
ctx.setFillColor(color(0x15172A))
ctx.fillPath()
ctx.restoreGState()

// Background: deep night gradient.
ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()
ctx.drawLinearGradient(
    gradient([color(0x30345A), color(0x161830), color(0x0B0C18)], [0, 0.55, 1]),
    start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

// Soft ambient glow behind the laptop.
ctx.drawRadialGradient(
    gradient([color(0x6C7BFF, 0.30), color(0x6C7BFF, 0)], [0, 1]),
    startCenter: CGPoint(x: 512, y: 420), startRadius: 0,
    endCenter: CGPoint(x: 512, y: 420), endRadius: 420, options: [])

// Laptop seen from the side: base slab and a lid almost shut, hinged on the right.
let hinge = CGPoint(x: 770, y: 372)
let baseLength: CGFloat = 520
let thickness: CGFloat = 30
let lidAngle: CGFloat = 13 * .pi / 180

// Light spilling out of the gap between lid and base.
ctx.saveGState()
let gap = CGMutablePath()
gap.move(to: hinge)
gap.addLine(to: CGPoint(x: hinge.x - baseLength, y: hinge.y))
gap.addLine(to: CGPoint(x: hinge.x - baseLength * cos(lidAngle), y: hinge.y + baseLength * sin(lidAngle)))
gap.closeSubpath()
ctx.addPath(gap)
ctx.clip()
ctx.drawLinearGradient(
    gradient([color(0x9FE8FF, 0.95), color(0x7A8CFF, 0.55), color(0x7A8CFF, 0.0)], [0, 0.45, 1]),
    start: CGPoint(x: hinge.x - baseLength, y: hinge.y), end: hinge, options: [])
ctx.restoreGState()

// Glow fanning out of the opening, to the left.
ctx.drawRadialGradient(
    gradient([color(0x8FDcFF, 0.55), color(0x8FDCFF, 0)], [0, 1]),
    startCenter: CGPoint(x: hinge.x - baseLength + 10, y: hinge.y + 40), startRadius: 0,
    endCenter: CGPoint(x: hinge.x - baseLength + 10, y: hinge.y + 40), endRadius: 200, options: [])

func slab(origin: CGPoint, angle: CGFloat, fill: CGGradient) {
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    ctx.rotate(by: angle)
    let rect = CGRect(x: -baseLength, y: 0, width: baseLength, height: thickness)
    let path = CGPath(roundedRect: rect, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil)
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, 0.45))
    ctx.addPath(path)
    ctx.setFillColor(color(0xB8BCCB))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(fill, start: CGPoint(x: 0, y: thickness), end: .zero, options: [])
    ctx.restoreGState()
}

let aluminium = gradient([color(0xF4F5F9), color(0xC9CCD8), color(0x8E92A4)], [0, 0.5, 1])
slab(origin: CGPoint(x: hinge.x, y: hinge.y - thickness), angle: 0, fill: aluminium)
slab(origin: hinge, angle: -lidAngle, fill: aluminium)

// AI sparkle above the laptop.
func sparkle(center: CGPoint, radius: CGFloat, waist: CGFloat) {
    let path = CGMutablePath()
    for i in 0..<4 {
        let a = CGFloat(i) * .pi / 2
        let tip = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
        let next = CGFloat(i + 1) * .pi / 2
        let nextTip = CGPoint(x: center.x + cos(next) * radius, y: center.y + sin(next) * radius)
        if i == 0 { path.move(to: tip) }
        let mid = a + .pi / 4
        let control = CGPoint(x: center.x + cos(mid) * radius * waist, y: center.y + sin(mid) * radius * waist)
        path.addQuadCurve(to: nextTip, control: control)
    }
    path.closeSubpath()
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: radius * 0.5, color: color(0x8FA2FF, 0.8))
    ctx.addPath(path)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([color(0xFFFFFF), color(0xC9B6FF), color(0x7FD8FF)], [0, 0.5, 1]),
        start: CGPoint(x: center.x - radius, y: center.y + radius),
        end: CGPoint(x: center.x + radius, y: center.y - radius), options: [])
    ctx.restoreGState()
}

sparkle(center: CGPoint(x: 452, y: 640), radius: 128, waist: 0.16)
sparkle(center: CGPoint(x: 618, y: 738), radius: 52, waist: 0.18)
sparkle(center: CGPoint(x: 600, y: 560), radius: 30, waist: 0.2)

// Subtle top highlight on the tile.
ctx.drawLinearGradient(
    gradient([color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)], [0, 1]),
    start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 700), options: [])
ctx.restoreGState()

// Hairline border.
ctx.addPath(bodyPath)
ctx.setStrokeColor(color(0xFFFFFF, 0.08))
ctx.setLineWidth(2)
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
