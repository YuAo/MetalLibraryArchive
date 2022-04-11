//
//  File.swift
//  
//
//  Created by YuAo on 2022/4/10.
//

import Foundation
import Metal

// https://github.com/nst/iOS-Runtime-Headers/blob/fbb634c78269b0169efdead80955ba64eaaa2f21/Frameworks/Metal.framework/MTLTypeInternal.h
@objc private protocol MTLTypeInternalProtocol: NSObjectProtocol {
    init(dataType: UInt64)
    var dataType: UInt64 { get }
}

struct MetalDataType {
    var id: UInt8
    var description: String
}

extension MetalDataType {
    static let allTypes: [MetalDataType] = (UInt8.min...UInt8.max).compactMap({ id in
        struct Static {
            static let MTLTypeInternal: MTLTypeInternalProtocol.Type = {
                let type: AnyClass = NSClassFromString("MTLTypeInternal")!
                class_addProtocol(type, MTLTypeInternalProtocol.self)
                return type as! MTLTypeInternalProtocol.Type
            }()
        }
        
        let type = Static.MTLTypeInternal.init(dataType: UInt64(id))
        if !type.description.isEmpty && type.description != "Unknown" {
            let prefix = "MTLDataType"
            precondition(type.description.hasPrefix(prefix))
            let description =  String(type.description.dropFirst(prefix.count))
            return MetalDataType(id: id, description: description)
        } else {
            return nil
        }
    })
}

extension MetalDataType {
    var hexID: String {
        if id < 16 {
            return "0x0\(String(id, radix: 16, uppercase: true))"
        } else {
            return "0x\(String(id, radix: 16, uppercase: true))"
        }
    }
    
    var camelCaseDescription: String {
        let prefix = description.prefix(while: { $0.isUppercase })
        return prefix.lowercased() + description.dropFirst(prefix.count)
    }
}
