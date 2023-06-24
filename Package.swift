// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FramedScreenshotsTool",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FrameKit", targets: ["FrameKit"]),
        .executable(name: "FramedScreenshotsCLI", targets: ["FramedScreenshotsCLI"]),
        .plugin(name: "FramedScreenshotsTool", targets: ["FramedScreenshotsTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.2.2")),
        //        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/lake-of-fire/ShotPlan.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "FrameKit",
            dependencies: [],
            resources: [
                .copy("Resources/Frames"),
            ]
        ),
        .target(
            name: "FrameKitLayout",
            dependencies: [
                .target(name: "FrameKit"),
            ]
        ),
        .executableTarget(
            name: "FramedScreenshotsCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "shotplan", package: "ShotPlan"),
                .target(name: "FrameKit"),
                .target(name: "FrameKitLayout"),
            ]),
        .plugin(
            name: "FramedScreenshotsTool",
            capability: .command(
                intent: .custom(verb: "generate-framed-screenshots", description: "Generate framed screenshots."),
                permissions: [
                    .writeToPackageDirectory(reason: "Takes and frames screenshots.")
                ]
            ),
            dependencies: [
                .product(name: "shotplan", package: "ShotPlan"),
                "FramedScreenshotsCLI",
            ]),
    ]
)
