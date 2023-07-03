#if os(macOS)
import SwiftUI
import ShotPlan

public protocol StoreScreenshotView: View {
    associatedtype Layout: LayoutProvider
    associatedtype Content

    var layout: Layout { get }
    var content: Content { get }
    var deviceIdiom: Device.Idiom? { get }
    static func makeView(layout: Layout, content: Content, deviceIdiom: Device.Idiom?) -> Self
}
#endif
