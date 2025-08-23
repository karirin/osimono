//
//  LanguageSelectionView.swift
//  osimono
//
//  Created by Apple on 2025/08/21.
//

import SwiftUI

struct LanguageSelectionView: View {
    @State private var selectedLanguage = Locale.current.languageCode ?? "en"
    
    var body: some View {
        List {
            Section(header: Text("Language / 言語")) {
                LanguageRow(code: "en", name: "English", isSelected: selectedLanguage == "en") {
                    changeLanguage(to: "en")
                }
                
                LanguageRow(code: "ja", name: "日本語", isSelected: selectedLanguage == "ja") {
                    changeLanguage(to: "ja")
                }
            }
        }
        .navigationTitle(L10n.settings)
    }
    
    private func changeLanguage(to language: String) {
        selectedLanguage = language
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Note: In a real app, you might want to show a restart prompt
        // or reload the main view hierarchy
    }
}

struct LanguageRow: View {
    let code: String
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}
