import Foundation
import PackagePlugin

@main
struct EnableAppStoreConnectPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let workspace = try WorkspaceResolver.resolve(from: arguments, defaultDirectory: context.package.directoryURL)
        let tool = try context.tool(named: "framed-screenshots-tool")
        try AppStoreConnectConfigurator(toolURL: tool.url).enable(workspaceRoot: workspace)
        Diagnostics.remark("Stored App Store Connect credentials for workspace at \(workspace.path)")
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension EnableAppStoreConnectPlugin: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let workspace = try WorkspaceResolver.resolve(from: arguments, defaultDirectory: context.xcodeProject.directoryURL)
        let tool = try context.tool(named: "framed-screenshots-tool")
        try AppStoreConnectConfigurator(toolURL: tool.url).enable(workspaceRoot: workspace)
        Diagnostics.remark("Stored App Store Connect credentials for workspace at \(workspace.path)")
    }
}
#endif

private struct AppStoreConnectConfigurator {
    var toolURL: URL

    func enable(workspaceRoot: URL) throws {
        let keyID = try promptText(title: dialogTitle, message: "Enter App Store Connect API Key ID:")
        let issuerID = try promptText(title: dialogTitle, message: "Enter App Store Connect Issuer ID:")
        let appID = try promptText(title: dialogTitle, message: "Enter App Store Connect App ID:")
        let platform = try promptPlatform()
        let version = try promptOptionalText(title: dialogTitle, message: "Target App Version (leave blank to auto-detect):")
        let privateKeyPath = try promptPrivateKeyPath()

        var cliArguments = [
            "enable-app-store-connect",
            "--workspace", workspaceRoot.path,
            "--non-interactive",
            "--key-id", keyID,
            "--issuer-id", issuerID,
            "--app-id", appID,
            "--platform", platform,
            "--private-key-path", privateKeyPath
        ]

        if let version, !version.isEmpty {
            cliArguments += ["--app-version", version]
        }

        try runProcess(arguments: cliArguments)
    }

    private func runProcess(arguments: [String]) throws {
        let process = Process()
        process.executableURL = toolURL
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8) ?? "Unknown error."
            throw PluginError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private func promptText(title: String, message: String) throws -> String {
        let script = """
set dialogResult to display dialog "\(escape(message))" default answer "" with title "\(escape(title))"
return text returned of dialogResult
"""
        let output = try runAppleScript(script)
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PluginError.userCancelled
        }
        return trimmed
    }

    private func promptOptionalText(title: String, message: String) throws -> String? {
        let script = """
set dialogResult to display dialog "\(escape(message))" default answer "" with title "\(escape(title))"
return text returned of dialogResult
"""
        let output = try runAppleScript(script)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func promptPlatform() throws -> String {
        let script = """
set options to {\"iOS\",\"macOS\",\"tvOS\"}
set dialogResult to choose from list options with title \"\(escape(dialogTitle))\" with prompt \"Select App Store platform:\" default items {\"iOS\"}
if dialogResult is false then error number -128
set selection to item 1 of dialogResult
return selection
"""
        let output = try runAppleScript(script).lowercased()
        switch output {
        case "ios":
            return "ios"
        case "macos":
            return "macos"
        case "tvos":
            return "appletvos"
        default:
            return "ios"
        }
    }

    private func promptPrivateKeyPath() throws -> String {
        let script = """
set pickedFile to choose file with prompt "Select the App Store Connect private key (.p8)"
set filePath to POSIX path of pickedFile
return filePath
"""
        return try runAppleScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runAppleScript(_ script: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PluginError.userCancelled
        }
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let string = String(data: data, encoding: .utf8) else {
            throw PluginError.userCancelled
        }
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private var dialogTitle: String {
        "Framed Screenshots"
    }
}

private enum PluginError: Error, CustomStringConvertible {
    case missingValue(option: String)
    case userCancelled
    case commandFailed(String)

    var description: String {
        switch self {
        case .missingValue(let option):
            return "No value provided for option \(option)."
        case .userCancelled:
            return "Operation cancelled."
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
