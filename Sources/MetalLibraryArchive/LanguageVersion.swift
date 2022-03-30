//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/22.
//

import Foundation

public struct LanguageVersion: Hashable, CustomStringConvertible {
    public init(major: Int, minor: Int) {
        self.major = major
        self.minor = minor
    }
    
    public let major: Int
    public let minor: Int
    
    public var description: String {
        return "\(major).\(minor)"
    }
}
