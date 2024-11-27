//
//  LLMAPI.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 10/11/24.
//

import Foundation
struct LLMTranslateAPI: TranslateAPI {
    func translate(_ input: InputModel) throws -> any API {
        guard let apiKey = apiKey,let url = llmURL, let llmModel = llmModel, let path = path else {
            throw TranslatorError.invalidAPI
        }
        return LLMAPI.translate(input: input, url: url, path:path, model: llmModel, apiKey: apiKey)
    }
    
    func detect(text: String) throws -> (any API)? {
        guard let apiKey = apiKey,let url = llmURL, let llmModel = llmModel, let path = path else {
            throw TranslatorError.invalidAPI
        }
        return LLMAPI.detect(text: text, url: url, path: path, model: llmModel, apiKey: apiKey)
    }
    
    func languages(model: String, target: String) throws -> (any API)? {
        return nil
    }
    
    var apiKey: String? {
        UserDefaults.standard.llmAPIKey
    }
    var llmURL: String? {
        let s = UserDefaults.standard.llmURL
        let host = URLComponents(string: s)?.url?.host()
        return host
    }
    var llmModel: String? {
        let model = UserDefaults.standard.llmModel
        if model.isEmpty {
            return nil
        } else {
            return model
        }
    }
    var path: String? {
        let s = UserDefaults.standard.llmURL
        let url = URLComponents(string: s)
        return url?.url?.path()
    }
    
    


}


enum LLMAPI: API {
    case translate(
        input: InputModel, url: String, path: String, model: String,
        apiKey: String)
    case detect(
        text: String, url: String, path: String, model: String, apiKey: String)
    var scheme: HTTPScheme {
        return .https
    }

    var baseURL: String {
        switch self {
        case .translate(_, let url, _, _, _):
            return url
        case .detect(_, let url, _, _, _):
            return url
        }
    }

    var path: String {
        switch self {
        case .translate(_, _, let path, _, _):
            return path
        case .detect(_, _, let path, _, _):
            return path
        }
    }
    private var message: [Any] {
        switch self {
        case .translate(let input, _, _, _, _):
            return [
                [
                    "content":
                        "You are a professional translator, translate \"\(input.text)\" in language \(input.source) to language \(input.target), you should not output other than the translated text. ",
                    "role": "user",
                ]
            ]
        case .detect(let text, _, _, _, _):
            return [
                [
                    "content":
                        "You are a professional translator, detect the language of the text \"\(text)\". you should only output the language code.",
                    "role": "user",
                ]
            ]

        }
    }
    private var model: String {
        switch self {
        case .translate(_, _, _, let model, _):
            return model
        case .detect(_, _, _, let model, _):
            return model
        }
    }
    var parameters: [URLQueryItem] {
        return []
    }

    var method: HTTPMethod {
        return .post
    }
    var body: Data? {

        let json: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": message,
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    var headers: [String: String]? {
        switch self {
        case .translate(_, _, _, _, let apiKey):
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey)",
            ]
        case .detect(_, _, _, _, let apiKey):
            return [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(apiKey)",
            ]
        }

    }

}
protocol LanguageModelAPI {
    /// .http  or .https
    var scheme: HTTPScheme { get }
    // Example: "maps.googleapis.com"
    var baseURL: String { get }

    var path: String { get }

    var key: String { get }

    var method: HTTPMethod { get }

    var payload: Data { get }
}

enum ZhiPuAPI: LanguageModelAPI {
    case contextUnderstand(text: String, context: String)
    var scheme: HTTPScheme {
        return .https
    }

    var baseURL: String {
        return "open.bigmodel.cn"
    }

    var modelName: String {
        return "glm-3-turbo"
    }

    var path: String {
        switch self {
        case .contextUnderstand:
            return "/api/paas/v4/chat/completions"
        }
    }

    var prompt: String {
        switch self {
        case .contextUnderstand(let text, let context):
            let temp = "你是一个专业的翻译，告诉我在以下文字中 \(context), 结合情景，“\(text)” 的意思是什么"
            print(temp)
            return temp
        }
    }

    var key: String {
        return "d5c1d5294dce01101cc6ff5fa197b065.aoGOPfYGzXZ3ML8p"
    }

    var method: HTTPMethod {
        return .post
    }

    var payload: Data {
        switch self {
        case .contextUnderstand:
            let json: [String: Any] = [
                "model": modelName,
                "stream": true,
                "messages": [
                    [
                        "role": "user",
                        "content": prompt,
                    ]
                ],
            ]
            return try! JSONSerialization.data(withJSONObject: json)
        }
    }
}
