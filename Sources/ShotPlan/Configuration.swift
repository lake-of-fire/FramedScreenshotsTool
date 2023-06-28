//
//  Configuration.swift
//  
//
//  Created by Devran on 14.07.22.
//
#if os(macOS)
import Foundation

public struct ShotPlanConfiguration: Codable {
    public let workspace: String
    public let scheme: String
    public let testPlan: String
    public let devices: [Device]
    public let localizeSimulator: Bool
    public let timeZone: String
    
    public init(workspace: String, scheme: String, testPlan: String, devices: [Device], localizeSimulator: Bool, timeZone: String) {
        self.workspace = workspace
        self.scheme = scheme
        self.testPlan = testPlan
        self.devices = devices
        self.localizeSimulator = localizeSimulator
        self.timeZone = timeZone
    }
    
}

public extension ShotPlanConfiguration {
    static let defaultFileName: String = "ShotPlan.json"
    static let defaultWorkspaceName: String = "YOUR_WORKSPACE"
    static let defaultSchemeName: String = "YOUR_SCHEME"
    static let defaultTestPlan: String = "YOUR_TESTPLAN"
    static let defaultTimeZone: String = "America/Los_Angeles"
    static let defaultDevices: [Device] = [
        Device(simulatorName: "iPhone 14 Plus", displaySize: "6.5", homeStyle: .indicator),
        Device(simulatorName: "iPhone 14 Pro Max", displaySize: "6.7", homeStyle: .indicator),
        Device(simulatorName: "iPhone 8 Plus", displaySize: "5.5", homeStyle: .button),
        Device(simulatorName: "iPad Pro (12.9-inch) (6th generation)", displaySize: "12.9", homeStyle: .indicator),
         Device(simulatorName: "iPad Pro (12.9-inch) (2nd generation)", displaySize: "12.9", homeStyle: .button),
    ]
    
    static func defaultConfiguration(workspaceName: String?, schemeName: String?, testPlan: String?) -> Self {
        return Self(workspace: workspaceName ?? defaultWorkspaceName,
                    scheme: schemeName ?? defaultSchemeName,
                    testPlan: testPlan ?? defaultTestPlan,
                    devices: defaultDevices,
                    localizeSimulator: true,
                    timeZone: defaultTimeZone)
    }
    
    var data: Data {
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        guard let encodedData = try? jsonEncoder.encode(self) else { fatalError() }
        return encodedData
    }
}

public extension ShotPlanConfiguration {
    static var configurationFileURL: URL {
        return Project.currentDirectoryURL.appendingPathComponent(defaultFileName)
    }
    
    static var exists: Bool {
        return Project.fileManager.fileExists(atPath: configurationFileURL.path)
    }
    
    static func save(contents: Data) {
        Project.fileManager.createFile(atPath: configurationFileURL.path, contents: contents)
    }
    
    static func load() throws -> Self {
        return try JSONDecoder().decode(self, from: Data(contentsOf: configurationFileURL))
    }
}
#endif
