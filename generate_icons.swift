import AppKit
import Foundation

func render(image: NSImage, size: Int, menubar: Bool) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height),
               operation: .copy,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    
    for x in 0..<size {
        for y in 0..<size {
            guard let color = rep.colorAt(x: x, y: y) else { continue }
            
            // Remove near-white background (RGB > 0.95 / 242)
            if color.redComponent > 0.95 && color.greenComponent > 0.95 && color.blueComponent > 0.95 {
                rep.setColor(NSColor.clear, atX: x, y: y)
            } else if menubar {
                // If it's for the menu bar, we make everything non-white black, preserving the alpha.
                // This creates a perfect template image for macOS to recolor dynamically.
                rep.setColor(NSColor(white: 0.0, alpha: color.alphaComponent), atX: x, y: y)
            }
        }
    }
    return rep.representation(using: .png, properties: [:])
}

let svgPath = "icon.svg"
guard let image = NSImage(contentsOfFile: svgPath) else {
    print("Failed to load \(svgPath)")
    exit(1)
}

print("Loaded \(svgPath), generating app and menubar icons...")

// 1. Generate AppIcon set
let iconsetDir = URL(fileURLWithPath: "NetworkMap.iconset")
try? FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let appIconSizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in appIconSizes {
    if let data = render(image: image, size: size, menubar: false) {
        try? data.write(to: iconsetDir.appendingPathComponent(name))
    }
}

// Shell out to iconutil to build the .icns
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", "NetworkMap.iconset", "-o", "Sources/NetworkMap/Resources/AppIcon.icns"]
task.launch()
task.waitUntilExit()

// Clean up iconset dir
try? FileManager.default.removeItem(at: iconsetDir)

// 2. Generate Menu Bar Icons
if let menuData16 = render(image: image, size: 16, menubar: true) {
    try? menuData16.write(to: URL(fileURLWithPath: "Sources/NetworkMap/Resources/MenuBarIcon.png"))
}
if let menuData32 = render(image: image, size: 32, menubar: true) {
    try? menuData32.write(to: URL(fileURLWithPath: "Sources/NetworkMap/Resources/MenuBarIcon@2x.png"))
}

print("Successfully generated and optimized icons from \(svgPath)")
