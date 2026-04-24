// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MoraFixtures",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MoraFixtures", targets: ["MoraFixtures"]),
    ],
    targets: [
        .target(
            name: "MoraFixtures",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MoraFixturesTests",
            dependencies: ["MoraFixtures"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
