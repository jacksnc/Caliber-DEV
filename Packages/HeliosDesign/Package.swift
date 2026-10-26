// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeliosDesign",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HeliosDesign", targets: ["HeliosDesign"]),
    ],
    targets: [
        .target(name: "HeliosDesign"),
        .testTarget(name: "HeliosDesignTests", dependencies: ["HeliosDesign"]),
    ]
)
