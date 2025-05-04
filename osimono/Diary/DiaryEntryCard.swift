//
//  DiaryEntryCard.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI

struct DiaryEntryCard: View {
    let entry: DiaryEntry
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー部分
            HStack {
                Text(dateFormatter.string(from: Date(timeIntervalSince1970: entry.createdAt)))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(DiaryMood(rawValue: entry.mood)?.icon ?? "😐")
                    .font(.system(size: 24))
            }
            .padding(16)
            .padding(.bottom, 4)
            
            // タイトル
            Text(entry.title)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
                .padding(.horizontal, 16)
            
            // コンテンツプレビュー
            if !entry.content.isEmpty {
                Text(entry.content)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            // 画像プレビュー
            if let imageUrls = entry.imageUrls, !imageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(imageUrls, id: \.self) { urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    case .failure:
                                        PlaceholderImage()
                                    case .empty:
                                        PlaceholderImage()
                                            .shimmering()
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            
            // タグ
            if let tags = entry.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.customPink)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color.customPink.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            } else {
                Spacer().frame(height: 16)
            }
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - プレースホルダー画像
    
    struct PlaceholderImage: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                )
        }
    }
}
