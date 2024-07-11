//
//  AppDelegate.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/8/24.
//

import AppKit

extension Notification.Name {
    static let receivedOpenURLsNotification = Notification.Name("ReceivedOpenURLsNotification")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowDelegate = WindowDelegate()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.delegate = windowDelegate
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if windowDelegate.allowClose() == false {
            return .terminateCancel
        }
        return .terminateNow
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        if windowDelegate.isOpening {
            return false
        }
        return true
    }
    
//    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
//        print("openFile", filename)
//        return true
//    }
//    
//    func application(_ sender: NSApplication, openFiles filenames: [String]) {
//        print("openFiles", filenames)
//    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        print("urls", urls)
        guard urls.isEmpty == false else {
            return
        }
        
        NotificationCenter.default.post(name: .receivedOpenURLsNotification, object: nil, userInfo: ["urls": urls])
    }
}
