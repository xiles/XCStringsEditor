//
//  AppModel_GoogleTranslate.swift
//  XCStringsEditor
//
//  Created by Michal on 07.05.2024.
//

import Foundation

//MARK: - Google Translate

extension AppModel {
    
    func detectLanguage() {
//        Task {
//            for id in self.selected {
//                guard
//                    let item = self.item(with: id),
//                    let translation = item.translation, translation.isEmpty == false
//                else {
//                    continue
//                }
//
//                let languageCode = await self.detectLanguage(text: translation)
////                print("detection", languageCode, id)
//                if languageCode == "zh-CN" {
//                    print("found zh-CN", id)
//                    item.needsWork = true
//                }
//            }
//            self.selected = []
//            print("Done Detection")
//        }
    }


    
    private func translate(text: String, language: Language) async -> (String?, String?) {
        guard let xcstrings else {
            return (nil, nil)
        }
        
        do {
            let sourceLanguage = xcstrings.sourceLanguage
            
            let translation = try await translator.translate(text: text, source: sourceLanguage.code, target: language.code)
            let reverseTranslation = try await translator.translate(text: translation, source: language.code, target: sourceLanguage.code)
            return (translation, reverseTranslation)
            
        } catch {
            return (nil, nil)
        }
    }
    

}
