import AppKit
import XCTest
@testable import InstallerCore

final class InstallerCoreTests: XCTestCase {
    private let fileManager = FileManager.default

    func testInstallCreatesWorkspacePackageAndIsIdempotent() throws {
        let workspace = try makeTemporaryWorkspace()
        defer { try? fileManager.removeItem(at: workspace) }

        let installer = FramedScreenshotsInstaller(fileManager: fileManager)
        let firstReport = try installer.install(options: InstallerOptions(workspace: workspace))

        let packageURL = workspace.appendingPathComponent("Tools/FramedScreenshots/Package.swift")
        let cliURL = workspace.appendingPathComponent("Tools/FramedScreenshots/Sources/FramedScreenshotsCLI/main.swift")
        let miseScript = workspace.appendingPathComponent(".mise/tasks/framed-screenshots")

        XCTAssertTrue(fileManager.fileExists(atPath: packageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: cliURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: miseScript.path))
        XCTAssertFalse(firstReport.createdFiles.isEmpty)

        let secondReport = try installer.install(options: InstallerOptions(workspace: workspace))
        XCTAssertTrue(secondReport.createdFiles.isEmpty)
        XCTAssertTrue(secondReport.updatedFiles.isEmpty)
        XCTAssertFalse(secondReport.skippedFiles.isEmpty)

        let packageContents = try String(contentsOf: packageURL)
        XCTAssertTrue(packageContents.contains(TemplateFactory.markerStart))
        XCTAssertTrue(packageContents.contains(TemplateFactory.markerEnd))
    }

    func testCreateOnceFileRespectsForce() throws {
        let workspace = try makeTemporaryWorkspace()
        defer { try? fileManager.removeItem(at: workspace) }

        let installer = FramedScreenshotsInstaller(fileManager: fileManager)
        _ = try installer.install(options: InstallerOptions(workspace: workspace))

        let catalogURL = workspace.appendingPathComponent("Tools/FramedScreenshots/Sources/FramedScreenshotsKit/FramedScreenshotsCatalog.swift")
        var catalog = try String(contentsOf: catalogURL)
        catalog.append("\n    // user customization\n")
        try catalog.write(to: catalogURL, atomically: true, encoding: .utf8)

        let secondReport = try installer.install(options: InstallerOptions(workspace: workspace))
        XCTAssertTrue(secondReport.updatedFiles.isEmpty)

        _ = try installer.install(options: InstallerOptions(workspace: workspace, force: true))
        let restored = try String(contentsOf: catalogURL)
        XCTAssertEqual(restored, TemplateFactory.catalogStubContents())
    }

    func testDryRunDoesNotWriteFiles() throws {
        let workspace = try makeTemporaryWorkspace(createTools: false)
        defer { try? fileManager.removeItem(at: workspace) }

        let installer = FramedScreenshotsInstaller(fileManager: fileManager)
        let report = try installer.install(
            options: InstallerOptions(
                workspace: workspace,
                dryRun: true,
                createMiseTask: false
            )
        )

        let packageURL = workspace.appendingPathComponent("FramedScreenshots/Package.swift")
        XCTAssertFalse(fileManager.fileExists(atPath: packageURL.path))
        XCTAssertFalse(report.createdFiles.isEmpty)
    }

    func testFocusedElementExtractorDetectsBorder() throws {
        let focusRect = CGRect(x: 150, y: 350, width: 300, height: 320)
        let image = try makeSyntheticScreenshot(
            size: CGSize(width: 600, height: 1200),
            borderColor: NSColor.systemPink,
            borderWidth: 12,
            focusRect: focusRect
        )

        let extractor = FocusedElementExtractor()
        let configuration = FocusExtractionConfiguration(
            screenshotName: "Synthetic",
            borderColor: NSColor.systemPink,
            tolerance: 0.1,
            zoomScale: 1.2
        )

        guard let result = extractor.extract(configuration: configuration, image: image) else {
            XCTFail("Expected focus extraction to succeed")
            return
        }
        XCTAssertGreaterThan(result.overlayImage.size.width, 0)
        XCTAssertGreaterThan(result.overlayImage.size.height, 0)
        let boundingBox = result.maskPath.boundingBox
        XCTAssertEqual(boundingBox.width, focusRect.width, accuracy: 30)
        XCTAssertEqual(boundingBox.height, focusRect.height, accuracy: 30)
        XCTAssertEqual(result.normalizedCentroid.x, 0.5, accuracy: 0.1)
        XCTAssertEqual(result.normalizedCentroid.y, 0.5, accuracy: 0.1)
    }

    func testFrameItAssetPreparerDownloadsAndMergesArchives() throws {
        let workspace = try makeTemporaryWorkspace()
        defer { try? fileManager.removeItem(at: workspace) }

        let cacheRoot = workspace.appendingPathComponent("FrameCache", isDirectory: true)

        let baseArchive = try makeFrameItArchive(
            within: workspace,
            files: [
                "frames/base.png": Data("base".utf8)
            ]
        )
        defer { try? fileManager.removeItem(at: baseArchive.scratchRoot) }

        let extraPNG = workspace.appendingPathComponent("cosmic.png")
        try Data("cosmic".utf8).write(to: extraPNG)

        let extraArchive = try makeFrameItArchive(
            within: workspace,
            files: [
                "Colored/zip-device.png": Data("zip".utf8)
            ]
        )
        defer { try? fileManager.removeItem(at: extraArchive.scratchRoot) }

        let preparer = FrameItAssetPreparer(
            fileManager: fileManager,
            verbose: true,
            session: .shared,
            primaryArchiveURL: baseArchive.archive
        )

        let framesDirectory = try preparer.prepareAssets(
            workspaceRoot: workspace,
            cacheOverride: cacheRoot,
            force: true,
            additionalArchives: [extraPNG, extraArchive.archive]
        )

        XCTAssertTrue(fileManager.fileExists(atPath: framesDirectory.path))

        let baseFrame = framesDirectory.appendingPathComponent("frames/base.png")
        XCTAssertTrue(fileManager.fileExists(atPath: baseFrame.path))

        let coloredDirect = framesDirectory.appendingPathComponent("Colored/cosmic.png")
        XCTAssertTrue(fileManager.fileExists(atPath: coloredDirect.path))

        let coloredZip = framesDirectory.appendingPathComponent("Colored/zip-device.png")
        XCTAssertTrue(fileManager.fileExists(atPath: coloredZip.path))
    }

    private func makeTemporaryWorkspace(createTools: Bool = true) throws -> URL {
        let tempDirectory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        if createTools {
            try fileManager.createDirectory(at: tempDirectory.appendingPathComponent("Tools", isDirectory: true), withIntermediateDirectories: true)
        }

        // Create a dummy Xcode project folder so installer resolves workspace root.
        try fileManager.createDirectory(at: tempDirectory.appendingPathComponent("SampleApp.xcodeproj", isDirectory: true), withIntermediateDirectories: true)

        return tempDirectory
    }

    private func makeSyntheticScreenshot(size: CGSize, borderColor: NSColor, borderWidth: CGFloat, focusRect: CGRect) throws -> NSImage {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw XCTSkip("Unable to allocate bitmap")
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context

            NSColor(calibratedWhite: 0.1, alpha: 1).setFill()
            NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

            NSColor(calibratedWhite: 0.2, alpha: 1).setFill()
            NSBezierPath(rect: focusRect.insetBy(dx: -40, dy: -40)).fill()

            borderColor.setStroke()
            let path = NSBezierPath(rect: focusRect)
            path.lineWidth = borderWidth
            path.stroke()

            NSColor.white.setFill()
            NSBezierPath(rect: focusRect.insetBy(dx: borderWidth, dy: borderWidth)).fill()
        } else {
            throw XCTSkip("Unable to create graphics context")
        }

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    private func makeFrameItArchive(within directory: URL, files: [String: Data]) throws -> (archive: URL, scratchRoot: URL) {
        let scratchRoot = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: scratchRoot, withIntermediateDirectories: true)

        let rootDirectoryName = "frameit-frames-master"
        let rootDirectory = scratchRoot.appendingPathComponent(rootDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        for (relativePath, data) in files {
            let fileURL = rootDirectory.appendingPathComponent(relativePath)
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL)
        }

        let archiveURL = scratchRoot.appendingPathComponent("archive.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.currentDirectoryURL = scratchRoot
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", rootDirectoryName, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw XCTSkip("Failed to create zip archive")
        }

        let verify = Process()
        verify.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        verify.currentDirectoryURL = scratchRoot
        verify.arguments = ["-tq", archiveURL.path]
        try verify.run()
        verify.waitUntilExit()
        if verify.terminationStatus != 0 {
            throw XCTSkip("Failed to verify zip archive")
        }

        return (archive: archiveURL, scratchRoot: scratchRoot)
    }
}
