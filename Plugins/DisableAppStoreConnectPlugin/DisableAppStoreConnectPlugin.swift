import Foundation
import PackagePlugin

@main
struct DisableAppStoreConnectPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let workspace = try WorkspaceResolver.resolve(from: arguments, defaultDirectory: context.package.directoryURL)
        let tool = try context.tool(named: "framed-screenshots-tool")
        try runCLI(toolURL: tool.url, workspace: workspace)
        Diagnostics.remark("Removed App Store Connect credentials for workspace at \(workspace.path)")
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension DisableAppStoreConnectPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let workspace = try WorkspaceResolver.resolve(from: arguments, defaultDirectory: context.xcodeProject.directoryURL)
        let tool = try context.tool(named: "framed-screenshots-tool")
        try runCLI(toolURL: tool.url, workspace: workspace)
        Diagnostics.remark("Removed App Store Connect credentials for workspace at \(workspace.path)")
    }
}
#endif

private func runCLI(toolURL: URL, workspace: URL) throws {
    let process = Process()
    process.executableURL = toolURL
    process.arguments = [
        "disable-app-store-connect",
        "--workspace", workspace.path
    ]
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error."
        throw PluginError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private enum PluginError: Error, CustomStringConvertible {
    case missingValue(option: String)
    case commandFailed(String)

    var description: String {
        switch self {
        case .missingValue(let option):
            return "No value provided for option \(option)."
        case .commandFailed(let message):
            return "framed-screenshots-tool failed: \(message)"
        }
    }
}

private enum WorkspaceResolver {
    static func resolve(from arguments: [String], defaultDirectory: URL) throws -> URL {
        var iterator = arguments.makeIterator()
        var workspaceURL = defaultDirectory
        while let argument = iterator.next() {
            switch argument {
            case "--workspace":
                guard let value = iterator.next() else {
                    throw PluginError.missingValue(option: "--workspace")
                }
                workspaceURL = resolvePath(value, relativeTo: defaultDirectory)
            default:
                continue
            }
        }
        return workspaceURL.standardizedFileURL
    }

    private static func resolvePath(_ value: String, relativeTo base: URL) -> URL {
        if (value as NSString).isAbsolutePath {
            return URL(fileURLWithPath: value, isDirectory: true)
        } else {
            return base.appendingPathComponent(value, isDirectory: true)
        }
    }
}
