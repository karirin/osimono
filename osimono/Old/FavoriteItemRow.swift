////
////  FavoriteItemRow.swift
////  osimono
////
////  Created by Apple on 2025/04/06.
////
//
//import SwiftUI
//
//struct FavoriteItemRow: View {
//    let item: OshiItem
//    
//    // 色の定義
//    let primaryColor = Color(.systemPink) // 明るいピンク
//    let cardColor = Color(.black) // カード背景色
//    
//    var body: some View {
//        HStack(spacing: 15) {
//            // 画像
//            if let imageUrl = item.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
//                AsyncImage(url: url) { phase in
//                    if let image = phase.image {
//                        image
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: 80, height: 80)
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                    } else {
//                        imagePlaceholder
//                    }
//                }
//                .frame(width: 80, height: 80)
//            } else {
//                imagePlaceholder
//            }
//            
//            // 情報
//            VStack(alignment: .leading, spacing: 6) {
//                Text(item.title ?? "無題")
//                    .font(.system(size: 16, weight: .medium))
//                    .foregroundColor(.black)
//                    .lineLimit(1)
//                
//                // タグ
//                if let tags = item.tags, !tags.isEmpty {
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack {
//                            ForEach(tags.prefix(3), id: \.self) { tag in
//                                Text("#\(tag)")
//                                    .font(.system(size: 12))
//                                    .foregroundColor(.gray)
//                            }
//                        }
//                    }
//                    .frame(height: 20)
//                }
//                
//                // 詳細情報
//                HStack {
//                    if let itemType = item.itemType {
//                        Text(itemType)
//                            .font(.system(size: 12))
//                            .padding(.horizontal, 6)
//                            .padding(.vertical, 2)
//                            .background(itemTypeColor(for: itemType).opacity(0.1))
//                            .foregroundColor(itemTypeColor(for: itemType))
//                            .cornerRadius(4)
//                    }
//                    
//                    Spacer()
//                    
//                    // お気に入り
//                    HStack(spacing: 2) {
//                        ForEach(0..<(item.favorite ?? 0), id: \.self) { _ in
//                            Image(systemName: "heart.fill")
//                                .font(.system(size: 12))
//                                .foregroundColor(.red)
//                        }
//                    }
//                }
//            }
//            
//            Spacer()
//            
//            Image(systemName: "chevron.right")
//                .foregroundColor(.gray)
//        }
//        .padding()
//        .background(cardColor)
//        .cornerRadius(16)
//        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
//    }
//    
//    // 画像プレースホルダー
//    var imagePlaceholder: some View {
//        ZStack {
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color.gray.opacity(0.1))
//                .frame(width: 80, height: 80)
//            
//            Image(systemName: "photo")
//                .font(.system(size: 24))
//                .foregroundColor(.gray)
//        }
//    }
//    
//    // アイテムタイプの色
//    func itemTypeColor(for type: String) -> Color {
//        switch type {
//        case "グッズ": return .blue
//        case "SNS投稿": return .green
//        case "ライブ記録": return .purple
//        default: return .gray
//        }
//    }
//}
