//
//  WindowDelegate.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/8/24.
//

import AppKit

@Observable
class WindowDelegate: NSObject, NSWindowDelegate {
    var allowClose: () -> Bool = {
        true
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return allowClose()
    }
}
