//
//  SettingsPane.swift
//  XCStringsEditor
//
//  Created by JungHoon Noh on 1/26/24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("GoogleTranslateAPIKey") var googleTranslateAPIKey = ""
    
    var body: some View {
        Form {
            TextField("Google Translate API Key", text: $googleTranslateAPIKey)
        }
        .padding()
        .frame(width: 500, height: 250)
    }
}

#Preview {
    SettingsView()
}
