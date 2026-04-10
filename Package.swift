// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HermesMac",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HermesMac",
            targets: ["HermesMac"]
        )
    ],
    dependencies: [
        // Dependencies worden per task toegevoegd.
        // Task 10: swift-markdown-ui
        // Task 11: Splash
    ],
    targets: [
        .target(
            name: "HermesMac",
            path: "Sources/HermesMac",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "HermesMacTests",
            dependencies: ["HermesMac"],
            path: "Tests/HermesMacTests"
        )
    ]
)
