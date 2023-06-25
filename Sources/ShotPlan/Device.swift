//
//  File.swift
//  
//
//  Created by Devran on 14.07.22.
//

import Foundation

public struct Device: Codable {
    public let simulatorName: String
    public let displaySize: String?
    public let homeStyle: HomeStyle?
    public var idiom: Idiom? {
        return Idiom.allCases.first { idiom in
            simulatorName.contains(idiom.description)
        }
    }
    
    public enum Idiom: String, CaseIterable, Codable, CustomStringConvertible {
        case tablet
        case phone
        case watch
        case tv
        
        public var description: String {
            switch self {
            case .tablet:
                return "iPad"
            case .phone:
                return "iPhone"
            case .watch:
                return "Apple Watch"
            case .tv:
                return "Apple TV"
            }
        }
    }
    
    public enum HomeStyle: String, Codable, CustomStringConvertible {
        case button
        case indicator
        
        public var description: String {
            switch self {
            case .indicator:
                return "Home Indicator"
            case .button:
                return "Home Button"
            }
        }
    }
    
    public var description: String {
        return "\(idiom?.description ?? "") \(displaySize ?? "")-inch with \(homeStyle?.description ?? "")"
    }
}
