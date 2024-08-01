//
//  LocalizeItem.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/4/24.
//

import Foundation
import SwiftUI

@Observable
class LocalizeItem: Identifiable, Hashable, CustomStringConvertible {
    static func == (lhs: LocalizeItem, rhs: LocalizeItem) -> Bool {
        return lhs.id == rhs.id
        && lhs.translation == rhs.translation
        && lhs.reverseTranslation == rhs.reverseTranslation
        && lhs.state == rhs.state
        && lhs.isModified == rhs.isModified
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static let ID_DIVIDER = "|XCSTRINGEDITORDIVIDER|"
    
    enum State: Int, Comparable {
        static func < (lhs: LocalizeItem.State, rhs: LocalizeItem.State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        case new
        case needsWork
        case needsReview
        case translateLater
        case dontTranslate
        case stale
        case translated
    }
    
    var id: String
    var parentID: String?
    var key: String
    var sourceString: String
    var comment: String?
    
    var language: Language
    var translation: String?
    var reverseTranslation: String?
    var pluralType: XCString.PluralType?
    var deviceType: XCString.DeviceType?
    
    var state: State {
        if shouldTranslate == false {
            return .dontTranslate
        } else if translateLater {
            return .translateLater
        } else if needsWork {
            return .needsWork
        } else if isStale {
            return .stale
        } else if needsReview {
            return .needsReview
        } else {
            if contains(matching: { $0.translation == nil }) {
                return .new
            } else {
                return .translated
            }
        }
    }
    
    var isStale: Bool = false
    
    var translateLater: Bool
    var needsWork: Bool
    var needsReview: Bool
    var shouldTranslate: Bool = true

    var isModified: Bool = false
//    var isEditing: Bool = false

    var translationStatus: TranslationStatus {
        guard let _ = translation else { return .missingTranslation }
        guard let reverseTranslation = reverseTranslation else { return .missingReverse }
        
        if sourceString == reverseTranslation {
            return .exact
        }
        
        if sourceString.uppercased() == reverseTranslation.uppercased() {
            return .similar
        }
        
        return .different
    }
    
    var children: [LocalizeItem]?
    
    var description: String {
        var result = "\(key), \(language.code), \(translation ?? "nil"), NeedsReview: \(needsReview), Modified: \(isModified)"
        
        if let children {
            let lines = children.map { $0.description }
            result.append("\n[\(lines.joined(separator: ",\n"))\n]")
        }

        return result
    }
    
    /// Check if the item is matched or contains matched subitems with matching closure
    ///
    /// - Parameter matching: matching condition closure
    /// - returns: Returns true if the item is matched or contains matched subitems. Otherwise returns false.
    func contains(matching: (LocalizeItem) -> Bool) -> Bool {
        return Self.itemContains(self, matching: matching)
    }

    static func itemContains(_ item: LocalizeItem, matching: (LocalizeItem) -> Bool) -> Bool {
        if item.children == nil {
            if matching(item) == true {
                return true
            }
        } else if let children = item.children {
            for subitem in children {
                if itemContains(subitem, matching: matching) == true {
                    return true
                }
            }
        }
        return false
    }

    static func baseID(_ id: LocalizeItem.ID) -> LocalizeItem.ID {
        let components = id.components(separatedBy: LocalizeItem.ID_DIVIDER)
        let key = components[0]
        let subcomponents = components[1].components(separatedBy: "/")
        let langCode = subcomponents[0]
        
        return "\(key)\(ID_DIVIDER)\(langCode)"
    }
    
    func item(with id: LocalizeItem.ID) -> LocalizeItem? {
        if id == self.id {
            return self
        }
        if let children {
            for subitem in children {
                if let item = subitem.item(with: id) {
                    return item
                }
            }
        }
        return nil
    }
    
    internal init(id: String, key: String, sourceString: String, comment: String? = nil, language: Language, translation: String? = nil, reverseTranslation: String? = nil, pluralType: XCString.PluralType? = nil, deviceType: XCString.DeviceType? = nil, isStale: Bool = false, translateLater: Bool = false, needsWork: Bool = false, needsReview: Bool, shouldTranslate: Bool = true, isModified: Bool = false, children: [LocalizeItem]? = nil) {
        self.id = id
        self.key = key
        self.sourceString = sourceString
        self.comment = comment
        self.language = language
        self.translation = translation
        self.reverseTranslation = reverseTranslation
        self.pluralType = pluralType
        self.deviceType = deviceType
        self.isStale = isStale
        self.translateLater = translateLater
        self.needsWork = needsWork
        self.needsReview = needsReview
        self.shouldTranslate = shouldTranslate
        self.isModified = isModified
        self.children = children
    }
}
