import Foundation
import PackagePlugin

@main
struct InstallFramedScreenshotsToolPlugin: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) throws {
        let installer = FramedScreenshotsInstaller()
        let options = try InstallerOptions(arguments: arguments, workingDirectory: context.package.directoryURL)
        let report = try installer.install(options: options)
        Diagnostics.remark(report.description)
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension InstallFramedScreenshotsToolPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodeProjectPlugin.XcodePluginContext, arguments: [String]) throws {
        let installer = FramedScreenshotsInstaller()
        let options = try InstallerOptions(arguments: arguments, workingDirectory: context.xcodeProject.directoryURL)
        let report = try installer.install(options: options)
        Diagnostics.remark(report.description)
    }
}
#endif
