//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/17.
//
import UniformTypeIdentifiers
import SwiftUI

// MARK: - Application Support
@available(macOS 11.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        NSApplication.shared.dockTile.contentView = AppIconView()
        NSApplication.shared.dockTile.display()
    }
}

private struct DisassemblerURLEnvironmentKey: EnvironmentKey {
    static let defaultValue: URL? = nil
}

@available(macOS 11.0, *)
extension EnvironmentValues {
    var disassemblerURL: URL? {
        get { self[DisassemblerURLEnvironmentKey.self] }
        set { self[DisassemblerURLEnvironmentKey.self] = newValue }
    }
}

@available(macOS 11.0, *)
struct Main: App {
    @NSApplicationDelegateAdaptor var appDelegate: AppDelegate
    @AppStorage("llvm-disassembler-url", store: UserDefaults(suiteName: "com.imyuao.MetalLibraryArchive.app")) var disassemblerURL: URL?

    var body: some Scene {
        DocumentGroup(viewing: MetalLibraryArchiveDocument.self, viewer: { configuration in
            MetalLibraryView(archive: configuration.document.archive, filename: configuration.document.filename).environment(\.disassemblerURL, disassemblerURL)
        }).commands(content: {
            CommandMenu("Disassembler", content: {
                if let url = disassemblerURL, FileManager.default.fileExists(atPath: url.path) {
                    Text("Disassembler: \(url.lastPathComponent) at \(url.path)")
                    Divider()
                    Button("Reset", action: {
                        disassemblerURL = nil
                    })
                } else {
                    Button("Locate llvm-dis", action: {
                        let openPanel = NSOpenPanel()
                        openPanel.allowedContentTypes = [.unixExecutable]
                        let response = openPanel.runModal()
                        if let url = openPanel.url, response == .OK {
                            disassemblerURL = url
                        }
                    })
                }
            })
        })
    }
}

if #available(macOS 11.0, *) {
    DispatchQueue.main.async {
        NSDocumentController.shared.openDocument(nil)
    }
    Main.main()
} else {
    fatalError()
}
