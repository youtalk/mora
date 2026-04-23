// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoraMLX",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraMLX", targets: ["MoraMLX"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraEngines"),
    ],
    targets: [
        .target(
            name: "MoraMLX",
            dependencies: [
                .product(name: "MoraCore", package: "MoraCore"),
                .product(name: "MoraEngines", package: "MoraEngines"),
            ]
        ),
        .testTarget(
            name: "MoraMLXTests",
            dependencies: ["MoraMLX"]
        ),
    ]
)
