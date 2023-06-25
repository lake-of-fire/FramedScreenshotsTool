//
//  Project.swift
//  
//
//  Created by Devran on 16.07.22.
//

import Foundation

public struct Project {
    public static let fileManager = FileManager()
    
    public static var currentDirectoryURL: URL {
        return URL(fileURLWithPath: fileManager.currentDirectoryPath)
    }
    
    public static var targetDirectoryURL: URL {
        return currentDirectoryURL.appendingPathComponent("Screenshots", isDirectory: true)
    }
    
    public static var derivedDataDirectoryURL: URL {
        return fileManager.temporaryDirectory.appendingPathComponent("ShotPlan-DerivedData", isDirectory: true)
    }
}
