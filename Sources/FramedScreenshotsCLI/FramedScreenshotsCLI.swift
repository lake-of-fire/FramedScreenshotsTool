#if os(macOS)
import SwiftUI
import ArgumentParser
import ShotPlan
import FrameKit
import FrameKitLayout

public struct FrameScreen {
    let screenshotMatchingPrefixes: [String]
    let resultFilename: String
    let keyword: String
    let title: String
    let backgroundImage: URL?
}

public struct FramedScreenshotsCLI: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "A utility creating automated framed screenshots with Xcode Test Plans.")
    
    public mutating func run() throws {
        let configurationFromFile = try? ShotPlanConfiguration.load()
        let devices = configurationFromFile?.devices ?? ShotPlanConfiguration.defaultDevices
        
        for device in devices {
            let screenshotsURL = Project.targetDirectoryURL.appending(path: device.description, directoryHint: .isDirectory).appending(path: device.simulatorName, directoryHint: .isDirectory)
            let screens = screens()
            try generateFinalScreens(forDevice: device, screens: screens, screenshots: screenshotsURL, output: screenshotsURL)
        }
    }
    
    public init(from decoder: Decoder) throws {
    }
    
    public init() {
    }
    
    public func screens() -> [FrameScreen] {
        return []
    }
}

func generateFinalScreens(forDevice device: Device, screens: [FrameScreen], screenshots: URL, output: URL) throws {
    let locale = "en_US"
//    let layoutDirection: LayoutDirection = device..isRTL ? .rightToLeft : .leftToRight
    let layoutDirection = LayoutDirection.leftToRight
    //        let layout = layout.value
    var layout: FrameLayout?
    if device.simulatorName == "iPhone 14 Plus" {
        layout = FrameLayout.iPhone14ProMax
    }
    if device.simulatorName == "iPhone 14 Pro Max" {
        layout = FrameLayout.iPhone14ProMax
    }
    if device.simulatorName == "iPhone 8 Plus" {
        layout = FrameLayout.iPhone8Plus
    }
    if device.simulatorName == "iPad Pro (12.9-inch) (6th generation)" {
        layout = FrameLayout.iPadPro129Inch6thGeneration
    }
    if device.simulatorName == "iPad Pro (12.9-inch) (2nd generation)" {
        layout = FrameLayout.iPadPro129Inch2ndGeneration
    }
    guard let layout = layout else { fatalError("Device simulator name \( device.simulatorName) not recognized") }
    
    let temporaryDirectoryURL = URL(
        fileURLWithPath: NSTemporaryDirectory(),
        isDirectory: true)
    
    for screen in screens {
        // Device frame's image needs to be generted separaratedly to make framing logic easy
        let orderedURLs = try? FileManager.default.contentsOfDirectory(at: screenshots, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles).sorted(by: {
            if let date1 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate,
               let date2 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate {
                return date1 < date2
            }
            return false
        })
            .filter { $0.isFileURL && $0.pathExtension.lowercased() == "png" }
        var screenshotURLs = [URL]()
        for namePrefix in screen.screenshotMatchingPrefixes {
            if let url = orderedURLs?.last(where: { $0.lastPathComponent.hasPrefix(namePrefix) }) {
                screenshotURLs.append(url)
            }
        }
        let deviceFrameImages = try screenshotURLs
            .compactMap({ screenshot in
                try DeviceFrame.makeImage(
                    screenshot: screenshot.absoluteString,
                    deviceName:  device.simulatorName,
                    deviceFrameOffset: layout.deviceFrameOffset
                )
            })
        
        let content = FrameContent(
            locale: Locale(identifier: locale),
            keyword: screen.keyword,
            title: screen.title,
            backgroundImage: [screen.backgroundImage].compactMap({ $0 }).compactMap({ NSImage(contentsOfFile: $0.absoluteString) }).first,
            framedScreenshots: deviceFrameImages)
        //framedScreenshots.compactMap { NSImage(contentsOfFile: $0.absoluteString) })
        
        let render = StoreScreenshotRenderer(
            outputPath: output.appending(component: screen.resultFilename).path,
            //            outputPath: temporaryDirectoryURL.appending(component: "\(device.simulatorName) - \(screen.resultFilename)").absoluteString,
            imageFormat: .png,
            layoutDirection: layoutDirection)
        //        if isHero {
        //            try render(SampleHeroStoreScreenshotView.makeView(layout: layout, content: content))
        //        } else {
        try render(SampleStoreScreenshotView.makeView(layout: layout, content: content))
        //        }
        
    }
}
#endif
