//
//  EnhancedAddLocationView.swift
//  osimono
//
//  Created by Apple on 2025/04/06.
//

import SwiftUI
import Firebase
import FirebaseAuth
import MapKit
import FirebaseStorage
import SwiftyCrop

struct EnhancedAddLocationView: View {
    @ObservedObject var viewModel: LocationViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var title: String = ""
    @State private var prefecture: String = "都道府県"
    @State private var streetAddress: String = ""
    @State private var buildingName: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var isShowingImagePicker: Bool = false
    @State private var note: String = ""
    @State private var selectedCategory: String = ""
    @State private var isShowingCategoryPicker = false
    @State private var coordinate: CLLocationCoordinate2D?
    @StateObject private var locationManager = LocationManager()
    @State private var userRating: Int = 0
    @State private var localImageURL: String? = nil
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6809591, longitude: 139.7673068),
        span: MKCoordinateSpan(latitudeDelta: 0.0008, longitudeDelta: 0.0008)
    )
    var onLocationAdded: (String) -> Void
    @State private var oshiItems: [String: Any] = [:]
    @State private var isSaving: Bool = false
    
    @State private var selectedImageForCropping: UIImage?
    @State private var croppingImage: UIImage?
    
    var cfg = SwiftyCropConfiguration(
        texts: .init(
            cancelButton: L10n.cancel,
            interactionInstructions: "",
            saveButton: NSLocalizedString("apply", comment: "Apply button")
        )
    )
    
    private var cropConfig: SwiftyCropConfiguration {
        var cfg = SwiftyCropConfiguration(
            texts: .init(
                cancelButton: L10n.cancel,
                interactionInstructions: "",
                saveButton: NSLocalizedString("apply", comment: "Apply button")
            )
        )
        
        return cfg
    }
    
    // Categories with localized strings
    let categories: [String]
    let categoryLabels: [String: String]
    
    init(viewModel: LocationViewModel, onLocationAdded: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.onLocationAdded = onLocationAdded
        
        // Initialize categories based on current language
        if isJapanese() {
            self.categories = ["聖地巡礼", "撮影スポット", "カフェ・飲食店", "ライブ会場", "グッズショップ", "その他"]
            self.categoryLabels = [
                "聖地巣礼": "聖地巡礼",
                "撮影スポット": "撮影スポット",
                "カフェ・飲食店": "カフェ・飲食店",
                "ライブ会場": "ライブ会場",
                "グッズショップ": "グッズショップ",
                "その他": "その他"
            ]
            self._selectedCategory = State(initialValue: "聖地巡礼")
        } else {
            self.categories = ["Pilgrimage", "Photo Spot", "Cafe/Restaurant", "Live Venue", "Goods Shop", "Other"]
            self.categoryLabels = [
                "Pilgrimage": "Pilgrimage",
                "Photo Spot": "Photo Spot",
                "Cafe/Restaurant": "Cafe/Restaurant",
                "Live Venue": "Live Venue",
                "Goods Shop": "Goods Shop",
                "Other": "Other"
            ]
            self._selectedCategory = State(initialValue: "Pilgrimage")
        }
        
        // Set default prefecture text based on language
        self._prefecture = State(initialValue: isJapanese() ? "都道府県" : "Prefecture")
    }
    
    // Computed property for the current address
    var currentAddress: String {
        var address = ""
        let prefectureDefault = isJapanese() ? "都道府県" : "Prefecture"
        if prefecture != prefectureDefault { address += prefecture + " " }
        if !streetAddress.isEmpty { address += streetAddress + " " }
        if !buildingName.isEmpty { address += buildingName }
        return address.trimmingCharacters(in: .whitespaces)
    }
    
    // Category color
    func categoryColor(_ category: String) -> Color {
        let normalizedCategory = categoryLabels[category] ?? category
        switch normalizedCategory {
        case "ライブ会場", "Live Venue": return Color(hex: "6366F1")
        case "聖地巡礼", "Pilgrimage": return Color(hex: "EF4444")
        case "カフェ・飲食店", "Cafe/Restaurant": return Color(hex: "10B981")
        case "グッズショップ", "Goods Shop": return Color(hex: "F59E0B")
        case "撮影スポット", "Photo Spot": return Color(hex: "EC4899")
        case "その他", "Other": return Color(hex: "6B7280")
        default: return Color(hex: "6366F1")
        }
    }

    var body: some View {
        ZStack{
            VStack(spacing: 0) {
                // Header
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
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Circle())
                        }
                        
                        Spacer()
                        
                        Text(NSLocalizedString("register_oshi_spot", comment: "Register oshi spot title"))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.leading,20)
                        Spacer()
                        
                        Button(action: {
                            generateHapticFeedback()
                            isSaving = true
                            // Save the location
                            if let coordinate = coordinate {
                                // 両方のテーブルに保存
                                saveToLocationsAndOshiItems(coordinate: coordinate)
                            } else {
                                // Try to geocode the address if coordinate is nil
                                let geocoder = CLGeocoder()
                                geocoder.geocodeAddressString(currentAddress) { placemarks, error in
                                    if let coordinate = placemarks?.first?.location?.coordinate {
                                        // 両方のテーブルに保存
                                        self.saveToLocationsAndOshiItems(coordinate: coordinate)
                                    } else {
                                        self.isSaving = false
                                        self.presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            }
                        }) {
                            Text(L10n.save)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top,isSmallDevice() ? 20 : 40)
                .edgesIgnoringSafeArea(.all)
                .frame(height: 50)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Image selector
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
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 200)
                                        .frame(maxWidth: .infinity)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.gray)
                                                
                                                Text(L10n.tapToSelectImage)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                }
                                if let image = selectedImage {
                                    // Edit button overlay
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
                                                    .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                                                    .padding(12)
                                            }
                                        }
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            
                                            Button(action: {
                                                generateHapticFeedback()
                                                isShowingImagePicker = true
                                            }) {
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
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Category Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.category)
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
                                    }
                                }
                                .padding(3)
                            }
                            .padding(.vertical, 4)
                        }
                        .padding(.horizontal)
                        
                        // Title Field
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(L10n.title)
                                    .font(.system(size: 16, weight: .medium))
                                
                                Spacer()
                                
                                Text("\(title.count) / 48")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            TextField(NSLocalizedString("example_oshi_spot", comment: "Example oshi spot title"), text: $title)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // New 5-Star Rating System
                        VStack(alignment: .leading, spacing: 12) {
                            HStack{
                                Text(L10n.favoriteRating)
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                            }
                            StarRatingView(rating: $userRating, size: 40)
                        }
                        .padding(.horizontal)
                        
                        // Address inputs
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(NSLocalizedString("address", comment: "Address"))
                                    .font(.system(size: 16, weight: .medium))
                                
                                Spacer()
                                
                                Button(action: {
                                    generateHapticFeedback()
                                    useCurrentLocation()
                                }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 12))
                                        
                                        Text(L10n.currentLocation)
                                            .font(.system(size: 14))
                                    }
                                    .foregroundColor(Color(hex: "6366F1"))
                                }
                            }
                            
                            VStack(spacing: 12) {
                                // Prefecture picker
                                Menu {
                                    Picker("", selection: $prefecture) {
                                        ForEach([isJapanese() ? "都道府県" : "Prefecture"] + prefectures, id: \.self) { pref in
                                            Text(pref).tag(pref)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(prefecture)
                                            .foregroundColor((prefecture == "都道府県" || prefecture == "Prefecture") ? .gray : .black)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                }
                                
                                // Street address
                                TextField(NSLocalizedString("street_address", comment: "Street address placeholder"), text: $streetAddress)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                
                                // Building name
                                TextField(NSLocalizedString("building_name", comment: "Building name placeholder"), text: $buildingName)
                                    .padding()
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Map preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("location_confirmation", comment: "Location confirmation"))
                                .font(.system(size: 16, weight: .medium))
                            
                            if let coordinate = coordinate {
                                Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { item in
                                    MapAnnotation(coordinate: item.coordinate, anchorPoint: CGPoint(x: 0.5, y: 0.5)) {
                                        MapPinView(
                                            imageName: localImageURL ?? "",
                                            isSelected: true,
                                            pinType: getPinType(for: selectedCategory)
                                        )
                                    }
                                }
                                .frame(height: 200)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            } else {
                                ZStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    if currentAddress.isEmpty {
                                        Text(NSLocalizedString("enter_address_to_show_map", comment: "Enter address message"))
                                            .foregroundColor(.gray)
                                    } else {
                                        ProgressView(NSLocalizedString("searching_location", comment: "Searching location"))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 80)
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
                            Text(L10n.saving)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                    )
                    .transition(.opacity)
            }
        }
        .dismissKeyboardOnTap()
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onChange(of: selectedImage) { newImage in
            if let newImage = newImage {
                localImageURL = localFileURL(for: newImage)
            } else {
                localImageURL = nil
            }
        }
        .onChange(of: currentAddress) { _ in
            geocodeAddress()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePickerView { pickedImage in
                self.selectedImageForCropping = pickedImage
            }
        }
        .onChange(of: selectedImageForCropping) { img in
            guard let img else { return }
            croppingImage = img            // シートを開くトリガ
        }
        .fullScreenCover(item: $croppingImage) { img in
            NavigationView {
                SwiftyCropView(
                    imageToCrop: img,
                    maskShape: .square,        // ← マスク形状
                    configuration: cropConfig  // ← 上で作った設定
                ) { cropped in
                    if let cropped { selectedImage = cropped }
                    croppingImage = nil
                }
            }
            .navigationBarHidden(true)        // 画面上部の「キャンセル」を消す
        }
        .onAppear {
            // If we have a current location, use it initially
            if let location = locationManager.userLocation {
                coordinate = location.coordinate
                region.center = location.coordinate
                
                // And also get the address
                let geocoder = CLGeocoder()
                geocoder.reverseGeocodeLocation(location) { placemarks, error in
                    if let placemark = placemarks?.first {
                        DispatchQueue.main.async {
                            prefecture = placemark.administrativeArea ?? prefecture
                            if let locality = placemark.locality,
                               let thoroughfare = placemark.thoroughfare,
                               let subThoroughfare = placemark.subThoroughfare {
                                streetAddress = "\(locality) \(thoroughfare) \(subThoroughfare)"
                            } else if let name = placemark.name {
                                streetAddress = name
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Rating description text based on the selected rating
    var ratingDescriptionText: String {
        switch userRating {
        case 0: return NSLocalizedString("tap_to_rate", comment: "Tap to rate")
        case 1: return NSLocalizedString("rating_poor", comment: "Poor rating")
        case 2: return NSLocalizedString("rating_fair", comment: "Fair rating")
        case 3: return NSLocalizedString("rating_good", comment: "Good rating")
        case 4: return NSLocalizedString("rating_very_good", comment: "Very good rating")
        case 5: return NSLocalizedString("rating_excellent", comment: "Excellent rating")
        default: return ""
        }
    }
    
    private func saveToOshiItems(coordinate: CLLocationCoordinate2D, locationId: String?) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not logged in")
            return
        }
        
        // 現在の日付
        let currentDate = Date()
        
        // アイテムデータの準備
        var oshiItemData: [String: Any] = [
            "id": locationId ?? UUID().uuidString,
            "title": title.isEmpty ? selectedCategory : title,
            "memo": note,
            "favorite": userRating,
            "itemType": isJapanese() ? "聖地巡礼" : "Pilgrimage", // Localized item type
            "oshiId": viewModel.currentOshiId,
            "createdAt": currentDate.timeIntervalSince1970,
            "visitDate": currentDate.timeIntervalSince1970,
            "locationAddress": currentAddress,
            "memories": note
        ]
        
        // 画像URLがある場合（先にlocationsに保存して画像URLが取得できている場合）は、
        // 同じURLを使用
        if let loc = viewModel.locations.first(where: { $0.id == locationId }),
           let imageURL = loc.imageURL {
            oshiItemData["imageUrl"] = imageURL
            saveOshiItemToFirebase(oshiItemData)
        } else if let image = selectedImage {
            // 画像をアップロード
            uploadImageForOshiItem(image) { imageUrl in
                if let url = imageUrl {
                    oshiItemData["imageUrl"] = url
                }
                self.saveOshiItemToFirebase(oshiItemData)
            }
        } else {
            // 画像なしで保存
            saveOshiItemToFirebase(oshiItemData)
        }
    }
    
    // oshiItemsテーブルへの画像アップロード
    private func uploadImageForOshiItem(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
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
    
    // oshiItemsテーブルにデータを保存
    private func saveOshiItemToFirebase(_ data: [String: Any]) {
        guard let userId = Auth.auth().currentUser?.uid,
              let itemId = data["id"] as? String,
              let oshiId = data["oshiId"] as? String else {
            print("必要なデータが不足しています")
            return
        }
        
        let ref = Database.database().reference().child("oshiItems").child(userId).child(oshiId).child(itemId)
        
        ref.setValue(data) { error, _ in
            if let error = error {
                print("oshiItemsテーブルへの保存に失敗しました: \(error.localizedDescription)")
            } else {
                print("oshiItemsテーブルへの保存に成功しました")
            }
        }
    }
    
    private func saveToLocationsAndOshiItems(coordinate: CLLocationCoordinate2D) {
        // まずlocationsテーブルに保存
        viewModel.addLocation(
            title: title.isEmpty ? selectedCategory : title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: selectedCategory,
            initialRating: userRating,
            note: note.isEmpty ? nil : note,
            image: selectedImage
        ) { newLocationId in
            // 次にoshiItemsテーブルにも保存（聖地巡礼の場合）
            let pilgrimageCategory = isJapanese() ? "聖地巡礼" : "Pilgrimage"
            if selectedCategory == pilgrimageCategory {
                self.saveToOshiItems(
                    coordinate: coordinate,
                    locationId: newLocationId
                )
            }
            
            if let newLocationId = newLocationId {
                // Call the callback with the new location ID
                onLocationAdded(newLocationId)
            }
            DispatchQueue.main.async {
                self.isSaving = false
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    func localFileURL(for image: UIImage) -> String? {
        if let data = image.jpegData(compressionQuality: 0.8) {
            let tempDirectory = NSTemporaryDirectory()
            let fileName = UUID().uuidString + ".jpg"
            let fileURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName)
            do {
                try data.write(to: fileURL)
                return fileURL.absoluteString
            } catch {
                print("画像の一時保存に失敗しました: \(error)")
                return nil
            }
        }
        return nil
    }
    
    // Convert the selected category to pin type
    func getPinType(for category: String) -> MapPinView.PinType {
        switch category {
        case "ライブ会場", "Live Venue": return .live
        case "聖地巡礼", "Pilgrimage": return .sacred
        case "カフェ・飲食店", "Cafe/Restaurant": return .cafe
        case "グッズショップ", "Goods Shop": return .shop
        case "撮影スポット", "Photo Spot": return .photo
        case "その他", "Other": return .other
        default: return .other
        }
    }
    
    // Geocode the address to get coordinates
    func geocodeAddress() {
        guard !currentAddress.isEmpty else { return }
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(currentAddress) { placemarks, error in
            if let placemark = placemarks?.first, let location = placemark.location {
                DispatchQueue.main.async {
                    coordinate = location.coordinate
                    region.center = location.coordinate
                }
            } else {
                print("住所のジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
            }
        }
    }
    
    // Use current location
    func useCurrentLocation() {
        if let location = locationManager.userLocation {
            coordinate = location.coordinate
            region.center = location.coordinate
            
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        prefecture = placemark.administrativeArea ?? prefecture
                        if let locality = placemark.locality,
                           let thoroughfare = placemark.thoroughfare,
                           let subThoroughfare = placemark.subThoroughfare {
                            streetAddress = "\(locality) \(thoroughfare) \(subThoroughfare)"
                        } else if let name = placemark.name {
                            streetAddress = name
                        }
                    }
                } else {
                    print("逆ジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
                }
            }
        } else {
            print("現在地が取得できません")
        }
    }
    
    // Array of prefectures for the picker - localized based on current language
    var prefectures: [String] {
        if isJapanese() {
            return [
                "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
                "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
                "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
                "岐阜県", "静岡県", "愛知県", "三重県",
                "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
                "鳥取県", "島根県", "岡山県", "広島県", "山口県",
                "徳島県", "香川県", "愛媛県", "高知県",
                "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
            ]
        } else {
            return [
                "Hokkaido", "Aomori", "Iwate", "Miyagi", "Akita", "Yamagata", "Fukushima",
                "Ibaraki", "Tochigi", "Gunma", "Saitama", "Chiba", "Tokyo", "Kanagawa",
                "Niigata", "Toyama", "Ishikawa", "Fukui", "Yamanashi", "Nagano",
                "Gifu", "Shizuoka", "Aichi", "Mie",
                "Shiga", "Kyoto", "Osaka", "Hyogo", "Nara", "Wakayama",
                "Tottori", "Shimane", "Okayama", "Hiroshima", "Yamaguchi",
                "Tokushima", "Kagawa", "Ehime", "Kochi",
                "Fukuoka", "Saga", "Nagasaki", "Kumamoto", "Oita", "Miyazaki", "Kagoshima", "Okinawa"
            ]
        }
    }
}

#Preview {
    let mockViewModel = LocationViewModel()
    
    return EnhancedAddLocationView(
        viewModel: mockViewModel,
        onLocationAdded: { locationId in
            print("追加された場所のID: \(locationId)")
        }
    )
}
