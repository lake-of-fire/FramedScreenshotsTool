import AppKit
import Foundation
import SwiftUI

{{MARKER_START}}
public enum ViewPNGWriter {
    public enum WriterError: Error, CustomStringConvertible {
        case failedToProduceImage

        public var description: String {
            switch self {
            case .failedToProduceImage:
                return "ImageRenderer did not produce an image. Ensure the SwiftUI view has a non-empty body."
            }
        }
    }

    @MainActor
    public static func write<V: View>(
        view: V,
        to url: URL,
        colorScheme: ColorScheme?,
        scale: CGFloat,
        proposedSize: CGSize?,
        locale: Locale? = nil
    ) throws {
        var content: AnyView = AnyView(view)
        if let locale {
            content = AnyView(content.environment(\.locale, locale))
        }
        let appliedScheme = colorScheme ?? .light
        content = AnyView(content.environment(\.colorScheme, appliedScheme))

        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        if let proposedSize {
            renderer.proposedSize = ProposedViewSize(width: proposedSize.width, height: proposedSize.height)
        }

        guard let image = renderer.nsImage else {
            throw WriterError.failedToProduceImage
        }

        try image.ensureDirectoryAndWritePNG(to: url)
    }
}

private extension NSImage {
    func ensureDirectoryAndWritePNG(to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw ViewPNGWriter.WriterError.failedToProduceImage
        }
        try pngData.write(to: url, options: .atomic)
    }
}
{{MARKER_END}}
