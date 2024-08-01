//
//  ContentView.swift
//  XCStringEditor
//
//  Created by JungHoon Noh on 1/20/24.
//

import SwiftUI
import SwiftData
import OSLog

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ContentView")

struct ActivityIndicatorModifier: ViewModifier {
    @Binding var isPresented: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                ProgressView()
            }
        }
    }
}

struct ContentView: View {
    enum Field: Hashable {
        case search
        case translation
        case table
    }
    
    @Environment(XCStringsModel.self) private var stringsModel
    @Environment(WindowDelegate.self) private var windowDelegate
    
    @State private var translation: String = ""
    @State private var isEditing: Bool = false
    @State private var nextEditingItem: LocalizeItem?
    @FocusState private var focusedField: Field?
    @State private var showConfirmClose: Bool = false
    
    
//    init() {
//        #if DEBUG
//        logger.debug("init ContentView")
//        #endif
//    }
        
    var body: some View {
        @Bindable var stringsModel = stringsModel
        
        NavigationStack {
            Table(selection: $stringsModel.selected, sortOrder: $stringsModel.sortOrder) {
                // Key
                TableColumn("Key", value: \.key) { item in
                    keyColumnView(item: item)
                }
                

                // Source
                TableColumn("Default Localization (\(stringsModel.baseLanguage.code))") { item in
                    sourceColumnView(item: item)
                }

                // Translation
                TableColumn(stringsModel.currentLanguage.localizedName) { item in
                    ZStack {
                        Text(verbatim: item.translation ?? item.sourceString)
                            .foregroundStyle(item.translation == nil ? .secondary.opacity(0.5) : (item.needsWork ? Color.orange : .primary))
                            .opacity(isEditing && item.id == stringsModel.editingID ? 0.0 : 1.0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentShape(Rectangle())
                            .allowsHitTesting(item.children == nil)
                            .onTapGesture {
                                onTapTranslation(item: item)
                            }
                        
                        if isEditing && stringsModel.editingID == item.id {
                            // Editing TextField
                            TextField("", text: $translation, axis: .vertical)
                                .lineLimit(nil)
                                .focused($focusedField, equals: .translation)
                                .onSubmit {
                                    if let editingID = stringsModel.editingID {
                                        stringsModel.updateTranslation(for: editingID, with: translation)
                                        stringsModel.editingID = nil
                                        isEditing = false
                                    }
                                }
                                .onAppear {
                                    logger.debug("textfield appear")
                                    
                                    self.translation = item.translation ?? ""
                                    focusedField = .translation
                                }
                        }
                    }
                    .id(item.id)
                }
                
                // Reverse Translation
                TableColumn("Reverse Translation") { item in
                    reverseTranslationColumnView(item: item)
                }
                
                // Comment
                TableColumn("Comment") { item in
                    commentColumnView(comment: item.comment ?? "")
                }
                // State
                TableColumn("State", value: \.state) { item in
                    ItemStateView(state: item.state)
                }
                .width(80)
                .alignment(.center)
                
            } rows: {
                OutlineGroup(stringsModel.localizeItems, children: \.children) { item in
                    TableRow(item)
                        .contextMenu { rowContextMenu(for: item) }
                }
            }
            .focused($focusedField, equals: .table)
            .navigationTitle(stringsModel.title ?? "XCStringsEditor")
            .onAppear {
                startMonitorKeyboardEvent()
                
                windowDelegate.allowClose = {
                    if stringsModel.canClose == false {
                        showConfirmClose = true
                        return false
                    }
                    return true
                }
            }
            .onChange(of: stringsModel.sortOrder, { oldValue, newValue in
                stringsModel.sort(using: newValue)
            })
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    if stringsModel.isModified {
                        Circle()
                            .fill(.blue)
                            .frame(width: 6, height: 6)
                    }
                }
                    
                if stringsModel.languages.isEmpty == false {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Spacer()
                        
                        Picker("Language", selection: $stringsModel.currentLanguage) {
                            ForEach(stringsModel.languages) { language in
                                Text(language.localizedName)
                            }
                        }
                        .frame(minWidth: 160)
                        
                        Spacer()
                        
                        Menu {
                            Button {
                                stringsModel.filter.reset()
                            } label: {
                                if stringsModel.filter.hasOn {
                                    Text("All Items")
                                } else {
                                    Label("All Item(s)", systemImage: "checkmark")
                                }
                            }
                            Divider()
                            Group {
                                Toggle("New", isOn: $stringsModel.filter.new)
                                //                            Toggle("Translated", isOn: $stringsModel.filter.translated)
                                Picker(selection: $stringsModel.filter.translated, label: Text("Translation")) {
                                    Text("All").tag(0)
                                    Text("Translated").tag(1)
                                    Text("Untranslated").tag(2)
                                }
                                Picker(selection: $stringsModel.filter.translationQuality, label: Text("Reverse")) {
                                    Text("All").tag(0)
                                    Text("Missing").tag(1)
                                    Text("Different").tag(2)
                                    Text("Similiar").tag(3)
                                    Text("Exact").tag(4)
                                }
                                
                                Toggle("Modified", isOn: $stringsModel.filter.modified)
                                Toggle("Needs Review", isOn: $stringsModel.filter.needsReview)
                                Toggle("Needs Work", isOn: $stringsModel.filter.needsWork)
                                Toggle("Translate Later", isOn: $stringsModel.filter.translateLater)
                                Toggle("Source = Translation", isOn: $stringsModel.filter.sourceEqualTranslation)
                            }
                        } label: {
                            Label("Filter", systemImage: stringsModel.filter.hasOn ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        }
                        .menuIndicator(.hidden)
                    }
                }
                    
            }
            .toolbarRole(.editor)
            .searchable(text: $stringsModel.searchText)
            .onChange(of: focusedField) { oldValue, newValue in
                if oldValue == .translation && newValue != .translation {
                    logger.debug("textfield focusout")

                    var oldSelected: Set<LocalizeItem.ID>?
                    if let editingID = stringsModel.editingID {
                        logger.debug("textfield focusout update")
                        
                        // update editing item
                        stringsModel.updateTranslation(for: editingID, with: translation)
                        stringsModel.editingID = nil
                        isEditing = false
                        
                        oldSelected = stringsModel.selected
                        stringsModel.selected = []
                    }

                    if let nextEditingItem {
                        self.nextEditingItem = nil
                        DispatchQueue.main.async {
                            editItem(nextEditingItem)
                        }
                    } else {
                        if let oldSelected {
                            stringsModel.selected = oldSelected
                        }
                    }
                }
            }
            .alert("Translate", isPresented: $stringsModel.showAPIKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Google Translate API Key must be set in settings to use this function.")
            }            
            .alert("Confirm Close", isPresented: $showConfirmClose) {
                Button("Cancel", role: .cancel) {}
                Button("Discard Changes", role: .destructive) {
                    stringsModel.forceClose = true
                    NSApp.terminate(nil)
                }
            } message: {
                Text("There are unsaved translations. Do you want to discard the changes?")
            }
            
        } // NavigationStack
        .modifier(ActivityIndicatorModifier(isPresented: $stringsModel.isLoading))
    }
    
    private func keyColumnView(item: LocalizeItem) -> some View {
        HStack {
            Circle()
                .fill(.blue)
                .frame(width: 6, height: 6)
                .opacity(item.isModified ? 1.0 : 0.0)
            Text(item.key)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(item.translateLater || item.shouldTranslate == false ? .secondary : (item.needsWork && item.children != nil ? Color.orange : .primary))
        }
    }
    
    private func sourceColumnView(item: LocalizeItem) -> some View {
        Text(verbatim: "\(item.sourceString)")
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(item.translateLater || item.shouldTranslate == false ? .secondary : .primary)
    }
    
    @ViewBuilder
    private func reverseTranslationColumnView(item: LocalizeItem) -> some View {
        if isReverseTranslationMatch(item) {
            let image = Image(systemName: isReverseTranslationExact(item) ? "checkmark.circle.fill" : "checkmark.circle")
            
            (
                Text(image)
                    .foregroundStyle(.green) +
                Text(verbatim: " \(item.reverseTranslation ?? "")")
            )
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(verbatim: item.reverseTranslation ?? "")
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func commentColumnView(comment: String) -> some View {
        Text(comment)
            .foregroundStyle(.secondary)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func rowContextMenu(for item: LocalizeItem) -> some View {
        let itemIDs = contextMenuItemIDs(itemID: item.id)

        Button("Auto Translate") {
            Task {
                await stringsModel.translate(ids: itemIDs)
            }
        }
        Button("Reverse Translate") {
            stringsModel.reverseTranslate(ids: itemIDs)
        }

        Divider()

        Button("Mark for Review") {
            stringsModel.markNeedsReview(ids: itemIDs)
        }
        Button("Mark as Reviewed") {
            stringsModel.reviewed(ids: itemIDs)
        }

        Divider()
        
        if stringsModel.items(with: Array(itemIDs)).allSatisfy({ $0.shouldTranslate == false }) {
            Button("Mark for Translation") {
                stringsModel.setShouldTranslate(true, for: itemIDs)
            }
        } else {
            Button("Mark as \"Don't Translate\"") {
                stringsModel.setShouldTranslate(false, for: itemIDs)
            }
        }

        Divider()
        
        Button("Mark for Translate Later") {
            stringsModel.markTranslateLater(ids: itemIDs, value: true)
        }
        Button("Unmark Translate Later") {
            stringsModel.markTranslateLater(ids: itemIDs, value: false)
        }
        Button("Mark for Needs Work") {
            stringsModel.markNeedsWork(ids: itemIDs, value: true)
        }
        Button("Unmark Needs Work") {
            stringsModel.markNeedsWork(ids: itemIDs, value: false)
        }
    }
    
    private func startMonitorKeyboardEvent() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifierFlags == [] && event.keyCode == 36/* Enter */ {
                if stringsModel.editingID == nil {
                    if let itemID = stringsModel.selected.first, let item = stringsModel.item(with: itemID) {
                        editItem(item)
                    }
                    return nil  // Intercept the event
                }
            } else if modifierFlags == [.command] && event.characters == "f" {
                focusedField = .search
                return nil
            }
            return event  // Let the event continue to be processed
        }
    }
    
    private func save() {
//        #if DEBUG
//        for item in stringsModel.allLocalizeItems {
//            print(item)
//        }
//        #endif

        stringsModel.save()
    }
    
    private func contextMenuItemIDs(itemID: LocalizeItem.ID) -> Set<LocalizeItem.ID> {
        if stringsModel.selected.contains(itemID) {
            return stringsModel.selected
        } else {
            return [itemID]
        }
    }
    
    private func onTapTranslation(item: LocalizeItem) {
        guard item.shouldTranslate == true else {
            return
        }
        
        if focusedField == .translation {
            nextEditingItem = item
            focusedField = nil
        } else {
            editItem(item)
        }
    }
    
    private func editItem(_ item: LocalizeItem) {
        guard item.children == nil else {
            return
        }
        stringsModel.editingID = item.id
        stringsModel.selected = [item.id]
        isEditing = true
    }
    
    private func colorForItemState(_ state: LocalizeItem.State) -> Color {
        switch state {
        case .needsReview:
            return .orange
        case .stale:
            return .secondary
        default:
            return .primary
        }
    }
    
    private func isReverseTranslationExact(_ item: LocalizeItem) -> Bool {
        return item.reverseTranslation == item.sourceString
    }
    
    private func isReverseTranslationMatch(_ item: LocalizeItem) -> Bool {
        return item.reverseTranslation?.uppercased() == item.sourceString.uppercased()
    }
}

#Preview {
    ContentView()
}
