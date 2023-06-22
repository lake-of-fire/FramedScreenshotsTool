import Foundation
import SwiftUI
import PackagePlugin
import XcodeProjectPlugin
import FrameKit

func takeScreenshots(for directory: PackagePlugin.Path, shotplan: PluginContext.Tool) throws {
    // ShotPlan
    let shotplanURL = URL(fileURLWithPath: shotplan.path.string)
    var errors: String = ""
    let stdout = Pipe()
    let stderr = Pipe()
    var stdoutData = Data.init(capacity: 8192)
    var stderrData = Data.init(capacity: 8192)
    let process = Process()
    process.currentDirectoryURL = URL(fileURLWithPath: directory.string)
    process.executableURL = shotplanURL
    process.arguments = ["run"]
    try process.run()
    while process.isRunning {
        stdoutData.append(stdout.fileHandleForReading.readDataToEndOfFile())
        stderrData.append(stderr.fileHandleForReading.readDataToEndOfFile())
    }
    process.waitUntilExit()
    let gracefulExit = process.terminationReason == .exit && process.terminationStatus == 0
    if !gracefulExit {
        Diagnostics.error("🛑 The plugin execution failed")
    }
    stdoutData.append(stdout.fileHandleForReading.readDataToEndOfFile())
    errors = String(decoding: stderrData, as: UTF8.self) + String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    if !errors.isEmpty {
        print(errors)
    }
    let screenshotsURL = shotplanURL.deletingLastPathComponent().appendingPathComponent("Screenshots", isDirectory: true)
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [screenshotsURL.absoluteString]
    try process.run()
}

struct FramesConfig {
    let isRTL: Bool
}

func generateFrames(for directory: PackagePlugin.Path, configs: [FramesConfig]) throws {
    for config in configs {
        let layoutDirection: LayoutDirection = config.isRTL ? .rightToLeft : .leftToRight
        let layout = layout.value
        
        // Device frame's image needs to be generted separaratedly to make framing logic easy
        let framedScreenshots = try screenshots.compactMap({ screenshot in
            try DeviceFrame.makeImage(
                screenshot: absolutePath(screenshot),
                deviceFrame: absolutePath(deviceFrame),
                deviceFrameOffset: layout.deviceFrameOffset
            )
        })
        
        let content = SampleContent(
            locale: Locale(identifier: locale),
            keyword: keyword,
            title: title,
            backgroundImage: backgroundImage.flatMap({ NSImage(contentsOfFile: absolutePath($0)) }),
            framedScreenshots: framedScreenshots
        )
        
        let render = StoreScreenshotRenderer(outputPath: output, imageFormat: .jpeg, layoutDirection: layoutDirection)
        if isHero {
            try render(SampleHeroStoreScreenshotView.makeView(layout: layout, content: content))
        } else {
            try render(SampleStoreScreenshotView.makeView(layout: layout, content: content))
        }
    }
}

extension FramedScreenshotsTool: XcodeCommandPlugin {
    /// This entry point is called when operating on an Xcode project.
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let configs = [
            FramesConfig(isRTL: false)
        ]
        try takeScreenshots(for: context.xcodeProject.directory, shotplan: context.tool(named: "shotplan"))
        try generateFrames(for: context.xcodeProject.directory, configs: [configs])
    }
}

public enum FrameLayoutOption: String, RawRepresentable, ExpressibleByArgument, LayoutProviderOption {
    case iPhone14Plus = "iPhone 14 Plus"
    case iPhone14ProMax = "iPhone 14 Pro Max"
    case iPhone8Plus = "iPhone 8 Plus"
    case iPadPro129Inch6thGeneration = "iPad Pro (12.9-inch) (6th generation)"
    case iPadPro129Inch2ndGeneration = "iPad Pro (12.9-inch) (2nd generation)"

    public init?(argument: String) {
        self.init(rawValue: argument)
    }

    public var value: FrameLayout {
        switch self {
        case .iPhone14Plus: return .iPhone14Plus
        case .iPhone14ProMax: return .iPhone14ProMax
        case .iPhone8Plus: return .iPhone8Plus
        case .iPadPro129Inch6thGeneration: return .iPadPro129Inch6thGeneration
        case .iPadPro129Inch2ndGeneration: return .iPadPro129Inch2ndGeneration
        }
    }
}

public struct SampleContent {
    public let locale: Locale
    public let keyword: String
    public let title: String
    public let backgroundImage: NSImage?
    public let framedScreenshots: [NSImage]

    public init(locale: Locale, keyword: String, title: String, backgroundImage: NSImage? = nil, framedScreenshots: [NSImage]) {
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
    public let backgroundColor: Color

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

extension FrameLayout {
    public static let defaultBackgroundColor = Color(red: 255 / 255, green: 153 / 255, blue: 51 / 255)

    public static let iPhone65 = Self(
        size: CGSize(width: 1242, height: 2688),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 72, leading: 120, bottom: 0, trailing: 120),
        imageInsets: EdgeInsets(top: 0, leading: 128, bottom: 72, trailing: 128),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPhone55 = Self(
        size: CGSize(width: 1242, height: 2208),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 36, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: -500, trailing: 84),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPadPro = Self(
        size: CGSize(width: 2048, height: 2732),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 48, leading: 96, bottom: 0, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 150, bottom: -200, trailing: 150),
        keywordFontSize: 148,
        titleFontSize: 72,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPadPro3rdGen = Self(
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

extension SampleLayout {
    public static let iPhone65Hero = Self(
        size: CGSize(width: 1242, height: 2688),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: 96, trailing: 84),
        keywordFontSize: 108,
        titleFontSize: 0,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPhone55Hero = Self(
        size: CGSize(width: 1242, height: 2208),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 84, bottom: 96, trailing: 84),
        keywordFontSize: 108,
        titleFontSize: 0,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPadProHero = Self(
        size: CGSize(width: 2048, height: 2732),
        deviceFrameOffset: .zero,
        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 150, bottom: 148, trailing: 150),
        keywordFontSize: 108,
        titleFontSize: 0,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )

    public static let iPadPro3rdGenHero = Self(
        size: CGSize(width: 2048, height: 2732),
        deviceFrameOffset: CGSize(width: -1, height: 1),
        textInsets: EdgeInsets(top: 0, leading: 96, bottom: 240, trailing: 96),
        imageInsets: EdgeInsets(top: 0, leading: 96, bottom: 148, trailing: 96),
        keywordFontSize: 108,
        titleFontSize: 0,
        textGap: 24,
        textColor: .white,
        backgroundColor: defaultBackgroundColor
    )
}

extension StoreScreenshotView where Self.Layout == SampleLayout {
    var keywordFont: Font { Font.system(size: layout.keywordFontSize, weight: .bold, design: .default) }
    var titleFont: Font { Font.system(size: layout.titleFontSize, weight: .regular, design: .default) }
}

public struct SampleStoreScreenshotView: StoreScreenshotView {
    public let layout: SampleLayout
    public let content: SampleContent

    public static func makeView(layout: SampleLayout, content: SampleContent) -> Self {
        Self(layout: layout, content: content)
    }

    public init(
        layout: SampleLayout,
        content: SampleContent
    ) {
        self.layout = layout
        self.content = content
    }

    public var body: some View {
        ZStack {
            // Background Color
            layout.backgroundColor

            // Background Image
            content.backgroundImage.map { backgroundImage in
                Image(nsImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }

            // Image
            HStack(alignment: .bottom) {
                Image(nsImage: content.framedScreenshots[0])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(layout.imageInsets)

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
        }
    }
}

public struct SampleHeroStoreScreenshotView: StoreScreenshotView {
    public let layout: SampleLayout
    public let content: SampleContent

    public static func makeView(layout: SampleLayout, content: SampleContent) -> Self {
        Self(layout: layout, content: content)
    }

    public init(
        layout: SampleLayout,
        content: SampleContent
    ) {
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
                        Image(nsImage: content.framedScreenshots[1])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width / 2.6)

                        Spacer()

                        Image(nsImage: content.framedScreenshots[2])
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width / 2.6)
                    }

                    Image(nsImage: content.framedScreenshots[0])
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
