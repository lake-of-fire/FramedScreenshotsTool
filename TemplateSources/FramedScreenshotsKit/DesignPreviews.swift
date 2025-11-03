import SwiftUI

{{MARKER_START}}
@available(macOS 14.0, *)
struct FramedScreenshotsDesignPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            HeroText(AttributedString("LOCALIZE\nAPP PRICES"), style: .exciting())
                .padding()
                .background(Color.blue)
                .previewDisplayName("Hero Text – Exciting")

            HeroText(AttributedString("HIGHLIGHT YOUR\nTOP FEATURES"), style: .wavy())
                .padding()
                .background(Color.purple.opacity(0.4))
                .previewDisplayName("Hero Text – Wavy")

            HighlightsText(sampleHighlightedString)
                .padding()
                .background(Color.green.opacity(0.2))
                .previewDisplayName("Highlights Text")

            MarketingBadge(
                headerSubtitle: "Editor's Choice",
                headline: "Rated Best New App\nIn 173 Countries",
                footerSubtitle: "Featured Worldwide"
            )
            .padding()
            .background(Color.blue.opacity(0.16))
            .previewDisplayName("Marketing Badge")

           FocusedScreenshotOverlay(
                screenshotName: "example",
                borderColor: .pink,
                dimming: .dimmed(amount: FocusedScreenshotOverlay.Dimming.defaultAmount),
                focusShadow: .default,
                borderStyle: .init(color: .white, width: 6)
            )
            .padding()
            .frame(height: 520)
            .background(Color.black.opacity(0.85))
            .previewDisplayName("Focused Overlay")
        }
    }

    private static var sampleHighlightedString: AttributedString {
        var attributed = AttributedString("Just take a picture in seconds")
        if let range = attributed.range(of: "picture") {
            attributed[range].framedScreenshots.highlight = HighlightMark()
        }
        if let range = attributed.range(of: "seconds") {
            attributed[range].framedScreenshots.highlight = HighlightMark(
                background: HighlightColor(red: 0.22, green: 0.27, blue: 0.93),
                foreground: HighlightColor(red: 1, green: 1, blue: 1),
                useSourceColor: false,
                tiltDegrees: -7.5,
                horizontalInset: 18,
                verticalInset: 10,
                cornerRadius: 28,
                shadowRadius: 14,
                shadowOpacity: 0.25,
                shadowYOffset: 10,
                knockout: true
            )
        }
        return attributed
    }
}
{{MARKER_END}}
