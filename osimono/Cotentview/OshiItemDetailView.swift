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
    @State private var navigateToEdit = false
    
    init(item: OshiItem) {
        self._item = State(initialValue: item)
    }
    // 色の定義
    let primaryColor = Color(.systemPink) // 明るいピンク
    let accentColor = Color(.purple) // 紫系
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    let textColor = Color(.black) // テキスト色
    
    // アイテムタイプのマッピング（他のViewと統一）
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
    
    // カテゴリーのマッピング
    var categoryMappings: [ItemTypeMapping] {
        [
            ItemTypeMapping(key: "すべて", displayName: L10n.all, icon: "", color: Color(.systemBlue)),
            ItemTypeMapping(key: "グッズ", displayName: L10n.goods, icon: "", color: Color(.systemPink)),
            ItemTypeMapping(key: "CD・DVD", displayName: L10n.cdDvd, icon: "", color: Color(.systemBlue)),
            ItemTypeMapping(key: "雑誌", displayName: L10n.magazine, icon: "", color: Color(.systemGreen)),
            ItemTypeMapping(key: "写真集", displayName: L10n.photoBook, icon: "", color: Color(.systemOrange)),
            ItemTypeMapping(key: "アクリルスタンド", displayName: L10n.acrylicStand, icon: "", color: Color(.systemPurple)),
            ItemTypeMapping(key: "ぬいぐるみ", displayName: L10n.plushie, icon: "", color: Color(.systemRed)),
            ItemTypeMapping(key: "Tシャツ", displayName: L10n.tShirt, icon: "", color: Color(.systemTeal)),
            ItemTypeMapping(key: "タオル", displayName: L10n.towel, icon: "", color: Color(.systemYellow)),
            ItemTypeMapping(key: "その他", displayName: L10n.other, icon: "", color: Color(.systemGray))
        ]
    }
    
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
                            // アイテムタイプバッジ（多言語対応）
                            if let itemType = item.itemType {
                                Text(displayNameForItemType(itemType))
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
                        Text(item.title ?? L10n.untitled)
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
                        if let category = item.category, !category.isEmpty {
                            detailRow(title: L10n.category, value: displayNameForCategory(category), icon: "tag.fill")
                        }
                        
                        if let eventName = item.eventName, !eventName.isEmpty {
                            detailRow(title: L10n.eventName, value: eventName, icon: "music.note.list")
                        }
                        
                        if let price = item.price, price > 0 {
                            detailRow(title: L10n.price, value: formatPrice(price), icon: "yensign.circle.fill")
                        }
                        
                        if let date = getItemDate() {
                            detailRow(
                                title: getDateLabel(),
                                value: formatDate(date),
                                icon: "calendar"
                            )
                        }
                        
                        if let location = item.location, !location.isEmpty {
                            detailRow(title: L10n.purchaseLocation, value: location, icon: "mappin.circle.fill")
                        }
                        
                        if let locationAddress = item.locationAddress, !locationAddress.isEmpty {
                            detailRow(title: L10n.location, value: locationAddress, icon: "mappin.circle.fill")
                        }
                    }
                    
                    Divider()
                    
                    // メモ・思い出
                    if let memo = item.memo, !memo.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.memoLabel(for: item.itemType ?? ""))
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
                                Text(L10n.share)
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
                                Text(L10n.edit)
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
                                Text(L10n.delete)
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
            NavigationLink(
                destination: OshiItemEditView(item: item)
                    .onSaveCompleted { updatedItem in
                        self.item = updatedItem
                    },
                isActive: $isEditing
            ) {
                EmptyView()
            }
            .hidden()
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
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
                    Text(L10n.back)
                }
                .foregroundColor(primaryColor)
            }
        )
        .navigationBarItems(
            trailing: Button(action: {
                generateHapticFeedback()
                isEditing = true
            }) {
                Text(L10n.edit)
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
            }
        )
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text(L10n.deleteConfirmationTitle),
                message: Text(L10n.deleteConfirmationMessage),
                primaryButton: .destructive(Text(L10n.delete)) {
                    deleteItem()
                },
                secondaryButton: .cancel(Text(L10n.cancel))
            )
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                ShareSheet(items: [url])
            } else {
                ShareSheet(items: [item.title ?? L10n.oshiItem])
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
    
    func getItemDate() -> Date? {
        guard let itemType = item.itemType else {
            return item.date
        }
        
        switch itemType {
        case "グッズ", "ライブ記録", "SNS投稿":
            if let timestamp = item.purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "聖地巡礼":
            if let timestamp = item.visitDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "その他":
            if let timestamp = item.recordDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        default:
            break
        }
        
        return item.date
    }

    // 日付ラベル取得メソッドを追加
    func getDateLabel() -> String {
        guard let itemType = item.itemType else {
            return NSLocalizedString("date", comment: "Date")
        }
        return L10n.dateLabel(for: itemType)
    }
    
    // データベース値からアイテムタイプの表示名を取得
    func displayNameForItemType(_ type: String) -> String {
        return itemTypeMappings.first(where: { $0.key == type })?.displayName ?? type
    }
    
    // データベース値からカテゴリーの表示名を取得
    func displayNameForCategory(_ category: String) -> String {
        return categoryMappings.first(where: { $0.key == category })?.displayName ?? category
    }
    
    // 価格のフォーマット（通貨記号を言語に合わせて調整）
    func formatPrice(_ price: Int) -> String {
        if isJapanese() {
            return "¥\(price)"
        } else {
            return "$\(price)" // 英語圏向けの表示（必要に応じて調整）
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
    
    // アイテムタイプによってアイコンを変更（マッピングを使用）
    func iconForItemType(_ type: String) -> String {
        return itemTypeMappings.first(where: { $0.key == type })?.icon ?? "photo"
    }
    
    func badgeColor(for type: String) -> Color {
        return itemTypeMappings.first(where: { $0.key == type })?.color ?? Color(.systemGray)
    }
    
    // 日付フォーマット（多言語対応）
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        if isJapanese() {
            formatter.dateFormat = "yyyy年MM月dd日"
        } else {
            formatter.dateStyle = .medium
        }
        
        return formatter.string(from: date)
    }
    
    // アイテム削除
    func deleteItem() {
        guard let userId = Auth.auth().currentUser?.uid,
              let oshiId = item.oshiId else {
            print("\(L10n.deleteError): ユーザーIDまたは推しIDが取得できません")
            return
        }
        
        let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(item.id)
        ref.removeValue { error, _ in
            if let error = error {
                print("\(L10n.deleteError): \(error.localizedDescription)")
            } else {
                print(L10n.deletedSuccessfully)
                
                if let imageUrl = item.imageUrl, !imageUrl.isEmpty {
                    let storageRef = Storage.storage().reference(forURL: imageUrl)
                    storageRef.delete { error in
                        if let error = error {
                            print("\(L10n.deleteError): \(error.localizedDescription)")
                        } else {
                            print("関連画像も削除しました")
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    // 触覚フィードバック
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    TopView()
}
