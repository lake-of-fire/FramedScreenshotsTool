// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FramedScreenshotsTool",
    products: [
        .plugin(name: "FramedScreenshotsTool", targets: ["FramedScreenshotsTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lake-of-fire/ShotPlan.git", branch: "main"),
        .package(url: "https://github.com/lake-of-fire/FrameKit.git", branch: "main"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .plugin(name: "FramedScreenshotsTool",
                capability: .command(
                    intent: .custom(verb: "generate-framed-screenshots", description: "Generate framed screenshots."),
                    permissions: [
                        .writeToPackageDirectory(reason: "Takes and frames screenshots.")
                    ]
                ),
                dependencies: [
                    .product(name: "shotplan", package: "ShotPlan"),
                    .product(name: "FrameKit", package: "framekit"),
                ]),
    ]
)
