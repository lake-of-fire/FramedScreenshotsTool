import Foundation
import SwiftUI

{{MARKER_START}}
public struct ScreenshotContext: Sendable {
    public let localeIdentifier: String
    public let locale: Locale
    public let deviceName: String?

    public init(localeIdentifier: String, deviceName: String? = nil) {
        self.localeIdentifier = localeIdentifier
        self.locale = Locale(identifier: localeIdentifier)
        self.deviceName = deviceName
    }
}

public struct ScreenshotEntry: Sendable {
    public let identifier: String
    public let fileName: String?
    public let colorScheme: ColorScheme?
    public let size: CGSize?
    public let scale: CGFloat
    public let preferredLocalizationFallback: String?
    private let builder: @Sendable (ScreenshotContext) -> AnyView

    public init<V: View>(
        identifier: String,
        fileName: String? = nil,
        colorScheme: ColorScheme? = nil,
        size: CGSize? = nil,
        scale: CGFloat = 3.0,
        preferredLocalizationFallback: String? = nil,
        @ViewBuilder makeView: @escaping @Sendable () -> V
    ) {
        self.identifier = identifier
        self.fileName = fileName
        self.colorScheme = colorScheme
        self.size = size
        self.scale = scale
        self.preferredLocalizationFallback = preferredLocalizationFallback
        self.builder = { _ in AnyView(makeView()) }
    }

    public init<V: View>(
        identifier: String,
        fileName: String? = nil,
        colorScheme: ColorScheme? = nil,
        size: CGSize? = nil,
        scale: CGFloat = 3.0,
        preferredLocalizationFallback: String? = nil,
        @ViewBuilder makeView: @escaping @Sendable (ScreenshotContext) -> V
    ) {
        self.identifier = identifier
        self.fileName = fileName
        self.colorScheme = colorScheme
        self.size = size
        self.scale = scale
        self.preferredLocalizationFallback = preferredLocalizationFallback
        self.builder = { AnyView(makeView($0)) }
    }

    @MainActor
    public func makeView(context: ScreenshotContext) -> AnyView {
        builder(context)
    }

    public func outputFileName(for localizationIdentifier: String?) -> String {
        if let fileName {
            if let localizationIdentifier, !localizationIdentifier.isEmpty {
                return "\(fileName)-\(localizationIdentifier)"
            }
            return fileName
        }
        let slug = ScreenshotEntry.slug(from: identifier)
        if let localizationIdentifier, !localizationIdentifier.isEmpty {
            return "\(slug)-\(localizationIdentifier)"
        }
        return slug
    }

    static func slug(from identifier: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let components = identifier
            .lowercased()
            .map { character -> String in
                let scalarString = String(character)
                if scalarString.rangeOfCharacter(from: allowed) != nil {
                    return scalarString
                } else if character.isWhitespace {
                    return "-"
                }
                return ""
            }
        let slug = components.joined()
        let trimmed = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "screenshot" : trimmed
    }
}

public struct ScreenshotRegistry: Sendable {
    private var entries: [ScreenshotEntry] = []

    public init() {}

    public mutating func register(_ entry: ScreenshotEntry) {
        entries.append(entry)
    }

    public mutating func register<V: View>(
        identifier: String,
        fileName: String? = nil,
        colorScheme: ColorScheme? = nil,
        size: CGSize? = nil,
        scale: CGFloat = 3.0,
        preferredLocalizationFallback: String? = nil,
        @ViewBuilder makeView: @escaping @Sendable () -> V
    ) {
        register(
            ScreenshotEntry(
                identifier: identifier,
                fileName: fileName,
                colorScheme: colorScheme,
                size: size,
                scale: scale,
                preferredLocalizationFallback: preferredLocalizationFallback,
                makeView: makeView
            )
        )
    }

    public mutating func register<V: View>(
        identifier: String,
        fileName: String? = nil,
        colorScheme: ColorScheme? = nil,
        size: CGSize? = nil,
        scale: CGFloat = 3.0,
        preferredLocalizationFallback: String? = nil,
        @ViewBuilder makeView: @escaping @Sendable (ScreenshotContext) -> V
    ) {
        register(
            ScreenshotEntry(
                identifier: identifier,
                fileName: fileName,
                colorScheme: colorScheme,
                size: size,
                scale: scale,
                preferredLocalizationFallback: preferredLocalizationFallback,
                makeView: makeView
            )
        )
    }

    public func entries(matching filters: [String]) -> [ScreenshotEntry] {
        guard !filters.isEmpty else {
            return entries
        }
        let globFilters = filters.compactMap(GlobPattern.init)
        return entries.filter { entry in
            globFilters.contains(where: { $0.matches(entry.identifier) })
        }
    }

    public var allEntries: [ScreenshotEntry] {
        entries
    }
}

struct GlobPattern {
    private let regex: NSRegularExpression

    init?(_ pattern: String) {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        let finalPattern = "^\(escaped)$"
        guard let expression = try? NSRegularExpression(pattern: finalPattern, options: [.caseInsensitive]) else {
            return nil
        }
        self.regex = expression
    }

    func matches(_ candidate: String) -> Bool {
        let range = NSRange(candidate.startIndex..<candidate.endIndex, in: candidate)
        return regex.firstMatch(in: candidate, options: [], range: range) != nil
    }
}
{{MARKER_END}}
