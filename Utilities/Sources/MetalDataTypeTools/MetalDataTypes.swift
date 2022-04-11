//
//  File.swift
//  
//
//  Created by YuAo on 2022/4/10.
//

import Foundation
import MetalDataTypeInternal

struct MetalDataType {
    var id: Int
    var description: String
}

extension MetalDataType {    
    static let allTypes: [MetalDataType] = (UInt8.min...UInt8.max).compactMap({ id in
        let type = MetalDataTypeObjectCreate(UInt64(id))
        if !type.description.isEmpty && type.description != "Unknown" {
            let prefix = "MTLDataType"
            precondition(type.description.hasPrefix(prefix))
            return MetalDataType(id: Int(id), description: String(type.description.dropFirst(prefix.count)))
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
