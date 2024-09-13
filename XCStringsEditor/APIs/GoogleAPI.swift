//
//  GoogleAPI.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
struct GoogleTranslateAPI: TranslateAPI {
    var apiKey: String?{
        UserDefaults.standard.googleTranslateAPIKey
    }
    var apiIsEnabled: Bool {
        return apiKey != nil && apiKey!.isEmpty == false
    }
    func detect(text: String) throws -> (any API)? {
        try checkAPIKey()
        return GoogleAPI.detect(text: text, apiKey:apiKey!)
    }
    
    func languages(model: String, target: String) throws -> (any API)? {
        try checkAPIKey()
        return GoogleAPI.languages(model: model, target: target, apiKey: apiKey!)
    }
    
    func translate(_ input:InputModel)throws->API{
        try checkAPIKey()
        return GoogleAPI.translate(input: input, apiKey: apiKey!)
    }
    func checkAPIKey()throws{
        guard apiKey != nil else {
            throw TranslatorError.invalidAPI
        }
    }
}

enum GoogleAPI: API {
    case translate(input: InputModel,apiKey:String)
    case detect(text:String,apiKey:String)
    case languages(model:String,target:String,apiKey:String)
    var scheme: HTTPScheme {
        return .https
    }
    var baseURL: String {
        return "translation.googleapis.com"
    }
    var path: String {
        switch self {
        case .translate:
            return "/language/translate/v2"
        case .detect:
            return "/language/translate/v2/detect"
        case .languages:
            return "/language/translate/v2/languages"
        }
    }
    var parameters: [URLQueryItem] {
        switch self {
        case .translate(let input,let apiKey):
            return [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "q", value: input.text),
                URLQueryItem(name: "source", value: input.source),
                URLQueryItem(name: "target", value: input.target),
                URLQueryItem(name: "format", value: input.format),
                URLQueryItem(name: "model", value: input.model)
                
            ]
        case .detect(let text,let apiKey):
            return [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "q", value: text)
            ]
        case .languages(let model,let target,let apiKey):
            return [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "model", value: model),
                URLQueryItem(name: "target", value: target)
            ]
        }
    }
    var method: HTTPMethod {
        switch self {
        case .translate:
            return .post
        case .detect:
            return .post
        case .languages:
            return .get
        }
    }
}
