// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RestaurantCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RestaurantCore", targets: ["RestaurantCore"]),
    ],
    dependencies: [
        .package(path: "../FoodCore"),
    ],
    targets: [
        .target(
            name: "RestaurantCore",
            dependencies: [.product(name: "FoodCore", package: "FoodCore")]
        ),
        .testTarget(
            name: "RestaurantCoreTests",
            dependencies: [
                "RestaurantCore",
                .product(name: "FoodCore", package: "FoodCore"),
            ]
        ),
    ]
)
