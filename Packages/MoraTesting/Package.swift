// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoraTesting",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraTesting", targets: ["MoraTesting"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraEngines"),
    ],
    targets: [
        .target(
            name: "MoraTesting",
            dependencies: ["MoraCore", "MoraEngines"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraTestingTests",
            dependencies: ["MoraTesting"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
