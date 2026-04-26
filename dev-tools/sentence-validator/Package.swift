// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sentence-validator",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "sentence-validator", targets: ["SentenceValidator"]),
    ],
    dependencies: [
        .package(path: "../../Packages/MoraEngines"),
        .package(path: "../../Packages/MoraCore"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "SentenceValidator",
            dependencies: [
                .product(name: "MoraEngines", package: "MoraEngines"),
                .product(name: "MoraCore", package: "MoraCore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/SentenceValidator"
        ),
        .testTarget(
            name: "SentenceValidatorTests",
            dependencies: ["SentenceValidator"],
            path: "Tests/SentenceValidatorTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
