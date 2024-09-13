//
//  Translator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 5/9/24.
//

import Foundation
protocol Translator{
    var translateAPI: TranslateAPI {get}
    func translate(_ inputModel:InputModel) async throws -> String
    func detect(text:String) async throws -> [Detection]
    func languages(model:String,target:String) async throws ->[SupportLanguage]
    
}
