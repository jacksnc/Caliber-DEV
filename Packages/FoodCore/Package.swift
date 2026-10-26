// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FoodCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FoodCore", targets: ["FoodCore"]),
    ],
    targets: [
        .target(name: "FoodCore"),
        .testTarget(name: "FoodCoreTests", dependencies: ["FoodCore"]),
    ]
)
