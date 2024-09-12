//
//  Translator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 5/9/24.
//

import Foundation
protocol Translator{
    var translateAPI: TranslateAPI {get set}
    func translate(text:String,source: String, target: String, format: String, model: String) async throws -> String
    func detect(text:String) async throws -> [Detection]
    func languages(model:String,target:String) async throws ->[SupportLanguage]
    
}
class GoogleTranslator:Translator{
    var translateAPI: any TranslateAPI = GoogleTranslateAPI()
    func translate(text: String, source: String, target: String, format: String = "text", model: String = "base") async throws -> String {
        let result:[String:Any] = try await NetworkManager.request(endpoint:
                                    translateAPI.translate(text: text, source: source, target: target, format: format, model: model))
        guard
            let d = result["data"] as? [String: Any],
            let translations = d["translations"] as? [[String: String]],
            let translation = translations.first,
            let translatedText = translation["translatedText"], translatedText.isEmpty == false
        else {
            throw TranslatorError.responseError
        }
        return translatedText
        
    }
    
    func detect(text: String) async throws -> [Detection] {
        if let api = try translateAPI.detect(text: text){
            let result:[String:Any] = try await NetworkManager.request(endpoint: api)
            guard
                let d = result["data"] as? [String: Any],
                let detections = d["detections"] as? [[[String: Any]]]
            else {
                throw TranslatorError.responseError
            }
            var ans = [Detection]()
            for languageDetections in detections {
                for detection in languageDetections {
                    if let language = detection["language"] as? String,
                        let isReliable = detection["isReliable"] as? Bool,
                        let confidence = detection["confidence"] as? Float {
                        ans.append(Detection(language: language, isReliable: isReliable, confidence: confidence))
                    }
                }
            }
            return ans
        }else{
            if let ans = LanguageRecognizer.detectLanguage(for: text){
                return ans
            }else{
                throw TranslatorError.invalidInput
            }
        }
    }
    
    func languages(model target: String = "en", target model: String = "base") async throws ->[SupportLanguage]{
        if let api = try translateAPI.languages(model: model, target: target){
            let result:[String:Any] = try await NetworkManager.request(endpoint: api)
            guard
                let d = result["data"] as? [String: Any],
                let languages = d["languages"] as? [[String: String]]
            else {
                throw TranslatorError.responseError
            }
            var ans = [SupportLanguage]()
            for language in languages {
                if let code = language["language"], let name = language["name"] {
                    ans.append(SupportLanguage(language: code, name: name))
                }
            }
            return ans
        }else{
            throw TranslatorError.invalidAPI
        }
    }
}
