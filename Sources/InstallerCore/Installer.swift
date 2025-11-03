import Foundation

// MARK: - Public API

public struct InstallerOptions {
    public var workspace: URL
    public var toolFolder: String
    public var taskName: String
    public var taskDirectoryStrategy: TaskDirectoryStrategy
    public var dryRun: Bool
    public var force: Bool
    public var verbose: Bool
    public var createMiseTask: Bool
    public var rawArguments: [String]

    public init(
        workspace: URL,
        toolFolder: String = "Tools/FramedScreenshots",
        taskName: String = "framed-screenshots",
        taskDirectoryStrategy: TaskDirectoryStrategy = .auto,
        dryRun: Bool = false,
        force: Bool = false,
        verbose: Bool = false,
        createMiseTask: Bool = true,
        rawArguments: [String] = []
    ) {
        self.workspace = workspace
        self.toolFolder = toolFolder
        self.taskName = taskName
        self.taskDirectoryStrategy = taskDirectoryStrategy
        self.dryRun = dryRun
        self.force = force
        self.verbose = verbose
        self.createMiseTask = createMiseTask
        self.rawArguments = rawArguments
    }

    public init(arguments: [String], workingDirectory: URL) throws {
        var workspaceURL = workingDirectory
        var toolFolder = "Tools/FramedScreenshots"
        var taskName = "framed-screenshots"
        var strategy: TaskDirectoryStrategy = .auto
        var dryRun = false
        var force = false
        var verbose = false
        var createMiseTask = true

        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--workspace":
                guard let value = iterator.next() else {
                    throw InstallerError.missingValue(option: "--workspace")
                }
                workspaceURL = InstallerOptions.resolvePath(value, relativeTo: workingDirectory)
            case "--tool-folder":
                guard let value = iterator.next() else {
                    throw InstallerError.missingValue(option: "--tool-folder")
                }
                toolFolder = value
            case "--task-name":
                guard let value = iterator.next() else {
                    throw InstallerError.missingValue(option: "--task-name")
                }
                taskName = value
            case "--task-dir":
                guard let value = iterator.next() else {
                    throw InstallerError.missingValue(option: "--task-dir")
                }
                strategy = value == "auto" ? .auto : .exact(value)
            case "--dry-run":
                dryRun = true
            case "--force":
                force = true
            case "--verbose":
                verbose = true
            case "--no-mise":
                createMiseTask = false
            default:
                continue
            }
        }

        self.init(
            workspace: workspaceURL,
            toolFolder: toolFolder,
            taskName: taskName,
            taskDirectoryStrategy: strategy,
            dryRun: dryRun,
            force: force,
            verbose: verbose,
            createMiseTask: createMiseTask,
            rawArguments: arguments
        )
    }

    private static func resolvePath(_ value: String, relativeTo base: URL) -> URL {
        if (value as NSString).isAbsolutePath {
            return URL(fileURLWithPath: value, isDirectory: true)
        } else {
            return base.appendingPathComponent(value, isDirectory: true)
        }
    }
}

public enum TaskDirectoryStrategy: Equatable {
    case auto
    case exact(String)
}

public struct InstallationReport: CustomStringConvertible {
    public var createdFiles: [URL] = []
    public var updatedFiles: [URL] = []
    public var skippedFiles: [URL] = []
    public var messages: [String] = []

    public init() {}

    public mutating func append(message: String, when verbose: Bool) {
        guard verbose else { return }
        messages.append(message)
    }

    public var description: String {
        var lines: [String] = []
        if !createdFiles.isEmpty {
            let values = createdFiles.map { $0.path }.joined(separator: ", ")
            lines.append("created: \(values)")
        }
        if !updatedFiles.isEmpty {
            let values = updatedFiles.map { $0.path }.joined(separator: ", ")
            lines.append("updated: \(values)")
        }
        if !skippedFiles.isEmpty {
            let values = skippedFiles.map { $0.path }.joined(separator: ", ")
            lines.append("skipped: \(values)")
        }
        lines.append(contentsOf: messages)
        if lines.isEmpty {
            lines.append("FramedScreenshots tool is already up to date.")
        }
        return lines.joined(separator: "\n")
    }
}

public enum InstallerError: Error, CustomStringConvertible {
    case missingValue(option: String)
    case emptyToolFolder
    case failedToCreateDirectory(URL, underlying: Error)
    case failedToWriteFile(URL, underlying: Error)
    case missingTaskDirectory(String)

    public var description: String {
        switch self {
        case .missingValue(let option):
            return "No value provided for option \(option)."
        case .emptyToolFolder:
            return "Tool folder must not be empty."
        case .failedToCreateDirectory(let url, let underlying):
            return "Failed to create directory at \(url.path): \(underlying)"
        case .failedToWriteFile(let url, let underlying):
            return "Failed to write file at \(url.path): \(underlying)"
        case .missingTaskDirectory(let path):
            return "Could not resolve task directory for \(path)."
        }
    }
}

public final class FramedScreenshotsInstaller {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func install(options: InstallerOptions) throws -> InstallationReport {
        var report = InstallationReport()
        let normalizedWorkspace = options.workspace.standardizingFileURL()

        let workspaceRoot = resolveWorkspaceRoot(startingAt: normalizedWorkspace)
        report.append(message: "workspace root: \(workspaceRoot.path)", when: options.verbose)

        let toolLocation = try resolveToolLocation(
            requestedPath: options.toolFolder,
            workspaceRoot: workspaceRoot,
            verbose: options.verbose,
            report: &report
        )

        report.append(
            message: "tool package: \(toolLocation.packageURL.path)",
            when: options.verbose
        )

        let miseTaskResolution = try resolveMiseTaskPath(
            strategy: options.taskDirectoryStrategy,
            taskName: options.taskName,
            workspaceRoot: workspaceRoot,
            verbose: options.verbose,
            report: &report
        )

        var directoriesToEnsure = toolLocation.requiredDirectories
        if let miseDirectory = miseTaskResolution?.directory {
            directoriesToEnsure.append(miseDirectory)
        }

        if !options.dryRun {
            try ensureDirectoriesExist(directoriesToEnsure, verbose: options.verbose, report: &report)
        } else {
            for directory in directoriesToEnsure {
                if !fileManager.itemExists(at: directory) {
                    report.append(message: "(dry-run) would create directory \(directory.path)", when: true)
                }
            }
        }

        let timestamp = Self.backupTimestampFormatter.string(from: Date())

        let filePlans = templatePlans(
            toolLocation: toolLocation,
            miseTask: miseTaskResolution,
            options: options
        )

        for plan in filePlans {
            try apply(plan: plan, timestamp: timestamp, options: options, report: &report)
        }

        return report
    }
}

// MARK: - Private helpers

private extension FramedScreenshotsInstaller {
    struct ToolLocation {
        var requestedPath: String
        var packageURL: URL
        var relativePath: String
        var fallbackApplied: Bool

        var cliSourcesURL: URL {
            packageURL.appendingPathComponent("Sources/FramedScreenshotsCLI", isDirectory: true)
        }

        var kitSourcesURL: URL {
            packageURL.appendingPathComponent("Sources/FramedScreenshotsKit", isDirectory: true)
        }

        var kitResourcesURL: URL {
            kitSourcesURL.appendingPathComponent("Resources", isDirectory: true)
        }

        var kitMarketingResourcesURL: URL {
            kitResourcesURL.appendingPathComponent("Marketing", isDirectory: true)
        }

        var installGuideURL: URL {
            packageURL.appendingPathComponent("INSTALL.md", isDirectory: false)
        }

        var requiredDirectories: [URL] {
            [
                packageURL,
                packageURL.appendingPathComponent("Sources", isDirectory: true),
                cliSourcesURL,
                kitSourcesURL,
                kitResourcesURL,
                kitMarketingResourcesURL
            ]
        }
    }

    struct MiseTaskLocation {
        var directory: URL
        var fileURL: URL
    }

    enum WriteMode {
        case managed
        case createOnce
    }

    struct FilePlan {
        var url: URL
        var contents: String
        var mode: WriteMode
        var makeExecutable: Bool
        var description: String
    }

    func resolveWorkspaceRoot(startingAt url: URL) -> URL {
        var current = url
        if !fileManager.directoryExists(at: current) {
            current.deleteLastPathComponent()
        }

        let initial = current
        while true {
            if containsXcodeContainer(in: current) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path || parent.path.isEmpty {
                return initial
            }
            current = parent
        }
    }

    func containsXcodeContainer(in directory: URL) -> Bool {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return false
        }
        return contents.contains { $0.hasSuffix(".xcworkspace") || $0.hasSuffix(".xcodeproj") }
    }

    func resolveToolLocation(
        requestedPath: String,
        workspaceRoot: URL,
        verbose: Bool,
        report: inout InstallationReport
    ) throws -> ToolLocation {
        guard !requestedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw InstallerError.emptyToolFolder
        }

        let normalized = requestedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if (normalized as NSString).isAbsolutePath {
            let url = URL(fileURLWithPath: normalized, isDirectory: true).standardizingFileURL()
            let relative = url.relativePath(from: workspaceRoot) ?? url.path
            return ToolLocation(
                requestedPath: normalized,
                packageURL: url,
                relativePath: relative,
                fallbackApplied: false
            )
        }

        var finalRelativePath = normalized
        var fallbackApplied = false

        if normalized.hasPrefix("Tools/") {
            let toolsRoot = workspaceRoot.appendingPathComponent("Tools", isDirectory: true)
            if !fileManager.directoryExists(at: toolsRoot) {
                finalRelativePath = "FramedScreenshots"
                fallbackApplied = true
                report.append(
                    message: "Tools/ directory missing. Falling back to workspace-local path \(finalRelativePath).",
                    when: verbose
                )
            }
        }

        let absolute = workspaceRoot.appendingPathComponent(finalRelativePath, isDirectory: true).standardizingFileURL()

        return ToolLocation(
            requestedPath: normalized,
            packageURL: absolute,
            relativePath: finalRelativePath,
            fallbackApplied: fallbackApplied
        )
    }

    func resolveMiseTaskPath(
        strategy: TaskDirectoryStrategy,
        taskName: String,
        workspaceRoot: URL,
        verbose: Bool,
        report: inout InstallationReport
    ) throws -> MiseTaskLocation? {
        switch strategy {
        case .auto:
            let candidateRelativePaths = [
                "mise-tasks",
                ".mise/tasks",
                "mise/tasks",
                ".config/mise/tasks"
            ]
            for candidate in candidateRelativePaths {
                let directory = workspaceRoot.appendingPathComponent(candidate, isDirectory: true)
                if fileManager.directoryExists(at: directory) {
                    let fileURL = directory.appendingPathComponent(taskName, isDirectory: false)
                    report.append(
                        message: "mise task directory detected at \(directory.path).",
                        when: verbose
                    )
                    return MiseTaskLocation(directory: directory, fileURL: fileURL)
                }
            }
            let fallbackDirectory = workspaceRoot.appendingPathComponent(".mise/tasks", isDirectory: true)
            report.append(
                message: "No existing mise task directory found. Will create \(fallbackDirectory.path).",
                when: verbose
            )
            return MiseTaskLocation(
                directory: fallbackDirectory,
                fileURL: fallbackDirectory.appendingPathComponent(taskName, isDirectory: false)
            )
        case .exact(let path):
            let resolved: URL
            if (path as NSString).isAbsolutePath {
                resolved = URL(fileURLWithPath: path, isDirectory: true).standardizingFileURL()
            } else {
                resolved = workspaceRoot.appendingPathComponent(path, isDirectory: true).standardizingFileURL()
            }
            report.append(
                message: "mise task directory set to \(resolved.path).",
                when: verbose
            )
            return MiseTaskLocation(
                directory: resolved,
                fileURL: resolved.appendingPathComponent(taskName, isDirectory: false)
            )
        }
    }

    func ensureDirectoriesExist(
        _ directories: [URL],
        verbose: Bool,
        report: inout InstallationReport
    ) throws {
        for directory in directories {
            if fileManager.directoryExists(at: directory) {
                continue
            }
            do {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                report.append(message: "created directory \(directory.path)", when: verbose)
            } catch {
                throw InstallerError.failedToCreateDirectory(directory, underlying: error)
            }
        }
    }

    func templatePlans(
        toolLocation: ToolLocation,
        miseTask: MiseTaskLocation?,
        options: InstallerOptions
    ) -> [FilePlan] {
        var plans: [FilePlan] = []

        plans.append(
            FilePlan(
                url: toolLocation.packageURL.appendingPathComponent("Package.swift"),
                contents: TemplateFactory.packageSwiftContents(),
                mode: .managed,
                makeExecutable: false,
                description: "Package.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.cliSourcesURL.appendingPathComponent("main.swift"),
                contents: TemplateFactory.cliMainContents(),
                mode: .managed,
                makeExecutable: false,
                description: "CLI main.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.cliSourcesURL.appendingPathComponent("LocalizationMatrix.swift"),
                contents: TemplateFactory.localizationMatrixContents(),
                mode: .managed,
                makeExecutable: false,
                description: "LocalizationMatrix.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.cliSourcesURL.appendingPathComponent("FrameItManager.swift"),
                contents: TemplateFactory.frameItManagerContents(),
                mode: .managed,
                makeExecutable: false,
                description: "FrameItManager.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.cliSourcesURL.appendingPathComponent("AppStoreConnectUploader.swift"),
                contents: TemplateFactory.appStoreConnectUploaderContents(),
                mode: .managed,
                makeExecutable: false,
                description: "AppStoreConnectUploader.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("ScreenshotRegistry.swift"),
                contents: TemplateFactory.screenshotRegistryContents(),
                mode: .managed,
                makeExecutable: false,
                description: "ScreenshotRegistry.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("ScreenshotLibrary.swift"),
                contents: TemplateFactory.screenshotLibraryContents(),
                mode: .managed,
                makeExecutable: false,
                description: "ScreenshotLibrary.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("FocusedScreenshotOverlay.swift"),
                contents: TemplateFactory.focusedOverlayContents(),
                mode: .managed,
                makeExecutable: false,
                description: "FocusedScreenshotOverlay.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("HeroText.swift"),
                contents: TemplateFactory.heroTextContents(),
                mode: .managed,
                makeExecutable: false,
                description: "HeroText.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("MarketingBadge.swift"),
                contents: TemplateFactory.marketingBadgeContents(),
                mode: .managed,
                makeExecutable: false,
                description: "MarketingBadge.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitMarketingResourcesURL.appendingPathComponent("LaurelBranchLeft.svg"),
                contents: TemplateFactory.laurelBranchSVGContents(),
                mode: .managed,
                makeExecutable: false,
                description: "Marketing Laurel SVG"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("HighlightsText.swift"),
                contents: TemplateFactory.highlightsTextContents(),
                mode: .managed,
                makeExecutable: false,
                description: "HighlightsText.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("DesignPreviews.swift"),
                contents: TemplateFactory.designPreviewsContents(),
                mode: .managed,
                makeExecutable: false,
                description: "DesignPreviews.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("ViewPNGWriter.swift"),
                contents: TemplateFactory.viewPNGWriterContents(),
                mode: .managed,
                makeExecutable: false,
                description: "ViewPNGWriter.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("GeneratedCatalog.swift"),
                contents: TemplateFactory.generatedCatalogContents(),
                mode: .managed,
                makeExecutable: false,
                description: "GeneratedCatalog.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.kitSourcesURL.appendingPathComponent("FramedScreenshotsCatalog.swift"),
                contents: TemplateFactory.catalogStubContents(),
                mode: .createOnce,
                makeExecutable: false,
                description: "FramedScreenshotsCatalog.swift"
            )
        )

        plans.append(
            FilePlan(
                url: toolLocation.installGuideURL,
                contents: TemplateFactory.installGuideContents(
                    relativeToolPath: toolLocation.relativePath,
                    taskName: options.taskName
                ),
                mode: .managed,
                makeExecutable: false,
                description: "INSTALL.md"
            )
        )

        if options.createMiseTask, let miseTask {
            plans.append(
                FilePlan(
                    url: miseTask.fileURL,
                    contents: TemplateFactory.miseTaskContents(
                        taskName: options.taskName,
                        preferredToolPath: toolLocation.relativePath
                    ),
                    mode: .managed,
                    makeExecutable: true,
                    description: "mise task \(options.taskName)"
                )
            )
        }

        return plans
    }


    func apply(
        plan: FilePlan,
        timestamp: String,
        options: InstallerOptions,
        report: inout InstallationReport
    ) throws {
        let exists = fileManager.fileExists(atPath: plan.url.path)

        if !exists {
            if options.dryRun {
                report.append(message: "(dry-run) would create \(plan.url.path)", when: true)
                report.createdFiles.append(plan.url)
                return
            }
            try write(plan.contents, to: plan.url, executable: plan.makeExecutable)
            report.createdFiles.append(plan.url)
            return
        }

        guard let existingData = fileManager.contents(atPath: plan.url.path),
              let existingString = String(data: existingData, encoding: .utf8)
        else {
            if options.dryRun {
                report.append(message: "(dry-run) would update \(plan.url.path)", when: true)
                report.updatedFiles.append(plan.url)
                return
            }
            try write(plan.contents, to: plan.url, executable: plan.makeExecutable)
            report.updatedFiles.append(plan.url)
            return
        }

        if existingString == plan.contents {
            report.skippedFiles.append(plan.url)
            return
        }

        if !existingString.contains(TemplateFactory.markerStart) || !existingString.contains(TemplateFactory.markerEnd) {
            if plan.mode == .createOnce && !options.force {
                report.skippedFiles.append(plan.url)
                return
            }
            try backupIfNeeded(originalContent: existingString, url: plan.url, timestamp: timestamp, dryRun: options.dryRun)
        }

        if plan.mode == .createOnce && !options.force {
            report.skippedFiles.append(plan.url)
            return
        }

        if options.dryRun {
            report.append(message: "(dry-run) would update \(plan.url.path)", when: true)
            report.updatedFiles.append(plan.url)
            return
        }

        try write(plan.contents, to: plan.url, executable: plan.makeExecutable)
        report.updatedFiles.append(plan.url)
    }

    func write(_ contents: String, to url: URL, executable: Bool) throws {
        do {
            try contents.data(using: .utf8)?.write(to: url, options: .atomic)
            if executable {
                try fileManager.setAttributes([.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: url.path)
            }
        } catch {
            throw InstallerError.failedToWriteFile(url, underlying: error)
        }
    }

    func backupIfNeeded(originalContent: String, url: URL, timestamp: String, dryRun: Bool) throws {
        if originalContent.contains(TemplateFactory.markerStart) && originalContent.contains(TemplateFactory.markerEnd) {
            return
        }

        let directory = url.deletingLastPathComponent()
        let baseName = url.lastPathComponent
        let backupName = "\(baseName).bak.\(timestamp)"
        let backupURL = directory.appendingPathComponent(backupName)

        if fileManager.fileExists(atPath: backupURL.path) {
            return
        }

        if dryRun {
            return
        }

        try fileManager.copyItem(at: url, to: backupURL)
    }

    static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - Template Factory

enum TemplateFactory {
    static let markerStart = "// BEGIN GENERATED BY FramedScreenshotsTool"
    static let markerEnd = "// END GENERATED BY FramedScreenshotsTool"

    static func packageSwiftContents() -> String {
        """
// swift-tools-version: 6.2
\(markerStart)
import PackageDescription

let package = Package(
    name: "FramedScreenshots",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "FramedScreenshotsKit",
            targets: ["FramedScreenshotsKit"]
        ),
        .executable(
            name: "framed-screenshots",
            targets: ["FramedScreenshotsCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.2"),
        .package(url: "https://github.com/AvdLee/appstoreconnect-swift-sdk.git", from: "2.3.0")
    ],
    targets: [
        .target(
            name: "FramedScreenshotsKit",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "FramedScreenshotsCLI",
            dependencies: [
                "FramedScreenshotsKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "AppStoreConnect-Swift-SDK", package: "appstoreconnect-swift-sdk")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"], .when(configuration: .debug)),
                .unsafeFlags(["-parse-as-library"], .when(configuration: .release))
            ]
        )
    ]
)
\(markerEnd)
"""
    }

    static func cliMainContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsCLI/main.swift"))
    }

    static func localizationMatrixContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsCLI/LocalizationMatrix.swift"))
    }

    static func frameItManagerContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsCLI/FrameItManager.swift"))
    }

    static func appStoreConnectUploaderContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsCLI/AppStoreConnectUploader.swift"))
    }

    static func screenshotRegistryContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/ScreenshotRegistry.swift"))
    }

    static func screenshotLibraryContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/ScreenshotLibrary.swift"))
    }

    static func focusedOverlayContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/FocusedScreenshotOverlay.swift"))
    }

    static func heroTextContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/HeroText.swift"))
    }

    static func marketingBadgeContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/MarketingBadge.swift"))
    }

    static func laurelBranchSVGContents() -> String {
        loadTemplate("FramedScreenshotsKit/Resources/Marketing/LaurelBranchLeft.svg")
    }

    static func highlightsTextContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/HighlightsText.swift"))
    }

    static func designPreviewsContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/DesignPreviews.swift"))
    }

    static func viewPNGWriterContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/ViewPNGWriter.swift"))
    }

    static func generatedCatalogContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/GeneratedCatalog.swift"))
    }

    static func catalogStubContents() -> String {
        replaceMarkers(in: loadTemplate("FramedScreenshotsKit/FramedScreenshotsCatalog.swift"))
    }

    static func installGuideContents(
        relativeToolPath: String,
        taskName: String
    ) -> String {
        replaceMarkers(
            in: loadTemplate("Docs/INSTALL.md"),
            replacements: [
                "RELATIVE_TOOL_PATH": relativeToolPath,
                "TASK_NAME": taskName
            ]
        )
    }

    static func miseTaskContents(
        taskName: String,
        preferredToolPath: String
    ) -> String {
        replaceMarkers(
            in: loadTemplate("Scripts/mise-task.sh"),
            replacements: [
                "TASK_NAME": taskName,
                "PREFERRED_TOOL_PATH": preferredToolPath
            ]
        )
    }

    private static func loadTemplate(_ relativePath: String) -> String {
        let url = TemplateSourceLocator.root.appendingPathComponent(relativePath)
        do {
            return try String(contentsOf: url)
        } catch {
            fatalError("Missing template at \(" + url.path + ")\nError: \(error)")
        }
    }

    private static func replaceMarkers(in template: String, replacements: [String: String] = [:]) -> String {
        var output = template.replacingOccurrences(of: "{{MARKER_START}}", with: markerStart)
        output = output.replacingOccurrences(of: "{{MARKER_END}}", with: markerEnd)
        output = output.replacingOccurrences(of: "#if !TEMPLATE_BUILD\n", with: "")
        output = output.replacingOccurrences(of: "#if !TEMPLATE_BUILD\r\n", with: "")
        output = output.replacingOccurrences(of: "#if !TEMPLATE_BUILD", with: "")
        for (key, value) in replacements {
            output = output.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return output
    }
}

private enum TemplateSourceLocator {
    static let root: URL = {
        var url = URL(fileURLWithPath: #filePath)
        // Walk up to package root (containing Package.swift)
        while url.lastPathComponent != "Vendor" && url.lastPathComponent != "Sources" {
            url.deleteLastPathComponent()
        }
        while url.lastPathComponent != "Sources" {
            url.deleteLastPathComponent()
        }
        url.deleteLastPathComponent() // -> package root
        return url.appendingPathComponent("TemplateSources", isDirectory: true)
    }()
}

// MARK: - FileManager utilities

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }

    func itemExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }
}

// MARK: - URL utilities

private extension URL {
    func standardizingFileURL() -> URL {
        standardizedFileURL
    }

    func relativePath(from base: URL) -> String? {
        let standardBase = base.standardizedFileURL
        let standardSelf = standardizedFileURL
        let baseComponents = standardBase.pathComponents
        let selfComponents = standardSelf.pathComponents

        var index = 0
        while index < baseComponents.count &&
            index < selfComponents.count &&
            baseComponents[index] == selfComponents[index] {
                index += 1
        }

        guard index != 0 else {
            return nil
        }

        var relativeComponents: [String] = []
        let remainingBase = baseComponents.count - index
        if remainingBase > 0 {
            relativeComponents.append(contentsOf: Array(repeating: "..", count: remainingBase))
        }
        relativeComponents.append(contentsOf: selfComponents[index...])
        return NSString.path(withComponents: relativeComponents)
    }
}
