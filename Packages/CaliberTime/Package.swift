// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaliberTime",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CaliberTime", targets: ["CaliberTime"]),
    ],
    targets: [
        .target(name: "CaliberTime"),
        .testTarget(name: "CaliberTimeTests", dependencies: ["CaliberTime"]),
    ]
)
