#if os(macOS)
import SwiftUI
import ArgumentParser
import ShotPlan
import FrameKit
import FrameKitLayout

public struct FramedScreenshotsCLI {
    public static func run(screens: [FrameScreen]) throws {
        var missingDevices = [Device]()
        for device in ShotPlanConfiguration.allDevices {
            let isMissingScreenshots = try generateFinalScreens(forDevice: device, screens: screens, output: device.screenshots)
            if isMissingScreenshots {
                missingDevices.append(device)
            }
        }
        
        let existingDevices: [Device] = ShotPlanConfiguration.allDevices.compactMap { device in missingDevices.contains(where: { missingDevice in return (missingDevice == device) }) ? nil : device }
        
        for device in missingDevices {
            if let replacementDevice = existingDevices.sorted(by: { lhs, rhs in
                let lIdiom = lhs.simulatorName.split(separator: " ").first
                let rIdiom = rhs.simulatorName.split(separator: " ").first
                if let lIdiom = lIdiom, let rIdiom = rIdiom, let dIdiom = device.idiom?.description, lIdiom != dIdiom || rIdiom != dIdiom {
                    if lIdiom != rIdiom {
                        if lIdiom == dIdiom {
                            return true
                        } else if rIdiom == dIdiom {
                            return false
                        }
                    }
                    return lIdiom < rIdiom
                }
                
                let targetSize = Float(device.displaySize ?? "6.5") ?? 0
                return (abs(Float(lhs.displaySize ?? "0") ?? 0).distance(to: targetSize)) < abs((Float(rhs.displaySize ?? "0") ?? 0).distance(to: targetSize)) }).first {
                _ = try generateFinalScreens(forDevice: device, usingDeviceImagesFromDevice: replacementDevice, screens: screens, output: device.screenshots)
            }
        }
    }
    
    static func generateFinalScreens(forDevice device: Device, usingDeviceImagesFromDevice replacementDevice: Device? = nil, screens: [FrameScreen], output: URL) throws -> Bool {
        let locale = "en_US"
    //    let layoutDirection: LayoutDirection = device..isRTL ? .rightToLeft : .leftToRight
        let layoutDirection = LayoutDirection.leftToRight
        //        let layout = layout.value
        var layout: FrameLayout?
        let frameDevice = replacementDevice ?? device
        var frameName = "Apple " + frameDevice.simulatorName
        switch device.idiom {
        case .macbook:
            if device.simulatorName.hasPrefix("Macbook Pro") {
                // TODO: Get new frame for 6th gen. Route to 4th gen until we have a frame.
                layout = FrameLayout.macbookPro13
                frameName = "Apple Macbook Pro 13 Space Gray"
            }
        case .phone:
            if device.simulatorName == "iPhone 14 Pro" {
                layout = FrameLayout.iPhone14Pro
            } else if device.simulatorName == "iPhone 14 Plus" {
                layout = FrameLayout.iPhone14Plus
            } else if device.simulatorName == "iPhone 14 Pro Max" {
                layout = FrameLayout.iPhone14ProMax
            } else if device.simulatorName == "iPhone 8 Plus" {
                layout = FrameLayout.iPhone8Plus
            }
            if frameDevice.simulatorName == "iPhone 14 Pro" {
                frameName += " Black"
            } else if frameDevice.simulatorName == "iPhone 14 Plus" {
                frameName += " Midnight"
            } else if frameDevice.simulatorName == "iPhone 14 Pro Max" {
                frameName += " Black"
            } else if frameDevice.simulatorName == "iPhone 8 Plus" {
                frameName += " Space Gray"
            }
        case .tablet:
            if device.simulatorName == "iPad Pro (12.9-inch) (6th generation)" {
                // TODO: Get new frame for 6th gen. Route to 4th gen until we have a frame.
                layout = FrameLayout.iPadPro129Inch4thGeneration
            } else if device.simulatorName == "iPad Pro (12.9-inch) (4th generation)" {
                layout = FrameLayout.iPadPro129Inch4thGeneration
            } else if device.simulatorName == "iPad Pro (12.9-inch) (2nd generation)" {
                layout = FrameLayout.iPadPro129Inch2ndGeneration
            }
            if frameDevice.simulatorName == "iPad Pro (12.9-inch) (6th generation)" {
                // TODO: Get new frame for 6th gen. Route to 4th gen until we have a frame.
                frameName = "Apple iPad Pro (12.9-inch) (4th generation) Space Gray"
            } else if frameDevice.simulatorName == "iPad Pro (12.9-inch) (4th generation)" {
                frameName += " Space Gray"
            } else if frameDevice.simulatorName == "iPad Pro (12.9-inch) (2nd generation)" {
                frameName += " Space Gray"
            }
        default: break
        }
        guard let layout = layout else { fatalError("Device name \(device.simulatorName) not recognized") }
        
        for screen in screens {
            var layout = layout
            if let backgroundColor = screen.backgroundColor {
                layout.backgroundColor = backgroundColor
            }
            // Device frame's image needs to be generted separaratedly to make framing logic easy
            let orderedURLs = try? FileManager.default.contentsOfDirectory(at: (replacementDevice ?? device).screenshots, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles).sorted(by: {
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
                sfSymbol: screen.sfSymbol,
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
            if screen.screenshotMatchingPrefixes.isEmpty {
                try render(SFSymbolView.makeView(layout: layout, content: content, deviceIdiom: device.idiom))
            } else {
                try render(SampleStoreScreenshotView.makeView(layout: layout, content: content, deviceIdiom: device.idiom))
            }
            //        }
        }
        return false
    }
}
#endif
