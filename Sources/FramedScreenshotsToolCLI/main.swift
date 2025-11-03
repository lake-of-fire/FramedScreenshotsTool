import ArgumentParser
import Foundation
import InstallerCore

@main
struct FramedScreenshotsTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "framed-screenshots-tool",
        abstract: "Utilities for installing and configuring the Framed Screenshots workspace tool.",
        subcommands: [
            Install.self,
            EnableAppStoreConnect.self,
            DisableAppStoreConnect.self,
            CacheFrameItAssets.self
        ],
        defaultSubcommand: Install.self
    )

    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install-framed-screenshots-tool",
            abstract: "Install or update the workspace-local FramedScreenshots package."
        )

        @Option(name: .customLong("workspace"), help: "Workspace or project directory to operate on.")
        var workspacePath: String = "."

        @Option(name: .customLong("tool-folder"), help: "Relative folder for the workspace-local FramedScreenshots package.")
        var toolFolder: String = "Tools/FramedScreenshots"

        @Option(name: .customLong("task-name"), help: "mise task name to create or update.")
        var taskName: String = "framed-screenshots"

        @Option(name: .customLong("task-dir"), help: "mise task directory strategy: auto or explicit relative path.")
        var taskDirectoryStrategy: String = "auto"

        @Flag(name: .customLong("dry-run"), help: "Show planned changes without writing.")
        var dryRun: Bool = false

        @Flag(name: .customLong("force"), help: "Recreate generated blocks.")
        var force: Bool = false

        @Flag(name: .customLong("verbose"), help: "Enable verbose logging.")
        var verbose: Bool = false

        @Flag(name: .customLong("no-mise"), help: "Skip mise task creation.")
        var skipMise: Bool = false

        func run() throws {
            let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
            let taskStrategy: TaskDirectoryStrategy
            if taskDirectoryStrategy == "auto" {
                taskStrategy = .auto
            } else {
                taskStrategy = .exact(taskDirectoryStrategy)
            }

            let installer = FramedScreenshotsInstaller()
            let report = try installer.install(
                options: InstallerOptions(
                    workspace: workspaceURL,
                    toolFolder: toolFolder,
                    taskName: taskName,
                    taskDirectoryStrategy: taskStrategy,
                    dryRun: dryRun,
                    force: force,
                    verbose: verbose,
                    createMiseTask: !skipMise
                )
            )
            print(report.description)
        }
    }

    struct EnableAppStoreConnect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "enable-app-store-connect",
            abstract: "Store App Store Connect credentials for automated screenshot uploads."
        )

        @Option(name: .customLong("workspace"), help: "Workspace or project directory to operate on.")
        var workspacePath: String = "."

        @Option(name: .customLong("key-id"), help: "App Store Connect API Key Identifier.")
        var keyIdentifier: String?

        @Option(name: .customLong("issuer-id"), help: "App Store Connect Issuer Identifier.")
        var issuerIdentifier: String?

        @Option(name: .customLong("app-id"), help: "App Store Connect App ID.")
        var appId: String?

        @Option(name: .customLong("platform"), help: "Platform to upload screenshots for (ios|macos|appletvos).")
        var platform: String?

        @Option(name: .customLong("app-version"), help: "Optional app version to target for uploads.")
        var version: String?

        @Option(name: .customLong("private-key"), help: "Raw private key string.")
        var privateKey: String?

        @Option(name: .customLong("private-key-path"), help: "Path to the .p8 private key file.")
        var privateKeyPath: String?

        @Flag(name: .customLong("non-interactive"), help: "Fail if required values are missing instead of prompting.")
        var nonInteractive: Bool = false

        func run() throws {
            let workspaceURL = URL(fileURLWithPath: workspacePath).standardizedFileURL
            let keyID = try resolveValue(existing: keyIdentifier, prompt: "App Store Connect API Key ID")
            let issuerID = try resolveValue(existing: issuerIdentifier, prompt: "App Store Connect Issuer ID")
            let appID = try resolveValue(existing: appId, prompt: "App Store Connect App ID")
            let resolvedPlatform = try resolvePlatform(existing: platform)
            let resolvedVersion = version ?? promptOptional("Target version (press return to skip)")
            let resolvedKey = try resolvePrivateKey()

            let credentials = AppStoreConnectConfigurationStore.Credentials(
                keyIdentifier: keyID,
                issuerIdentifier: issuerID,
                privateKey: resolvedKey,
                appId: appID,
                platform: resolvedPlatform,
                version: resolvedVersion?.isEmpty == true ? nil : resolvedVersion
            )

            try AppStoreConnectConfigurationStore.saveCredentials(credentials, workspaceRoot: workspaceURL)
            print("Saved App Store Connect credentials for workspace \(workspaceURL.path) to the macOS Keychain.")
        }

        private func resolveValue(existing: String?, prompt: String) throws -> String {
            if let value = existing, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
            guard !nonInteractive else {
                throw ValidationError("\(prompt) is required.")
            }
            return promptForInput(prompt)
        }

        private func resolvePlatform(existing: String?) throws -> String {
            let candidate: String
            if let existing, !existing.isEmpty {
                candidate = existing.lowercased()
            } else if nonInteractive {
                throw ValidationError("Platform is required.")
            } else {
                candidate = promptWithDefault("Platform (ios/macos/appletvos)", defaultValue: "ios").lowercased()
            }
            switch candidate {
            case "ios", "macos", "appletvos":
                return candidate
            default:
                throw ValidationError("Unsupported platform \(candidate). Use ios, macos, or appletvos.")
            }
        }

        private func resolvePrivateKey() throws -> String {
            if let key = privateKey, !key.isEmpty {
                return normalisePrivateKey(key)
            }
            if let path = privateKeyPath, !path.isEmpty {
                return try loadPrivateKey(from: path)
            }
            guard !nonInteractive else {
                throw ValidationError("Private key is required.")
            }
            print("Paste the contents of your App Store Connect private key (.p8). Finish with an empty line:")
            var collected: [String] = []
            while let line = readLine() {
                if line.isEmpty && !collected.isEmpty {
                    break
                }
                collected.append(line)
            }
            let joined = collected.joined(separator: "\n")
            if joined.isEmpty {
                throw ValidationError("No private key provided.")
            }
            return normalisePrivateKey(joined)
        }

        private func normalisePrivateKey(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("-----BEGIN PRIVATE KEY-----") {
                return trimmed
            } else {
                return """
                -----BEGIN PRIVATE KEY-----
                \(trimmed)
                -----END PRIVATE KEY-----
                """
            }
        }

        private func loadPrivateKey(from path: String) throws -> String {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            guard let string = String(data: data, encoding: .utf8) else {
                throw ValidationError("Private key file is not valid UTF-8 text.")
            }
            return normalisePrivateKey(string)
        }

        private func promptForInput(_ prompt: String) -> String {
            while true {
                print("\(prompt): ", terminator: "")
                guard let line = readLine(), !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    print("Value is required.")
                    continue
                }
                return line.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        private func promptOptional(_ prompt: String) -> String? {
            print("\(prompt): ", terminator: "")
            return readLine()?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func promptWithDefault(_ prompt: String, defaultValue: String) -> String {
            while true {
                print("\(prompt) [\(defaultValue)]: ", terminator: "")
                guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    continue
                }
                if line.isEmpty {
                    return defaultValue
                }
                return line
            }
        }
    }

    struct DisableAppStoreConnect: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "disable-app-store-connect",
            abstract: "Remove stored App Store Connect credentials."
        )

        @Option(name: .customLong("workspace"), help: "Workspace or project directory to operate on.")
        var workspacePath: String = "."

        func run() throws {
            let workspaceURL = URL(fileURLWithPath: workspacePath).standardizedFileURL
            try AppStoreConnectConfigurationStore.deleteCredentials(workspaceRoot: workspaceURL)
            print("Removed App Store Connect credentials for workspace \(workspaceURL.path) from the macOS Keychain.")
        }
    }

    struct CacheFrameItAssets: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "cache-frameit-frames",
            abstract: "Download and cache FrameIt device frames for the workspace."
        )

        @Option(name: .customLong("workspace"), help: "Workspace or project directory to operate on.")
        var workspacePath: String = "."

        @Option(name: .customLong("cache-dir"), help: "Target directory for cached FrameIt assets.")
        var cacheDirectory: String?

        @Option(name: .customLong("archive"), parsing: .upToNextOption, help: "Additional archive URL(s) to merge into the cache (e.g. colored device variants).")
        var extraArchives: [String] = []

        @Flag(name: .customLong("force"), help: "Force re-downloading assets even if a cache exists.")
        var force: Bool = false

        @Flag(name: .customLong("verbose"), help: "Enable verbose logging.")
        var verbose: Bool = false

        func run() throws {
            let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true).standardizedFileURL
            let cacheURL = cacheDirectory.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
            let archives = extraArchives.compactMap { string -> URL? in
                if let remote = URL(string: string), remote.scheme?.isEmpty == false {
                    return remote
                } else {
                    return URL(fileURLWithPath: string)
                }
            }

            let preparer = FrameItAssetPreparer(verbose: verbose)
            let location = try preparer.prepareAssets(
                workspaceRoot: workspaceURL,
                cacheOverride: cacheURL,
                force: force,
                additionalArchives: archives
            )
            print("FrameIt assets available at \(location.path)")
        }
    }
}
