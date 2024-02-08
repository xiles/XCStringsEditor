//
//  AppDelegate.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/8/24.
//

import AppKit

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
}
