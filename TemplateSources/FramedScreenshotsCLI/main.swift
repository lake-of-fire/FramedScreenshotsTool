import ArgumentParser
import Foundation
import FramedScreenshotsKit
import ImageIO

{{MARKER_START}}
struct FramedScreenshotsCommand: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "framed-screenshots",
        abstract: "List, render, and upload App Store screenshots using FramedScreenshotsKit."
    )

    @Flag(name: .customLong("list"), help: "List registered screenshots and detected localizations.")
    var listOnly: Bool = false

    @Option(name: .customLong("out"), help: "Destination directory for rendered PNG files.")
    var outputDirectory: String?

    @Option(name: .customLong("workspace"), help: "Workspace or project directory to inspect.")
    var workspacePath: String = FileManager.default.currentDirectoryPath

    @Option(name: .customLong("localizations"), parsing: .upToNextOption, help: "Comma separated localization identifiers or 'auto'.")
    var localizationArguments: [String] = []

    @Option(name: .customLong("filter"), parsing: .upToNextOption, help: "Glob filters to restrict screenshot identifiers.")
    var filters: [String] = []

    @Option(name: .customLong("screenshot-dir"), parsing: .upToNextOption, help: "Additional directories to search for raw screenshots.")
    var screenshotDirectories: [String] = []

    @Option(name: .customLong("simulator"), help: "Simulator device name to use when capturing UI tests.")
    var simulatorIdentifier: String?

    @Option(name: .customLong("ui-test-plan"), help: "UI test plan or scheme to execute when capturing screenshots.")
    var uiTestPlan: String?

    @Flag(name: .customLong("skip-capture"), help: "Skip UI-test based screenshot capture.")
    var skipCapture: Bool = false

    @Flag(name: .customLong("skip-upload"), help: "Skip App Store Connect upload stage.")
    var skipUpload: Bool = false

    @Option(name: .customLong("frameit-cache"), help: "Override cache directory for FrameIt assets.")
    var frameItCache: String?

    @Option(name: .customLong("frame-archive"), parsing: .upToNextOption, help: "Additional FrameIt archive or image URLs to merge (repeatable).")
    var frameArchivePaths: [String] = []

    @Option(name: .customLong("ui-test-arg"), parsing: .upToNextOption, help: "Additional arguments to pass to xcodebuild test.")
    var uiTestArguments: [String] = []

    @Flag(name: .customLong("verbose"), help: "Enable verbose logging.")
    var verbose: Bool = false

    mutating func run() async throws {
        let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
        var registry = ScreenshotRegistry()
        ScreenshotCatalogBuilder.build(into: &registry)
        let entries = registry.entries(matching: filters)

        let additionalPaths = screenshotDirectories.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let matrix = LocalizationMatrix(
            workspaceRoot: workspaceURL,
            additionalScreenshotPaths: additionalPaths,
            verbose: verbose
        )
        let localizations = try matrix.resolveLocalizations(arguments: localizationArguments)

        if listOnly {
            matrix.describe(localizations: localizations, entries: entries)
            return
        }

        guard let outputDirectory else {
            Diagnostics.warn("No --out directory specified. Nothing to render.")
            return
        }
        let destination = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        try matrix.captureIfNeeded(
            localizations: localizations,
            skipCapture: skipCapture,
            simulator: simulatorIdentifier,
            uiTestPlan: uiTestPlan,
            extraArguments: uiTestArguments
        )

        let frameArchives = frameArchivePaths
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { string -> URL? in
                if let remote = URL(string: string), remote.scheme?.isEmpty == false {
                    return remote
                }
                if string.contains("://"),
                   let encoded = string.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
                   let remote = URL(string: encoded),
                   remote.scheme?.isEmpty == false {
                    return remote
                }
                return URL(fileURLWithPath: string)
            }

        let frameManager = FrameItManager(
            cacheDirectory: frameItCache.map { URL(fileURLWithPath: $0, isDirectory: true) },
            workspaceRoot: workspaceURL,
            additionalArchives: frameArchives,
            verbose: verbose
        )
        try frameManager.ensureAssets()

        let searchPaths = matrix.screenshotSearchPaths(for: localizations)
        try await matrix.render(
            entries: entries,
            localizations: localizations,
            destination: destination,
            searchPaths: searchPaths
        )

        let reportURL = try generateReport(destinationRoot: destination, localizations: localizations)
        if verbose {
            Diagnostics.info("Screenshot report generated at \(reportURL.path)")
        }

        if skipUpload {
            if verbose { Diagnostics.info("Skipping App Store Connect upload stage.") }
            return
        }

        let uploader = AppStoreConnectUploader(workspaceRoot: workspaceURL, verbose: verbose)
        for locale in localizations {
            let localeDirectory = destination.appendingPathComponent(locale.identifier, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: localeDirectory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                if verbose {
                    Diagnostics.warn("Rendered output missing for locale \(locale.identifier) at \(localeDirectory.path); skipping upload.")
                }
                continue
            }
            let assets = try FileManager.default.contentsOfDirectory(at: localeDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "png" }
            await uploader.uploadIfPossible(locale: locale, platformVariant: "ios", assets: assets)
        }
    }

    @discardableResult
    private func generateReport(
        destinationRoot: URL,
        localizations: [LocalizationMatrix.LocaleContext]
    ) throws -> URL {
        let fileManager = FileManager.default
        var sections: [LocaleReportSection] = []

        for locale in localizations {
            let directory = destinationRoot.appendingPathComponent(locale.identifier, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let assets = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                .filter { $0.pathExtension.lowercased() == "png" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            guard !assets.isEmpty else { continue }

            var grouped: [String: [ReportImage]] = [:]

            for asset in assets {
                let baseName = asset.deletingPathExtension().lastPathComponent
                let deviceSegment = baseName.split(separator: "-").first.map(String.init) ?? "device"
                let deviceLabel = prettifiedDeviceName(from: deviceSegment)
                let pixelSize = imageSize(for: asset)
                let resolution: String
                if let size = pixelSize {
                    resolution = "\(Int(size.width))×\(Int(size.height))"
                } else {
                    resolution = "Unknown Size"
                }
                let groupKey = "\(deviceLabel) — \(resolution)"
                let relativePath = "\(locale.identifier)/\(asset.lastPathComponent)"
                let image = ReportImage(
                    fileName: asset.lastPathComponent,
                    relativePath: relativePath,
                    identifier: baseName
                )
                grouped[groupKey, default: []].append(image)
            }

            let orderedGroups = grouped
                .map { groupKey, images in
                    LocaleReportGroup(
                        label: groupKey,
                        images: images.sorted { $0.fileName < $1.fileName }
                    )
                }
                .sorted { $0.label < $1.label }

            if !orderedGroups.isEmpty {
                sections.append(LocaleReportSection(locale: locale, groups: orderedGroups))
            }
        }

        let reportURL = destinationRoot.appendingPathComponent("framed-screenshots-report.html")
        let html = makeReportHTML(sections: sections)
        try html.write(to: reportURL, atomically: true, encoding: .utf8)
        return reportURL
    }

    private func imageSize(for url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else {
            return nil
        }
        return CGSize(width: CGFloat(truncating: width), height: CGFloat(truncating: height))
    }

    private func prettifiedDeviceName(from segment: String) -> String {
        let replaced = segment
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        return replaced.capitalized
    }

    private func makeReportHTML(sections: [LocaleReportSection]) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let generated = dateFormatter.string(from: Date())
        var body = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Framed Screenshots Report</title>
  <style>
    :root {
      color-scheme: dark light;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      margin: 32px;
      background-color: #0f1115;
      color: #f4f5f8;
    }
    h1 {
      margin-top: 0;
      font-size: 2.2rem;
    }
    p.meta {
      color: #8891a7;
      margin-bottom: 32px;
    }
    section.locale {
      margin-bottom: 48px;
    }
    section.locale h2 {
      margin-bottom: 16px;
      font-size: 1.75rem;
    }
    .device-row {
      margin-bottom: 28px;
    }
    .device-row h3 {
      margin: 0 0 12px 0;
      font-size: 1.1rem;
      color: #c5cbda;
    }
    .strip {
      display: flex;
      gap: 16px;
      overflow-x: auto;
      padding-bottom: 12px;
      scroll-snap-type: x proximity;
    }
    .strip a {
      flex: 0 0 auto;
      scroll-snap-align: start;
    }
    .strip img {
      height: 400px;
      border-radius: 18px;
      box-shadow: 0 8px 26px rgba(15, 17, 21, 0.5);
      border: 1px solid rgba(255, 255, 255, 0.08);
      background-color: rgba(0, 0, 0, 0.2);
    }
    .strip img:hover {
      transform: translateY(-2px);
      transition: transform 0.18s ease-out;
    }
    footer {
      margin-top: 40px;
      font-size: 0.9rem;
      color: #737a8f;
    }
    @media (prefers-color-scheme: light) {
      body { background-color: #f5f6f8; color: #1a1c23; }
      p.meta { color: #606774; }
      .strip img { box-shadow: 0 6px 20px rgba(26, 28, 35, 0.18); border-color: rgba(0, 0, 0, 0.08); }
      footer { color: #7a808c; }
    }
  </style>
</head>
<body>
  <h1>Framed Screenshots Report</h1>
  <p class="meta">Generated \(generated). Scroll horizontally to review each device/resolution.</p>
"""
        if sections.isEmpty {
            body += """
  <p>No rendered screenshots were found in the output directory.</p>
"""
        } else {
            for section in sections {
                body += """
  <section class="locale">
    <h2>\(section.locale.displayName) (\(section.locale.identifier))</h2>
"""
                for group in section.groups {
                    body += """
    <div class="device-row">
      <h3>\(group.label)</h3>
      <div class="strip">
"""
                    for image in group.images {
                        let escapedPath = image.relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? image.relativePath
                        let title = image.identifier.replacingOccurrences(of: "-", with: " ")
                        body += """
        <a href="\(escapedPath)" title="\(title)">
          <img src="\(escapedPath)" alt="\(title)">
        </a>
"""
                    }
                    body += """
      </div>
    </div>
"""
                }
                body += "  </section>\n"
            }
        }

        body += """
  <footer>
    <p>Review this report before uploading to App Store Connect.</p>
  </footer>
</body>
</html>
"""
        return body
    }

    private struct ReportImage {
        let fileName: String
        let relativePath: String
        let identifier: String
    }

    private struct LocaleReportGroup {
        let label: String
        let images: [ReportImage]
    }

    private struct LocaleReportSection {
        let locale: LocalizationMatrix.LocaleContext
        let groups: [LocaleReportGroup]
    }
}

@main
struct FramedScreenshotsCLIEntry {
    static func main() async {
        await FramedScreenshotsCommand.main()
    }
}

enum Diagnostics {
    static func info(_ message: String) {
        FileHandle.standardOutput.write(Data(("ℹ️  " + message + "\n").utf8))
    }

    static func warn(_ message: String) {
        FileHandle.standardError.write(Data(("⚠️  " + message + "\n").utf8))
    }
}
{{MARKER_END}}
