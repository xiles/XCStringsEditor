//
//  LanguageRecognizer.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
import NaturalLanguage
final class LanguageRecognizer{
    static func detectLanguage(for text: String) -> [Detection]? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        // Returns the most likely language
        if let languageCode = recognizer.dominantLanguage?.rawValue {
            return [.init(language: languageCode, isReliable: true, confidence: 1)]
        }
        return nil
    }
    private init(){}
}
