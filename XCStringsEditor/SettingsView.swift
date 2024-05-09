//
//  SettingsPane.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 1/26/24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("GoogleTranslateAPIKey") var googleTranslateAPIKey = ""
    @AppStorage("DeeplAPIKey") var deeplAPIKey = ""
    @AppStorage("TranslateService") var translateService: TranslateService = .google
    
    @State private var translateServiceOption: TranslateService = .google

    var body: some View {
        Form {
            Picker("Translate Service", selection: $translateServiceOption) {
                ForEach(TranslateService.allCases) { option in
                    Text(String(describing: option))
                }
            }
            TextField("Google Translate API Key", text: $googleTranslateAPIKey)
            TextField("DeepL API Key", text: $deeplAPIKey)
        }
        .onAppear {
            translateServiceOption = translateService
        }
        .onChange(of: translateServiceOption, {
            translateService = translateServiceOption
        })
        .padding()
        .frame(width: 500, height: 250)
    }
}

#Preview {
    SettingsView()
}
