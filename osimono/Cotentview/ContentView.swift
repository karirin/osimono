//
//  ContentView.swift
//  osimono
//
//  Created by Apple on 2025/03/20.
//

import Foundation
import Firebase
import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseDatabase
import PhotosUI
import Shimmer
import ShimmerEffect

struct ContentView: View {
    @State private var image: UIImage? = nil
    @State private var imageUrl: URL? = nil
    @State private var isShowingImagePicker = false
    @State private var isShowingForm = false
    @State private var addFlag = false
    @State private var editFlag = false
    @ObservedObject var authManager = AuthManager()
    @State var backgroundImageUrl: URL?
    @State private var editType: UploadImageType? = nil
    @State private var currentEditType: UploadImageType? = nil
    @State private var isLoading = true
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme
    @State private var userProfile = UserProfile(id: "", username: "推し活ユーザー", favoriteOshi: "")
    @State private var selectedOshi: Oshi? = nil
    @State private var oshiList: [Oshi] = []
    @State private var showAddOshiForm = false
    
    // テーマカラーの定義 - アイドル/推し活向けに明るく元気なカラースキーム
//    let primaryColor = Color("#FF4B8A") // 明るいピンク
//    let accentColor = Color("#8A4FFF") // 紫系
//    let backgroundColor = Color("#FCFAFF") // 明るい背景色
//    let cardColor = Color("#FFFFFF") // カード背景色
//    let textColor = Color("#333333") // テキスト色
    let primaryColor = Color(.systemPink) // 明るいピンク
    let accentColor = Color(.purple) // 紫系
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.black) // カード背景色
    let textColor = Color(.black) // テキスト色
    @State private var isProfileImageEnlarged = false
    @State private var isEditingUsername = false
    @State private var editingUsername = ""
    @State private var editingFavoriteOshi = ""
    @State private var saveTimer: Timer? = nil
    @State private var refreshTrigger = false
    
    // プロフィールセクションの高さ
    var profileSectionHeight: CGFloat {
        isSmallDevice() ? 230 : 280
    }

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: -60) {
                    // プロフィールセクション
                    profileSection
                    // メインコンテンツ
                    TabView(selection: $selectedTab) {
                        OshiCollectionView(addFlag: $addFlag, oshiId: selectedOshi?.id ?? "default", refreshTrigger: refreshTrigger)
                            .tag(0)
                        
                        TimelineView(oshiId: selectedOshi?.id ?? "default")
                            .tag(1)
                        
                        CategoriesView()
                            .tag(2)
                        
                        SettingsView()
                            .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: selectedTab)
                }
            }
            .overlay(
                VStack(spacing: -5) {
                    Spacer()
                    HStack {
                        Spacer()
                        oshiSelector
                        Button(action: {
                            withAnimation(.spring()) {
                                editFlag.toggle()
                                isEditingUsername.toggle()
                                generateHapticFeedback()
                            }
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 22, weight: .medium))
                                .padding(15)
                                .background(
                                    Circle()
                                        .fill(accentColor)
                                        .shadow(color: accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                                )
                                .foregroundColor(.white)
                        }
                        .padding(.trailing)
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                addFlag = true
                            }
                            generateHapticFeedback()
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .medium))
                                .padding(18)
                                .background(
                                    Circle()
                                        .fill(primaryColor)
                                        .shadow(color: primaryColor.opacity(0.3), radius: 5, x: 0, y: 3)
                                )
                                .foregroundColor(.white)
                        }
                        .padding()
                    }
                }.padding(.trailing,10)
            )
            // プロフィール画像が拡大表示されている場合のオーバーレイを修正
            .overlay(
                ZStack {
                    if isProfileImageEnlarged, let oshi = selectedOshi, let imageUrlString = oshi.imageUrl, let imageUrl = URL(string: imageUrlString) {
                        Color.black.opacity(0.9)
                            .edgesIgnoringSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    isProfileImageEnlarged = false
                                }
                            }
                    
                        VStack {
                            AsyncImage(url: imageUrl) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: isiPhone12Or13() ? 260 : isSmallDevice() ? 250 : 300)
                                        .clipShape(Circle())
                                default:
                                    Circle().foregroundColor(.white)
                                        .frame(height: isiPhone12Or13() ? 260 : isSmallDevice() ? 250 : 300)
                                        .shimmering()
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    isProfileImageEnlarged = false
                                }
                            }) {
                                Text("閉じる")
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(primaryColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.top, 30)
                        }
                    }
                }
                .animation(.easeInOut, value: isProfileImageEnlarged)
            )
        }
        .accentColor(primaryColor)
        .onAppear {
            loadAllData()
            fetchOshiList()
        }
        .onChange(of: selectedOshi?.id) { newOshi in
            // 選択中の推しが変わったとき、投稿を再取得するためにリフレッシュトリガーを変更する
            if newOshi != nil {
                // refreshTriggerの値を反転させることで変更を通知
                refreshTrigger.toggle()
            }
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $image, onImagePicked: { pickedImage in
                self.image = pickedImage
                uploadOshiImageToFirebase(pickedImage)
            })
        }
        .sheet(item: $currentEditType) { type in
            ImagePicker(
                image: $image,
                onImagePicked: { pickedImage in
                    self.image = pickedImage
                    uploadOshiImageToFirebase(pickedImage, type: type)
                }
            )
        }
        .sheet(isPresented: $showAddOshiForm) {
            AddOshiView()
        }
        .sheet(item: $currentEditType) { type in
            ImagePicker(
                image: $image,
                onImagePicked: { pickedImage in
                    self.image = pickedImage
                    uploadImageToFirebase(pickedImage, type: type)
                    fetchUserImageURL(type: .profile) { url in
                        self.imageUrl = url
                    }
                    fetchUserImageURL(type: .background) { url in
                        self.backgroundImageUrl = url
                    }
                }
            )
        }
    }
    
    // 背景編集オーバーレイ
    var editBackgroundOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        currentEditType = .background
                        generateHapticFeedback()
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
    
    // プロフィールセクション - 推し活ユーザー向け
    var profileSection: some View {
        ZStack(alignment: .top) {
            // 背景画像 - 選択中の推しの背景画像に変更
            if isLoading {
                // ローディング状態の背景（既存コード）
                Rectangle()
                    .frame(height: profileSectionHeight)
                    .frame(maxWidth: .infinity)
                    .foregroundColor(Color.gray.opacity(0.1))
                    .shimmering(active: true)
                    .edgesIgnoringSafeArea(.all)
            } else {
                if let oshi = selectedOshi, let backgroundUrl = oshi.backgroundImageUrl, let url = URL(string: backgroundUrl) {
                    // 選択中の推しの背景画像を表示
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: profileSectionHeight)
                                .overlay(
                                    editFlag ? editBackgroundOverlay : nil
                                )
                                .clipped()
                                .edgesIgnoringSafeArea(.all)
                        default:
                            Rectangle()
                                .frame(height: profileSectionHeight)
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Color.gray.opacity(0.1))
                                .shimmering(active: true)
                                .edgesIgnoringSafeArea(.all)
                        }
                    }
                } else {
                    // 背景画像がない場合（既存コード）
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [primaryColor.opacity(0.7), accentColor.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: profileSectionHeight)
                        .edgesIgnoringSafeArea(.all)
                        if editFlag {
                            editBackgroundOverlay
                        }
                    }
                }
            }
            
            // プロフィール情報とアバター
            VStack(spacing: 8) {
                // プロフィール画像 - 選択中の推しのプロフィール画像に変更
                ZStack {
                    if let oshi = selectedOshi, let imageUrlString = oshi.imageUrl, let imageUrl = URL(string: imageUrlString) {
                        AsyncImage(url: imageUrl) { phase in
                            switch phase {
                            case .success(let image):
                                ZStack {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 3)
                                        )
                                        .shadow(color: Color.black.opacity(0.2), radius: 5)
                                        .onTapGesture {
                                            withAnimation(.spring()) {
                                                isProfileImageEnlarged = true
                                            }
                                            generateHapticFeedback()
                                        }
                                    
                                    if editFlag {
                                        Button(action: {
                                            currentEditType = .profile
                                            generateHapticFeedback()
                                        }) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.5))
                                                    .frame(width: 100, height: 100)
                                                
                                                Image(systemName: "camera.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 30))
                                            }
                                        }
                                    }
                                }
                            case .failure(_):
                                profilePlaceholder
                            case .empty:
                                profilePlaceholder
                            @unknown default:
                                profilePlaceholder
                            }
                        }
                    } else {
                        Button(action: {
                            if let oshi = selectedOshi {
                                isShowingImagePicker = true
                            } else {
                                // 推しが選択されていない場合は、推し追加フォームを表示
                                showAddOshiForm = true
                            }
                        }) {
                            profilePlaceholder
                        }
                    }
                }
                .padding(.bottom, 4)
                
                // ユーザー名と詳細 - 推し情報表示
                VStack(spacing: 4) {
                    if isEditingUsername {
                        // 編集モード: テキストフィールドを表示
                        HStack {
                            TextField("推しの名前", text: $editingUsername)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .multilineTextAlignment(.center)
                                .frame(width: 200)
                                .onAppear{
                                    startEditing()
                                }
                                .onChange(of: editingUsername) { newValue in
                                    saveOshiProfile()
                                }
                        }
                    } else {
                        // 表示モード: 通常のテキスト表示
                        Text(selectedOshi?.name ?? "推しを選択してください")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 12)
            }
            .offset(y: 30)
        }
        .onAppear{
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                print("oshi.backgroundImageUrl      :\(selectedOshi)")
            }
        }
    }
    
    
    func saveSelectedOshiId(_ oshiId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedOshiId": oshiId]) { error, _ in
            if let error = error {
                print("推しID保存エラー: \(error.localizedDescription)")
            }
        }
    }
    
    func loadSelectedOshi() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            if let selectedOshiId = value["selectedOshiId"] as? String {
                // 選択中の推しIDが存在する場合、oshiListから該当する推しを検索して設定
                if let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                    self.selectedOshi = oshi
                }
            }
        }
    }
    
    func startEditing() {
        if let oshi = selectedOshi {
            editingUsername = oshi.name
        }
    }

    // プロフィール保存関数 - ContentViewに追加
    func saveUserProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let updatedUsername = editingUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !updatedUsername.isEmpty {
            // Firebaseにデータを保存
            let dbRef = Database.database().reference().child("users").child(userID)
            let updates: [String: Any] = [
                "username": updatedUsername,
                "favoriteOshi": editingFavoriteOshi
            ]
            
            dbRef.updateChildValues(updates) { error, _ in
                if error == nil {
                    // ローカルのuserProfileを更新
                    userProfile.username = updatedUsername
                    userProfile.favoriteOshi = editingFavoriteOshi
                }
            }
        }
        
        // 編集モードを終了
//        isEditingUsername = false
    }
    
    // カスタムタブビュー - 推し活に特化したタブ
    var customTabView: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    withAnimation {
                        selectedTab = index
                    }
                    generateHapticFeedback()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tabIcon(for: index))
                            .font(.system(size: 20))
                        
                        Text(tabTitle(for: index))
                            .font(.system(size: 12))
                    }
                    .foregroundColor(selectedTab == index ? primaryColor : Color.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
//        .background(cardColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
//        .padding(.top, isSmallDevice() ?   -20 : -50)
    }
    
    // プロフィール画像プレースホルダー
    var profilePlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5)
            
            .shimmering(active: true)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
            
            if isShowingImagePicker == false {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .background(Circle().fill(primaryColor))
                    .offset(x: 32, y: 32)
            }
        }
    }
    
    var oshiSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                // 新規追加ボタン
                Button(action: {
                    // 推し追加画面を表示
                    showAddOshiForm = true
                }) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .padding(12)
                            .background(Circle().fill(primaryColor))
                            .foregroundColor(.black)
                        
                        Text("推し追加")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 70)
                }
                
                // 推しリスト
                ForEach(oshiList) { oshi in
                    Button(action: {
                        selectedOshi = oshi
                        generateHapticFeedback()
                        saveSelectedOshiId(oshi.id)
                    }) {
                        VStack {
                            if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedOshi?.id == oshi.id ? primaryColor : Color.clear, lineWidth: 3)
                                            )
                                    default:
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Text(String(oshi.name.prefix(1)))
                                                    .font(.system(size: 24, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text(String(oshi.name.prefix(1)))
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(selectedOshi?.id == oshi.id ? primaryColor : Color.clear, lineWidth: 3)
                                    )
                            }
                            
                            Text(oshi.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 70)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    func saveOshiProfile() {
        guard let userID = Auth.auth().currentUser?.uid, let oshi = selectedOshi else { return }
        
        let updatedName = editingUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        if !updatedName.isEmpty {
            // Firebaseにデータを保存
            let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
            let updates: [String: Any] = [
                "name": updatedName
            ]
            
            dbRef.updateChildValues(updates) { error, _ in
                if error == nil {
                    // ローカルのselectedOshiを更新
                    var updatedOshi = self.selectedOshi!
                    updatedOshi.name = updatedName
                    self.selectedOshi = updatedOshi
                    
                    // oshiListも更新
                    if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                        self.oshiList[index].name = updatedName
                    }
                }
            }
        }
    }
    
    func fetchOshiList() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("oshis").child(userId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            var newOshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot {
                    if let value = childSnapshot.value as? [String: Any] {
                        let id = childSnapshot.key
                        let name = value["name"] as? String ?? "名前なし"
                        let imageUrl = value["imageUrl"] as? String
                        let backgroundImageUrl = value["backgroundImageUrl"] as? String
                        let memo = value["memo"] as? String
                        let createdAt = value["createdAt"] as? TimeInterval
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl, // ここで追加
                            memo: memo,
                            createdAt: createdAt
                        )
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.loadSelectedOshi()
                // 初期表示用に最初の推しを選択
                if let firstOshi = newOshis.first, self.selectedOshi == nil {
                    self.selectedOshi = firstOshi
                }
            }
        }
    }
    
    // 推し用の画像アップロード
    func uploadOshiImageToFirebase(_ image: UIImage, type: UploadImageType = .profile) {
        guard let userID = Auth.auth().currentUser?.uid, let oshi = selectedOshi else {
            print("ユーザーがログインしていないか、推しが選択されていません")
            return
        }

        let storageRef = Storage.storage().reference()
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let imageRef = storageRef.child("oshis/\(userID)/\(oshi.id)/\(filename)")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // アップロード中の表示
        withAnimation {
            isLoading = true
        }

        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
            } else {
                print("画像をアップロードしました")
                
                // 画像URL取得
                imageRef.downloadURL { url, error in
                    if let url = url {
                        // DBにURLを保存
                        let dbRef = Database.database().reference().child("oshis").child(userID).child(oshi.id)
                        let updates: [String: Any] = type == .profile
                            ? ["imageUrl": url.absoluteString]
                            : ["backgroundImageUrl": url.absoluteString]
                        
                        dbRef.updateChildValues(updates) { error, _ in
                            if error == nil {
                                // ローカルのselectedOshiを更新
                                var updatedOshi = self.selectedOshi!
                                if type == .profile {
                                    updatedOshi.imageUrl = url.absoluteString
                                } else {
                                    updatedOshi.backgroundImageUrl = url.absoluteString
                                }
                                self.selectedOshi = updatedOshi
                                
                                // oshiListも更新
                                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                                    if type == .profile {
                                        self.oshiList[index].imageUrl = url.absoluteString
                                    } else {
                                        self.oshiList[index].backgroundImageUrl = url.absoluteString
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // アップロード完了後
            withAnimation {
                isLoading = false
            }
        }
    }
    
    // タブアイコン取得 - 推し活向けアイコン
    func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "square.grid.2x2.fill"
        case 1: return "heart.fill"
        case 2: return "tag.fill"
        case 3: return "gearshape.fill"
        default: return ""
        }
    }
    
    // タブタイトル取得 - 推し活向けタイトル
    func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "コレクション"
        case 1: return "推し活記録"
        case 2: return "カテゴリー"
        case 3: return "設定"
        default: return ""
        }
    }
    
    // 商品データの参照用プロパティ
    var oshiItems: [OshiItem] {
        []
    }
    
    // データ読み込み
    func loadAllData() {
        isLoading = true

        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        fetchUserImageURL(type: .profile) { url in
            self.imageUrl = url
            dispatchGroup.leave()
        }

        dispatchGroup.enter()
        fetchUserImageURL(type: .background) { url in
            self.backgroundImageUrl = url
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        fetchUserProfile { profile in
            if let profile = profile {
                self.userProfile = profile
            }
            dispatchGroup.leave()
        }

        dispatchGroup.notify(queue: .main) {
            withAnimation {
                self.isLoading = false
            }
        }
    }
    
    // ユーザープロフィール取得
    func fetchUserProfile(completion: @escaping (UserProfile?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        // Firebaseからユーザープロフィール情報を取得する処理
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                completion(nil)
                return
            }
            
            let profile = UserProfile(
                id: userID,
                username: value["username"] as? String,
                favoriteOshi: value["favoriteOshi"] as? String,
                profileImageUrl: value["profileImageUrl"] as? String,
                backgroundImageUrl: value["backgroundImageUrl"] as? String,
                bio: value["bio"] as? String
            )
            
            completion(profile)
        }
    }
    
    // 画像URL取得
    func fetchUserImageURL(type: UploadImageType, completion: @escaping (URL?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }

        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let storageRef = Storage.storage().reference().child("images/\(userID)/\(filename)")

        storageRef.downloadURL { url, error in
            completion(url)
        }
    }

    // プロフィール画像のURL取得
    func fetchUserImageURL(completion: @escaping (URL?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            completion(nil)
            return
        }

        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child("images/\(userID)/profile.jpg")

        imageRef.downloadURL { url, error in
            if let error = error {
                print("画像URL取得エラー: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(url)
            }
        }
    }

    // 画像アップロード
    func uploadImageToFirebase(_ image: UIImage, type: UploadImageType = .profile) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("ユーザーがログインしていません")
            return
        }

        let storageRef = Storage.storage().reference()
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let imageRef = storageRef.child("images/\(userID)/\(filename)")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        // アップロード中の表示
        withAnimation {
            isLoading = true
        }

        imageRef.putData(imageData, metadata: metadata) { _, error in
            if let error = error {
                print("アップロードエラー: \(error.localizedDescription)")
            } else {
                print("画像をアップロードしました")
                if type == .profile {
                    fetchUserImageURL(type: .profile) { url in
                        self.imageUrl = url
                    }
                } else {
                    fetchUserImageURL(type: .background) { url in
                        self.backgroundImageUrl = url
                    }
                }
            }
            
            // アップロード完了後
            withAnimation {
                isLoading = false
            }
        }
    }
    
    // 小型デバイス判定（iPhone SE など）
    func isSmallDevice() -> Bool {
        return UIScreen.main.bounds.height < 700
    }
    
    func isiPhone12Or13() -> Bool {
        let screenSize = UIScreen.main.bounds.size
        let width = min(screenSize.width, screenSize.height)
        let height = max(screenSize.width, screenSize.height)
        // iPhone 12,13 の画面サイズは約幅390ポイント、高さ844ポイント
        return abs(width - 390) < 1 && abs(height - 844) < 1
    }
    
    // 触覚フィードバック生成
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
      
#Preview {
//    ContentView()
    TopView()
}
