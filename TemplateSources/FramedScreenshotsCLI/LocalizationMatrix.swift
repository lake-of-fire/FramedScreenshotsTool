import Foundation
import FramedScreenshotsKit
import SwiftUI

{{MARKER_START}}
struct LocalizationMatrix {
    struct LocaleContext: Hashable {
        let identifier: String
        let displayName: String
        let screenshotOutput: URL
    }

    let workspaceRoot: URL
    let additionalScreenshotPaths: [URL]
    let verbose: Bool

    func resolveLocalizations(arguments: [String]) throws -> [LocaleContext] {
        let discovered = discoverLocalizations()
        let requested: [String]
        if arguments.isEmpty {
            requested = discovered.map { $0.identifier }
        } else {
            requested = arguments.flatMap { argument in
                argument.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        }

        let lookup = Dictionary(uniqueKeysWithValues: discovered.map { ($0.identifier.lowercased(), $0) })
        let fallbacks = Dictionary(uniqueKeysWithValues: discovered.map { ($0.identifier, $0) })
        var contexts: [LocaleContext] = []
        for identifier in requested {
            if identifier.lowercased() == "auto" {
                contexts.append(contentsOf: discovered)
                continue
            }
            if let context = lookup[identifier.lowercased()] ?? fallbacks[identifier] {
                contexts.append(context)
            } else {
                Diagnostics.warn("Localization \(identifier) not found in workspace; skipping.")
            }
        }
        if contexts.isEmpty {
            contexts = discovered
        }
        if contexts.isEmpty {
            contexts = [LocaleContext(identifier: "en", displayName: "English", screenshotOutput: workspaceRoot.appendingPathComponent("Screenshots/en", isDirectory: true))]
        }
        return contexts.unique()
    }

    func describe(localizations: [LocaleContext], entries: [ScreenshotEntry]) {
        Diagnostics.info("Discovered \(localizations.count) localization(s).")
        for locale in localizations {
            Diagnostics.info("  - \(locale.identifier) → \(locale.screenshotOutput.path)")
        }
        Diagnostics.info("Registered screenshot entries: \(entries.count)")
        for entry in entries {
            Diagnostics.info("  • \(entry.identifier)")
        }
    }

    func captureIfNeeded(
        localizations: [LocaleContext],
        skipCapture: Bool,
        simulator: String?,
        uiTestPlan: String?,
        extraArguments: [String]
    ) throws {
        guard !skipCapture else {
            if verbose { Diagnostics.info("Skipping UI test capture as requested.") }
            return
        }
        guard let uiTestPlan else {
            if verbose { Diagnostics.warn("No UI test plan provided; skipping capture.") }
            return
        }

        for locale in localizations {
            var arguments = ["test", "-scheme", uiTestPlan]
            if let simulator {
                arguments += ["-destination", "platform=iOS Simulator,name=\(simulator)"]
            }
            arguments += ["-resultBundlePath", workspaceRoot.appendingPathComponent(".DerivedData/FramedScreenshots-\(locale.identifier).xcresult").path]
            arguments += extraArguments
            arguments += ["-derivedDataPath", workspaceRoot.appendingPathComponent(".DerivedData").path]
            arguments += ["-enableCodeCoverage", "NO"]
            arguments += ["-skipPackagePluginValidation", "YES"]

            if verbose {
                Diagnostics.info("Running xcodebuild for locale \(locale.identifier): \n  xcodebuild \(arguments.joined(separator: " "))")
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
            process.arguments = arguments
            process.currentDirectoryURL = workspaceRoot

            let pipe = Pipe()
            process.standardOutput = verbose ? FileHandle.standardOutput : pipe
            process.standardError = verbose ? FileHandle.standardError : pipe

            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                Diagnostics.warn("xcodebuild exited with status \(process.terminationStatus) for locale \(locale.identifier). Continuing.")
            }
        }
    }

    func screenshotSearchPaths(for localizations: [LocaleContext]) -> [URL] {
        var set: OrderedSet<URL> = []
        for locale in localizations {
            set.append(locale.screenshotOutput)
            set.append(workspaceRoot.appendingPathComponent("Screenshots/\(locale.identifier)", isDirectory: true))
        }
        additionalScreenshotPaths.forEach { set.append($0) }
        return set.filter { FileManager.default.directoryExists(at: $0) }
    }

    func render(
        entries: [ScreenshotEntry],
        localizations: [LocaleContext],
        destination: URL,
        searchPaths: [URL]
    ) async throws {
        for locale in localizations {
            let directory = destination.appendingPathComponent(locale.identifier, isDirectory: true)
            for entry in entries {
                let context = ScreenshotContext(localeIdentifier: locale.identifier)
                var view = await entry.makeView(context: context)
                view = AnyView(view.environment(\.framedScreenshotsSearchPaths, searchPaths))
                let fileURL = directory
                    .appendingPathComponent(entry.outputFileName(for: locale.identifier))
                    .appendingPathExtension("png")
                try await ViewPNGWriter.write(
                    view: view,
                    to: fileURL,
                    colorScheme: entry.colorScheme,
                    scale: entry.scale,
                    proposedSize: entry.size,
                    locale: context.locale
                )
            }
        }
    }

    private func discoverLocalizations() -> [LocaleContext] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: workspaceRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        var results: OrderedSet<LocaleContext> = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "lproj" else { continue }
            let identifier = url.deletingPathExtension().lastPathComponent
            let display = Locale(identifier: identifier).localizedString(forIdentifier: identifier) ?? identifier
            let output = workspaceRoot.appendingPathComponent("Screenshots/\(identifier)", isDirectory: true)
            results.append(LocaleContext(identifier: identifier, displayName: display, screenshotOutput: output))
        }
        return results.map { $0 }
    }
}

private struct OrderedSet<Element: Hashable>: ExpressibleByArrayLiteral, Sequence {
    private var storage: [Element] = []
    private var lookup: Set<Element> = []

    init() {}

    init(arrayLiteral elements: Element...) {
        elements.forEach { append($0) }
    }

    mutating func append(_ element: Element) {
        guard !lookup.contains(element) else { return }
        storage.append(element)
        lookup.insert(element)
    }

    func filter(_ predicate: (Element) -> Bool) -> [Element] {
        storage.filter(predicate)
    }

    func makeIterator() -> IndexingIterator<[Element]> {
        storage.makeIterator()
    }
}

private extension Array where Element: Hashable {
    func unique() -> [Element] {
        var set: OrderedSet<Element> = []
        for element in self {
            set.append(element)
        }
        return set.map { $0 }
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
{{MARKER_END}}
