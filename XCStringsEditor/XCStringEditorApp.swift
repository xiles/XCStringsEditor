//
//  XCStringEditorApp.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/20/24.
//

import SwiftUI

extension Notification.Name {
    static let findCommand = Notification.Name("findCommand")
}

@main
struct XCStringEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.controlActiveState) private var controlActiveState
    
    @State private var appModel: AppModel = AppModel()
    @State private var isDiscardConfirmVisible: Bool = false
    
    var body: some Scene {
        Window("XCStringsEditor", id: "main") {
            ContentView()
                .background(FileDropView { url in
                    openURL(url)
                })
                .environment(appModel)
                .environment(appDelegate.windowDelegate)
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { newValue in
                    if let url = appModel.settingsFileURL {
                        appModel.settings.save(to: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .receivedOpenURLsNotification), perform: { newValue in
                    guard let urls = newValue.userInfo?["urls"] as? [URL], let url = urls.first else {
                        return
                    }
                    
                    openURL(url)
                })
                .confirmationDialog("Unsaved Changes Detected", isPresented: $isDiscardConfirmVisible) {
                    Button("Save and Open", role: .none) {
                        guard let url = appModel.openingFileURL else {
                            return
                        }
                        appModel.save()
                        appModel.load(file: url)
                    }
                    
                    Button("Discard and Open", role: .destructive) {
                        guard let url = appModel.openingFileURL else {
                            return
                        }
                        appModel.load(file: url)
                    }
                    
                    Button("Cancel", role: .cancel) {
                    }
                } message: {
                    Text("You have unsaved changes. Do you want to save your changes before opening a new file?")
                }

        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Divider()
                Button("Open") {
                    open()
                }
                .keyboardShortcut("o", modifiers: [.command]) // Cmd + O
                
                Menu("Open Recent") {
                    let recents = (UserDefaults.standard.array(forKey: "RecentFiles") as? [String])?.map { URL(filePath: $0) } ?? [URL]()
                    if recents.isEmpty == false {
                        ForEach(recents.reversed(), id: \.self) { url in
                            Button {
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
                                    Text(verbatim: url.lastPathComponent)
                                }
                            }
                        }
                        Divider()
                        Button("Clear Menu") {
                            UserDefaults.standard.removeObject(forKey: "RecentFiles")
                        }
                    }
                }
                
                Divider()
                
                Button("Save") {
                    appModel.save()
                }
                .keyboardShortcut("s", modifiers: [.command]) // Cmd + S
                .disabled(appModel.fileURL == nil)
            }
            CommandGroup(after: .pasteboard) {
                Button("Copy Source Text") {
                    appModel.copySourceText()
                }
                .keyboardShortcut("c", modifiers: [.command, .control]) // Cmd + Control + C
                .disabled(appModel.selected.isEmpty)
                
                Button("Copy Translation") {
                    appModel.copyTranslationText()
                }
                .keyboardShortcut("c", modifiers: [.command, .option]) // Cmd + Option + C
                .disabled(appModel.selected.isEmpty)

                Button("Copy Source and Translation Text") {
                    appModel.copySourceAndTranslationText()
                }
                .keyboardShortcut("c", modifiers: [.command, .option, .control]) // Cmd + Option + Control + C
                .disabled(appModel.selected.isEmpty)

                Divider() // ------------------------
                
                Button("Clear Translation") {
                    appModel.clearTranslation()
                }
                .keyboardShortcut("e", modifiers: [.command]) // Cmd + E
                .disabled(appModel.selected.isEmpty)
                
                Button("Copy from Source Text") {
                    appModel.copyFromSourceText()
                }
                .keyboardShortcut("d", modifiers: [.command]) // Cmd + D
                .disabled(appModel.selected.isEmpty)
                
                Divider() // ------------------------
                
                Button("Mark for Review") {
                    appModel.markNeedsReview()
                }
                .disabled(appModel.selected.isEmpty)
                Button("Mark as Reviewed") {
                    appModel.reviewed()
                }
                .disabled(appModel.selected.isEmpty)

                if appModel.selected.isEmpty == false && appModel.items(with: Array(appModel.selected)).allSatisfy({ $0.shouldTranslate == false }) {
                    Button("Mark for Translation") {
                        appModel.setShouldTranslate(true)
                    }
                } else {
                    Button("Mark as \"Don't Translate\"") {
                        appModel.setShouldTranslate(false)
                    }
                    .disabled(appModel.selected.isEmpty)
                }
                                
                Divider()
                
                Button("Mark for Translate Later") {
                    appModel.markTranslateLater(value: true)
                }
                .keyboardShortcut("l", modifiers: [.command]) // Cmd + L
                .disabled(appModel.selected.isEmpty)
                
                Button("Unmark Translate Later") {
                    appModel.markTranslateLater(value: false)
                }
                .keyboardShortcut("l", modifiers: [.shift, .command]) // Cmd + Shift + L
                .disabled(appModel.selected.isEmpty)
                
                Button("Mark for Needs Work") {
                    appModel.markNeedsWork(value: true)
                }
                .keyboardShortcut("w", modifiers: [.control, .command]) // Cmd + Control + W
                .disabled(appModel.selected.isEmpty)

                Button("Mark for Needs Work for All Languages") {
                    appModel.markNeedsWork(value: true, allLanguages: true)
                }
                .disabled(appModel.selected.isEmpty)
                .keyboardShortcut("w", modifiers: [.control, .option, .command]) // Cmd + Option + Control + W
                
                Button("Clear Needs Work for All Languages") {
                    appModel.clearNeedsWork(allLanguages: true)
                }

                Button("Unmark Needs Work") {
                    appModel.markNeedsWork(value: false)
                }
                .keyboardShortcut("w", modifiers: [.control, .shift, .command]) // Cmd + Shift + Control + W
                .disabled(appModel.selected.isEmpty)

                Divider() // ------------------------
                
                Button("Auto Translate") {
                    Task {
                        await appModel.translate()
                    }
                }
                .keyboardShortcut("t", modifiers: [.command, .option]) // Cmd + Option + T
                .disabled(appModel.selected.isEmpty)

                Button("Reverse Translate") {
                    appModel.reverseTranslate()
                }
                .keyboardShortcut("t", modifiers: [.shift, .option, .command]) // Cmd + Option + Shift + T
                .disabled(appModel.selected.isEmpty)

                Button("Check Translation") {
                    appModel.detectLanguage()
                }
                .disabled(true) //stringsModel.selected.isEmpty)
            }
            CommandGroup(after: .toolbar) {
                Button(appModel.staleItemsHidden ? "Show Stale Items" : "Hide Stale Items") {
                    appModel.staleItemsHidden.toggle()
                }
                Button(appModel.dontTranslateItemsHidden ? "Show \"Don't Translate\" Items" : "Hide \"Don't Translate\" Items") {
                    appModel.dontTranslateItemsHidden.toggle()
                }
                Button(appModel.translateLaterItemsHidden ? "Show Translate Later Items" : "Hide Translate Later Items") {
                    appModel.translateLaterItemsHidden.toggle()
                }
                Divider()
            }
            
            CommandGroup(replacing: .appInfo) {
                Button("About XCStringsEditor") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "https://github.com/xiles",
                                attributes: [
                                    NSAttributedString.Key.font: NSFont.boldSystemFont(
                                        ofSize: NSFont.smallSystemFontSize)
                                ]
                            )
                        ]
                    )
                }
            }
        } // commands
        
        Settings {
            SettingsView()
                .environment(appModel)

        }
    }
}

extension XCStringEditorApp {
    func open() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            if let fileURL = panel.url {
                openURL(fileURL)
            }
        }
    }

    private func openURL(_ url: URL) {
        if appModel.isModified == false {
            appModel.load(file: url)
        } else {
            appModel.openingFileURL = url
            isDiscardConfirmVisible = true
        }
    }
}
