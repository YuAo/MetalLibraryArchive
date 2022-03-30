//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/22.
//

import Foundation

public enum LibraryType: Int, CustomStringConvertible, CaseIterable, Hashable {
    case executable = 0
    case coreImage = 1
    case dynamic = 2
    case symbolCompanion = 3
    
    public var description: String {
        switch self {
        case .executable:
            return "Executable"
        case .coreImage:
            return "Core Image"
        case .dynamic:
            return "Dynamic"
        case .symbolCompanion:
            return "Symbol Companion"
        }
    }
}
