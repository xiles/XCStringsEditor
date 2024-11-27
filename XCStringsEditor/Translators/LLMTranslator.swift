//
//  LLMTranslator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 10/11/24.
//

import Foundation
class LLMTranslator:Translator{
    func translate(_ inputModel: InputModel) async throws -> String {
        let result:[String:Any] = try await NetworkManager.request(endpoint:translateAPI.translate(inputModel))
        guard let choices = (result["choices"] as? Array<Any>)?.first as?[String:Any] else{
            throw TranslatorError.responseError
        }
        guard let choice = choices["message"] as? [String:Any],let ans = choice["content"] as? String else{
            throw TranslatorError.responseError
        }
        return ans
    }
    
    func detect(text: String) async throws -> [Detection] {
        return []
    }
    
    func languages(model: String, target: String) async throws -> [SupportLanguage] {
        throw TranslatorError.notImplemented
    }
    let translateAPI: any TranslateAPI = LLMTranslateAPI()
}
