import Foundation

{{MARKER_START}}
public protocol FramedScreenshotsCatalogProviding {
    static func register(into registry: inout ScreenshotRegistry)
}

public enum ScreenshotCatalogBuilder {
    public static func build(into registry: inout ScreenshotRegistry) {
        FramedScreenshots.register(into: &registry)
    }
}
{{MARKER_END}}
