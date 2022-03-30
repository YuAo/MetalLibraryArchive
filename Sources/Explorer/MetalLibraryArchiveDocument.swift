//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/17.
//

import SwiftUI
import MetalLibraryArchive
import UniformTypeIdentifiers

@available(macOS 11.0, *)
struct MetalLibraryArchiveDocument: FileDocument {
    
    enum Error: LocalizedError {
        case cannotLoadFile
        var errorDescription: String? {
            switch self {
            case .cannotLoadFile:
                return "Error loading file content."
            }
        }
        var failureReason: String? { errorDescription }
    }
    
    static let readableContentTypes: [UTType] = [.data]
    
    let archive: Archive
    let filename: String
    
    init(configuration: ReadConfiguration) throws {
        guard let content = configuration.file.regularFileContents else {
            throw Error.cannotLoadFile
        }
        archive = try Archive(data: content)
        filename = configuration.file.filename ?? "default.metallib"
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw CocoaError(.fileWriteNoPermission)
    }
}
