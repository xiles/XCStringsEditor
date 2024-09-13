//
//  BaiduAPI.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 13/9/24.
//

import Foundation
import CommonCrypto
struct BaiduTranslateAPI:TranslateAPI{
    var apiKey: String?{
        UserDefaults.standard.baiduAPIKey
    }
    var appID: String?{
        UserDefaults.standard.baiduAppID
    }
    func translate(_ input:InputModel) throws -> any API {
        try checkAPIKey()
        let salt = String(Int.random(in: 32768...65536))
        let sign = makeMD5(appID! + input.text + salt + apiKey!)
        
        return BaiduAPI.translate(input:input, apiKey: apiKey!, appID: UserDefaults.standard.baiduAppID, salt: salt, sign: sign)
    }
    
    func detect(text: String) throws -> (any API)? {
        return nil
    }
    
    func languages(model: String, target: String) throws -> (any API)? {
        return nil
    }
    func checkAPIKey()throws{
        guard apiKey != nil  && appID != nil  && !apiKey!.isEmpty && !appID!.isEmpty else {
            throw TranslatorError.invalidAPI
        }
    }
    private func makeMD5(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = data.withUnsafeBytes {
            //baidu still use md5
            CC_MD5($0.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
enum BaiduAPI: API {
    var method: HTTPMethod{
        HTTPMethod.get
    }
    case translate(input:InputModel, apiKey:String,appID:String,salt:String,sign:String)
    var scheme: HTTPScheme{
        return .https
    }
    var baseURL: String {
        return "fanyi-api.baidu.com"
    }
    var path: String {
        switch self {
        case .translate:
            return "/api/trans/vip/translate"
        }
    }
    var parameters: [URLQueryItem] {
        switch self {
        case .translate(let input,let apiKey,let appID,let salt,let sign):
            return [
                URLQueryItem(name: "appid", value: appID),
                URLQueryItem(name: "q", value: input.text),
                URLQueryItem(name: "from", value: input.source),
                URLQueryItem(name: "to", value: input.target),
                URLQueryItem(name: "salt", value: salt),
                URLQueryItem(name: "sign", value: sign)
            ]
        }
    }
}
