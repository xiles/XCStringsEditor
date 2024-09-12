//
//  Translator.swift
//  XCStringsEditor
//
//  Created by 王培屹 on 5/9/24.
//

import Foundation
protocol Translator{
    func translate(text:String,source: String, target: String, format: String, model: String) async throws -> String
    func detect(text:String) async throws -> [Detection]
    func languages(model:String,target:String) async
    
}
