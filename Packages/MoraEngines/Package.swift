// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoraEngines",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraEngines", targets: ["MoraEngines"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
    ],
    targets: [
        .target(
            name: "MoraEngines",
            dependencies: ["MoraCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "MoraEnginesTests", dependencies: ["MoraEngines"]),
    ]
)
