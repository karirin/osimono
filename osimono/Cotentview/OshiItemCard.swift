//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Shimmer

struct OshiItemCard: View {
    let item: OshiItem
    @State private var isPressed = false
    
    // カラーテーマ
    let primaryColor = Color(.systemPink)
    let cardColor = Color.white
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 画像部分
            ZStack(alignment: .topTrailing) {
                if let imageUrl = item.imageUrl,
                   !imageUrl.isEmpty,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipped()
                        } else {
                            placeholderImage
                        }
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .foregroundColor(Color.gray.opacity(0.1))
                        //                .frame(maxWidth: .infinity)
                            .frame(width: 120,height: 120)
                        if let itemType = item.itemType {
                            Image(systemName: iconForItemType(itemType))
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                            //                    placeholderImage
                        }
                    }
                }
                
                // アイテムタイプバッジ
                if let itemType = item.itemType {
                    HStack(spacing: 4) {
                        Image(systemName: iconForItemType(itemType))
                            .font(.system(size: 10))
                        
                        Text(itemType)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(badgeColor(for: itemType))
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    )
                    .foregroundColor(.white)
                    .padding(6)
                }
            }
            
            // 商品情報
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "無題")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                
                HStack {
                    if let date = item.date {
                        Text(formatDate(date))
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // お気に入り表示
                    if let favorite = item.favorite, favorite > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text("\(favorite)")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(primaryColor)
                    }
                }
            }
            .padding(8)
            .background(cardColor)
        }
        .frame(width: 120)
        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
    }
    
    // プレースホルダー画像（既存のコードから改善）
    var placeholderImage: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.gray.opacity(0.1))
                .frame(width: 120, height: 120)
                .shimmering(active: true)
            
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
//    func iconForItemType(_ type: String) -> String {
//        switch type {
//        case "グッズ": return "gift"
//        case "SNS投稿": return "bubble.right"
//        case "ライブ記録": return "music.note"
//        default: return "photo"
//        }
//    }
    
    func iconForItemType(_ type: String) -> String {
        switch type {
        case "すべて":
            return "square.grid.2x2"        // 例：グリッド状のアイコン
        case "グッズ":
            return "gift.fill"
        case "聖地巡礼":
            return "mappin.and.ellipse"     // 例：地図ピンのアイコン
        case "ライブ記録":
            return "music.note"
        case "SNS投稿":
            return "bubble.right.fill"
        case "その他":
            return "questionmark.circle"     // 例：疑問符付き丸のアイコン
        default:
            return "photo"
        }
    }
    
//    "すべて": Color(.systemBlue),
//    "グッズ": Color(.systemPink),
//    "聖地巡礼": Color(.systemGreen),
//    "ライブ記録": Color(.systemOrange),
//    "SNS投稿": Color(.systemPurple),
//    "その他": Color(.systemGray)
    // アイテムタイプによって背景色を変更
    func badgeColor(for type: String) -> Color {
        switch type {
        case "グッズ": return Color(.systemPink)
        case "SNS投稿": return Color(.systemPurple)
        case "ライブ記録": return Color(.systemOrange)
        case "聖地巡礼": return Color(.systemGreen)
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

#Preview {
    TopView()
}
