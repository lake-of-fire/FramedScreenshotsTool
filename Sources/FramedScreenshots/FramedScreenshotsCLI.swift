#if os(macOS)
import SwiftUI
import ArgumentParser
import ShotPlan
import FrameKit
import FrameKitLayout

public struct FramedScreenshotsCLI {
    public static func run(screens: [FrameScreen]) throws {
        var missingDevices = [Device]()
        for device in ShotPlanConfiguration.appleRequiredDevices {
            let isMissingScreenshots = try generateFinalScreens(forDevice: device, screens: screens, output: device.screenshots)
            if isMissingScreenshots {
                missingDevices.append(device)
            }
        }
        let existingDevices: [Device] = ShotPlanConfiguration.appleRequiredDevices.compactMap { device in missingDevices.contains(where: { missingDevice in return (missingDevice == device) }) ? nil : device }
        for device in missingDevices {
            let targetSize = Float(device.displaySize ?? "6.5") ?? 0
            if let replacementDevice = existingDevices.sorted(by: { (Float($0.displaySize ?? "0") ?? 0).distance(to: targetSize) < (Float($1.displaySize ?? "0") ?? 0).distance(to: targetSize) }).first {
                _ = try generateFinalScreens(forDevice: replacementDevice, screens: screens, output: device.screenshots)
            }
        }

    }
    
    static func generateFinalScreens(forDevice device: Device, screens: [FrameScreen], output: URL) throws -> Bool {
        let locale = "en_US"
    //    let layoutDirection: LayoutDirection = device..isRTL ? .rightToLeft : .leftToRight
        let layoutDirection = LayoutDirection.leftToRight
        //        let layout = layout.value
        var layout: FrameLayout?
        var frameName = "Apple " + device.simulatorName
        if device.simulatorName == "iPhone 14 Plus" {
            layout = FrameLayout.iPhone14ProMax
            frameName += " Midnight"
        } else if device.simulatorName == "iPhone 14 Pro Max" {
            layout = FrameLayout.iPhone14ProMax
            frameName += " Black"
        } else if device.simulatorName == "iPhone 8 Plus" {
            layout = FrameLayout.iPhone8Plus
            frameName += " Space Gray"
        } else if device.simulatorName == "iPad Pro (12.9-inch) (4th generation)" {
            layout = FrameLayout.iPadPro129Inch4thGeneration
            frameName += " Space Gray"
        }
//        if device.simulatorName == "iPad Pro (12.9-inch) (6th generation)" {
//            layout = FrameLayout.iPadPro129Inch6thGeneration
//            frameName += " Space Gray"
//        }
        if device.simulatorName == "iPad Pro (12.9-inch) (2nd generation)" {
            layout = FrameLayout.iPadPro129Inch2ndGeneration
            frameName += " Space Gray"
        }
        guard let layout = layout else { fatalError("Device simulator name \(device.simulatorName) not recognized") }
        
        for screen in screens {
            var layout = layout
            if let backgroundColor = screen.backgroundColor {
                layout.backgroundColor = backgroundColor
            }
            // Device frame's image needs to be generted separaratedly to make framing logic easy
            let orderedURLs = try? FileManager.default.contentsOfDirectory(at: device.screenshots, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles).sorted(by: {
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
            
            guard screenshotURLs.count >= screen.screenshotMatchingPrefixes.count else {
                return true
            }
            
            let deviceFrameImages: [FrameContent.FramedScreenshot] = try screenshotURLs
                .compactMap { screenshot in
                    guard let image = try DeviceFrame.makeImage(
                        screenshot: screenshot.path,
                        deviceName: frameName,
                        deviceFrameOffset: layout.deviceFrameOffset
                    ) else { return nil }
                    return FrameContent.FramedScreenshot(id: screenshot, image: image)
                }
            
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
        return false
    }
}
#endif
