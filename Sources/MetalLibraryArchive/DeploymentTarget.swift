//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/26.
//

import Foundation

public struct DeploymentTarget: Hashable {
    
    public enum OperatingSystem: Int, CustomStringConvertible, CaseIterable, Hashable {
        case macOS = 0x81
        case iOS = 0x82
        case tvOS = 0x83
        case watchOS = 0x84
        case bridgeOS = 0x85
        case macCatalyst = 0x86
        case iOSSimulator = 0x87
        case tvOSSimulator = 0x88
        case watchOSSimulator = 0x89
        
        public var description: String {
            switch self {
            case .macOS:
                return "macOS"
            case .iOS:
                return "iOS"
            case .tvOS:
                return "tvOS"
            case .watchOS:
                return "watchOS"
            case .bridgeOS:
                return "bridgeOS"
            case .macCatalyst:
                return "Mac Catalyst"
            case .iOSSimulator:
                return "iOS Simulator"
            case .tvOSSimulator:
                return "tvOS Simulator"
            case .watchOSSimulator:
                return "watchOS Simulator"
            }
        }
        
        public struct Version: Hashable, CustomStringConvertible {
            public let major: Int
            public let minor: Int
            
            public var description: String {
                return "\(major).\(minor)"
            }
        }
    }
    
    public let operatingSystem: OperatingSystem
    public let operatingSystemVersion: OperatingSystem.Version
}
