//
//  WelcomeView.swift
//  XCStringsEditor
//
//  Created by William Alexander on 29/12/2024.
//

import SwiftUI

struct WelcomeView: View {
    
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    private var version: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "Version \(version) (\(build))"
        }
        return "Version information not available"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 16) {
                Spacer()
                
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .frame(width: 128, height: 128)
                    .shadow(color: .blue, radius: 16)
                
                Text("XCStringsEditor")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(version)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(64)
            .frame(maxWidth: 400)
            .background(.thinMaterial)
            
            ScrollView {
                LazyVStack(alignment: .leading) {
                    let recents = (UserDefaults.standard.array(forKey: "RecentFiles") as? [String])?.map { URL(filePath: $0) } ?? [URL]()
                    if recents.isEmpty == false {
                        ForEach(recents.reversed(), id: \.self) { url in
                            Button {
                                openWindow(id: "main")
                                dismissWindow()
                                
                                appModel.load(file: url)
                                
                                var recents = UserDefaults.standard.array(forKey: "RecentFiles") as? [String] ?? [String]()
                                if let index = recents.firstIndex(where: { $0 == url.path(percentEncoded: false) }) {
                                    recents.remove(at: index)
                                    recents.append(url.path(percentEncoded: false))
                                    UserDefaults.standard.set(recents, forKey: "RecentFiles")
                                }
                            } label: {
                                HStack {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false)))
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                    VStack(alignment: .leading) {
                                        Text(verbatim: url.lastPathComponent)
                                            .fontWeight(.bold)
                                        Text(filePath(url))
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background)
        }
        .frame(minWidth: 800, minHeight: 400)
    }
    
    private func filePath(_ url: URL) -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        
        var path = url.path
        if path.hasPrefix(homeDirectory.path) {
            path = path.replacingOccurrences(of: homeDirectory.path, with: "~")
        }
        
        let urlWithoutLastPath = URL(fileURLWithPath: path).deletingLastPathComponent()
        
        var finalPath = urlWithoutLastPath.path
        if finalPath.hasPrefix("/") {
            finalPath.removeFirst()
        }
        
        return finalPath
    }
}
