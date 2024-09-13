//
//  BaiduTranslator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
class BaiduTranslator: Translator {
    
    //https://api.fanyi.baidu.com/doc/21
    //baidu sucks!
    private static let languageConvertTable:[String:String]=[
        "zh-HK":"cht",
        "zh-TW":"cht",
        "zh-CN":"zh",
        "zh-Hans":"zh",
        "zh-Hant":"cht",
        "da":"dan",
        "ko":"kor",
        "ja":"jp",
        "es":"spa",
        "fr":"fra",
        "fr-CA":"fra",
        "en-AU":"en",
        "en-GB":"en",
        "en-IN":"en",
        "pt-BR":"pt",
        "pt-PT":"pt",
        "es-419":"spa",
        "vi":"vie"
    ]
    var translateAPI: any TranslateAPI = BaiduTranslateAPI()
    func translate(_ inputModel: InputModel) async throws -> String {
        let source = BaiduTranslator.languageConvertTable[inputModel.source] ?? inputModel.source
        let target = BaiduTranslator.languageConvertTable[inputModel.target] ?? inputModel.target
        let newModel = InputModel(text: inputModel.text, source: source, target: target)
        let api = try translateAPI.translate(newModel)
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
