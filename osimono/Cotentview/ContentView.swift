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
    
    // プロフィールセクションの高さ
    var profileSectionHeight: CGFloat {
        isSmallDevice() ? 230 : 280
    }

    var body: some View {
//        NavigationView {
            ZStack {
                
                VStack(spacing: 0) {
                    // プロフィールセクション
                    profileSection
                    
                    // タブビュー
                    customTabView
                    
                    // メインコンテンツ
                    TabView(selection: $selectedTab) {
                        OshiCollectionView(addFlag: $addFlag)
                            .tag(0)
                        
                        FavoritesView()
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
                        Button(action: {
                            withAnimation(.spring()) {
                                editFlag.toggle()
                            }
                            generateHapticFeedback()
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
//                        .offset(y: editFlag ? -60 : 0)
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
                                .font(.system(size: 25, weight: .medium))
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
//            .navigationBarTitle("推しコレクション", displayMode: .inline)
//            .navigationBarItems(trailing:
//                Button(action: {
//                    // 通知ボタン
//                }) {
//                    Image(systemName: "bell")
//                        .font(.system(size: 16, weight: .medium))
//                        .foregroundColor(textColor)
//                }
//            )
//        }
        .accentColor(primaryColor)
        .onAppear {
            loadAllData()
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: $image, onImagePicked: { pickedImage in
                self.image = pickedImage
                uploadImageToFirebase(pickedImage)
            })
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
    
    // プロフィールセクション - 推し活ユーザー向け
    var profileSection: some View {
        ZStack(alignment: .top) {
            // 背景画像
            if isLoading {
                // ローディング状態の背景
                Rectangle()
                    .frame(height: profileSectionHeight)
                    .frame(maxWidth: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .foregroundColor(Color.gray.opacity(0.1))
            } else {
                if let backgroundImageUrl = backgroundImageUrl {
                    AsyncImage(url: backgroundImageUrl) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .overlay(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, primaryColor.opacity(0.6)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: profileSectionHeight)
                                .overlay(
                                    editFlag ? editBackgroundOverlay : nil
                                )
                                .clipped()
                                .edgesIgnoringSafeArea(.all)
                        default:
                            Rectangle()
                                .frame(height: profileSectionHeight)
                                .foregroundColor(Color.gray.opacity(0.1))
                                .edgesIgnoringSafeArea(.all)
                        }
                    }
                } else {
                    // 背景画像がない場合
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [primaryColor.opacity(0.7), accentColor.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
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
                // プロフィール画像
                ZStack {
                    if let imageUrl = imageUrl {
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
                            isShowingImagePicker = true
                        }) {
                            profilePlaceholder
                        }
                    }
                }
                .padding(.bottom, 4)
                
                // ユーザー名と詳細 - 推し情報表示
                VStack(spacing: 4) {
                    Text(userProfile.username ?? "推し活ユーザー")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let favoriteOshi = userProfile.favoriteOshi, !favoriteOshi.isEmpty {
                        Text("推し: \(favoriteOshi)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Text("コレクション: \(oshiItems.count)点")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.bottom, 12)
            }
            .offset(y: 30)
        }
//        .frame(height: profileSectionHeight + 60)
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
        .padding(.top, isSmallDevice() ? -20 : -50)
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
