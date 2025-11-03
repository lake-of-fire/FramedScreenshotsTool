#if os(macOS)
import AppKit
import SwiftUI
import ShotPlan

/// `DeviceFrame` provides a way to embed app screenshot into device frame image.
public struct DeviceFrame {
    public enum Error: Swift.Error {
        case fileNotFound(String)
    }

    /// To make an NSImage object that has image combining store screenshot and device frame image togther
    /// - Parameters:
    ///   - screenshot: A relative or absolute path to app screenshot image file
    ///   - deviceName: Name of device with frame contained in module bundle
    ///   - deviceFrameOffset: Offset to adjust the position of app screenshot
    /// - Returns: an image object. `nil` if something went wrong.
    @MainActor
    public static func makeImage(screenshot: String, deviceName: String, deviceFrameOffset: CGSize) throws -> NSImage? {
        guard let screenshotImage = NSImage(contentsOfFile: absolutePath(screenshot)) else {
            throw Error.fileNotFound("screenshot was not found at \(screenshot)")
        }

        let deviceName = deviceName + ".png"
        guard let deviceFrameImage = Bundle.module.image(forResource: deviceName) else {
            let fm = FileManager.default
            let path = Bundle.module.resourcePath!
            let items = try! fm.contentsOfDirectory(atPath: path)
            var s = ""
            for item in items {
                s += " // " + item
            }
            throw Error.fileNotFound("device frame was not found for name \(deviceName) from choices: \(s)")
        }
        
        var deviceIdiom = Device.Idiom.phone
        if deviceName.starts(with: "Apple Macbook") {
            deviceIdiom = .macbook
        } else if deviceName.starts(with: "Apple iPad") {
            deviceIdiom = .tablet
        } else if deviceName.starts(with: "Apple Watch") {
            deviceIdiom = .watch
        }

        // Device frame's image needs to be generted separaratedly to make framing logic easy
        return makeDeviceFrameImage(
            screenshot: screenshotImage,
            deviceIdiom: deviceIdiom,
            deviceFrame: deviceFrameImage,
            deviceFrameOffset: deviceFrameOffset
        )
    }

    @MainActor
    public static func makeDeviceFrameImage(screenshot: NSImage, deviceIdiom: Device.Idiom, deviceFrame: NSImage, deviceFrameOffset: CGSize) -> NSImage? {
        let pngData = makeDeviceFrameData(screenshot: screenshot, deviceIdiom: deviceIdiom, deviceFrame: deviceFrame, deviceFrameOffset: deviceFrameOffset)
        return pngData.flatMap { NSImage(data: $0) }
    }

    @MainActor
    public static func makeDeviceFrameData(screenshot: NSImage, deviceIdiom: Device.Idiom, deviceFrame: NSImage, deviceFrameOffset: CGSize) -> Data? {
        var deviceFrame = deviceFrame
        if deviceIdiom == .macbook {
            deviceFrame = trim(image: deviceFrame, rect: CGRect(x: 0, y: 150, width: deviceFrame.size.width, height: deviceFrame.size.height - 150))
        }
        let deviceFrameView = DeviceFrameView(
            deviceIdiom: deviceIdiom,
            deviceFrame: deviceFrame,
            screenshot: screenshot,
            offset: deviceFrameOffset
        )
        let view = NSHostingView(rootView: deviceFrameView)
        view.layer?.contentsScale = 1.0
        view.frame = CGRect(x: 0, y: 0, width: deviceFrame.size.width, height: deviceFrame.size.height)

        // Use png here to use alpha layer
        return convertToImage(view: view, format: .png)
    }
    
    @MainActor
    private static func trim(image: NSImage, rect: CGRect) -> NSImage {
        let result = NSImage(size: rect.size)
        result.lockFocus()

        let destRect = CGRect(origin: .zero, size: result.size)
        image.draw(in: destRect, from: rect, operation: .copy, fraction: 1.0)

        result.unlockFocus()
        return result
    }
}
#endif
