import AppKit
import Foundation

public struct FocusExtractionConfiguration: Sendable, Hashable {
    public var screenshotName: String
    public var localizationIdentifier: String?
    public var borderColor: NSColor
    public var tolerance: CGFloat
    public var zoomScale: CGFloat

    public init(
        screenshotName: String,
        localizationIdentifier: String? = nil,
        borderColor: NSColor,
        tolerance: CGFloat = 0.08,
        zoomScale: CGFloat = 1.18
    ) {
        self.screenshotName = screenshotName
        self.localizationIdentifier = localizationIdentifier
        self.borderColor = borderColor
        self.tolerance = tolerance
        self.zoomScale = zoomScale
    }

    var cacheKey: String {
        "\(screenshotName)-\(localizationIdentifier ?? "baseline")-\(borderColor.description)-\(tolerance)"
    }
}

public struct FocusExtractionResult: Equatable {
    public var overlayImage: NSImage
    public var maskPath: CGPath
    public var normalizedCentroid: CGPoint

    public init(overlayImage: NSImage, maskPath: CGPath, normalizedCentroid: CGPoint) {
        self.overlayImage = overlayImage
        self.maskPath = maskPath
        self.normalizedCentroid = normalizedCentroid
    }
}

public final class FocusedElementExtractor {
    private var cache: [String: FocusExtractionResult] = [:]
    private let cacheLock = NSLock()

    public init() {}

    public func extract(configuration: FocusExtractionConfiguration, image: NSImage) -> FocusExtractionResult? {
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

        guard let maskedImage = maskImage(cgImage, with: path) else {
            return nil
        }

        let centroid = centroidOfPolygon(points: hull)
        let normalizedCentroid = CGPoint(
            x: centroid.x / CGFloat(width),
            y: centroid.y / CGFloat(height)
        )

        let result = FocusExtractionResult(
            overlayImage: maskedImage,
            maskPath: path.copy() ?? path,
            normalizedCentroid: normalizedCentroid
        )

        cacheLock.lock()
        cache[configuration.cacheKey] = result
        cacheLock.unlock()
        return result
    }

    private func maskImage(_ source: CGImage, with maskPath: CGPath) -> NSImage? {
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
            return nil
        }
        context.addPath(maskPath)
        context.clip()
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let masked = context.makeImage() else {
            return nil
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
}

private enum ConvexHull {
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

private func colorDistance(_ lhs: (CGFloat, CGFloat, CGFloat), _ rhs: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
    let dr = lhs.0 - rhs.0
    let dg = lhs.1 - rhs.1
    let db = lhs.2 - rhs.2
    return sqrt(dr * dr + dg * dg + db * db)
}

private extension NSColor {
    var componentsRGB: (CGFloat, CGFloat, CGFloat) {
        let converted = usingColorSpace(.deviceRGB) ?? self
        return (converted.redComponent, converted.greenComponent, converted.blueComponent)
    }
}
