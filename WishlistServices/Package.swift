// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WishlistServices",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "WishlistServices",
      type: .dynamic,
      targets: ["WishlistServices"]
    )
  ],
  dependencies: [
    .package(path: "../WishlistFoundation"),
    .package(path: "../WishlistModel")
  ],
  targets: [
    .target(
      name: "WishlistServices",
      dependencies: ["WishlistFoundation", "WishlistModel"]
    ),
    .testTarget(
      name: "WishlistServicesTests",
      dependencies: ["WishlistServices", "WishlistFoundation", "WishlistModel"]
    )
  ]
)
