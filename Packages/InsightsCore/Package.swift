// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InsightsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InsightsCore", targets: ["InsightsCore"]),
    ],
    dependencies: [
        .package(path: "../HeliosTime"),
    ],
    targets: [
        .target(
            name: "InsightsCore",
            dependencies: [.product(name: "HeliosTime", package: "HeliosTime")]
        ),
        .testTarget(
            name: "InsightsCoreTests",
            dependencies: [
                "InsightsCore",
                .product(name: "HeliosTime", package: "HeliosTime"),
            ]
        ),
    ]
)
