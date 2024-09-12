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
enum GoogleTranslateAPI: API {
    static var apiKey:String = ""
    case translate(text:String,source: String, target: String, format: String = "text", model: String = "base")
    case detect(text:String)
    case languages(model:String,target:String)
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
        case .translate(let text, let source, let target, let format, let model):
            return [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "source", value: source),
                URLQueryItem(name: "target", value: target),
                URLQueryItem(name: "format", value: format),
                URLQueryItem(name: "model", value: model)
                
            ]
        case .detect(let text):
            return [
                URLQueryItem(name: "key", value: apiKey),
                URLQueryItem(name: "q", value: text)
            ]
        case .languages(let model,let target):
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
