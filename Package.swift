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
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
    ],
    targets: [
        .executableTarget(
            name: "HermesMac",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
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
