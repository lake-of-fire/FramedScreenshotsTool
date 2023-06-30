#if os(macOS)
import SwiftUI
import FrameKit

public enum FrameLayoutOption: String, RawRepresentable, LayoutProviderOption {
    case iPhone14Plus = "iPhone 14 Plus Midnight"
    case iPhone14ProMax = "iPhone 14 Pro Max Black"
    case iPhone8Plus = "iPhone 8 Plus Space Gray"
    case iPadPro129Inch4thGeneration = "iPad Pro (12.9-inch) (4th generation) Space Gray"
    case iPadPro129Inch2ndGeneration = "iPad Pro (12.9-inch) (2nd generation) Space Gray"

    public init?(argument: String) {
        self.init(rawValue: argument)
    }

    public var value: FrameLayout {
        switch self {
        case .iPhone14Plus: return .iPhone14Plus
        case .iPhone14ProMax: return .iPhone14ProMax
        case .iPhone8Plus: return .iPhone8Plus
        case .iPadPro129Inch4thGeneration: return .iPadPro129Inch4thGeneration
        case .iPadPro129Inch2ndGeneration: return .iPadPro129Inch2ndGeneration
        }
    }
}

public struct FrameContent {
    public let locale: Locale
    public let keyword: String
    public let title: String
    public let backgroundImage: NSImage?
    public let framedScreenshots: [FramedScreenshot]

    public struct FramedScreenshot: Identifiable {
        public let id: URL
        public let image: NSImage
        
        public init(id: URL, image: NSImage) {
            self.id = id
            self.image = image
        }
    }
    
    public init(locale: Locale, keyword: String, title: String, backgroundImage: NSImage? = nil, framedScreenshots: [FramedScreenshot]) {
        self.locale = locale
        self.keyword = keyword
        self.title = title
        self.backgroundImage = backgroundImage
        self.framedScreenshots = framedScreenshots
    }
}

public struct FrameLayout: LayoutProvider {
    public let size: CGSize
    public let deviceFrameOffset: CGSize
    public let textInsets: EdgeInsets
    public let imageInsets: EdgeInsets
    public let keywordFontSize: CGFloat
    public let titleFontSize: CGFloat
    public let textGap: CGFloat
    public let textColor: Color
    public var backgroundColor: Color

    public init(
        size: CGSize,
        deviceFrameOffset: CGSize,
        textInsets: EdgeInsets,
        imageInsets: EdgeInsets,
        keywordFontSize: CGFloat,
        titleFontSize: CGFloat,
        textGap: CGFloat,
        textColor: Color,
        backgroundColor: Color
    ) {
        self.size = size
        self.deviceFrameOffset = deviceFrameOffset
        self.textInsets = textInsets
        self.imageInsets = imageInsets
        self.keywordFontSize = keywordFontSize
        self.titleFontSize = titleFontSize
        self.textGap = textGap
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
}

public struct FrameScreen {
    public let screenshotMatchingPrefixes: [String]
    public let resultFilename: String
    public let keyword: String
    public let title: String
    public let backgroundImage: URL?
    public let backgroundColor: Color?
    
    public init(screenshotMatchingPrefixes: [String], resultFilename: String, keyword: String, title: String, backgroundImage: URL? = nil, backgroundColor: Color?) {
        self.screenshotMatchingPrefixes = screenshotMatchingPrefixes
        self.resultFilename = resultFilename
        self.keyword = keyword
        self.title = title
        self.backgroundImage = backgroundImage
        self.backgroundColor = backgroundColor
    }
}

extension FrameLayout {
    public static let defaultBackgroundColor = Color(red: 255 / 255, green: 153 / 255, blue: 51 / 255)

    public static let iPhone14Plus = Self(
        size: CGSize(width: 1284, height: 2778),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 36, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: -500, trailing: 84),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )
    
    public static let iPhone14ProMax = Self(
        size: CGSize(width: 1290, height: 2796),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 36, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: -500, trailing: 84),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPhone8Plus = Self(
        size: CGSize(width: 1242, height: 2208),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 48, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 150, bottom: -200, trailing: 150),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPadPro129Inch4thGeneration = Self(
        size: CGSize(width: 2048, height: 2732),
        deviceFrameOffset: CGSize(width: -1, height: 1),
        textInsets: EdgeInsets(top: 48, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 96, bottom: -200, trailing: 96),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPadPro129Inch2ndGeneration = Self(
        size: CGSize(width: 2048, height: 2732),
        deviceFrameOffset: CGSize(width: -1, height: 1),
        textInsets: EdgeInsets(top: 48, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 96, bottom: -200, trailing: 96),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )
}

//extension SampleLayout {
//    public static let iPhone14ProMax = Self(
//        size: CGSize(width: 1242, height: 2688),
//        deviceFrameOffset: .zero,
//        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
//        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: 96, trailing: 84),
//        keywordFontSize: 108,
//        titleFontSize: 0,
//        textGap: 24,
//        textColor: .white,
//        backgroundColor: defaultBackgroundColor
//    )
//
//    public static let iPhone55Hero = Self(
//        size: CGSize(width: 1242, height: 2208),
//        deviceFrameOffset: .zero,
//        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
//        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: 96, trailing: 84),
//        keywordFontSize: 108,
//        titleFontSize: 0,
//        textGap: 24,
//        textColor: .white,
//        backgroundColor: defaultBackgroundColor
//    )
//
//    public static let iPadProHero = Self(
//        size: CGSize(width: 2048, height: 2732),
//        deviceFrameOffset: .zero,
//        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
//        imageInsets: EdgeInsets(top: 0, leading: 150, bottom: 148, trailing: 150),
//        keywordFontSize: 108,
//        titleFontSize: 0,
//        textGap: 24,
//        textColor: .white,
//        backgroundColor: defaultBackgroundColor
//    )
//
//    public static let iPadPro3rdGenHero = Self(
//        size: CGSize(width: 2048, height: 2732),
//        deviceFrameOffset: CGSize(width: -1, height: 1),
//        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
//        imageInsets: EdgeInsets(top: 0, leading: 96, bottom: 148, trailing: 96),
//        keywordFontSize: 108,
//        titleFontSize: 0,
//        textGap: 24,
//        textColor: .white,
//        backgroundColor: defaultBackgroundColor
//    )
//}

extension StoreScreenshotView where Self.Layout == FrameLayout {
    var keywordFont: Font { Font.system(size: layout.keywordFontSize, weight: .bold, design: .rounded) }
    var titleFont: Font { Font.system(size: layout.titleFontSize, weight: .regular, design: .default) }
}

public struct SampleStoreScreenshotView: StoreScreenshotView {
    public let layout: FrameLayout
    public let content: FrameContent

    public static func makeView(layout: FrameLayout, content: FrameContent) -> Self {
        Self(layout: layout, content: content)
    }

    public init(layout: FrameLayout, content: FrameContent) {
        self.layout = layout
        self.content = content
    }

    public var body: some View {
        ZStack {
            // Background Color
            layout.backgroundColor

            // Background Image
//            content.backgroundImage.map { backgroundImage in
//                Image(nsImage: backgroundImage)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//            }
            VStack(spacing: 0) {
                // Text
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: layout.textGap) {
                        Text(content.keyword)
                            .font(keywordFont)
                            .foregroundColor(layout.textColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                        
                        Text(content.title)
                            .font(titleFont)
                            .foregroundColor(layout.textColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(self.layout.textInsets)
                }
                
                Spacer(minLength: 0)
                
                // Image
                ForEach(content.framedScreenshots, id: \.id) { framedScreenshot in
                    HStack(alignment: .bottom) {
                        Image(nsImage: framedScreenshot.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(layout.imageInsets)
                }
            }
        }
    }
}

public struct SampleHeroStoreScreenshotView: StoreScreenshotView {
    public let layout: FrameLayout
    public let content: FrameContent

    public static func makeView(layout: FrameLayout, content: FrameContent) -> Self {
        Self(layout: layout, content: content)
    }

    public init(layout: FrameLayout, content: FrameContent) {
        self.layout = layout
        self.content = content
    }

    public var body: some View {
        ZStack {
            // Background Colour
            layout.backgroundColor

            // Background Image
            content.backgroundImage.map { backgroundImage in
                Image(nsImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Images
            GeometryReader() { geometry in
                ZStack {
                    HStack(alignment: .center, spacing: 10) {
                        Image(nsImage: content.framedScreenshots[1].image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width / 2.6)

                        Spacer()

                        Image(nsImage: content.framedScreenshots[2].image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width / 2.6)
                    }

                    Image(nsImage: content.framedScreenshots[0].image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width / 2.2, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(self.layout.imageInsets)
            }

            // Text
            HStack {
                Text(content.keyword)
                    .font(keywordFont)
                    .foregroundColor(self.layout.textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(self.layout.textInsets)
        }
    }
}
#endif
