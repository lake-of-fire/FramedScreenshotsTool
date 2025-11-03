import XCTest
@testable import InstallerCore

final class ExampleEndToEndTests: XCTestCase {
    private let fileManager = FileManager.default

    func testWorkspaceInstallIsIdempotentAndRenders() throws {
        try runScenario(
            name: "workspace",
            containerSetup: createWorkspaceContainer
        )
    }

    func testProjectInstallIsIdempotentAndRenders() throws {
        try runScenario(
            name: "project",
            containerSetup: createProjectContainer
        )
    }

    private func runScenario(
        name: String,
        containerSetup: (URL) throws -> Void
    ) throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let exampleSource = root.appendingPathComponent("Examples/FramedScreenshotsDemo", isDirectory: true)
        guard fileManager.directoryExists(at: exampleSource) else {
            throw XCTSkip("Example workspace not found at \(exampleSource.path)")
        }

        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let exampleWorkspace = tempRoot.appendingPathComponent("FramedScreenshotsDemo-\(name)", isDirectory: true)
        try fileManager.copyItem(at: exampleSource, to: exampleWorkspace)
        try containerSetup(exampleWorkspace)

        let toolBuildPath = root.appendingPathComponent(".build/e2e-tool-\(name)", isDirectory: true)
        let exampleBuildPath = root.appendingPathComponent(".build/e2e-example-\(name)", isDirectory: true)
        try fileManager.createDirectory(at: toolBuildPath, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exampleBuildPath, withIntermediateDirectories: true)

        let installArguments: [String] = [
            "run",
            "--package-path", root.path,
            "--build-path", toolBuildPath.path,
            "framed-screenshots-tool",
            "install-framed-screenshots-tool",
            "--workspace", exampleWorkspace.path
        ]

        let installer = ProcessRunner(
            executable: "swift",
            arguments: installArguments,
            workingDirectory: exampleWorkspace
        )
        let firstRun = try installer.run(captureOutput: true)
        XCTAssertTrue(
            firstRun.stdout.contains("created:"),
            "Expected installer to create files on first run."
        )

        let applyScript = ProcessRunner(
            executable: "swift",
            arguments: [
                exampleWorkspace.appendingPathComponent("Scripts/apply_demo_catalog.swift").path,
                "--tool-path",
                exampleWorkspace.appendingPathComponent("Tools/FramedScreenshots").path
            ],
            workingDirectory: exampleWorkspace
        )
        try applyScript.run()

        let packageURL = exampleWorkspace
            .appendingPathComponent("Tools/FramedScreenshots/Package.swift")
        let packageBefore = try Data(contentsOf: packageURL)

        let reinstaller = ProcessRunner(
            executable: "swift",
            arguments: installArguments,
            workingDirectory: exampleWorkspace
        )
        let secondRun = try reinstaller.run(captureOutput: true)
        XCTAssertFalse(secondRun.stdout.contains("created:"), "Second install should not recreate files.")
        XCTAssertFalse(secondRun.stdout.contains("updated:"), "Second install should not rewrite files.")

        let packageAfter = try Data(contentsOf: packageURL)
        XCTAssertEqual(packageBefore, packageAfter, "Package manifest should remain unchanged on reinstall.")

        let extrasDirectory = exampleWorkspace.appendingPathComponent("FrameItExtras", isDirectory: true)
        try fileManager.createDirectory(at: extrasDirectory, withIntermediateDirectories: true)
        let cosmicFrame = extrasDirectory.appendingPathComponent("cosmic-orange.png")
        try Data("frame".utf8).write(to: cosmicFrame)

        try seedFrameCacheIfNeeded(at: exampleWorkspace)

        let outputDirectory = exampleWorkspace.appendingPathComponent(".build/screenshots-\(name)", isDirectory: true)
        let renderArguments: [String] = [
            "run",
            "--package-path",
            exampleWorkspace.appendingPathComponent("Tools/FramedScreenshots").path,
            "--build-path",
            exampleBuildPath.path,
            "framed-screenshots",
            "--workspace",
            exampleWorkspace.path,
            "--frame-archive",
            cosmicFrame.path,
            "--out",
            outputDirectory.path,
            "--verbose"
        ]

        let renderer = ProcessRunner(
            executable: "swift",
            arguments: renderArguments,
            workingDirectory: exampleWorkspace
        )
        try renderer.run()

        let localeDirectory = outputDirectory.appendingPathComponent("en", isDirectory: true)
        XCTAssertTrue(
            fileManager.directoryExists(at: localeDirectory),
            "Expected output directory for localization 'en'."
        )

        let expectedFiles = [
            "iphone-hero-en.png",
            "ipad-spotlight-en.png",
            "mac-focus-en.png"
        ]

        for file in expectedFiles {
            let url = localeDirectory.appendingPathComponent(file)
            XCTAssertTrue(fileManager.fileExists(atPath: url.path), "Missing rendered screenshot: \(file)")
            if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? NSNumber {
                XCTAssertGreaterThan(size.intValue, 1024, "Screenshot file appears empty: \(file)")
            }
        }

        let coloredFrame = exampleWorkspace
            .appendingPathComponent("Tools/FrameItCache/frameit-frames-master/Colored/cosmic-orange.png")
        XCTAssertTrue(
            fileManager.fileExists(atPath: coloredFrame.path),
            "Expected custom frame archive to be ingested."
        )

        let reportFile = outputDirectory.appendingPathComponent("framed-screenshots-report.html")
        XCTAssertTrue(
            fileManager.fileExists(atPath: reportFile.path),
            "Expected report to be generated at \(reportFile.path)"
        )
    }

    private func seedFrameCacheIfNeeded(at workspace: URL) throws {
        let cacheRoot = workspace
            .appendingPathComponent("Tools/FrameItCache/frameit-frames-master", isDirectory: true)
        if fileManager.directoryExists(at: cacheRoot) {
            return
        }
        let deviceDir = cacheRoot.appendingPathComponent("iphone", isDirectory: true)
        try fileManager.createDirectory(at: deviceDir, withIntermediateDirectories: true)
        let placeholder = deviceDir.appendingPathComponent("placeholder.txt")
        try Data("frame".utf8).write(to: placeholder)

        let coloredDir = cacheRoot.appendingPathComponent("Colored", isDirectory: true)
        try fileManager.createDirectory(at: coloredDir, withIntermediateDirectories: true)
        let cosmicSource = workspace.appendingPathComponent("FrameItExtras/cosmic-orange.png")
        let cosmicDestination = coloredDir.appendingPathComponent("cosmic-orange.png")
        if fileManager.fileExists(atPath: cosmicSource.path) {
            if fileManager.fileExists(atPath: cosmicDestination.path) {
                try fileManager.removeItem(at: cosmicDestination)
            }
            try fileManager.copyItem(at: cosmicSource, to: cosmicDestination)
        }
    }

    private func createWorkspaceContainer(at root: URL) throws {
        let workspaceDir = root.appendingPathComponent("DemoApp.xcworkspace", isDirectory: true)
        try fileManager.createDirectory(at: workspaceDir, withIntermediateDirectories: true)
        let contents = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace
           version = "1.0">
        </Workspace>
        """
        try contents.write(
            to: workspaceDir.appendingPathComponent("contents.xcworkspacedata"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func createProjectContainer(at root: URL) throws {
        let projectDir = root.appendingPathComponent("DemoApp.xcodeproj", isDirectory: true)
        try fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let pbxproj = """
        // !$*UTF8*$!
        {
            archiveVersion = 1;
            classes = {};
            objectVersion = 58;
            objects = {};
            rootObject = 000000000000000000000000;
        }
        """
        try pbxproj.write(
            to: projectDir.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
    }
}

struct ProcessOutput {
    var stdout: String
    var stderr: String
}

private struct ProcessRunner {
    var executable: String
    var arguments: [String]
    var workingDirectory: URL?

    @discardableResult
    func run(captureOutput: Bool = false) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolveExecutable(executable))
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let stdoutPipe: Pipe?
        let stderrPipe: Pipe?
        if captureOutput {
            let out = Pipe()
            let err = Pipe()
            stdoutPipe = out
            stderrPipe = err
            process.standardOutput = out
            process.standardError = err
        } else {
            stdoutPipe = nil
            stderrPipe = nil
            process.standardOutput = FileHandle.standardOutput
            process.standardError = FileHandle.standardError
        }

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ProcessRunner",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Command failed: \(executable) \(arguments.joined(separator: " "))"]
            )
        }

        let stdoutData = stdoutPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        let stderrData = stderrPipe?.fileHandleForReading.readDataToEndOfFile() ?? Data()
        return ProcessOutput(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    private func resolveExecutable(_ path: String) -> String {
        if path.hasPrefix("/") {
            return path
        }
        if let which = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":") {
            for component in which {
                let candidate = URL(fileURLWithPath: String(component), isDirectory: true)
                    .appendingPathComponent(path)
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    return candidate.path
                }
            }
        }
        return path
    }
}

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }
}
