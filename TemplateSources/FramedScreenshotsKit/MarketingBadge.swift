import Foundation
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

{{MARKER_START}}
public struct MarketingBadge: View {
    public struct Content: Sendable {
        public var headerSubtitle: String?
        public var headline: String
        public var footerSubtitle: String?

        public init(headerSubtitle: String? = nil, headline: String, footerSubtitle: String? = nil) {
            self.headerSubtitle = headerSubtitle
            self.headline = headline
            self.footerSubtitle = footerSubtitle
        }
    }

    public var content: Content

    public init(content: Content) {
        self.content = content
    }

    public init(headerSubtitle: String? = nil, headline: String, footerSubtitle: String? = nil) {
        self.init(content: Content(headerSubtitle: headerSubtitle, headline: headline, footerSubtitle: footerSubtitle))
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 28) {
            LaurelDecoration(direction: .leading)

            VStack(spacing: 10) {
                if let header = content.headerSubtitle {
                    Text(header)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Text(content.headline)
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .lineSpacing(4)

                if let footer = content.footerSubtitle {
                    Text(footer)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)

            LaurelDecoration(direction: .trailing)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
}
{{MARKER_END}}

private struct LaurelDecoration: View {
    enum Direction { case leading, trailing }

    var direction: Direction

    var body: some View {
        LaurelBranchAsset()
            .frame(width: 110, height: 240)
            .scaleEffect(x: direction == .trailing ? -1 : 1, y: 1)
            .foregroundStyle(.primary.opacity(0.85))
            .accessibilityHidden(true)
    }
}

private struct LaurelBranchAsset: View {
    var body: some View {
#if os(macOS)
        if let image = Self.cachedImage {
            image
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
        } else {
            EmptyView()
        }
#else
        EmptyView()
#endif
    }

#if os(macOS)
    private static let cachedImage: Image? = {
        guard let url = Bundle.module.url(forResource: "Marketing/LaurelBranchLeft", withExtension: "svg"),
              let data = try? Data(contentsOf: url),
              let nsImage = NSImage(data: data) else {
            return nil
        }
        nsImage.isTemplate = true
        return Image(nsImage: nsImage)
    }()
#endif
}
