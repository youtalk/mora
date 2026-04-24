// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoraCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraCore", targets: ["MoraCore"]),
    ],
    targets: [
        .target(
            name: "MoraCore",
            resources: [
                .process("Resources"),
                .copy("Yokai/YokaiCatalog.json"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraCoreTests",
            dependencies: ["MoraCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
