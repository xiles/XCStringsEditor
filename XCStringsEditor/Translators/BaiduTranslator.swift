//
//  BaiduTranslator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
class BaiduTranslator: Translator {
    var translateAPI: any TranslateAPI = BaiduTranslateAPI()
    func translate(_ inputModel: InputModel) async throws -> String {
        let api = try translateAPI.translate(inputModel)
        let result: [String: Any] = try await NetworkManager.request(endpoint: api)
        guard let translations = result["trans_result"] as? [[String: Any]] else {
            throw TranslatorError.responseError
        }
        return translations.map { $0["dst"] as? String ?? "" }.joined(separator: "\n")
    }
    
    func detect(text: String) async throws -> [Detection] {
        LanguageRecognizer.detectLanguage(for: text) ?? []
    }
    
    func languages(model: String, target: String) async throws -> [SupportLanguage] {
        throw TranslatorError.notImplemented
    }
    
}
