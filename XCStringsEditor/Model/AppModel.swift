//
//  XCStrings.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/20/24.
//

import Foundation
import Combine
import AppKit
import OSLog

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppModel")

struct Filter {
    var new: Bool = false
    var translated: Int = 0
    var translationQuality: Int = 0
    var modified: Bool = false
    var needsReview: Bool = false
    var needsWork: Bool = false
    var translateLater: Bool = false
    var sourceEqualTranslation: Bool = false
    
    mutating func reset() {
        new = false
        translated = 0
        translationQuality = 0
        modified = false
        needsReview = false
        needsWork = false
        translateLater = false
        sourceEqualTranslation = false
    }
    
    var hasOn: Bool {
        return new || translated > 0 || translationQuality > 0 || modified || needsReview || translateLater || needsWork || sourceEqualTranslation
    }
}

@Observable
class AppModel {

    private(set) var fileURL: URL?
    private(set) var title: String?

    private(set) var xcstrings: XCStrings?
    private(set) var languages: [Language] = []

    @ObservationIgnored
    private(set) var allLocalizeItems: [LocalizeItem] = []
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

    var openingFileURL: URL?
    
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
    var dontTranslateItemsHidden: Bool = false {
        didSet {
            UserDefaults.standard.set(dontTranslateItemsHidden, forKey: "DontTranslateItemsHidden")
            reloadData()
        }
    }

    var selected = Set<LocalizeItem.ID>()
    
    var settings: FileSettings!
    
    var showAPIKeyAlert: Bool = false
    var isLoading: Bool = false
    var translator = TranslatorFactory.translator
    init() {
        translateLaterItemsHidden = UserDefaults.standard.bool(forKey: "TranslateLaterItemsHidden")
        staleItemsHidden = UserDefaults.standard.bool(forKey: "StaleItemsHidden")
        dontTranslateItemsHidden = UserDefaults.standard.bool(forKey: "DontTranslateItemsHidden")
        
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
            
            
            // Update recent files
            var recents = UserDefaults.standard.array(forKey: "RecentFiles") as? [String] ?? [String]()
            if let index = recents.firstIndex(where: { $0 == file.path(percentEncoded: false) }) {
                recents.remove(at: index)
            }
            recents.append(file.path(percentEncoded: false))
            if recents.count > 15 {
                recents.removeFirst(recents.count - 15)
            }
            UserDefaults.standard.set(recents, forKey: "RecentFiles")

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
        
        updateAllLocalizedItems()
        
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
            
            clearModifiedMark()
            
            reloadData()
            
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

            xcstrings.strings[index].shouldTranslate = item.shouldTranslate
            
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
    
    func updateAllLocalizedItems() {
        var allItems = allLocalizeItems
        for item in localizeItems {
            if let index = allLocalizeItems.firstIndex(where: { $0.id == item.id }) {
                allItems[index] = item
            }
        }
        allLocalizeItems = allItems
    }

    func reloadData() {
        // TODO: filter sub items
        
//        print(#function, currentLanguage)
        
        updateAllLocalizedItems()

        localizeItems = allLocalizeItems.filter {
            if $0.language != currentLanguage {
                return false
            }
            
            if dontTranslateItemsHidden == true && $0.shouldTranslate == false {
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
                if $0.contains(matching: { item in item.translation == nil }) == false {
                    return false
                }
            }

            switch filter.translated {
            case 1:
                if $0.contains(matching: { item in item.translation == nil }) {
                    return false
                }
            case 2:
                if $0.contains(matching: { item in item.translation != nil }) {
                    return false
                }
            default:
                break
            }
            
            switch filter.translationQuality {
            case 1:
                return $0.reverseTranslation == nil
            case 2:
                return $0.reverseTranslation != nil
                && $0.translationStatus == .different
            case 3:
                return $0.reverseTranslation != nil
                && $0.translationStatus == .similar
            case 4:
                return $0.reverseTranslation != nil
                && $0.translationStatus == .exact
            default:
                break
            }

            if filter.modified == true {
                if $0.contains(matching: { item in item.isModified == true }) == false {
                    return false
                }
            }
            
            if filter.needsReview == true {
                if $0.contains(matching: { item in item.needsReview == true }) == false {
                    return false
                }
            }
            
            if filter.needsWork == true {
                if $0.contains(matching: { item in item.needsWork == true }) == false {
                    return false
                }
            }
            
            if filter.translateLater == true {
                if $0.contains(matching: { item in item.translateLater == true }) == false {
                    return false
                }
            }
            
            if filter.sourceEqualTranslation == true {
                if $0.contains(matching: { item in item.sourceString == item.translation }) == false {
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
                        var item = LocalizeItem(id: id, key: xcstring.key!, sourceString: "", comment: xcstring.comment, language: language, translation: nil, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: false, shouldTranslate: xcstring.shouldTranslate)
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
                    var item = LocalizeItem(id: id, key: xcstring.key!, sourceString: sourceString, comment: xcstring.comment, language: language, translation: nil, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: false, shouldTranslate: xcstring.shouldTranslate)
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
        
        var item = LocalizeItem(id: id, key: key, sourceString: sourceString, comment: xcstring.comment, language: language, translation: stringUnit.value, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: needsReview, shouldTranslate: xcstring.shouldTranslate)
        item.translateLater = parentItem?.translateLater ?? settings.translateLater.contains(id)
        item.needsWork = parentItem?.needsWork ?? settings.needsWork.contains(id)
        item.deviceType = deviceType
        item.parentID = parentItem?.id
        return item
    }
    
    private func buildPluralVarationItem(_ variation: [XCString.PluralType: XCString.Localization], id: String, sourceString: String, xcstring: XCString, sourceLanguage: Language, language: Language, deviceType: XCString.DeviceType? = nil) -> LocalizeItem {
        let key = deviceType != nil ? deviceType!.localizedName : xcstring.key!
        
        var item = LocalizeItem(id: id, key: key, sourceString: "", comment: xcstring.comment, language: language, translation: nil, isStale: xcstring.extractionState == .stale, translateLater: false, needsReview: false, shouldTranslate: xcstring.shouldTranslate)
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
                
                var subitem = LocalizeItem(id: subid, key: key.localizedName, sourceString: subSourceString, comment: nil, language: language, translation: stringUnit.value, isStale: false, translateLater: false, needsReview: needsReview, shouldTranslate: xcstring.shouldTranslate)
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

//    func updateItem(with id: String, updateHandler: (inout LocalizeItem) -> Void) -> Bool {
//
//        if let updatedItems = update(items: )
//    }
//
//    private func update(items: [LocalizeItem], by id: String, update: (inout LocalizeItem) -> Void) -> [LocalizeItem]? {
//        var updatedItems = items
//        for (index, item) in items.enumerated() {
//            if item.id == id {
//                // Modify the found item
//                var updatedItem = item
//                update(&updatedItem)
//                updatedItems[index] = updatedItem
//                return updatedItems
//            } else if !item.subitems.isEmpty {
//                // Recursively check and update in subitems
//                if let updatedSubitems = update(items: item.subitems, by: id, update: update) {
//                    var updatedItem = item
//                    updatedItem.subitems = updatedSubitems
//                    updatedItems[index] = updatedItem
//                    return updatedItems
//                }
//            }
//        }
//        return nil
//    }
//
//    func updateItemProperty(by id: String, update: (inout LocalizeItem) -> Void) -> Bool {
//           // Update the main `items` array
//           if let updatedItems = update(items: items, by: id, update: update) {
//               items = updatedItems
//               return true
//           }
//           return false
//       }

    func updateItem(with id: String, updateHandler: (inout LocalizeItem) -> Void) {
        func update(items: inout [LocalizeItem]) {
            for index in items.indices {
                if items[index].id == id {
                    var updatedItem = items[index]
                    updateHandler(&updatedItem)
                    items[index] = updatedItem
                    return
                }
                if items[index].children != nil {
                    update(items: &items[index].children!)
                }
            }
        }
        var items = self.localizeItems
        update(items: &items)
        self.localizeItems = items
        
        var allItems = self.allLocalizeItems
        update(items: &allItems)
        self.allLocalizeItems = allItems
    }

    func updateItem(with id: String, updateHandler: (inout LocalizeItem) async -> Void) async {
        func update(items: inout [LocalizeItem]) async {
            for index in items.indices {
                if items[index].id == id {
                    var updatedItem = items[index]
                    await updateHandler(&updatedItem)
                    items[index] = updatedItem
                    return
                }
                if items[index].children != nil {
                    await update(items: &items[index].children!)
                }
            }
        }
        var items = self.localizeItems
        await update(items: &items)
        
        var allItems = self.allLocalizeItems
        await update(items: &allItems)

        Task { @MainActor in
            self.localizeItems = items
            self.allLocalizeItems = allItems
        }
    }
    
    // Update function for edited items
    func updateItem(_ updatedItem: LocalizeItem) {
        func update(items: inout [LocalizeItem]) {
            for index in items.indices {
                if items[index].id == updatedItem.id {
                    items[index] = updatedItem
                    return
                }
                if items[index].children != nil {
                    update(items: &items[index].children!)
                }
            }
        }
        var items = self.localizeItems
        update(items: &items)
        self.localizeItems = items

        var allItems = self.allLocalizeItems
        update(items: &allItems)
        self.allLocalizeItems = allItems
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
    
    func items(with ids: [LocalizeItem.ID]) -> [LocalizeItem] {
        return ids.compactMap { self.item(with: $0) }
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
        
    // MARK: - Editing
    
    private func updateTranslation(for item: inout LocalizeItem, with translation: String, reverseTranslation: String? = nil) {
        guard item.translation != translation else {
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

        if translation.isEmpty == false {
            if let reverseTranslation {
                item.reverseTranslation = reverseTranslation
            }
            item.translateLater = false
            settings.removeTranslateLaterItemID(item.id)
        }
        isModified = true
    }
    
    func updateTranslation(for id: String, with translation: String, reverseTranslation: String? = nil) {
        updateItem(with: id) { item in
            guard item.translation != translation else {
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
    }

    func clearTranslation(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            updateItem(with: itemID) { item in
                item.translation = nil
                item.reverseTranslation = nil
                item.isModified = false
            }
        }
        reloadData()
    }
    
    /// Translates the specified items asynchronously.
    ///
    /// This function performs translations for each provided item ID or for all selected items if no IDs are passed.
    /// The translation process includes translating the source string to the target language
    /// and performing a reverse translation for verification.
    /// If the translation fails, appropriate error handling is triggered.
    ///
    /// - Parameters:
    ///   - ids: A set of `LocalizeItem.ID` representing the items to be translated. If `nil`, the selected items will be translated.
    ///
    /// - Precondition: The `sourceLanguage` must be available for translation to proceed.
    ///
    /// - Throws: This function does not throw errors but handles them internally (e.g., logs or updates UI).
    func translate(ids: Set<LocalizeItem.ID>? = nil) async {
        guard let sourceLanguage = self.xcstrings?.sourceLanguage else {
            return
        }

        isLoading = true
        let itemIDs = ids ?? self.selected

        // TODO: Allow sending multiple translation requests simultaneously
        for itemID in itemIDs {
            await self.updateItem(with: itemID) { item in
                // Ensure the source language is available
                var translation: String? = nil
                var reverseTranslation: String? = nil
                let language = item.language
                do {
                    // Perform translation from source to target language
                    translation = try await self.translator.translate(.init(text: item.sourceString, source: sourceLanguage.code, target: language.code))
                    if let translation {
                        // Perform reverse translation from target back to source language
                        reverseTranslation = try await self.translator.translate(.init(text: translation, source: language.code, target: sourceLanguage.code))
                        
                        // Update the item's translation and reverse translation
                        self.updateTranslation(for: &item, with: translation, reverseTranslation: reverseTranslation)
                    }
                } catch {
                    // Handle errors during translation
                    if error as? TranslatorError == TranslatorError.invalidAPI {
                        self.showAPIKeyAlert = true // Notify the user to check API key
                    } else {
                        logger.error("Failed to translate. \(error)")
                    }
                }
            }
        }
        isLoading = false
    }
    
    func reverseTranslate(ids: Set<LocalizeItem.ID>? = nil) async {
        isLoading = true
        let itemIDs = ids ?? self.selected

        // TODO: Allow sending multiple translation requests simultaneously
        for itemID in itemIDs {
            await updateItem(with: itemID) { item in
                guard
                    let translation = item.translation, translation.isEmpty == false
                else {
                    return
                }
                do {
                    let reverseTranslation = try await translator.translate(.init(text: translation, source: item.language.code, target: xcstrings?.sourceLanguage.code ?? "en"))
                    item.reverseTranslation = reverseTranslation
                }
                catch {
                    if error as? TranslatorError == TranslatorError.invalidAPI {
                        showAPIKeyAlert = true
                    } else {
                        logger.error("Failed to reverse translation. \(error)")
                    }
                }
            }
        }
        isLoading = false
    }

    func markNeedsReview(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            updateItem(with: itemID) { item in
                if item.needsReview == false {
                    item.needsReview = true
                    isModified = true
                }
            }
        }
    }

    func setShouldTranslate(_ shouldTranslate: Bool, for ids: Set<LocalizeItem.ID>? = nil) {
        var updatedIDs = [LocalizeItem.ID]()
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            updateItem(with: itemID) { item in
                guard item.parentID == nil else {
                    return
                }
                item.shouldTranslate = shouldTranslate
                updatedIDs.append(item.id)
                
                // update children
                // TODO: recursive? optimize
                var children = item.children
                if children != nil {
                    for i in 0 ..< children!.count {
                        children![i].shouldTranslate = shouldTranslate
                    }
                    item.children = children
                }
            }
        }

        // TODO: check subitems
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
    }

    func reviewed(ids: Set<LocalizeItem.ID>? = nil) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            updateItem(with: itemID) { item in
                if item.needsReview == true {
                    item.needsReview = false
                    isModified = true
                }
            }
        }
    }
    
    /// Mark "Translate Later" for the string
    ///
    /// Mark can be done only to root items
    func markTranslateLater(ids: Set<LocalizeItem.ID>? = nil, value: Bool = true) {
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            updateItem(with: itemID) { item in
                markTranslateLater(for: item, value: value)
            }
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

        var updatedItem = item
        
        updatedItem.translateLater = value

        // update children
        var children = updatedItem.children
        if children != nil {
            for i in 0 ..< children!.count {
                children![i].translateLater = value
            }
            updatedItem.children = children
        }
        
        updateItem(updatedItem)

        // update settings (translateLater items)
        if value {
            settings.appendTranslateLaterItemID(item.id)
        } else {
            settings.removeTranslateLaterItemID(item.id)
        }
    }
    

    /// Mark "Needs Work" for the string
    ///
    /// Mark can be done only to root items
    func markNeedsWork(ids: Set<LocalizeItem.ID>? = nil, value: Bool = true, allLanguages: Bool = false) {
        var updatedIDs = [LocalizeItem.ID]()
        let itemIDs = ids ?? self.selected
        
        for itemID in itemIDs {
            updateItem(with: itemID) { item in
                guard item.parentID == nil else {
                    return
                }

                item.needsWork = value
                updatedIDs.append(item.id)

                var children = item.children
                if children != nil {
                    for i in 0 ..< children!.count {
                        children![i].needsWork = value
                    }
                    item.children = children
                }

            }
            
            if value {
                settings.appendNeedsWorkItemID(itemID)
            } else {
                settings.removeNeedsWorkItemID(itemID)
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
                updateItem(with: itemID) { item in
                    guard item.parentID == nil else {
                        return
                    }

                    item.needsWork = value
                    updatedIDs.append(item.id)

                    var children = item.children
                    if children != nil {
                        for i in 0 ..< children!.count {
                            children![i].needsWork = value
                        }
                        item.children = children
                    }

                }
                
                if value {
                    settings.appendNeedsWorkItemID(itemID)
                } else {
                    settings.removeNeedsWorkItemID(itemID)
                }
            }
        }
                
        
        if let settingsFileURL {
            settings.save(to: settingsFileURL)
        }
    }
        
    func clearNeedsWork(allLanguages: Bool = false) {
        var items = allLanguages ? self.allLocalizeItems : self.localizeItems
        
        func unmarkNeedsWork(items: inout [LocalizeItem]) {
            for index in items.indices {
                if items[index].needsWork {
                    items[index].needsWork = false
                    if items[index].children != nil {
                        unmarkNeedsWork(items: &items[index].children!)
                    }
                    if let index = settings.needsWork.firstIndex(of: items[index].id) {
                        settings.needsWork.remove(at: index)
                    }
                }
            }
        }
        unmarkNeedsWork(items: &items)

        if allLanguages {
            self.allLocalizeItems = items
            reloadData()
        } else {
            self.localizeItems = items
        }

        // save settings (updated needsWork items)
        if let settingsFileURL {
            settings.save(to: settingsFileURL)
        }
    }

    func clearModifiedMark() {
        var items = self.allLocalizeItems
        
        func removeModifiedMark(items: inout [LocalizeItem]) {
            for index in items.indices {
                items[index].isModified = false
                if items[index].children != nil {
                    removeModifiedMark(items: &items[index].children!)
                }
            }
        }
        
        removeModifiedMark(items: &items)
        
        self.allLocalizeItems = items
        
        reloadData()
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
    func detectLanguage(text: String) async -> String? {
        do {
            let languages = try await translator.detect(text: text)
            return languages.first?.language
        } catch {
            return nil
        }
    }
    //MARK: NOTHING HAPPENED
    func detectLanguage(){
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
    
}
