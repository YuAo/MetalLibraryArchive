import XCTest
import MetalLibraryArchive

struct SDK {
    var name: String
    var metalPlatform: String
    static let macOS = SDK(name: "macosx", metalPlatform: "macos")
    static let iOS = SDK(name: "iphoneos", metalPlatform: "ios")
    static let tvOS = SDK(name: "appletvos", metalPlatform: "ios")
    static let tvOSSimulator = SDK(name: "appletvsimulator", metalPlatform: "ios")
    static let iOSSimulator = SDK(name: "iphonesimulator", metalPlatform: "ios")
    static let watchOS = SDK(name: "watchos", metalPlatform: "ios")
    
    var targetPlatform: Platform {
        switch self.metalPlatform {
        case "macos":
            return .macOS
        case "ios":
            return .iOS
        default:
            fatalError()
        }
    }
}

struct ComplieOptions {
    enum SourceRecordingOption {
        case none
        case embeded
        case separated
    }
    
    var target: String?
    var coreImageSupportEnabled: Bool = false
    var libraryType: LibraryType = .executable
    var languageVersion: LanguageVersion?
    var installName: String?
    var sourceRecordingOption: SourceRecordingOption = .none
}

struct MetalLibraryArchiveTestUtilities {
    
    struct Library {
        var data: Data
        var symbolCompanionData: Data?
    }
    
    static var temporaryDirectory: URL {
        let tempDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("MetalLibraryArchiveTests")
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        return tempDirectoryURL
    }
    
    static func makeLibrary(source: String, sdk: SDK, options: ComplieOptions = ComplieOptions()) throws -> Library {
        let complierFlags: [String] = try {
            var flags: [String] = []
            if let target = options.target {
                flags.append(contentsOf: ["-target", target])
            }
            if let version = options.languageVersion {
                flags.append("-std=\(sdk.metalPlatform)-metal\(version.major).\(version.minor)")
            }
            if options.coreImageSupportEnabled {
                flags.append("-fcikernel")
            }
            if options.libraryType == .dynamic {
                flags.append("-dynamiclib")
                if let installName = options.installName {
                    flags.append("-install_name")
                    flags.append(installName)
                }
            }
            switch options.sourceRecordingOption {
            case .none:
                break
            case .embeded:
                flags.append("-frecord-sources")
            case .separated:
                if sdk.targetPlatform == .macOS {
                    guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 12 else {
                        throw XCTSkip("The target platform does not support companion metallib.")
                    }
                }
                flags.append("-frecord-sources=flat")
            }
            return flags
        }()
        
        let tempDirectoryURL = self.temporaryDirectory
        let workUUID = UUID()
        let sourceURL = tempDirectoryURL.appendingPathComponent(workUUID.uuidString).appendingPathExtension("metal")
        let libraryURL = tempDirectoryURL.appendingPathComponent(workUUID.uuidString).appendingPathExtension("metallib")
        defer {
            do {
                try FileManager.default.removeItem(at: sourceURL)
                try FileManager.default.removeItem(at: libraryURL)
            } catch {}
        }
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)
        
        let compileProcess = Process()
        compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        compileProcess.arguments = ["--sdk", sdk.name, "metal"] + complierFlags + ["-o", libraryURL.path, sourceURL.path]
        try compileProcess.run()
        compileProcess.waitUntilExit()
        XCTAssert(compileProcess.terminationStatus == 0)
        
        
        let data = try Data(contentsOf: libraryURL)
        var library = Library(data: data)
        if options.sourceRecordingOption == .separated {
            library.symbolCompanionData = try Data(contentsOf: libraryURL.deletingPathExtension().appendingPathExtension("metallibsym"))
        }
        return library
    }
}

class MetalLibraryArchiveTests_macOSSDK: XCTestCase {
    var sdk: SDK = .macOS
    
    private func makeLibrary(source: String, options: ComplieOptions = ComplieOptions()) throws -> Data {
        return try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: sdk, options: options).data
    }
    
    func testEmptyLibrary() throws {
        let data = try self.makeLibrary(source: "")
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 0)
    }
    
    func testVertexFunction() throws {
        let source = """
        #include <metal_stdlib>
        struct VertexOut { float4 position [[position]]; };
        vertex VertexOut testVertex() { VertexOut out = {0}; return out; }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "testVertex")
        XCTAssertEqual(function.type, .vertex)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testFragmentFunction() throws {
        let source = """
        #include <metal_stdlib>
        fragment float4 testFragment() { return float4(0); }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "testFragment")
        XCTAssertEqual(function.type, .fragment)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testKernelFunction() throws {
        let source = """
        #include <metal_stdlib>
        kernel void testKernel() {}
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "testKernel")
        XCTAssertEqual(function.type, .kernel)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testVisibleFunction() throws {
        let source = """
        #include <metal_stdlib>
        [[visible]] void test() {}
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "test")
        XCTAssertEqual(function.type, .visible)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testIntersectionFunction() throws {
        let source = """
        #include <metal_stdlib>
        [[intersection(triangle)]]
        bool testIntersectionFunction() { return true; }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "testIntersectionFunction")
        XCTAssertEqual(function.type, .intersection)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testUnqualifiedFunction() throws {
        let source = """
        #include <metal_stdlib>
        namespace test {
            void action() {}
        }
        """
        let data = try self.makeLibrary(source: source, options: ComplieOptions(libraryType: .dynamic, installName: "@executable_path/libtest.metallib"))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "_ZN4test6actionEv")
        XCTAssertEqual(function.type, .unqualified)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testUnqualifiedFunction_globalNamespace() throws {
        let source = """
        #include <metal_stdlib>
        void test() {}
        """
        let data = try self.makeLibrary(source: source, options: ComplieOptions(libraryType: .dynamic, installName: "@executable_path/libtest.metallib"))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "_Z4testv")
        XCTAssertEqual(function.type, .unqualified)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testUnqualifiedFunction_externC() throws {
        let source = """
        #include <metal_stdlib>
        extern "C" void test() {}
        """
        let data = try self.makeLibrary(source: source, options: ComplieOptions(libraryType: .dynamic, installName: "@executable_path/libtest.metallib"))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "test")
        XCTAssertEqual(function.type, .unqualified)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testExternFunction() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        #include <CoreImage/CoreImage.h>
        
        extern "C" { namespace coreimage {
            float4 test(sample_t s) {
                return s.rgba;
            }
        }}
        """
        let data = try self.makeLibrary(source: source, options: ComplieOptions(coreImageSupportEnabled: true))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.libraryType, .coreImage)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "test")
        XCTAssertEqual(function.type, .extern)
        XCTAssert(function.bitcode.count > 0)
        XCTAssert(archive.functions[0].publicMetadataTags.contains(where: { $0.name == "RETR" }))
        XCTAssert(archive.functions[0].publicMetadataTags.contains(where: { $0.name == "ARGR" }))
    }
    
    func testLanguageVersion_2_0() throws {
        let source = """
        #include <metal_stdlib>
        kernel void testKernel() {}
        """
        let mslVersion = LanguageVersion(major: 2, minor: 0)
        let data = try self.makeLibrary(source: source, options: ComplieOptions(languageVersion: mslVersion))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "testKernel")
        XCTAssertEqual(function.type, .kernel)
        XCTAssertEqual(function.languageVersion, mslVersion)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testLanguageVersion_1_2() throws {
        let source = """
        #include <metal_stdlib>
        kernel void testKernel() {}
        """
        let mslVersion = LanguageVersion(major: 1, minor: 2)
        let data = try self.makeLibrary(source: source, options: ComplieOptions(languageVersion: mslVersion))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 1)
        let function = try XCTUnwrap(archive.functions.first)
        XCTAssertEqual(function.name, "testKernel")
        XCTAssertEqual(function.type, .kernel)
        XCTAssertEqual(function.languageVersion, mslVersion)
        XCTAssert(function.bitcode.count > 0)
    }
    
    func testMultipleFunctions() throws {
        let source = """
        #include <metal_stdlib>
        struct VertexOut { float4 position [[position]]; };
        vertex VertexOut testVertex() { VertexOut out = {0}; return out; }
        kernel void testKernel() {}
        fragment float4 testFragment() { return float4(0); }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 3)
    }
    
    func testMultipleExternFunctions() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        #include <CoreImage/CoreImage.h>
        
        extern "C" { namespace coreimage {
            float4 test1(sample_t s) {
                return s.rgba;
            }
            void test2() { }
            void test3() { }
        }}
        """
        let data = try self.makeLibrary(source: source, options: ComplieOptions(coreImageSupportEnabled: true))
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 3)
    }
    
    func testQualifiedFunctionNames() throws {
        let source = """
        #include <metal_stdlib>
        namespace test {
            struct VertexOut { float4 position [[position]]; };
            vertex VertexOut testVertex() { VertexOut out = {0}; return out; }
            kernel void testKernel() {}
            fragment float4 testFragment() { return float4(0); }
        }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.functions.count, 3)
        for function in archive.functions {
            XCTAssert(function.name.hasPrefix("test::"))
        }
    }
    
    func testLinkedLibraries() throws {
        let tempDirectoryURL = MetalLibraryArchiveTestUtilities.temporaryDirectory
        let workUUID = UUID()
        let workingDirectory = tempDirectoryURL.appendingPathComponent(workUUID.uuidString)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: workingDirectory)
        }
        do {
            let source = """
            #include <metal_stdlib>
            namespace test {
                float4 blackColor() { return float4(0); }
            }
            """
            let sourceURL = workingDirectory.appendingPathComponent("dylib.metal")
            let libraryURL = workingDirectory.appendingPathComponent("libTest.metallib")
            try source.write(to: sourceURL, atomically: true, encoding: .utf8)
            
            let compileProcess = Process()
            compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            compileProcess.arguments = ["--sdk", sdk.name, "metal", "-dynamiclib", "-install_name", "@executable_path/libTest.metallib", "-o", libraryURL.path, sourceURL.path]
            try compileProcess.run()
            compileProcess.waitUntilExit()
            XCTAssert(compileProcess.terminationStatus == 0)
            
            let archive = try Archive(data: Data(contentsOf: libraryURL))
            XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
            XCTAssertEqual(archive.libraryType, .dynamic)
            XCTAssertEqual(archive.functions.count, 1)
        }
        do {
            let source = """
            #include <metal_stdlib>
            namespace test {
                float4 blackColor();
            }
            kernel void testKernel() {
                test::blackColor();
            }
            """
            let sourceURL = workingDirectory.appendingPathComponent("exe.metal")
            let libraryURL = workingDirectory.appendingPathComponent("default.metallib")
            try source.write(to: sourceURL, atomically: true, encoding: .utf8)
            
            let compileProcess = Process()
            compileProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            compileProcess.arguments = ["--sdk", sdk.name, "metal", "-L", workingDirectory.path, "-lTest", "-o", libraryURL.path, sourceURL.path]
            try compileProcess.run()
            compileProcess.waitUntilExit()
            XCTAssert(compileProcess.terminationStatus == 0)
            
            let archive = try Archive(data: Data(contentsOf: libraryURL))
            XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
            XCTAssertEqual(archive.libraryType, .executable)
        }
    }
    
    func testLibraryType() throws {
        let source = """
        #include <metal_stdlib>
        namespace test {
            void action() {}
        }
        """
        do {
            let data = try self.makeLibrary(source: source, options: ComplieOptions(libraryType: .dynamic, installName: "@executable_path/libtest.metallib"))
            let archive = try Archive(data: data)
            XCTAssertEqual(archive.libraryType, .dynamic)
        }
        do {
            let data = try self.makeLibrary(source: source, options: ComplieOptions(libraryType: .executable))
            let archive = try Archive(data: data)
            XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
            XCTAssertEqual(archive.libraryType, .executable)
        }
    }
    
    func testTessellationFuntion() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct ControlPoint {
            float4 position [[attribute(0)]];
            float3 normal   [[attribute(1)]];
        };
        
        struct PatchIn {
            patch_control_point<ControlPoint> controlPoints;
        };
        
        struct VertexOut {
            float4 position [[position]];
        };

        [[patch(quad, 4)]]
        vertex VertexOut vertex_subdiv_quad(PatchIn patch [[stage_in]],
                                            float2 positionInPatch [[position_in_patch]]) {
            VertexOut out = {0};
            return out;
        }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        let tessellationTag = try XCTUnwrap(archive.functions.first?.tags.first(where: { $0.name == "TESS" }))
        XCTAssertEqual(tessellationTag.content.withUnsafeBytes({ $0.bindMemory(to: UInt8.self)[0] }), 4 << 2 | 2)
        XCTAssert(archive.functions[0].publicMetadataTags.contains(where: { $0.name == "VATT" }))
        XCTAssert(archive.functions[0].publicMetadataTags.contains(where: { $0.name == "VATY" }))
        
        let vatyTag = try XCTUnwrap(archive.functions.first?.publicMetadataTags.first(where: { $0.name == "VATY" }))
        XCTAssertEqual(vatyTag.content.withUnsafeBytes({ $0.bindMemory(to: UInt16.self)[0] }), 2) // count
        XCTAssertEqual(vatyTag.content.withUnsafeBytes({ $0.bindMemory(to: UInt8.self)[2] }), MetalDataType.float4.rawValue) //position
        XCTAssertEqual(vatyTag.content.withUnsafeBytes({ $0.bindMemory(to: UInt8.self)[3] }), MetalDataType.float3.rawValue) //normal
    }
    
    func testFuntionConstants() throws {
        let source = """
        #include <metal_stdlib>
        constant int constantValueA [[function_constant(0)]];
        kernel void testKernel(device float *io) {
            for (int i = 0; i < constantValueA; i += 1) {
                io[i] = 0;
            }
        }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        XCTAssert(archive.functions[0].publicMetadataTags.contains(where: { $0.name == "CNST" }))
    }
    
    func testFuntionConstants_unused() throws {
        let source = """
        #include <metal_stdlib>
        constant int constantValueA [[function_constant(0)]];
        kernel void testKernel(device float *io) {
            for (int i = 0; i < constantValueA; i += 1) {
                break;
            }
        }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        XCTAssertEqual(archive.functions[0].publicMetadataTags.contains(where: { $0.name == "CNST" }), false)
    }
    
    func testLayeredRendering_uint() throws {
        let source = """
        typedef struct {
            uint   layer [[render_target_array_index]];
            float4 position [[position]];
        } ColorInOut;
        
        vertex ColorInOut vertexTransform(){
            ColorInOut out;
            out.layer = 0;
            out.position = float4(0);
            return out;
        }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        let layerTag = try XCTUnwrap(archive.functions.first?.tags.first(where: { $0.name == "LAYR" }))
        XCTAssertEqual(layerTag.content.withUnsafeBytes({ $0.bindMemory(to: UInt8.self)[0] }), MetalDataType.uint.rawValue)
    }
    
    func testLayeredRendering_ushort() throws {
        let source = """
        typedef struct {
            ushort   layer [[render_target_array_index]];
            float4 position [[position]];
        } ColorInOut;
        
        vertex ColorInOut vertexTransform(){
            ColorInOut out;
            out.layer = 0;
            out.position = float4(0);
            return out;
        }
        """
        let data = try self.makeLibrary(source: source)
        let archive = try Archive(data: data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        let layerTag = try XCTUnwrap(archive.functions.first?.tags.first(where: { $0.name == "LAYR" }))
        XCTAssertEqual(layerTag.content.withUnsafeBytes({ $0.bindMemory(to: UInt8.self)[0] }), MetalDataType.ushort.rawValue)
    }
    
    func testSourceArchives_executable() throws {
        let source = """
        #include <metal_stdlib>
        kernel void testKernel() {}
        """
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: sdk, options: ComplieOptions(sourceRecordingOption: .embeded))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        XCTAssert(archive.sourceArchives.count > 0)
        XCTAssert(archive.functions[0].privateMetadataTags.contains(where: { $0.name == "DEPF" }))
    }
    
    func testSourceArchives_dynamic() throws {
        let source = """
        #include <metal_stdlib>
        namespace test {
            void action() {}
        }
        """
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: sdk, options: ComplieOptions(libraryType: .dynamic, installName: "@executable_path/libtest.metallib", sourceRecordingOption: .embeded))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .dynamic)
        XCTAssert(archive.sourceArchives.count > 0)
    }
    
    func testSourceArchives_executable_sym() throws {
        let source = """
        #include <metal_stdlib>
        kernel void testKernel() {}
        """
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: sdk, options: ComplieOptions(sourceRecordingOption: .separated))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .executable)
        XCTAssertEqual(archive.sourceArchives.count, 0)
        
        let symArchive = try Archive(data: XCTUnwrap(library.symbolCompanionData))
        XCTAssertEqual(symArchive.functions.count, 1)
        XCTAssertEqual(symArchive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(symArchive.libraryType, .symbolCompanion)
        XCTAssert(symArchive.sourceArchives.count > 0)
    }
    
    func testSourceArchives_dynamic_sym() throws {
        let source = """
        #include <metal_stdlib>
        namespace test {
            void action() {}
        }
        """
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: sdk, options: ComplieOptions(libraryType: .dynamic, installName: "@executable_path/libtest.metallib", sourceRecordingOption: .separated))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.functions.count, 1)
        XCTAssertEqual(archive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(archive.libraryType, .dynamic)
        XCTAssertEqual(archive.sourceArchives.count, 0)
     
        let symArchive = try Archive(data: XCTUnwrap(library.symbolCompanionData))
        XCTAssertEqual(symArchive.functions.count, 1)
        XCTAssertEqual(symArchive.targetPlatform, sdk.targetPlatform)
        XCTAssertEqual(symArchive.libraryType, .symbolCompanion)
        XCTAssert(symArchive.sourceArchives.count > 0)
    }
}

class MetalLibraryArchiveTests_iOSSDK: MetalLibraryArchiveTests_macOSSDK {
    override func setUp() {
        self.sdk = .iOS
        super.setUp()
    }
}

class MetalLibraryArchiveTests_tvOSSDK: MetalLibraryArchiveTests_macOSSDK {
    override func setUp() {
        self.sdk = .tvOS
        super.setUp()
    }
}

class MetalLibraryArchiveTests_iOSSimulatorSDK: MetalLibraryArchiveTests_macOSSDK {
    override func setUp() {
        self.sdk = .iOSSimulator
        super.setUp()
    }
}

class MetalLibraryArchiveTests_tvOSSimulatorSDK: MetalLibraryArchiveTests_macOSSDK {
    override func setUp() {
        self.sdk = .tvOSSimulator
        super.setUp()
    }
}

class MetalLibraryArchiveTests: XCTestCase {
    func testInvalidLibraryData() throws {
        do {
            let data = Data()
            XCTAssertThrowsError(try Archive(data: data))
        }
        do {
            let data = "MTLB".data(using: .utf8)!
            XCTAssertThrowsError(try Archive(data: data))
        }
    }
}

class MetalLibraryArchiveTests_TargetPlatformBug: XCTestCase {
    func testEmptyLibraryTargetPlatform_expectFailure() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: "", sdk: .iOS, options: ComplieOptions(target: "air64-apple-ios14.0"))
        let archive = try Archive(data: library.data)
        XCTExpectFailure(failingBlock: {
            XCTAssertEqual(archive.targetPlatform, .iOS)
        })
    }
    
    func testEmptyLibraryTargetPlatform_expectSuccess() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: "", sdk: .iOS, options: ComplieOptions(target: "air64-apple-ios15.0"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .iOS)
    }
}

class MetalLibraryArchiveTests_DeploymentTarget: XCTestCase {
    private let source = """
    #include <metal_stdlib>
    kernel void testKernel() {}
    """
    
    func testDeploymentTarget_macOS_12() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .macOS, options: ComplieOptions(target: "air64-apple-macos12.0"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .macOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystem, .macOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystemVersion.description, "12.0")
    }
    
    func testDeploymentTarget_iOS_15() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .iOS, options: ComplieOptions(target: "air64-apple-ios15.0"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .iOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystem, .iOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystemVersion.description, "15.0")
    }
    
    func testDeploymentTarget_iOS_15_1() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .iOS, options: ComplieOptions(target: "air64-apple-ios15.1"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .iOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystem, .iOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystemVersion.description, "15.1")
    }
    
    func testDeploymentTarget_iOS_11() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .iOS, options: ComplieOptions(target: "air64-apple-ios11.0"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .iOS)
        XCTAssertEqual(archive.deploymentTarget, nil)
    }
    
    func testDeploymentTarget_watchOS_8_5() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .watchOS, options: ComplieOptions(target: "air64-apple-watchos8.5"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .iOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystem, .watchOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystemVersion.description, "8.5")
    }
    
    func testDeploymentTarget_iOSSimulator_15_2() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .iOSSimulator, options: ComplieOptions(target: "air64-apple-ios15.2-simulator"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .iOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystem, .iOSSimulator)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystemVersion.description, "15.2")
    }
    
    func testDeploymentTarget_macCatalyst_15() throws {
        let library = try MetalLibraryArchiveTestUtilities.makeLibrary(source: source, sdk: .iOS, options: ComplieOptions(target: "air64-apple-ios15.0-macabi"))
        let archive = try Archive(data: library.data)
        XCTAssertEqual(archive.targetPlatform, .macOS)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystem, .macCatalyst)
        XCTAssertEqual(archive.deploymentTarget?.operatingSystemVersion.description, "15.0")
    }
}
