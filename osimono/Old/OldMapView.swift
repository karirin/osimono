////
////  MapView.swift
////  osimono
////
////  Created by Apple on 2025/03/25.
////
//
import MapKit
import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import CoreLocation
import Shimmer
//
//

//

//struct MapAnnotationItem: Identifiable {
//    let id = UUID()
//    var coordinate: CLLocationCoordinate2D
//}
//
//// 変更箇所：新規追加
//
////struct GoodsFormView: View {
////    @State private var eventTitle = ""
////    @State private var startDate = Date()
////    @State private var endDate = Date().addingTimeInterval(3600) // Default 1 hour later
////    @State private var eventDescription = ""
////    
////    @State private var newGoodsName = ""
////    @State private var newPrice = ""
////    @State private var newPurchasePlace = ""
////    @State private var newCategory = ""
////    @State private var newOshi = ""
////    @State private var newMemo = ""
////    @State private var privacy = "公開"
////    @State private var selectedImage: UIImage?
////    @State private var isShowingImagePicker = false
////    @Environment(\.presentationMode) var presentationMode
////    
////    var body: some View {
////        VStack(spacing: 0) {
////            // Header
////            HStack {
////                Button(action: {
////                    self.presentationMode.wrappedValue.dismiss()
////                }) {
////                    Image(systemName: "xmark")
////                        .foregroundStyle(.black)
////                }
////                Spacer()
////                Text("イベント作成")
////                    .font(.system(size: 18, weight: .medium))
////                Spacer()
////                Button("作成") {
////                    saveEvent()
////                    self.presentationMode.wrappedValue.dismiss()
////                }
////                .foregroundColor(.gray)
////            }
////            .padding(.horizontal)
////            .padding(.vertical, 12)
////            
////            ScrollView {
////                VStack(spacing: 24) {
////                    // Image Selection
////                    Button(action: {
////                        isShowingImagePicker = true
////                    }) {
////                        ZStack {
////                            if let image = selectedImage {
////                                Image(uiImage: image)
////                                    .resizable()
////                                    .scaledToFill()
////                                    .frame(height: 180)
////                                    .frame(maxWidth: .infinity)
////                                    .clipped()
////                            } else {
////                                Rectangle()
////                                    .fill(Color.yellow)
////                                    .frame(height: 180)
////                                    .frame(maxWidth: .infinity)
////                                
////                                // Calendar and people illustration would be here
////                                // Placeholder text for the demo
////                                VStack {
////                                    Spacer()
////                                    HStack {
////                                        Spacer()
////                                        Button(action: {
////                                            isShowingImagePicker = true
////                                        }) {
////                                            Text("画像を変更する")
////                                                .font(.system(size: 14))
////                                                .padding(.vertical, 6)
////                                                .padding(.horizontal, 10)
////                                                .background(Color.black.opacity(0.6))
////                                                .foregroundColor(.white)
////                                                .cornerRadius(20)
////                                        }
////                                        .padding(8)
////                                    }
////                                }
////                            }
////                        }
////                    }
////                    
////                    // Title Field
////                    VStack(alignment: .leading, spacing: 8) {
////                        HStack {
////                            Text("タイトル")
////                                .font(.system(size: 16))
////                            Spacer()
////                            Text("\(newGoodsName.count) / 48")
////                                .font(.system(size: 14))
////                                .foregroundColor(.gray)
////                        }
////                        
////                        TextField("ライブ", text: $newGoodsName)
////                            .padding()
////                            .background(Color(UIColor.systemGray6))
////                            .cornerRadius(8)
////                    }
////                    .padding(.horizontal)
////                    
////                    VStack(alignment: .leading, spacing: 8) {
////                        HStack {
////                            Text("価格")
////                                .font(.system(size: 16))
////                            Spacer()
////                            Text("\(newPrice.count) / 48")
////                                .font(.system(size: 14))
////                                .foregroundColor(.gray)
////                        }
////                        
////                        TextField("5000", text: $newPrice)
////                            .padding()
////                            .background(Color(UIColor.systemGray6))
////                            .cornerRadius(8)
////                    }
////                    .padding(.horizontal)
////                    
////                    VStack(alignment: .leading, spacing: 8) {
////                        HStack {
////                            Text("カテゴリ")
////                                .font(.system(size: 16))
////                            Spacer()
////                            Text("\(newCategory.count) / 48")
////                                .font(.system(size: 14))
////                                .foregroundColor(.gray)
////                        }
////                        
////                        TextField("ライブ写真", text: $eventTitle)
////                            .padding()
////                            .background(Color(UIColor.systemGray6))
////                            .cornerRadius(8)
////                    }
////                    .padding(.horizontal)
////                    
////                    // Description
////                    VStack(alignment: .leading, spacing: 8) {
////                        HStack {
////                            Text("メモ")
////                                .font(.system(size: 16))
////                            Spacer()
////                            Text("\(eventDescription.count) / 394")
////                                .font(.system(size: 14))
////                                .foregroundColor(.gray)
////                        }
////                        
////                        ZStack(alignment: .topLeading) {
////                            if eventDescription.isEmpty {
////                                Text("どんな推しに関する投稿か簡単なテキストで説明しましょう")
////                                    .foregroundColor(.gray)
////                                    .padding(.horizontal, 8)
////                                    .padding(.vertical, 12)
////                            }
////                            
////                            TextEditor(text: $eventDescription)
////                                .padding(4)
////                                .frame(height: 100)
////                                .background(Color(UIColor.systemGray6))
////                                .opacity(eventDescription.isEmpty ? 0.25 : 1)
////                        }
////                        .background(Color(UIColor.systemGray6))
////                        .cornerRadius(8)
////                    }
////                    .padding(.horizontal)
////                    
////                    Spacer()
////                }
////                .padding(.top, 16)
////            }
////        }
////        .sheet(isPresented: $isShowingImagePicker) {
////            ImagePicker(image: $selectedImage, onImagePicked: { image in
////                self.selectedImage = image
////            })
////        }
////    }
////    
////    func saveEvent() {
////        guard let userId = Auth.auth().currentUser?.uid else { return }
////        
////        // Upload image if available
////        if let image = selectedImage {
////            uploadImage(userId: userId) { imageUrl in
////                saveEventToDatabase(userId: userId, imageUrl: imageUrl)
////            }
////        } else {
////            saveEventToDatabase(userId: userId, imageUrl: nil)
////        }
////    }
////    
////    func uploadImage(userId: String, completion: @escaping (String?) -> Void) {
////        guard let image = selectedImage else {
////            completion(nil)
////            return
////        }
////        
////        let storageRef = Storage.storage().reference()
////        let imageID = UUID().uuidString
////        let imageRef = storageRef.child("events/\(userId)/\(imageID).jpg")
////        
////        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
////            completion(nil)
////            return
////        }
////        
////        let metadata = StorageMetadata()
////        metadata.contentType = "image/jpeg"
////        
////        imageRef.putData(imageData, metadata: metadata) { _, error in
////            if let error = error {
////                print("アップロードエラー: \(error.localizedDescription)")
////                completion(nil)
////                return
////            }
////            
////            imageRef.downloadURL { url, error in
////                if let error = error {
////                    print("画像URL取得エラー: \(error.localizedDescription)")
////                    completion(nil)
////                    return
////                }
////                
////                completion(url?.absoluteString)
////            }
////        }
////    }
////    
////    func saveEventToDatabase(userId: String, imageUrl: String?) {
////        let ref = Database.database().reference().child("events").child(userId)
////        let newEventID = ref.childByAutoId().key ?? UUID().uuidString
////        
////        // Format dates to strings for display
////        let dateFormatter = DateFormatter()
////        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
////        
////        let event = [
////            "id": newEventID,
////            "userId": userId,
////            "title": eventTitle,
////            "imageUrl": imageUrl ?? "",
////            "startDate": dateFormatter.string(from: startDate),
////            "endDate": dateFormatter.string(from: endDate),
////            "description": eventDescription,
////            "privacy": privacy,
////            "createdAt": ServerValue.timestamp()
////        ] as [String : Any]
////        
////        ref.child(newEventID).setValue(event) { error, _ in
////            if let error = error {
////                print("イベント保存エラー: \(error.localizedDescription)")
////            } else {
////                print("イベントを保存しました: \(newEventID)")
////            }
////        }
////    }
////}
//
//struct AddLocationView: View {
//    @ObservedObject var viewModel: LocationViewModel
//    @Environment(\.presentationMode) var presentationMode
//    @State private var title: String = ""
//    @State private var address: String = ""
//    @State private var latitude: String = ""
//    @State private var longitude: String = ""
//    @State private var selectedImage: UIImage? = nil
//    @State private var isShowingImagePicker: Bool = false
//    @State private var isAddressFlag: Bool = false
//    @State private var prefecture: String = "都道府県"
//    @State private var streetAddress: String = ""
//    @State private var buildingName: String = ""
//    let prefectures = [
//        "都道府県", "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
//        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
//        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
//        "岐阜県", "静岡県", "愛知県", "三重県",
//        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
//        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
//        "徳島県", "香川県", "愛媛県", "高知県",
//        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
//    ]
//    @StateObject private var locationManager = LocationManager()
//    @State private var region = MKCoordinateRegion(
//        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
//        span: MKCoordinateSpan(latitudeDelta: 0.0008, longitudeDelta: 0.0008)
//    )
//    @State private var coordinate: CLLocationCoordinate2D?
//
//    // 入力中の住所を組み立てるプロパティ
//    var currentAddress: String {
//        var address = ""
//        if !prefecture.isEmpty { address += prefecture + " " }
//        if !streetAddress.isEmpty { address += streetAddress + " " }
//        if !buildingName.isEmpty { address += buildingName }
//        return address.trimmingCharacters(in: .whitespaces)
//    }
//    
//
//    var body: some View {
//        VStack{
//            HStack {
//                Button(action: {
//                    self.presentationMode.wrappedValue.dismiss()
//                }) {
//                    Image(systemName: "xmark")
//                        .foregroundStyle(.black)
//                }
//                Spacer()
//                Text("登録")
//                    .font(.system(size: 18, weight: .medium))
//                Spacer()
//                Button(action: {
//                    let geocoder = CLGeocoder()
//                    geocoder.geocodeAddressString(currentAddress) { placemarks, error in
//                        if let coordinate = placemarks?.first?.location?.coordinate {
//                            viewModel.addLocation(title: title, latitude: coordinate.latitude, longitude: coordinate.longitude, image: selectedImage)
//                        } else {
//                            print("住所のジオコーディングに失敗しました: \(error?.localizedDescription ?? "不明なエラー")")
//                        }
//                    }
//                    self.presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("作成")
//                }
//                .foregroundColor(.gray)
//            }
//            .padding()
//            ScrollView {
//                VStack(spacing: 24) {
//                    // Image Selection
//                    Button(action: {
//                        isShowingImagePicker = true
//                    }) {
//                        ZStack {
//                            if let image = selectedImage {
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(height: 180)
//                                    .frame(maxWidth: .infinity)
//                                    .clipped()
//                            } else {
//                                ZStack{
//                                    Rectangle()
//                                        .fill(Color.gray.opacity(0.2))
//                                        .frame(height: 180)
//                                        .frame(maxWidth: .infinity)
//                                    Image(systemName: "photo")
//                                        .font(.system(size: 30))
//                                        .foregroundStyle(.black)
//                                    // Calendar and people illustration would be here
//                                    // Placeholder text for the demo
//                                    VStack {
//                                        Spacer()
//                                        HStack {
//                                            Spacer()
//                                            Button(action: {
//                                                isShowingImagePicker = true
//                                            }) {
//                                                Text("画像を変更する")
//                                                    .font(.system(size: 14))
//                                                    .padding(.vertical, 6)
//                                                    .padding(.horizontal, 10)
//                                                    .background(Color.black.opacity(0.6))
//                                                    .foregroundColor(.white)
//                                                    .cornerRadius(20)
//                                            }
//                                            .padding(8)
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                    }
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("タイトル")
//                                .font(.system(size: 16))
//                            Spacer()
//                            Text("\(title.count) / 48")
//                                .font(.system(size: 14))
//                                .foregroundColor(.gray)
//                        }
//                        
//                        TextField("ライブ", text: $title)
//                            .padding(10)
//                            .background(Color(UIColor.systemGray6))
//                            .cornerRadius(8)
//                    }
//                    .padding(.horizontal)
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("住所入力")
//                                .font(.system(size: 16))
//                            Spacer()
//                            Button(action: {
//                                useCurrentLocation()
//                                geocodeAddress()
//                            }) {
//                                Text("現在地を使用")
//                            }
//                        }
//                        HStack{
//                            Picker("都道府県", selection: $prefecture) {
//                                ForEach(prefectures, id: \.self) { pref in
//                                    Text(pref)
//                                }
//                            }
//                            
//                            TextField("市区町村・番地", text: $streetAddress)
//                                .padding(10)
//                                .background(Color(UIColor.systemGray6))
//                                .cornerRadius(8)
//                        }
//                    }.padding(.horizontal)
//                    if let coordinate = coordinate {
//                        //                .cornerRadius(10)
//                        Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { item in
//                            MapAnnotation(coordinate: item.coordinate, anchorPoint: CGPoint(x: 0.5, y: 1.0)) {
//                                AddressMapPinView(image: selectedImage, isSelected: false)
//                            }
//                        }
//                        .frame(height: isSmallDevice() ? 150 : 200)
//                    } else {
//                        Text("位置情報は設定されていません")
//                            .foregroundStyle(Color.gray)
//                            .frame(height: 100)
//                    }
//                }
//                .onChange(of: currentAddress) { _ in
//                     geocodeAddress()
//                 }
//                .sheet(isPresented: $isAddressFlag) {
//                    AddressInputView(image: selectedImage, prefecture: $prefecture, streetAddress: $streetAddress, buildingName: $buildingName)
//                }
//                .sheet(isPresented: $isShowingImagePicker) {
//                    ImageTimeLinePicker(selectedImage: $selectedImage)
//                }
//            }
//        }
//    }
//    
//    func geocodeAddress() {
//        let geocoder = CLGeocoder()
//        geocoder.geocodeAddressString(currentAddress) { placemarks, error in
//            if let placemark = placemarks?.first, let location = placemark.location {
//                DispatchQueue.main.async {
//                    // ① 取得した座標をいったん保持
//                    coordinate = location.coordinate
//                    
//                    // ② マップの中心を少しだけ北側にオフセットして設定
//                    let offsetLatitude = location.coordinate.latitude + 0.00025
//                    region.center = CLLocationCoordinate2D(latitude: offsetLatitude,
//                                                           longitude: location.coordinate.longitude)
//                }
//            } else {
//                print("住所のジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
//            }
//        }
//    }
//    
//    func useCurrentLocation() {
//        if let location = locationManager.userLocation {
//            let geocoder = CLGeocoder()
//            geocoder.reverseGeocodeLocation(location) { placemarks, error in
//                if let placemark = placemarks?.first {
//                    DispatchQueue.main.async {
//                        prefecture = placemark.administrativeArea ?? prefecture
//                        if let locality = placemark.locality,
//                           let thoroughfare = placemark.thoroughfare,
//                           let subThoroughfare = placemark.subThoroughfare {
//                            print("現在地  ：\(locality) \(thoroughfare) \(subThoroughfare)")
//                            streetAddress = "\(locality) \(thoroughfare) \(subThoroughfare)"
//                        } else if let name = placemark.name {
//                            streetAddress = name
//                        }
//                    }
//                } else {
//                    print("逆ジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
//                }
//            }
//        } else {
//            print("現在地が取得できません")
//        }
//    }
//}
//
//struct MapView: View {
//    @ObservedObject var viewModel = LocationViewModel()
//    @State private var showAddLocation = false
//    @State private var region = MKCoordinateRegion(
//        center: CLLocationCoordinate2D(latitude: 35.6809591, longitude: 139.7673068), // 初期表示座標（例：東京駅付近）
//        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
//    )
//    @State private var selectedLocationId: String? = nil
//    @StateObject private var locationManager = LocationManager()
//    @State private var prefecture: String = ""
//    @State private var cityStreet: String = ""
//    @State private var buildingName: String = ""
//    @State private var errorMessage: String?
//    
//    struct Location: Identifiable {
//        let id = UUID()
//        let title: String
//        let imageURL: String
//        let likeCount: Int
//        let type: String
//    }
//    
//    var body: some View {
//        NavigationView {
//            ZStack(alignment: .bottom) {
//                Map(coordinateRegion: $region, annotationItems: viewModel.locations) { location in
//                    MapAnnotation(
//                        coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), anchorPoint: CGPoint(x: 0.5, y: 1.0)
//                    ) {
//                        MapPinView(imageName: location.imageURL ?? "アイドル会場", isSelected: selectedLocationId == location.id)
//                            .onTapGesture {
//                                withAnimation {
//                                    if selectedLocationId == location.id {
//                                        selectedLocationId = nil  // すでに選択されている場合は解除
//                                    } else {
//                                        selectedLocationId = location.id  // 未選択の場合は選択
//                                    }
//                                }
//                            }
//                            .zIndex(selectedLocationId == location.id ? 1 : 0)
//                    }
//                }
//                
//                .edgesIgnoringSafeArea(.all)
//                ScrollViewReader { scrollProxy in
//                    ScrollView(.horizontal, showsIndicators: false) {
//                        HStack(spacing: 16) {
//                            ForEach(viewModel.locations) { location in
//                                VStack(alignment: .leading, spacing: 0) {
//                                    // カード上部の画像
//                                    ZStack {
//                                        AsyncImage(url: URL(string: location.imageURL ?? "")) { image in
//                                            image
//                                                .resizable()
//                                                .scaledToFill()
//                                        } placeholder: {
//                                            Rectangle()
//                                                .foregroundColor(.gray)
//                                                .shimmer(true)
//                                        }
//                                    }
//                                    .frame(height: selectedLocationId == location.id ? 140 : 100)
//                                    .clipped()
//                                    
//                                    // カード下部のテキストやアイコン
//                                    VStack(alignment: .leading, spacing: 4) {
//                                        Text(location.title)
//                                            .font(.system(size: 16))
//                                            .lineLimit(1)
//                                    }
//                                    .padding(.bottom,selectedLocationId == location.id ? 10 : 0)
//                                    .padding(.leading,selectedLocationId == location.id ? 10 : 0)
//                                    .padding(10)
//                                }
//                                .frame(width: selectedLocationId == location.id ? 250 : 160)
//                                .scaleEffect(selectedLocationId == location.id ? 1.1 : 1.0)
//                                .background(Color.white)
//                                .cornerRadius(12)
//                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
//                                
//                                // 変更箇所：要素ごとに .id() を付けてScrollViewReaderで参照できるようにする
//                                .id(location.id)
//                                // タップしたら選択状態にしてスクロール
//                                .onTapGesture {
//                                    withAnimation {
//                                        if selectedLocationId == location.id {
//                                            selectedLocationId = nil
//                                        } else {
//                                            selectedLocationId = location.id
//                                        }
//                                    }
//                                }
//                            }
//                        }
//                        .padding(.horizontal, 16)
//                        .padding(.bottom, 16)
//                    }
//                    .onChange(of: selectedLocationId) { id in
//                        if let id = id {
//                            withAnimation {
//                                print("スクロール")
//                                scrollProxy.scrollTo(id, anchor: .center)
//                            }
//                        }
//                    }
//                }
//            }
//            .onChange(of: selectedLocationId) { newId in
//                if let newId = newId,
//                   let selectedLocation = viewModel.locations.first(where: { $0.id == newId }) {
//                    withAnimation {
//                        region.center = CLLocationCoordinate2D(latitude: selectedLocation.latitude,
//                                                                 longitude: selectedLocation.longitude)
//                    }
//                }
//            }
//        }
//        .overlay(
//            VStack{
//                HStack{
//                    Spacer()
//                    Button(action: {
//                        showAddLocation = true
//                    }) {
//                        Image(systemName: "plus")
//                            .font(.system(size: 30))
//                            .padding(18)
//                            .background(.black).opacity(0.8)
//                            .foregroundColor(Color.white)
//                            .clipShape(Circle())
//                    }
//                }.padding(.trailing)
//                Spacer()
//            }
//        )
//        .onAppear {
//            // 画面を開いた時に現在地を表示する
//            if let userLocation = locationManager.userLocation {
//                withAnimation {
//                    region.center = userLocation.coordinate
//                }
//            }
//            viewModel.fetchLocations()
//        }
//        .fullScreenCover(isPresented: $showAddLocation) {
//            AddLocationView(viewModel: viewModel)
//        }
//    }
//}
//
//
//
//struct MapPinView: View {
//    var imageName: String
//    var isSelected: Bool
//    
//    var body: some View {
//        VStack(spacing: -20) {
//            // 白い円とグラデーション枠を重ねる
//            ZStack {
//                Circle()
//                    .fill(Color.white)
//                    .frame(width: isSelected ? 185 : 100, height: isSelected ? 185 : 100)
//                Circle()
//                    .stroke(
//                        LinearGradient(
//                            gradient: Gradient(colors: [Color.blue, Color.purple]),
//                            startPoint: .top,
//                            endPoint: .bottom
//                        ),
//                        lineWidth: 5
//                    )
//                    .frame(width: isSelected ? 185 : 100, height: isSelected ? 185 : 100)
//                ZStack {
//                    AsyncImage(url: URL(string: imageName ?? "")) { image in
//                        image
//                            .resizable()
//                            .scaledToFill()
//                            .frame(width: isSelected ? 170 : 85, height: isSelected ? 170 : 85)
//                            .clipShape(Circle())
//                    } placeholder: {
//                        Circle()
//                            .frame(width: isSelected ? 170 : 85, height: isSelected ? 170 : 85)
//                            .shimmer(true)
//                            .clipShape(Circle())
//                    }
//                }
//            }
//            .zIndex(1)
//            // 下に生やす三角形（ポインター）
//            Triangle()
//                .fill(
//                    LinearGradient(
//                        gradient: Gradient(colors: [Color.blue, Color.purple]),
//                        startPoint: .top,
//                        endPoint: .bottom
//                    )
//                )
//                .frame(width: isSelected ? 10 : 60, height: isSelected ? 10 : 40)
//        }
//    }
//}
//
//struct Triangle: Shape {
//    func path(in rect: CGRect) -> Path {
//        var path = Path()
//        // 下辺を頂点に、上辺を底辺にする
//        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))   // 三角形の頂点を下に
//        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // 左上
//        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // 右上
//        path.closeSubpath()
//        return path
//    }
//}
//struct MapPinView_Previews: PreviewProvider {
//    static var previews: some View {
////        MapPinView(imageName: "testImage", isSelected: false)
//        MapView()
////        AddLocationView(viewModel: LocationViewModel())
////        MapPinView()
//        //    AddressInputView()
////        AddressConfirmationView(prefecture: "東京都", streetAddress: "新宿区北新宿", buildingName: "")
//    }
//}
