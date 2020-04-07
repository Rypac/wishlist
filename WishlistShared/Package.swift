// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WishlistShared",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "WishlistShared",
      type: .dynamic,
      targets: ["WishlistShared"]
    )
  ],
  dependencies: [
    .package(path: "../UserDefaults")
  ],
  targets: [
    .target(
      name: "WishlistShared",
      dependencies: ["UserDefaults"]
    ),
    .testTarget(
      name: "WishlistSharedTests",
      dependencies: ["WishlistShared"]
    )
  ]
)
