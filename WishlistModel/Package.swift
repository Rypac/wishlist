// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WishlistModel",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "WishlistModel",
      type: .dynamic,
      targets: ["WishlistModel"]
    )
  ],
  dependencies: [
    .package(path: "../WishlistFoundation")
  ],
  targets: [
    .target(
      name: "WishlistModel",
      dependencies: ["WishlistFoundation"]
    ),
    .testTarget(
      name: "WishlistModelTests",
      dependencies: ["WishlistModel"]
    )
  ]
)
