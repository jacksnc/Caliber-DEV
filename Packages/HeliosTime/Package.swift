// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeliosTime",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HeliosTime", targets: ["HeliosTime"]),
    ],
    targets: [
        .target(name: "HeliosTime"),
        .testTarget(name: "HeliosTimeTests", dependencies: ["HeliosTime"]),
    ]
)
