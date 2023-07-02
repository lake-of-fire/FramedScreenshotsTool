#if os(macOS)
import SwiftUI
import ShotPlan

/// The SwiftUI View struct that is used in `DeviceImage`.
///
/// Currently this view layout relies on the fact that iPhone's vessel size match other side of it.
/// So that we can simply put a screenshot image onto the center of a device frame image! Thanks, Steve.
/// If we need to deal with asymmetry devices or images (e.g. iPhone 5c having lock button on its top),
/// we need to adjust the position of screenshot with offset to account of buttons.
public struct DeviceFrameView: View {
    public let deviceIdiom: Device.Idiom
    public let deviceFrame: NSImage
    public let screenshot: NSImage
    public let offset: CGSize

    public init(deviceIdiom: Device.Idiom, deviceFrame: NSImage, screenshot: NSImage, offset: CGSize = .zero) {
        self.deviceIdiom = deviceIdiom
        self.deviceFrame = deviceFrame
        self.screenshot = screenshot
        self.offset = offset
    }

    var screenshotSize: CGSize {
        switch deviceIdiom {
        case .macbook:
            return CGSize(width: screenshot.size.width * 2, height: screenshot.size.height * 2)
        default:
            return screenshot.size
        }
    }
    
    public var body: some View {
        // Two images are combined by overlapping each other on ZStack
        ZStack {
            Image(nsImage: screenshot)
                .resizable()
                .frame(width: screenshotSize.width, height: screenshotSize.height)
                .offset(self.offset)
            Image(nsImage: deviceFrame)
                .resizable()
                .frame(width: deviceFrame.size.width, height: deviceFrame.size.height)
            HStack {
                Text("\(screenshot.size.width)")
                Text("\(screenshot.size.height)")
                Text("\(deviceFrame.size.width)")
                Text("\(deviceFrame.size.height)")
            }
        }
    }
}
#endif
