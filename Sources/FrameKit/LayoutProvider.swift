#if os(macOS)
import Foundation

// This is the minimal requirement to be able to work with `Frameit.run`
public protocol LayoutProvider {
    var size: CGSize { get }
    var deviceFrameOffset: CGSize { get }
}
#endif
