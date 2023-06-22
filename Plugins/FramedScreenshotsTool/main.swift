import Foundation
import PackagePlugin

func generateFramedScreenshots(for directory: PackagePlugin.Path) throws {
    let process = Process()
//    process.currentDirectoryURL = URL(filePath: directory.string)
    process.currentDirectoryURL = URL(fileURLWithPath: directory.string)
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", "mint run shotplan@main run"]
    try process.run()
    process.waitUntilExit()
}

@main
struct FramedScreenshotsTool: CommandPlugin {
    /// This entry point is called when operating on a Swift package.
    func performCommand(context: PluginContext, arguments: [String]) throws {
        try generateFramedScreenshots(for: context.package.directory)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension FramedScreenshotsTool: XcodeCommandPlugin {
    /// This entry point is called when operating on an Xcode project.
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        try generateFramedScreenshots(for: context.xcodeProject.directory)
    }
}
#endif
