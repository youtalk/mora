// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoraMLX",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraMLX", targets: ["MoraMLX"]),
    ],
    targets: [
        .target(name: "MoraMLX"),
    ]
)
