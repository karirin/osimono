import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import CoreLocation

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
    @State private var locationAddress: String
    
    // 画像関連
    @State private var selectedImage: UIImage?
    @State private var imageUrl: String
    @State private var isImagePickerPresented = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // 位置情報関連
    @StateObject private var locationManager = LocationManager()
    @State private var isGettingLocation = false
    @State private var locationCoordinate: CLLocationCoordinate2D?
    
    // カラー定義
    let primaryColor = Color(.systemPink)
    let accentColor = Color(.systemPurple)
    let backgroundColor = Color(.white)
    let cardColor = Color(.white)
    
    // アイテムタイプの選択肢
    let itemTypes = ["グッズ", "聖地巡礼", "ライブ記録", "SNS投稿", "その他"]
    
    // カテゴリーリスト
    let categories = ["グッズ", "CD・DVD", "雑誌", "写真集", "アクリルスタンド", "ぬいぐるみ", "Tシャツ", "タオル", "その他"]
    
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
        _locationAddress = State(initialValue: item.locationAddress ?? "")
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // アイテムタイプ選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("投稿タイプ")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 15) {
                                    ForEach(itemTypes, id: \.self) { type in
                                        Button(action: {
                                            generateHapticFeedback()
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
                        .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        
                        // 画像選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("画像")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            Button(action: {
                                generateHapticFeedback()
                                isImagePickerPresented = true
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
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                                )
                                        } else {
                                            imagePlaceholder
                                        }
                                    }
                                } else {
                                    imagePlaceholder
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        
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
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            
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
                                                    generateHapticFeedback()
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
                                .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            }
                            
                            // 価格（グッズの場合のみ表示）
                            if itemType == "グッズ" {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("価格")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    NumberTextField(text: $price, placeholder: "例: 5500")
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                                .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            }
                            
                            // イベント名（ライブ記録の場合のみ表示）
                            if itemType == "ライブ記録" {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("イベント名")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    TextField("例: BTS ライブ『LOVE YOURSELF』", text: $eventName)
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                                .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            }
                            
                            // 場所（聖地巡礼の場合のみ表示）
                            if itemType == "聖地巡礼" {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("場所")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Button(action: {
                                            generateHapticFeedback()
                                            requestCurrentLocation()
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 12))
                                                Text("現在地を設定")
                                                    .font(.system(size: 12))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(primaryColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                        }
                                        .disabled(isGettingLocation)
                                    }
                                    TextField("例: 東京都渋谷区〇〇", text: $locationAddress)
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                                .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            }
                            
                            // 日付
                            VStack(alignment: .leading, spacing: 5) {
                                Text(dateLabel())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .labelsHidden()
                                    .padding()
                                    .background(cardColor)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                                    .environment(\.locale, Locale(identifier: "ja_JP"))
                            }
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            
                            // タグ
                            VStack(alignment: .leading, spacing: 5) {
                                Text("タグ")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                // 現在のタグ表示
                                if !tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(tags.indices, id: \.self) { index in
                                                HStack(spacing: 4) {
                                                    Text("#\(tags[index])")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(accentColor)
                                                    
                                                    Button(action: {
                                                        generateHapticFeedback()
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
                                    .frame(height: 40)
                                    .padding(.vertical, 5)
                                }
                                
                                // 新しいタグ追加
                                HStack {
                                    TextField("新しいタグを追加", text: $newTag)
                                        .padding()
                                        .background(cardColor)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                    
                                    Button(action: addTag) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(accentColor)
                                    }
                                }
                            }
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            
                            // お気に入り度
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("お気に入り度")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                StarRatingView(rating: $favorite, size: 40)
                            }
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                            
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
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        }
                        .padding(.horizontal)
                        
                        // 保存ボタン
                        Button(action: {
                            generateHapticFeedback()
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
                        .disabled(isLoading || title.isEmpty)
                    }
                }
                .dismissKeyboardOnTap()
                
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
            .navigationBarTitle("アイテム編集", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    generateHapticFeedback()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                },
                trailing: Button("保存") {
                    generateHapticFeedback()
                    saveItem()
                }
                .disabled(isLoading || title.isEmpty)
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("通知"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
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
            
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(primaryColor.opacity(0.8))
                Text("タップして画像を選択")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
        }
        .onTapGesture {
            isImagePickerPresented = true
        }
    }
    
    // 新しいタグ用の状態変数
    @State private var newTag: String = ""
    
    // タグ追加
    func addTag() {
        generateHapticFeedback()
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
            withAnimation {
                tags.append(trimmedTag)
                newTag = ""
            }
        }
    }
    
    // タイトルのプレースホルダーをアイテムタイプに応じて変更
    func titlePlaceholder() -> String {
        switch itemType {
        case "グッズ":
            return "例: BTS 公式ペンライト Ver.3"
        case "聖地巡礼":
            return "例: MVロケ地・渋谷〇〇カフェ"
        case "ライブ記録":
            return "例: 東京ドーム公演"
        case "SNS投稿":
            return "例: インスタストーリー投稿"
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
        case "聖地巡礼":
            return "訪問日"
        case "ライブ記録":
            return "イベント日"
        case "SNS投稿":
            return "投稿日"
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
        case "聖地巡礼":
            return "感想・エピソード"
        case "ライブ記録":
            return "思い出・エピソード"
        case "SNS投稿":
            return "メモ"
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
        case "聖地巡礼": return "mappin.and.ellipse"
        case "ライブ記録": return "music.note.list"
        case "SNS投稿": return "bubble.right.fill"
        case "その他": return "ellipsis.circle.fill"
        default: return "square.grid.2x2.fill"
        }
    }
    
    // 小さいデバイスかどうかを確認
    func isSmallDevice() -> Bool {
        return UIScreen.main.bounds.height < 700
    }
    
    // 現在地の取得
    func requestCurrentLocation() {
        isGettingLocation = true
        
        // 現在地の更新を開始
        locationManager.startUpdatingLocation()
        
        // 位置情報の取得を待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 2秒待機
            if let location = self.locationManager.userLocation {
                // 座標を保存
                self.locationCoordinate = location.coordinate
                
                // 逆ジオコーディングで住所を取得
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
                    DispatchQueue.main.async {
                        self.isGettingLocation = false
                        
                        if let error = error {
                            self.alertMessage = "住所の取得に失敗しました: \(error.localizedDescription)"
                            self.showAlert = true
                            return
                        }
                        
                        if let placemark = placemarks?.first {
                            // 日本語住所の形式に整形
                            var address = ""
                            
                            if let administrativeArea = placemark.administrativeArea {
                                address += administrativeArea // 都道府県
                            }
                            
                            if let locality = placemark.locality {
                                address += locality // 市区町村
                            }
                            
                            if let subLocality = placemark.subLocality, !subLocality.isEmpty {
                                address += subLocality // 町名
                            }
                            
                            if let thoroughfare = placemark.thoroughfare, !thoroughfare.isEmpty {
                                address += thoroughfare // 番地
                            }
                            
                            if let subThoroughfare = placemark.subThoroughfare, !subThoroughfare.isEmpty {
                                address += subThoroughfare // 建物など
                            }
                            
                            self.locationAddress = address
                        } else {
                            self.alertMessage = "住所の取得に失敗しました"
                            self.showAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isGettingLocation = false
                    self.alertMessage = "位置情報の取得に失敗しました。設定から位置情報の利用を許可してください。"
                    self.showAlert = true
                }
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
            "updatedAt": Date().timeIntervalSince1970,
            "favorite": favorite
        ]
        
        // アイテムタイプに応じたデータを追加
        switch itemType {
        case "グッズ":
            itemData["category"] = category
            itemData["price"] = Int(price) ?? 0
            itemData["location"] = location
            itemData["purchaseDate"] = date.timeIntervalSince1970
        case "ライブ記録":
            itemData["eventName"] = eventName
            itemData["purchaseDate"] = date.timeIntervalSince1970
            itemData["memories"] = memo
        case "聖地巡礼":
            itemData["locationAddress"] = locationAddress
            itemData["visitDate"] = date.timeIntervalSince1970
            itemData["memories"] = memo
        case "SNS投稿":
            itemData["publishDate"] = date.timeIntervalSince1970
        case "その他":
            itemData["recordDate"] = date.timeIntervalSince1970
            itemData["details"] = memo
        default:
            itemData["date"] = date.timeIntervalSince1970
        }
        
        // タグの追加
        if !tags.isEmpty {
            itemData["tags"] = tags
        }
        
        print("item.oshiId      :\(item)")
        guard let oshiId = item.oshiId else {
            isLoading = false
            alertMessage = "推し情報が取得できませんでした。"
            showAlert = true
            return
        }
        
        // 画像の処理
        let uploadCompletion: () -> Void = {
            // Firestoreに保存
            let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(self.item.id)
            ref.updateChildValues(itemData) { error, _ in
                self.isLoading = false
                
                if let error = error {
                    self.alertMessage = "保存に失敗しました: \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        // 新しい画像がある場合はアップロード
        if let selectedImage = selectedImage {
            let storageRef = Storage.storage().reference().child("oshiItems").child(userId).child("\(item.id)_\(Date().timeIntervalSince1970).jpg")
            
            if let imageData = selectedImage.jpegData(compressionQuality: 0.7) {
                storageRef.putData(imageData, metadata: nil) { _, error in
                    if let error = error {
                        self.isLoading = false
                        self.alertMessage = "画像のアップロードに失敗しました: \(error.localizedDescription)"
                        self.showAlert = true
                        return
                    }
                    
                    // 画像URLの取得
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            self.isLoading = false
                            self.alertMessage = "画像URLの取得に失敗しました: \(error.localizedDescription)"
                            self.showAlert = true
                            return
                        }
                        
                        if let downloadURL = url {
                            // 以前の画像がある場合は削除
                            if !self.imageUrl.isEmpty, let oldImageURL = URL(string: self.imageUrl) {
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
    var oshiId: String?
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
        case locationAddress, visitDate, recordDate, details, oshiId
    }
}

#Preview {
    let dummyItem = OshiItem(
        id: UUID().uuidString,
        title: "ダミータイトル",
        category: "ダミーカテゴリ",
        memo: "ここにメモを入力",
        imageUrl: "",
        price: 1000,
        purchaseDate: Date().timeIntervalSince1970,
        eventName: "ダミーイベント",
        favorite: 3,
        memories: "ダミー思い出",
        tags: ["タグ1", "タグ2"],
        location: "ダミー購入場所",
        itemType: "グッズ",
        locationAddress: "ダミー住所",
        visitDate: nil,
        recordDate: nil,
        details: "ダミー詳細",
        createdAt: Date().timeIntervalSince1970
    )
//    OshiItemEditView(item: dummyItem)
    TopView()
}


