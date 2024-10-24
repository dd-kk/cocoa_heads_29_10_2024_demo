// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemoteAsyncOperation",
    defaultLocalization: "ua",
    platforms: [
        .iOS("14.5"), .macOS(.v11)
    ],
    products: [
        .library(
            name: "RemoteAsyncOperation",
            targets: ["RemoteAsyncOperation"]
        )
    ],
    targets: [
        .target(
            name: "RemoteAsyncOperation"
        ),
        .testTarget(
            name: "RemoteAsyncOperationTests",
            dependencies: [
                "RemoteAsyncOperation"
            ]
        )
    ]
)
