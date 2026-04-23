// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoraCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraCore", targets: ["MoraCore"]),
    ],
    targets: [
        .target(name: "MoraCore"),
        .testTarget(name: "MoraCoreTests", dependencies: ["MoraCore"]),
    ]
)
