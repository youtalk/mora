// swift-tools-version: 6.0
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
            ],
            resources: [
                .copy("Resources/wav2vec2-phoneme.mlmodelc"),
                .process("Resources/phoneme-labels.json"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraMLXTests",
            dependencies: ["MoraMLX"],
            resources: [
                .process("Fixtures"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
