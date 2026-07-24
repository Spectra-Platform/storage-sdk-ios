// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpectraStorageSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "SpectraStorageSDK",
            targets: ["SpectraStorageSDK"]
        ),
    ],
    targets: [
        .target(
            name: "SpectraStorageSDK"
        ),
        .testTarget(
            name: "SpectraStorageSDKTests",
            dependencies: ["SpectraStorageSDK"]
        ),
    ]
)
