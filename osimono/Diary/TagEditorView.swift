//
//  TagEditorView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct TagEditorView: View {
    @Binding var tags: [String]
    @State private var newTag = ""
    @State private var suggestedTags = ["ライブ", "握手会", "CD購入", "グッズ", "SNS更新", "イベント", "サイン会", "リリイベ"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Selected tags
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Text("#\(tag)")
                                    .font(.subheadline)
                                
                                Button(action: {
                                    generateHapticFeedback()
                                    removeTag(tag)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(15)
                        }
                    }
                }
            }
            
            // New tag input
            HStack {
                TextField("新しいタグ", text: $newTag)
                    .onSubmit {
                        addNewTag()
                    }
                
                Button(action: {
                    generateHapticFeedback()
                    addNewTag()
                }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
            
            // Suggested tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(suggestedTags.filter { !tags.contains($0) }, id: \.self) { tag in
                        Button(action: {
                            generateHapticFeedback()
                            tags.append(tag)
                        }) {
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
    
    private func addNewTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            tags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func removeTag(_ tag: String) {
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
        }
    }
}
