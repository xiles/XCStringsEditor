//
//  AppModel_DeepL.swift
//  XCStringsEditor
//
//  Created by Michal on 07.05.2024.
//

import Foundation

//MARK: - DeepL
extension AppModel {
    
    func translateByDeepL(ids: Set<LocalizeItem.ID>? = nil) async {
        guard DeepL.shared.isAvailable == true else {
            showAPIKeyAlert = true
            return
        }
        
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = self.item(with: itemID) else {
                continue
            }
            
            let (translation, reverseTranslation) = await self.translateByDeepL(text: item.sourceString, language: item.language)
            if let translation {
                self.updateTranslation(for: itemID, with: translation, reverseTranslation: reverseTranslation)
            }
        }
    }
    
    
    private func translateByDeepL(text: String, language: Language) async -> (String?, String?) {
        guard let xcstrings else {
            return (nil, nil)
        }
        
        do {
            let sourceLanguage = xcstrings.sourceLanguage
            
            let translation = try await DeepL.shared.translate(text, source: sourceLanguage.code, target: language.code)
            let reverseTranslation = try await DeepL.shared.translate(translation, source: language.code, target: sourceLanguage.code)

            return (translation, reverseTranslation.replacingOccurrences(of: "** ", with: "**"))

        } catch {
            return (nil, nil)
        }
    }
    
    private func translateByDeepL(text: String, from sourceLanguage: Language, to targetLanguage: Language) async -> String? {
        do {
            let translation = try await DeepL.shared.translate(text, source: sourceLanguage.code, target: targetLanguage.code)
            return translation
            
        } catch {
            return nil
        }
    }


    func reverseTranslateByDeepL(ids: Set<LocalizeItem.ID>? = nil) {
        guard DeepL.shared.isAvailable == true else {
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
                
                let reverseTranslation = await self.translateByDeepL(text: translation, from: item.language, to: xcstrings?.sourceLanguage ?? .english)
                item.reverseTranslation = reverseTranslation
            }
        }
    }
}
