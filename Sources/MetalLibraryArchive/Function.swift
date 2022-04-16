//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/18.
//

import Foundation

public enum FunctionType: Int, CaseIterable, CustomStringConvertible, Hashable {
    case vertex = 0
    case fragment = 1
    case kernel = 2
    case unqualified = 3
    case visible = 4
    case extern = 5
    case intersection = 6
    
    public var description: String {
        switch self {
        case .vertex:
            return "Vertex"
        case .fragment:
            return "Fragment"
        case .kernel:
            return "Kernel"
        case .unqualified:
            return "Unqualified"
        case .visible:
            return "Visible"
        case .extern:
            return "Extern"
        case .intersection:
            return "Intersection"
        }
    }
}

public struct Function: Hashable {
    public let name: String
    public let type: FunctionType?
    public let languageVersion: LanguageVersion
    public let tags: [Tag]
    public let publicMetadataTags: [Tag]
    public let privateMetadataTags: [Tag]
    public let bitcode: Data
    public let bitcodeHash: Data
}

extension Function {
    public var isSourceIncluded: Bool {
        return tags.contains(where: { $0.name == "SOFF" })
    }
}
