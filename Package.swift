// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FramedScreenshotsTool",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "FrameKit", targets: ["FrameKit"]),
        .library(name: "FrameKitLayout", targets: ["FrameKitLayout"]),
        .library(name: "ShotPlan", targets: ["ShotPlan"]),
        .executable(name: "ShotPlanCLI", targets: ["ShotPlanCLI"]),
        .executable(name: "framed-screenshots-tool", targets: ["FramedScreenshotsToolCLI"]),
        .plugin(name: "InstallFramedScreenshotsToolPlugin", targets: ["InstallFramedScreenshotsToolPlugin"]),
        .plugin(name: "EnableAppStoreConnectPlugin", targets: ["EnableAppStoreConnectPlugin"]),
        .plugin(name: "DisableAppStoreConnectPlugin", targets: ["DisableAppStoreConnectPlugin"]),
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
        .executableTarget(
            name: "ShotPlanCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .target(name: "ShotPlan"),
            ]),
        .target(
            name: "InstallerCore",
            dependencies: []
        ),
        .executableTarget(
            name: "FramedScreenshotsToolCLI",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "InstallerCore"
            ]
        ),
        .plugin(
            name: "InstallFramedScreenshotsToolPlugin",
            capability: .command(
                intent: .custom(
                    verb: "install-framed-screenshots-tool",
                    description: "Install or update the workspace-local FramedScreenshots package and mise task."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Writes the workspace-local FramedScreenshots package and mise tasks.")
                ]
            )
        ),
        .plugin(
            name: "EnableAppStoreConnectPlugin",
            capability: .command(
                intent: .custom(
                    verb: "enable-framed-screenshots-app-store-connect",
                    description: "Enable App Store Connect screenshot uploads for the current workspace."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Stores App Store Connect credentials in the workspace configuration directory.")
                ]
            )
        ),
        .plugin(
            name: "DisableAppStoreConnectPlugin",
            capability: .command(
                intent: .custom(
                    verb: "disable-framed-screenshots-app-store-connect",
                    description: "Disable App Store Connect screenshot uploads for the current workspace."
                ),
                permissions: [
                    .writeToPackageDirectory(reason: "Removes App Store Connect credentials from the workspace configuration directory.")
                ]
            )
        ),
        .testTarget(
            name: "InstallerCoreTests",
            dependencies: ["InstallerCore"]
        ),
    ]
)
