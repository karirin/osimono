import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import CoreLocation

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
    var oshiId: String
    
    // タグ関連状態
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    
    @State private var itemType: String = "グッズ"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var locationAddress: String = "新宿区北新宿2-2-14" // 聖地巡礼の場所住所
    
    @StateObject private var locationManager = LocationManager()
    @State private var isGettingLocation = false
    @State private var locationCoordinate: CLLocationCoordinate2D?
    @ObservedObject private var locationViewModel = LocationViewModel()
    
    // 色の定義
    let primaryColor = Color(.systemPink) // ピンク
    let accentColor = Color(.systemPurple) // 紫
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.white) // カード背景色
    
    // カテゴリーリスト
    let categories = ["グッズ", "CD・DVD", "雑誌", "写真集", "アクリルスタンド", "ぬいぐるみ", "Tシャツ", "タオル", "その他"]
    
    // アイテムタイプ
    let itemTypes = ["グッズ", "聖地巡礼", "ライブ記録", "SNS投稿", "その他"]
    
    var userId: String? {
        Auth.auth().currentUser?.uid
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
                            ScrollView(.horizontal,showsIndicators: false) {
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
                        .padding(.horizontal,isSmallDevice() ? 10 : 0)
                        // 画像選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("画像")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            Button(action: {
                                generateHapticFeedback()
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
                        .padding(.horizontal,isSmallDevice() ? 10 : 0)
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
                            .padding(.horizontal,isSmallDevice() ? 10 : 0)
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
                                .padding(.horizontal,isSmallDevice() ? 10 : 0)
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
                                .padding(.horizontal,isSmallDevice() ? 10 : 0)
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
                                .padding(.horizontal,isSmallDevice() ? 10 : 0)
                            }
                            
                            // 場所（聖地巡礼の場合のみ表示）
                            if itemType == "聖地巡礼" {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack{
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
                                .padding(.horizontal,isSmallDevice() ? 10 : 0)
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
                                    .environment(\.locale, Locale(identifier: "ja_JP"))
                            }
                            .padding(.horizontal,isSmallDevice() ? 10 : 0)
                            // タグ（新しい実装）
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
                            .padding(.horizontal,isSmallDevice() ? 10 : 0)
                            // お気に入り度
                            VStack(alignment: .leading, spacing: 20) {
                                HStack{
                                    Text("お気に入り度")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                StarRatingView(rating: $favorite, size: 40)
                            }
                            .padding(.horizontal,isSmallDevice() ? 10 : 0)
                            
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
                            .padding(.horizontal,isSmallDevice() ? 10 : 0)
                        }
                        .padding(.horizontal)
                        
                        // 送信ボタン
                        Button(action: {
                            generateHapticFeedback()
                            saveItem()
                        }) {
                            Text("投稿する")
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
            .navigationBarTitle("推しの投稿を追加", displayMode: .inline)
            .navigationBarItems(leading:
                Button(action: {
                generateHapticFeedback()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
            )
            .navigationBarItems(trailing:
                Button(action: {
                generateHapticFeedback()
                    saveItem()
                }) {
                    Text("投稿")
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
    
    // タグ追加関数
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
    
    // データ保存
    func saveItem() {
        isLoading = true
        
        // アイテムデータの準備
        var data: [String: Any] = [
            "id": UUID().uuidString,
            "title": title,
            "memo": memo,
            "favorite": favorite,
            "itemType": itemType,
            "oshiId": oshiId,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        if !tags.isEmpty {
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
            
            // 位置情報が取得できている場合、locationViewModelにも保存
            if let locationCoord = locationCoordinate {
                saveToLocationsTable(coordinate: locationCoord)
            } else if !locationAddress.isEmpty {
                // 住所から座標を取得して保存
                geocodeAddressAndSaveLocation()
            }
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
    
    private func geocodeAddressAndSaveLocation() {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(locationAddress) { placemarks, error in
            if let error = error {
                print("住所のジオコーディングに失敗しました: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first,
               let location = placemark.location {
                self.saveToLocationsTable(coordinate: location.coordinate)
            }
        }
    }

    // locationsテーブルに聖地巡礼データを保存する関数
    private func saveToLocationsTable(coordinate: CLLocationCoordinate2D) {
        // OshiItemFormViewで使用するカテゴリーからEnhancedAddLocationViewの対応するカテゴリーに変換
        let locationCategory = "聖地" // EnhancedAddLocationViewのカテゴリーに合わせる
        
        // LocationViewModelのcurrentOshiIdをoshiIdに設定
        locationViewModel.currentOshiId = oshiId
        
        // locationsテーブルに保存
        locationViewModel.addLocation(
            title: title.isEmpty ? "聖地巡礼スポット" : title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: locationCategory,
            initialRating: favorite, // お気に入り度をratingとして使用
            note: memo.isEmpty ? nil : memo,
            image: selectedImage
        ) { _ in
            // locationsテーブルへの保存完了。特に何もしなくてOK
            print("聖地巡礼データをlocationsテーブルにも保存しました")
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
        
        // ここを変更：oshiIdを含めたパスに保存
        let oshiId = data["oshiId"] as? String ?? "default"
        let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(itemId)
        
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

#Preview {
    OshiItemFormView(oshiId: "test")
}
