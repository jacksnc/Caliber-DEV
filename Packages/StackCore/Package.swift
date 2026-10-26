// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StackCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "StackCore", targets: ["StackCore"]),
    ],
    dependencies: [
        .package(path: "../HeliosTime"),
    ],
    targets: [
        .target(
            name: "StackCore",
            dependencies: [.product(name: "HeliosTime", package: "HeliosTime")]
        ),
        .testTarget(
            name: "StackCoreTests",
            dependencies: [
                "StackCore",
                .product(name: "HeliosTime", package: "HeliosTime"),
            ]
        ),
    ]
)
