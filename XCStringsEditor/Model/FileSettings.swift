//
//  FileSettings.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/24/24.
//

import Foundation

// TODO: Convert to use SwiftData

struct FileSettings: Codable {
    var lastLanguage: String = "en"

    var translateLater: [String] = []
    var needsWork: [String] = []
    
    static func load(fileURL: URL) -> FileSettings {
        guard let data = try? Data(contentsOf: fileURL) else {
            return FileSettings()
        }
        return (try? JSONDecoder().decode(FileSettings.self, from: data)) ?? FileSettings()
    }
    
    func save(to fileURL: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        if let data = try? encoder.encode(self) {
            try? data.write(to: fileURL)
        }
    }
}
