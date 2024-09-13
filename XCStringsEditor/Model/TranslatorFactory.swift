//
//  TranslatorFactory.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
final class TranslatorFactory {
    static var translator:any Translator{
        get{
            switch UserDefaults.standard.translationService {
            case .google:
                return GoogleTranslator()
            case .deepL:
                return DeepLTranslator()
            case .baidu:
                return BaiduTranslator()
            }
        }
    }
}
