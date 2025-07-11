//
//  ProfileSection.swift
//  osimono
//
//  Created by Apple on 2025/04/19.
//

import SwiftUI
import Firebase
import FirebaseAuth
import Shimmer
import FirebaseStorage

struct ProfileSection: View {
    @State private var isLoading = true
    var profileSectionHeight: CGFloat {
        isSmallDevice() ? 230 : 230
    }
    let primaryColor = Color(.systemPink) // 明るいピンク
    let accentColor = Color(.purple) // 紫系
    let backgroundColor = Color(.white) // 明るい背景色
    let cardColor = Color(.black) // カード背景色
    let textColor = Color(.black) // テキスト色
    @Binding var editFlag: Bool
    @Binding var oshiChange: Bool
    @State private var currentEditType: UploadImageType? = nil
    @State private var isProfileImageEnlarged = false
    @State private var isShowingImagePicker = false
    @Binding var showAddOshiForm: Bool
    @Binding var isEditingUsername: Bool
    @Binding var isShowingOshiSelector: Bool
    @Binding var showChangeOshiButton: Bool
    @Binding var isOshiChange: Bool
    @State private var editingUsername = ""
    @State private var oshiList: [Oshi] = []
    @State var backgroundImageUrl: URL?
    @State private var imageUrl: URL? = nil
    @State private var userProfile = UserProfile(id: "", username: "推し活ユーザー", favoriteOshi: "")
    @State private var image: UIImage? = nil
    @Binding var isShowingEditOshiView: Bool
    var onOshiUpdated: (() -> Void)? = nil
    @State private var hasLoadedInitialData = false
    @Binding var firstOshiFlag: Bool
    @Binding var showingOshiAlert: Bool
    var oshiId: String
    @State private var unreadMessageCount: Int = 0
    @State private var hasNewMessages: Bool = false
    
    @State private var unreadPostCount: Int = 0
    @State private var hasUnreadPosts: Bool = false
    
    @State private var isAnimatingBadge: Bool = false
    @State private var badgeBounce: Bool = false
    @State private var showChatView: Bool = false
    
    @State private var imageCache: [String: URL] = [:]
    @State private var needsFullReload = false
    
    @State private var viewModel: OshiViewModel?
    
    // NavigationLink用の状態変数を追加
    @Binding var navigateToAddOshiForm: Bool
    @Binding var navigateToEditOshi: Bool
    @State private var navigateToChatView = false
    
    init(editFlag: Binding<Bool>, oshiChange: Binding<Bool>, showAddOshiForm: Binding<Bool>, isEditingUsername: Binding<Bool>, isShowingOshiSelector: Binding<Bool>, showChangeOshiButton: Binding<Bool>, isOshiChange: Binding<Bool>, isShowingEditOshiView: Binding<Bool>, onOshiUpdated: (() -> Void)? = nil, firstOshiFlag: Binding<Bool>, showingOshiAlert: Binding<Bool>, oshiId: String, navigateToAddOshiForm: Binding<Bool>, navigateToEditOshi: Binding<Bool>) {
        self._editFlag = editFlag
        self._oshiChange = oshiChange
        self._showAddOshiForm = showAddOshiForm
        self._isEditingUsername = isEditingUsername
        self._isShowingOshiSelector = isShowingOshiSelector
        self._showChangeOshiButton = showChangeOshiButton
        self._isOshiChange = isOshiChange
        self._isShowingEditOshiView = isShowingEditOshiView
        self.onOshiUpdated = onOshiUpdated
        self._firstOshiFlag = firstOshiFlag
        self._showingOshiAlert = showingOshiAlert
        self.oshiId = oshiId
        self._navigateToAddOshiForm = navigateToAddOshiForm
        self._navigateToEditOshi = navigateToEditOshi
        
        // 初期Oshiオブジェクトを作成してViewModelを初期化
        let initialOshi = Oshi(id: oshiId, name: "推しを選択してください", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil)
        self._viewModel = State(initialValue: OshiViewModel(oshi: initialOshi))
    }
    
    var body: some View {
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
                if let oshi = viewModel?.selectedOshi, let backgroundUrl = oshi.backgroundImageUrl, let url = URL(string: backgroundUrl) {
                    // 選択中の推しの背景画像を表示
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            ZStack(alignment: .topLeading) { // ZStackを追加
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: profileSectionHeight)
                                    .overlay(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.clear, Color.black.opacity(0.6)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .clipped()
                                    .edgesIgnoringSafeArea(.all)
                            }
                            
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
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: profileSectionHeight)
                    .edgesIgnoringSafeArea(.all)
                }
                
                // プロフィール情報とアバター
                VStack(spacing: viewModel?.selectedOshi.name == "" ? 0 : 8) {
                    // プロフィール画像 - 選択中の推しのプロフィール画像に変更
                    ZStack {
                        if let oshi = viewModel?.selectedOshi, let imageUrlString = oshi.imageUrl, let imageUrl = URL(string: imageUrlString) {
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
                                                    showChatAIView()
                                                }
                                                generateHapticFeedback()
                                            }
                                    }
                                    .overlay(
                                        VStack{
                                            HStack {
                                                Spacer()
                                                chatButtonWithBadge
                                                    .scaleEffect(1.0)
                                                    .offset(x: 50, y: -10)
                                            }
                                            Spacer()
                                        }
                                        .zIndex(1)
                                    )
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
                                generateHapticFeedback()
                                print("profilePlaceholder button tapped")
                                navigateToAddOshiForm = true
                            }) {
                                profilePlaceholder
                            }
                        }
                    }
                    .padding(.top,10)
                    .padding(.bottom, 4)
                    
                    // ユーザー名と詳細 - 推し情報表示
                    VStack(spacing: 4) {
                        if isEditingUsername {
                            HStack {
                                TextField("推しの名前", text: $editingUsername)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(2)
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
                            Text(viewModel?.selectedOshi.name ?? "推しを選択してください")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 12)
                    .zIndex(1)
                }
                .offset(y: 0)
            }
            
            // NavigationLinkを非表示で配置
            if viewModel != nil {
                NavigationLink(
                    destination: OshiAIChatView(viewModel: viewModel!, oshiItem: nil)
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width > 80 {
                                        navigateToChatView = false
                                        fetchOshiList()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            checkForUnreadMessages()
                                        }
                                    }
                                }
                        ),
                    isActive: $navigateToChatView
                ) {
                    EmptyView()
                }
                .hidden()
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
        .onAppear {
            if !hasLoadedInitialData {
                loadAllData()
                fetchOshiList()
                hasLoadedInitialData = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // 少し遅らせて未読チェックを実行（データ読み込み完了後）
                    checkForAllUnreadItems()
                }
                
                // 定期的にチェックするタイマー
                startUnreadItemsCheckTimer()
            } else {
                // 画面が再表示される場合も、最新の未読状態をチェック
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkForAllUnreadItems()
                }
            }
        }
        .onChange(of: viewModel?.selectedOshi) { newOshi in
            if newOshi != nil {
                checkForAllUnreadItems()
            }
        }
        .onChange(of: isOshiChange) { newOshi in
            withAnimation {
                loadAllData()
            }
        }
        .onChange(of: oshiId) { newOshiId in
            if newOshiId != viewModel?.selectedOshi.id {
                // 強制的にデータ更新
                loadAllData()
                fetchOshiList()
            }
        }
        .onChange(of: oshiChange) { newOshi in
            withAnimation {
                loadSettingAllData()
                fetchOshiList()
            }
        }
        .onChange(of: showAddOshiForm) { newValue in
            if newValue {
                navigateToAddOshiForm = true
                showAddOshiForm = false
            }
        }
        .onChange(of: showChatView) { newValue in
            if newValue {
                navigateToChatView = true
                showChatView = false
            }
        }
        .onChange(of: isShowingEditOshiView) { newValue in
            if newValue {
                navigateToEditOshi = true
                isShowingEditOshiView = false
            }
        }
    }
    
    func startUnreadItemsCheckTimer() {
        // 1分ごとに未読メッセージと未読投稿をチェック
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            checkForAllUnreadItems()
        }
    }

    // showChatAIView関数を更新して投稿の既読も処理
    func showChatAIView() {
        // チャットを開いたら既読にマーク
        if let oshiId = viewModel?.selectedOshi.id {
            // メッセージを既読にマーク
            ChatDatabaseManager.shared.markMessagesAsRead(for: oshiId) { error in
                if let error = error {
                    print("メッセージを既読にできませんでした: \(error.localizedDescription)")
                } else {
                    // 投稿も既読にマーク（推しの投稿を見る画面を開くことで既読になるケースも考慮）
                    UnreadPostTracker.shared.markPostsAsRead(for: oshiId) { error in
                        if let error = error {
                            print("投稿を既読にできませんでした: \(error.localizedDescription)")
                        }
                        
                        // 既読にしたので、バッジをリセット
                        DispatchQueue.main.async {
                            self.hasNewMessages = false
                            self.unreadMessageCount = 0
                            self.hasUnreadPosts = false
                            self.unreadPostCount = 0
                        }
                    }
                }
            }
        }
        
        // チャットビューを表示
        navigateToChatView = true
    }

    // 投稿を既読にするメソッドを追加（推し投稿一覧画面に遷移する時に呼び出す）
    func markPostsAsRead() {
        if let oshiId = viewModel?.selectedOshi.id {
            UnreadPostTracker.shared.markPostsAsRead(for: oshiId) { error in
                if let error = error {
                    print("投稿を既読にできませんでした: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async {
                        self.hasUnreadPosts = false
                        self.unreadPostCount = 0
                        self.updateBadgeStatus()
                    }
                }
            }
        }
    }
    
    // その他の既存メソッドはそのまま...
    // (checkForUnreadMessages, startMessageCheckTimer, uploadOshiImageToFirebase, checkForUnreadPosts, updateBadgeStatus, checkForAllUnreadItems, forceCheckUnreadMessages, startBadgeAnimation, chatButtonWithBadge, oshiSelectorOverlay, fetchOshiList, loadSelectedOshi, saveSelectedOshiId, saveOshiProfile, loadAllData, loadSettingAllData, fetchUserProfile, fetchUserImageURL, startEditing, profilePlaceholder)
    
    var chatButtonWithBadge: some View {
        Button(action: {
            showChatAIView()
            generateHapticFeedback()
        }) {
            ChatBadgeView(count: unreadMessageCount, hasNewMessages: hasNewMessages)
        }
        .padding(.trailing, 16)
        .padding(.top, 8)
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
                ScrollView{
                    
                    // 推しリスト - グリッドレイアウト
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        // 新規追加ボタン
                        Button(action: {
                            generateHapticFeedback()
                            navigateToAddOshiForm = true
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
                                viewModel?.selectedOshi = oshi
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
                                        if viewModel?.selectedOshi.id == oshi.id {
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
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
            )
            .padding()
        }
    }
    
    // 未読メッセージをチェックする関数
    func checkForUnreadMessages() {
        guard let oshi = viewModel?.selectedOshi else {
            return
        }
        
        ChatDatabaseManager.shared.fetchUnreadMessageCount(for: oshi.id) { count, error in
            if let error = error {
                return
            }
            
            DispatchQueue.main.async {
                self.unreadMessageCount = count
                self.hasNewMessages = count > 0
                
                // 新規メッセージがある場合、バッジをアニメーション
                if self.hasNewMessages && !self.isAnimatingBadge {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        self.startBadgeAnimation()
                    }
                } else {
                }
            }
        }
    }
    
    func startMessageCheckTimer() {
        // 1分ごとに未読メッセージをチェック
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            checkForUnreadMessages()
        }
    }
    
    func uploadOshiImageToFirebase(_ image: UIImage, type: UploadImageType = .profile) {
        guard let userID = Auth.auth().currentUser?.uid, let oshi = viewModel?.selectedOshi else {
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
                                // ローカルのviewModel?.selectedOshiを更新
                                var updatedOshi = self.viewModel?.selectedOshi
                                if type == .profile {
                                    updatedOshi?.imageUrl = url.absoluteString
                                } else {
                                    updatedOshi?.backgroundImageUrl = url.absoluteString
                                }
                                self.viewModel?.selectedOshi = updatedOshi!
                                
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
    
    func checkForUnreadPosts() {
        guard let oshi = viewModel?.selectedOshi else { return }
        
        UnreadPostTracker.shared.fetchUnreadPostCount(for: oshi.id) { count, error in
            if let error = error {
                print("未読投稿の取得に失敗しました: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                self.unreadPostCount = count
                self.hasUnreadPosts = count > 0
                
                // 未読メッセージまたは未読投稿があれば、バッジを表示
                self.updateBadgeStatus()
            }
        }
    }
    
    // バッジの状態を更新する関数
    func updateBadgeStatus() {
        // 未読メッセージまたは未読投稿があるかどうかを確認
        let hasAnyUnread = self.hasNewMessages || self.hasUnreadPosts
        let totalUnreadCount = self.unreadMessageCount + self.unreadPostCount
        
        // バッジの表示状態を更新
        if hasAnyUnread != self.hasNewMessages || totalUnreadCount != self.unreadMessageCount {
            self.hasNewMessages = hasAnyUnread
            self.unreadMessageCount = totalUnreadCount
            
            // 新しい未読アイテムがある場合のみアニメーション
            if hasAnyUnread && !self.isAnimatingBadge {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    self.startBadgeAnimation()
                }
            }
        }
    }
    
    // チェック関数を統合（メッセージと投稿の両方をチェック）
    func checkForAllUnreadItems() {
        checkForUnreadMessages()
        checkForUnreadPosts()
        
        // 追加のデバッグのために少し遅らせて再チェック
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.forceCheckUnreadMessages()
        }
    }
    
    func forceCheckUnreadMessages() {
        guard let oshi = viewModel?.selectedOshi else {
            return
        }
        
        // 強制的に未読チェック
        ChatDatabaseManager.shared.fetchUnreadMessageCount(for: oshi.id) { count, error in
            if let error = error {
                return
            }
            
            DispatchQueue.main.async {
                
                // 状態の変更を強制的に適用
                self.unreadMessageCount = count
                let hasNewMessages = count > 0
                
                if hasNewMessages != self.hasNewMessages {
                    self.hasNewMessages = hasNewMessages
                    
                    // バッジの表示を強制的に更新
                    if hasNewMessages {
                        self.startBadgeAnimation()
                    }
                }
            }
        }
    }
    
    func startBadgeAnimation() {
        // すでにアニメーション中なら何もしない
        if isAnimatingBadge {
            return
        }
        
        isAnimatingBadge = true
        
        // バウンスエフェクトのアニメーション
        withAnimation(Animation.spring(response: 0.3, dampingFraction: 0.6).repeatCount(3)) {
            badgeBounce = true
        }
        
        // アニメーション終了後のリセット
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.badgeBounce = false
                self.isAnimatingBadge = false
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
                        
                        // 新しい属性を取得
                        let personality = value["personality"] as? String
                        let speaking_style = value["speaking_style"] as? String
                        let favorite_food = value["favorite_food"] as? String
                        let disliked_food = value["disliked_food"] as? String
                        let interests = value["interests"] as? [String]
                        let gender = value["gender"] as? String ?? "男性"
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl,
                            memo: memo,
                            createdAt: createdAt,
                            // 属性を設定
                            personality: personality,
                            interests: interests,
                            speaking_style: speaking_style,
                            favorite_food: favorite_food,
                            disliked_food: disliked_food,
                            gender: gender
                        )
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.imageCache = [:]
                
                // oshiIdに一致する推しを検索
                if let matchingOshi = newOshis.first(where: { $0.id == self.oshiId }) {
                    self.viewModel?.selectedOshi = matchingOshi
                    print("推しのデータを更新: \(matchingOshi.name), ID: \(matchingOshi.id)")
                } else {
                    // 選択中の推しIDから推しを設定
                    self.loadSelectedOshi()
                }
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
                    DispatchQueue.main.async {
                        self.viewModel?.selectedOshi = oshi
                    }
                } else if !self.oshiList.isEmpty {
                    // selectedOshiIdに該当する推しが見つからない場合は最初の推しを設定
                    DispatchQueue.main.async {
                        self.viewModel?.selectedOshi = self.oshiList[0]
                    }
                }
            } else if !self.oshiList.isEmpty {
                // selectedOshiIdがない場合も最初の推しを設定
                DispatchQueue.main.async {
                    self.viewModel?.selectedOshi = self.oshiList[0]
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
    
    func saveOshiProfile() {
        guard let userID = Auth.auth().currentUser?.uid, let oshi = viewModel?.selectedOshi else { return }
        
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
                    var updatedOshi = self.viewModel?.selectedOshi
                    updatedOshi?.name = updatedName
                    self.viewModel?.selectedOshi = updatedOshi!
                    
                    // oshiListも更新
                    if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                        self.oshiList[index].name = updatedName
                    }
                }
            }
        }
    }
    
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
    
    func loadSettingAllData() {
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
                print("self.isLoading = false")
                self.isLoading = false
            }
        }
    }
    
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
    
    func startEditing() {
        if let oshi = viewModel?.selectedOshi {
            editingUsername = oshi.name
        }
    }
    
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
                .padding(5)
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
    
    // 小さいデバイスかどうかを確認
    func isSmallDevice() -> Bool {
        return UIScreen.main.bounds.height < 700
    }
    
    // 触覚フィードバック
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    TopView()
}
