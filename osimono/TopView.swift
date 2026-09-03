//
//  TopView.swift
//  osimono
//
//  Created by Apple on 2025/03/23.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TopView: View {
    @State private var selectedOshiId: String = "default"
    @ObservedObject var tutorialManager = TutorialManager.shared
    @State private var showWelcomeScreen = false
    @State private var oshiChange: Bool = false
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshi: Oshi? = nil
    @State private var viewModel: OshiViewModel? = nil
    @State private var showAddOshiFlag = false
    
    @State private var hasLoadedProfileImages = false
    @State private var cachedImageURLs: [String: String] = [:] // oshiId: imageUrl
    @State private var initialLoadCompleted = false
    @State private var observerHandle: DatabaseHandle? // 監視ハンドルを追加
    
    // グループチャット関連の状態
    @State private var selectedGroupId: String = ""
    @State private var groupChats: [GroupChatInfo] = []
    @StateObject private var groupChatManager = GroupChatManager()

    // タブバーバッジ用
    @State private var chatUnreadCount: Int = 0
    @State private var groupUnreadCount: Int = 0
    
    let dummyOshi = Oshi(
        id: "1",
        name: "テストの推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: nil,
        createdAt: Date().timeIntervalSince1970
    )
    
    var body: some View {
        ZStack{
            TabView {
                HStack{
                    ContentView(oshiChange: $oshiChange)
                        .id(selectedOshiId)
                }
                .tabItem {
                    Image(systemName: "rectangle.split.2x2")
                        .padding()
                    Text(L10n.oshiLogTab) // 修正: ハードコーディングされた文字列を多言語対応
                        .padding()
                }
                
                ZStack {
                    MapView(oshiId: selectedOshiId ?? "default")
                }
                .tabItem {
                    Image(systemName: "mappin.and.ellipse")
                    Text(L10n.pilgrimageTab) // 修正: ハードコーディングされた文字列を多言語対応
                }
                
                ZStack {
                    IndividualChatTabView()
                }
                .tabItem {
                    Image(systemName: "message")
                        .frame(width:1,height:1)
                    Text(L10n.chatTab)
                }
                .badge(chatUnreadCount > 0 ? chatUnreadCount : 0)

                // グループチャットタブ（直接チャット画面表示）
                ZStack {
                    DirectGroupChatTabView(
                        selectedGroupId: $selectedGroupId,
                        groupChats: $groupChats,
                        allOshiList: oshiList
                    )
                }
                .tabItem {
                    Image(systemName: "person.2")
                        .frame(width:1,height:1)
                    Text(L10n.groupChatTab)
                }
                .badge(groupUnreadCount > 0 ? groupUnreadCount : 0)
                
                ZStack {
                    SettingsView(oshiChange: $oshiChange)
                }
                .tabItem {
                    Image(systemName: "gear")
                        .frame(width:1,height:1)
                    Text(L10n.settingsTab) // 修正: ハードコーディングされた文字列を多言語対応
                }
            }
            // チュートリアルオーバーレイを条件付きで表示
            if tutorialManager.isShowingTutorial {
                TutorialOverlayView(closeAction: {
                    withAnimation {
                        tutorialManager.isShowingTutorial = false
                    }
                })
                .zIndex(100) // 最前面に表示
            }
        }
        .fullScreenCover(isPresented: $showAddOshiFlag, onDismiss: {
            // 推し追加後に確実にデータを再取得
            fetchOshiList()
            
            // 少し遅らせてselectedOshiIdの監視を確実に再初期化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                observeSelectedOshiId()
                
                // タブビューのデータ更新をトリガー
                oshiChange.toggle()
            }
        }) {
            AddOshiView()
        }
        .onAppear {
            if !initialLoadCompleted {
                // 初回のみ完全にロード
                fetchOshiList()
                observeSelectedOshiId()
                loadGroupChats() // グループチャットデータも読み込み
                initialLoadCompleted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    loadTabBadgeCounts()
                }
                
                if !UserDefaults.standard.bool(forKey: "appLaunchedBefore") {
                    UserDefaults.standard.set(false, forKey: "tutorialCompleted")
                    UserDefaults.standard.set(true, forKey: "appLaunchedBefore")
                    
                    // アプリの起動アニメーションを待ってからチュートリアルを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            tutorialManager.startTutorial()
                        }
                    }
                }
            } else if oshiChange {
                // 推し変更されたときのみ再ロード
                fetchOshiList()
                loadGroupChats() // グループチャットも再読み込み
                oshiChange = false
            } else {
                loadTabBadgeCounts()
            }
        }
        .onDisappear {
            // メモリリーク防止のために監視を解除
            removeObserver()
        }
    }
    
    private func loadTabBadgeCounts() {
        guard !oshiList.isEmpty else { return }

        // 個別チャット未読数（全推しの合計）
        let chatGroup = DispatchGroup()
        var totalChat = 0
        for oshi in oshiList {
            chatGroup.enter()
            ChatDatabaseManager.shared.fetchUnreadMessageCount(for: oshi.id) { count, _ in
                totalChat += count
                chatGroup.leave()
            }
        }
        chatGroup.notify(queue: .main) {
            self.chatUnreadCount = totalChat
        }

        // グループチャット未読数（全グループの合計）
        guard !groupChats.isEmpty else { return }
        let groupGroup = DispatchGroup()
        var totalGroup = 0
        for group in groupChats {
            groupGroup.enter()
            groupChatManager.fetchUnreadMessageCount(for: group.id) { count, _ in
                totalGroup += count
                groupGroup.leave()
            }
        }
        groupGroup.notify(queue: .main) {
            self.groupUnreadCount = totalGroup
        }
    }

    private func loadSelectedGroupId() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.child("selectedGroupId").observeSingleEvent(of: .value) { snapshot in
            if let savedGroupId = snapshot.value as? String,
               !savedGroupId.isEmpty {
                DispatchQueue.main.async {
                    print("✅ \(L10n.savedGroupIdRetrieved): \(savedGroupId)") // 修正: ログメッセージを多言語対応
                    self.selectedGroupId = savedGroupId
                }
            } else {
                print("📝 \(L10n.noSavedGroupId)") // 修正: ログメッセージを多言語対応
            }
        }
    }
    
    private func saveSelectedGroupId(_ groupId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedGroupId": groupId]) { error, _ in
            if let error = error {
                print("❌ \(L10n.groupIdSaveError): \(error.localizedDescription)") // 修正: エラーメッセージを多言語対応
            } else {
                print("✅ \(L10n.groupIdSaveSuccess): \(groupId)") // 修正: 成功メッセージを多言語対応
            }
        }
    }
    
    // グループチャットデータを読み込み
    private func loadGroupChats() {
        groupChatManager.fetchGroupList { groups, error in
            DispatchQueue.main.async {
                if let groups = groups {
                    self.groupChats = groups
                    
                    // 保存されたグループIDがある場合はそれを優先
                    self.loadSelectedGroupId()
                    
                    // 少し遅延して、保存されたIDが有効かチェック
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if !self.selectedGroupId.isEmpty {
                            // 保存されたIDが現在のグループリストに存在するかチェック
                            if !groups.contains(where: { $0.id == self.selectedGroupId }) {
                                // 存在しない場合は最初のグループを選択
                                self.selectedGroupId = groups.first?.id ?? ""
                            }
                        } else {
                            // 保存されたIDがない場合は最初のグループを選択
                            self.selectedGroupId = groups.first?.id ?? ""
                        }
                    }
                } else {
                    self.groupChats = []
                    self.selectedGroupId = ""
                }
            }
        }
    }
    
    // 監視ハンドル削除メソッドを追加
    private func removeObserver() {
        guard let userID = Auth.auth().currentUser?.uid,
              let handle = observerHandle else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.removeObserver(withHandle: handle)
        observerHandle = nil
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
                        let name = value["name"] as? String ?? L10n.noNamePlaceholder // 修正: ハードコーディングされた文字列を多言語対応
                        
                        // 画像URLは結果的にキャッシュする
                        let imageUrl = value["imageUrl"] as? String
                        if let imageUrl = imageUrl {
                            self.cachedImageURLs[id] = imageUrl
                        }
                        
                        let backgroundImageUrl = value["backgroundImageUrl"] as? String
                        let memo = value["memo"] as? String
                        let createdAt = value["createdAt"] as? TimeInterval
                        
                        // 性格関連の属性も追加
                        let personality = value["personality"] as? String
                        let speakingStyle = value["speaking_style"] as? String
                        let birthday = value["birthday"] as? String
                        let height = value["height"] as? Int
                        let favoriteColor = value["favorite_color"] as? String
                        let favoriteFood = value["favorite_food"] as? String
                        let dislikedFood = value["disliked_food"] as? String
                        let hometown = value["hometown"] as? String
                        let interests = value["interests"] as? [String]
                        let gender = value["gender"] as? String ?? "男性"
                        let userNickname = value["user_nickname"] as? String
                        let relationshipStatus = value["relationship_status"] as? String
                        let relationshipDetail = value["relationship_detail"] as? String
                        let sharedMemory = value["shared_memory"] as? String
                        let signaturePhrase = value["signature_phrase"] as? String
                        let conversationTopics = value["conversation_topics"] as? [String]
                        let forbiddenTopics = value["forbidden_topics"] as? [String]
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl,
                            memo: memo,
                            createdAt: createdAt,
                            personality: personality,
                            interests: interests,
                            speaking_style: speakingStyle,
                            birthday: birthday,
                            height: height,
                            favorite_color: favoriteColor,
                            favorite_food: favoriteFood,
                            disliked_food: dislikedFood,
                            hometown: hometown,
                            gender: gender,
                            user_nickname: userNickname,
                            relationship_status: relationshipStatus,
                            relationship_detail: relationshipDetail,
                            shared_memory: sharedMemory,
                            signature_phrase: signaturePhrase,
                            conversation_topics: conversationTopics,
                            forbidden_topics: forbiddenTopics
                        )
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.hasLoadedProfileImages = true
                
                print("✅ \(L10n.oshiDataLoaded): \(newOshis.count)人") // 修正: ログメッセージを多言語対応（日本語部分は保持）
                
                // 推しリストが取得できたら、選択中の推しを設定
                if !newOshis.isEmpty {
                    // 現在のselectedOshiIdがデフォルト値の場合は、最初の推しを選択
                    if self.selectedOshiId == "default" {
                        self.loadSelectedOshiFromFirebase(withFallback: newOshis.first!)
                    } else {
                        // selectedOshiIdがある場合は、該当する推しを検索
                        if let matchingOshi = newOshis.first(where: { $0.id == self.selectedOshiId }) {
                            self.updateSelectedOshi(matchingOshi)
                        } else {
                            // 該当する推しがない場合は最初の推しを選択
                            self.updateSelectedOshi(newOshis.first!)
                        }
                    }
                }
            }
        }
    }
    
    // 選択中の推しをFirebaseから取得し、フォールバックも設定
    func loadSelectedOshiFromFirebase(withFallback fallbackOshi: Oshi) {
        guard let userID = Auth.auth().currentUser?.uid else {
            // ユーザーIDがない場合はフォールバックを使用
            updateSelectedOshi(fallbackOshi)
            return
        }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedOshiId = snapshot.value as? String,
               selectedOshiId != "default",
               let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                // Firebaseに保存されている推しIDに該当する推しが見つかった場合
                DispatchQueue.main.async {
                    print("✅ \(L10n.firebaseSavedOshi): \(oshi.name)") // 修正: ログメッセージを多言語対応
                    self.updateSelectedOshi(oshi)
                }
            } else {
                // Firebaseに保存されていないか、該当する推しがない場合はフォールバックを使用
                DispatchQueue.main.async {
                    print("✅ \(L10n.fallbackOshi): \(fallbackOshi.name)") // 修正: ログメッセージを多言語対応
                    self.updateSelectedOshi(fallbackOshi)
                    // Firebaseにも保存
                    self.saveSelectedOshiId(fallbackOshi.id)
                }
            }
        }
    }
    
    // 選択中の推しを更新する共通メソッド
    func updateSelectedOshi(_ oshi: Oshi) {
        self.selectedOshi = oshi
        self.selectedOshiId = oshi.id
        self.viewModel = OshiViewModel(oshi: oshi)
        print("🎯 \(L10n.oshiSelectionCompleted): \(oshi.name) (ID: \(oshi.id))") // 修正: ログメッセージを多言語対応
    }
    
    // 推しIDをFirebaseに保存
    func saveSelectedOshiId(_ oshiId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedOshiId": oshiId]) { error, _ in
            if let error = error {
                print("❌ \(L10n.oshiIdSaveError): \(error.localizedDescription)") // 修正: エラーメッセージを多言語対応
            } else {
                print("✅ \(L10n.oshiIdSaveSuccess): \(oshiId)") // 修正: 成功メッセージを多言語対応
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
                        self.updateSelectedOshi(oshi)
                    }
                }
            }
        }
    }
    
    // 修正された observeSelectedOshiId メソッド
    func observeSelectedOshiId() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        
        // 既存の監視を解除（重複監視を防ぐ）
        removeObserver()
        
        // 再度監視を設定（selectedOshiIdのみを監視）
        observerHandle = dbRef.child("selectedOshiId").observe(.value) { snapshot in
            if let selectedOshiId = snapshot.value as? String {
                DispatchQueue.main.async {
                    print("🔄 \(L10n.selectedOshiIdChangeDetected): \(selectedOshiId)") // 修正: ログメッセージを多言語対応
                    
                    // 現在のIDと異なる場合のみ更新
                    if self.selectedOshiId != selectedOshiId {
                        self.selectedOshiId = selectedOshiId
                        
                        // 選択中の推しIDに対応する推しオブジェクトを取得
                        if let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                            self.updateSelectedOshi(oshi)
                            
                            // タブビューのデータ更新をトリガー
                            DispatchQueue.main.async {
                                self.oshiChange.toggle()
                            }
                        } else {
                            // 対応する推しが見つからない場合は再取得
                            print("⚠️ \(L10n.correspondingOshiNotFound)") // 修正: ログメッセージを多言語対応
                            self.fetchOshiList()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 直接グループチャット表示用のタブビュー
struct DirectGroupChatTabView: View {
    @Binding var selectedGroupId: String
    @Binding var groupChats: [GroupChatInfo]
    let allOshiList: [Oshi]
    
    @State private var showGroupList = false
    @State private var isLoading = true
    @StateObject private var groupChatManager = GroupChatManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    loadingView
                } else if groupChats.isEmpty {
                    emptyGroupStateView
                } else if selectedGroupId.isEmpty {
                    noSelectedGroupView
                } else {
                    // 選択中のグループチャット画面を直接表示
                    OshiGroupChatView(
                        groupId: $selectedGroupId,
                        onShowGroupList: {
                            showGroupList = true
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadInitialData()
        }
        .sheet(isPresented: $showGroupList) {
            GroupChatListModalView(
                groupChats: $groupChats,
                selectedGroupId: $selectedGroupId,
                allOshiList: allOshiList
            )
        }
        // グループ選択変更を監視して保存
        .onChange(of: selectedGroupId) { newGroupId in
            if !newGroupId.isEmpty {
                saveSelectedGroupId(newGroupId)
            }
        }
    }
    
    // 選択中のグループIDを保存
    private func saveSelectedGroupId(_ groupId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedGroupId": groupId]) { error, _ in
            if let error = error {
                print("❌ グループID保存エラー: \(error.localizedDescription)")
            } else {
                print("✅ グループID保存成功: \(groupId)")
            }
        }
    }
    
    // 保存されたグループIDを取得
    private func loadSelectedGroupId(completion: @escaping (String?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.child("selectedGroupId").observeSingleEvent(of: .value) { snapshot in
            let savedGroupId = snapshot.value as? String
            completion(savedGroupId)
        }
    }
    
    private func loadInitialData() {
        isLoading = true
        
        groupChatManager.fetchGroupList { groups, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let groups = groups {
                    self.groupChats = groups
                    
                    // 保存されたグループIDを取得して設定
                    self.loadSelectedGroupId { savedGroupId in
                        DispatchQueue.main.async {
                            if let savedGroupId = savedGroupId,
                               !savedGroupId.isEmpty,
                               groups.contains(where: { $0.id == savedGroupId }) {
                                self.selectedGroupId = savedGroupId
                                print("✅ \(L10n.savedGroupRestored): \(savedGroupId)")
                            } else {
                                let firstGroupId = groups.first?.id ?? ""
                                self.selectedGroupId = firstGroupId
                                if !firstGroupId.isEmpty {
                                    print("✅ \(L10n.defaultGroupSelected): \(firstGroupId)")
                                }
                            }
                        }
                    }
                } else {
                    self.groupChats = []
                    self.selectedGroupId = ""
                }
            }
        }
    }
    
    // 以下、既存のView定義は変更なし...
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(L10n.loadingGroupChats)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyGroupStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(L10n.noGroupChatsAvailable)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(L10n.createGroupChatsMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showGroupList = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text(L10n.createGroupButtonText)
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemPink), Color(.systemPink).opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: Color(.systemPink).opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var noSelectedGroupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(L10n.selectGroupPlease)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(L10n.selectGroupFromList)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showGroupList = true
            }) {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20))
                    Text(L10n.showGroupList)
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemBlue), Color(.systemBlue).opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: Color(.systemBlue).opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    TopView()
}
