//
//  DeepLAPI.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
struct DeepLTranslateAPI:TranslateAPI{
    var apiKey: String?{
        UserDefaults.standard.deeplAPIKey
    }
    
    func translate(_ input:InputModel) throws -> any API {
        try checkAPIKey()
        return DeepLAPI.translate(input:input, apiKey: apiKey!)
    }
    
    func detect(text: String) throws -> (any API)? {
        return nil
    }
    
    func languages(model: String, target: String) throws -> (any API)? {
        return nil
    }
    func checkAPIKey()throws{
        guard apiKey != nil else {
            throw TranslatorError.invalidAPI
        }
    }
    
}

enum DeepLAPI: API {
    
    case translate(input:InputModel,apiKey:String)
    var scheme: HTTPScheme{
        return .https
    }
    var baseURL: String {
        return "api-free.deepl.com"
    }
    var path: String {
        switch self {
        case .translate:
            return "/v2/translate"
        }
    }
    var parameters: [URLQueryItem] {
        switch self {
        case .translate(let input,let apiKey):
            return [
                URLQueryItem(name: "auth_key", value: apiKey),
                URLQueryItem(name: "text", value: input.text),
                URLQueryItem(name: "source_lang", value: input.source),
                URLQueryItem(name: "target_lang", value: input.target)
            ]
        }
    }
    var method: HTTPMethod {
        return .post
    }
}
