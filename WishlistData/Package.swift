// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WishlistData",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15)
  ],
  products: [
    .library(
      name: "WishlistData",
      type: .dynamic,
      targets: ["WishlistData"]
    )
  ],
  dependencies: [
    .package(path: "../WishlistFoundation")
  ],
  targets: [
    .target(
      name: "WishlistData",
      dependencies: ["WishlistFoundation"]
    ),
    .testTarget(
      name: "WishlistDataTests",
      dependencies: ["WishlistData"]
    )
  ]
)
