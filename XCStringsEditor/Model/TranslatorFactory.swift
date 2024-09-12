//
//  TranslatorFactory.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
final class TranslatorFactory {
    let googleTranslator = GoogleTranslator()
    
     func makeTranslator() -> Translator {
        return GoogleTranslator()
    }
     func setAPIKey(_ key: String,to service: TranslateService) {
        switch service {
        case .google:
            googleTranslator.translateAPI.apiKey = key
        default:
            break
        }
    }
    
}
