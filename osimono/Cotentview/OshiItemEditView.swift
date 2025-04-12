import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import PhotosUI

struct OshiItemEditView: View {
    @Environment(\.presentationMode) var presentationMode
    let item: OshiItem
    
    // 編集用の状態変数
    @State private var title: String
    @State private var itemType: String
    @State private var category: String
    @State private var eventName: String
    @State private var price: String
    @State private var date: Date
    @State private var location: String
    @State private var memo: String
    @State private var tags: [String]
    @State private var favorite: Int
    
    // 画像関連
    @State private var selectedImage: UIImage?
    @State private var imageUrl: String
    @State private var isImagePickerPresented = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // カラー定義
    let primaryColor = Color(.systemPink)
    let accentColor = Color(.purple)
    let backgroundColor = Color(.systemGray6)
    
    // アイテムタイプの選択肢
    let itemTypes = ["グッズ", "SNS投稿", "ライブ記録"]
    
    // 初期化
    init(item: OshiItem) {
        self.item = item
        _title = State(initialValue: item.title ?? "")
        _itemType = State(initialValue: item.itemType ?? "グッズ")
        _category = State(initialValue: item.category ?? "")
        _eventName = State(initialValue: item.eventName ?? "")
        _price = State(initialValue: item.price != nil ? String(item.price!) : "")
        _date = State(initialValue: item.date ?? Date())
        _location = State(initialValue: item.location ?? "")
        _memo = State(initialValue: item.memo ?? "")
        _tags = State(initialValue: item.tags ?? [])
        _favorite = State(initialValue: item.favorite ?? 0)
        _imageUrl = State(initialValue: item.imageUrl ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 画像選択
                    ZStack {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .cornerRadius(12)
                        } else if !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .clipped()
                                        .cornerRadius(12)
                                } else {
                                    imagePlaceholder
                                }
                            }
                        } else {
                            imagePlaceholder
                        }
                        
                        // 画像選択ボタン
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Button(action: {
                                    isImagePickerPresented = true
                                }) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(primaryColor)
                                        .clipShape(Circle())
                                        .shadow(radius: 3)
                                }
                                .padding()
                            }
                        }
                    }
                    .frame(height: 200)
                    
                    // 基本情報
                    GroupBox(label: Text("基本情報").fontWeight(.bold)) {
                        VStack(alignment: .leading, spacing: 15) {
                            // タイトル
                            inputField(title: "タイトル", binding: $title, icon: "tag.fill")
                            
                            // アイテムタイプ
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .foregroundColor(primaryColor)
                                    Text("タイプ")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Picker("アイテムタイプ", selection: $itemType) {
                                    ForEach(itemTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .padding(.vertical, 5)
                            
                            // カテゴリー（グッズの場合）またはイベント名（ライブ記録の場合）
                            if itemType == "グッズ" {
                                inputField(title: "カテゴリー", binding: $category, icon: "folder.fill")
                            } else if itemType == "ライブ記録" {
                                inputField(title: "イベント名", binding: $eventName, icon: "music.note.list")
                            }
                            
                            // 価格（グッズの場合）
                            if itemType == "グッズ" {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "yensign.circle.fill")
                                            .foregroundColor(primaryColor)
                                        Text("価格")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    TextField("価格を入力", text: $price)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .padding(.vertical, 5)
                            }
                            
                            // 日付
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(primaryColor)
                                    Text(itemType == "グッズ" ? "購入日" : (itemType == "ライブ記録" ? "イベント日" : "投稿日"))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "ja_JP"))
                            }
                            .padding(.vertical, 5)
                            
                            // 場所（グッズの場合）
                            if itemType == "グッズ" {
                                inputField(title: "購入場所", binding: $location, icon: "mappin.circle.fill")
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // メモまたは思い出
                    GroupBox(label: Text(itemType == "ライブ記録" ? "思い出・エピソード" : "メモ").fontWeight(.bold)) {
                        VStack(alignment: .leading) {
                            TextEditor(text: $memo)
                                .frame(minHeight: 120)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
//                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // タグ
                    GroupBox(label: Text("タグ").fontWeight(.bold)) {
                        VStack(alignment: .leading, spacing: 10) {
                            // 現在のタグ表示
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags.indices, id: \.self) { index in
                                        HStack(spacing: 4) {
                                            Text("#\(tags[index])")
                                                .font(.system(size: 14))
                                                .foregroundColor(accentColor)
                                            
                                            Button(action: {
                                                tags.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 14))
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(accentColor.opacity(0.1))
                                        .cornerRadius(15)
                                    }
                                }
                            }
                            .frame(height: tags.isEmpty ? 0 : 40)
                            
                            // 新しいタグ追加
                            HStack {
                                TextField("新しいタグを追加", text: $newTag)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                
                                Button(action: addTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(accentColor)
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(.horizontal)
                    
                    // お気に入り度
                    VStack(alignment: .leading, spacing: 12) {
                        HStack{
                            Text("お気に入り度")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        StarRatingView(rating: $favorite, size: 40)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .dismissKeyboardOnTap()
            .background(backgroundColor.ignoresSafeArea())
            .navigationBarTitle("アイテム編集", displayMode: .inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    saveItem()
                }
                .disabled(title.isEmpty)
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("通知"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay(
                Group {
                    if isLoading {
                        ZStack {
                            Color.black.opacity(0.4)
                                .ignoresSafeArea()
                            ProgressView()
                                .scaleEffect(1.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImageTimeLinePicker(selectedImage: $selectedImage)
        }
    }
    
    // 画像プレースホルダー
    var imagePlaceholder: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.gray.opacity(0.1))
                .frame(height: 200)
                .cornerRadius(12)
            
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text("画像をタップして選択")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .onTapGesture {
            isImagePickerPresented = true
        }
    }
    
    // 入力フィールド
    func inputField(title: String, binding: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(primaryColor)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            TextField(title + "を入力", text: binding)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(.vertical, 5)
    }
    
    // 新しいタグ用の状態変数
    @State private var newTag: String = ""
    
    // タグ追加
    func addTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            withAnimation {
                tags.append(trimmedTag)
                newTag = ""
            }
        }
    }
    
    // アイテム保存
    func saveItem() {
        isLoading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            alertMessage = "ユーザー情報が取得できませんでした。"
            showAlert = true
            return
        }
        
        // アイテムデータの準備
        var itemData: [String: Any] = [
            "title": title,
            "itemType": itemType,
            "memo": memo,
            "date": date.timeIntervalSince1970,
            "favorite": favorite,
            "updatedAt": Date().timeIntervalSince1970
        ]
        
        // アイテムタイプに応じたデータを追加
        if itemType == "グッズ" {
            itemData["category"] = category
            itemData["price"] = Int(price) ?? 0
            itemData["location"] = location
        } else if itemType == "ライブ記録" {
            itemData["eventName"] = eventName
        }
        
        // タグの追加
        if !tags.isEmpty {
            itemData["tags"] = tags
        }
        
        // 画像の処理
        let uploadCompletion: () -> Void = {
            // Firestoreに保存
            let ref = Database.database().reference().child("oshiItems").child(userId).child(self.item.id)
            ref.updateChildValues(itemData) { error, _ in
                isLoading = false
                
                if let error = error {
                    alertMessage = "保存に失敗しました: \(error.localizedDescription)"
                    showAlert = true
                } else {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        // 新しい画像がある場合はアップロード
        if let selectedImage = selectedImage {
            let storageRef = Storage.storage().reference().child("oshiItems").child(userId).child("\(item.id)_\(Date().timeIntervalSince1970).jpg")
            
            if let imageData = selectedImage.jpegData(compressionQuality: 0.7) {
                storageRef.putData(imageData, metadata: nil) { _, error in
                    if let error = error {
                        isLoading = false
                        alertMessage = "画像のアップロードに失敗しました: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }
                    
                    // 画像URLの取得
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            isLoading = false
                            alertMessage = "画像URLの取得に失敗しました: \(error.localizedDescription)"
                            showAlert = true
                            return
                        }
                        
                        if let downloadURL = url {
                            // 以前の画像がある場合は削除
                            if !imageUrl.isEmpty, let oldImageURL = URL(string: imageUrl) {
                                let oldStorageRef = Storage.storage().reference(forURL: oldImageURL.absoluteString)
                                oldStorageRef.delete { _ in }
                            }
                            
                            itemData["imageUrl"] = downloadURL.absoluteString
                            uploadCompletion()
                        }
                    }
                }
            } else {
                isLoading = false
                alertMessage = "画像の処理に失敗しました"
                showAlert = true
            }
        } else {
            // 画像がない場合はそのまま保存
            itemData["imageUrl"] = imageUrl
            uploadCompletion()
        }
    }
}

// キーボードを非表示にする拡張
//extension View {
//    func dismissKeyboardOnTap() -> some View {
//        self.onTapGesture {
//            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
//        }
//    }
//}

// OshiItemデータモデル（参照用）は省略

struct OshiItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String?
    var category: String?
    var memo: String?
    var imageUrl: String?
    var price: Int?
    var purchaseDate: TimeInterval?
    var eventName: String?
    var favorite: Int?  // お気に入り度（5段階）
    var memories: String? // 思い出・エピソード
    var tags: [String]?  // タグ（メンバー名など）
    var location: String? // 購入場所
    var itemType: String? // グッズ/SNS投稿/ライブ記録/聖地巡礼/その他
    
    // 聖地巡礼用フィールド
    var locationAddress: String? // 聖地の場所・住所
    var visitDate: TimeInterval? // 訪問日
    
    // その他用フィールド
    var recordDate: TimeInterval? // 記録日
    var details: String? // 詳細メモ
    
    // Firebase用のタイムスタンプ
    var createdAt: TimeInterval?
    
    var date: Date? {
        if let timestamp = createdAt {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }
    
    // 各タイプごとの日付取得
    var typeSpecificDate: Date? {
        switch itemType {
        case "グッズ":
            if let timestamp = purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "ライブ記録":
            if let timestamp = purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "SNS投稿":
            if let timestamp = purchaseDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "聖地巡礼":
            if let timestamp = visitDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        case "その他":
            if let timestamp = recordDate {
                return Date(timeIntervalSince1970: timestamp)
            }
        default:
            break
        }
        return date
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, category, memo, imageUrl, price, purchaseDate, eventName
        case favorite, memories, tags, location, itemType, createdAt
        case locationAddress, visitDate, recordDate, details
    }
}

#Preview {
    TopView()
}


