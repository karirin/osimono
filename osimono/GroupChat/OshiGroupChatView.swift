//
//  OshiGroupChatView.swift
//  osimono
//
//  複数の推しとのグループチャット機能 - 編集機能修正版
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
    @State private var isInitialScrollComplete: Bool = false
    @State private var shouldScrollToBottom: Bool = false
    @State private var showMemberSelection: Bool = false
    @State private var showMessageLimitModal = false
    @State private var showRewardCompletedModal = false
    @State private var rewardAmount = 0
    
    // 編集機能関連の新しい状態
    @State private var showEditGroupSheet = false
    @State private var groupInfo: GroupChatInfo?
    
    // 選択された推しメンバー
    @State private var selectedMembers: [Oshi] = []
    @State private var allOshiList: [Oshi] = []
    
    // グループチャット情報
    let groupId: String
    @State private var groupName: String = ""
    
    // キーボード関連
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    // 既読管理用
    @State private var hasMarkedAsRead: Bool = false
    
    // LINE風カラー設定
    let lineBgColor = Color(UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0))
    let lineGreen = Color(UIColor(red: 0.0, green: 0.68, blue: 0.31, alpha: 1.0))
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        ZStack {
            chatContent
            
            if showMemberSelection {
                GroupMemberSelectionView(
                    isPresented: $showMemberSelection,
                    allOshiList: allOshiList,
                    selectedMembers: $selectedMembers,
                    onSave: { updateGroupMembers() }
                )
            }
            
            if showMessageLimitModal {
                MessageLimitModal(
                    isPresented: $showMessageLimitModal,
                    onWatchAd: { showRewardAd() },
                    remainingMessages: MessageLimitManager.shared.getRemainingMessages()
                )
            }
            
            if showRewardCompletedModal {
                RewardCompletedModal(
                    isPresented: $showRewardCompletedModal,
                    rewardAmount: rewardAmount
                )
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeInOut(duration: 0.3)) { keyboardHeight = height }
        }
        .onAppear {
            setupGroupChat()
            markAsReadWhenAppear()
        }
        .onDisappear {
            markAsReadWhenDisappear()
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
                        self.loadGroupMembers()
                    }
                )
            }
        }
    }
    
    private var chatContent: some View {
        ZStack {
            lineBgColor.edgesIgnoringSafeArea(.all)
            
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
    }
    
    private var headerView: some View {
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
                
                // グループアイコン（複数の推しの画像を重ねて表示）
                groupIconView
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(groupName.isEmpty ? "グループチャット" : groupName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.black)
                    
                    Text("\(selectedMembers.count)人のメンバー")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 編集ボタン（新規追加）
                Button(action: {
                    generateHapticFeedback()
                    showEditGroupSheet = true
                }) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 30))
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
                .opacity(isInitialScrollComplete ? 1 : 0)
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
        .opacity(isInitialScrollComplete ? 1 : 0)
    }
    
    // MARK: - 既読マーク関連メソッド
    
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
        loadOshiList()
        loadMessages()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadGroupMembers()
        }
        isInitialScrollComplete = true
    }
    
    private func loadOshiList() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
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
            }
        }
    }
    
    private func loadMessages() {
        groupChatManager.fetchMessages(for: groupId) { fetchedMessages, error in
            DispatchQueue.main.async {
                if let messages = fetchedMessages {
                    self.messages = messages
                    self.markAsReadAfterDelay()
                }
            }
        }
    }
    
    private func loadGroupMembers() {
        groupChatManager.fetchGroupMembers(for: groupId) { memberIds, error in
            DispatchQueue.main.async {
                if let memberIds = memberIds, !memberIds.isEmpty {
                    self.selectedMembers = self.allOshiList.filter { memberIds.contains($0.id) }
                } else {
                    self.selectedMembers = []
                }
                
                // グループ情報を読み込み（編集機能のため）
                self.loadGroupInfo()
            }
        }
    }
    
    // グループ情報を取得する修正版メソッド（編集用のgroupInfoも設定）
    private func loadGroupInfo() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
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
        guard !inputText.isEmpty, !selectedMembers.isEmpty else { return }
        
        // メッセージ制限チェック
        if MessageLimitManager.shared.hasReachedLimit() {
            showMessageLimitModal = true
            return
        }
        
        MessageLimitManager.shared.incrementCount()
        
        // ユーザーメッセージを作成
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
        
        messages.append(userMessage)
        shouldScrollToBottom = true
        
        // メッセージを保存
        groupChatManager.saveMessage(userMessage) { error in
            if let error = error {
                print("メッセージ保存エラー: \(error.localizedDescription)")
            }
        }
        
        // AI返信を生成（複数の推しから）
        generateGroupResponse(for: userInput)
    }
    
    // ... 残りのメソッドは既存のまま（generateGroupResponse等）...
    
    private func generateGroupResponse(for userInput: String) {
        guard !selectedMembers.isEmpty else { return }
        
        isLoading = true
        
        // 最初の返信メンバーを選択
        let initialRespondingMembers = selectedMembers.shuffled().prefix(Int.random(in: 1...min(2, selectedMembers.count)))
        
        generateInitialResponses(for: userInput, members: Array(initialRespondingMembers)) {
            self.checkForAIReactions()
        }
    }
    
    private func checkForAIReactions() {
        let reactionProbability = 1.0
        
        guard let lastMessage = messages.last,
              !lastMessage.isUser,
              let lastSender = selectedMembers.first(where: { $0.id == lastMessage.senderId }) else {
            return
        }
        
        let otherMembers = selectedMembers.filter { $0.id != lastMessage.senderId }
        
        for member in otherMembers {
            if Double.random(in: 0...1) < reactionProbability {
                let delay = Double.random(in: 2.0...5.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.generateAIReaction(reactor: member, originalMessage: lastMessage, originalSender: lastSender)
                }
                
                break
            }
        }
    }
    
    private func generateAIReaction(reactor: Oshi, originalMessage: GroupChatMessage, originalSender: Oshi) {
        let reactionPrompt = """
        \(originalSender.name)が「\(originalMessage.content)」と言いました。
        あなた（\(reactor.name)）は同じグループの仲間として、この発言に短く自然に反応してください。
        リアクションは1〜2文程度の短いものにしてください。
        """
        
        let chatHistory = Array(messages.suffix(3).map { $0.toChatMessage() })
        
        AIMessageGenerator.shared.generateResponse(
            for: reactionPrompt,
            oshi: reactor,
            chatHistory: chatHistory
        ) { content, error in
            guard let content = content,
                  !content.isEmpty else { return }
            
            DispatchQueue.main.async {
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
                
                self.messages.append(reactionMessage)
                self.shouldScrollToBottom = true
                
                self.groupChatManager.saveMessage(reactionMessage) { error in
                    if let error = error {
                        print("AI反応保存エラー: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func generateInitialResponses(for userInput: String, members: [Oshi], completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()
        var responses: [(oshi: Oshi, content: String)] = []
        
        for oshi in members {
            dispatchGroup.enter()
            
            AIMessageGenerator.shared.generateResponse(
                for: userInput,
                oshi: oshi,
                chatHistory: Array(messages.suffix(5).compactMap { message in
                    ChatMessage(
                        id: message.id,
                        content: message.content,
                        isUser: message.isUser,
                        timestamp: message.timestamp,
                        oshiId: message.senderId,
                        itemId: nil
                    )
                })
            ) { content, error in
                if let content = content {
                    responses.append((oshi: oshi, content: content))
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
            
            for (index, response) in responses.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5) {
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
                    
                    self.messages.append(aiMessage)
                    self.shouldScrollToBottom = true
                    
                    self.groupChatManager.saveMessage(aiMessage) { error in
                        if let error = error {
                            print("AI返信保存エラー: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(responses.count) * 1.5 + 0.5) {
                completion()
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if !messages.isEmpty && isInitialScrollComplete {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("bottomMarker", anchor: .bottom)
            }
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
    OshiGroupChatView(groupId: "preview-group")
}
