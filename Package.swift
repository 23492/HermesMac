// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HermesMac",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HermesMac",
            targets: ["HermesMac"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
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
