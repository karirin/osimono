//
//  OshiGroupChatView.swift
//  osimono
//
//  複数の推しとのグループチャット機能 - サブスクリプション対応版
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import Combine

enum ConversationPattern {
    case aiToAI        // AI同士で話す
    case aiToGroup     // AIがAIと自分に話す（グループ全体）
    case aiToUser      // AIが自分に話す
}

struct OshiGroupChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var groupChatManager = GroupChatManager()
    @State private var messages: [GroupChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isInitialLoadingComplete: Bool = false // ローディング完了フラグ
    @State private var shouldScrollToBottom: Bool = false
    @State private var showMemberSelection: Bool = false
    @State private var showRewardCompletedModal = false
    @State private var rewardAmount = 0
    
    // 編集機能関連の新しい状態
    @State private var showEditGroupSheet = false
    @State private var groupInfo: GroupChatInfo?
    
    // 選択された推しメンバー
    @State private var selectedMembers: [Oshi] = []
    @State private var allOshiList: [Oshi] = []
    
    // グループチャット情報
    @Binding var groupId: String
    @State private var currentGroupId = ""
    let onShowGroupList: (() -> Void)? // グループリスト表示用のクロージャ
    @State private var groupName: String = ""
    
    // キーボード関連
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    // 既読管理用
    @State private var hasMarkedAsRead: Bool = false
    
    @StateObject private var interstitialManager = GroupChatInterstitialManager.shared
    
    // サブスクリプション管理を追加
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    // 管理者権限チェック用
    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    
    private let adminUserIds = [
        ""
//        "3UDNienzhkdheKIy77lyjMJhY4D3",
//        "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    ]
    
    // 広告表示判定のプロパティを追加
    private var shouldShowAd: Bool {
        return !isAdmin && !subscriptionManager.isSubscribed
    }
    
    // LINE風カラー設定
    let lineBgColor = Color(UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0))
    let lineGreen = Color(UIColor(red: 0.0, green: 0.68, blue: 0.31, alpha: 1.0))
    let primaryColor = Color(.systemPink)
    
    @State private var helpFlag: Bool = false
    @State private var customerFlag: Bool = false
    @ObservedObject var authManager = AuthManager()
    
    // イニシャライザを修正
    init(groupId: Binding<String>,          // ←型を Binding に
         onShowGroupList: (() -> Void)? = nil) {
        self._groupId = groupId             // ←Binding を保持
        self.onShowGroupList = onShowGroupList
        _currentGroupId = State(initialValue: groupId.wrappedValue) // ←追加
    }
    
    var body: some View {
        ZStack {
            // 背景色（ローディング中でも表示）
            lineBgColor.edgesIgnoringSafeArea(.all)
            
            if isInitialLoadingComplete {
                // メインのチャット画面
                chatContent
            } else {
                // ローディング画面
                loadingView
            }
            
            // モーダル系（ローディング完了後でも表示）
            if showMemberSelection {
                GroupMemberSelectionView(
                    isPresented: $showMemberSelection,
                    allOshiList: allOshiList,
                    selectedMembers: $selectedMembers,
                    onSave: { updateGroupMembers() }
                )
            }
            
            if showRewardCompletedModal {
                RewardCompletedModal(
                    isPresented: $showRewardCompletedModal,
                    rewardAmount: rewardAmount
                )
            }
            
            if helpFlag {
                HelpModalView(isPresented: $helpFlag)
            }
            
            if customerFlag {
                ReviewView(isPresented: $customerFlag, helpFlag: $helpFlag)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 && isInitialLoadingComplete {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeInOut(duration: 0.3)) { keyboardHeight = height }
        }
        .onAppear {
            checkAdminStatus()
            setupGroupChat()
            // インタースティシャル広告を事前読み込み（サブスク状態を考慮）
            if shouldShowAd {
                interstitialManager.preloadInterstitialAd()
            }
        }
        .onChange(of: groupId) { newValue in
            guard newValue != currentGroupId else { return }
            // 古いリスナーを解除
            groupChatManager.removeMessageListener(for: currentGroupId)
            
            // 状態をリセット（必要に応じて）
            messages.removeAll()
            selectedMembers.removeAll()
            hasMarkedAsRead = false
            
            // 新しいグループをロード
            currentGroupId = newValue
            setupGroupChat()
        }
        .onDisappear {
            markAsReadWhenDisappear()
            // リスナーを削除してメモリリークを防止
            groupChatManager.removeMessageListener(for: groupId)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditGroupSheet) {
            if let group = groupInfo {
                EditGroupChatView(
                    group: group,
                    allOshiList: allOshiList,
                    onUpdate: { updatedGroup in
                        // グループ情報更新後の処理
                        self.groupInfo = updatedGroup
                        self.groupName = updatedGroup.name
                        // メンバー情報を再読み込み
                        self.loadGroupMembers {
                            // 完了処理
                        }
                    }
                )
            }
        }
    }
    
    // 管理者権限チェック関数を追加
    private func checkAdminStatus() {
        guard let userID = Auth.auth().currentUser?.uid else {
            isAdmin = false
            isCheckingAdminStatus = false
            return
        }
        
        // UserIDで管理者権限をチェック
        isAdmin = adminUserIds.contains(userID)
        isCheckingAdminStatus = false
        
        if isAdmin {
            print("🔑 管理者としてログイン中: \(userID)")
        }
    }
    
    // MARK: - ローディング画面
    private var loadingView: some View {
        VStack(spacing: 0) {
            // ヘッダー部分（ローディング中でも表示）
            headerViewLoading
            
            // ローディング中のメインエリア
            VStack(spacing: 24) {
                Spacer()
                
                // ローディングアニメーション
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: primaryColor))
                    
                    Text("グループチャットを準備中...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
    }
    
    // ローディング中のヘッダー（戻るボタンのみ）
    private var headerViewLoading: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 戻るボタン
                Button(action: {
                    generateHapticFeedback()
                    isTextFieldFocused = false
                    
                    // 戻る前に既読マーク
                    markAsReadWhenDisappear()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    generateHapticFeedback()
                    onShowGroupList?()
                }) {
                    HStack(spacing: 10) {
                        groupIconView
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(groupName.isEmpty ? "グループチャット" : groupName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.black)
                            
                            HStack(spacing: 4) {
                                Text("\(selectedMembers.count)人のメンバー")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // 編集ボタン（新規追加）
                Button(action: {
                    generateHapticFeedback()
                    showEditGroupSheet = true
                }) {
                    Text("編集")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
        }
    }
    
    private var chatContent: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerView
            
            // チャットメッセージリスト
            chatMessagesView
            
            // 入力エリア
            inputAreaView
                .padding(.bottom, keyboardHeight > 0 ? 0 : 0)
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // 戻るボタン
//                Button(action: {
//                    generateHapticFeedback()
//                    isTextFieldFocused = false
//
//                    // 戻る前に既読マーク
//                    markAsReadWhenDisappear()
//
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        presentationMode.wrappedValue.dismiss()
//                    }
//                }) {
//                }
                
                Button(action: {
                    generateHapticFeedback()
                    onShowGroupList?()
                }) {
                    HStack(spacing: 10) {
                        
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                        groupIconView
                            .frame(width: 36, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(groupName.isEmpty ? "グループチャット" : groupName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.black)
                            
                            HStack(spacing: 4) {
                                Text("\(selectedMembers.count)人のメンバー")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // 編集ボタン（新規追加）
                Button(action: {
                    generateHapticFeedback()
                    showEditGroupSheet = true
                }) {
                    Text("編集")
                       .font(.system(size: 16))
                       .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
        }
    }
    
    private var groupIconView: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 36, height: 36)
            
            if selectedMembers.isEmpty {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            } else if selectedMembers.count == 1 {
                // 1人の場合は通常のプロフィール画像
                if let imageUrl = selectedMembers[0].imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Text(String(selectedMembers[0].name.prefix(1)))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Text(String(selectedMembers[0].name.prefix(1)))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        )
                }
            } else {
                // 複数人の場合は重ねて表示
                ForEach(Array(selectedMembers.prefix(2).enumerated()), id: \.element.id) { index, oshi in
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(String(oshi.name.prefix(1)))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        )
                        .offset(
                            x: index == 0 ? -6 : 6,
                            y: index == 0 ? -6 : 6
                        )
                }
            }
        }
    }
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    if messages.isEmpty {
                        VStack(spacing: 12) {
                            Text("グループチャットを始めましょう！")
                                .foregroundColor(.gray)
                                .padding(.top, 40)
                            
                            if selectedMembers.isEmpty {
                                Button(action: {
                                    showMemberSelection = true
                                }) {
                                    Text("メンバーを追加する")
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    } else {
                        ForEach(messages, id: \.id) { message in
                            GroupChatBubble(
                                message: message,
                                selectedMembers: selectedMembers
                            )
                            .id(message.id)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("bottomMarker")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
                markAsReadAfterDelay()
            }
            .onChange(of: shouldScrollToBottom) { shouldScroll in
                if shouldScroll && !messages.isEmpty {
                    scrollToBottom(proxy: proxy)
                    shouldScrollToBottom = false
                }
            }
            .onChange(of: keyboardHeight) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onAppear {
                // メッセージが読み込まれた後に初回スクロール
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !messages.isEmpty {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
                }
                
                authManager.fetchUserFlag { userFlag, error in
                    if let error = error {
                        print(error.localizedDescription)
                    } else if let userFlag = userFlag {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            if userFlag == 0 {
                                executeProcessEveryThreeTimes()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                TextField("メッセージを入力", text: $inputText)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onSubmit {
                        if !inputText.isEmpty && !isLoading && !selectedMembers.isEmpty {
                            sendMessage()
                        }
                    }
                
                Button(action: {
                    if !inputText.isEmpty && !isLoading && !selectedMembers.isEmpty {
                        generateHapticFeedback()
                        // サブスクリプション状態を考慮してカウント処理
                        if shouldShowAd {
                            interstitialManager.incrementSendCount()
                        }
                        sendMessage()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(inputText.isEmpty || isLoading || selectedMembers.isEmpty ? Color.gray.opacity(0.4) : lineGreen)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(inputText.isEmpty || isLoading || selectedMembers.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    }
    
    func executeProcessEveryThreeTimes() {
        // UserDefaultsからカウンターを取得
        let count = UserDefaults.standard.integer(forKey: "launchCount") + 1
        
        // カウンターを更新
        UserDefaults.standard.set(count, forKey: "launchCount")
        
        // 3回に1回の割合で処理を実行
        
        if count % 10 == 0 {
            customerFlag = true
        }
    }
    
    private func markAsReadWhenAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            markGroupChatAsRead()
        }
    }
    
    private func markAsReadWhenDisappear() {
        markGroupChatAsRead()
    }
    
    private func markAsReadAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            markGroupChatAsRead()
        }
    }
    
    private func markGroupChatAsRead() {
        guard !hasMarkedAsRead else { return }
        
        hasMarkedAsRead = true
        
        groupChatManager.markGroupChatAsRead(for: groupId) { error in
            if let error = error {
                print("グループチャット既読マークエラー: \(error.localizedDescription)")
            } else {
                print("グループチャット既読マーク成功: \(self.groupId)")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.hasMarkedAsRead = false
            }
        }
    }
    
    // MARK: - セットアップ関連メソッド
    
    private func setupGroupChat() {
        // 初期ローディング開始
        isInitialLoadingComplete = false
        
        // 順次読み込みに変更（並行処理を避ける）
        loadOshiList {
            self.loadMessages {
                self.loadGroupMembers {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.isInitialLoadingComplete = true
                        }
                        
                        // 画面表示後に既読マーク
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.markAsReadWhenAppear()
                        }
                    }
                }
            }
        }
    }
    
    // 残りのメソッドは元のコードと同じ（省略）
    private func loadOshiList(completion: @escaping () -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion()
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId)
        ref.observeSingleEvent(of: .value) { snapshot in
            var oshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any] {
                    let id = childSnapshot.key
                    let name = value["name"] as? String ?? "名前なし"
                    let imageUrl = value["imageUrl"] as? String
                    
                    let oshi = Oshi(
                        id: id,
                        name: name,
                        imageUrl: imageUrl,
                        backgroundImageUrl: value["backgroundImageUrl"] as? String,
                        memo: value["memo"] as? String,
                        createdAt: value["createdAt"] as? TimeInterval,
                        personality: value["personality"] as? String,
                        interests: value["interests"] as? [String],
                        speaking_style: value["speaking_style"] as? String,
                        birthday: value["birthday"] as? String,
                        height: value["height"] as? Int,
                        favorite_color: value["favorite_color"] as? String,
                        favorite_food: value["favorite_food"] as? String,
                        disliked_food: value["disliked_food"] as? String,
                        hometown: value["hometown"] as? String,
                        gender: value["gender"] as? String,
                        user_nickname: value["user_nickname"] as? String
                    )
                    oshis.append(oshi)
                }
            }
            
            DispatchQueue.main.async {
                self.allOshiList = oshis
                completion()
            }
        }
    }
    
    private func loadMessages(completion: @escaping () -> Void) {
        print("メッセージ読み込み開始: \(groupId)")
        
        groupChatManager.fetchMessages(for: groupId) { fetchedMessages, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("メッセージ読み込みエラー: \(error.localizedDescription)")
                    self.messages = []
                } else if let fetchedMessages = fetchedMessages {
                    print("メッセージ読み込み成功: \(fetchedMessages.count)件")
                    self.messages = fetchedMessages
                    
                    // 初回読み込み完了後のスクロール
                    if !self.isInitialLoadingComplete {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.shouldScrollToBottom = true
                        }
                    }
                } else {
                    self.messages = []
                }
                
                completion()
            }
        }
    }

    private func loadGroupMembers(completion: @escaping () -> Void) {
        groupChatManager.fetchGroupMembers(for: groupId) { memberIds, error in
            DispatchQueue.main.async {
                if let memberIds = memberIds, !memberIds.isEmpty {
                    self.selectedMembers = self.allOshiList.filter { memberIds.contains($0.id) }
                } else {
                    self.selectedMembers = []
                }
                
                // グループ情報を読み込み（編集機能のため）
                self.loadGroupInfo {
                    completion()
                }
            }
        }
    }

    // グループ情報を取得する修正版メソッド（編集用のgroupInfoも設定）
    private func loadGroupInfo(completion: @escaping () -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion()
            return
        }
        
        let groupInfoRef = Database.database().reference()
            .child("groupChats")
            .child(userId)
            .child(groupId)
            .child("info")
        
        groupInfoRef.observeSingleEvent(of: .value) { snapshot in
            if let groupData = snapshot.value as? [String: Any],
               let groupInfo = GroupChatInfo.fromDictionary(groupData) {
                DispatchQueue.main.async {
                    self.groupName = groupInfo.name
                    self.groupInfo = groupInfo // 編集用にグループ情報を保存
                    print("グループ情報読み込み完了: \(groupInfo.name)")
                    completion()
                }
            } else {
                // グループ情報が存在しない場合は、デフォルトのグループ情報を作成
                DispatchQueue.main.async {
                    let defaultGroupInfo = GroupChatInfo(
                        id: self.groupId,
                        name: "グループチャット",
                        memberIds: self.selectedMembers.map { $0.id },
                        createdAt: Date().timeIntervalSince1970,
                        lastMessageTime: 0,
                        lastMessage: nil
                    )
                    self.groupInfo = defaultGroupInfo
                    self.groupName = defaultGroupInfo.name
                    print("デフォルトグループ情報作成: \(defaultGroupInfo.name)")
                    completion()
                }
            }
        }
    }
    
    private func updateGroupMembers() {
        let memberIds = selectedMembers.map { $0.id }
        groupChatManager.updateGroupMembers(groupId: groupId, memberIds: memberIds) { error in
            if let error = error {
                print("グループメンバー更新エラー: \(error.localizedDescription)")
            } else {
                // メンバー更新後にgroupInfoも更新
                DispatchQueue.main.async {
                    if var currentGroupInfo = self.groupInfo {
                        currentGroupInfo = GroupChatInfo(
                            id: currentGroupInfo.id,
                            name: currentGroupInfo.name,
                            memberIds: memberIds,
                            createdAt: currentGroupInfo.createdAt,
                            lastMessageTime: currentGroupInfo.lastMessageTime,
                            lastMessage: currentGroupInfo.lastMessage
                        )
                        self.groupInfo = currentGroupInfo
                    }
                }
            }
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty, !selectedMembers.isEmpty else {
            print("送信条件不足: テキスト=\(inputText), メンバー数=\(selectedMembers.count)")
            return
        }
        
        let userMessage = GroupChatMessage(
            id: UUID().uuidString,
            content: inputText,
            isUser: true,
            timestamp: Date().timeIntervalSince1970,
            groupId: groupId,
            senderId: "user"
        )
        
        let userInput = inputText
        inputText = ""
        
        print("メッセージ保存開始: \(userMessage.id)")
        
        groupChatManager.saveMessage(userMessage) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("メッセージ保存エラー: \(error.localizedDescription)")
                    self.inputText = userInput // エラー時は入力を復元
                } else {
                    print("メッセージ保存成功、AI返信生成開始")
                    self.generateGroupResponse(for: userInput)
                }
            }
        }
    }
    
    private func generateGroupResponse(for userInput: String) {
        guard !selectedMembers.isEmpty else { return }
        
        isLoading = true
        
        // 最初の返信メンバーを選択（1〜2人）
        let respondingMemberCount = min(2, selectedMembers.count)
        let initialRespondingMembers = selectedMembers.shuffled().prefix(Int.random(in: 1...respondingMemberCount))
        
        print("AI返信生成開始 - 返信メンバー: \(initialRespondingMembers.map { $0.name }.joined(separator: ", "))")
        
        generateInitialResponses(for: userInput, members: Array(initialRespondingMembers)) {
            // 初期返信完了後、追加のリアクションをチェック
            self.checkForAIReactions()
        }
    }
    
    private func generateInitialResponses(for userInput: String, members: [Oshi], completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()
        var responses: [(oshi: Oshi, content: String)] = []
        
        print("初期返信生成中 - メンバー数: \(members.count)")
        
        for oshi in members {
            dispatchGroup.enter()
            
            // チャット履歴を最新5件に限定
            let recentChatHistory = Array(messages.suffix(5).compactMap { message in
                ChatMessage(
                    id: message.id,
                    content: message.content,
                    isUser: message.isUser,
                    timestamp: message.timestamp,
                    oshiId: message.senderId,
                    itemId: nil
                )
            })
            
            AIMessageGenerator.shared.generateResponse(
                for: userInput,
                oshi: oshi,
                chatHistory: recentChatHistory
            ) { content, error in
                if let content = content, !content.isEmpty {
                    responses.append((oshi: oshi, content: content))
                    print("AI返信生成成功 - \(oshi.name): \(content.prefix(20))...")
                } else if let error = error {
                    print("AI返信生成エラー - \(oshi.name): \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
            print("全ての初期返信生成完了 - 返信数: \(responses.count)")
            
            // レスポンスを順次送信（並行送信を避ける）
            self.sendResponsesSequentially(responses: responses, index: 0, completion: completion)
        }
    }
    
    private func checkForAIReactions() {
        print("AIリアクションチェック開始")
        
        // リアクション発生確率（100%から調整可能）
        let reactionProbability = 0.7 // 70%の確率でリアクション発生
        
        guard let lastMessage = messages.last,
              !lastMessage.isUser,
              let lastSender = selectedMembers.first(where: { $0.id == lastMessage.senderId }) else {
            print("リアクション条件不満足")
            return
        }
        
        // 最後にメッセージを送った推し以外のメンバー
        let otherMembers = selectedMembers.filter { $0.id != lastMessage.senderId }
        
        guard !otherMembers.isEmpty else {
            print("リアクション可能なメンバーなし")
            return
        }
        
        // ランダムに1人選択してリアクション生成
        if let reactor = otherMembers.randomElement(),
           Double.random(in: 0...1) < reactionProbability {
            
            let delay = Double.random(in: 2.0...5.0) // 2〜5秒の遅延
            print("リアクション予定 - \(reactor.name): \(delay)秒後")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.generateAIReaction(reactor: reactor, originalMessage: lastMessage, originalSender: lastSender)
            }
        } else {
            print("リアクション発生せず")
        }
    }
    
    private func generateAIReaction(reactor: Oshi, originalMessage: GroupChatMessage, originalSender: Oshi) {
        print("AIリアクション生成開始 - \(reactor.name) -> \(originalSender.name)の発言")
        
        let reactionPrompt = """
        \(originalSender.name)が「\(originalMessage.content)」と言いました。
        あなた（\(reactor.name)）は同じグループの仲間として、この発言に短く自然に反応してください。
        リアクションは1〜2文程度の短いものにしてください。
        """
        
        // 最新3件のチャット履歴を使用
        let recentChatHistory = Array(messages.suffix(3).map { $0.toChatMessage() })
        
        AIMessageGenerator.shared.generateResponse(
            for: reactionPrompt,
            oshi: reactor,
            chatHistory: recentChatHistory
        ) { content, error in
            guard let content = content, !content.isEmpty else {
                if let error = error {
                    print("AIリアクション生成エラー - \(reactor.name): \(error.localizedDescription)")
                }
                return
            }
            
            print("AIリアクション生成成功 - \(reactor.name): \(content.prefix(20))...")
            
            let reactionMessage = GroupChatMessage(
                id: UUID().uuidString,
                content: content,
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                groupId: self.groupId,
                senderId: reactor.id,
                senderName: reactor.name,
                senderImageUrl: reactor.imageUrl
            )
            
            // メッセージを保存（楽観的更新は行わない）
            self.groupChatManager.saveMessage(reactionMessage) { error in
                if let error = error {
                    print("AIリアクション保存エラー - \(reactor.name): \(error.localizedDescription)")
                } else {
                    print("AIリアクション保存成功 - \(reactor.name)")
                }
            }
        }
    }
    
    private func sendResponsesSequentially(responses: [(oshi: Oshi, content: String)], index: Int, completion: @escaping () -> Void) {
        guard index < responses.count else {
            // 全てのレスポンス送信完了
            print("全ての返信送信完了")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
            return
        }
        
        let response = responses[index]
        let delay = Double(index) * 1.5 // 1.5秒間隔で送信
        
        print("返信送信予定 - \(response.oshi.name): \(delay)秒後")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let aiMessage = GroupChatMessage(
                id: UUID().uuidString,
                content: response.content,
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                groupId: self.groupId,
                senderId: response.oshi.id,
                senderName: response.oshi.name,
                senderImageUrl: response.oshi.imageUrl
            )
            
            print("返信送信中 - \(response.oshi.name): \(aiMessage.id)")
            
            // メッセージを保存（楽観的更新は行わない）
            self.groupChatManager.saveMessage(aiMessage) { error in
                if let error = error {
                    print("AI返信保存エラー - \(response.oshi.name): \(error.localizedDescription)")
                } else {
                    print("AI返信保存成功 - \(response.oshi.name)")
                }
                
                // 次のレスポンスを送信
                DispatchQueue.main.async {
                    self.sendResponsesSequentially(responses: responses, index: index + 1, completion: completion)
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard !messages.isEmpty else { return }
        
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("bottomMarker", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottomMarker", anchor: .bottom)
        }
    }
    
    private func showRewardAd() {
        // リワード広告表示の実装
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    OshiGroupChatView(groupId: .constant("123"))
}
