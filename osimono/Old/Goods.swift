//
//  Goods.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

struct Goods: Identifiable, Codable {
    var id: String
    var userId: String
    var imageUrl: String?
    var date: String?
    var price: Int?
    var purchasePlace: String?
    var category: String?
    var memo: String?
    var status: String?
    var favorite: Int?
    var createdAt: Int?
    var title: String?
}

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import PhotosUI
import ShimmerEffect
import MapKit

struct GoodsListView: View {
    @State private var goods: [Goods] = []
    @State private var selectedImage: UIImage?
    @State private var isShowingForm = false
    @State private var newGoodsName = ""
    @State private var newPrice = ""
    @State private var newPurchasePlace = ""
    @State private var newCategory = ""
    @State private var newOshi = ""
    @State private var newMemo = ""
    @State private var newStatus = "所持中"
    @State private var newFavorite = 3
    @Binding var addFlag: Bool
    @State var isLoading = false
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        VStack{
//            if isLoading {
//                VStack{
//                    Spacer()
//                }.frame(width: .infinity,height: .infinity)
//            } else if goods.isEmpty {
//                VStack(spacing: 10){
//                    Spacer()
//                    Image("エンプティステート")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 150)
//                        .opacity(0.2)
//                    Text("投稿がありません")
//                        .foregroundColor(.gray)
//                        .font(.system(size: 20))
//                    Spacer()
//                    Spacer()
//                }.frame(width: .infinity,height: .infinity )
//            } else {
//                ScrollView {
//                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
//                        ForEach(goods) { item in
//                            NavigationLink(destination: GoodsDetailView(goods: item)) {
//                                ZStack(alignment: .bottomLeading) {
//                                    if let imageUrl = item.imageUrl,
//                                       !imageUrl.isEmpty,
//                                       let url = URL(string: imageUrl) {
//                                        AsyncImage(url: url) { phase in
//                                            if let image = phase.image {
//                                                image
//                                                    .resizable()
//                                                    .scaledToFill()
//                                                    .frame(width: UIScreen.main.bounds.width / 3 - 2,
//                                                           height: UIScreen.main.bounds.width / 3 - 2)
//                                            } else {
//                                                Rectangle()
//                                                    .foregroundColor(.gray)
//                                                    .frame(width: UIScreen.main.bounds.width / 3 - 2,
//                                                           height: UIScreen.main.bounds.width / 3 - 2)
//                                                    .shimmer(true)
//                                            }
//                                        }
//                                    } else {
//                                        ZStack{
//                                            Rectangle()
//                                                .foregroundColor(.gray).opacity(0.2)
//                                                .frame(width: UIScreen.main.bounds.width / 3 - 2,
//                                                       height: UIScreen.main.bounds.width / 3 - 2)
//                                            Image(systemName: "photo")
//                                                .font(.system(size: 24))
//                                                .foregroundStyle(Color.black)
//                                        }
//                                    }
//                                    if let name = item.title, !name.isEmpty {
//                                        Text(name)
//                                            .foregroundColor(.white)
//                                            .padding(4)
//                                            .background(Color.black.opacity(0.7))
//                                            .clipShape(RoundedRectangle(cornerRadius: 5))
//                                            .offset(x: 5, y: -10)
//                                    }
//                                }
//                                .cornerRadius(10)
//                            }
//                        }
//                    }
//                    
//                }
//            }
        }
        .onAppear {
//            addTestData()
            fetchGoods()
        }
        .onChange(of: addFlag) { newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                fetchGoods()
            }
        }
        .fullScreenCover(isPresented: $addFlag) {
            GoodsFormView()
        }
    }
    
    func addTestData() {
        let testImages = [
            "https://via.placeholder.com/120/FF0000/FFFFFF?text=推し活1",
            "https://via.placeholder.com/120/00FF00/FFFFFF?text=推し活2",
            "https://via.placeholder.com/120/0000FF/FFFFFF?text=推し活3",
            "https://via.placeholder.com/120/FFFF00/FFFFFF?text=推し活4",
            "https://via.placeholder.com/120/FF00FF/FFFFFF?text=推し活5",
            "https://via.placeholder.com/120/00FFFF/FFFFFF?text=推し活6",
            "https://via.placeholder.com/120/AAAAAA/FFFFFF?text=推し活7"
        ]
        
        let testGoods = testImages.enumerated().map { index, url in
            Goods(
                id: UUID().uuidString,
                userId: userId ?? "testUser",
                imageUrl: url,
                date: "2025-03-20",
                price: (index + 1) * 1000,
                purchasePlace: "公式ストア",
                category: "アクリル",
                memo: "テストデータ",
                status: "所持中",
                favorite: (index % 5) + 1
            )
        }
        
        self.goods = testGoods
    }

    func fetchGoods() {
        guard let userId = userId else { return }
        self.isLoading = true
        let ref = Database.database().reference().child("goods").child(userId)
        ref.observeSingleEvent(of: .value) { snapshot in
            var newGoods: [Goods] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot {
                    
                    if let value = childSnapshot.value as? [String: Any] {
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: value)
                            let good = try JSONDecoder().decode(Goods.self, from: jsonData)
                            newGoods.append(good)
                        } catch {
                            print("デコードエラー: \(error.localizedDescription)")
                            print("エラーが発生したデータ: \(value)")
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.goods = newGoods
                self.isLoading = false
                print("fetchGoods 完了", self.goods)
            }
        }
    }
}

struct GoodsDetailView: View {
    let goods: Goods
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            HStack{
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.black)
                }
                Spacer()
                Text("詳細")
                    .font(.system(size: 20))
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }.padding(.horizontal)
            
            ScrollView {
                Group {
                    VStack(spacing: 16) {
                        if let imageUrl = goods.imageUrl,
                           let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, minHeight: 300)
//                                    .shimmer(true)
                            }
                        } else {
                            ZStack{
                                Rectangle()
                                    .foregroundColor(.gray).opacity(0.2)
                                    .frame(maxWidth: .infinity, minHeight: 300)
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.black)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            displayField(title: "タイトル", value: goods.title)
                            //                        displayField(title: "名前", value: goods.name)
                            displayField(title: "価格", value: goods.price != nil ? "\(goods.price!) 円" : nil)
                            displayField(title: "購入・撮影場所", value: goods.purchasePlace)
                            displayField(title: "カテゴリ", value: goods.category)
                            //                        displayField(title: "推し", value: goods.oshi)
                            displayField(title: "メモ", value: goods.memo)
                            displayField(title: "ステータス", value: goods.status)
                            displayField(title: "お気に入り度", value: goods.favorite != nil ? "\(goods.favorite!)" : nil)
                            //                        displayField(title: "作成日時", value: goods.createdAt != nil ? "\(goods.createdAt!)" : nil)
                            //                        displayField(title: "説明", value: goods.description)
                            //                        displayField(title: "開始日", value: goods.startDate)
                            //                        displayField(title: "終了日", value: goods.endDate)
                            //                        displayField(title: "プライバシー", value: goods.privacy)
                            
                        }
                        .padding(.horizontal)
                        .font(.system(size: 18))
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
        }
    }
    
    // 🔥 共通化した表示フィールド関数
    @ViewBuilder
    func displayField(title: String, value: String?) -> some View {
        if let value = value, !value.isEmpty {
            VStack(alignment: .leading) {
                HStack {
                    Text(title)
                        .bold()
                    Spacer()
                    Text(value)
                }
                Divider()
            }
            .padding(.vertical, 4)
        }
    }
}

struct GoodsFormView: View {
    // 既存の@State変数はそのまま
    @State private var eventTitle = ""
    @State private var newGoodsName = ""
    @State private var newPrice = ""
    @State private var newPurchasePlace = ""
    @State private var newCategory = ""
    @State private var newOshi = ""
    @State private var newMemo = ""
    @State private var privacy = "公開"
    @State private var selectedImage: UIImage?
    @State private var isShowingImagePicker = false
    @Environment(\.presentationMode) var presentationMode
    @State private var newFavorite = 3
    @State private var newDescription = ""
    @State private var newStartDate = Date()
    @State private var newEndDate = Date().addingTimeInterval(3600)
    @State private var newStatus = "所持中"
    
    @State private var prefecture: String = "都道府県"
    @State private var streetAddress: String = ""
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
    )
    @StateObject private var locationManager = LocationManager()
    
    // アニメーション関連
    @State private var isImageHovering = false
    @State private var showMapPreview = false
    
    private let prefectures = [
        "都道府県", "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]
    
    var currentAddress: String {
        var address = ""
        if prefecture != "都道府県" {
            address += prefecture + " "
        }
        address += streetAddress
        return address.trimmingCharacters(in: .whitespaces)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // モダンなヘッダー
            HStack {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                Spacer()
                Text("登録")
                    .font(.system(size: 18, weight: .bold)).padding(.trailing, -25)
                Spacer()
                Button(action: {
                    saveEvent()
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("保存")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            
            ScrollView {
                VStack(spacing: 24) {
                    // モダンな画像アップロード領域
                    VStack {
                        Button(action: {
                            isShowingImagePicker = true
                        }) {
                            ZStack {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 220)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                        .overlay(
                                            VStack {
                                                Spacer()
                                                HStack {
                                                    Spacer()
                                                    Button(action: {
                                                        isShowingImagePicker = true
                                                    }) {
                                                        HStack {
                                                            Image(systemName: "photo")
                                                                .font(.system(size: 14))
                                                            Text("画像を変更する")
                                                                .font(.system(size: 14, weight: .medium))
                                                        }
                                                        .padding(.vertical, 8)
                                                        .padding(.horizontal, 14)
                                                        .background(Color.black.opacity(0.6))
                                                        .foregroundColor(.white)
                                                        .cornerRadius(20)
                                                    }
                                                    .padding(16)
                                                }
                                            }
                                        )
                                } else {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.gray.opacity(0.08))
                                        .frame(height: 220)
                                        .frame(maxWidth: .infinity)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                .scaleEffect(isImageHovering ? 1.02 : 1.0)
                                        )
                                        .overlay(
                                            VStack(spacing: 12) {
                                                Image(systemName: "photo.on.rectangle.angled")
                                                    .font(.system(size: 40))
                                                    .foregroundStyle(Color.gray.opacity(0.8))
                                                
                                                Text("タップして画像を追加")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(Color.gray.opacity(0.8))
                                            }
                                        )
                                        .onHover { hovering in
                                            withAnimation(.spring()) {
                                                isImageHovering = hovering
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // フォーム入力（改良版）
                    VStack(alignment: .leading, spacing: 24) {
                        // タイトル
                        FormField(title: "タイトル", placeholder: "推しのライブ", text: $eventTitle)
                        
                        // メモ
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メモ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                            
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $newMemo)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(height: 120)
                                    .scrollContentBackground(.hidden)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(UIColor.systemGray6))
                                    )
                                
                                if newMemo.isEmpty {
                                    Text("推しのパフォーマンスは圧巻で、特にアンコールの瞬間は心が震えた")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                        .foregroundColor(Color.gray.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 価格
                        FormField(
                            title: "価格",
                            placeholder: "5000",
                            text: $newPrice,
                            keyboardType: .numberPad,
                            leadingIcon: "yen.circle.fill"
                        )
                        
                        // 住所入力
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("住所入力")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black.opacity(0.8))
                                
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
                                    .foregroundColor(.blue)
                                }
                            }
                            
                            VStack(spacing: 12) {
                                // 都道府県選択
                                Menu {
                                    ForEach(prefectures, id: \.self) { pref in
                                        Button(pref) {
                                            prefecture = pref
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
                                    .frame(maxWidth: .infinity)
                                    .background(Color(UIColor.systemGray6))
                                    .cornerRadius(12)
                                }
                                
                                // 市区町村・番地入力
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 12)
                                    
                                    TextField("市区町村・番地", text: $streetAddress)
                                        .padding(.vertical, 16)
                                }
                                .background(Color(UIColor.systemGray6))
                                .cornerRadius(12)
                                
                                // マッププレビュー（位置情報がある場合のみ表示）
//                                if let coordinate = coordinate, showMapPreview {
//                                    Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem1(coordinate: coordinate)]) { item in
//                                        MapMarker(coordinate: item.coordinate, tint: .red)
//                                    }
//                                    .frame(height: 150)
//                                    .cornerRadius(12)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 12)
//                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//                                    )
//                                    .onAppear {
//                                        // マップの表示サイズを調整
//                                        region.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
//                                        region.center = coordinate
//                                    }
//                                }
                            }
                        }
                        .padding(.horizontal)
                        .onChange(of: currentAddress) { _ in
                            geocodeAddress()
                            // 住所が十分に入力されたらマップを表示
                            showMapPreview = !currentAddress.isEmpty && prefecture != "都道府県"
                        }
                        
                        // カテゴリ
                        FormField(title: "カテゴリ", placeholder: "ライブ・グッズなど", text: $newCategory)
                        
                        // お気に入り度
                        VStack(alignment: .leading, spacing: 8) {
                            Text("お気に入り度")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                            
                            // アニメーション付きの星評価システム
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= newFavorite ? "star.fill" : "star")
                                        .font(.system(size: 36))
                                        .foregroundColor(star <= newFavorite ? .yellow : .gray.opacity(0.3))
                                        .scaleEffect(star == newFavorite ? 1.1 : 1.0)
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                newFavorite = star
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                        }
                        .padding(.horizontal)
                        
                        // ステータス選択（オプション）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ステータス")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black.opacity(0.8))
                            
                            HStack(spacing: 12) {
                                ForEach(["所持中", "予約済み", "譲渡済み"], id: \.self) { status in
                                    StatusButton(
                                        title: status,
                                        isSelected: newStatus == status,
                                        action: { newStatus = status }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage, onImagePicked: { image in
                self.selectedImage = image
            })
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    // 既存のメソッドはそのまま保持
    func geocodeAddress() {
        // 既存のコード
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(currentAddress) { placemarks, error in
            if let placemark = placemarks?.first, let location = placemark.location {
                DispatchQueue.main.async {
                    coordinate = location.coordinate
                    let offsetLatitude = location.coordinate.latitude + 0.00025
                    region.center = CLLocationCoordinate2D(latitude: offsetLatitude,
                                                         longitude: location.coordinate.longitude)
                }
            } else {
                print("住所のジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
            }
        }
    }
    
    func useCurrentLocation() {
        // 既存のコード
        if let location = locationManager.userLocation {
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
                        geocodeAddress() // 新しい住所でマップ更新
                    }
                } else {
                    print("逆ジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
                }
            }
        } else {
            print("現在地が取得できません")
        }
    }
    
    func saveEvent() {
        // 既存のコード
        guard let userId = Auth.auth().currentUser?.uid else {
            print("saveEvent1")
            return
        }

        // Upload image if available
        if let image = selectedImage {
            print("saveEvent2")
            uploadImage(userId: userId) { imageUrl in
                saveEventToDatabase(userId: userId, imageUrl: imageUrl)
            }
        } else {
            print("saveEvent3")
            saveEventToDatabase(userId: userId, imageUrl: nil)
        }
    }

    func uploadImage(userId: String, completion: @escaping (String?) -> Void) {
        // 既存のコード
        guard let image = selectedImage else {
            completion(nil)
            return
        }

        let storageRef = Storage.storage().reference()
        let imageID = UUID().uuidString
        let imageRef = storageRef.child("goods/\(userId)/\(imageID).jpg")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
                completion(nil)
                return
            }

            imageRef.downloadURL { url, error in
                if let error = error {
                    print("画像URL取得エラー: \(error.localizedDescription)")
                    completion(nil)
                    return
                }

                completion(url?.absoluteString)
            }
        }
    }

    func saveEventToDatabase(userId: String, imageUrl: String?) {
        // 既存のコード
        let ref = Database.database().reference().child("goods").child(userId)
        let newEventID = ref.childByAutoId().key ?? UUID().uuidString

        let event = [
            "id": newEventID,
            "userId": userId,
            "title": eventTitle,
            "purchasePlace": currentAddress,
            "category": newCategory,
            "imageUrl": imageUrl ?? "",
            "memo": newMemo,
            "status": newStatus,
            "favorite": newFavorite,
            "createdAt": ServerValue.timestamp()
        ] as [String : Any]

        ref.child(newEventID).setValue(event) { error, _ in
            if let error = error {
                print("イベント保存エラー: \(error.localizedDescription)")
            } else {
                print("イベントを保存しました: \(newEventID)")
            }
        }
    }
}

// カスタム入力フィールドコンポーネント
struct FormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var leadingIcon: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black.opacity(0.8))
            
            HStack {
                if let iconName = leadingIcon {
                    Image(systemName: iconName)
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                }
                
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .padding(.vertical, 16)
                    .padding(.leading, leadingIcon == nil ? 16 : 4)
                    .padding(.trailing, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemGray6))
            )
        }
        .padding(.horizontal)
    }
}

// ステータスボタンコンポーネント
struct StatusButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .foregroundColor(isSelected ? .white : .black)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// マップアノテーション用の構造体
struct MapAnnotationItem1: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// モダンなマップピン表示コンポーネント
struct AddressMapPinView1: View {
    let image: UIImage?
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
            } else {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.red)
            }
            
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .offset(y: -5)
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
    }
}

//    struct GoodsFormView: View {
//        @State private var eventTitle = ""
//        @State private var newGoodsName = ""
//        @State private var newPrice = ""
//        @State private var newPurchasePlace = ""
//        @State private var newCategory = ""
//        @State private var newOshi = ""
//        @State private var newMemo = ""
//        @State private var privacy = "公開"
//        @State private var selectedImage: UIImage?
//        @State private var isShowingImagePicker = false
//        @Environment(\.presentationMode) var presentationMode
//        @State private var newFavorite = 3
//        @State private var newDescription = ""
//        @State private var newStartDate = Date()
//        @State private var newEndDate = Date().addingTimeInterval(3600)
//        @State private var newStatus = "所持中"
//        
//        @State private var prefecture: String = "都道府県"
//        @State private var streetAddress: String = ""
//        @State private var coordinate: CLLocationCoordinate2D?
//        @State private var region = MKCoordinateRegion(
//            center: CLLocationCoordinate2D(latitude: 35.0, longitude: 139.0),
//            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
//        )
//        @StateObject private var locationManager = LocationManager()
//
//        private let prefectures = [
//            "都道府県", "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
//            "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
//            "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
//            "岐阜県", "静岡県", "愛知県", "三重県",
//            "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
//            "鳥取県", "島根県", "岡山県", "広島県", "山口県",
//            "徳島県", "香川県", "愛媛県", "高知県",
//            "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
//        ]
//        
//        var currentAddress: String {
//            var address = ""
//            if prefecture != "都道府県" {
//                address += prefecture + " "
//            }
//            address += streetAddress
//            return address.trimmingCharacters(in: .whitespaces)
//        }
//        
//        var body: some View {
//            VStack(spacing: 0) {
//                HStack {
//                    Button(action: {
//                        self.presentationMode.wrappedValue.dismiss()
//                    }) {
//                        Image(systemName: "xmark")
//                            .foregroundStyle(.black)
//                    }
//                    Spacer()
//                    Text("登録")
//                        .font(.system(size: 18, weight: .medium))
//                    Spacer()
//                    Button("保存") {
//                        saveEvent()
//                        self.presentationMode.wrappedValue.dismiss()
//                    }
//                    .foregroundColor(.gray)
//                }
//                .padding(.horizontal)
//                .padding(.vertical, 12)
//                
//                ScrollView {
//                    VStack(spacing: 24) {
//                        // 画像選択
//                        Button(action: {
//                            isShowingImagePicker = true
//                        }) {
//                            ZStack{
//                            if let image = selectedImage {
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(height: 180)
//                                    .frame(maxWidth: .infinity)
//                                    .clipped()
//                            } else {
//                                Rectangle()
//                                    .fill(Color.gray.opacity(0.2))
//                                    .frame(height: 180)
//                                    .frame(maxWidth: .infinity)
//                                Image(systemName: "photo")
//                                    .font(.system(size: 30))
//                                    .foregroundStyle(.black)
//                                // Calendar and people illustration would be here
//                                // Placeholder text for the demo
//                                VStack {
//                                    Spacer()
//                                    HStack {
//                                        Spacer()
//                                        Button(action: {
//                                            isShowingImagePicker = true
//                                        }) {
//                                            Text("画像を変更する")
//                                                .font(.system(size: 14))
//                                                .padding(.vertical, 6)
//                                                .padding(.horizontal, 10)
//                                                .background(Color.black.opacity(0.6))
//                                                .foregroundColor(.white)
//                                                .cornerRadius(20)
//                                        }
//                                        .padding(8)
//                                    }
//                                }
//                            }
//                            }
//                        }
//                        // フォーム入力
//                        VStack(alignment: .leading, spacing: 20) {
//                            Group {
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("タイトル")
//                                            .font(.system(size: 16))
//                                        Spacer()
//                                    }
//                                    TextField("推しのライブ", text: $eventTitle)
//                                        .padding()
//                                        .background(Color(UIColor.systemGray6))
//                                        .cornerRadius(8)
//                                }
//                                
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("メモ")
//                                            .font(.system(size: 16))
//                                        Spacer()
//                                    }
//                                    ZStack(alignment: .topLeading) {
//                                        
//                                        TextEditor(text: $newMemo)
//                                            .padding(.horizontal, 12)
//                                            .frame(height: 100)
//                                            .scrollContentBackground(.hidden)
//                                            .background(Color(UIColor.systemGray6))
//                                            .cornerRadius(8)
//                                        if newMemo.isEmpty {
//                                            Text("推しのパフォーマンスは圧巻で、特にアンコールの瞬間は心が震えた")
//                                                .padding(.horizontal, 16)
//                                                .padding(.vertical, 16)
//                                                .foregroundColor(Color.gray.opacity(0.7))
//                                        }
//                                    }
//                                }
//                                
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("価格")
//                                            .font(.system(size: 16))
//                                        Spacer()
//                                    }
//                                    TextField("5000", text: $newPrice)
//                                        .keyboardType(.numberPad)
//                                        .padding()
//                                        .background(Color(UIColor.systemGray6))
//                                        .cornerRadius(8)
//                                }
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("住所入力")
//                                            .font(.system(size: 16))
//                                        Spacer()
//                                        Button("現在地を使用") {
//                                            useCurrentLocation()
//                                        }
//                                    }
//                                    HStack {
//                                        Picker("都道府県", selection: $prefecture) {
//                                            ForEach(prefectures, id: \.self) { pref in
//                                                Text(pref)
//                                            }
//                                        }
//    //                                    .frame(maxWidth: 150)
//                                        
//                                        TextField("市区町村・番地", text: $streetAddress)
//                                            .padding(10)
//                                            .background(Color(UIColor.systemGray6))
//                                            .cornerRadius(8)
//                                    }
//                                    // 入力された住所に基づくマップ表示
//    //                                if let coordinate = coordinate {
//    //                                    Map(coordinateRegion: $region, annotationItems: [MapAnnotationItem(coordinate: coordinate)]) { item in
//    //                                        MapAnnotation(coordinate: item.coordinate, anchorPoint: CGPoint(x: 0.5, y: 1.0)) {
//    //                                            AddressMapPinView(image: selectedImage, isSelected: false)
//    //                                        }
//    //                                    }
//    //                                    .frame(height: 150)
//    //                                } else {
//    //                                    Text("位置情報は設定されていません")
//    //                                        .foregroundColor(.gray)
//    //                                        .frame(height: 100)
//    //                                }
//                                }
//                                .onChange(of: currentAddress) { _ in
//                                    geocodeAddress()
//                                }
//                                .padding(.horizontal)
//                                
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("カテゴリ")
//                                            .font(.system(size: 16))
//                                        Spacer()
//                                    }
//                                    TextField("カテゴリ", text: $newCategory)
//                                        .padding()
//                                        .background(Color(UIColor.systemGray6))
//                                        .cornerRadius(8)
//                                }
//    //                            Picker("ステータス", selection: $newStatus) {
//    //                                Text("所持中").tag("所持中")
//    //                                Text("予約済み").tag("予約済み")
//    //                                Text("譲渡済み").tag("譲渡済み")
//    //                            }
//    //
//                                VStack(alignment: .leading, spacing: 8) {
//                                    HStack {
//                                        Text("お気に入り度")
//                                            .font(.system(size: 16))
//                                        Spacer()
//                                    }
//                                    HStack{
//                                        ForEach(1...5, id: \.self) { star in
//                                            Image(systemName: star <= newFavorite ? "star.fill" : "star")
//                                                .foregroundColor(.yellow)
//                                                .font(.system(size: 48))
//                                                .onTapGesture {
//                                                    newFavorite = star
//                                                }
//                                        }
//                                    }.padding(.leading,10)
//                                }
//                            }
//                            .padding(.horizontal)
//                        }
//                    }
//                }
//            }
//            .sheet(isPresented: $isShowingImagePicker) {
//                ImagePicker(image: $selectedImage, onImagePicked: { image in
//                    self.selectedImage = image
//                })
//            }
//        }
//        
//        func geocodeAddress() {
//            let geocoder = CLGeocoder()
//            geocoder.geocodeAddressString(currentAddress) { placemarks, error in
//                if let placemark = placemarks?.first, let location = placemark.location {
//                    DispatchQueue.main.async {
//                        coordinate = location.coordinate
//                        let offsetLatitude = location.coordinate.latitude + 0.00025
//                        region.center = CLLocationCoordinate2D(latitude: offsetLatitude,
//                                                               longitude: location.coordinate.longitude)
//                    }
//                } else {
//                    print("住所のジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
//                }
//            }
//        }
//
//        // 現在地を取得して住所入力欄に反映する関数
//        func useCurrentLocation() {
//            if let location = locationManager.userLocation {
//                let geocoder = CLGeocoder()
//                geocoder.reverseGeocodeLocation(location) { placemarks, error in
//                    if let placemark = placemarks?.first {
//                        DispatchQueue.main.async {
//                            prefecture = placemark.administrativeArea ?? prefecture
//                            if let locality = placemark.locality,
//                               let thoroughfare = placemark.thoroughfare,
//                               let subThoroughfare = placemark.subThoroughfare {
//                                streetAddress = "\(locality) \(thoroughfare) \(subThoroughfare)"
//                            } else if let name = placemark.name {
//                                streetAddress = name
//                            }
//                            geocodeAddress() // 新しい住所でマップ更新
//                        }
//                    } else {
//                        print("逆ジオコーディング失敗: \(error?.localizedDescription ?? "不明なエラー")")
//                    }
//                }
//            } else {
//                print("現在地が取得できません")
//            }
//        }
//        
//        func saveEvent() {
//            guard let userId = Auth.auth().currentUser?.uid else {
//                print("saveEvent1")
//                return
//            }
//
//            // Upload image if available
//            if let image = selectedImage {
//                print("saveEvent2")
//                uploadImage(userId: userId) { imageUrl in
//                    saveEventToDatabase(userId: userId, imageUrl: imageUrl)
//                }
//            } else {
//                print("saveEvent3")
//                saveEventToDatabase(userId: userId, imageUrl: nil)
//            }
//        }
//
//        func uploadImage(userId: String, completion: @escaping (String?) -> Void) {
//            guard let image = selectedImage else {
//                completion(nil)
//                return
//            }
//
//            let storageRef = Storage.storage().reference()
//            let imageID = UUID().uuidString
//            let imageRef = storageRef.child("goods/\(userId)/\(imageID).jpg")
//
//            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
//                completion(nil)
//                return
//            }
//
//            let metadata = StorageMetadata()
//            metadata.contentType = "image/jpeg"
//
//            imageRef.putData(imageData, metadata: metadata) { _, error in
//                if let error = error {
//                    print("アップロードエラー: \(error.localizedDescription)")
//                    completion(nil)
//                    return
//                }
//
//                imageRef.downloadURL { url, error in
//                    if let error = error {
//                        print("画像URL取得エラー: \(error.localizedDescription)")
//                        completion(nil)
//                        return
//                    }
//
//                    completion(url?.absoluteString)
//                }
//            }
//        }
//
//        func saveEventToDatabase(userId: String, imageUrl: String?) {
//            let ref = Database.database().reference().child("goods").child(userId)
//            let newEventID = ref.childByAutoId().key ?? UUID().uuidString
//
//            // Format dates to strings for display
//            let dateFormatter = DateFormatter()
//            dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
//
//    //        id: newGoodsID,
//    //        userId: userId,
//    //        imageUrl: imageUrl,
//    //        price: Int(newPrice),
//    //        purchasePlace: newPurchasePlace,
//    //        category: newCategory,
//    //        memo: newMemo,
//    //        status: newStatus,
//    //        favorite: newFavorite,
//    //        title: eventTitle
//            let event = [
//                "id": newEventID,
//                "userId": userId,
//                "title": eventTitle,
//                "purchasePlace": currentAddress,
//                "category": newCategory,
//                "imageUrl": imageUrl ?? "",
//                "memo": newMemo,
//                "status": newStatus,
//                "favorite": newFavorite,
//                "createdAt": ServerValue.timestamp()
//            ] as [String : Any]
//
//            ref.child(newEventID).setValue(event) { error, _ in
//                if let error = error {
//                    print("イベント保存エラー: \(error.localizedDescription)")
//                } else {
//                    print("イベントを保存しました: \(newEventID)")
//                }
//            }
//        }
//        /// ✅ データベースに保存
//        func saveGoodsToDatabase(imageUrl: String?) {
//            guard let userId = Auth.auth().currentUser?.uid else { return }
//            
//            let ref = Database.database().reference().child("goods").child(userId)
//            let newGoodsID = ref.childByAutoId().key ?? UUID().uuidString
//            
//            let newGoods = Goods(
//                id: newGoodsID,
//                userId: userId,
//                imageUrl: imageUrl,
//                price: Int(newPrice),
//                purchasePlace: newPurchasePlace,
//                category: newCategory,
//                memo: newMemo,
//                status: newStatus,
//                favorite: newFavorite,
//                title: eventTitle
//            )
//            
//            do {
//                let data = try JSONEncoder().encode(newGoods)
//                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
//                    ref.child(newGoodsID).setValue(json)
//                }
//            } catch {
//                print("保存エラー: \(error)")
//            }
//        }
//    }

//struct GoodsFormView: View {
//    @State private var eventTitle = ""
//    @State private var startDate = Date()
//    @State private var endDate = Date().addingTimeInterval(3600) // Default 1 hour later
//    @State private var eventDescription = ""
//    
//    @State private var newGoodsName = ""
//    @State private var newPrice = ""
//    @State private var newPurchasePlace = ""
//    @State private var newCategory = ""
//    @State private var newOshi = ""
//    @State private var newMemo = ""
//    @State private var privacy = "公開"
//    @State private var selectedImage: UIImage?
//    @State private var isShowingImagePicker = false
//    @Environment(\.presentationMode) var presentationMode
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            // Header
//            HStack {
//                Button(action: {
//                    self.presentationMode.wrappedValue.dismiss()
//                }) {
//                    Image(systemName: "xmark")
//                        .foregroundStyle(.black)
//                }
//                Spacer()
//                Text("イベント作成")
//                    .font(.system(size: 18, weight: .medium))
//                Spacer()
//                Button("作成") {
//                    saveEvent()
//                    self.presentationMode.wrappedValue.dismiss()
//                }
//                .foregroundColor(.gray)
//            }
//            .padding(.horizontal)
//            .padding(.vertical, 12)
//            
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
//                                Rectangle()
//                                    .fill(Color.yellow)
//                                    .frame(height: 180)
//                                    .frame(maxWidth: .infinity)
//                                
//                                // Calendar and people illustration would be here
//                                // Placeholder text for the demo
//                                VStack {
//                                    Spacer()
//                                    HStack {
//                                        Spacer()
//                                        Button(action: {
//                                            isShowingImagePicker = true
//                                        }) {
//                                            Text("画像を変更する")
//                                                .font(.system(size: 14))
//                                                .padding(.vertical, 6)
//                                                .padding(.horizontal, 10)
//                                                .background(Color.black.opacity(0.6))
//                                                .foregroundColor(.white)
//                                                .cornerRadius(20)
//                                        }
//                                        .padding(8)
//                                    }
//                                }
//                            }
//                        }
//                    }
//                    
//                    // Title Field
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("タイトル")
//                                .font(.system(size: 16))
//                            Spacer()
//                            Text("\(newGoodsName.count) / 48")
//                                .font(.system(size: 14))
//                                .foregroundColor(.gray)
//                        }
//                        
//                        TextField("ライブ", text: $newGoodsName)
//                            .padding()
//                            .background(Color(UIColor.systemGray6))
//                            .cornerRadius(8)
//                    }
//                    .padding(.horizontal)
//                    
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("価格")
//                                .font(.system(size: 16))
//                            Spacer()
//                            Text("\(newPrice.count) / 48")
//                                .font(.system(size: 14))
//                                .foregroundColor(.gray)
//                        }
//                        
//                        TextField("5000", text: $newPrice)
//                            .padding()
//                            .background(Color(UIColor.systemGray6))
//                            .cornerRadius(8)
//                    }
//                    .padding(.horizontal)
//                    
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("カテゴリ")
//                                .font(.system(size: 16))
//                            Spacer()
//                            Text("\(newCategory.count) / 48")
//                                .font(.system(size: 14))
//                                .foregroundColor(.gray)
//                        }
//                        
//                        TextField("ライブ写真", text: $eventTitle)
//                            .padding()
//                            .background(Color(UIColor.systemGray6))
//                            .cornerRadius(8)
//                    }
//                    .padding(.horizontal)
//                    
//                    // Description
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Text("メモ")
//                                .font(.system(size: 16))
//                            Spacer()
//                            Text("\(eventDescription.count) / 394")
//                                .font(.system(size: 14))
//                                .foregroundColor(.gray)
//                        }
//                        
//                        ZStack(alignment: .topLeading) {
//                            if eventDescription.isEmpty {
//                                Text("どんな推しに関する投稿か簡単なテキストで説明しましょう")
//                                    .foregroundColor(.gray)
//                                    .padding(.horizontal, 8)
//                                    .padding(.vertical, 12)
//                            }
//                            
//                            TextEditor(text: $eventDescription)
//                                .padding(4)
//                                .frame(height: 100)
//                                .background(Color(UIColor.systemGray6))
//                                .opacity(eventDescription.isEmpty ? 0.25 : 1)
//                        }
//                        .background(Color(UIColor.systemGray6))
//                        .cornerRadius(8)
//                    }
//                    .padding(.horizontal)
//                    
//                    Spacer()
//                }
//                .padding(.top, 16)
//            }
//        }
//        .sheet(isPresented: $isShowingImagePicker) {
//            ImagePicker(image: $selectedImage, onImagePicked: { image in
//                self.selectedImage = image
//            })
//        }
//    }
//    
//    func saveEvent() {
//        guard let userId = Auth.auth().currentUser?.uid else {
//            print("saveEvent1")
//            return
//        }
//        
//        // Upload image if available
//        if let image = selectedImage {
//            print("saveEvent2")
//            uploadImage(userId: userId) { imageUrl in
//                saveEventToDatabase(userId: userId, imageUrl: imageUrl)
//            }
//        } else {
//            print("saveEvent3")
//            saveEventToDatabase(userId: userId, imageUrl: nil)
//        }
//    }
//    
//    func uploadImage(userId: String, completion: @escaping (String?) -> Void) {
//        guard let image = selectedImage else {
//            completion(nil)
//            return
//        }
//        
//        let storageRef = Storage.storage().reference()
//        let imageID = UUID().uuidString
//        let imageRef = storageRef.child("goods/\(userId)/\(imageID).jpg")
//        
//        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
//            completion(nil)
//            return
//        }
//        
//        let metadata = StorageMetadata()
//        metadata.contentType = "image/jpeg"
//        
//        imageRef.putData(imageData, metadata: metadata) { _, error in
//            if let error = error {
//                print("アップロードエラー: \(error.localizedDescription)")
//                completion(nil)
//                return
//            }
//            
//            imageRef.downloadURL { url, error in
//                if let error = error {
//                    print("画像URL取得エラー: \(error.localizedDescription)")
//                    completion(nil)
//                    return
//                }
//                
//                completion(url?.absoluteString)
//            }
//        }
//    }
//    
//    func saveEventToDatabase(userId: String, imageUrl: String?) {
//        let ref = Database.database().reference().child("goods").child(userId)
//        let newEventID = ref.childByAutoId().key ?? UUID().uuidString
//        
//        // Format dates to strings for display
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm"
//        
//        let event = [
//            "id": newEventID,
//            "userId": userId,
//            "title": eventTitle,
//            "imageUrl": imageUrl ?? "",
//            "startDate": dateFormatter.string(from: startDate),
//            "endDate": dateFormatter.string(from: endDate),
//            "description": eventDescription,
//            "privacy": privacy,
//            "createdAt": ServerValue.timestamp()
//        ] as [String : Any]
//        
//        ref.child(newEventID).setValue(event) { error, _ in
//            if let error = error {
//                print("イベント保存エラー: \(error.localizedDescription)")
//            } else {
//                print("イベントを保存しました: \(newEventID)")
//            }
//        }
//    }
//}

//struct GoodsFormView: View {
//    @State private var newGoodsName = ""
//    @State private var newPrice = ""
//    @State private var newPurchasePlace = ""
//    @State private var newCategory = ""
//    @State private var newOshi = ""
//    @State private var newMemo = ""
//    @State private var newStatus = "所持中"
//    @State private var newFavorite = 3
//    @State private var selectedImage: UIImage?
//    @State private var uploadedImageUrl: String?
//    @State private var isShowingImagePicker = false
//    @Environment(\.presentationMode) var presentationMode
//    
//    var body: some View {
//        VStack {
//            HStack{
//                Button(action: {
//                    self.presentationMode.wrappedValue.dismiss()
//                }) {
//                    Image(systemName: "chevron.left")
//                        .foregroundStyle(.black)
//                }
//                Spacer()
//                Text("登録する")
//                    .font(.system(size: 20))
//                Spacer()
//                Image(systemName: "chevron.left").opacity(0)
//            }.padding(.horizontal)
//            VStack {
//                Button(action: {
//                    isShowingImagePicker = true
//                }) {
//                    if let image = selectedImage {
//                        Image(uiImage: image)
//                            .resizable()
//                            .scaledToFit()
//                            .cornerRadius(10)
//                            .frame(width: 120, height: 120)
//                    } else {
//                        ZStack{
//                            Image(systemName: "photo")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 120, height: 120)
//                                .foregroundColor(.black)
//                            RoundedRectangle(cornerRadius: 10, style: .continuous).foregroundColor(.black).opacity(0.3)
//                                .frame(width: 120, height: 100)
//                            Image(systemName: "camera.fill")
//                                .resizable()
//                                .scaledToFit()
//                                .foregroundColor(.white)
//                                .frame(width: 40, height: 40)
//                        }
//                    }
//                }
//            }
//            
//            VStack {
//                HStack{
//                    Text("タイトル")
//                    Spacer()
//                    TextField("例: アクリルスタンド", text: $newGoodsName)
//                        .multilineTextAlignment(.trailing)
//                }.padding(.horizontal)
//                Divider()
//                HStack {
//                    Text("価格")
//                    Spacer()
//                    TextField("例: 3500", text: $newPrice)
//                        .keyboardType(.numberPad)
//                        .multilineTextAlignment(.trailing)
//                }.padding(.horizontal)
//                Divider()
//                HStack {
//                    Text("購入場所")
//                    Spacer()
//                    TextField("例: 公式ストア", text: $newPurchasePlace)
//                        .multilineTextAlignment(.trailing)
//                }.padding(.horizontal)
//                Divider()
//                HStack {
//                    Text("カテゴリ")
//                    Spacer()
//                    TextField("例: フィギュア", text: $newCategory)
//                        .multilineTextAlignment(.trailing)
//                }.padding(.horizontal)
//                Divider()
//                HStack{
//                    Text("推し")
//                    Spacer()
//                    TextField("例: Aくん", text: $newOshi)
//                        .multilineTextAlignment(.trailing)
//                }.padding(.horizontal)
//                Divider()
//                HStack{
//                    Text("ステータス")
//                    Spacer()
//                    Picker("状態", selection: $newStatus) {
//                        Text("所持中").tag("所持中")
//                        Text("予約済み").tag("予約済み")
//                        Text("譲渡済み").tag("譲渡済み")
//                    }
//                }.padding(.horizontal)
//                Divider()
//                HStack{
//                    Text("メモ")
//                    Spacer()
//                    TextField("メモ", text: $newMemo).multilineTextAlignment(.trailing)
//                }.padding(.horizontal)
//            }
//            .font(.system(size: 18))
//            
//            Spacer()
//            Button("登録する") {
//                self.presentationMode.wrappedValue.dismiss()
//                uploadImageAndSaveGoods()
//            }
//            .padding()
//            .frame(maxWidth: .infinity)
//            .background(Color.green)
//            .foregroundColor(.white)
//            .cornerRadius(10).padding()
//        }
//        .sheet(isPresented: $isShowingImagePicker) {
//            ImagePicker(image: $selectedImage, onImagePicked: { image in
//                self.selectedImage = image  // ✅ 選択した画像を保存
//            })
//        }
//    }
//    
//    /// ✅ Firebase Realtime Database に保存
//    func saveGoodsToDatabase(imageUrl: String?) {
//        guard let userId = Auth.auth().currentUser?.uid else { return }
//        
//        let ref = Database.database().reference().child("goods").child(userId)
//        let newGoodsID = ref.childByAutoId().key ?? UUID().uuidString
//        let newGoods = Goods(
//            id: newGoodsID,
//            userId: userId,
//            name: newGoodsName,
//            imageUrl: imageUrl ?? "",
//            date: Date().formatted(),
//            price: Int(newPrice) ?? 0,
//            purchasePlace: newPurchasePlace,
//            category: newCategory,
//            oshi: newOshi,
//            memo: newMemo,
//            status: newStatus,
//            favorite: newFavorite
//        )
//        
//        do {
//            let goodsDict = try JSONEncoder().encode(newGoods)
//            ref.child(newGoodsID).setValue(try JSONSerialization.jsonObject(with: goodsDict)) { error, _ in
//                if let error = error {
//                    print("データ追加エラー: \(error.localizedDescription)")
//                }
//            }
//        } catch {
//            print("データ保存エラー: \(error.localizedDescription)")
//        }
//    }
//    
//    /// ✅ 画像を Firebase Storage にアップロード → URL を取得 → Realtime Database に保存
//    func uploadImageAndSaveGoods() {
//        guard let userId = Auth.auth().currentUser?.uid else { return }
//        
//        if let image = selectedImage {
//            let storageRef = Storage.storage().reference()
//            let imageID = UUID().uuidString
//            let imageRef = storageRef.child("goods/\(userId)/\(imageID).jpg")
//            
//            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
//            
//            let metadata = StorageMetadata()
//            metadata.contentType = "image/jpeg"
//            
//            imageRef.putData(imageData, metadata: metadata) { _, error in
//                if let error = error {
//                    print("アップロードエラー: \(error.localizedDescription)")
//                    return
//                }
//                imageRef.downloadURL { url, error in
//                    if let error = error {
//                        print("画像URL取得エラー: \(error.localizedDescription)")
//                        return
//                    }
//                    saveGoodsToDatabase(imageUrl: url?.absoluteString)
//                }
//            }
//        } else {
//            saveGoodsToDatabase(imageUrl: nil)  // 画像なしでデータを保存
//        }
//    }
//}


#Preview {
//    GoodsDetailView(goods: Goods(
//        id: "dummy-id",
//        userId: "dummy-user",
//        imageUrl: "https://via.placeholder.com/300x300.png?text=Sample",
//        price: 3500,
//        purchasePlace: "公式ストア",
//        category: "アクリル",
//        memo: "これはサンプルのメモです",
//        status: "所持中",
//        favorite: 4
//    ))
    //    GoodsListView(addFlag: .constant(false))
//        ContentView()
        GoodsFormView()
}
