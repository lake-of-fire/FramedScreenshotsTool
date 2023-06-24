import SwiftUI
import ArgumentParser
import shotplan
import FrameKit
import FrameKitLayout

@main
struct FramedScreenshotsCLI: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A utility creating automated framed screenshots with Xcode Test Plans.",
        subcommands: [Run.self],
        defaultSubcommand: Run.self)
    
    mutating func run() {
    }
}

extension FramedScreenshotsCLI {
    struct Run: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Starts creating screenshots based on your configuration.")
        
        mutating func run() {
            let configurationFromFile = try? ShotPlan.Configuration.load()
            let devices = configurationFromFile?.devices ?? ShotPlan.Configuration.defaultDevices
            
            do {
                for device in devices {
                    let screenshotsURL = Project.targetDirectoryURL.appending(path: device.description, directoryHint: .isDirectory).appending(path: device.simulatorName, directoryHint: .isDirectory)
                    let screens = [
                        FrameScreen(keyword: "", title: "", backgroundImage: nil)
                    ]
                    try generateFinalScreens(forDevice: device, screens: screens, screenshots: screenshotsURL, output: screenshotsURL)
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
}

struct FrameScreen {
    let keyword: String
    let title: String
    let backgroundImage: URL?
//    let screenshotName
}

func walkDirectory(at url: URL, options: FileManager.DirectoryEnumerationOptions) -> AsyncStream<URL> {
    AsyncStream { continuation in
        Task {
            let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: options)
                
            while let fileURL = enumerator?.nextObject() as? URL {
                if fileURL.hasDirectoryPath {
                    for await item in walkDirectory(at: fileURL, options: options) {
                        continuation.yield(item)
                    }
                } else {
                    continuation.yield( fileURL )
                }
            }
            continuation.finish()
        }
    }
}

func generateFinalScreens(forDevice device: Device, screens: [FrameScreen], screenshots: URL, output: URL) throws {
    let locale = "en_US"
//    let layoutDirection: LayoutDirection = device..isRTL ? .rightToLeft : .leftToRight
    let layoutDirection = LayoutDirection.leftToRight
    //        let layout = layout.value
    var layout: FrameLayout?
    if device.simulatorName == "iPhone 14 Pro Max" {
        layout = FrameLayout.iPhone14ProMax
    }
    if device.simulatorName == "iPhone 8 Plus" {
        layout = FrameLayout.iPhone8Plus
    }
    if device.simulatorName == "iPad Pro (12.9-inch) (6th Generation)" {
        layout = FrameLayout.iPadPro129Inch6thGeneration
    }
    if device.simulatorName == "iPad Pro (12.9-inch) (2nd Generation)" {
        layout = FrameLayout.iPadPro129Inch2ndGeneration
    }
    guard let layout = layout else { fatalError("Device simulator name \( device.simulatorName) not recognized") }
    
    for screen in screens {
        // Device frame's image needs to be generted separaratedly to make framing logic easy
        let framedScreenshots = walkDirectory(at: screenshots, options: .skipsHiddenFiles)
            .filter({ $0.isFileURL && $0.pathExtension.lowercased() == "png" })
        // FIXME: each FrameScreen should have a list of 'screenshot names' to filter here; also filter by correct device type
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
            framedScreenshots: [])
        //framedScreenshots.compactMap { NSImage(contentsOfFile: $0.absoluteString) })
        
        let render = StoreScreenshotRenderer(outputPath: output.absoluteString, imageFormat: .jpeg, layoutDirection: layoutDirection)
        //        if isHero {
        //            try render(SampleHeroStoreScreenshotView.makeView(layout: layout, content: content))
        //        } else {
        try render(SampleStoreScreenshotView.makeView(layout: layout, content: content))
        //        }
    }
}
