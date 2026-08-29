// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Ledge",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LedgeCore", targets: ["LedgeCore"]),
        .executable(name: "Ledge", targets: ["Ledge"])
    ],
    targets: [
        .target(name: "LedgeCore"),
        .executableTarget(
            name: "Ledge",
            dependencies: ["LedgeCore"]
        ),
        .testTarget(
            name: "LedgeCoreTests",
            dependencies: ["LedgeCore"]
        )
    ]
)
