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
    @State private var selectedCategory: String = "聖地巡礼"
    @State private var userRating: Int = 0
    @State private var note: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var isShowingImagePicker: Bool = false
    @State private var isSaving: Bool = false
    
    // 住所関連の追加項目
    @State private var prefecture: String = "都道府県"
    @State private var streetAddress: String = ""
    @State private var buildingName: String = ""
    @State private var isEditingAddress: Bool = false
    @State private var isGeocodingAddress: Bool = false
    @State private var newLatitude: Double = 0.0
    @State private var newLongitude: Double = 0.0
    @State private var showAddressUpdateAlert: Bool = false
    @State private var pendingCoordinate: (latitude: Double, longitude: Double)?
    
    // 現在の住所を組み立て
    var currentAddress: String {
        var address = ""
        if prefecture != "都道府県" { address += prefecture + " " }
        if !streetAddress.isEmpty { address += streetAddress + " " }
        if !buildingName.isEmpty { address += buildingName }
        return address.trimmingCharacters(in: .whitespaces)
    }
    
    let categories = ["聖地巡礼", "撮影スポット", "カフェ・飲食店", "ライブ会場", "グッズショップ", "その他"]
    
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
                // Custom Header (EnhancedAddLocationViewと同じスタイル)
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
                        
                        Spacer()
                        
                        Text("スポット編集")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            generateHapticFeedback()
                            saveChanges()
                        }) {
                            Text("保存")
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
                            ProgressView("読み込み中...")
                                .scaleEffect(1.2)
                            Text("スポット情報を取得しています")
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
                                                        Text("タップして画像を変更")
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
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                // タイトル編集
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("タイトル")
                                            .font(.system(size: 16, weight: .medium))
                                        
                                        Spacer()
                                        
                                        Text("\(title.count) / 48")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    TextField("スポット名を入力", text: $title)
                                        .padding()
                                        .background(Color(UIColor.systemGray6))
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal)
                                
                                // 住所編集セクション
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("住所")
                                            .font(.system(size: 16, weight: .medium))
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            generateHapticFeedback()
                                            geocodeAddress()
                                        }) {
                                            HStack {
                                                Image(systemName: "location.fill")
                                                    .font(.system(size: 12))
                                                
                                                Text("現在地を使用")
                                                    .font(.system(size: 14))
                                            }
                                            .foregroundColor(Color(hex: "6366F1"))
                                        }
                                    }
                                    
                                    VStack(spacing: 12) {
                                        // 都道府県選択
                                        Menu {
                                            Picker("", selection: $prefecture) {
                                                ForEach(["都道府県"] + prefectures, id: \.self) { pref in
                                                    Text(pref).tag(pref)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(prefecture)
                                                    .foregroundColor(prefecture == "都道府県" ? .gray : .black)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                        }
                                        
                                        // 市区町村・番地
                                        TextField("市区町村・番地", text: $streetAddress)
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                        
                                        // ビル名・階数
                                        TextField("ビル名・階数（任意）", text: $buildingName)
                                            .padding()
                                            .background(Color(UIColor.systemGray6))
                                            .cornerRadius(12)
                                    }
                                }
                                .padding(.horizontal)
                                
                                // カテゴリー選択
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("カテゴリー")
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
                                
                                // 評価編集
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack{
                                        Text("評価")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    StarRatingView(rating: $userRating, size: 40)
                                    
//                                    Text(ratingDescriptionText)
//                                        .font(.system(size: 14))
//                                        .foregroundColor(.gray)
//                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .padding(.horizontal)
                                
                                // メモ編集
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("メモ")
//                                            .font(.system(size: 16, weight: .medium))
//                                        
//                                        Spacer()
//                                        
//                                        Text("\(note.count) / 200")
//                                            .font(.system(size: 14))
//                                            .foregroundColor(.gray)
//                                    }
//                                    
////                                    ZStack(alignment: .topLeading) {
////                                        if note.isEmpty {
////                                            Text("メモを入力してください")
////                                                .foregroundColor(.gray)
////                                                .padding(.horizontal, 8)
////                                                .padding(.vertical, 12)
////                                        }
////                                        
////                                        TextEditor(text: $note)
////                                            .padding(4)
////                                            .frame(height: 100)
////                                            .background(Color(UIColor.systemGray6))
////                                            .cornerRadius(12)
////                                            .opacity(note.isEmpty ? 0.25 : 1)
////                                    }
////                                    .background(Color(UIColor.systemGray6))
////                                    .cornerRadius(12)
//                                }
//                                .padding(.horizontal)
                                Button(action: {
                                    generateHapticFeedback()
                                    saveChanges()
                                }) {
                                    Text("保存する")
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
                            Text("スポット情報の読み込みに失敗しました")
                                .font(.headline)
                                .padding(.top, 8)
                            Button("再試行") {
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
                                    Text("更新中...")
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
                .navigationTitle("推しスポット編集")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    },
                    trailing: Button("保存") {
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
                    title: Text("位置情報を更新"),
                    message: Text("住所から新しい位置情報を取得しました。位置情報を更新しますか？"),
                    primaryButton: .default(Text("更新")) {
                        if let coordinate = pendingCoordinate {
                            newLatitude = coordinate.latitude
                            newLongitude = coordinate.longitude
                        }
                        pendingCoordinate = nil
                    },
                    secondaryButton: .cancel(Text("キャンセル")) {
                        pendingCoordinate = nil
                    }
                )
            }
        }
    }
        // 評価の説明テキスト
        var ratingDescriptionText: String {
            switch userRating {
            case 0: return "タップして評価してください"
            case 1: return "イマイチ"
            case 2: return "まあまあ"
            case 3: return "普通"
            case 4: return "良い"
            case 5: return "最高の推しスポット！"
            default: return ""
            }
        }
        
        // カテゴリーの色を取得
        func categoryColor(_ category: String) -> Color {
            switch category {
            case "ライブ会場": return Color(hex: "6366F1")
            case "聖地巡礼": return Color(hex: "EF4444")
            case "カフェ・飲食店": return Color(hex: "10B981")
            case "グッズショップ": return Color(hex: "F59E0B")
            case "撮影スポット": return Color(hex: "EC4899")
            case "その他": return Color(hex: "6B7280")
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
                        // エラーハンドリング（必要に応じてユーザーに通知）
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
                self.selectedCategory = existingLocation.category
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
                        self.selectedCategory = locationData.category
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
                        // エラーハンドリング
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
