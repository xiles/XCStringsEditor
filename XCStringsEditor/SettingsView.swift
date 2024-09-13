//
//  SettingsPane.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 1/26/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @AppStorage(UserDefaults.Keys.googleTranslateAPIKey) var googleTranslateAPIKey = ""
    @AppStorage(UserDefaults.Keys.deeplAPIKey) var deeplAPIKey = ""
    @AppStorage(UserDefaults.Keys.translationService) var translateService: TranslateService = .google
    @AppStorage(UserDefaults.Keys.baiduAppID) var baiduAppID = ""
    @AppStorage(UserDefaults.Keys.baiduAPIKey) var baiduAPIKey = ""
    
    var body: some View {
        Form {
            Picker("Translate Service", selection: $translateService) {
                ForEach(TranslateService.allCases) { option in
                    Text(String(describing: option))
                        .tag(option)
                }
            }
            switch translateService {
            case .google:
                TextField("Google Translate API Key", text: $googleTranslateAPIKey)
            case .deepL:
                TextField("DeepL API Key", text: $deeplAPIKey)
            case .baidu:
                TextField("Baidu App ID", text: $baiduAppID)
                TextField("Baidu API Key", text: $baiduAPIKey)
            }
        }
        .padding()
        .frame(width: 500, height: 250)
        .onChange(of: translateService) { oldValue, newValue in
            appModel.translator = TranslatorFactory.translator
        }
    }
}

#Preview {
    SettingsView()
}
