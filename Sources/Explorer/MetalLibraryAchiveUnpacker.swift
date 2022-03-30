//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/18.
//

import Foundation
import MetalLibraryArchive

@available(macOS 11.0, *)
struct Unpacker {
    static func unpack(_ archive: Archive, to url: URL, disassembler: URL?) throws {
        let fileManager = FileManager()
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        var savedData = Set<Data>()
        for function in archive.functions {
            if savedData.contains(function.bitcode) {
                continue
            }
            let airFileURL = url.appendingPathComponent(function.name).appendingPathExtension("air")
            try function.bitcode.write(to: airFileURL)
            
            if let disassembler = disassembler {
                let process = Process()
                process.executableURL = disassembler
                process.arguments = [airFileURL.path]
                try process.run()
                process.waitUntilExit()
            }
            
            savedData.insert(function.bitcode)
        }
        for sourceArchive in archive.sourceArchives {
            let sourceArchiveURL = url.appendingPathComponent("SourceArchive-\(sourceArchive.id)").appendingPathExtension("bz2")
            try sourceArchive.data.write(to: sourceArchiveURL)
        }
    }
}
