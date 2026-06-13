// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Preflight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Preflight", targets: ["Preflight"]),
        .executable(name: "preflight", targets: ["PreflightCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "Preflight",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .executableTarget(
            name: "PreflightCLI",
            dependencies: [
                "Preflight",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/PreflightCLI"
        ),
        .testTarget(
            name: "PreflightTests",
            dependencies: ["Preflight"]
        ),
    ]
)
