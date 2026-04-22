// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoraUI",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraUI", targets: ["MoraUI"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraEngines"),
        .package(path: "../MoraTesting"),
    ],
    targets: [
        .target(name: "MoraUI", dependencies: ["MoraCore", "MoraEngines", "MoraTesting"]),
        .testTarget(name: "MoraUITests", dependencies: ["MoraUI"]),
    ]
)
