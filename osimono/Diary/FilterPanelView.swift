//
//  FilterPanelView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct FilterPanelView: View {
    let availableTags: [String]
    @Binding var activeFilters: [DiaryFilter]
    @Binding var appliedFilters: [DiaryFilter]
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // ヘッダー
            HStack {
                Text("フィルター")
                    .font(.headline)
                
                Spacer()
                
                Button("クリア") {
                    generateHapticFeedback()
                    withAnimation(.spring()) {
                        activeFilters = []
                    }
                }
                .foregroundColor(.customPink)
                .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // 気分フィルター
            VStack(alignment: .leading, spacing: 12) {
                Text("気分")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                
                HStack {
                    ForEach(DiaryMood.allCases, id: \.rawValue) { mood in
                        Button(action: {
                            generateHapticFeedback()
                            toggleFilter(.mood(mood))
                        }) {
                            VStack(spacing: 4) {
                                Text(mood.icon)
                                    .font(.system(size: 24))
                                
//                                if isFilterActive(.mood(mood)) {
//                                    Circle()
//                                        .fill(mood.color)
//                                        .frame(width: 6, height: 6)
//                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isFilterActive(.mood(mood)) ? mood.color.opacity(0.2) : Color.clear)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // タグフィルター
            VStack(alignment: .leading, spacing: 12) {
                Text("タグ")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(availableTags, id: \.self) { tag in
                            Button(action: {
                                generateHapticFeedback()
                                toggleFilter(.tag(tag))
                            }) {
                                Text("#\(tag)")
                                    .font(.subheadline)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(isFilterActive(.tag(tag)) ? Color.customPink.opacity(0.2) : Color.gray.opacity(0.2))
                                    .foregroundColor(isFilterActive(.tag(tag)) ? Color.customPink : Color.gray)
                                    .cornerRadius(15)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // 適用ボタン
            Button(action: {
                generateHapticFeedback()
                withAnimation(.spring()) {
                    appliedFilters = activeFilters
                    onClose()
                }
            }) {
                Text("フィルターを適用")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.customPink)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
    
    private func toggleFilter(_ filter: DiaryFilter) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let index = activeFilters.firstIndex(of: filter) {
                activeFilters.remove(at: index)
            } else {
                activeFilters.append(filter)
            }
        }
    }
    
    private func isFilterActive(_ filter: DiaryFilter) -> Bool {
        return activeFilters.contains(filter)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var activeFilters: [DiaryFilter] = []
        @State private var appliedFilters: [DiaryFilter] = []
        
        var body: some View {
            FilterPanelView(
                availableTags: ["仕事", "プライベート", "運動", "読書", "友人", "家族"],
                activeFilters: $activeFilters,
                appliedFilters: $appliedFilters,
                onClose: {}
            )
        }
    }
    
    return PreviewWrapper()
}
