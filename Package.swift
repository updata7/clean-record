// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CleanRecord",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "CleanRecord",
            targets: ["CleanRecord"]
        ),
    ],
    dependencies: [
        // Dependencies go here.
    ],
    targets: [
        .executableTarget(
            name: "CleanRecord",
            dependencies: [],
            path: "Sources"
        ),
    ]
)
