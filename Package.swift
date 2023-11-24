// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FramedScreenshotsTool",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "FrameKit", targets: ["FrameKit"]),
        .library(name: "ShotPlan", targets: ["ShotPlan"]),
        .executable(name: "ShotPlanCLI", targets: ["ShotPlanCLI"]),
        .library(name: "FramedScreenshotsCLI", targets: ["FramedScreenshotsCLI"]),
        .plugin(name: "TakeAppStoreScreenshots", targets: ["TakeAppStoreScreenshots"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.2.2")),
    ],
    targets: [
        .target(
            name: "FrameKit",
            dependencies: [
                .target(name: "ShotPlan"),
            ],
            resources: [
//                .copy("Resources/Frames"),
                .process("Resources"),
            ]
        ),
        .target(
            name: "FrameKitLayout",
            dependencies: [
                .target(name: "FrameKit"),
            ]
        ),
        .target(
            name: "ShotPlan",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "FramedScreenshotsCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
//                .product(name: "ShotPlan", package: "ShotPlan"),
                "ShotPlan",
//                .product(name: "shotplan", package: "ShotPlan"),
                .target(name: "FrameKit"),
                .target(name: "FrameKitLayout"),
            ]),
        .executableTarget(
            name: "ShotPlanCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "ShotPlan"),
            ]),
        .plugin(
            name: "TakeAppStoreScreenshots",
            capability: .command(
                intent: .custom(verb: "generate-framed-screenshots", description: "Generate screenshots for devices."),
                permissions: [
                    .writeToPackageDirectory(reason: "Takes screenshots and saves them.")
                ]
            ),
            dependencies: [
                .target(name: "ShotPlanCLI"),
            ]),
    ]
)
