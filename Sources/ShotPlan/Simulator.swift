//
//  Simulator.swift
//  
//
//  Created by Devran on 14.07.22.
//
#if os(macOS)
import Foundation

public struct Simulator {
    public static func defaultDate(timeZone: String) -> Date {
        let timeZone = TimeZone(identifier: timeZone) ?? .current
        let dateComponents = DateComponents(
            calendar: Calendar.current,
            timeZone: timeZone,
            year: 2007,
            month: 01,
            day: 09,
            hour: 9,
            minute: 41,
            second: 0,
            nanosecond: 0)
        guard dateComponents.isValidDate, let importantDate = dateComponents.date else {
            fatalError("Date Invalid.")
        }
        return importantDate
    }
    
    public static func defaultDateString(timeZone: String) -> String {
        defaultDate(timeZone: timeZone).ISO8601Format()
    }
    
    public static func setStatusBar(device: Device, timeZone: String) {
        clearStatusBar(simulatorName: device.simulatorName)
        switch device.idiom {
        case .tablet:
            setStatusBarPad(simulatorName: device.simulatorName, timeZone: timeZone)
        case .phone:
            switch device.homeStyle {
            case .indicator:
                setStatusBarPhoneWithHomeIndicator(simulatorName: device.simulatorName, timeZone: timeZone)
            default:
                setStatusBarPhoneWithHomeButton(simulatorName: device.simulatorName, timeZone: timeZone)
            }
        default:
            break
        }
    }
    
    public static func findUDID(from simulatorName: String) -> String? {
        guard let jsonString = try? Shell.call("xcrun simctl list --json") else { return nil }
        guard let data = jsonString.data(using: .utf8) else { fatalError() }
        guard let knownSimulators = try? JSONDecoder().decode(XcodeSimulator.self, from: data) else { fatalError() }
        return knownSimulators.devices.values.flatMap { $0 }.first { $0.name == simulatorName }?.udid
    }
    
    public static func boot(simulatorName: String) {
        let _ = try? Shell.call("xcrun simctl boot \(simulatorName.quoted())")
    }
    
    public static func shutdown(simulatorName: String) {
        let _ = try? Shell.call("xcrun simctl shutdown \(simulatorName.quoted())")
    }
    
    public static func clearStatusBar(simulatorName: String) {
        let _ = try? Shell.call("xcrun simctl status_bar \(simulatorName.quoted()) clear")
    }
    
    public static func setStatusBarPhoneWithHomeButton(simulatorName: String, timeZone: String) {
        let _ = try? Shell.call("xcrun simctl status_bar \(simulatorName.quoted()) override --time \(defaultDateString(timeZone: timeZone).quoted()) --wifiBars 3 --cellularBars 4 --operatorName \"\"")
    }
    
    public static func setStatusBarPhoneWithHomeIndicator(simulatorName: String, timeZone: String) {
        let _ = try? Shell.call("xcrun simctl status_bar \(simulatorName.quoted()) override --time \(defaultDateString(timeZone: timeZone).quoted()) --wifiBars 3 --cellularBars 4")
    }
    
    public static func setStatusBarPad(simulatorName: String, timeZone: String) {
        let _ = try? Shell.call("xcrun simctl status_bar \(simulatorName.quoted()) override --time \(defaultDateString(timeZone: timeZone).quoted()) --wifiBars 3 --wifiMode active")
        hideDate(simulatorName: simulatorName)
    }
    
    public static func hideDate(simulatorName: String) {
        let _ = try? Shell.call("xcrun simctl spawn \(simulatorName.quoted()) defaults write com.apple.UIKit StatusBarHidesDate 1")
    }
    
    public static func setLocalization(simulatorName: String, locale: String = "en_US", language: String = "en") {
        if let udid = Simulator.findUDID(from: simulatorName) {
            // Boot
            // If the simulator was never used before, you have to boot it at least once, so that changes can be applied.
            Simulator.shutdown(simulatorName: simulatorName)
            Simulator.boot(simulatorName: simulatorName)
            
            // Change Locale and Language
            let _ = try? Shell.call("plutil -replace AppleLocale -string \"\(locale)\" ~/Library/Developer/CoreSimulator/Devices/\(udid)/data/Library/Preferences/.GlobalPreferences.plist")
            let _ = try? Shell.call("plutil -replace AppleLanguages -json \"[\\\"\(language)\\\"]\" ~/Library/Developer/CoreSimulator/Devices/\(udid)/data/Library/Preferences/.GlobalPreferences.plist")
            
            // Boot again
            Simulator.shutdown(simulatorName: simulatorName)
            Simulator.boot(simulatorName: simulatorName)
        }
    }
}
#endif
