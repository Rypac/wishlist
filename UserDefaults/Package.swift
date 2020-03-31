// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "UserDefaults",
  products: [
    .library(
      name: "UserDefaults",
      targets: ["UserDefaults"]
    )
  ],
  targets: [
    .target(
      name: "UserDefaults",
      dependencies: []
    ),
    .testTarget(
      name: "UserDefaultsTests",
      dependencies: ["UserDefaults"]
    )
  ]
)
