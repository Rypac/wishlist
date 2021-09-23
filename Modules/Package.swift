// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
  name: "Modules",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "Toolbox", targets: ["Toolbox"]),
    .library(name: "ToolboxUI", targets: ["ToolboxUI"]),
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "Services", targets: ["Services"])
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "0.5.0")),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", .upToNextMajor(from: "1.5.0"))
  ],
  targets: [
    .target(
      name: "Toolbox"
    ),
    .target(
      name: "ToolboxUI",
      dependencies: [
        "SDWebImageSwiftUI"
      ]
    ),
    .target(
      name: "Domain",
      dependencies: [
        .product(name: "CombineSchedulers", package: "combine-schedulers"),
        "Toolbox"
      ]
    ),
    .target(
      name: "Services",
      dependencies: ["Toolbox", "Domain"]
    ),
    .testTarget(
      name: "ToolboxTests",
      dependencies: ["Toolbox"]
    ),
    .testTarget(
      name: "DomainTests",
      dependencies: ["Domain"]
    )
  ],
  swiftLanguageVersions: [
    .v5
  ]
)
