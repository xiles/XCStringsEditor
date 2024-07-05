//
//  FileDropView.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 7/4/24.
//

import SwiftUI

struct FileDropView: NSViewRepresentable {
    var handleDroppedFile: (URL) -> Void

    class Coordinator: NSObject, NSDraggingDestination {
        var parent: FileDropView

        init(parent: FileDropView) {
            self.parent = parent
        }

        func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            return .copy
        }

        func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            let pasteboard = sender.draggingPasteboard
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                for url in urls {
                    self.parent.handleDroppedFile(url)
                }
                return true
            }
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = CustomNSView()
        view.delegate = context.coordinator
        view.registerForDraggedTypes([.fileURL])
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class CustomNSView: NSView {
        weak var delegate: NSDraggingDestination?

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            return delegate?.draggingEntered?(sender) ?? []
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            return delegate?.performDragOperation?(sender) ?? false
        }
    }
}
