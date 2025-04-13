//
//  FilterSheetView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth

// View for filtering locations
struct FilterSheetView: View {
    @Binding var selectedCategories: Set<String>
    @Environment(\.presentationMode) var presentationMode
    
    let categories = ["ライブ", "広告", "カフェ", "その他"]
    let categoryColors = [
        "ライブ": Color(hex: "6366F1"),
        "広告": Color(hex: "EC4899"),
        "カフェ": Color(hex: "10B981"),
        "その他": Color(hex: "6366F1")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("カテゴリー")) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: {
                            generateHapticFeedback()
                            if selectedCategories.contains(category) {
                                // Only remove if it wouldn't make the selection empty
                                if selectedCategories.count > 1 {
                                    selectedCategories.remove(category)
                                }
                            } else {
                                selectedCategories.insert(category)
                            }
                        }) {
                            HStack {
                                Circle()
                                    .fill(categoryColors[category, default: .gray])
                                    .frame(width: 12, height: 12)
                                
                                Text(category)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedCategories.contains(category) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(categoryColors[category, default: .blue])
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("フィルター")
            .navigationBarItems(
                leading: Button("リセット") {
                    selectedCategories = Set(categories)
                },
                trailing: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}
