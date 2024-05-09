//
//  TranslateService.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 5/8/24.
//

import Foundation

enum TranslateService: String, CaseIterable, Identifiable, CustomStringConvertible {
    case google
    case deepL
    
    var id: Self { self }
    
    var description: String {
        switch self {
          case .google:
            return "Google Translate"
          case .deepL:
            return "DeepL"
        }
    }    
}
