// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "WishlistServices",
  platforms: [
    .iOS(.v13)
  ],
  products: [
    .library(
      name: "WishlistServices",
      type: .dynamic,
      targets: ["WishlistServices"]
    )
  ],
  dependencies: [
    .package(path: "../WishlistShared")
  ],
  targets: [
    .target(
      name: "WishlistServices",
      dependencies: ["WishlistShared"]
    ),
    .testTarget(
      name: "WishlistServicesTests",
      dependencies: ["WishlistServices"]
    )
  ]
)
