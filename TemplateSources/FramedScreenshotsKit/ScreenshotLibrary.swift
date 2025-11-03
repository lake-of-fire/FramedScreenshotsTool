import AppKit
import Foundation
import SwiftUI

{{MARKER_START}}
public struct ScreenshotAsset: Sendable {
    public let name: String
    public let url: URL?
    public let image: NSImage
    public let isPlaceholder: Bool

    public init(name: String, url: URL?, image: NSImage, isPlaceholder: Bool) {
        self.name = name
        self.url = url
        self.image = image
        self.isPlaceholder = isPlaceholder
    }
}

public enum ScreenshotLibrary {
    public static func resolveSearchPaths(additional: [URL] = []) -> [URL] {
        var paths: OrderedSet<URL> = []
        if let env = ProcessInfo.processInfo.environment["FRAMED_SCREENSHOTS_ASSET_PATHS"] {
            env.split(separator: ":").forEach { component in
                let url = URL(fileURLWithPath: String(component), isDirectory: true)
                paths.append(url)
            }
        }

        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        paths.append(current.appendingPathComponent("Screenshots", isDirectory: true))
        paths.append(current.appendingPathComponent("UITestScreenshots", isDirectory: true))
        paths.append(current)

        if let derivedData = DerivedDataLocator.defaultDirectory {
            paths.append(derivedData)
        }

        additional.forEach { paths.append($0) }

        return paths.filter { FileManager.default.directoryExists(at: $0) }
    }

    public static func asset(
        named name: String,
        localizationIdentifier: String?,
        searchPaths: [URL]
    ) -> ScreenshotAsset {
        let fm = FileManager.default
        let candidates = filenameCandidates(for: name, localizationIdentifier: localizationIdentifier)

        for directory in searchPaths {
            for candidate in candidates {
                let url = directory.appendingPathComponent(candidate)
                if fm.fileExists(atPath: url.path) {
                    if let image = NSImage(contentsOf: url) {
                        return ScreenshotAsset(name: name, url: url, image: image, isPlaceholder: false)
                    }
                }
            }
        }

        return ScreenshotAsset(name: name, url: nil, image: PlaceholderFactory.makePlaceholder(for: name), isPlaceholder: true)
    }

    private static func filenameCandidates(for name: String, localizationIdentifier: String?) -> [String] {
        var candidates: [String] = []
        if let localizationIdentifier, !localizationIdentifier.isEmpty {
            candidates.append("\(name)-\(localizationIdentifier).png")
            candidates.append("\(name)_\(localizationIdentifier).png")
        }
        candidates.append("\(name).png")
        candidates.append("\(name).heic")
        candidates.append("\(name).jpg")
        candidates.append("\(name).jpeg")
        return candidates
    }
}

private enum PlaceholderFactory {
    static func makePlaceholder(for name: String) -> NSImage {
        let size = NSSize(width: 1080, height: 1920)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let gradient = NSGradient(colors: [NSColor.systemGray, NSColor.systemGray.withSystemEffect(.pressed)])
        gradient?.draw(in: NSBezierPath(rect: NSRect(origin: .zero, size: size)), angle: 90)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            .paragraphStyle: paragraph
        ]
        let text = "Placeholder\n\(name)"
        text.draw(in: NSRect(x: 80, y: 680, width: size.width - 160, height: size.height - 160), withAttributes: attributes)
        return image
    }
}

private enum DerivedDataLocator {
    static var defaultDirectory: URL? {
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        let derivedData = library.appendingPathComponent("Developer/Xcode/DerivedData", isDirectory: true)
        guard FileManager.default.directoryExists(at: derivedData) else {
            return nil
        }
        return derivedData
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

private extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        if fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return isDirectory.boolValue
        }
        return false
    }
}

private struct FramedScreenshotsSearchPathsKey: EnvironmentKey {
    static let defaultValue: [URL] = ScreenshotLibrary.resolveSearchPaths()
}

public extension EnvironmentValues {
    var framedScreenshotsSearchPaths: [URL] {
        get { self[FramedScreenshotsSearchPathsKey.self] }
        set { self[FramedScreenshotsSearchPathsKey.self] = newValue }
    }
}
{{MARKER_END}}
