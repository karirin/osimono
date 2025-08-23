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
    
    var onSaveCompleted: ((OshiItem) -> Void)?
    
    // アイテムタイプの選択肢（多言語対応）
    var itemTypes: [String] {
        [L10n.goods, L10n.pilgrimage, L10n.liveRecord, L10n.snsPost, L10n.other]
    }
    
    // カテゴリーリスト（多言語対応）
    var categories: [String] {
        [L10n.goods, L10n.cdDvd, L10n.magazine, L10n.photoBook, L10n.acrylicStand, L10n.plushie, L10n.tShirt, L10n.towel, L10n.other]
    }
    
    init(item: OshiItem) {
        self.item = item
        _title = State(initialValue: item.title ?? "")
        _itemType = State(initialValue: item.itemType ?? L10n.goods)
        _category = State(initialValue: item.category ?? "")
        _eventName = State(initialValue: item.eventName ?? "")
        _price = State(initialValue: item.price != nil ? String(item.price!) : "")
        
        // 日付の初期化を修正 - アイテムタイプに応じて適切な日付を取得
        var initialDate = Date()
        if let itemType = item.itemType {
            switch itemType {
            case L10n.goods, L10n.liveRecord, L10n.snsPost:
                if let timestamp = item.purchaseDate {
                    initialDate = Date(timeIntervalSince1970: timestamp)
                }
            case L10n.pilgrimage:
                if let timestamp = item.visitDate {
                    initialDate = Date(timeIntervalSince1970: timestamp)
                }
            case L10n.other:
                if let timestamp = item.recordDate {
                    initialDate = Date(timeIntervalSince1970: timestamp)
                }
            default:
                if let timestamp = item.createdAt {
                    initialDate = Date(timeIntervalSince1970: timestamp)
                }
            }
        } else {
            if let timestamp = item.createdAt {
                initialDate = Date(timeIntervalSince1970: timestamp)
            }
        }
        
        _date = State(initialValue: initialDate)
        _location = State(initialValue: item.location ?? "")
        _memo = State(initialValue: item.memo ?? "")
        _tags = State(initialValue: item.tags ?? [])
        _favorite = State(initialValue: item.favorite ?? 0)
        _imageUrl = State(initialValue: item.imageUrl ?? "")
        _locationAddress = State(initialValue: item.locationAddress ?? "")
    }
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // アイテムタイプ選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.postType)
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
                        Text(L10n.image)
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        Button(action: {
                            generateHapticFeedback()
                            isImagePickerPresented = true
                        }) {
                            if let image = selectedImage {
                                ZStack{
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
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Button(action: {
                                                generateHapticFeedback()
                                                withAnimation {
                                                    selectedImage = nil
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 22))
                                                    .foregroundColor(.white)
                                                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                                                    .padding(12)
                                            }
                                        }
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            Text(L10n.changeImage)
                                                .font(.system(size: 14))
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color.black.opacity(0.6))
                                                .foregroundColor(.white)
                                                .cornerRadius(16)
                                        }
                                        .padding(12)
                                    }
                                }
                            } else if !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        ZStack{
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
                                            
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Button(action: {
                                                        generateHapticFeedback()
                                                        imageUrl = ""
                                                    }) {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 22))
                                                            .foregroundColor(.white)
                                                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                                                            .padding(12)
                                                    }
                                                }
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Text(L10n.changeImage)
                                                        .font(.system(size: 14))
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.black.opacity(0.6))
                                                        .foregroundColor(.white)
                                                        .cornerRadius(16)
                                                }
                                                .padding(12)
                                            }
                                        }
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
                            Text(L10n.title)
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            TextField(titlePlaceholder(), text: $title)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.separator), lineWidth: 0.5)
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 2)
                        }
                        .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        
                        // カテゴリー（グッズの場合のみ表示）
                        if itemType == L10n.goods {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.category)
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
                        if itemType == L10n.goods {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.price)
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                NumberTextField(text: $price, placeholder: L10n.pricePlaceholder)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        }
                        
                        // イベント名（ライブ記録の場合のみ表示）
                        if itemType == L10n.liveRecord {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(L10n.eventName)
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                
                                TextField(L10n.eventNamePlaceholder, text: $eventName)
                                    .padding()
                                    .background(cardColor)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                            }
                            .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        }
                        
                        // 場所（聖地巡礼の場合のみ表示）
                        if itemType == L10n.pilgrimage {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(L10n.location)
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
                                            Text(L10n.currentLocation)
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
                                TextField(L10n.locationPlaceholder, text: $locationAddress)
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
                                .environment(\.locale, Locale.current)
                        }
                        .padding(.horizontal, isSmallDevice() ? 10 : 0)
                        
                        // タグ
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.tags)
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
                                TextField(L10n.addNewTag, text: $newTag)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
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
                                Text(L10n.favoriteRating)
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
                            
                            ZStack(alignment: .topLeading) {
                                // 背景
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.separator), lineWidth: 0.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 2)
                                
                                // TextEditorを透明背景で配置
                                TextEditor(text: $memo)
                                    .frame(minHeight: 100)
                                    .padding()
                                    .background(Color.clear)
                                    .scrollContentBackground(.hidden) // iOS 16以降で背景を非表示
                                    .onAppear {
                                        // iOS 15以前のTextEditorの背景色設定
                                        UITextView.appearance().backgroundColor = UIColor.clear
                                    }
                                
                                // プレースホルダーテキスト（メモが空の場合）
                                if memo.isEmpty {
                                    Text(L10n.memoPlaceholder)
                                        .foregroundColor(.gray.opacity(0.6))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                            .frame(minHeight: 120)
                        }
                        .padding(.horizontal, isSmallDevice() ? 10 : 0)
                    }
                    .padding(.horizontal)
                    
                    // 保存ボタン
                    Button(action: {
                        generateHapticFeedback()
                        saveItem()
                    }) {
                        Text(L10n.save)
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
                            Text(L10n.saving)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                    )
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .navigationBarBackButtonHidden(true)
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
                saveItem()
            }) {
                Text(L10n.save)
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
            }
        )
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(L10n.notification),
                message: Text(alertMessage),
                dismissButton: .default(Text(L10n.ok))
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
            
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(primaryColor.opacity(0.8))
                Text(L10n.tapToSelectImage)
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
        return L10n.titlePlaceholder(for: itemType)
    }
    
    // 日付ラベルをアイテムタイプに応じて変更
    func dateLabel() -> String {
        return L10n.dateLabel(for: itemType)
    }
    
    // メモラベルをアイテムタイプに応じて変更
    func memoLabel() -> String {
        return L10n.memoLabel(for: itemType)
    }
    
    // アイコンの取得
    func iconForItemType(_ type: String) -> String {
        switch type {
        case L10n.goods: return "gift.fill"
        case L10n.pilgrimage: return "mappin.and.ellipse"
        case L10n.liveRecord: return "music.note.list"
        case L10n.snsPost: return "bubble.right.fill"
        case L10n.other: return "ellipsis.circle.fill"
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
                            self.alertMessage = L10n.addressFetchFailedMessage(error.localizedDescription)
                            self.showAlert = true
                            return
                        }
                        
                        if let placemark = placemarks?.first {
                            // 住所の形式を現在のロケールに合わせて整形
                            var address = ""
                            
                            if isJapanese() {
                                // 日本語住所の形式
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
                            } else {
                                // 英語住所の形式
                                if let subThoroughfare = placemark.subThoroughfare {
                                    address += subThoroughfare + " "
                                }
                                if let thoroughfare = placemark.thoroughfare {
                                    address += thoroughfare + ", "
                                }
                                if let locality = placemark.locality {
                                    address += locality + ", "
                                }
                                if let administrativeArea = placemark.administrativeArea {
                                    address += administrativeArea
                                }
                            }
                            
                            self.locationAddress = address
                        } else {
                            self.alertMessage = L10n.addressFetchError
                            self.showAlert = true
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isGettingLocation = false
                    self.alertMessage = L10n.locationFetchFailed
                    self.showAlert = true
                }
            }
        }
    }
    
    func onSaveCompleted(action: @escaping (OshiItem) -> Void) -> Self {
        var view = self
        view.onSaveCompleted = action
        return view
    }
    
    func saveItem() {
        isLoading = true
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            alertMessage = L10n.unknownError
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
        
        // アイテムタイプに応じたデータを追加（日付フィールドを正しく設定）
        switch itemType {
        case L10n.goods:
            itemData["category"] = category
            itemData["price"] = Int(price) ?? 0
            itemData["location"] = location
            itemData["purchaseDate"] = date.timeIntervalSince1970
        case L10n.liveRecord:
            itemData["eventName"] = eventName
            itemData["purchaseDate"] = date.timeIntervalSince1970
            itemData["memories"] = memo
        case L10n.pilgrimage:
            itemData["locationAddress"] = locationAddress
            itemData["visitDate"] = date.timeIntervalSince1970
            itemData["memories"] = memo
        case L10n.snsPost:
            itemData["purchaseDate"] = date.timeIntervalSince1970
        case L10n.other:
            itemData["recordDate"] = date.timeIntervalSince1970
            itemData["details"] = memo
        default:
            itemData["purchaseDate"] = date.timeIntervalSince1970
        }
        
        // タグの追加
        if !tags.isEmpty {
            itemData["tags"] = tags
        }
        
        guard let oshiId = item.oshiId else {
            isLoading = false
            alertMessage = L10n.unknownError
            showAlert = true
            return
        }
        
        // 画像の処理
        let uploadCompletion: () -> Void = {
            let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(self.item.id)
            ref.updateChildValues(itemData) { error, _ in
                self.isLoading = false
                
                if let error = error {
                    self.alertMessage = L10n.saveError + ": \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    // Create updated item with all the new values
                    var updatedItem = self.item
                    updatedItem.title = self.title
                    updatedItem.itemType = self.itemType
                    updatedItem.memo = self.memo
                    updatedItem.favorite = self.favorite
                    updatedItem.tags = self.tags
                    
                    // Update type-specific fields including dates
                    switch self.itemType {
                    case L10n.goods:
                        updatedItem.category = self.category
                        updatedItem.price = Int(self.price) ?? 0
                        updatedItem.location = self.location
                        updatedItem.purchaseDate = self.date.timeIntervalSince1970
                    case L10n.liveRecord:
                        updatedItem.eventName = self.eventName
                        updatedItem.purchaseDate = self.date.timeIntervalSince1970
                        updatedItem.memories = self.memo
                    case L10n.pilgrimage:
                        updatedItem.locationAddress = self.locationAddress
                        updatedItem.visitDate = self.date.timeIntervalSince1970
                        updatedItem.memories = self.memo
                    case L10n.snsPost:
                        updatedItem.purchaseDate = self.date.timeIntervalSince1970
                    case L10n.other:
                        updatedItem.recordDate = self.date.timeIntervalSince1970
                        updatedItem.details = self.memo
                    default:
                        updatedItem.purchaseDate = self.date.timeIntervalSince1970
                    }
                    
                    // Update imageUrl
                    updatedItem.imageUrl = itemData["imageUrl"] as? String ?? self.imageUrl
                    
                    // Call callback with updated item
                    self.onSaveCompleted?(updatedItem)
                    self.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        // 新しい画像がある場合はアップロード
        if let selectedImage = selectedImage {
            // 画像アップロード処理
            let imageData = selectedImage.jpegData(compressionQuality: 0.8)
            guard let data = imageData else {
                isLoading = false
                alertMessage = L10n.uploadError
                showAlert = true
                return
            }
            
            let fileName = "item_\(UUID().uuidString).jpg"
            let storageRef = Storage.storage().reference().child("oshiItems").child(userId).child(oshiId).child(fileName)
            
            storageRef.putData(data, metadata: nil) { metadata, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.alertMessage = L10n.uploadError + ": \(error.localizedDescription)"
                        self.showAlert = true
                    }
                    return
                }
                
                storageRef.downloadURL { url, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.isLoading = false
                            self.alertMessage = L10n.uploadError + ": \(error.localizedDescription)"
                            self.showAlert = true
                            return
                        }
                        
                        if let downloadURL = url {
                            itemData["imageUrl"] = downloadURL.absoluteString
                        }
                        uploadCompletion()
                    }
                }
            }
        } else {
            // 画像がない場合はそのまま保存
            itemData["imageUrl"] = imageUrl
            uploadCompletion()
        }
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = UIColor.clear
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.text = placeholder
        textView.textColor = UIColor.placeholderText
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if text.isEmpty && uiView.text == placeholder {
            return
        }
        if !text.isEmpty && uiView.textColor == UIColor.placeholderText {
            uiView.text = text
            uiView.textColor = UIColor.label
        } else if uiView.text != text {
            uiView.text = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.textColor == UIColor.placeholderText {
                textView.text = ""
                textView.textColor = UIColor.label
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            if textView.textColor != UIColor.placeholderText {
                parent.text = textView.text
            }
        }
    }
}

struct OshiItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var title: String?
    var category: String?
    var memo: String?
    var imageUrl: String?
    var price: Int?
    var purchaseDate: TimeInterval?
    var eventName: String?
    var favorite: Int?
    var memories: String?
    var tags: [String]?
    var location: String?
    var itemType: String?
    
    // 聖地巡礼用フィールド
    var locationAddress: String?
    var visitDate: TimeInterval?
    
    // その他用フィールド
    var recordDate: TimeInterval?
    var details: String?
    
    // Firebase用のタイムスタンプ
    var createdAt: TimeInterval?
    var oshiId: String?
    
    // 修正されたdateプロパティ - アイテムタイプに応じて適切な日付を返す
    var date: Date? {
        guard let itemType = itemType else {
            // itemTypeが不明な場合はcreatedAtを使用
            if let timestamp = createdAt {
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        }
        
        switch itemType {
        case "グッズ", "ライブ記録", "SNS投稿":
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
        
        // フォールバック: createdAtを使用
        if let timestamp = createdAt {
            return Date(timeIntervalSince1970: timestamp)
        }
        
        return nil
    }
    
    // 各タイプごとの日付取得（既存のコードはそのまま維持）
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
        OshiItemEditView(item: dummyItem)
//    TopView()
}


