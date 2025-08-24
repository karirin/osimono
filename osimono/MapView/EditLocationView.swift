//
//  EditLocationView.swift
//  osimono
//
//  Created by Apple on 2025/05/26.
//

import SwiftUI
import MapKit
import SwiftyCrop

struct EditLocationView: View {
    @ObservedObject var viewModel: LocationViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let locationId: String
    @State private var location: EventLocation?
    @State private var isLoading = true
    
    // 編集可能な項目
    @State private var title: String = ""
    @State private var selectedCategory: String = ""
    @State private var userRating: Int = 0
    @State private var note: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var isShowingImagePicker: Bool = false
    @State private var isSaving: Bool = false
    
    // 住所関連の追加項目
    @State private var prefecture: String = ""
    @State private var streetAddress: String = ""
    @State private var buildingName: String = ""
    @State private var isEditingAddress: Bool = false
    @State private var isGeocodingAddress: Bool = false
    @State private var newLatitude: Double = 0.0
    @State private var newLongitude: Double = 0.0
    @State private var showAddressUpdateAlert: Bool = false
    @State private var pendingCoordinate: (latitude: Double, longitude: Double)?
    
    // Localized categories
    private var categories: [String] {
        return [
            NSLocalizedString("pilgrimage", comment: "Pilgrimage"),
            NSLocalizedString("photo_spot", comment: "Photo Spot"),
            NSLocalizedString("cafe_restaurant", comment: "Cafe・Restaurant"),
            NSLocalizedString("live_venue", comment: "Live Venue"),
            NSLocalizedString("goods_shop", comment: "Goods Shop"),
            NSLocalizedString("other", comment: "Other")
        ]
    }
    
    // Prefecture placeholder text
    private var prefecturePlaceholder: String {
        NSLocalizedString("prefecture_placeholder", comment: "Prefecture")
    }
    
    // 現在の住所を組み立て
    var currentAddress: String {
        var address = ""
        if prefecture != prefecturePlaceholder && !prefecture.isEmpty {
            address += prefecture + " "
        }
        if !streetAddress.isEmpty { address += streetAddress + " " }
        if !buildingName.isEmpty { address += buildingName }
        return address.trimmingCharacters(in: .whitespaces)
    }
    
    var onLocationUpdated: (String) -> Void
    
    let existingLocation: EventLocation?
    
    init(viewModel: LocationViewModel, existingLocation: EventLocation, onLocationUpdated: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.locationId = existingLocation.id ?? ""
        self.existingLocation = existingLocation
        self.onLocationUpdated = onLocationUpdated
    }
    
    init(viewModel: LocationViewModel, locationId: String, onLocationUpdated: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.locationId = locationId
        self.existingLocation = nil
        self.onLocationUpdated = onLocationUpdated
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Custom Header
                ZStack {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "6366F1"), Color(hex: "A855F7")]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .edgesIgnoringSafeArea(.all)
                    
                    HStack {
                        Button(action: {
                            generateHapticFeedback()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(NSLocalizedString("close", comment: "Close"))
                        
                        Spacer()
                        
                        Text(NSLocalizedString("edit_spot", comment: "Edit Spot"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            generateHapticFeedback()
                            saveChanges()
                        }) {
                            Text(NSLocalizedString("save", comment: "Save"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(16)
                        }
                        .disabled(title.isEmpty || isSaving)
                    }
                    .padding(.horizontal)
                }
                .padding(.top,isSmallDevice() ? 20 : 40)
                .edgesIgnoringSafeArea(.all)
                .frame(height: 50)
                
                // Main Content
                ZStack {
                    if isLoading {
                        VStack {
                            ProgressView(NSLocalizedString("loading", comment: "Loading..."))
                                .scaleEffect(1.2)
                            Text(NSLocalizedString("loading_spot_info", comment: "Loading spot information"))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                    } else if let location = location {
                        ScrollView {
                            VStack(spacing: 20) {
                                // 画像セクション
                                Button(action: {
                                    generateHapticFeedback()
                                    isShowingImagePicker = true
                                }) {
                                    ZStack {
                                        if let image = selectedImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 200)
                                                .frame(maxWidth: .infinity)
                                                .clipped()
                                                .cornerRadius(16)
                                        } else if let imageURL = location.imageURL, let url = URL(string: imageURL) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(height: 200)
                                                    .frame(maxWidth: .infinity)
                                                    .clipped()
                                                    .cornerRadius(16)
                                            } placeholder: {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(height: 200)
                                                    .cornerRadius(16)
                                                    .overlay(
                                                        ProgressView()
                                                    )
                                            }
                                        } else {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.1))
                                                .frame(height: 200)
                                                .cornerRadius(16)
                                                .overlay(
                                                    VStack {
                                                        Image(systemName: "photo")
                                                            .font(.system(size: 40))
                                                            .foregroundColor(.gray)
                                                        Text(NSLocalizedString("tap_to_change_image", comment: "Tap to change image"))
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    }
                                                )
                                        }
                                        
                                        // 変更ボタンオーバーレイ
                                        VStack {
                                            HStack {
                                                Spacer()
                                                Button(action: {
                                                    generateHapticFeedback()
                                                    selectedImage = nil
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 22))
                                                        .foregroundColor(.white)
                                                        .shadow(radius: 2)
                                                        .padding(12)
                                                }
                                                .accessibilityLabel(NSLocalizedString("delete", comment: "Delete"))
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .accessibilityLabel(NSLocalizedString("change_image", comment: "Change Image"))
                                .padding(.horizontal)
                                
                                // タイトル編集
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(NSLocalizedString("title", comment: "Title"))
                                            .font(.system(size: 16, weight: .medium))
                                        
                                        Spacer()
                                        
                                        Text("\(title.count) / 48")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    TextField(NSLocalizedString("spot_name_placeholder", comment: "Enter spot name"), text: $title)
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                                
                                // 住所編集セクション
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(NSLocalizedString("location", comment: "Location"))
                                            .font(.system(size: 16, weight: .medium))
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            generateHapticFeedback()
                                            geocodeAddress()
                                        }) {
                                            HStack {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 12))
                                                
                                                Text(NSLocalizedString("get_current_location", comment: "Get Current Location"))
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color(hex: "6366F1"))
                                        }
                                    }
                                    
                                    VStack(spacing: 12) {
                                        // 都道府県選択
                                        Menu {
                                            Picker("", selection: $prefecture) {
                                                ForEach([prefecturePlaceholder] + prefectures, id: \.self) { pref in
                                                    Text(pref).tag(pref)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(prefecture.isEmpty ? prefecturePlaceholder : prefecture)
                                                    .foregroundColor((prefecture.isEmpty || prefecture == prefecturePlaceholder) ? .gray : .black)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                        }
                                        .accessibilityLabel(NSLocalizedString("prefecture_selection", comment: "Prefecture Selection"))
                                        
                                        // 市区町村・番地
                                        TextField(NSLocalizedString("street_address_placeholder", comment: "City, district, street number"), text: $streetAddress)
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                        
                                        // ビル名・階数
                                        TextField(NSLocalizedString("building_name_placeholder", comment: "Building name, floor (optional)"), text: $buildingName)
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // カテゴリー選択
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("category", comment: "Category"))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    
                                    ScrollView(.horizontal, showsIndicators: false){
                                        HStack {
                                            ForEach(categories, id: \.self) { category in
                                                Button(action: {
                                                    generateHapticFeedback()
                                                    selectedCategory = category
                                                }) {
                                                    HStack {
                                                        Circle()
                                                            .fill(categoryColor(category))
                                                            .frame(width: 12, height: 12)
                                                        
                                                        Text(category)
                                                            .font(.system(size: 14))
                                                    }
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 12)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .fill(selectedCategory == category ?
                                                                  categoryColor(category).opacity(0.15) :
                                                                    Color.gray.opacity(0.1))
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(selectedCategory == category ?
                                                                    categoryColor(category) :
                                                                        Color.clear,
                                                                    lineWidth: 1)
                                                    )
                                                }
                                                .foregroundColor(selectedCategory == category ?
                                                                 categoryColor(category) : .gray)
                                                .accessibilityLabel(category)
                                            }
                                        }
                                        .padding(3)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .padding(.horizontal)
                                
                                // 評価編集
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack{
                                        Text(NSLocalizedString("favorite_rating", comment: "Favorite Rating"))
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    StarRatingView(rating: $userRating, size: 40)
                                }
                                .padding(.horizontal)
                                
                                Button(action: {
                                    generateHapticFeedback()
                                    saveChanges()
                                }) {
                                    Text(NSLocalizedString("save_changes", comment: "Save Changes"))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 15)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.systemPurple))
                                        )
                                        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                                .padding(.bottom, 30)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 80)
                        }
                    } else {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text(NSLocalizedString("failed_to_load_spot_info", comment: "Failed to load spot information"))
                                .font(.headline)
                                .padding(.top, 8)
                            Button(NSLocalizedString("retry", comment: "Retry")) {
                                loadLocationData()
                            }
                            .padding(.top, 16)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    if isSaving {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .overlay(
                                VStack {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .tint(.white)
                                    Text(NSLocalizedString("updating", comment: "Updating..."))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.top, 10)
                                }
                            )
                            .transition(.opacity)
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
                .navigationTitle(NSLocalizedString("edit_oshi_spot", comment: "Edit Oshi Spot"))
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        presentationMode.wrappedValue.dismiss()
                    },
                    trailing: Button(NSLocalizedString("save", comment: "Save")) {
                        saveChanges()
                    }
                        .disabled(title.isEmpty || isSaving)
                )
            }
            .onAppear {
                loadLocationData()
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePickerView { pickedImage in
                    self.selectedImage = pickedImage
                }
            }
            .alert(isPresented: $showAddressUpdateAlert) {
                Alert(
                    title: Text(NSLocalizedString("update_location_info", comment: "Update Location Information")),
                    message: Text(NSLocalizedString("location_info_update_message", comment: "New location information obtained from address. Update location information?")),
                    primaryButton: .default(Text(NSLocalizedString("update", comment: "Update"))) {
                        if let coordinate = pendingCoordinate {
                            newLatitude = coordinate.latitude
                            newLongitude = coordinate.longitude
                        }
                        pendingCoordinate = nil
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel"))) {
                        pendingCoordinate = nil
                    }
                )
            }
        }
    }
    
    // 評価の説明テキスト
    var ratingDescriptionText: String {
        switch userRating {
        case 0: return NSLocalizedString("tap_to_rate", comment: "Tap to rate")
        case 1: return NSLocalizedString("rating_poor", comment: "Poor")
        case 2: return NSLocalizedString("rating_fair", comment: "Fair")
        case 3: return NSLocalizedString("rating_good", comment: "Good")
        case 4: return NSLocalizedString("rating_very_good", comment: "Very Good")
        case 5: return NSLocalizedString("rating_excellent", comment: "Excellent oshi spot!")
        default: return ""
        }
    }
    
    // カテゴリーの色を取得
    func categoryColor(_ category: String) -> Color {
        let liveVenue = NSLocalizedString("live_venue", comment: "Live Venue")
        let pilgrimage = NSLocalizedString("pilgrimage", comment: "Pilgrimage")
        let cafeRestaurant = NSLocalizedString("cafe_restaurant", comment: "Cafe・Restaurant")
        let goodsShop = NSLocalizedString("goods_shop", comment: "Goods Shop")
        let photoSpot = NSLocalizedString("photo_spot", comment: "Photo Spot")
        let other = NSLocalizedString("other", comment: "Other")
        
        switch category {
        case liveVenue: return Color(hex: "6366F1")
        case pilgrimage: return Color(hex: "EF4444")
        case cafeRestaurant: return Color(hex: "10B981")
        case goodsShop: return Color(hex: "F59E0B")
        case photoSpot: return Color(hex: "EC4899")
        case other: return Color(hex: "6B7280")
        default: return Color(hex: "6366F1")
        }
    }
    
    // 住所から位置情報を取得
    func geocodeAddress() {
        guard !currentAddress.isEmpty else { return }
        
        isGeocodingAddress = true
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(currentAddress) { [self] placemarks, error in
            DispatchQueue.main.async {
                self.isGeocodingAddress = false
                
                if let error = error {
                    print("Geocoding error: \(error)")
                    return
                }
                
                if let placemark = placemarks?.first,
                   let location = placemark.location {
                    self.pendingCoordinate = (
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude
                    )
                    self.showAddressUpdateAlert = true
                }
            }
        }
    }
    
    // 現在の位置情報から住所を取得（逆ジオコーディング）
    func reverseGeocodeLocation(_ latitude: Double, _ longitude: Double) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    // 都道府県
                    if let administrativeArea = placemark.administrativeArea {
                        self.prefecture = administrativeArea
                    }
                    
                    // 市区町村・番地
                    let addressComponents = [
                        placemark.locality,
                        placemark.thoroughfare,
                        placemark.subThoroughfare
                    ].compactMap { $0 }
                    
                    if !addressComponents.isEmpty {
                        self.streetAddress = addressComponents.joined(separator: " ")
                    }
                    
                    // ビル名（詳細情報があれば）
                    if let subLocality = placemark.subLocality {
                        self.buildingName = subLocality
                    }
                }
            }
        }
    }
    
    // ロケーションデータを読み込み
    func loadLocationData() {
        isLoading = true
        
        // 既存のlocationオブジェクトがある場合はそれを使用
        if let existingLocation = existingLocation {
            print("✅ Using existing location object")
            self.location = existingLocation
            // 既存の値で初期化
            self.title = existingLocation.title
            self.selectedCategory = localizeCategory(existingLocation.category)
            self.userRating = existingLocation.ratingSum
            self.note = existingLocation.note ?? ""
            
            // 位置情報を初期化
            self.newLatitude = existingLocation.latitude
            self.newLongitude = existingLocation.longitude
            
            // 住所を取得（逆ジオコーディング）
            reverseGeocodeLocation(existingLocation.latitude, existingLocation.longitude)
            
            // 既存の画像がある場合は読み込み
            if let imageURL = existingLocation.imageURL, let url = URL(string: imageURL) {
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.selectedImage = image
                        }
                    }
                }.resume()
            }
            
            self.isLoading = false
            return
        }
        
        // 既存のgetLocationDetailsを使用するロジック（デバッグ用に残す）
        viewModel.getLocationDetails(id: locationId) { locationData in
            DispatchQueue.main.async {
                if let locationData = locationData {
                    self.location = locationData
                    self.title = locationData.title
                    self.selectedCategory = self.localizeCategory(locationData.category)
                    self.userRating = locationData.ratingSum
                    self.note = locationData.note ?? ""
                    
                    // 位置情報を初期化
                    self.newLatitude = locationData.latitude
                    self.newLongitude = locationData.longitude
                    
                    // 住所を取得（逆ジオコーディング）
                    self.reverseGeocodeLocation(locationData.latitude, locationData.longitude)
                    
                    if let imageURL = locationData.imageURL, let url = URL(string: imageURL) {
                        URLSession.shared.dataTask(with: url) { data, response, error in
                            if let data = data, let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    self.selectedImage = image
                                }
                            }
                        }.resume()
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    // Convert stored category to localized version
    func localizeCategory(_ storedCategory: String) -> String {
        // Handle both old Japanese categories and already localized categories
        switch storedCategory {
        case "ライブ会場", "Live Venue":
            return NSLocalizedString("live_venue", comment: "Live Venue")
        case "聖地巡礼", "Pilgrimage":
            return NSLocalizedString("pilgrimage", comment: "Pilgrimage")
        case "カフェ・飲食店", "Cafe・Restaurant":
            return NSLocalizedString("cafe_restaurant", comment: "Cafe・Restaurant")
        case "グッズショップ", "Goods Shop":
            return NSLocalizedString("goods_shop", comment: "Goods Shop")
        case "撮影スポット", "Photo Spot":
            return NSLocalizedString("photo_spot", comment: "Photo Spot")
        case "その他", "Other":
            return NSLocalizedString("other", comment: "Other")
        default:
            // If it's already a localized string, return as is
            if categories.contains(storedCategory) {
                return storedCategory
            }
            // Fallback to "Other" if category is not recognized
            return NSLocalizedString("other", comment: "Other")
        }
    }
    
    // 変更を保存
    func saveChanges() {
        guard let location = location else { return }
        
        isSaving = true
        
        // 位置情報が更新されている場合は新しい座標を使用
        let finalLatitude = newLatitude != 0.0 ? newLatitude : location.latitude
        let finalLongitude = newLongitude != 0.0 ? newLongitude : location.longitude
        
        viewModel.updateLocation(
            id: locationId,
            title: title,
            latitude: finalLatitude,
            longitude: finalLongitude,
            category: selectedCategory,
            rating: userRating,
            note: note.isEmpty ? nil : note,
            image: selectedImage
        ) { success in
            DispatchQueue.main.async {
                self.isSaving = false
                if success {
                    self.onLocationUpdated(self.locationId)
                    self.presentationMode.wrappedValue.dismiss()
                } else {
                    print("更新に失敗しました")
                }
            }
        }
    }
    
    // 都道府県リスト
    let prefectures = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
}

#Preview {
//    EditLocationView(
//        viewModel: LocationViewModel(),
//        locationId: "test-location-id",
//        onLocationUpdated: { id in
//            print("Location updated: \(id)")
//        }
//    )
    TopView()
}
