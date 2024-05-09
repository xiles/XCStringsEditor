//
//  DeepL.swift
//  XCStringsEditor
//
//  Created by Michal on 07.05.2024.
//

import Foundation

/// A helper class for using DeepL API.
public class DeepL {
    
    /// Shared instance.
    public static let shared = DeepL()
    
    /// API key.
    private var apiKey: String!

    private let session = URLSession(configuration: .default)
    
    public var isAvailable: Bool {
        return apiKey != nil && apiKey.isEmpty == false
    }
    
    
    /// Configure API key.
    /// - Parameter apiKey: An API key to handle requests for DeepL API.
    public func configure(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /// Translate text.
    /// - Parameters:
    ///   - q: Text to be translated.
    ///   - source: Source language code.
    ///   - target: Target language code.
    /// - Returns: Translated text.
    public func translate(_ q: String, source: String, target: String) async throws -> String {
        
        guard let url = URL(string: "https://api-free.deepl.com/v2/translate?text="+q+"&target_lang="+target+"&source_lang="+source+"&auth_key="+apiKey) else { fatalError("Missing URL") }

        let urlRequest = URLRequest(url: url)
        
        let (data, urlResponse) = try await session.data(for: urlRequest)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode >= 200 && statusCode < 300 else {
            throw GoogleTranslateError.invalidResponse
        }
        
        do {
            let decoded = try JSONDecoder().decode(DeepLResponse.self, from: data)
            return decoded.resultText
        } catch let error {
            print("Error decoding: ", error)
        }
        return ""
    }
        
}

fileprivate struct DeepLResponse: Decodable {
    let translations: [Translation]
    
    var resultText: String {
        translations.map(\.text).joined(separator: "\n")
    }
    
    struct Translation: Decodable {
        let detected_source_language: String
        let text: String
    }
}

