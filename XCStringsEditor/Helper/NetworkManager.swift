//
//  NetworkManager.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation

final class NetworkManager {
    /// Builds the relevant URL components from the values specified
    /// in the API.
    private class func buildURL(endpoint: API) -> URLComponents {
        var components = URLComponents()
        components.scheme = endpoint.scheme.rawValue
        components.host = endpoint.baseURL
        components.path = endpoint.path
        if endpoint.parameters.count > 0 {
            components.queryItems = endpoint.parameters
        }
        return components
    }

    /// Executes the HTTP request and will attempt to decode the JSON
    /// response into a Codable object.
    /// - Parameters:
    /// - endpoint: the endpoint to make the HTTP request to
    /// - completion: the JSON response converted to the provided Codable
    /// object when successful or a failure otherwise
    class func request(endpoint: API) async throws -> [String: Any] {
        // Build the URL
        let components = buildURL(endpoint: endpoint)
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        // Create URL request
        var urlRequest = URLRequest(url: url)
        for header in endpoint.headers ?? [:] {
            urlRequest.setValue(header.value, forHTTPHeaderField: header.key)
        }
        urlRequest.httpMethod = endpoint.method.rawValue
        if let body = endpoint.body {
            urlRequest.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Check response status

        // Convert the response data to a dictionary using JSONSerialization
        do {
            if let jsonObject = try JSONSerialization.jsonObject(
                with: data, options: []) as? [String: Any]
            {
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    print("network error with \(jsonObject)")
                    throw TranslatorError.networkError
                }
                return jsonObject
            } else {
                throw TranslatorError.responseError
            }
        } catch {
            throw TranslatorError.responseError
        }
    }
}
