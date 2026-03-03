import AppKit
import Foundation

func render(image: NSImage, size: Int, menubar: Bool) -> Data? {
    let targetSize = NSSize(width: size, height: size)
    let newImage = NSImage(size: targetSize)
    
    newImage.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: targetSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    newImage.unlockFocus()
    
    guard let tiffData = newImage.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData) else { return nil }
    
    for x in 0..<size {
        for y in 0..<size {
            guard let color = rep.colorAt(x: x, y: y) else { continue }
            
            // For a black-on-white SVG, the grayscale intensity represents the "background"
            // We convert white (1.0) to alpha=0.0 (transparent) and black (0.0) to alpha=1.0 (opaque)
            let whiteLevel = (color.redComponent + color.greenComponent + color.blueComponent) / 3.0
            let newAlpha = 1.0 - whiteLevel
            
            if newAlpha < 0.01 {
                rep.setColor(NSColor.clear, atX: x, y: y)
            } else {
                // Set all drawn pixels to black with their properly extracted alpha
                // This makes them perfectly anti-aliased templates for the Menu Bar
                rep.setColor(NSColor(white: 0.0, alpha: newAlpha), atX: x, y: y)
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
