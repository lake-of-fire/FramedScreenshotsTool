import Foundation
import SwiftUI

{{MARKER_START}}
public struct HeroText: View {
    public var text: AttributedString
    public var style: HeroTextStyle

    public init(_ text: AttributedString, style: HeroTextStyle = .exciting()) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        let prepared = style.prepare(text: text)

        return ZStack {
            HeroStrokeView(prepared: prepared, style: style)
            HeroFillView(prepared: prepared, style: style)
        }
        .padding(style.contentPadding)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(style.backgroundStyle)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(style.borderStyle, lineWidth: 1.5)
                        .opacity(style.borderOpacity)
                )
        )
        .accessibilityLabel(Text(prepared.accessibilityLabel))
    }
}

public enum HeroTextStyle: Sendable, Equatable {
    case exciting(fill: FillMode = .solid)
    case wavy(fill: FillMode = .gradient)

    public enum FillMode: Sendable, Equatable {
        case solid
        case gradient
    }

    var fillMode: FillMode {
        switch self {
        case .exciting(let fill), .wavy(let fill):
            return fill
        }
    }

    var font: Font {
        switch self {
        case .exciting:
            return .system(size: 72, weight: .heavy, design: .rounded)
        case .wavy:
            return .system(size: 64, weight: .heavy, design: .rounded)
        }
    }

    var kerning: CGFloat {
        switch self {
        case .exciting:
            return 0.8
        case .wavy:
            return 1.4
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .exciting:
            return 40
        case .wavy:
            return 44
        }
    }

    var contentPadding: EdgeInsets {
        switch self {
        case .exciting:
            return EdgeInsets(top: 36, leading: 56, bottom: 42, trailing: 56)
        case .wavy:
            return EdgeInsets(top: 42, leading: 48, bottom: 48, trailing: 48)
        }
    }

    var fillShapeStyle: AnyShapeStyle {
        switch self {
        case .exciting(let fill):
            switch fill {
            case .solid:
                return AnyShapeStyle(Color.white)
            case .gradient:
                return AnyShapeStyle(Self.primaryFillGradient)
            }
        case .wavy(let fill):
            switch fill {
            case .solid:
                return AnyShapeStyle(Color(red: 0.98, green: 0.98, blue: 1.0))
            case .gradient:
                return AnyShapeStyle(Self.primaryFillGradient)
            }
        }
    }

    var backgroundStyle: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.11, blue: 0.24),
                Color(red: 0.16, green: 0.13, blue: 0.31)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    var borderStyle: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [
                Color.white.opacity(0.45),
                Color.white.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    var borderOpacity: Double { 0.45 }

    var strokeColor: Color {
        switch self {
        case .exciting:
            return Color.black
        case .wavy:
            return Color.white.opacity(0.9)
        }
    }

    var strokeWidth: CGFloat {
        switch self {
        case .exciting:
            return 10
        case .wavy:
            return 6
        }
    }

    var strokeOpacity: Double {
        switch self {
        case .exciting:
            return 1.0
        case .wavy:
            return 0.88
        }
    }

    var slantAngle: CGFloat {
        switch self {
        case .exciting:
            return .pi / 9 // 20°
        case .wavy:
            return .pi / 12
        }
    }

    var shearVariance: CGFloat {
        switch self {
        case .exciting:
            return 0
        case .wavy:
            return 0.24
        }
    }

    var waveAmplitude: CGFloat {
        switch self {
        case .exciting:
            return 0
        case .wavy:
            return 16
        }
    }

    var waveFrequency: CGFloat {
        switch self {
        case .exciting:
            return 0
        case .wavy:
            return 1.05
        }
    }

    var verticalLiftPerLine: CGFloat {
        switch self {
        case .exciting:
            return 0
        case .wavy:
            return 18
        }
    }

    var shadow: ShadowSpec? {
        switch self {
        case .exciting:
            return nil
        case .wavy:
            return ShadowSpec(
                color: Color.black.opacity(0.45),
                radius: 26,
                offset: CGSize(width: 0, height: 18)
            )
        }
    }

    var strokeOffsets: [CGPoint] {
        let radius = max(strokeWidth / 2, 1)
        let sampleCount = max(16, Int(radius * 8))
        var offsets: [CGPoint] = (0..<sampleCount).map { index in
            let angle = (Double(index) / Double(sampleCount)) * (2 * .pi)
            return CGPoint(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
        }
        offsets.append(.zero)
        return offsets
    }

    func prepare(text: AttributedString) -> HeroPreparedText {
        var working = text
        if working.characters.isEmpty {
            working = AttributedString("HERO TEXT")
        }
        return HeroPreparedText(
            renderable: working,
            accessibilityLabel: String(working.characters)
        )
    }

    func shearFactor(progress: CGFloat) -> CGFloat {
        tan(slantAngle) + (progress - 0.5) * shearVariance
    }

    func waveOffset(progress: CGFloat, lineIndex: Int) -> CGFloat {
        guard waveAmplitude > 0 else { return 0 }
        let phase = CGFloat(lineIndex) * 0.85
        return sin(progress * .pi * waveFrequency + phase) * waveAmplitude
    }

    private static var primaryFillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.45, blue: 0.58),
                Color(red: 0.54, green: 0.41, blue: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    struct ShadowSpec {
        var color: Color
        var radius: CGFloat
        var offset: CGSize
    }
}

struct HeroPreparedText {
    var renderable: AttributedString
    var accessibilityLabel: String
}

private struct HeroFillView: View {
    var prepared: HeroPreparedText
    var style: HeroTextStyle

    var body: some View {
        Text(prepared.renderable)
            .font(style.font)
            .italic()
            .kerning(style.kerning)
            .foregroundStyle(style.fillShapeStyle)
            .multilineTextAlignment(.center)
            .textRenderer(HeroFillRenderer(style: style))
    }
}

private struct HeroStrokeView: View {
    var prepared: HeroPreparedText
    var style: HeroTextStyle

    var body: some View {
        Text(prepared.renderable)
            .font(style.font)
            .italic()
            .kerning(style.kerning)
            .foregroundColor(style.strokeColor)
            .multilineTextAlignment(.center)
            .opacity(style.strokeOpacity)
            .textRenderer(HeroStrokeRenderer(style: style))
    }
}

private struct HeroFillRenderer: TextRenderer {
    var style: HeroTextStyle

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        var overallBounds = CGRect.null
        for (lineIndex, line) in layout.enumerated() {
            let slices = line.flattenedSlices
            guard !slices.isEmpty else { continue }
            var lineBounds = CGRect.null
            for slice in slices {
                let rect = slice.typographicBounds.rect
                lineBounds = lineBounds == .null ? rect : lineBounds.union(rect)
            }
            overallBounds = overallBounds == .null ? lineBounds : overallBounds.union(lineBounds)
            for (glyphIndex, slice) in slices.enumerated() {
                let sliceBounds = slice.typographicBounds.rect
                var drawingContext = context
                let progress = CGFloat(glyphIndex) / CGFloat(max(slices.count - 1, 1))
                applyTransforms(
                    &drawingContext,
                    sliceBounds: sliceBounds,
                    lineBounds: lineBounds,
                    overallBounds: overallBounds,
                    progress: progress,
                    lineIndex: lineIndex
                )

                if let shadow = style.shadow {
                    drawingContext.addFilter(
                        .shadow(
                            color: shadow.color,
                            radius: shadow.radius,
                            x: shadow.offset.width,
                            y: shadow.offset.height
                        )
                    )
                }
                drawingContext.draw(slice, options: .disablesSubpixelQuantization)
            }
        }
    }

    private func applyTransforms(
        _ context: inout GraphicsContext,
        sliceBounds: CGRect,
        lineBounds: CGRect,
        overallBounds: CGRect,
        progress: CGFloat,
        lineIndex: Int
    ) {
        let anchor = CGPoint(x: sliceBounds.midX, y: sliceBounds.midY)
        context.translateBy(x: anchor.x, y: anchor.y)

        let shear = style.shearFactor(progress: progress)
        let shearTransform = CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0)
        context.transform = context.transform.concatenating(shearTransform)

        let wave = style.waveOffset(progress: progress, lineIndex: lineIndex)
        context.translateBy(x: 0, y: wave - CGFloat(lineIndex) * style.verticalLiftPerLine)

        if overallBounds.width > lineBounds.width {
            let compensation = (overallBounds.width - lineBounds.width) * 0.004
            context.translateBy(x: -compensation, y: 0)
        }

        context.translateBy(x: -anchor.x, y: -anchor.y)
    }
}

private struct HeroStrokeRenderer: TextRenderer {
    var style: HeroTextStyle

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        guard style.strokeWidth > 0 else { return }
        let offsets = style.strokeOffsets
        for (lineIndex, line) in layout.enumerated() {
            let slices = line.flattenedSlices
            guard !slices.isEmpty else { continue }

            for (glyphIndex, slice) in slices.enumerated() {
                let sliceBounds = slice.typographicBounds.rect
                var drawingContext = context
                drawingContext.opacity = style.strokeOpacity

                let progress = CGFloat(glyphIndex) / CGFloat(max(slices.count - 1, 1))
                applyTransforms(
                    &drawingContext,
                    sliceBounds: sliceBounds,
                    progress: progress,
                    lineIndex: lineIndex
                )

                for offset in offsets {
                    drawingContext.translateBy(x: offset.x, y: offset.y)
                    drawingContext.draw(slice, options: .disablesSubpixelQuantization)
                    drawingContext.translateBy(x: -offset.x, y: -offset.y)
                }
            }
        }
    }

    private func applyTransforms(
        _ context: inout GraphicsContext,
        sliceBounds: CGRect,
        progress: CGFloat,
        lineIndex: Int
    ) {
        let anchor = CGPoint(x: sliceBounds.midX, y: sliceBounds.midY)
        context.translateBy(x: anchor.x, y: anchor.y)

        let shear = style.shearFactor(progress: progress)
        let shearTransform = CGAffineTransform(a: 1, b: 0, c: shear, d: 1, tx: 0, ty: 0)
        context.transform = context.transform.concatenating(shearTransform)

        let wave = style.waveOffset(progress: progress, lineIndex: lineIndex)
        context.translateBy(x: 0, y: wave)

        context.translateBy(x: -anchor.x, y: -anchor.y)
    }
}

private extension Text.Layout.Line {
    var flattenedSlices: [Text.Layout.RunSlice] {
        flatMap { run in run.map { $0 } }
    }
}

#if DEBUG
struct HeroText_Previews: PreviewProvider {
    static var previews: some View {
        HeroText(
            AttributedString("DESIGN YOUR\nNEXT LAUNCH"),
            style: .exciting()
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
{{MARKER_END}}
