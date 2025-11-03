import AppKit
import Foundation
import SwiftUI

{{MARKER_START}}
public struct FocusedScreenshotOverlay: View {
    public struct Configuration {
        public var screenshotName: String
        public var localizationIdentifier: String?
        public var borderColor: NSColor
        public var tolerance: CGFloat
        public var zoomScale: CGFloat
        public var dimming: Dimming
        public var focusShadow: FocusShadow?
        public var borderStyle: FocusBorderStyle?
        public var searchPaths: [URL]

        public init(
            screenshotName: String,
            localizationIdentifier: String? = nil,
            borderColor: NSColor,
            tolerance: CGFloat = 0.08,
            zoomScale: CGFloat = 1.18,
            dimming: Dimming = .dimmed(amount: Dimming.defaultAmount),
            focusShadow: FocusShadow? = .default,
            borderStyle: FocusBorderStyle? = nil,
            searchPaths: [URL] = ScreenshotLibrary.resolveSearchPaths()
        ) {
            self.screenshotName = screenshotName
            self.localizationIdentifier = localizationIdentifier
            self.borderColor = borderColor
            self.tolerance = tolerance
            self.zoomScale = zoomScale
            self.dimming = dimming
            self.focusShadow = focusShadow
            self.borderStyle = borderStyle
            self.searchPaths = searchPaths
        }
    }

    public enum Dimming {
        case undimmed
        case dimmed(amount: Double)

        var opacity: Double {
            switch self {
            case .undimmed:
                return 0
            case .dimmed(let value):
                return value
            }
        }

        public static let defaultAmount: Double = 0.45
    }

    public struct FocusShadow {
        public var color: Color
        public var radius: CGFloat
        public var x: CGFloat
        public var y: CGFloat

        public init(color: Color = .black.opacity(0.35), radius: CGFloat = 18, x: CGFloat = 0, y: CGFloat = 12) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }

        public static let `default` = FocusShadow()
    }

    public struct FocusBorderStyle {
        public var color: Color
        public var width: CGFloat
        public var dash: [CGFloat]

        public init(color: Color = .white, width: CGFloat = 6, dash: [CGFloat] = []) {
            self.color = color
            self.width = width
            self.dash = dash
        }
    }

    @StateObject private var model: FocusedScreenshotOverlayModel

    public init(configuration: Configuration) {
        _model = StateObject(wrappedValue: FocusedScreenshotOverlayModel(configuration: configuration))
    }

    public init(
        screenshotName: String,
        localizationIdentifier: String? = nil,
        borderColor: Color,
        tolerance: CGFloat = 0.08,
        zoomScale: CGFloat = 1.18,
        dimming: Dimming = .dimmed(amount: Dimming.defaultAmount),
        focusShadow: FocusShadow? = .default,
        borderStyle: FocusBorderStyle? = nil,
        searchPaths: [URL] = ScreenshotLibrary.resolveSearchPaths()
    ) {
        let nsColor = NSColor(borderColor)
        let configuration = Configuration(
            screenshotName: screenshotName,
            localizationIdentifier: localizationIdentifier,
            borderColor: nsColor,
            tolerance: tolerance,
            zoomScale: zoomScale,
            dimming: dimming,
            focusShadow: focusShadow,
            borderStyle: borderStyle,
            searchPaths: searchPaths
        )
        _model = StateObject(wrappedValue: FocusedScreenshotOverlayModel(configuration: configuration))
    }

    public var body: some View {
        ZStack {
            if let asset = model.asset {
                Image(nsImage: asset.image)
                    .resizable()
                    .scaledToFit()
                    .overlay(dimmingOverlay)
                    .overlay(focusOverlay)
            } else {
                PlaceholderView(configuration: model.configuration)
            }
        }
        .task(id: model.configuration.cacheKey) {
            await model.load()
        }
    }

    @ViewBuilder
    private var dimmingOverlay: some View {
        if let focus = model.focusResult, model.configuration.dimming.opacity > 0 {
            Color.black
                .opacity(model.configuration.dimming.opacity)
                .mask(
            FocusMaskShape(mask: focus.mask)
                .fill(style: FillStyle(eoFill: true))
                .overlay(FocusMaskShape(mask: focus.mask).stroke(Color.clear, lineWidth: 1))
            )
            .animation(.easeInOut(duration: 0.25), value: model.focusResult?.mask.boundingBox)
        } else if model.configuration.dimming.opacity > 0 {
            Color.black.opacity(model.configuration.dimming.opacity)
        }
    }

    @ViewBuilder
    private var focusOverlay: some View {
        if let focus = model.focusResult {
            FocusOverlayImage(focus: focus, configuration: model.configuration)
                .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.2), value: model.focusResult?.mask.boundingBox)
        }
    }
}

private final class FocusedScreenshotOverlayModel: ObservableObject {
    @Published var asset: ScreenshotAsset?
    @Published var focusResult: FocusExtractionResult?

    let configuration: FocusedScreenshotOverlay.Configuration

    init(configuration: FocusedScreenshotOverlay.Configuration) {
        self.configuration = configuration
    }

    var focusExtractor = FocusedElementExtractor()

    var configurationContext: FocusExtractionConfiguration {
        FocusExtractionConfiguration(
            screenshotName: configuration.screenshotName,
            localizationIdentifier: configuration.localizationIdentifier,
            borderColor: configuration.borderColor,
            tolerance: configuration.tolerance,
            zoomScale: configuration.zoomScale
        )
    }

    func load() async {
        let searchPaths = configuration.searchPaths
        let asset = ScreenshotLibrary.asset(
            named: configuration.screenshotName,
            localizationIdentifier: configuration.localizationIdentifier,
            searchPaths: searchPaths
        )
        await MainActor.run {
            self.asset = asset
        }
        guard !asset.isPlaceholder else { return }
        let result = focusExtractor.extract(
            configuration: configurationContext,
            image: asset.image
        )
        await MainActor.run {
            self.focusResult = result
        }
    }
}

private struct FocusOverlayImage: View {
    let focus: FocusExtractionResult
    let configuration: FocusedScreenshotOverlay.Configuration

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scale = configuration.zoomScale
            let centroid = focus.normalizedCentroid
            let position = CGPoint(x: centroid.x * size.width, y: (1 - centroid.y) * size.height)

            Image(nsImage: focus.overlayImage)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale, anchor: .center)
                .modifier(FocusBorderModifier(mask: focus.mask, border: configuration.borderStyle))
                .shadow(
                    color: configuration.focusShadow?.color ?? .clear,
                    radius: configuration.focusShadow?.radius ?? 0,
                    x: configuration.focusShadow?.x ?? 0,
                    y: configuration.focusShadow?.y ?? 0
                )
                .position(position)
        }
    }
}

private struct PlaceholderView: View {
    let configuration: FocusedScreenshotOverlay.Configuration

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: PlaceholderFactory.makePlaceholder(for: configuration.screenshotName))
                .resizable()
                .scaledToFit()
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )
            Text("Missing screenshot: \(configuration.screenshotName)")
                .font(.title2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.gray.opacity(0.12))
        )
    }
}

private struct FocusMaskShape: Shape {
    let mask: FocusMask

    func path(in rect: CGRect) -> Path {
        Path(mask.cgPath)
    }
}

private struct FocusBorderModifier: ViewModifier {
    let mask: FocusMask
    let border: FocusedScreenshotOverlay.FocusBorderStyle?

    func body(content: Content) -> some View {
        if let border {
            content
                .overlay(
                    Path(mask.cgPath)
                        .stroke(border.color, style: StrokeStyle(lineWidth: border.width, dash: border.dash))
                )
        } else {
            content
        }
    }
}

private struct FocusExtractionConfiguration {
    var screenshotName: String
    var localizationIdentifier: String?
    var borderColor: NSColor
    var tolerance: CGFloat
    var zoomScale: CGFloat

    var cacheKey: String {
        "\(screenshotName)-\(localizationIdentifier ?? "baseline")-\(borderColor.description)-\(tolerance)"
    }
}

private final class FocusedElementExtractor {
    private var cache: [String: FocusExtractionResult] = [:]
    private let cacheLock = NSLock()

    func extract(configuration: FocusExtractionConfiguration, image: NSImage) -> FocusExtractionResult? {
        cacheLock.lock()
        if let cached = cache[configuration.cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data as Data? else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8

        guard bytesPerPixel >= 4 else { return nil }

        let targetColor = configuration.borderColor.usingColorSpace(.deviceRGB) ?? configuration.borderColor
        let targetComponents = targetColor.componentsRGB

        var focusPoints: [CGPoint] = []
        let tolerance = configuration.tolerance

        data.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else { return }
            for y in 0..<height {
                for x in 0..<width {
                    let index = (y * width + x) * bytesPerPixel
                    let pixel = baseAddress.advanced(by: index).assumingMemoryBound(to: UInt8.self)
                    let r = CGFloat(pixel[0]) / 255.0
                    let g = CGFloat(pixel[1]) / 255.0
                    let b = CGFloat(pixel[2]) / 255.0
                    let a = CGFloat(pixel[3]) / 255.0
                    guard a > 0.05 else { continue }
                    let distance = colorDistance((r, g, b), targetComponents)
                    if distance <= tolerance {
                        focusPoints.append(CGPoint(x: CGFloat(x), y: CGFloat(y)))
                    }
                }
            }
        }

        guard focusPoints.count > 12 else {
            return nil
        }

        let hull = ConvexHull.compute(for: focusPoints)
        guard hull.count >= 3 else { return nil }

        let path = CGMutablePath()
        path.addLines(between: hull)
        path.closeSubpath()

        let overlayImage = makeOverlayImage(from: cgImage, maskPath: path)
        let centroid = centroidOfPolygon(points: hull)
        let normalizedCentroid = CGPoint(x: centroid.x / CGFloat(width), y: centroid.y / CGFloat(height))
        let result = FocusExtractionResult(
            overlayImage: overlayImage,
            mask: FocusMask(cgPath: path),
            normalizedCentroid: normalizedCentroid
        )
        cacheLock.lock()
        cache[configuration.cacheKey] = result
        cacheLock.unlock()
        return result
    }

    private func makeOverlayImage(from source: CGImage, maskPath: CGPath) -> NSImage {
        let width = source.width
        let height = source.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return NSImage(size: .zero)
        }
        context.addPath(maskPath)
        context.clip()
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let masked = context.makeImage() else {
            return NSImage(size: .zero)
        }
        return NSImage(cgImage: masked, size: NSSize(width: width, height: height))
    }

    private func centroidOfPolygon(points: [CGPoint]) -> CGPoint {
        var area: CGFloat = 0
        var centroidX: CGFloat = 0
        var centroidY: CGFloat = 0
        let count = points.count
        guard count >= 3 else {
            return points.first ?? .zero
        }
        for i in 0..<count {
            let current = points[i]
            let next = points[(i + 1) % count]
            let cross = current.x * next.y - next.x * current.y
            area += cross
            centroidX += (current.x + next.x) * cross
            centroidY += (current.y + next.y) * cross
        }
        area *= 0.5
        if area == 0 {
            return points.first ?? .zero
        }
        centroidX /= (6 * area)
        centroidY /= (6 * area)
        return CGPoint(x: centroidX, y: centroidY)
    }

    private func colorDistance(_ lhs: (CGFloat, CGFloat, CGFloat), _ rhs: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
        let dr = lhs.0 - rhs.0
        let dg = lhs.1 - rhs.1
        let db = lhs.2 - rhs.2
        return sqrt(dr * dr + dg * dg + db * db)
    }
}

private struct ConvexHull {
    static func compute(for points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { lhs, rhs in
            if lhs.x == rhs.x {
                return lhs.y < rhs.y
            }
            return lhs.x < rhs.x
        }
        guard sorted.count > 2 else { return sorted }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    private static func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    }
}

private struct FocusExtractionResult {
    let overlayImage: NSImage
    let mask: FocusMask
    let normalizedCentroid: CGPoint
}

private struct FocusMask: @unchecked Sendable {
    let cgPath: CGPath

    var boundingBox: CGRect {
        cgPath.boundingBox
    }
}

private extension FocusedScreenshotOverlay.Configuration {
    var cacheKey: String {
        "\(screenshotName)-\(localizationIdentifier ?? "baseline")-\(borderColor.description)-\(tolerance)-\(zoomScale)"
    }
}

private extension NSColor {
    convenience init(_ color: Color) {
        if let cgColor = color.cgColor {
            self.init(cgColor: cgColor)!
        } else {
            self.init(srgbRed: 1, green: 0, blue: 0, alpha: 1)
        }
    }

    var componentsRGB: (CGFloat, CGFloat, CGFloat) {
        let converted = usingColorSpace(.deviceRGB) ?? self
        return (converted.redComponent, converted.greenComponent, converted.blueComponent)
    }
}

private enum PlaceholderFactory {
    static func makePlaceholder(for name: String) -> NSImage {
        let size = NSSize(width: 900, height: 1600)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let background = NSGradient(colors: [NSColor.systemBlue.withAlphaComponent(0.6), NSColor.systemIndigo])
        background?.draw(in: NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 48, yRadius: 48), angle: -90)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 44, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]

        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8),
            .paragraphStyle: paragraph
        ]

        let title = "Focused overlay preview"
        title.draw(in: NSRect(x: 40, y: size.height / 2 + 40, width: size.width - 80, height: 160), withAttributes: titleAttributes)

        let subtitle = "Screenshot ‘\(name)’ not found"
        subtitle.draw(in: NSRect(x: 40, y: size.height / 2 - 80, width: size.width - 80, height: 120), withAttributes: subtitleAttributes)
        return image
    }
}
{{MARKER_END}}
