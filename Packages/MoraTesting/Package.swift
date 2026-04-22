// swift-tools-version: 5.9
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
        .target(name: "MoraTesting", dependencies: ["MoraCore", "MoraEngines"]),
        .testTarget(name: "MoraTestingTests", dependencies: ["MoraTesting"]),
    ]
)
