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
    ],
    targets: [
        .target(
            name: "PrismKit",
            path: "Sources/PrismKit"
        ),
        .testTarget(
            name: "PrismKitTests",
            dependencies: ["PrismKit"],
            path: "Tests/PrismKitTests"
        ),
    ]
)
