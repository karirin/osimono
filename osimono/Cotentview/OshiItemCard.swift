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
    
    // アイテムタイプのマッピング（OshiCollectionViewと同じ構造）
    var itemTypeMappings: [ItemTypeMapping] {
        [
            ItemTypeMapping(key: "すべて", displayName: L10n.all, icon: "square.grid.2x2", color: Color(.systemBlue)),
            ItemTypeMapping(key: "グッズ", displayName: L10n.goods, icon: "gift.fill", color: Color(.systemPink)),
            ItemTypeMapping(key: "聖地巡礼", displayName: L10n.pilgrimage, icon: "mappin.and.ellipse", color: Color(.systemGreen)),
            ItemTypeMapping(key: "ライブ記録", displayName: L10n.liveRecord, icon: "music.note", color: Color(.systemOrange)),
            ItemTypeMapping(key: "SNS投稿", displayName: L10n.snsPost, icon: "bubble.right.fill", color: Color(.systemPurple)),
            ItemTypeMapping(key: "その他", displayName: L10n.other, icon: "questionmark.circle", color: Color(.systemGray))
        ]
    }
    
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
                            .frame(width: 120,height: 120)
                        if let itemType = item.itemType {
                            Image(systemName: iconForItemType(itemType))
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                // アイテムタイプバッジ（多言語対応）
                if let itemType = item.itemType {
                    HStack(spacing: 4) {
                        Image(systemName: iconForItemType(itemType))
                            .font(.system(size: 10))
                        
                        // データベース値を表示用テキストに変換
                        Text(displayNameForItemType(itemType))
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
                Text(item.title ?? L10n.untitled)
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
    
    // データベース値（日本語）からアイコンを取得
    func iconForItemType(_ type: String) -> String {
        return itemTypeMappings.first(where: { $0.key == type })?.icon ?? "photo"
    }
    
    // データベース値（日本語）から表示用テキストを取得
    func displayNameForItemType(_ type: String) -> String {
        return itemTypeMappings.first(where: { $0.key == type })?.displayName ?? type
    }
    
    // データベース値（日本語）からバッジ色を取得
    func badgeColor(for type: String) -> Color {
        return itemTypeMappings.first(where: { $0.key == type })?.color ?? Color.gray
    }
    
    // 日付フォーマット
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = isJapanese() ? "yyyy/MM/dd" : "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    TopView()
}
