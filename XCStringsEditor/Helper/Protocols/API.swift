//
//  API.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
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
    /// http body
    var body:Data? { get }
    /// http headers
    var headers:[String:String]? { get }
    
    
}

protocol TranslateAPI{
    var apiKey: String? { get }
    func translate(_ input: InputModel)throws->API
    func detect(text:String)throws->API?
    func languages(model:String,target:String)throws->API?
}
