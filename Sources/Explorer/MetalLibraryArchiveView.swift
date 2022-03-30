//
//  File.swift
//  
//
//  Created by YuAo on 2022/3/17.
//

import SwiftUI
import MetalLibraryArchive

@available(macOS 11.0, *)
struct MetalLibraryView: View {
    private let archive: Archive
    private let filename: String
    private let functionBitcodeID: [String: Int]
    
    @Environment(\.disassemblerURL) private var disassemblerURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    
    init(archive: Archive, filename: String) {
        self.archive = archive
        self.filename = filename
        self.functionBitcodeID = {
            var currentID: Int = 0
            var functionBitcodeID: [String: Int] = [:]
            var bitcodeID: [Data: Int] = [:]
            for function in archive.functions {
                if let id = bitcodeID[function.bitcode] {
                    functionBitcodeID[function.name] = id
                } else {
                    bitcodeID[function.bitcode] = currentID
                    functionBitcodeID[function.name] = currentID
                    currentID += 1
                }
            }
            return functionBitcodeID
        }()
    }
    
    struct LanguageVersionView: View {
        private let text: String
        init(version: LanguageVersion) {
            text = "MSL \(version.major).\(version.minor)"
        }
        var body: some View {
            BadgeView(text: text, foregroundColor: .white, backgroundColor: .gray)
        }
    }
    
    struct BadgeView: View {
        @Environment(\.controlActiveState) private var controlActiveState

        let text: String
        let foregroundColor: Color
        let backgroundColor: Color
        
        var body: some View {
            Text(text)
                .font(Font.system(.footnote, design: .monospaced).weight(.medium))
                .foregroundColor(foregroundColor)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).foregroundColor(controlActiveState == .inactive ? .gray.opacity(0.5) : backgroundColor))
        }
    }
    
    struct BitcodeSizeView: View {
        private let text: String
        init(bytes: Int) {
            let formatter = ByteCountFormatter()
            text = formatter.string(fromByteCount: Int64(bytes))
        }
        var body: some View {
            BadgeView(text: text, foregroundColor: .white, backgroundColor: .gray.opacity(0.75))
        }
    }
    
    struct BitcodeIDView: View {
        private let text: String
        init(id: Int) {
            text = "BC \(id)"
        }
        var body: some View {
            BadgeView(text: text, foregroundColor: .white, backgroundColor: .gray.opacity(0.75))
        }
    }
    
    struct SourceBadge: View {
        @Environment(\.controlActiveState) private var controlActiveState
        
        private var color: Color {
            controlActiveState == .inactive ? .gray.opacity(0.5) : .green.opacity(0.75)
        }
        
        var body: some View {
            Text("SRC")
                .font(Font.system(.caption, design: .monospaced).smallCaps())
                .foregroundColor(color)
                .padding(EdgeInsets(top: 1, leading: 4, bottom: 1, trailing: 4))
                .background(GeometryReader(content: { proxy in
                    RoundedRectangle(cornerRadius: proxy.size.height/2).strokeBorder(color, lineWidth: 1, antialiased: true)
                }))
        }
    }
    
    struct FunctionTypeView: View {
        private struct TypeInfo {
            var symbol: String
            var textColor: Color
            var backgroundColor: Color
        }
        
        private let typeInfo: TypeInfo?
        
        init(type: FunctionType?) {
            typeInfo = {
                let colors: [Color] = [.green, .blue, .orange, .red, .pink, .purple, .yellow]
                precondition(colors.count == FunctionType.allCases.count)
                if let type = type {
                    let colorIndex = FunctionType.allCases.firstIndex(of: type)!
                    return TypeInfo(symbol: type.description, textColor: .white, backgroundColor: colors[colorIndex])
                } else {
                    return TypeInfo(symbol: "Unknown", textColor: .white, backgroundColor: .gray)
                }
            }()
        }
        
        var body: some View {
            if let info = typeInfo {
                BadgeView(text: info.symbol, foregroundColor: info.textColor, backgroundColor: info.backgroundColor)
            }
        }
    }
    
    @State private var functionType: FunctionType?
    
    var filteredEntries: [Function] {
        archive.functions.filter({
            if let filter = functionType {
                if $0.type != filter {
                    return false
                }
            }
            return true
        })
    }
    
    var body: some View {
        List {
            HStack {
                if filteredEntries.count != archive.functions.count {
                    Text("\(filteredEntries.count)/\(archive.functions.count) functions")
                } else {
                    Text("\(archive.functions.count) functions")
                }
                Spacer()
                Picker("", selection: $functionType, content: {
                    Text("All").tag(Optional<FunctionType>.none)
                    ForEach(FunctionType.allCases) { type in
                        Text(type.description).tag(Optional<FunctionType>.some(type))
                    }
                })
                .scaledToFit()
            }
            ForEach(filteredEntries, id: \.name) { entry in
                HStack {
                    Group {
                        if #available(macOS 12.0, *) {
                            Text(entry.name).textSelection(.enabled)
                        } else {
                            Text(entry.name)
                        }
                    }.font(Font.system(.headline, design: .monospaced).weight(.bold))
                    if entry.isSourceIncluded {
                       SourceBadge()
                    }
                    Spacer()
                    FunctionTypeView(type: entry.type)
                    LanguageVersionView(version: entry.languageVersion)
                    BitcodeIDView(id: functionBitcodeID[entry.name]!)
                }
                .lineLimit(nil)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .foregroundColor(colorScheme == .dark ? Color.black : Color.white)
                )
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .navigation, content: {
                Text("\(archive.targetPlatform.description) - \(archive.libraryType.description)")
                    .font(Font.system(.footnote).weight(.medium))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).foregroundColor(controlActiveState == .inactive ? .gray.opacity(0.5) : .gray))
            })
            ToolbarItem(placement: .primaryAction, content: {
                Menu(content: {
                    Button("Unpack", action: {
                        unpack(disassemble: false)
                    })
                    Button("Unpack and Disassemble", action: {
                        unpack(disassemble: true)
                    })
                }, label: {
                    Image(systemName: "tray.and.arrow.up.fill")
                })
            })
        })
        .listStyle(.sidebar)
    }
    
    func unpack(disassemble: Bool) {
        let disassemblerURL: URL?
        if disassemble {
            if let url = self.disassemblerURL {
                disassemblerURL = url
            } else {
                class AlertDelegate: NSObject, NSAlertDelegate {
                    func alertShowHelp(_ alert: NSAlert) -> Bool {
                        NSWorkspace.shared.open(URL(string: "https://github.com")!)
                        return true
                    }
                }
                let delegate = AlertDelegate()
                let alert = NSAlert()
                alert.messageText = "In order to disassemble .air files. llvm-dis is required. Use the \"Disassembler\" menu to locate llvm-dis."
                alert.showsHelp = true
                alert.delegate = delegate
                alert.icon = nil
                alert.runModal()
                withExtendedLifetime(delegate, {})
                return
            }
        } else {
            disassemblerURL = nil
        }
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "\(filename).unpacked"
        let response = savePanel.runModal()
        guard let url = savePanel.url, response == .OK else {
            return
        }
        do {
            try Unpacker.unpack(archive, to: url, disassembler: disassemblerURL)
            let alert = NSAlert()
            alert.messageText = "Operation completed."
            alert.runModal()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

extension FunctionType: Identifiable {
    public var id: Int { self.rawValue }
}

