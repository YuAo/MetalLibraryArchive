import Foundation
import Crypto

public struct Archive: Hashable {
    
    public class DataScanner {
        public enum Error: LocalizedError {
            case indexOutOfBounds
            case invalidStringData
            
            public var errorDescription: String? {
                switch self {
                case .indexOutOfBounds:
                    return "DataScanner: Index out of bounds."
                case .invalidStringData:
                    return "DataScanner: Invalid string data."
                }
            }
            
            public var failureReason: String? { errorDescription }
        }
        
        private(set) var offset: Int
        
        let data: Data
        
        init(data: Data) {
            self.data = data
            self.offset = data.startIndex
        }
        
        private func checkBoundsForReading(byteCount: Int) throws {
            if offset + byteCount > data.endIndex {
                throw Error.indexOutOfBounds
            }
        }
        
        func scanFourCharCode() throws -> String {
            let byteCount = 4
            try checkBoundsForReading(byteCount: byteCount)
            guard let string = String(data: data[offset..<(offset + byteCount)], encoding: .utf8) else {
                throw Error.invalidStringData
            }
            offset += byteCount
            assert(string.allSatisfy({ $0.isASCII }))
            return string
        }
        
        func scanData(byteCount: Int) throws -> Data {
            try checkBoundsForReading(byteCount: byteCount)
            let scanned = data[offset..<(offset + byteCount)]
            offset += byteCount
            return scanned
        }
        
        func scanDataToEnd() throws -> Data {
            try checkBoundsForReading(byteCount: 1)
            return data[offset...]
        }
        
        func scanCString() throws -> String {
            let string: String = try data[offset...].withUnsafeBytes({ pointer in
                guard let index = pointer.firstIndex(of: 0) else {
                    throw Error.invalidStringData
                }
                let string = String(cString: pointer.bindMemory(to: UInt8.self).baseAddress!)
                guard index == string.lengthOfBytes(using: .utf8) else {
                    throw Error.invalidStringData
                }
                return string
            })
            offset += (string.lengthOfBytes(using: .utf8) + 1)
            return string
        }
        
        func scan<T: FixedWidthInteger>(_ type: T.Type) throws -> Int {
            let size = MemoryLayout<T>.size
            try checkBoundsForReading(byteCount: size)
            let value = data[offset..<(offset + size)].withUnsafeBytes({ pointer in
                return pointer.bindMemory(to: T.self)[0]
            })
            offset += size
            return Int(value.littleEndian)
        }
        
        func scanTags<T: FixedWidthInteger>(contentSizeType: T.Type) throws -> [Tag] {
            var tags: [Tag] = []
            while true {
                let tagName = try scanFourCharCode()
                if tagName == "ENDT" {
                    break
                }
                let tagSize = try scan(T.self)
                let content = try scanData(byteCount: tagSize)
                tags.append(Tag(name: tagName, content: content))
            }
            return tags
        }
        
        func seek(to offset: Int) throws {
            if offset > data.count || offset < 0 {
                throw Error.indexOutOfBounds
            }
            self.offset = data.startIndex + offset
        }
    }
 
    public enum Error: LocalizedError {
        case invalidHeader
        case invalidFunctionListOffset
        case invalidTagGroupSize
        case incompleteFunctionInfo
        case incompleteSourceArchiveInfo
        case invalidBitcodeHash
        case unexpectedTagContentSize(tagName: String)
        case unexpectedFunctionListEnding
        case unexpectedLibraryType(Int)
        case unexpectedTargetPlatform(Int)
        case unexpectedBitcodeSize
        case unexpectedOperatingSystemType(Int)
        case unexpectedFileSize
        
        public var errorDescription: String? {
            switch self {
            case .invalidHeader:
                return "Invalid file header."
            case .invalidFunctionListOffset:
                return "Invalid function list offset."
            case .invalidTagGroupSize:
                return "Invalid tag group size."
            case .incompleteFunctionInfo:
                return "Incomplete function info."
            case .incompleteSourceArchiveInfo:
                return "Incomplete source archive info."
            case .invalidBitcodeHash:
                return "Invalid bitcode hash."
            case .unexpectedTagContentSize(let name):
                return "Unexpected size for tag \"\(name)\"."
            case .unexpectedFunctionListEnding:
                return "Unexpected function list ending."
            case .unexpectedLibraryType(let value):
                return "Unexpected library type: \(value)."
            case .unexpectedTargetPlatform(let value):
                return "Unexpected target platform: \(value)."
            case .unexpectedBitcodeSize:
                return "Unexpected bitcode size."
            case .unexpectedOperatingSystemType(let value):
                return "Unexpected OS type: \(value)."
            case .unexpectedFileSize:
                return "Unexpected file size."
            }
        }
        
        public var failureReason: String? { errorDescription }
    }
    
    public struct Version: Hashable, CustomStringConvertible {
        public let major: Int
        public let minor: Int
        
        public var description: String {
            return "\(major).\(minor)"
        }
    }

    public let functions: [Function]
    
    public let headerExtensionTags: [Tag]
    
    public let libraryType: LibraryType
    
    public let targetPlatform: Platform
    
    public let deploymentTarget: DeploymentTarget?
    
    public let sourceArchives: [SourceArchive]
    
    public let version: Version
    
    public init(data: Data) throws {
        let dataScanner = DataScanner(data: data)
        
        do {
            guard try dataScanner.scanFourCharCode() == "MTLB" else {
                throw Error.invalidHeader
            }
        } catch {
            throw Error.invalidHeader
        }
        
        //4...5
        let targetPlatform = try dataScanner.scan(UInt16.self)
        if targetPlatform == 0x8001 {
            self.targetPlatform = .macOS
        } else if targetPlatform == 0x0001 {
            self.targetPlatform = .iOS
        } else {
            throw Error.unexpectedTargetPlatform(targetPlatform)
        }
        
        //6,7,8,9
        let libraryMajorVersion = try dataScanner.scan(UInt16.self)
        let libraryMinorVersion = try dataScanner.scan(UInt16.self)
        version = Version(major: libraryMajorVersion, minor: libraryMinorVersion)
        
        //10
        let libraryTypeValue = try dataScanner.scan(UInt8.self)
        if let type = LibraryType(rawValue: libraryTypeValue) {
            libraryType = type
        } else {
            throw Error.unexpectedLibraryType(libraryTypeValue)
        }
        
        // 11: Target OS
        let targetOSValue = try dataScanner.scan(UInt8.self)
        // 12...13: Target OS version, major
        let targetOSMajorVersion = try dataScanner.scan(UInt16.self)
        // 14...15: Target OS version, minor
        let targetOSMinorVersion = try dataScanner.scan(UInt16.self)
        if targetOSValue != 0 {
            guard let os = DeploymentTarget.OperatingSystem(rawValue: targetOSValue) else {
                throw Error.unexpectedOperatingSystemType(targetOSValue)
            }
            self.deploymentTarget = DeploymentTarget(operatingSystem: os, operatingSystemVersion: DeploymentTarget.OperatingSystem.Version(major: targetOSMajorVersion, minor: targetOSMinorVersion))
        } else {
            self.deploymentTarget = nil
        }

        // 16...23
        let fileSize = try dataScanner.scan(UInt64.self)
        guard fileSize == data.count else {
            throw Error.unexpectedFileSize
        }
        
        let functionListOffset = try dataScanner.scan(UInt64.self) //24...31
        let functionListSize = try dataScanner.scan(UInt64.self) //32...39
        
        // Public metadata offset
        let publicMetadataOffset = try dataScanner.scan(UInt64.self) //40...47
        // Public metadata size
        _ = try dataScanner.scan(UInt64.self) //48...55
        
        // Private metadata offset
        _ = try dataScanner.scan(UInt64.self) //56...63
        // Private metadata size
        _ = try dataScanner.scan(UInt64.self) //64...71
        
        let bitcodeOffset = try dataScanner.scan(UInt64.self) //72...79
        let bitcodeSize = try dataScanner.scan(UInt64.self) //80...87
        
        // Validations
        guard functionListOffset + functionListSize < fileSize, functionListOffset > 0 else {
            throw Error.invalidFunctionListOffset
        }
        if functionListSize > 0 {
            try dataScanner.seek(to: functionListOffset + functionListSize)
            let functionListEndMark = try dataScanner.scanFourCharCode()
            guard functionListEndMark == "ENDT" else {
                throw Error.unexpectedFunctionListEnding
            }
        }
        
        // Read header extension tags, 4 is for `ENDT` or `0x00000000`
        if functionListOffset + functionListSize + 4 != publicMetadataOffset {
            try dataScanner.seek(to: functionListOffset + functionListSize + 4)
            headerExtensionTags = try dataScanner.scanTags(contentSizeType: UInt16.self)
        } else {
            headerExtensionTags = []
        }
        
        guard functionListSize > 0 else {
            functions = []
            sourceArchives = []
            return
        }
        
        guard bitcodeSize > 0 else {
            throw Error.unexpectedBitcodeSize
        }
        
        // Read functions
        try dataScanner.seek(to: functionListOffset)
        let numberOfFunctions = try dataScanner.scan(UInt32.self)
        
        let functionInfos: [FunctionInfo] = try {
            var infos: [FunctionInfo] = []
            for _ in 0..<numberOfFunctions {
                let tagsSize = try dataScanner.scan(UInt32.self)
                guard tagsSize > 0 else {
                    throw Error.invalidTagGroupSize
                }
                infos.append(try Self.scanFunctionInfo(using: dataScanner))
            }
            return infos
        }()
        
        let functions: [Function] = try {
            var entries: [Function] = []
            for info in functionInfos {
                try dataScanner.seek(to: bitcodeOffset + Int(info.bitcodeOffset))
                let data = try dataScanner.scanData(byteCount: Int(info.bitcodeSize))
                guard SHA256.hash(data: data) == info.hash else {
                    throw Error.invalidBitcodeHash
                }
                entries.append(Function(name: info.name, type: info.type, languageVersion: info.languageVersion, tags: info.tags, bitcode: data))
            }
            return entries
        }()
        self.functions = functions
        
        if let embededSourceTag = headerExtensionTags.first(where: { $0.name == "HSRD" || $0.name == "HSRC" }) {
            guard embededSourceTag.content.count == MemoryLayout<UInt64>.size * 2 else {
                throw Error.unexpectedTagContentSize(tagName: embededSourceTag.name)
            }
            let offset = embededSourceTag.content.withUnsafeBytes({ ptr in
                ptr.bindMemory(to: UInt64.self)[0]
            })
            try dataScanner.seek(to: Int(offset))
            let archiveCount = try dataScanner.scan(UInt32.self)
            _ = try dataScanner.scanCString() //Link options
            if embededSourceTag.name == "HSRD" {
                _ = try dataScanner.scanCString() //Working dir
            }
            var archives: [SourceArchive] = []
            for _ in 0..<archiveCount {
                let tagsSize = try dataScanner.scan(UInt32.self)
                guard tagsSize > 0 else {
                    throw Error.invalidTagGroupSize
                }
                guard let sourceArchiveTag = try dataScanner.scanTags(contentSizeType: UInt32.self).first(where: { $0.name == "SARC" }) else {
                    throw Error.incompleteSourceArchiveInfo
                }
                let tagContentScanner = DataScanner(data: sourceArchiveTag.content)
                let archiveID = try tagContentScanner.scanCString()
                let archiveData = try tagContentScanner.scanDataToEnd()
                precondition(archiveData.count + archiveID.lengthOfBytes(using: .utf8) + 1 == sourceArchiveTag.content.count)
                archives.append(SourceArchive(id: archiveID, data: archiveData))
            }
            sourceArchives = archives
        } else {
            sourceArchives = []
        }
    }
}

extension Archive {
    
    private struct FunctionInfo {
        var name: String
        var bitcodeSize: UInt64
        var bitcodeOffset: UInt64
        var type: FunctionType?
        var languageVersion: LanguageVersion
        var hash: Data
        var tags: [Tag]
    }
    
    private static func scanFunctionInfo(using scanner: DataScanner) throws -> FunctionInfo {
        let tags: [Tag] = try scanner.scanTags(contentSizeType: UInt16.self)
        var name: String?
        var bitcodeSize: UInt64?
        var bitcodeOffset: UInt64?
        var type: FunctionType?
        var hash: Data?
        var languageVersion: LanguageVersion?
        for tag in tags {
            switch tag.name {
            case "NAME":
                name = String(data: tag.content.dropLast(), encoding: .utf8)
            case "MDSZ":
                guard tag.content.count == MemoryLayout<UInt64>.size else {
                    throw Error.unexpectedTagContentSize(tagName: tag.name)
                }
                bitcodeSize = tag.content.withUnsafeBytes({ pointer in
                    pointer.bindMemory(to: UInt64.self)[0]
                })
            case "TYPE":
                guard tag.content.count == MemoryLayout<UInt8>.size else {
                    throw Error.unexpectedTagContentSize(tagName: tag.name)
                }
                let rawType = tag.content.withUnsafeBytes({ pointer in
                    pointer.bindMemory(to: UInt8.self)[0]
                })
                type = FunctionType(rawValue: Int(rawType))
            case "HASH":
                guard tag.content.count == 32 else {
                    throw Error.unexpectedTagContentSize(tagName: tag.name)
                }
                hash = tag.content
            case "OFFT":
                guard tag.content.count == MemoryLayout<UInt64>.size * 3 else {
                    throw Error.unexpectedTagContentSize(tagName: tag.name)
                }
                bitcodeOffset = tag.content.withUnsafeBytes({ pointer in
                    // 0: public metadata offset
                    // 1: private metadata offset
                    pointer.bindMemory(to: UInt64.self)[2]
                })
            case "VERS":
                guard tag.content.count == MemoryLayout<UInt16>.size * 4 else {
                    throw Error.unexpectedTagContentSize(tagName: tag.name)
                }
                let versionNumbers = tag.content.withUnsafeBytes({ pointer in
                    Array(pointer.bindMemory(to: UInt16.self))
                })
                //air version
                _ = (Int(versionNumbers[0]), Int(versionNumbers[1]))
                languageVersion = LanguageVersion(major: Int(versionNumbers[2]), minor: Int(versionNumbers[3]))
            default:
                break
            }
        }
        guard let name = name, let bitcodeSize = bitcodeSize, let bitcodeOffset = bitcodeOffset, let hash = hash, let languageVersion = languageVersion else {
            throw Error.incompleteFunctionInfo
        }
        return FunctionInfo(name: name, bitcodeSize: bitcodeSize, bitcodeOffset: bitcodeOffset, type: type, languageVersion: languageVersion, hash: hash, tags: tags)
    }
}
