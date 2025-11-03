#if os(macOS)
import Foundation
import ArgumentParser
import ShotPlan

@main
struct ShotPlanCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A utility creating automated screenshots with Xcode Test Plans.",
        subcommands: [Init.self, Run.self, Info.self],
        defaultSubcommand: Info.self)
    
    mutating func run() {
    }
    
    init() {
    }
}

extension ShotPlanCLI {
    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Starts creating screenshots based on your configuration.")
             
        mutating func run() {
            let configurationFromFile = try? ShotPlanConfiguration.load()
            
            guard let workspaceName = configurationFromFile?.workspace else {
                print("\(ShotPlanConfiguration.defaultWorkspaceName) not found. Create a configuration by running 'shotplan init'")
                return
            }
            
            guard let schemeName = configurationFromFile?.scheme else {
                print("\(ShotPlanConfiguration.defaultSchemeName) not found. Create a configuration by running 'shotplan init'")
                return
            }
            
            guard let testPlan = configurationFromFile?.testPlan else {
                print("\(ShotPlanConfiguration.defaultTestPlan) not found. Create a configuration by running 'shotplan init'")
                return
            }
            
            let devices = configurationFromFile?.devices ?? ShotPlanConfiguration.defaultDevices
            
            let localizeSimulator = configurationFromFile?.localizeSimulator ?? true
            
            let timeZone = configurationFromFile?.timeZone ?? ShotPlanConfiguration.defaultTimeZone
            
            let configuration = ShotPlanConfiguration(workspace: workspaceName, scheme: schemeName, testPlan: testPlan, devices: devices, localizeSimulator: localizeSimulator, timeZone: timeZone)
            let targetFolder = Project.targetDirectoryURL.relativePath
            let derivedDataPath = Project.derivedDataDirectoryURL.relativePath
            
            for device in devices {
                let screenshotsPath = "\(targetFolder)/\(device.description)/\(device.simulatorName)"
                print("Starting Simulator: \(device.simulatorName)")
                Simulator.boot(simulatorName: device.simulatorName)
                print("Simulator started.")
                
                print("Setting Status Bar …")
                Simulator.setStatusBar(device: device, timeZone: timeZone)
                print("Status Bar set.")
                
                print("Deleting Derived Data …")
                let _ = try? Shell.call("rm -rf \(derivedDataPath.quoted())")
                
                print("Creating Screenshots Directory …")
                let _ = try? Shell.call("mkdir -p \(screenshotsPath.quoted())")
                
                print("Running Tests …")
//                let _ = try? Shell.call("xcodebuild test -workspace \(configuration.workspace) -list")
                let _ = try? Shell.call("xcodebuild test -workspace \(configuration.workspace) -scheme \(configuration.scheme) -destination \"platform=iOS Simulator,name=\(device.simulatorName)\" -testPlan \(configuration.testPlan) -derivedDataPath \(derivedDataPath.quoted())")
                
                print("Copying Screenshots for \(device.simulatorName) …")
                let _ = try? Shell.call("find \"\(derivedDataPath)/Logs/Test\" -maxdepth 1 -type d -exec xcparse screenshots --activity-type userCreated attachmentContainer --language {} \(screenshotsPath.quoted()) \\;")
                
                //    run("xcrun simctl shutdown \"\(device.simulatorName)\"")
            }
        }
    }
}

extension ShotPlanCLI {
    struct Init: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Creates a configuration file.")
        
        @Option(name: .short, help: "Name of your workspace.")
        var workspaceName: String?
        
        @Option(name: .short, help: "Name of your project scheme.")
        var schemeName: String?
        
        @Option(name: .short, help: "Name of your Xcode Test Plan.")
        var testPlan: String?
        
        mutating func run() {
            print("Creating default configuration …")
            
            let defaultConfiguration = ShotPlanConfiguration.defaultConfiguration(
                workspaceName: workspaceName,
                schemeName: schemeName,
                testPlan: testPlan)
            ShotPlanConfiguration.save(contents: defaultConfiguration.data)
            
            if ShotPlanConfiguration.exists {
                print("\(ShotPlanConfiguration.defaultFileName) created.")
                print("Call 'shotplan run' command to start creating screenshots.")
            }
        }
    }
}

extension ShotPlanCLI {
    struct Info: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Shows you how to run this tool.")
        
        mutating func run() {
            print("Call 'shotplan run' command to start creating screenshots.")
        }
    }
}

extension ShotPlanCLI {
    struct Debug: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Debug.")
        
        mutating func run() {
            
        }
    }
}
#endif
