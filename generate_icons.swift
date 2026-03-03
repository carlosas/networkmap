import AppKit
import Foundation

func render(image: NSImage, size: Int, menubar: Bool) -> Data? {
    // Use NSBitmapImageRep directly to guarantee exact pixel dimensions
    // (NSImage lockFocus creates 2x bitmaps on Retina displays)
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
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    if menubar {
        // For menu bar template images, macOS uses only the alpha channel to draw the shape.
        // The SVG's icon silhouette is black (dark) and interior details are white (light).
        // Dark pixels → high alpha (visible); light pixels → low alpha (transparent).
        // Use direct pixel buffer access to avoid colorAt/setColor color space conversion issues.
        guard let data = rep.bitmapData else { return nil }
        let bytesPerRow = rep.bytesPerRow
        let spp = rep.samplesPerPixel

        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                let offset = y * bytesPerRow + x * spp
                let r = CGFloat(data[offset])     / 255.0
                let g = CGFloat(data[offset + 1]) / 255.0
                let b = CGFloat(data[offset + 2]) / 255.0
                let a = CGFloat(data[offset + 3]) / 255.0

                let brightness = (r + g + b) / 3.0
                let newAlpha = a * (1.0 - brightness)

                data[offset]     = 0  // R → black
                data[offset + 1] = 0  // G → black
                data[offset + 2] = 0  // B → black
                data[offset + 3] = UInt8(min(255, max(0, newAlpha * 255.0)))
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
let resourcesDir = URL(fileURLWithPath: "Sources/NetworkMap/Resources")
try? FileManager.default.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

if let menuData16 = render(image: image, size: 16, menubar: true) {
    try? menuData16.write(to: resourcesDir.appendingPathComponent("MenuBarIcon.png"))
}
if let menuData32 = render(image: image, size: 32, menubar: true) {
    try? menuData32.write(to: resourcesDir.appendingPathComponent("MenuBarIcon@2x.png"))
}

print("Successfully generated and optimized icons from \(svgPath)")
