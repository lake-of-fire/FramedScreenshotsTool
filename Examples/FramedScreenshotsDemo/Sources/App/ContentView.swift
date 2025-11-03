import SwiftUI
import FramedScreenshotsKit

struct ContentView: View {
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 40) {
                    HeroText(AttributedString("LOCALIZE\nAPP PRICES"), style: .exciting())
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(Color.blue.gradient.opacity(0.85))
                        .cornerRadius(36)

                    MarketingBadge(
                        headerSubtitle: "Editor's Choice",
                        headline: "Manage Your Dopamine\nWith DIGITAL THERAPEUTICS",
                        footerSubtitle: "Featured Worldwide"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Color.cyan.opacity(0.18))
                    .cornerRadius(36)

                    HighlightsText(highlightedSample)
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(28)
                }
                .frame(maxWidth: proxy.size.width)
                .padding(.horizontal, 32)
                .padding(.vertical, 48)
            }
            .background(Color(white: 0.12))
        }
    }

    var highlightedSample: AttributedString {
        var attributed = AttributedString("Just take a picture in seconds")
        if let range = attributed.range(of: "picture") {
            attributed[range].foregroundColor = .black
            attributed[range].framedScreenshots.highlight = .inverted(color: .black.opacity(0.85))
        }
        return attributed
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 430, height: 932)
    }
}
