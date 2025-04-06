//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI

struct OshiItemCard: View {
    let item: OshiItem
    @State private var heartScale: CGFloat = 1.0
    
    // 色の定義
    let primaryColor = Color("#FF4B8A") // ピンク
    let cardColor = Color("#FFFFFF") // カード背景色
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 画像
            ZStack(alignment: .topTrailing) {
                if let imageUrl = item.imageUrl,
                   !imageUrl.isEmpty,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipped()
                        } else {
                            placeholderImage
                        }
                    }
                } else {
                    placeholderImage
                }
                
                // アイテムタイプバッジ
                if let itemType = item.itemType {
                    Text(itemType)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor(for: itemType))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(6)
                }
                
                // お気に入りバッジ
                if let favorite = item.favorite, favorite >= 4 {
                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .scaleEffect(heartScale)
                            .foregroundColor(.white)
                            .onAppear {
                                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                    heartScale = 1.2
                                }
                            }
                            
                        Text("\(favorite)")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                    .padding(6)
//                    .offset(x: -itemType != nil ? -80 : 0)
                }
            }
            
            // 商品情報
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "無題")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                if let tags = item.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .frame(height: 20)
                }
                
                HStack {
                    if let price = item.price, price > 0 {
                        Text("¥\(price)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if let date = item.date {
                        Text(formatDate(date))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(cardColor)
        }
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
    }
    
    // プレースホルダー画像
    var placeholderImage: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.gray.opacity(0.1))
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            
            if let itemType = item.itemType {
                Image(systemName: iconForItemType(itemType))
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // アイテムタイプによってアイコンを変更
    func iconForItemType(_ type: String) -> String {
        switch type {
        case "グッズ": return "gift"
        case "SNS投稿": return "bubble.right"
        case "ライブ記録": return "music.note"
        default: return "photo"
        }
    }
    
    // アイテムタイプによって背景色を変更
    func badgeColor(for type: String) -> Color {
        switch type {
        case "グッズ": return Color.blue
        case "SNS投稿": return Color.green
        case "ライブ記録": return Color.purple
        default: return Color.gray
        }
    }
    
    // 日付フォーマット
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
}
