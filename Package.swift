// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "obsidian-clipper",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ObsidianClipper",
            targets: ["ObsidianClipper"]
        )
    ],
    targets: [
        .target(
            name: "ObsidianClipper",
            path: "swift/Sources/ObsidianClipper",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ObsidianClipperTests",
            dependencies: ["ObsidianClipper"],
            path: "swift/Tests/ObsidianClipperTests"
        )
    ]
)
