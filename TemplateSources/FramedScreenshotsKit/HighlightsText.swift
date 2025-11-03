import SwiftUI
#if canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#elseif canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#endif

{{MARKER_START}}
@available(macOS 14.0, *)
public struct HighlightsText: View {
    public var text: AttributedString
    public var style: HighlightStyle

    public init(_ text: AttributedString, style: HighlightStyle = .accented) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        let prepared = style.preparedHighlights(from: text)
        HighlightLayoutView(prepared: prepared, style: style)
    }
}

@available(macOS 14.0, *)
public enum HighlightStyle: Sendable {
    case accented

    var font: Font {
        .system(size: 32, weight: .semibold, design: .rounded)
    }

    var fontSize: CGFloat { 32 }
    var fontWeight: Font.Weight { .semibold }
    var textColor: Color { .primary }
    var lineSpacing: CGFloat { 6 }
    var highlightForegroundColor: Color { .white }
    var accentColor: Color { Color(red: 0.95, green: 0.32, blue: 0.53) }

    var defaultMark: HighlightMark {
        HighlightMark(
            background: nil,
            foreground: nil,
            useSourceColor: true,
            tiltDegrees: -4.5,
            horizontalInset: 14,
            verticalInset: 8,
            cornerRadius: 26,
            shadowRadius: 12,
            shadowOpacity: 0.22,
            shadowYOffset: 8,
            knockout: true
        )
    }

    var placeholder: AttributedString {
        var sample = AttributedString("Just take a picture in seconds")
        if let range = sample.range(of: "picture") {
            sample[range].framedScreenshots.highlight = HighlightMark()
        }
        return sample
    }

    fileprivate func preparedHighlights(from raw: AttributedString) -> PreparedHighlights {
        var working = raw
        if working.characters.isEmpty {
            working = placeholder
        }

        var highlights: [HighlightCandidate] = []
        var utf16Cursor = 0

        for run in working.runs {
            let range = run.range
            let baseColor = run.foregroundColor ?? textColor
            let resolved = resolve(mark: run[HighlightAttribute.self], baseColor: baseColor)
            let substring = working[range]
            let segmentString = String(substring.characters)
            let segmentLength = segmentString.utf16.count
            if let resolved {
                working[range].foregroundColor = resolved.knockout ? .clear : resolved.foreground.color
                working[range].framedScreenshots.highlight = resolved.asMark()
                let nsRange = NSRange(location: utf16Cursor, length: segmentLength)
                if nsRange.length > 0 {
                    highlights.append(HighlightCandidate(nsRange: nsRange, range: range, mark: resolved))
                }
            } else {
                working[range].foregroundColor = baseColor
            }
            utf16Cursor += segmentLength
        }

        return PreparedHighlights(text: working, highlights: highlights)
    }

    private func resolve(mark: HighlightMark?, baseColor: Color) -> ResolvedHighlightMark? {
        if mark == nil && baseColor == textColor {
            return nil
        }

        let baseBackground = HighlightColor(baseColor)
        let backgroundColor: HighlightColor
        if let explicitBackground = mark?.background {
            backgroundColor = explicitBackground
        } else if mark?.useSourceColor ?? true {
            backgroundColor = baseBackground
        } else {
            backgroundColor = HighlightColor(accentColor)
        }

        let foregroundColor = mark?.foreground ?? HighlightColor(highlightForegroundColor)
        let knockout = mark?.knockout ?? defaultMark.knockout

        return ResolvedHighlightMark(
            background: backgroundColor,
            foreground: foregroundColor,
            tiltDegrees: mark?.tiltDegrees ?? defaultMark.tiltDegrees,
            horizontalInset: mark?.horizontalInset ?? defaultMark.horizontalInset,
            verticalInset: mark?.verticalInset ?? defaultMark.verticalInset,
            cornerRadius: mark?.cornerRadius ?? defaultMark.cornerRadius,
            shadowRadius: mark?.shadowRadius ?? defaultMark.shadowRadius,
            shadowOpacity: mark?.shadowOpacity ?? defaultMark.shadowOpacity,
            shadowYOffset: mark?.shadowYOffset ?? defaultMark.shadowYOffset,
            knockout: knockout
        )
    }

    fileprivate var platformFont: PlatformFont {
        #if canImport(AppKit)
        PlatformFont.systemFont(ofSize: fontSize, weight: PlatformFont.Weight(fontWeight))
        #elseif canImport(UIKit)
        PlatformFont.systemFont(ofSize: fontSize, weight: PlatformFont.Weight(fontWeight))
        #else
        fatalError("Unsupported platform")
        #endif
    }
}

public struct HighlightMark: Codable, Hashable, Sendable {
    public var background: HighlightColor?
    public var foreground: HighlightColor?
    public var useSourceColor: Bool
    public var tiltDegrees: Double
    public var horizontalInset: CGFloat
    public var verticalInset: CGFloat
    public var cornerRadius: CGFloat
    public var shadowRadius: CGFloat
    public var shadowOpacity: Double
    public var shadowYOffset: CGFloat
    public var knockout: Bool

    public init(
        background: HighlightColor? = nil,
        foreground: HighlightColor? = nil,
        useSourceColor: Bool = true,
        tiltDegrees: Double = -4.5,
        horizontalInset: CGFloat = 14,
        verticalInset: CGFloat = 8,
        cornerRadius: CGFloat = 26,
        shadowRadius: CGFloat = 12,
        shadowOpacity: Double = 0.22,
        shadowYOffset: CGFloat = 8,
        knockout: Bool = true
    ) {
        self.background = background
        self.foreground = foreground
        self.useSourceColor = useSourceColor
        self.tiltDegrees = tiltDegrees
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
        self.shadowYOffset = shadowYOffset
        self.knockout = knockout
    }
}

public struct HighlightColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    public init(_ color: Color) {
        let components = color.colorComponents
        self.red = components.red
        self.green = components.green
        self.blue = components.blue
        self.opacity = components.opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: opacity)
    }
}

public struct HighlightAttribute: AttributedStringKey {
    public typealias Value = HighlightMark
    public static let name = "framedScreenshots.highlight"
}

extension HighlightAttribute: TextAttribute {}

public extension AttributeScopes {
    struct FramedScreenshotsAttributes: AttributeScope {
        public let highlight: HighlightAttribute
        public let swiftUI: SwiftUIAttributes
    }

    var framedScreenshots: FramedScreenshotsAttributes.Type { FramedScreenshotsAttributes.self }
}

public extension AttributeDynamicLookup {
    subscript<T>(dynamicMember keyPath: KeyPath<AttributeScopes.FramedScreenshotsAttributes, T>) -> T where T: AttributedStringKey {
        self[T.self]
    }
}

@available(macOS 14.0, *)
private struct HighlightLayoutView: View {
    var prepared: PreparedHighlights
    var style: HighlightStyle
    @State private var textSize: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            baseText
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: HighlightSizePreference.self, value: proxy.size)
                    }
                )
            ZStack(alignment: .topLeading) {
                HighlightCanvasView(prepared: prepared, style: style, size: textSize)
                knockoutText
            }
            .compositingGroup()
        }
        .onPreferenceChange(HighlightSizePreference.self) { newValue in
            if newValue != .zero {
                textSize = newValue
            }
        }
    }

    private var baseText: some View {
        Text(prepared.text)
            .font(style.font)
            .multilineTextAlignment(.leading)
            .lineSpacing(style.lineSpacing)
            .foregroundColor(style.textColor)
    }

    private var knockoutText: some View {
        Text(prepared.knockoutAttributedString)
            .font(style.font)
            .multilineTextAlignment(.leading)
            .lineSpacing(style.lineSpacing)
            .foregroundColor(.white)
            .blendMode(.destinationOut)
    }
}

@available(macOS 14.0, *)
private struct HighlightCanvasView: View {
    var prepared: PreparedHighlights
    var style: HighlightStyle
    var size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            guard canvasSize.width > 0, canvasSize.height > 0 else { return }
            let geometries = HighlightGeometryBuilder.compute(
                prepared: prepared,
                style: style,
                width: canvasSize.width
            )

            for geometry in geometries {
                for rect in geometry.rects {
                    let insetRect = rect.insetBy(
                        dx: -geometry.mark.horizontalInset,
                        dy: -geometry.mark.verticalInset
                    )
                    let center = CGPoint(x: insetRect.midX, y: insetRect.midY)
                    context.drawLayer { layerContext in
                        layerContext.withCGContext { cg in
                            cg.saveGState()
                            cg.translateBy(x: center.x, y: center.y)
                            cg.rotate(by: CGFloat(geometry.mark.tiltDegrees * .pi / 180))
                            cg.translateBy(x: -center.x, y: -center.y)
                            let shadowColor = geometry.mark.background.cgColor.copy(alpha: geometry.mark.shadowOpacity) ?? geometry.mark.background.cgColor
                            cg.setShadow(
                                offset: CGSize(width: 0, height: geometry.mark.shadowYOffset),
                                blur: geometry.mark.shadowRadius,
                                color: shadowColor
                            )
                            let path = CGPath(
                                roundedRect: insetRect,
                                cornerWidth: geometry.mark.cornerRadius,
                                cornerHeight: geometry.mark.cornerRadius,
                                transform: nil
                            )
                            cg.setFillColor(geometry.mark.background.cgColor)
                            cg.addPath(path)
                            cg.fillPath()
                            cg.restoreGState()
                        }
                    }
                }
            }
        }
        .frame(width: max(size.width, 1), height: max(size.height, 1), alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

private struct HighlightSizePreference: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let new = nextValue()
        if new != .zero {
            value = new
        }
    }
}

private struct PreparedHighlights {
    var text: AttributedString
    var highlights: [HighlightCandidate]

    var knockoutAttributedString: AttributedString {
        var working = text
        let fullRange = working.startIndex..<working.endIndex
        if fullRange.lowerBound != fullRange.upperBound {
            working[fullRange].foregroundColor = .clear
        }
        for candidate in highlights where candidate.mark.knockout {
            working[candidate.range].foregroundColor = .white
        }
        return working
    }
}

private struct HighlightCandidate {
    var nsRange: NSRange
    var range: Range<AttributedString.Index>
    var mark: ResolvedHighlightMark
}

@available(macOS 14.0, *)
private struct ResolvedHighlightMark: Hashable {
    var background: HighlightColor
    var foreground: HighlightColor
    var tiltDegrees: Double
    var horizontalInset: CGFloat
    var verticalInset: CGFloat
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var shadowOpacity: Double
    var shadowYOffset: CGFloat
    var knockout: Bool

    func asMark() -> HighlightMark {
        HighlightMark(
            background: background,
            foreground: foreground,
            useSourceColor: false,
            tiltDegrees: tiltDegrees,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity,
            shadowYOffset: shadowYOffset,
            knockout: knockout
        )
    }
}

@available(macOS 14.0, *)
private struct HighlightGeometry {
    var mark: ResolvedHighlightMark
    var rects: [CGRect]
}

@available(macOS 14.0, *)
private enum HighlightGeometryBuilder {
    static func compute(
        prepared: PreparedHighlights,
        style: HighlightStyle,
        width: CGFloat
    ) -> [HighlightGeometry] {
        guard width > 0 else { return [] }

        let mutable = NSMutableAttributedString(
            attributedString: NSAttributedString(prepared.text)
        )
        mutable.addAttribute(
            .font,
            value: style.platformFont,
            range: NSRange(location: 0, length: mutable.length)
        )

        let textStorage = NSTextStorage(attributedString: mutable)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        layoutManager.addTextContainer(textContainer)
        layoutManager.ensureLayout(for: textContainer)

        var geometries: [HighlightGeometry] = []

        for candidate in prepared.highlights {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: candidate.nsRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { continue }
            var rects: [CGRect] = []
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, textContainer, glyphRangeForLine, _ in
                let intersection = NSIntersectionRange(glyphRangeForLine, glyphRange)
                guard intersection.length > 0 else { return }
                var highlightRect = layoutManager.boundingRect(forGlyphRange: intersection, in: textContainer)
                highlightRect.origin.y = rect.minY
                rects.append(highlightRect)
            }
            if !rects.isEmpty {
                geometries.append(HighlightGeometry(mark: candidate.mark, rects: rects))
            }
        }

        return geometries
    }
}

private extension Color {
    var colorComponents: (red: Double, green: Double, blue: Double, opacity: Double) {
        #if canImport(AppKit)
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        return (
            Double(converted.redComponent),
            Double(converted.greenComponent),
            Double(converted.blueComponent),
            Double(converted.alphaComponent)
        )
        #elseif canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (
            Double(red),
            Double(green),
            Double(blue),
            Double(alpha)
        )
        #else
        return (1, 1, 1, 1)
        #endif
    }
}

#if canImport(AppKit)
private extension NSFont.Weight {
    init(_ weight: Font.Weight) {
        switch weight {
        case .ultraLight: self = .ultraLight
        case .thin: self = .thin
        case .light: self = .light
        case .regular: self = .regular
        case .medium: self = .medium
        case .semibold: self = .semibold
        case .bold: self = .bold
        case .heavy: self = .heavy
        case .black: self = .black
        default: self = .regular
        }
    }
}
#elseif canImport(UIKit)
private extension UIFont.Weight {
    init(_ weight: Font.Weight) {
        switch weight {
        case .ultraLight: self = .ultraLight
        case .thin: self = .thin
        case .light: self = .light
        case .regular: self = .regular
        case .medium: self = .medium
        case .semibold: self = .semibold
        case .bold: self = .bold
        case .heavy: self = .heavy
        case .black: self = .black
        default: self = .regular
        }
    }
}
#endif
{{MARKER_END}}
