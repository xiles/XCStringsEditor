//
//  TranslateAPI.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 5/9/24.
//

import Foundation
enum HTTPMethod: String {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"
}
enum HTTPScheme: String {
    case http
    case https
}
protocol API {
    /// .http  or .https
    var scheme: HTTPScheme { get }
    // Example: "maps.googleapis.com"
    var baseURL: String { get }
    // "/maps/api/place/nearbysearch/"
    var path: String { get }
    // [URLQueryItem(name: "api_key", value: API_KEY)]
    var parameters: [URLQueryItem] { get }
// "GET"
    var method: HTTPMethod { get }
    
}

protocol TranslateAPI{
    var apiKey: String? { get set }
    func translate(text:String,source: String, target: String, format: String, model: String)throws->API
    func detect(text:String)throws->API?
    func languages(model:String,target:String)throws->API?
}

struct GoogleTranslateAPI: TranslateAPI {
    var apiKey: String?{
        get {
            UserDefaults.standard.string(forKey: String(describing: self))
        }
        set {
            UserDefaults.standard.set(newValue, forKey: String(describing: self))
        }
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
    
    func translate(text:String,source: String, target: String, format: String = "text", model: String = "base")throws->API{
        try checkAPIKey()
        return GoogleAPI.translate(text: text, source: source, target: target, format: format, model: model, apiKey: apiKey!)
    }
    func checkAPIKey()throws{
        guard let apiKey = apiKey else {
            throw TranslatorError.invalidAPI
        }
    }
}
enum TranslatorError: Error {
    case invalidAPI
    case invalidInput
    case responseError
    case networkError
}
enum GoogleAPI: API {
    case translate(text:String,source: String, target: String, format: String = "text", model: String = "base",apiKey:String)
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
        case .translate(let text, let source, let target, let format, let model,let apiKey):
            return [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "source", value: source),
                URLQueryItem(name: "target", value: target),
                URLQueryItem(name: "format", value: format),
                URLQueryItem(name: "model", value: model)
                
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
