//
//  OshiItemFormView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct OshiItemFormView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = ""
    @State private var category: String = "グッズ"
    @State private var memo: String = ""
    @State private var price: String = ""
    @State private var purchaseDate = Date()
    @State private var eventName: String = ""
    @State private var favorite: Int = 3
    @State private var memories: String = ""
    @State private var location: String = ""
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @State private var isLoading = false
    @State private var tagsInput: String = ""
    @State private var itemType: String = "グッズ"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var locationAddress: String = "" // 聖地巡礼の場所住所
    
    // 色の定義
    let primaryColor = Color(.systemPink) // ピンク
    let accentColor = Color(.systemPurple) // 紫
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    
    // カテゴリーリスト
    let categories = ["グッズ", "CD・DVD", "雑誌", "写真集", "アクリルスタンド", "ぬいぐるみ", "Tシャツ", "タオル", "その他"]
    
    // アイテムタイプ
    let itemTypes = ["グッズ", "SNS投稿", "ライブ記録", "聖地巡礼", "その他"]
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // ヘッダータイトル
                        Text("推しアイテムを追加")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(primaryColor)
                            .padding(.top)
                            .padding(.horizontal)
                        
                        // アイテムタイプ選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("アイテムタイプ")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            ScrollView(.horizontal,showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(itemTypes, id: \.self) { type in
                                        Button(action: {
                                            itemType = type
                                        }) {
                                            VStack(spacing: 5) {
                                                Image(systemName: iconForItemType(type))
                                                    .font(.system(size: 24))
                                                Text(type)
                                                    .font(.caption)
                                            }
                                            .foregroundColor(itemType == type ? primaryColor : .gray)
                                            .frame(width: 80, height: 80)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(itemType == type ? primaryColor : Color.gray.opacity(0.3), lineWidth: 2)
                                                    .background(itemType == type ? primaryColor.opacity(0.1) : Color.white)
                                                    .cornerRadius(12)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // 画像選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("画像")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            Button(action: {
                                isShowingImagePicker = true
                            }) {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                } else {
                                    ZStack {
                                        Rectangle()
                                            .foregroundColor(Color.gray.opacity(0.1))
                                            .frame(height: 200)
                                            .cornerRadius(12)
                                        
                                        VStack(spacing: 10) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(primaryColor.opacity(0.8))
                                            Text("タップして画像を選択")
                                                .font(.system(size: 16))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 基本情報フォーム
                        VStack(alignment: .leading, spacing: 15) {
                            // タイトル
                            VStack(alignment: .leading, spacing: 5) {
                                Text("タイトル")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                TextField(titlePlaceholder(), text: $title)
                                    .padding()
                                    .background(cardColor)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                            
                            // カテゴリー（グッズの場合のみ表示）
                            if itemType == "グッズ" {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("カテゴリー")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 10) {
                                            ForEach(categories, id: \.self) { cat in
                                                Button(action: {
                                                    category = cat
                                                }) {
                                                    Text(cat)
                                                        .padding(.horizontal, 15)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 20)
                                                                .fill(category == cat ? accentColor : Color.gray.opacity(0.1))
                                                        )
                                                        .foregroundColor(category == cat ? .white : .gray)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 価格（グッズの場合のみ表示）
                            if itemType == "グッズ" {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("価格")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    TextField("例: 5500", text: $price)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                            }
                            
                            // イベント名（ライブ記録の場合のみ表示）
                            if itemType == "ライブ記録" {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("イベント名")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    TextField("例: BTS WORLD TOUR 'LOVE YOURSELF'", text: $eventName)
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                            }
                            
                            // 場所（聖地巡礼の場合のみ表示）
                            if itemType == "聖地巡礼" {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("場所")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    TextField("例: 東京都渋谷区〇〇", text: $locationAddress)
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                            }
                            
                            // 日付
                            VStack(alignment: .leading, spacing: 5) {
                                Text(dateLabel())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .labelsHidden()
                                    .padding()
                                    .background(cardColor)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                            
                            // タグ
                            VStack(alignment: .leading, spacing: 5) {
                                Text("タグ（カンマ区切りで入力）")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                TextField("例: BTS, RM, ARMY", text: $tagsInput)
                                    .padding()
                                    .background(cardColor)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                            
                            // お気に入り度
                            VStack(alignment: .leading, spacing: 5) {
                                Text("お気に入り度")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                HStack {
                                    ForEach(1...5, id: \.self) { rating in
                                        Button(action: {
                                            favorite = rating
                                        }) {
                                            Image(systemName: rating <= favorite ? "heart.fill" : "heart")
                                                .foregroundColor(rating <= favorite ? .red : .gray)
                                                .font(.system(size: 24))
                                                .padding(.horizontal, 5)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(favorite)/5")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(primaryColor)
                                        .padding(.trailing)
                                }
                                .padding()
                                .background(cardColor)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                            
                            // メモ
                            VStack(alignment: .leading, spacing: 5) {
                                Text(memoLabel())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                TextEditor(text: $memo)
                                    .frame(minHeight: 100)
                                    .padding()
                                    .background(cardColor)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                        }
                        .padding(.horizontal)
                        
                        // 送信ボタン
                        Button(action: {
                            saveItem()
                        }) {
                            Text("保存する")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(primaryColor)
                                )
                                .shadow(color: primaryColor.opacity(0.4), radius: 5, x: 0, y: 3)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                        .disabled(isLoading)
                    }
                }
                
                // ローディングオーバーレイ
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("保存中...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.top, 10)
                            }
                        )
                }
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(leading:
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            )
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImageTimeLinePicker(selectedImage: $selectedImage)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // タイトルのプレースホルダーをアイテムタイプに応じて変更
    func titlePlaceholder() -> String {
        switch itemType {
        case "グッズ":
            return "例: BTS 公式ペンライト Ver.3"
        case "SNS投稿":
            return "例: インスタストーリー投稿"
        case "ライブ記録":
            return "例: 東京ドーム公演"
        case "聖地巡礼":
            return "例: MVロケ地・渋谷〇〇カフェ"
        case "その他":
            return "例: 推しの誕生日、記念日など"
        default:
            return "タイトルを入力"
        }
    }
    
    // 日付ラベルをアイテムタイプに応じて変更
    func dateLabel() -> String {
        switch itemType {
        case "グッズ":
            return "購入日"
        case "SNS投稿":
            return "投稿日"
        case "ライブ記録":
            return "イベント日"
        case "聖地巡礼":
            return "訪問日"
        case "その他":
            return "記録日"
        default:
            return "日付"
        }
    }
    
    // メモラベルをアイテムタイプに応じて変更
    func memoLabel() -> String {
        switch itemType {
        case "グッズ":
            return "メモ"
        case "SNS投稿":
            return "メモ"
        case "ライブ記録":
            return "思い出・エピソード"
        case "聖地巡礼":
            return "感想・エピソード"
        case "その他":
            return "詳細メモ"
        default:
            return "メモ"
        }
    }
    
    // アイコンの取得
    func iconForItemType(_ type: String) -> String {
        switch type {
        case "グッズ": return "gift.fill"
        case "SNS投稿": return "bubble.right.fill"
        case "ライブ記録": return "music.note.list"
        case "聖地巡礼": return "mappin.and.ellipse"
        case "その他": return "ellipsis.circle.fill"
        default: return "square.grid.2x2.fill"
        }
    }
    
    // データ保存
    func saveItem() {
        guard let userId = userId, !title.isEmpty else {
            alertMessage = "タイトルを入力してください"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // アイテムデータの準備
        var data: [String: Any] = [
            "id": UUID().uuidString,
            "title": title,
            "memo": memo,
            "favorite": favorite,
            "itemType": itemType,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // タグを処理
        if !tagsInput.isEmpty {
            let tags = tagsInput.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            data["tags"] = tags
        }
        
        // アイテムタイプ別のデータ追加
        if itemType == "グッズ" {
            data["category"] = category
            if let priceInt = Int(price) {
                data["price"] = priceInt
            }
            data["purchaseDate"] = purchaseDate.timeIntervalSince1970
            data["location"] = location
        } else if itemType == "ライブ記録" {
            data["eventName"] = eventName
            data["purchaseDate"] = purchaseDate.timeIntervalSince1970
            data["memories"] = memo
        } else if itemType == "聖地巡礼" {
            data["locationAddress"] = locationAddress
            data["visitDate"] = purchaseDate.timeIntervalSince1970
            data["memories"] = memo
        } else if itemType == "その他" {
            data["recordDate"] = purchaseDate.timeIntervalSince1970
            data["details"] = memo
        } else {
            data["publishDate"] = purchaseDate.timeIntervalSince1970
        }
        
        // 画像がある場合はアップロード
        if let image = selectedImage {
            uploadImage(image) { imageUrl in
                if let url = imageUrl {
                    data["imageUrl"] = url
                    self.saveDataToFirebase(data)
                } else {
                    self.isLoading = false
                    self.alertMessage = "画像のアップロードに失敗しました"
                    self.showAlert = true
                }
            }
        } else {
            // 画像なしで保存
            saveDataToFirebase(data)
        }
    }
    
    // 画像アップロード
    func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let userId = userId else {
            completion(nil)
            return
        }
        
        let storageRef = Storage.storage().reference()
        let imageId = UUID().uuidString
        let imageRef = storageRef.child("oshiItems/\(userId)/\(imageId).jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("画像アップロードエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            imageRef.downloadURL { url, error in
                if let error = error {
                    print("URL取得エラー: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                completion(url?.absoluteString)
            }
        }
    }
    
    // Firebaseにデータを保存
    func saveDataToFirebase(_ data: [String: Any]) {
        guard let userId = userId, let itemId = data["id"] as? String else {
            isLoading = false
            alertMessage = "保存に失敗しました"
            showAlert = true
            return
        }
        
        let ref = Database.database().reference().child("oshiItems").child(userId).child(itemId)
        
        ref.setValue(data) { error, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.alertMessage = "保存に失敗しました: \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    // 保存成功
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
