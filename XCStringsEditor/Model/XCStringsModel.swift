//
//  XCStrings.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/20/24.
//

import Foundation
import Combine
import AppKit

struct Filter {
    var new: Bool = false
    var translated: Bool = false
    var modified: Bool = false
    var needsReview: Bool = false
    var needsWork: Bool = false
    var translateLater: Bool = false
    var sourceEqualTranslation: Bool = false
    
    mutating func reset() {
        new = false
        translated = false
        modified = false
        needsReview = false
        needsWork = false
        translateLater = false
        sourceEqualTranslation = false
    }
    
    var hasOn: Bool {
        return new || translated || modified || needsReview || translateLater || needsWork || sourceEqualTranslation
    }
}

@Observable
class XCStringsModel {

    private(set) var fileURL: URL?
    private(set) var title: String?

    private(set) var xcstrings: XCStrings?
    private(set) var allLocalizeItems: [LocalizeItem] = []
    private(set) var languages: [Language] = []
    private(set) var localizeItems: [LocalizeItem] = []
    var baseLanguage: Language = .english
    var currentLanguage: Language = .english {
        didSet {
            reloadData()
            
            settings.lastLanguage = currentLanguage.code
            if let settingsFileURL {
                settings.save(to: settingsFileURL)
            }
        }
    }
    var editingID: String?
    var sortOrder: [KeyPathComparator<LocalizeItem>] = [
        .init(\.state, order: SortOrder.forward),
        .init(\.key, order: SortOrder.forward)
    ]
    var searchText: String = "" {
        didSet {
            // TODO: debounce
            reloadData()
        }
    }
    var isModified: Bool = false
    var forceClose: Bool = false
    var canClose: Bool { forceClose || isModified == false }

//    private var debouncedSearchText: String = ""
//    private var cancellables = Set<AnyCancellable>()
    var filter: Filter = Filter() {
        didSet {
            reloadData()
        }
    }
    var translateLaterItemsHidden: Bool = false {
        didSet {
            UserDefaults.standard.set(translateLaterItemsHidden, forKey: "TranslateLaterItemsHidden")
            reloadData()
        }
    }
    var staleItemsHidden: Bool = false {
        didSet {
            UserDefaults.standard.set(staleItemsHidden, forKey: "StaleItemsHidden")
            reloadData()
        }
    }
    
    var selected = Set<LocalizeItem.ID>()

    var settings: FileSettings!
    
    var showGoogleAPIKeyAlert: Bool = false

    init() {
        if let apiKey = UserDefaults.standard.string(forKey: "GoogleTranslateAPIKey") {
            GoogleTranslate.shared.configure(apiKey: apiKey)
        }
        
        translateLaterItemsHidden = UserDefaults.standard.bool(forKey: "TranslateLaterItemsHidden")
        staleItemsHidden = UserDefaults.standard.bool(forKey: "StaleItemsHidden")

//        searchText.publisher
//            .debounce(for: 0.2, scheduler: RunLoop.main)
//            .removeDuplicates()
//            .assign(to: \.self.debouncedSearchText, on: self)
//            .store(in: &cancellables)
//        
//        debouncedSearchText.publisher
//            .debounce(for: .seconds(0.2), scheduler: DispatchQueue.main)
////            .filter({ $0.count >= 2 })
//            .removeDuplicates()
//            .sink { [weak self] _ in
//                self?.reloadData()
////                self?.debouncedSearchText = String(value)
//            }
//            .store(in: &cancellables)
    }
    
    func load(file: URL) {
        do {
            let data = try Data(contentsOf: file)
            let xcstrings = try JSONDecoder().decode(XCStrings.self, from: data)
            
            print(xcstrings.version, xcstrings.sourceLanguage)
            print("string count", xcstrings.strings.count)

            // xcstrings.printStrings()

            self.baseLanguage = xcstrings.sourceLanguage
            self.xcstrings = xcstrings
            self.languages = languages(in: xcstrings).sorted(using: KeyPathComparator<Language>(\.localizedName, order: .forward))

            self.fileURL = file
            if let projectName = self.projectName(for: file) {
                self.title = "\(projectName)/\(file.deletingPathExtension().lastPathComponent)"
            } else {
                self.title = file.deletingPathExtension().lastPathComponent
            }
            self.settings = loadSettings()

            print("settings file", settingsFileURL!.standardizedFileURL)
            print("settings translatelater", settings.translateLater.count)
            
            self.allLocalizeItems = xcStringsToLocalizeItems(xcstrings: xcstrings, languages: self.languages)

            // Setting currentLanguage triggers reloadData
            self.currentLanguage = if let lastLanguage = Language(code: settings.lastLanguage), self.languages.contains(lastLanguage) {
                lastLanguage
            } else {
                self.languages.first!
            }
            isModified = false
            
        } catch {
            print("Failed to load", error)
        }
    }
    
    func projectName(for url: URL) -> String? {
        var result: String?
        var projectURL = url.deletingLastPathComponent()
        for _ in 0 ..< 5 {
            if
                let files = try? FileManager.default.contentsOfDirectory(atPath: projectURL.path(percentEncoded: false)),
                let projectFileName = files.first(where: { $0.hasSuffix(".xcodeproj") })
            {
                result = projectFileName
                break
            }
            
            projectURL.deleteLastPathComponent()
            if projectURL.pathComponents.count < 3 {
                break
            }
        }
        
        return result == nil ? nil : String(result!.dropLast(".xcodeproj".count))
    }
    
    func save() {
        guard let fileURL else {
            return
        }
        
        guard let xcstrings = updateXCStrings() else {
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            
            let data = try encoder.encode(xcstrings)
                        
//            let outputURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent("modified.xcstrings", conformingTo: .fileURL)
            let outputURL = fileURL
            
            try data.write(to: outputURL, options: [.atomic])
            isModified = false
            
        } catch {
            print("Save failed", error)
        }
    }
    
    private func updateXCStrings() -> XCStrings? {
        guard var xcstrings = self.xcstrings else {
            return nil
        }
        
        for item in allLocalizeItems {
            guard let index = xcstrings.strings.firstIndex(where: { $0.key == item.key }) else {
                continue
            }

            if let children = item.children {
                // plural or device variations
                for subitem in children {
                    if let deviceType = subitem.deviceType {
                        // device variation
                        var deviceLocalization = xcstrings.strings[index].localizations[item.language] ?? XCString.Localization()
                        var deviceVariation = deviceLocalization.deviceVariation ?? [XCString.DeviceType: XCString.Localization]()

                        if let pluralItems = subitem.children {
                            // device variation (Plural)
                            for pluralItem in pluralItems {
                                guard let translation = pluralItem.translation, let pluralType = pluralItem.pluralType else {
                                    continue
                                }
                                var pluralLocalization = deviceVariation[deviceType] ?? XCString.Localization()
                                var pluralVariation = pluralLocalization.pluralVariation ?? [XCString.PluralType: XCString.Localization]()
                                
                                let stringUnit = XCString.Localization.StringUnit(state: pluralItem.needsReview ? .needsReview : .translated, value: translation)
                                pluralVariation[pluralType] = XCString.Localization(stringUnit: stringUnit)
                                
                                pluralLocalization.pluralVariation = pluralVariation
                                
                                
                                deviceVariation[deviceType] = pluralLocalization
                                deviceLocalization.deviceVariation = deviceVariation
                                xcstrings.strings[index].localizations[item.language] = deviceLocalization
                            }
                                                        
                        } else {
                            guard let translation = subitem.translation else {
                                continue
                            }

                            // device variation (StringUnit)
                            let stringUnit = XCString.Localization.StringUnit(state: subitem.needsReview ? .needsReview : .translated, value: translation)
                            
                            deviceVariation[deviceType] = XCString.Localization(stringUnit: stringUnit)
                            deviceLocalization.deviceVariation = deviceVariation
                            xcstrings.strings[index].localizations[item.language] = deviceLocalization
                        }
                        
                    } else if let pluralType = subitem.pluralType {
                        guard let translation = subitem.translation else {
                            continue
                        }

                        // plural variation
                        var pluralLocalization = xcstrings.strings[index].localizations[item.language] ?? XCString.Localization()
                        var pluralVariation = pluralLocalization.pluralVariation ?? [XCString.PluralType: XCString.Localization]()
                        
                        let stringUnit = XCString.Localization.StringUnit(state: subitem.needsReview ? .needsReview : .translated, value: translation)
                        
                        pluralVariation[pluralType] = XCString.Localization(stringUnit: stringUnit)
                        pluralLocalization.pluralVariation = pluralVariation
                        xcstrings.strings[index].localizations[item.language] = pluralLocalization
                    }
                }
                
            } else {
                // string unit
                if let translation = item.translation {
                    let stringUnit = XCString.Localization.StringUnit(state: item.needsReview ? .needsReview : .translated, value: translation)
                    let l = XCString.Localization(stringUnit: stringUnit)
                    xcstrings.strings[index].localizations[item.language] = l
                } else {
                    xcstrings.strings[index].localizations.removeValue(forKey: item.language)
                }
            }
        }
        
        return xcstrings
    }
    
    private func reloadData() {
        // TODO: filter sub items
        
//        print(#function, currentLanguage)
        
        func itemContains(_ item: LocalizeItem, matching: (LocalizeItem) -> Bool) -> Bool {
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
        
        
        localizeItems = allLocalizeItems.filter {
            if $0.language != currentLanguage {
                return false
            }
            
            if translateLaterItemsHidden == true && $0.translateLater {
                return false
            }
            if staleItemsHidden == true && $0.isStale {
                return false
            }
            
            // filter
            if filter.new == true {
                if itemContains($0, matching: { item in item.translation != nil }) == true {
                    return false
                }
            }
            
            if filter.modified == true {
                if itemContains($0, matching: { item in item.isModified == false }) == true {
                    return false
                }

                if let children = $0.children {
                    if children.allSatisfy({ $0.isModified == false }) {
                        return false
                    }
                } else if $0.isModified == false {
                    return false
                }
            }
            if filter.needsReview == true {
                if $0.needsReview == false {
                    return false
                } else if let children = $0.children {
                    if children.contains(where: { $0.needsReview == false } ) {
                        return false
                    }
                }
            }
            if filter.translated == true {
                if $0.translation == nil {
                    return false
                } else if let children = $0.children {
                    if children.contains(where: { $0.translation == nil } ) {
                        return false
                    }
                }
            }
            if filter.needsWork == true {
                if $0.needsWork == false {
                    return false
                } else if let children = $0.children {
                    if children.contains(where: { $0.needsWork == false } ) {
                        return false
                    }
                }
            }
            if filter.translateLater == true {
                if $0.translateLater == false {
                    return false
                } else if let children = $0.children {
                    if children.contains(where: { $0.translateLater == false } ) {
                        return false
                    }
                }
            }
            if filter.sourceEqualTranslation == true {
                if $0.children == nil && $0.sourceString != $0.translation {
                    return false
                }
            }

            // search text
            if self.searchText.isEmpty == false {
                let text = self.searchText.lowercased()
                var filtered = false
                if $0.translation?.lowercased().contains(text) == true || $0.sourceString.lowercased().contains(text) == true {
                    filtered = true
                } else if let children = $0.children {
                    filtered = children.contains { $0.translation?.lowercased().contains(text) == true }
                }
                if filtered == false {
                    return false
                }
            }
            
            return true
        }
        .sorted(using: sortOrder)
        
        print("reloadData", localizeItems.count)
    }
    
    private func languages(in xcstrings: XCStrings) -> [Language] {
        var result = Set<Language>()
        for xcstring in xcstrings.strings {
            for (language, _) in xcstring.localizations {
                result.insert(language)
            }
        }
        return Array<Language>(result)
    }

    func setEditing(id: LocalizeItem.ID) {
        // TODO: children 안에 있는거도 찾아서...
        if let item = self.item(with: id) {
            editingID = item.id
        }
//        
//        
//        if let editingIndex = localizeItems.firstIndex(where: { $0.isEditing }) {
//            localizeItems[editingIndex].isEditing = false
//        }
//
//        if let index = localizeItems.firstIndex(where: { $0.id == id }) {
//            localizeItems[index].isEditing = true
//            editingID = id
//        }
    }
    
    func sort(using comparator: [KeyPathComparator<LocalizeItem>]) {
        var comparator = comparator
        if comparator.count == 1 {
            if comparator.first!.keyPath == \.state {
                comparator.append(.init(\.key, order: SortOrder.forward))
            }
        }
        localizeItems.sort(using: comparator)
    }
    
    private func xcStringsToLocalizeItems(xcstrings: XCStrings, languages: [Language]) -> [LocalizeItem] {
        var localizeItems = [LocalizeItem]()
        let sourceLanguage = xcstrings.sourceLanguage
        
        for xcstring in xcstrings.strings {
            for language in languages {
                var sourceString: String = xcstring.key!
                if let sourceLocalization = xcstring.localizations[xcstrings.sourceLanguage] {
                    if let stringUnit = sourceLocalization.stringUnit, stringUnit.value.isEmpty == false {
                        sourceString = stringUnit.value
                    }
                }
                let id = "\(xcstring.key!)\(LocalizeItem.ID_DIVIDER)\(language.code)"

                if let localization = xcstring.localizations[language] {
                    if let stringUnit = localization.stringUnit {
                        // normal string
                        let item = buildStringUnitItem(id: id, stringUnit: stringUnit, xcstring: xcstring, sourceString: sourceString, language: language)
                        localizeItems.append(item)
                        
                    } else if let pluralVariation = localization.pluralVariation {
                        // plural variations
                   
                        let item = buildPluralVarationItem(pluralVariation, id: id, sourceString: sourceString, xcstring: xcstring, sourceLanguage: sourceLanguage, language: language)
                        localizeItems.append(item)
                        
                    } else if let deviceVariation = localization.deviceVariation {
                        // device varations
                        let item = LocalizeItem(id: id, key: xcstring.key!, sourceString: "", comment: xcstring.comment, language: language, translation: nil, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: false)
                        item.translateLater = settings.translateLater.contains(id)
                        item.needsWork = settings.needsWork.contains(id)
                        
                        var subItems = [LocalizeItem]()
                        for (key, deviceLocalization) in deviceVariation {
                            
                            let subid = "\(id)/\(key.rawValue)"

                            if let stringUnit = deviceLocalization.stringUnit {
                                
                                var subSourceString = sourceString
                                if let sourceLocalization = xcstring.localizations[sourceLanguage] {
                                    if let sourceDeviceVariataion = sourceLocalization.deviceVariation {
                                        if let sourceStringUnit = sourceDeviceVariataion[key]?.stringUnit, sourceStringUnit.value.isEmpty == false {
                                            subSourceString = sourceStringUnit.value
                                        }
                                    }
                                }
                                let stringUnitSubItem = buildStringUnitItem(id: subid, stringUnit: stringUnit, xcstring: xcstring, sourceString: subSourceString, language: language, parentItem: item, deviceType: key)
                                subItems.append(stringUnitSubItem)
                                
                            } else if let pluralVariation = deviceLocalization.pluralVariation {
                                
                                let pluralSubItem = buildPluralVarationItem(pluralVariation, id: subid, sourceString: sourceString, xcstring: xcstring, sourceLanguage: sourceLanguage, language: language, deviceType: key)
                                subItems.append(pluralSubItem)
                            }
                        }
                        subItems.sort { $0.deviceType!.sortNum < $1.deviceType!.sortNum }
                        item.children = subItems
                        localizeItems.append(item)
                    }

                } else {
                    // not translated
                    let item = LocalizeItem(id: id, key: xcstring.key!, sourceString: sourceString, comment: xcstring.comment, language: language, translation: nil, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: false)
                    item.translateLater = settings.translateLater.contains(id)
                    item.needsWork = settings.needsWork.contains(id)
                    localizeItems.append(item)
                }
            }
        }
        
        return localizeItems
    }
    
    private func buildStringUnitItem(id: String, stringUnit: XCString.Localization.StringUnit, xcstring: XCString, sourceString: String, language: Language, parentItem: LocalizeItem? = nil, deviceType: XCString.DeviceType? = nil) -> LocalizeItem {
        let needsReview = stringUnit.state == .needsReview
        let key = deviceType != nil ? deviceType!.localizedName : xcstring.key!
        
        let item = LocalizeItem(id: id, key: key, sourceString: sourceString, comment: xcstring.comment, language: language, translation: stringUnit.value, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: needsReview)
        item.translateLater = parentItem?.translateLater ?? settings.translateLater.contains(id)
        item.needsWork = parentItem?.needsWork ?? settings.needsWork.contains(id)
        item.deviceType = deviceType
        item.parentID = parentItem?.id
        return item
    }
    
    private func buildPluralVarationItem(_ variation: [XCString.PluralType: XCString.Localization], id: String, sourceString: String, xcstring: XCString, sourceLanguage: Language, language: Language, deviceType: XCString.DeviceType? = nil) -> LocalizeItem {
        let key = deviceType != nil ? deviceType!.localizedName : xcstring.key!
        
        let item = LocalizeItem(id: id, key: key, sourceString: "", comment: xcstring.comment, language: language, translation: nil, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: false)
        item.translateLater = settings.translateLater.contains(id)
        item.needsWork = settings.needsWork.contains(id)
        item.children = buildPluralVariationSubItems(variation, parentID: id, parent: item, sourceString: sourceString, xcstring: xcstring, sourceLanguage: sourceLanguage, language: language)
        item.deviceType = deviceType
        return item
    }
    
    private func buildPluralVariationSubItems(_ variation: [XCString.PluralType: XCString.Localization], parentID: String, parent: LocalizeItem, sourceString: String, xcstring: XCString, sourceLanguage: Language, language: Language) -> [LocalizeItem] {
        var subItems = [LocalizeItem]()
        for (key, pluralLocalization) in variation {
            if let stringUnit = pluralLocalization.stringUnit {
                let subid = "\(parentID)/\(key.rawValue)"
                let needsReview = stringUnit.state == .needsReview
                
                var subSourceString = sourceString
                if let sourceLocalization = xcstring.localizations[sourceLanguage] {
                    if let sourcePluralVariataion = sourceLocalization.pluralVariation {
                        if let sourceStringUnit = sourcePluralVariataion[key]?.stringUnit, sourceStringUnit.value.isEmpty == false {
                            subSourceString = sourceStringUnit.value
                        }
                    }
                }
                
                let subitem = LocalizeItem(id: subid, key: key.localizedName, sourceString: subSourceString, comment: nil, language: language, translation: stringUnit.value, isStale: false, translateLater: false, needsReview: needsReview)
                subitem.pluralType = key
                subitem.parentID = parentID
                subitem.translateLater = parent.translateLater
                subitem.needsWork = parent.needsWork
                subItems.append(subitem)
            }
        }
        subItems.sort { $0.pluralType!.sortNum < $1.pluralType!.sortNum }
        
        return subItems
    }
    
    func item(with id: LocalizeItem.ID, in items: [LocalizeItem]? = nil) -> LocalizeItem? {
        let items = items ?? localizeItems
        let baseID = LocalizeItem.baseID(id)

        if let item = items.first(where: { $0.id == baseID }) {
            if item.id == id {
                return item

            } else if item.children != nil {
                // children
                if let item = self.findSubItem(id: id, in: item) {
                    return item
                }
            }
        }
        return nil
    }

    private func findSubItem(id: String, in item: LocalizeItem) -> LocalizeItem? {
        guard let children = item.children else {
            return nil
        }
        
        for subitem in children {
            if subitem.children != nil {
                if let item = self.findSubItem(id: id, in: subitem) {
                    return item
                }
            } else if subitem.id == id {
                return subitem
            }
        }
        return nil
    }

        
//    private func updateItemValue(for id: LocalizeItem.ID, updateHandler: (LocalizeItem) -> LocalizeItem?) {
//        let components = id.components(separatedBy: ID_DIVIDER)
//        let key = components[0]
//        let subcomponents = components[1].components(separatedBy: "/")
//        let langCode = subcomponents[0]
//        
//        let baseID = "\(key)\(ID_DIVIDER)\(langCode)"
//
//        if let index = localizeItems.firstIndex(where: { $0.id == baseID }) {
//            if baseID == id {
//                // found
//                if let modifiedItem = updateHandler(localizeItems[index]) {
//                    localizeItems[index] = modifiedItem
//                }
//            } else {
//                // children
//                if localizeItems[index].children != nil {
//                    for i in 0 ..< localizeItems[index].children!.count {
//                        localizeItems[index].children![i].update
//                    }
//                }
//            }
//        }
//    }
    
    // MARK: - Editing
    
    func updateTranslation(for id: String, with translation: String, reverseTranslation: String? = nil) {
        guard 
            let item = self.item(with: id),
            item.translation != translation
        else {
            return
        }
        
        if translation.isEmpty && item.key != "" && item.translation == nil {
            return
        }
        
        if translation.isEmpty && item.key != "" {
            item.translation = nil
        } else {
            item.translation = translation
        }
        item.isModified = true
        item.needsReview = false
        isModified = true

        if translation.isEmpty == false {
            if let reverseTranslation {
                item.reverseTranslation = reverseTranslation
            }
            markTranslateLater(for: item, value: false)
        }
    }

    func clearTranslation(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            item.translation = nil
        }
    }
    
    private func translate(text: String, language: Language) async -> (String?, String?) {
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
    
    private func translate(text: String, from sourceLanguage: Language, to targetLanguage: Language) async -> String? {
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

    func translate(ids: Set<LocalizeItem.ID>? = nil) {
        guard GoogleTranslate.shared.isAvailable == true else {
            showGoogleAPIKeyAlert = true
            return
        }
        
        let itemIDs = ids ?? self.selected
        
        Task {
            for itemID in itemIDs {
                guard let item = self.item(with: itemID) else {
                    continue
                }
                
                let (translation, reverseTranslation) = await self.translate(text: item.sourceString, language: item.language)
                if let translation {
                    self.updateTranslation(for: itemID, with: translation, reverseTranslation: reverseTranslation)
                }
            }
        }
    }

    func reverseTranslate(ids: Set<LocalizeItem.ID>? = nil) {
        guard GoogleTranslate.shared.isAvailable == true else {
            showGoogleAPIKeyAlert = true
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
                
                let reverseTranslation = await self.translate(text: translation, from: item.language, to: xcstrings?.sourceLanguage ?? .english)
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

    func markNeedsReview(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            if item.needsReview == false {
                item.needsReview = true
                isModified = true
            }
        }
    }
    
    func reviewed(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            if item.needsReview == true {
                item.needsReview = false
                isModified = true
            }
        }
    }
    
    /// Mark "Translate Later" for the string
    ///
    /// Mark can be done only to root items
    func markTranslateLater(ids: Set<LocalizeItem.ID>? = nil, value: Bool = true) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            markTranslateLater(for: item, value: value)
        }
        if let settingsFileURL {
            settings.save(to: settingsFileURL)
        }
    }
    
    private func markTranslateLater(for item: LocalizeItem, value: Bool = true) {
        guard item.parentID == nil else {
            return
        }
        if item.translation != nil && value == true {
            return
        }

        item.translateLater = value
        // update children
        item.children?.forEach { $0.translateLater = value }

        if value {
            if settings.translateLater.contains(item.id) == false {
                settings.translateLater.append(item.id)
            }
        } else {
            if let index = settings.translateLater.firstIndex(of: item.id) {
                settings.translateLater.remove(at: index)
            }
        }
    }

    /// Mark "Needs Work" for the string
    ///
    /// Mark can be done only to root items
    func markNeedsWork(ids: Set<LocalizeItem.ID>? = nil, value: Bool = true, allLanguages: Bool = false) {
        var updatedIDs = [LocalizeItem.ID]()
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID), item.parentID == nil else {
                continue
            }
            item.needsWork = value
            updatedIDs.append(item.id)
            // update children
            item.children?.forEach { $0.needsWork = value }
            
            if value {
                if settings.needsWork.contains(item.id) == false {
                    settings.needsWork.append(item.id)
                }
            } else {
                if let index = settings.needsWork.firstIndex(of: item.id) {
                    settings.needsWork.remove(at: index)
                }
            }
        }
        
        if allLanguages {
            let languages = self.languages.filter { $0 != currentLanguage }
            var ids = [LocalizeItem.ID]()
            for itemID in updatedIDs {
                let components = itemID.components(separatedBy: LocalizeItem.ID_DIVIDER)
                for language in languages {
                    let newIDSuffix = language.code + components[1].trimmingPrefix(self.currentLanguage.code)
                    let id = components[0] + LocalizeItem.ID_DIVIDER + newIDSuffix
                    ids.append(id)
                }
            }
            
            for itemID in ids {
                guard let item = item(with: itemID, in: allLocalizeItems) else {
                    continue
                }
                item.needsWork = value
                // update children
                item.children?.forEach { $0.needsWork = value }
                
                if value {
                    if settings.needsWork.contains(item.id) == false {
                        settings.needsWork.append(item.id)
                    }
                } else {
                    if let index = settings.needsWork.firstIndex(of: item.id) {
                        settings.needsWork.remove(at: index)
                    }
                }
            }
        }
                
        
        if let settingsFileURL {
            settings.save(to: settingsFileURL)
        }
    }
        
    func clearNeedsWork(allLanguages: Bool = false) {
        let items = allLanguages ? self.allLocalizeItems : self.localizeItems
        
        func unmarkNeedsWork(items: [LocalizeItem]) {
            for item in items {
                if item.needsWork {
                    item.needsWork = false
                    if let index = settings.needsWork.firstIndex(of: item.id) {
                        settings.needsWork.remove(at: index)
                    }
                }
                
                // children
                if let children = item.children {
                    unmarkNeedsWork(items: children)
                }
            }
        }
        
        unmarkNeedsWork(items: items)

        if let settingsFileURL {
            settings.save(to: settingsFileURL)
        }
    }

    
    func copyFromSourceText(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            updateTranslation(for: item.id, with: item.sourceString)
        }
    }
    
    func copySourceText(ids: Set<LocalizeItem.ID>? = nil) {
        var lines = [String]()
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            if item.sourceString.isEmpty == false {
                lines.append(item.sourceString)
            }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }
    
    func copyTranslationText(ids: Set<LocalizeItem.ID>? = nil) {
        var lines = [String]()
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            if let translation = item.translation {
                lines.append(translation)
            }
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    func copySourceAndTranslationText(ids: Set<LocalizeItem.ID>? = nil) {
        var lines = [String]()
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            guard let item = item(with: itemID) else {
                continue
            }
            lines.append("\(item.sourceString) = \(item.translation ?? "")")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    // MARK: -
    var settingsFileURL: URL? {
        guard let fileURL else {
            return nil
        }
        
        var ids = UserDefaults.standard.dictionary(forKey: "FileIDs") ?? [String: Any]()
        var fileID: String
        
        if let id = ids[fileURL.absoluteString] as? String {
            fileID = id
        } else {
            fileID = UUID().uuidString
            ids[fileURL.absoluteString] = fileID
            UserDefaults.standard.set(ids, forKey: "FileIDs")
        }
        
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last!
        let appSettingsDir = appSupportDir.appendingPathComponent("app.xiles.XCStringEditor", conformingTo: .directory)
        let fileSettingsDir = appSettingsDir.appendingPathComponent("FileSettings", conformingTo: .directory)
        if FileManager.default.fileExists(atPath: fileSettingsDir.path()) == false {
            try! FileManager.default.createDirectory(at: fileSettingsDir, withIntermediateDirectories: true)
        }
        
        return fileSettingsDir.appendingPathComponent("\(fileID).json", conformingTo: .json)
    }
    
    func loadSettings() -> FileSettings? {
        guard let settingsFileURL else {
            return nil
        }
        return FileSettings.load(fileURL: settingsFileURL)
    }
}
