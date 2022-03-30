//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/23.
//

import Foundation

public enum Platform: CustomStringConvertible, CaseIterable, Hashable {
    case iOS
    case macOS
    
    public var description: String {
        switch self {
        case .iOS:
            return "iOS"
        case .macOS:
            return "macOS"
        }
    }
}
