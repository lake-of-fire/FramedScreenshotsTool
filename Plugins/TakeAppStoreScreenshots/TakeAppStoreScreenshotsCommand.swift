import Foundation
import PackagePlugin

/*
 {
   "simulatorName" : "iPhone 14 Plus",
   "homeStyle" : "indicator",
   "displaySize" : "6.5"
 },
 */

@main
public struct TakeAppStoreScreenshotsCommand: CommandPlugin {
    /// This entry point is called when operating on a Swift package.
    public func performCommand(context: PluginContext, arguments: [String]) throws {
        debugPrint(context)
    }
    
    public init() {
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension TakeAppStoreScreenshotsCommand: XcodeCommandPlugin {
    /// This entry point is called when operating on an Xcode project.
    public func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        print(context.xcodeProject.directory)
        try takeScreenshots(for: context.xcodeProject.directory, shotplan: context.tool(named: "ShotPlanCLI"))
        print("Finished taking screnshots.")
    }
}
#endif

func takeScreenshots(for directory: PackagePlugin.Path, shotplan: PluginContext.Tool) throws {
    // ShotPlan
    let shotplanURL = URL(fileURLWithPath: shotplan.path.string)
    var errors: String = ""
    let stdout = Pipe()
    let stderr = Pipe()
    var stdoutData = Data.init(capacity: 8192)
    var stderrData = Data.init(capacity: 8192)
    let process = Process()
    process.currentDirectoryURL = URL(fileURLWithPath: directory.string)
    process.executableURL = shotplanURL
    process.arguments = ["run"]
    try process.run()
    while process.isRunning {
        stdoutData.append(stdout.fileHandleForReading.readDataToEndOfFile())
        stderrData.append(stderr.fileHandleForReading.readDataToEndOfFile())
    }
    process.waitUntilExit()
    let gracefulExit = process.terminationReason == .exit && process.terminationStatus == 0
    if !gracefulExit {
//        Diagnostics.error("🛑 The plugin execution failed")
        print("Plugin execution failed")
    }
    stdoutData.append(stdout.fileHandleForReading.readDataToEndOfFile())
    errors = String(decoding: stderrData, as: UTF8.self) + String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    if !errors.isEmpty {
        print(errors)
    }
    try process.run()
}
