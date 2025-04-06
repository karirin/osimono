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
    @State private var selectedCategory: String = "ライブ"
    @State private var isShowingCategoryPicker = false
    @State private var coordinate: CLLocationCoordinate2D?
    @StateObject private var locationManager = LocationManager()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6809591, longitude: 139.7673068),
        span: MKCoordinateSpan(latitudeDelta: 0.0008, longitudeDelta: 0.0008)
    )
    
    let categories = ["ライブ", "広告", "カフェ", "その他"]
    
    // Computed property for the current address
    var currentAddress: String {
        var address = ""
        if prefecture != "都道府県" { address += prefecture + " " }
        if !streetAddress.isEmpty { address += streetAddress + " " }
        if !buildingName.isEmpty { address += buildingName }
        return address.trimmingCharacters(in: .whitespaces)
    }
    
    // Category color
    func categoryColor(_ category: String) -> Color {
        switch category {
        case "ライブ": return Color(hex: "6366F1")
        case "広告": return Color(hex: "EC4899")
        case "カフェ": return Color(hex: "10B981")
        default: return Color(hex: "6366F1")
        }
    }
    
    var body: some View {
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
//                    .frame(height: 60)
                
                HStack {
                    Button(action: {
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
                    
                    Text("推しスポット登録")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.leading,20)
                    Spacer()
                    
                    Button(action: {
                        // Save the location
                        if let coordinate = coordinate {
                            viewModel.addLocation(
                                title: title.isEmpty ? selectedCategory : title,
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                image: selectedImage
                            )
                        } else {
                            // Try to geocode the address if coordinate is nil
                            let geocoder = CLGeocoder()
                            geocoder.geocodeAddressString(currentAddress) { placemarks, error in
                                if let coordinate = placemarks?.first?.location?.coordinate {
                                    viewModel.addLocation(
                                        title: title.isEmpty ? selectedCategory : title,
                                        latitude: coordinate.latitude,
                                        longitude: coordinate.longitude,
                                        image: selectedImage
                                    )
                                }
                            }
                        }
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(16)
                    }
                    .disabled(coordinate == nil && currentAddress.isEmpty)
                    .opacity((coordinate == nil && currentAddress.isEmpty) ? 0.5 : 1)
                }
                .padding(.horizontal)
            }
            .padding(.top,40)
            .edgesIgnoringSafeArea(.all)
            .frame(height: 50)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Image selector
                    Button(action: {
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
                                            
                                            Text("タップして画像を追加")
                                                .font(.system(size: 16))
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                            
                            // Edit button overlay
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    
                                    Button(action: {
                                        isShowingImagePicker = true
                                    }) {
                                        Text("画像を変更")
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
                    .padding(.horizontal)
                    
                    // Category Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("カテゴリー")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                        
                        HStack {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
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
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                    
                    // Title Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("タイトル")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(title.count) / 48")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        TextField("例：XX推しライブ会場", text: $title)
                            .padding()
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Address inputs
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("住所")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Button(action: {
                                useCurrentLocation()
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
                            // Prefecture picker
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
                            
                            // Street address
                            TextField("市区町村・番地", text: $streetAddress)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                            
                            // Building name
                            TextField("ビル名・階数（任意）", text: $buildingName)
                                .padding()
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Map preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("場所の確認")
                            .font(.system(size: 16, weight: .medium))
                        
                        if let coordinate = coordinate {
                            Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { item in
                                MapAnnotation(coordinate: item.coordinate, anchorPoint: CGPoint(x: 0.5, y: 1.0)) {
                                    MapPinView(
                                        imageName: "",
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
                                    Text("住所を入力すると地図が表示されます")
                                        .foregroundColor(.gray)
                                } else {
                                    ProgressView("位置情報を検索中...")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Note Field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("メモ")
                                .font(.system(size: 16, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(note.count) / 200")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty {
                                Text("どんな推しスポットか簡単に説明しましょう")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $note)
                                .padding(4)
                                .frame(height: 100)
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                .opacity(note.isEmpty ? 0.25 : 1)
                        }
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
                .padding(.bottom, 80)
            }
        }
        .onChange(of: currentAddress) { _ in
            geocodeAddress()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            // Use your image picker implementation here
            // For example:
            // ImagePicker(image: $selectedImage)
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
    
    // Convert the selected category to pin type
    func getPinType(for category: String) -> MapPinView.PinType {
        switch category {
        case "ライブ": return .live
        case "広告": return .ad
        case "カフェ": return .cafe
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
    
    // Array of prefectures for the picker
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
