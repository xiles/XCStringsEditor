//
//  AppModel_GoogleTranslate.swift
//  XCStringsEditor
//
//  Created by Michal on 07.05.2024.
//

import Foundation

//MARK: - Google Translate

extension AppModel {
    
    func translateByGoogle(ids: Set<LocalizeItem.ID>? = nil) async {
        guard GoogleTranslate.shared.isAvailable == true else {
            showAPIKeyAlert = true
            return
        }
        
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = self.item(with: itemID) else {
                continue
            }
            
            let (translation, reverseTranslation) = await self.translateByGoogle(text: item.sourceString, language: item.language)
            if let translation {
                self.updateTranslation(for: itemID, with: translation, reverseTranslation: reverseTranslation)
            }
        }

    }
    

    func reverseTranslateByGoogle(ids: Set<LocalizeItem.ID>? = nil) {
        guard GoogleTranslate.shared.isAvailable == true else {
            showAPIKeyAlert = true
            return
        }

        let itemIDs = ids ?? self.selected

        Task {
            for itemID in itemIDs {
                guard
                    let item = self.item(with: itemID),
                    let translation = item.translation, translation.isEmpty == false
                else {
                    continue
                }
                
                let reverseTranslation = await self.translateByGoogle(text: translation, from: item.language, to: xcstrings?.sourceLanguage ?? .english)
                item.reverseTranslation = reverseTranslation
            }
        }
    }
    
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


    
    private func translateByGoogle(text: String, language: Language) async -> (String?, String?) {
        guard let xcstrings else {
            return (nil, nil)
        }
        
        do {
            let sourceLanguage = xcstrings.sourceLanguage
            
            let translation = try await GoogleTranslate.shared.translate(text, source: sourceLanguage.code, target: language.code)
            let reverseTranslation = try await GoogleTranslate.shared.translate(translation, source: language.code, target: sourceLanguage.code)
            
            return (translation, reverseTranslation)
            
        } catch {
            return (nil, nil)
        }
    }
    
    
    private func translateByGoogle(text: String, from sourceLanguage: Language, to targetLanguage: Language) async -> String? {
        do {
            let translation = try await GoogleTranslate.shared.translate(text, source: sourceLanguage.code, target: targetLanguage.code)
            return translation
            
        } catch {
            return nil
        }
    }
    
    
    func detectLanguage(text: String) async -> String? {
        do {
            let languages = try await GoogleTranslate.shared.detectLanguage(text)
            return languages.first?.language
        } catch {
            return nil
        }
    }
    
}
