//
//  Shell.swift
//  
//
//  Created by Devran on 14.07.22.
//

#if os(macOS)
import Foundation

public struct Shell {
    @discardableResult
    public static func call(executable: String? = nil, _ command: String) throws -> String {
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.currentDirectoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        task.arguments = [command]
        if let executable = executable {
            task.executableURL = URL(fileURLWithPath: executable)
        } else {
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = ["-c"] + (task.arguments ?? [])
        }
        task.standardInput = nil
        
//        print("Working directory: \(task.currentDirectoryURL?.path ?? "(none found)")")
        print("$ [\(task.executableURL?.path ?? "")] \(task.arguments?.joined(separator: " ") ?? "")")
        try task.run()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        print(output)
        
        return output
    }
}
#endif
