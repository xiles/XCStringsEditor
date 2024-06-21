//
//  UserDefaults+Keys.swift
//  XCStringsEditor
//
//  Created by William Alexander on 14/06/2024.
//

import Foundation

extension UserDefaults {
    
    enum Keys {
        static var googleTranslateAPIKey = "GoogleTranslateAPIKey"
        static var deeplAPIKey = "DeeplAPIKey"
        static var translationService = "TranslateService"
    }
    
    var googleTranslateAPIKey: String {
        string(forKey: Keys.googleTranslateAPIKey) ?? ""
    }
    
    var deeplAPIKey: String {
        string(forKey: Keys.deeplAPIKey) ?? ""
    }
    
    var translationService: TranslateService {
        guard 
            let rawValue = string(forKey: Keys.translationService),
            let translationService = TranslateService(rawValue: rawValue)
        else {
            return .google
        }
        return translationService
    }
}
