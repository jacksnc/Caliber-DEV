// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrainingCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TrainingCore", targets: ["TrainingCore"]),
    ],
    dependencies: [
        .package(path: "../HeliosTime"),
    ],
    targets: [
        .target(
            name: "TrainingCore",
            dependencies: [.product(name: "HeliosTime", package: "HeliosTime")]
        ),
        .testTarget(
            name: "TrainingCoreTests",
            dependencies: [
                "TrainingCore",
                .product(name: "HeliosTime", package: "HeliosTime"),
            ]
        ),
    ]
)
