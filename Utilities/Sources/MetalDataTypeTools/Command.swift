//
//  File.swift
//  
//
//  Created by YuAo on 2020/3/16.
//

import Foundation
import ArgumentParser

extension URL: ExpressibleByArgument {
    public init?(argument: String) {
        if let url = URL(string: argument), url.scheme != nil {
            self.init(string: argument)
        } else {
            //Assuming it is a file url.
            self.init(fileURLWithPath: argument)
        }
    }
}

struct GenerateMetalDataTypeTableMarkdown: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(commandName: "gen-markdown")
    
    @Option var columns: Int = 1
    
    func run() throws {
        let rows = (MetalDataType.allTypes.count + columns - 1) / columns
        var table: String = ""
        for _ in 0..<columns {
            table += "| Value | Type "
        }
        table += "|\n"
        for _ in 0..<columns {
            table += "| ----- | ---- "
        }
        table += "|\n"
        for row in 0..<rows {
            for column in 0..<columns {
                let index = row * columns + column
                if index < MetalDataType.allTypes.count {
                    let type = MetalDataType.allTypes[index]
                    table += "| \(type.hexID) | \(type.description) "
                } else {
                    table += "|  | "
                }
            }
            table += "|\n"
        }
        print(table)
    }
}

struct GenerateMetalDataTypeDefinition: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(commandName: "gen-swift")
    
    func run() throws {
        let keywords: Set<String> = ["struct", "enum", "class"]
        let code = """
        //
        //  MetalDataType.swift
        //  Generated on \(Date())
        //
        
        public enum MetalDataType: UInt8, Hashable, CaseIterable {
        \(MetalDataType.allTypes.map({ type in
            if keywords.contains(type.camelCaseDescription) {
                return "    case `\(type.camelCaseDescription)` = \(type.hexID)"
            } else {
                return "    case \(type.camelCaseDescription) = \(type.hexID)"
            }
        }).joined(separator: "\n"))
        }
        
        """
        print(code)
    }
}

@main
struct MetalDataTypeTools: ParsableCommand {
    static let configuration: CommandConfiguration = CommandConfiguration(subcommands: [GenerateMetalDataTypeDefinition.self, GenerateMetalDataTypeTableMarkdown.self])
}
