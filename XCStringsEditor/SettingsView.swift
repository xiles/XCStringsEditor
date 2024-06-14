//
//  SettingsPane.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 1/26/24.
//

import SwiftUI

struct SettingsView: View {
    
    @AppStorage(UserDefaults.Keys.googleTranslateAPIKey) var googleTranslateAPIKey = ""
    @AppStorage(UserDefaults.Keys.deeplAPIKey) var deeplAPIKey = ""
    @AppStorage(UserDefaults.Keys.translationService) var translateService: TranslateService = .google
    
    var body: some View {
        Form {
            Picker("Translate Service", selection: $translateService) {
                ForEach(TranslateService.allCases) { option in
                    Text(String(describing: option))
                        .tag(option)
                }
            }
            TextField("Google Translate API Key", text: $googleTranslateAPIKey)
            TextField("DeepL API Key", text: $deeplAPIKey)
        }
        .padding()
        .frame(width: 500, height: 250)
    }
}

#Preview {
    SettingsView()
}
