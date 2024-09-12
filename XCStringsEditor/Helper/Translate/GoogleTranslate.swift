//
//  GoogleTranslate.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/22/24.
//

import Foundation

enum GoogleTranslateError: Error {
    case invalidAPIURL
    case invalidResponse
    case parsingResponse
    case emptyText
}

/// A helper class for using Google Translate API.
public class GoogleTranslate {
        
    /// Shared instance.
    public static let shared = GoogleTranslate()

    /// Language response structure.
    public struct Language {
        public let language: String
        public let name: String
    }
    
    /// Detect response structure.
    
    /// API structure.
    private struct API {
        /// Base Google Translation API url.
        static let base = "https://translation.googleapis.com/language/translate/v2"
        
        /// A translate endpoint.
        struct translate {
            static let method = "POST"
            static let url = API.base
        }
        
        /// A detect endpoint.
        struct detect {
            static let method = "POST"
            static let url = API.base + "/detect"
        }
        
        /// A list of languages endpoint.
        struct languages {
            static let method = "GET"
            static let url = API.base + "/languages"
        }
    }
    
    /// API key.
    private var apiKey: String!
    /// Default URL session.
    private let session = URLSession(configuration: .default)
    
    public var isAvailable: Bool {
        return apiKey != nil && apiKey.isEmpty == false
    }
    
    
    /// Configure API key.
    /// - Parameter apiKey: An API key to handle requests for Google Cloud Translate API.
    public func configure(apiKey: String) {
        self.apiKey = apiKey
    }
    
    
    /// Translate text.
    /// - Parameters:
    ///   - q: Text to be translated.
    ///   - source: Source language code.
    ///   - target: Target language code.
    ///   - format: The format of the source text. A value can be "html" in HTML format or "text" in plain text. The default value is "text"."
    ///   - model: The translation model. Can be either base to use the Phrase-Based Machine Translation (PBMT) model, or nmt to use the Neural Machine Translation (NMT) model. If omitted, then nmt is used. If the model is nmt, and the requested language translation pair is not supported for the NMT model, then the request is translated using the base model.
    /// - Returns: Translated text.
    public func translate(_ q: String, source: String, target: String, format: String = "text", model: String = "base") async throws -> String {
        guard var urlComponents = URLComponents(string: API.translate.url) else {
            throw GoogleTranslateError.invalidAPIURL
        }
        
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        queryItems.append(URLQueryItem(name: "q", value: q))
        queryItems.append(URLQueryItem(name: "target", value: target))
        queryItems.append(URLQueryItem(name: "source", value: source))
        queryItems.append(URLQueryItem(name: "format", value: format))
        queryItems.append(URLQueryItem(name: "model", value: model))
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw GoogleTranslateError.invalidAPIURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = API.translate.method
        
        let (data, urlResponse) = try await session.data(for: urlRequest)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode >= 200 && statusCode < 300 else {
            throw GoogleTranslateError.invalidResponse
        }
        
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleTranslateError.parsingResponse
        }
        
        guard
            let d = object["data"] as? [String: Any],
            let translations = d["translations"] as? [[String: String]],
            let translation = translations.first,
            let translatedText = translation["translatedText"], translatedText.isEmpty == false
        else {
            throw GoogleTranslateError.parsingResponse
        }
                
        return translatedText
    }
    
    
    /// Detect a language of the text.
    /// - Parameter q: Text to be detected.
    /// - Returns: A list of delected languages
    public func detectLanguage(_ q: String) async throws -> [Detection] {
        guard var urlComponents = URLComponents(string: API.detect.url) else {
            throw GoogleTranslateError.invalidAPIURL
        }
        
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        queryItems.append(URLQueryItem(name: "q", value: q))
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw GoogleTranslateError.invalidAPIURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = API.detect.method
        
        let (data, urlResponse) = try await session.data(for: urlRequest)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode >= 200 && statusCode < 300 else {
            throw GoogleTranslateError.invalidResponse
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleTranslateError.parsingResponse
        }
        
        guard
            let d = object["data"] as? [String: Any],
            let detections = d["detections"] as? [[[String: Any]]]
        else {
            throw GoogleTranslateError.parsingResponse
        }

        
        var result = [Detection]()
        for languageDetections in detections {
            for detection in languageDetections {
                if let language = detection["language"] as? String,
                    let isReliable = detection["isReliable"] as? Bool,
                    let confidence = detection["confidence"] as? Float {
                    result.append(Detection(language: language, isReliable: isReliable, confidence: confidence))
                }
            }
        }
        return result
    }
    
    /// Fetch a list of supported languages for translation.
    /// - Parameters:
    ///   - target: The target language code for the results. If specified, then the language names are returned in the name field of the response, localized in the target language. If you do not supply a target language, then the name field is omitted from the response and only the language codes are returned.
    ///   - model: The translation model of the supported languages. Can be either base to return languages supported by the Phrase-Based Machine Translation (PBMT) model, or nmt to return languages supported by the Neural Machine Translation (NMT) model. If omitted, then all supported languages are returned. Languages supported by the NMT model can only be translated to or from English (en).
    /// - Returns: A list of supported languages.
    public func languages(target: String = "en", model: String = "base") async throws -> [Language] {
        guard var urlComponents = URLComponents(string: API.languages.url) else {
            throw GoogleTranslateError.invalidAPIURL
        }
        
        var queryItems = [URLQueryItem]()
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        queryItems.append(URLQueryItem(name: "target", value: target))
        queryItems.append(URLQueryItem(name: "model", value: model))
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw GoogleTranslateError.invalidAPIURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = API.detect.method
        
        let (data, urlResponse) = try await session.data(for: urlRequest)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode >= 200 && statusCode < 300 else {
            throw GoogleTranslateError.invalidResponse
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GoogleTranslateError.parsingResponse
        }
        
        guard
            let data = object["data"] as? [String: Any],
            let languages = data["languages"] as? [[String: String]]
        else {
            throw GoogleTranslateError.parsingResponse
        }
        
        var result = [Language]()
        for language in languages {
            if let code = language["language"], let name = language["name"] {
                result.append(Language(language: code, name: name))
            }
        }
        
        return result
    }
}
