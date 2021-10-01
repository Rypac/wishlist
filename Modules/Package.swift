// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
  name: "Modules",
  platforms: [
    .iOS("15.0")
  ],
  products: [
    .library(name: "UserDefaults", targets: ["UserDefaults"]),
    .library(name: "Toolbox", targets: ["Toolbox"]),
    .library(name: "ToolboxUI", targets: ["ToolboxUI"]),
    .library(name: "Domain", targets: ["Domain"]),
    .library(name: "Services", targets: ["Services"])
  ],
  targets: [
    .target(
      name: "UserDefaults"
    ),
    .target(
      name: "Toolbox"
    ),
    .target(
      name: "ToolboxUI"
    ),
    .target(
      name: "Domain",
      dependencies: ["Toolbox", "UserDefaults"]
    ),
    .target(
      name: "Services",
      dependencies: ["Toolbox", "Domain"]
    ),
    .testTarget(
      name: "UserDefaultsTests",
      dependencies: ["UserDefaults"]
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
