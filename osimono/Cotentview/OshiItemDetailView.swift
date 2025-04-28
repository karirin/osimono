//
//  Untitled.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import Shimmer

struct OshiItemDetailView: View {
    @State private var item: OshiItem
    @State private var isEditing = false
    @State private var isShareSheetPresented = false
    @State private var showDeleteConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    init(item: OshiItem) {
        self._item = State(initialValue: item)
    }
    // 色の定義
    let primaryColor = Color(.systemPink) // 明るいピンク
    let accentColor = Color(.purple) // 紫系
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    let textColor = Color(.black) // テキスト色
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 画像表示
                ZStack(alignment: .bottomTrailing) {
                    if let imageUrl = item.imageUrl,
                       !imageUrl.isEmpty,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                            } else {
                                placeholderImage
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .foregroundColor(Color.gray.opacity(0.1))
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                            if let itemType = item.itemType {
                                Image(systemName: iconForItemType(itemType))
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                                //                    placeholderImage
                            }
                        }
                    }
                }
                
                // 基本情報
                VStack(alignment: .leading, spacing: 20) {
                    // タイトルとタグ
                    VStack(alignment: .leading, spacing: 10) {
                        // アイテムタイプバッジとお気に入り
                        HStack {
                            // アイテムタイプバッジ
                            if let itemType = item.itemType {
                                Text(itemType)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(badgeColor(for: itemType))
                                    .foregroundColor(.white)
                                    .cornerRadius(15)
                            }
                            
                            Spacer()
                            
                            // お気に入りバッジ
                            if let favorite = item.favorite, favorite > 0 {
                                HStack(spacing: 0) {
                                    ForEach(1...favorite, id: \.self) { index in
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.red)
                                            .padding(4)
                                            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                            .scaleEffect(1.0)
                                            .animation(
                                                Animation.spring(response: 0.3, dampingFraction: 0.6)
                                                    .delay(0.05 * Double(index)),
                                                value: favorite
                                            )
                                    }
                                }
                            }
                        }
                        
                        // タイトル
                        Text(item.title ?? "無題")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        // タグ
                        if let tags = item.tags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 14))
                                            .foregroundColor(accentColor)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 15)
                                                    .fill(accentColor.opacity(0.1))
                                            )
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // 詳細情報
                    VStack(alignment: .leading, spacing: 15) {
                        // カテゴリーまたはイベント名
                        if let category = item.category, !category.isEmpty {
                            detailRow(title: "カテゴリー", value: category, icon: "tag.fill")
                        }
                        
                        if let eventName = item.eventName, !eventName.isEmpty {
                            detailRow(title: "イベント", value: eventName, icon: "music.note.list")
                        }
                        
                        // 価格
                        if let price = item.price, price > 0 {
                            detailRow(title: "価格", value: "¥\(price)", icon: "yensign.circle.fill")
                        }
                        
                        // 日付
                        if let date = item.date {
                            detailRow(
                                title: item.itemType == "グッズ" ? "購入日" : (item.itemType == "ライブ記録" ? "イベント日" : "投稿日"),
                                value: formatDate(date),
                                icon: "calendar"
                            )
                        }
                        
                        // 場所
                        if let location = item.location, !location.isEmpty {
                            detailRow(title: "購入場所", value: location, icon: "mappin.circle.fill")
                        }
                    }
                    
                    Divider()
                    
                    // メモ・思い出
                    if let memo = item.memo, !memo.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.itemType == "ライブ記録" ? "思い出・エピソード" : "メモ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text(memo)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.05))
                                )
                        }
                    }
                    
                    // 管理ボタン
                    HStack(spacing: 20) {
                        Button(action: {
                            generateHapticFeedback()
                            isShareSheetPresented = true
                        }) {
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20))
                                Text("シェア")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(accentColor, lineWidth: 1)
                            )
                        }
                        
                        Button(action: {
                            generateHapticFeedback()
                            isEditing = true
                        }) {
                            VStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 20))
                                Text("編集")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(primaryColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryColor, lineWidth: 1)
                            )
                        }
                        
                        Button(action: {
                            generateHapticFeedback()
                            showDeleteConfirmation = true
                        }) {
                            VStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 20))
                                Text("削除")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal)
                .padding(.vertical, 20)
                .background(cardColor)
                .cornerRadius(20, corners: [.topLeft, .topRight])
                .offset(y: -20)
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(leading:
            Button(action: {
                generateHapticFeedback()
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("戻る")
                }
                .foregroundColor(primaryColor)
            }
        )
        .navigationBarItems(
            trailing: Button(action: {
                generateHapticFeedback()
                isEditing = true
            }) {
                Text("編集")
                .foregroundColor(primaryColor)
                .frame(maxWidth: .infinity)
            }
        )
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("投稿を削除"),
                message: Text("この投稿を削除してもよろしいですか？この操作は元に戻せません。"),
                primaryButton: .destructive(Text("削除")) {
                    deleteItem()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                ShareSheet(items: [url])
            } else {
                ShareSheet(items: [item.title ?? "推しアイテム"])
            }
        }
        .fullScreenCover(isPresented: $isEditing) {
            OshiItemEditView(item: item)
                .onSaveCompleted { updatedItem in
                    self.item = updatedItem
                }
        }
    }
    
    // プレースホルダー画像
    var placeholderImage: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.gray.opacity(0.1))
                .frame(height: 300)
                .shimmering()
            
            if let itemType = item.itemType {
                Image(systemName: iconForItemType(itemType))
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 詳細行
    func detailRow(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(primaryColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
            }
        }
    }
    
    func fetchUpdatedItemData() {
        guard let userId = Auth.auth().currentUser?.uid,
              let oshiId = item.oshiId else { return }
        
        let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(item.id)
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else { return }
            
            // Create a new item with the same ID
            var updatedItem = OshiItem(id: self.item.id)
            updatedItem.oshiId = oshiId
            
            // Parse all the fields from the data
            updatedItem.title = data["title"] as? String
            updatedItem.itemType = data["itemType"] as? String
            updatedItem.memo = data["memo"] as? String
            updatedItem.imageUrl = data["imageUrl"] as? String
            updatedItem.favorite = data["favorite"] as? Int
            updatedItem.tags = data["tags"] as? [String]
            
            // Parse specific fields based on item type
            if let itemType = updatedItem.itemType {
                switch itemType {
                case "グッズ":
                    updatedItem.category = data["category"] as? String
                    updatedItem.price = data["price"] as? Int
                    updatedItem.location = data["location"] as? String
                    updatedItem.purchaseDate = data["purchaseDate"] as? TimeInterval
                case "ライブ記録":
                    updatedItem.eventName = data["eventName"] as? String
                    updatedItem.purchaseDate = data["purchaseDate"] as? TimeInterval
                    updatedItem.memories = data["memories"] as? String
                case "聖地巡礼":
                    updatedItem.locationAddress = data["locationAddress"] as? String
                    updatedItem.visitDate = data["visitDate"] as? TimeInterval
                    updatedItem.memories = data["memories"] as? String
                case "SNS投稿":
                    updatedItem.purchaseDate = data["publishDate"] as? TimeInterval
                case "その他":
                    updatedItem.recordDate = data["recordDate"] as? TimeInterval
                    updatedItem.details = data["details"] as? String
                default:
                    break
                }
            }
            
            // Parse timestamps
            updatedItem.createdAt = data["createdAt"] as? TimeInterval ?? data["updatedAt"] as? TimeInterval
            
            // Update the view's item with the fresh data
            self.item = updatedItem
        }
    }
    
    // アイテムタイプによってアイコンを変更
    func iconForItemType(_ type: String) -> String {
        switch type {
        case "グッズ": return "gift"
        case "SNS投稿": return "bubble.right"
        case "ライブ記録": return "music.note"
        case "聖地巡礼": return "mappin.and.ellipse"
        default: return "photo"
        }
    }
    
    func badgeColor(for type: String) -> Color {
        switch type {
        case "すべて": return Color(.systemBlue)
        case "グッズ": return Color(.systemPink)
        case "聖地巡礼": return Color(.systemGreen)
        case "ライブ記録": return Color(.systemOrange)
        case "SNS投稿": return Color(.systemPurple)
        case "その他": return Color(.systemGray)
        default:
            return Color(.systemGray)
        }
    }
    
    // 日付フォーマット
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: date)
    }
    
    // アイテム削除
    func deleteItem() {
        guard let userId = Auth.auth().currentUser?.uid,
              let oshiId = item.oshiId else {
            print("削除エラー: ユーザーIDまたは推しIDが取得できません")
            return
        }
        
        // Firebaseからアイテムを削除
        let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(item.id)
        ref.removeValue { error, _ in
            if let error = error {
                print("削除エラー: \(error.localizedDescription)")
            } else {
                print("投稿を削除しました")
                
                // 画像も削除
                if let imageUrl = item.imageUrl, !imageUrl.isEmpty {
                    let storageRef = Storage.storage().reference(forURL: imageUrl)
                    storageRef.delete { error in
                        if let error = error {
                            print("画像削除エラー: \(error.localizedDescription)")
                        } else {
                            print("関連画像も削除しました")
                        }
                    }
                }
                
                // 前の画面に戻る
                DispatchQueue.main.async {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    TopView()
}
