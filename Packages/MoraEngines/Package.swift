// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoraEngines",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraEngines", targets: ["MoraEngines"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraTesting"),
    ],
    targets: [
        .target(
            name: "MoraEngines",
            dependencies: ["MoraCore"],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraEnginesTests",
            dependencies: ["MoraEngines", "MoraTesting"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
