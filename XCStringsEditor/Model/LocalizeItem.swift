//
//  LocalizeItem.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 2/4/24.
//

import Foundation
import SwiftUI

struct LocalizeItem: Identifiable, Hashable, CustomStringConvertible {
    /// Enum representing the various states of a LocalizeItem.
    enum State: Int, Comparable {
        static func < (lhs: LocalizeItem.State, rhs: LocalizeItem.State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        /// Item is newly created and not yet translated.
        case new
        /// Item has been translated.
        case translated
        /// Item is not used in code.
        case stale
        /// Item needs to be reviewed for accuracy. Manually marked by the user.
        case needsReview
        /// Item is marked as "Do not translate". Manually marked by the user.
        case dontTranslate
        /// Item requires additional work or corrections. Manually marked by the user. Managed in XCStringsEditor not Xcode.
        case needsWork
        /// Item is marked to be translated later. Manually marked by the user. Managed in XCStringsEditor not Xcode.
        case translateLater
    }

    /// Separator used in item IDs for dividing different components.
    static let ID_DIVIDER = "|XCSTRINGEDITORDIVIDER|"
    
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
            return isTranslated ? .translated : .new
        }
    }
    
    var isStale: Bool = false
    var needsReview: Bool
    
    var translateLater: Bool
    var needsWork: Bool
    var shouldTranslate: Bool = true

    /// Tracks if the item has been modified.
    var isModified: Bool = false

    /// Check if the item has been translated.
    var isTranslated: Bool {
        return contains(matching: { $0.translation == nil }) == false
    }

    /// Checks the extent to which the translation and reverse translation match.
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
    
    /// Child items for hierarchical data.
    var children: [LocalizeItem]?
    
    /// Description for debugging and logging purposes.
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

    /// Finds a child item by its ID.
    ///
    /// - Parameter id: The ID to search for.
    /// - Returns: The matching `LocalizeItem`, or `nil` if not found.
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
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

//    static func == (lhs: LocalizeItem, rhs: LocalizeItem) -> Bool {
//        return lhs.id == rhs.id
//        && lhs.translation == rhs.translation
//        && lhs.reverseTranslation == rhs.reverseTranslation
//        && lhs.state == rhs.state
//        && lhs.isModified == rhs.isModified
//    }
    
    /// Check if an item or its children match a condition.
    ///
    /// - Parameters:
    ///   - item: The `LocalizeItem` to evaluate.
    ///   - matching: Closure defining the matching condition.
    /// - Returns: `true` if the condition is met; otherwise, `false`.
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

    /// Extracts the base ID from a composite ID.
    ///
    /// - Parameter id: The composite ID to process.
    /// - Returns: The base ID.
    static func baseID(_ id: LocalizeItem.ID) -> LocalizeItem.ID {
        let components = id.components(separatedBy: LocalizeItem.ID_DIVIDER)
        let key = components[0]
        let subcomponents = components[1].components(separatedBy: "/")
        let langCode = subcomponents[0]
        
        return "\(key)\(ID_DIVIDER)\(langCode)"
    }
}
