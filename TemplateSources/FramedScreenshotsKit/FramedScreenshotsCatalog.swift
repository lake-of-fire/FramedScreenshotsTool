import SwiftUI

{{MARKER_START}}
public enum FramedScreenshots: FramedScreenshotsCatalogProviding {
    public static func register(into registry: inout ScreenshotRegistry) {
        // Register your SwiftUI views here. Example:
        //
        // registry.register(identifier: "home-light") { context in
        //     ExampleScreenshotView(locale: context.locale)
        // }
    }
}
{{MARKER_END}}
