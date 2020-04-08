// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WishlistFoundation",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "WishlistFoundation",
      type: .dynamic,
      targets: ["WishlistFoundation"]
    )
  ],
  dependencies: [],
  targets: [
    .target(
      name: "WishlistFoundation",
      dependencies: []
    ),
    .testTarget(
      name: "WishlistFoundationTests",
      dependencies: ["WishlistFoundation"]
    )
  ]
)
