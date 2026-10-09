// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NutritionCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NutritionCore", targets: ["NutritionCore"]),
    ],
    dependencies: [
        .package(path: "../CaliberTime"),
    ],
    targets: [
        .target(
            name: "NutritionCore",
            dependencies: [.product(name: "CaliberTime", package: "CaliberTime")]
        ),
        .testTarget(
            name: "NutritionCoreTests",
            dependencies: [
                "NutritionCore",
                .product(name: "CaliberTime", package: "CaliberTime"),
            ]
        ),
    ]
)
