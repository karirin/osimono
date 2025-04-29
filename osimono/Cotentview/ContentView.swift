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
    @State private var showingOshiAlert = false
    @State private var showingAnniversaryAlert = false
    @State private var anniversaryDays = 0
    
    // テーマカラーの定義 - アイドル/推し活向けに明るく元気なカラースキーム
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
    @State private var isOshiChange = false
    @State private var isShowingOshiSelector = false
    @State private var showChangeOshiButton = false
    @State private var isShowingEditOshiView = false
    
    // プロフィールセクションの高さ
    var profileSectionHeight: CGFloat {
        isSmallDevice() ? 280 : 280
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: -60) {
                    ProfileSection(
                        editFlag: $editFlag,
                        showAddOshiForm: $showAddOshiForm,
                        isEditingUsername: $isEditingUsername,
                        isShowingOshiSelector: $isShowingOshiSelector,
                        showChangeOshiButton: $showChangeOshiButton,
                        isOshiChange: $isOshiChange,
                        isShowingEditOshiView: $isShowingEditOshiView, onOshiUpdated: {
                            self.refreshTrigger.toggle()
                        }
                    )
                    
                    OshiCollectionView(addFlag: $addFlag, oshiId: selectedOshi?.id ?? "default", refreshTrigger: refreshTrigger, showingOshiAlert: $showingOshiAlert, editFlag: $editFlag,isEditingUsername: $isEditingUsername,showChangeOshiButton: $showChangeOshiButton, isShowingEditOshiView: $isShowingEditOshiView)
                }
            }
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
                                generateHapticFeedback()
                                if let oshi = selectedOshi {
                                    isShowingImagePicker = true
                                } else {
                                    showAddOshiForm = true
                                }
                            }) {
                                Text("登録")
                            }
                            
                            Button(action: {
                                generateHapticFeedback()
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
            fetchOshiList()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                checkOshiAnniversary()
            }
        }
        .overlay(
            ZStack {
                if isShowingOshiSelector {
                    oshiSelectorOverlay
                }
                if showingOshiAlert {
                    OshiAlertView(
                        title: "推しを登録しよう！",
                        message: "推しグッズやSNS投稿を記録する前に、まずは推しを登録してください。",
                        buttonText: "推しを登録する",
                        action: {
                            showAddOshiForm = true
                        },
                        isShowing: $showingOshiAlert
                    )
                    .transition(.opacity)
                }
                if showingAnniversaryAlert {
                    OshiAnniversaryView(
                        isShowing: $showingAnniversaryAlert,
                        days: anniversaryDays,
                        oshiName: selectedOshi?.name ?? "推し",
                        imageUrl: selectedOshi?.imageUrl
                    )
                    .transition(.opacity)
                }
            }
        )
        .onChange(of: selectedOshi?.id) { newOshi in
            // 選択中の推しが変わったとき、投稿を再取得するためにリフレッシュトリガーを変更する
            if newOshi != nil {
                // refreshTriggerの値を反転させることで変更を通知
                refreshTrigger.toggle()
            }
        }
        .onChange(of: isOshiChange) { newFlag in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                loadAllData()
            }
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
    
    var oshiSelectorOverlay: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShowingOshiSelector = false
                    }
                }
            
            VStack(spacing: 20) {
                // ヘッダー
                HStack {
                    Text("推しを選択")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring()) {
                            isShowingOshiSelector = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                // 推しリスト - グリッドレイアウト
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                    // 新規追加ボタン
                    Button(action: {
                        generateHapticFeedback()
                        showAddOshiForm = true
                        isShowingOshiSelector = false
                    }) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(primaryColor.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(primaryColor)
                            }
                            
                            Text("新規追加")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 推しリスト
                    ForEach(oshiList) { oshi in
                        Button(action: {
                            selectedOshi = oshi
                            saveSelectedOshiId(oshi.id)
                            generateHapticFeedback()
                            withAnimation(.spring()) {
                                isShowingOshiSelector = false
                                editFlag = false
                                isEditingUsername = false
                                showChangeOshiButton = false
                            }
                        }) {
                            VStack {
                                ZStack {
                                    // プロフィール画像またはプレースホルダー
                                    if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            default:
                                                Circle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text(String(oshi.name.prefix(1)))
                                                            .font(.system(size: 30, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        }
                                    } else {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(String(oshi.name.prefix(1)))
                                                    .font(.system(size: 30, weight: .bold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
                                    // 選択インジケーター
                                    if selectedOshi?.id == oshi.id {
                                        Circle()
                                            .stroke(primaryColor, lineWidth: 4)
                                            .frame(width: 85, height: 85)
                                    }
                                }
                                
                                Text(oshi.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
            )
            .padding()
        }
    }
    
    func checkOshiAnniversary() {
        guard let selectedOshi = selectedOshi,
              let createdAt = selectedOshi.createdAt else { return }
        
        // 登録日の日付を取得
        let creationDate = Date(timeIntervalSince1970: createdAt)
        let today = Date()
        
        // 経過日数を計算
        let days = Date.daysBetween(start: creationDate, end: today)
        
        // 10日ごとの節目かどうかをチェック
        if days > 0 && days % 10 == 0 {
            // UserDefaultsを使って、既に表示済みの記念日を管理
            let userDefaults = UserDefaults.standard
            let anniversaryKey = "oshi_anniversary_\(selectedOshi.id)_\(days)"
            
            // まだ表示していない場合にのみ表示
            if !userDefaults.bool(forKey: anniversaryKey) {
                // 表示フラグをセット
                userDefaults.set(true, forKey: anniversaryKey)
                
                // モーダル表示をトリガー
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.anniversaryDays = days
                    self.showingAnniversaryAlert = true
                }
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
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    var oshiSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                // 新規追加ボタン
                Button(action: {
                    generateHapticFeedback()
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
        
        // アップロード中の表示
        withAnimation {
            isLoading = true
        }
        
        let storageRef = Storage.storage().reference()
        let filename = type == .profile ? "profile.jpg" : "background.jpg"
        let imageRef = storageRef.child("oshis/\(userID)/\(oshi.id)/\(filename)")
        
        // プロフィール画像と背景画像で圧縮率を調整
        let compressionQuality: CGFloat = type == .profile ? 0.8 : 0.7
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else { return }
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
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
    
    // 触覚フィードバック生成
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

func isiPhone12Or13() -> Bool {
    let screenSize = UIScreen.main.bounds.size
    let width = min(screenSize.width, screenSize.height)
    let height = max(screenSize.width, screenSize.height)
    // iPhone 12,13 の画面サイズは約幅390ポイント、高さ844ポイント
    return abs(width - 390) < 1 && abs(height - 844) < 1
}

#Preview {
    //    ContentView()
    TopView()
}
