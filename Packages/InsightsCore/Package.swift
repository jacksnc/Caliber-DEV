// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InsightsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "InsightsCore", targets: ["InsightsCore"]),
    ],
    dependencies: [
        .package(path: "../CaliberTime"),
    ],
    targets: [
        .target(
            name: "InsightsCore",
            dependencies: [.product(name: "CaliberTime", package: "CaliberTime")]
        ),
        .testTarget(
            name: "InsightsCoreTests",
            dependencies: [
                "InsightsCore",
                .product(name: "CaliberTime", package: "CaliberTime"),
            ]
        ),
    ]
)
