// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "NetworkMap",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NetworkMap", targets: ["NetworkMap"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4")
    ],
    targets: [
        .executableTarget(
            name: "NetworkMap",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/NetworkMap",
            exclude: ["Resources"]
        ),
    ]
)
