//
//  TagInputView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct TagInputView: View {
    @Binding var selectedTags: [String]
    let suggestedTags: [String]
    @State private var tagText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 選択済みタグ
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.system(size: 15, weight: .medium))
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedTags.removeAll { $0 == tag }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.customPink.opacity(0.1))
                            .foregroundColor(.customPink)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }
            }
            
            // タグ入力フィールド
            HStack {
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(.gray)
                    
                    TextField("タグを追加", text: $tagText)
                        .onSubmit {
                            addTag()
                        }
                }
                .padding()
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.customPink)
                }
            }
            
            // 推奨タグ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestedTags.filter { !selectedTags.contains($0) }, id: \.self) { tag in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedTags.append(tag)
                            }
                        }) {
                            Text("#\(tag)")
                                .font(.system(size: 14, weight: .medium))
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.gray)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
        }
    }
    
    private func addTag() {
        let newTag = tagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newTag.isEmpty && !selectedTags.contains(newTag) {
            withAnimation(.spring(response: 0.3)) {
                selectedTags.append(newTag)
            }
            tagText = ""
        }
    }
}
