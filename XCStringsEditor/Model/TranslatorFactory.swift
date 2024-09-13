//
//  TranslatorFactory.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
final class TranslatorFactory {
    static private let googleTranslator = GoogleTranslator()
    static private let deepLTranslator = DeepLTranslator()
    static var translator:any Translator{
        get{
            switch UserDefaults.standard.translationService {
            case .google:
                return googleTranslator
            case .deepL:
                return deepLTranslator
            }
        }
    }
}
