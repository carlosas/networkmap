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
    targets: [
        .executableTarget(
            name: "NetworkMap",
            path: "Sources/NetworkMap"
        ),
    ]
)
