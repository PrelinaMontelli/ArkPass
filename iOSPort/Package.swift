// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iOSPort",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "ArkPassApp",
            targets: ["iOSPort"]
        )
    ],
    targets: [
        .executableTarget(
            name: "iOSPort"
        )
    ]
)
