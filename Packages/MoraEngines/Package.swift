// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoraEngines",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraEngines", targets: ["MoraEngines"]),
    ],
    dependencies: [
        .package(path: "../MoraCore"),
        .package(path: "../MoraTesting"),
    ],
    targets: [
        .target(
            name: "MoraEngines",
            dependencies: ["MoraCore"],
            // Per-item enumeration: SwiftPM's `.process` flattens unknown
            // resource subdirectories on macos-15 (CI) but preserves them on
            // macOS 16+ (local). The SentenceLibrary loader walks a directory
            // tree at runtime, so we use `.copy` for that subtree to pin the
            // structure across SwiftPM versions, and `.process` for the rest.
            // Adding new flat-named JSON files here requires extending this
            // list.
            resources: [
                .process("Resources/sh_week1.json"),
                .process("Resources/th_week.json"),
                .process("Resources/f_week.json"),
                .process("Resources/r_week.json"),
                .process("Resources/short_a_week.json"),
                .process("Resources/WordChainLibrary"),
                .copy("Resources/SentenceLibrary"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraEnginesTests",
            dependencies: ["MoraEngines", "MoraTesting"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
