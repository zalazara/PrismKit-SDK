// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrismKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(name: "PrismKit", targets: ["PrismKit"]),
        .executable(name: "prismkit-mcp", targets: ["PrismKitMCP"]),
    ],
    targets: [
        .target(
            name: "PrismKit",
            path: "Sources/PrismKit"
        ),
        .executableTarget(
            name: "PrismKitMCP",
            dependencies: ["PrismKit"],
            path: "Sources/PrismKitMCP"
        ),
        .testTarget(
            name: "PrismKitTests",
            dependencies: ["PrismKit"],
            path: "Tests/PrismKitTests"
        ),
    ]
)
