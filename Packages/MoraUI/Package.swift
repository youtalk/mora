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
    ],
    targets: [
        .target(
            name: "MoraUI",
            dependencies: ["MoraCore", "MoraEngines"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MoraUITests", dependencies: ["MoraUI"]),
    ]
)
