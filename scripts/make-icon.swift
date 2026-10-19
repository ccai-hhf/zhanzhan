import AppKit
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let pixels = size * scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()
    let base = NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 215, yRadius: 215)
    NSGradient(starting: NSColor.systemBlue, ending: NSColor(red: 0.39, green: 0.65, blue: 1, alpha: 1))!.draw(in: base, angle: 75)
    NSColor.white.withAlphaComponent(0.65).setStroke()
    let back = NSBezierPath(roundedRect: NSRect(x: 265, y: 385, width: 365, height: 385), xRadius: 65, yRadius: 65)
    back.lineWidth = 35; back.stroke()
    NSColor.white.withAlphaComponent(0.16).setFill()
    let front = NSBezierPath(roundedRect: NSRect(x: 385, y: 255, width: 365, height: 385), xRadius: 65, yRadius: 65)
    front.fill(); NSColor.white.setStroke(); front.lineWidth = 38; front.stroke()
    image.unlockFocus()
    let representation = NSBitmapImageRep(data: image.tiffRepresentation!)!
    let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
    try representation.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name))
  }
}
