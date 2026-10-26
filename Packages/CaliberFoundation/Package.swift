// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CaliberFoundation",
  defaultLocalization: "en",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "CaliberCore", targets: ["CaliberCore"]),
    .library(name: "CaliberDatabase", targets: ["CaliberDatabase"]),
    .library(name: "CaliberDesignSystem", targets: ["CaliberDesignSystem"]),
    .library(name: "CaliberCharts", targets: ["CaliberCharts"]),
    .library(name: "CaliberSeedData", targets: ["CaliberSeedData"]),
    .library(name: "CaliberIntegrations", targets: ["CaliberIntegrations"]),
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.9.0"),
    .package(path: "../HeliosDesign"),
  ],
  targets: [
    .target(name: "CaliberCore", resources: [.process("Resources")]),
    .target(
      name: "CaliberDatabase",
      dependencies: ["CaliberCore", .product(name: "GRDB", package: "GRDB.swift")],
      resources: [.process("Resources")]),
    .target(
      name: "CaliberDesignSystem", dependencies: ["CaliberCore", "HeliosDesign"],
      resources: [.process("Resources")]
    ),
    .target(name: "CaliberCharts", dependencies: ["CaliberCore", "CaliberDesignSystem"]),
    .target(name: "CaliberSeedData", dependencies: ["CaliberCore"]),
    .target(name: "CaliberIntegrations", dependencies: ["CaliberCore", "CaliberDatabase"]),
    .testTarget(name: "CaliberCoreTests", dependencies: ["CaliberCore"]),
    .testTarget(name: "CaliberChartsTests", dependencies: ["CaliberCharts"]),
    .testTarget(
      name: "CaliberDatabaseTests", dependencies: ["CaliberDatabase", "CaliberSeedData"]),
    .testTarget(name: "CaliberSeedDataTests", dependencies: ["CaliberSeedData"]),
    .testTarget(name: "CaliberIntegrationsTests", dependencies: ["CaliberIntegrations"]),
  ]
)
