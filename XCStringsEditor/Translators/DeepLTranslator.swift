//
//  DeepLTranslator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation

class DeepLTranslator: Translator {
    func translate(_ input: InputModel) async throws -> String {
        // https://developers.deepl.com/docs/resources/supported-languages
        // DeepL source language should not add the country code
        let trimmedSource = String(input.source.split(separator: "-").first!)
        let newModel = InputModel(text: input.text, source: trimmedSource, target: input.target)
        let result: [String: Any] = try await NetworkManager.request(endpoint: translateAPI.translate(newModel))
        guard
            let d = result["translations"] as? [[String: Any]]
        else {
            throw TranslatorError.responseError
        }
        return d.compactMap {
            $0["text"] as? String
        }.joined(separator: "\n")
    }
    
    func detect(text: String) async throws -> [Detection] {
        LanguageRecognizer.detectLanguage(for: text) ?? []
    }
    
    func languages(model: String, target: String) async throws -> [SupportLanguage] {
        throw TranslatorError.notImplemented
    }
    
    var translateAPI: TranslateAPI = DeepLTranslateAPI()
}
