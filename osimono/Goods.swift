//
//  Goods.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

struct Goods: Identifiable, Codable {
    var id: String
    var userId: String
    var name: String
    var imageUrl: String
    var purchaseDate: String
    var price: Int
    var purchasePlace: String
    var category: String
    var oshi: String
    var memo: String
    var status: String  // "所持中" / "予約済み" / "譲渡済み"
    var favorite: Int   // 1〜5の星評価
}


import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import PhotosUI
import ShimmerEffect

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
    
    var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    var body: some View {
        ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                    ForEach(goods) { item in
                        NavigationLink(destination: GoodsDetailView(goods: item)) {
                            ZStack(alignment: .bottomLeading) {
                                AsyncImage(url: URL(string: item.imageUrl)) { image in
                                    image
//                                    Image("\(item.name)")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                                }
                                placeholder: {
                                    Rectangle()
                                        .foregroundColor(.gray)
                                        .frame(width: UIScreen.main.bounds.width / 3 - 2, height: UIScreen.main.bounds.width / 3 - 2)
                                        .shimmer(true)
                                }
                                Text(item.name)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.7)) // 背景を黒にして視認性UP
                                    .clipShape(RoundedRectangle(cornerRadius: 5)) // 角丸の背景
                                    .offset(x: 5, y: -10) // 左下に寄せる
                            }
                            .cornerRadius(10)
                        }
                    }
                }
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
                name: "推し活\(index + 1)",
                imageUrl: url,
                purchaseDate: "2025-03-20",
                price: (index + 1) * 1000,
                purchasePlace: "公式ストア",
                category: "アクリル",
                oshi: "Aくん",
                memo: "テストデータ",
                status: "所持中",
                favorite: (index % 5) + 1
            )
        }
        
        self.goods = testGoods
    }
    /// ✅ Realtime Database からデータを取得
    func fetchGoods() {
        guard let userId = userId else { return }
        
        let ref = Database.database().reference().child("goods").child(userId)
        ref.observeSingleEvent(of: .value) { snapshot in
            var newGoods: [Goods] = []
            for child in snapshot.children {
                if let snapshot = child as? DataSnapshot,
                   let value = snapshot.value as? [String: Any],
                   let id = value["id"] as? String {
                    let good = try? JSONDecoder().decode(Goods.self, from: JSONSerialization.data(withJSONObject: value))
                    if let good = good {
                        newGoods.append(good)
                    }
                }
            }
            self.goods = newGoods
        }
    }
}

struct GoodsDetailView: View {
    let goods: Goods
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
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
            VStack(spacing: 16) {
                AsyncImage(url: URL(string: goods.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    case .success(let image):
                          image
//                        Image("\(goods.name)")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    case .failure(_):
                        Image(systemName: "photo")
//                        Image("\(goods.name)")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.gray)
                    @unknown default:
                        EmptyView()
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack{
                        Text("タイトル")
                            .bold()
                        Spacer()
                        Text(goods.name)
                    }
                    .padding(.horizontal)
                    Divider()
                    HStack{
                        Text("購入・撮影場所")
                            .bold()
                        Spacer()
                        Text("\(goods.purchasePlace)")
                    }
                    .padding(.horizontal)
                    Divider()
                    HStack{
                        Text("カテゴリ")
                            .bold()
                        Spacer()
                        Text("\(goods.category)")
                    }
                    .padding(.horizontal)
                    Divider()
                    HStack{
                        Text("価格")
                            .bold()
                        Spacer()
                        Text("\(goods.price)")
                    }
                    .padding(.horizontal)
                    Divider()
                    HStack{
                        Text("推し")
                            .bold()
                        Spacer()
                        Text("\(goods.oshi)")
                    }
                    .padding(.horizontal)
                    Divider()
                    HStack{
                        Text("メモ")
                            .bold()
                        Spacer()
                        Text("\(goods.memo)")
                    }
                    .padding(.horizontal)
                }.font(.system(size: 18))
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


struct GoodsFormView: View {
    @State private var newGoodsName = ""
    @State private var newPrice = ""
    @State private var newPurchasePlace = ""
    @State private var newCategory = ""
    @State private var newOshi = ""
    @State private var newMemo = ""
    @State private var newStatus = "所持中"
    @State private var newFavorite = 3
    @State private var selectedImage: UIImage?
    @State private var uploadedImageUrl: String?
    @State private var isShowingImagePicker = false
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
                Text("登録する")
                    .font(.system(size: 20))
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }.padding(.horizontal)
            VStack {
                Button(action: {
                    isShowingImagePicker = true
                }) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(10)
                            .frame(width: 120, height: 120)
                    } else {
                        ZStack{
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.black)
                            RoundedRectangle(cornerRadius: 10, style: .continuous).foregroundColor(.black).opacity(0.3)
                                .frame(width: 120, height: 100)
                            Image(systemName: "camera.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                        }
                    }
                }
            }
            
            VStack {
                HStack{
                    Text("タイトル")
                    Spacer()
                    TextField("例: アクリルスタンド", text: $newGoodsName)
                        .multilineTextAlignment(.trailing)
                }.padding(.horizontal)
                Divider()
                HStack {
                    Text("価格")
                    Spacer()
                    TextField("例: 3500", text: $newPrice)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }.padding(.horizontal)
                Divider()
                HStack {
                    Text("購入場所")
                    Spacer()
                    TextField("例: 公式ストア", text: $newPurchasePlace)
                        .multilineTextAlignment(.trailing)
                }.padding(.horizontal)
                Divider()
                HStack {
                    Text("カテゴリ")
                    Spacer()
                    TextField("例: フィギュア", text: $newCategory)
                        .multilineTextAlignment(.trailing)
                }.padding(.horizontal)
                Divider()
                HStack{
                    Text("推し")
                    Spacer()
                    TextField("例: Aくん", text: $newOshi)
                        .multilineTextAlignment(.trailing)
                }.padding(.horizontal)
                Divider()
                HStack{
                    Text("ステータス")
                    Spacer()
                    Picker("状態", selection: $newStatus) {
                        Text("所持中").tag("所持中")
                        Text("予約済み").tag("予約済み")
                        Text("譲渡済み").tag("譲渡済み")
                    }
                }.padding(.horizontal)
                Divider()
                HStack{
                    Text("メモ")
                    Spacer()
                    TextField("メモ", text: $newMemo).multilineTextAlignment(.trailing)
                }.padding(.horizontal)
            }
            .font(.system(size: 18))
            
            Spacer()
            Button("登録する") {
                self.presentationMode.wrappedValue.dismiss()
                uploadImageAndSaveGoods()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10).padding()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $selectedImage, onImagePicked: { image in
                self.selectedImage = image  // ✅ 選択した画像を保存
            })
        }
    }
    
    /// ✅ Firebase Realtime Database に保存
    func saveGoodsToDatabase(imageUrl: String?) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let ref = Database.database().reference().child("goods").child(userId)
        let newGoodsID = ref.childByAutoId().key ?? UUID().uuidString
        let newGoods = Goods(
            id: newGoodsID,
            userId: userId,
            name: newGoodsName,
            imageUrl: imageUrl ?? "",
            purchaseDate: Date().formatted(),
            price: Int(newPrice) ?? 0,
            purchasePlace: newPurchasePlace,
            category: newCategory,
            oshi: newOshi,
            memo: newMemo,
            status: newStatus,
            favorite: newFavorite
        )
        
        do {
            let goodsDict = try JSONEncoder().encode(newGoods)
            ref.child(newGoodsID).setValue(try JSONSerialization.jsonObject(with: goodsDict)) { error, _ in
                if let error = error {
                    print("データ追加エラー: \(error.localizedDescription)")
                }
            }
        } catch {
            print("データ保存エラー: \(error.localizedDescription)")
        }
    }
    
    /// ✅ 画像を Firebase Storage にアップロード → URL を取得 → Realtime Database に保存
    func uploadImageAndSaveGoods() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        if let image = selectedImage {
            let storageRef = Storage.storage().reference()
            let imageID = UUID().uuidString
            let imageRef = storageRef.child("goods/\(userId)/\(imageID).jpg")
            
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            imageRef.putData(imageData, metadata: metadata) { _, error in
                if let error = error {
                    print("アップロードエラー: \(error.localizedDescription)")
                    return
                }
                imageRef.downloadURL { url, error in
                    if let error = error {
                        print("画像URL取得エラー: \(error.localizedDescription)")
                        return
                    }
                    saveGoodsToDatabase(imageUrl: url?.absoluteString)
                }
            }
        } else {
            saveGoodsToDatabase(imageUrl: nil)  // 画像なしでデータを保存
        }
    }
}


#Preview {
//    GoodsDetailView(goods: Goods(
//        id: "dummy-id",
//        userId: "dummy-user",
//        name: "推し活1",
//        imageUrl: "https://via.placeholder.com/300x300.png?text=Sample",
//        purchaseDate: "2025-03-20",
//        price: 3500,
//        purchasePlace: "公式ストア",
//        category: "アクリル",
//        oshi: "Aくん",
//        memo: "これはサンプルのメモです",
//        status: "所持中",
//        favorite: 4
//    ))
    //    GoodsListView(addFlag: .constant(false))
        ContentView()
    //    GoodsFormView(onSubmit: { _ in })
}
