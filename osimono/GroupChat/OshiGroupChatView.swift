//
//  OshiGroupChatView.swift
//  osimono
//
//  複数の推しとのグループチャット機能
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
    
    // 選択された推しメンバー
    @State private var selectedMembers: [Oshi] = []
    @State private var allOshiList: [Oshi] = []
    
    // グループチャット情報
    let groupId: String
    @State private var groupName: String = ""
    
    // キーボード関連
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
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
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeInOut(duration: 0.3)) { keyboardHeight = height }
        }
        .onAppear {
            setupGroupChat()
        }
        .navigationBarHidden(true)
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
                
                // メンバー編集ボタン
                Button(action: {
                    generateHapticFeedback()
                    showMemberSelection = true
                }) {
                    Image(systemName: "person.2.circle")
                        .font(.system(size: 20))
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
    
    private func setupGroupChat() {
        loadOshiList()
        loadMessages()
        // グループメンバーの読み込みを後回しにして、推しリストが読み込まれてから実行
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
                // ★ 修正：自動的に全員選択しないように変更
                // グループメンバーはFirebaseから読み込まれるか、手動で選択されるまで空のままにする
            }
        }
    }
    
    private func loadMessages() {
        groupChatManager.fetchMessages(for: groupId) { fetchedMessages, error in
            DispatchQueue.main.async {
                if let messages = fetchedMessages {
                    self.messages = messages
                }
            }
        }
    }
    
    private func loadGroupMembers() {
        groupChatManager.fetchGroupMembers(for: groupId) { memberIds, error in
            DispatchQueue.main.async {
                if let memberIds = memberIds, !memberIds.isEmpty {
                    // Firebaseから取得したメンバーIDに基づいて推しを選択
                    self.selectedMembers = self.allOshiList.filter { memberIds.contains($0.id) }
                } else {
                    // メンバーが設定されていない場合は空のまま
                    self.selectedMembers = []
                }
                
                // グループ名も取得
                self.loadGroupInfo()
            }
        }
    }
    
    // グループ情報を取得する新しいメソッド
    private func loadGroupInfo() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let groupInfoRef = Database.database().reference()
            .child("groupChats")
            .child(userId)
            .child(groupId)
            .child("info")
        
        groupInfoRef.observeSingleEvent(of: .value) { snapshot in
            if let groupData = snapshot.value as? [String: Any],
               let name = groupData["name"] as? String {
                DispatchQueue.main.async {
                    self.groupName = name
                }
            }
        }
    }
    
    private func updateGroupMembers() {
        let memberIds = selectedMembers.map { $0.id }
        groupChatManager.updateGroupMembers(groupId: groupId, memberIds: memberIds) { error in
            if let error = error {
                print("グループメンバー更新エラー: \(error.localizedDescription)")
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
    
    private func generateGroupResponse(for userInput: String) {
        guard !selectedMembers.isEmpty else { return }
        
        isLoading = true
        
        // 最初の返信メンバーを選択
        let initialRespondingMembers = selectedMembers.shuffled().prefix(Int.random(in: 1...min(2, selectedMembers.count)))
        
        // [weak self] を削除
        generateInitialResponses(for: userInput, members: Array(initialRespondingMembers)) {
            // 初回返信完了後、AI同士の反応をチェック
            self.checkForAIReactions()
        }
    }
    
    private func checkForAIReactions() {
        // 反応の確率（30%程度）
        let reactionProbability = 1.0
        
        // 最新のAIメッセージを取得
        guard let lastMessage = messages.last,
              !lastMessage.isUser,
              let lastSender = selectedMembers.first(where: { $0.id == lastMessage.senderId }) else {
            return
        }
        
        // 他のメンバーが反応するかチェック
        let otherMembers = selectedMembers.filter { $0.id != lastMessage.senderId }
        
        for member in otherMembers {
            // 各メンバーが反応する確率をチェック
            if Double.random(in: 0...1) < reactionProbability {
                // 反応を生成（少し遅延をつけて）
                let delay = Double.random(in: 2.0...5.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.generateAIReaction(reactor: member, originalMessage: lastMessage, originalSender: lastSender)
                }
                
                break // 一度に一人だけ反応
            }
        }
    }
    
    private func generateAIReaction(reactor: Oshi, originalMessage: GroupChatMessage, originalSender: Oshi) {
        let reactionPrompt = """
        \(originalSender.name)が「\(originalMessage.content)」と言いました。
        あなた（\(reactor.name)）は同じグループの仲間として、この発言に短く自然に反応してください。
        リアクションは1〜2文程度の短いものにしてください。
        """
        
        // 簡潔な型変換
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
                
                // メッセージを保存
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
            
            // 時間差をつけて返信を表示
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
            
            // 最後のメッセージ表示後に完了通知
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(responses.count) * 1.5 + 0.5) {
                completion()
            }
        }
    }
    
    private func determineConversationPattern() -> ConversationPattern {
        let patterns: [(ConversationPattern, Double)] = [
            (.aiToAI, 0.3),      // 30%の確率でAI同士
            (.aiToGroup, 0.4),   // 40%の確率でグループ全体
            (.aiToUser, 0.3)     // 30%の確率でユーザーのみ
        ]
        
        let random = Double.random(in: 0...1)
        var cumulative = 0.0
        
        for (pattern, probability) in patterns {
            cumulative += probability
            if random <= cumulative {
                return pattern
            }
        }
        
        return .aiToUser // デフォルト
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if !messages.isEmpty && isInitialScrollComplete {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo("bottomMarker", anchor: .bottom)
            }
        }
    }
    
    private func scheduleRandomConversation() {
        // 5〜15分後にランダムで会話を開始
        let delay = Double.random(in: 300...900) // 5-15分
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.selectedMembers.count >= 2 {
                // 20%の確率で自動会話を開始
                if Double.random(in: 0...1) < 0.2 {
                    self.initiateAIConversation()
                }
            }
            
            // 次の会話をスケジュール
            self.scheduleRandomConversation()
        }
    }
    
    private func generateConversationStarter() -> String {
        let topics = [
            "最近見た映画",
            "今日の天気",
            "好きな音楽",
            "おすすめの本",
            "週末の予定",
            "美味しかった食べ物",
            "面白いニュース",
            "趣味の話"
        ]
        return topics.randomElement() ?? "最近の出来事"
    }

    private func generateGroupTopic() -> String {
        let topics = [
            "みんなでできる楽しいこと",
            "今度の休日の計画",
            "おすすめのスポット",
            "一緒に見たい映画",
            "グループでやりたいこと",
            "みんなの近況報告"
        ]
        return topics.randomElement() ?? "みんなでできること"
    }

    private func generateUserDirectedTopic() -> String {
        let topics = [
            "最近どう？",
            "今日は何をしてた？",
            "何か面白いことあった？",
            "おすすめの話",
            "最近気になること",
            "今度一緒にしたいこと"
        ]
        return topics.randomElement() ?? "最近の様子"
    }
    
    private func initiateAIConversation() {
        guard selectedMembers.count >= 2 else { return }
        
        let conversationPattern = determineConversationPattern()
        
        switch conversationPattern {
        case .aiToAI:
            startAIToAIConversation()
        case .aiToGroup:
            startAIToGroupConversation()
        case .aiToUser:
            startAIToUserConversation()
        }
    }

    private func startAIToAIConversation() {
        let participants = selectedMembers.shuffled().prefix(2)
        guard participants.count == 2 else { return }
        
        let speaker = participants[0]
        let listener = participants[1]
        let conversationStarter = generateConversationStarter()
        
        AIMessageGenerator.shared.generateAIToAIMessage(
            speaker: speaker,
            listener: listener,
            topic: conversationStarter,
            chatHistory: Array(messages.suffix(3).map { $0.toChatMessage() })
        ) { content, error in // [weak self] を削除
            guard let content = content, !content.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.addAIMessage(from: speaker, content: content)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.generateAIResponse(from: listener, to: speaker, originalMessage: content)
                }
            }
        }
    }

    // startAIToGroupConversation() メソッドを修正
    private func startAIToGroupConversation() {
        guard let speaker = selectedMembers.randomElement() else { return }
        let groupTopic = generateGroupTopic()
        
        AIMessageGenerator.shared.generateAIToGroupMessage(
            speaker: speaker,
            groupMembers: selectedMembers,
            topic: groupTopic,
            chatHistory: Array(messages.suffix(3).map { $0.toChatMessage() })
        ) { content, error in // [weak self] を削除
            guard let content = content, !content.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.addAIMessage(from: speaker, content: content)
                self.checkForGroupReactions(originalSpeaker: speaker, message: content)
            }
        }
    }

    // startAIToUserConversation() メソッドを修正
    private func startAIToUserConversation() {
        guard let speaker = selectedMembers.randomElement() else { return }
        let userTopic = generateUserDirectedTopic()
        
        AIMessageGenerator.shared.generateAIToUserMessage(
            speaker: speaker,
            topic: userTopic,
            chatHistory: Array(messages.suffix(3).map { $0.toChatMessage() })
        ) { content, error in // [weak self] を削除
            guard let content = content, !content.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.addAIMessage(from: speaker, content: content)
            }
        }
    }
    
    private func addAIMessage(from oshi: Oshi, content: String) {
        let message = GroupChatMessage(
            id: UUID().uuidString,
            content: content,
            isUser: false,
            timestamp: Date().timeIntervalSince1970,
            groupId: groupId,
            senderId: oshi.id,
            senderName: oshi.name,
            senderImageUrl: oshi.imageUrl
        )
        
        messages.append(message)
        shouldScrollToBottom = true
        
        // メッセージを保存
        groupChatManager.saveMessage(message) { error in
            if let error = error {
                print("AIメッセージ保存エラー: \(error.localizedDescription)")
            }
        }
    }

    private func generateAIResponse(from responder: Oshi, to originalSpeaker: Oshi, originalMessage: String) {
        let responsePrompt = """
        \(originalSpeaker.name)が「\(originalMessage)」と言いました。
        あなた（\(responder.name)）は\(originalSpeaker.name)に対して自然に返答してください。
        返答は1〜2文程度の短いものにしてください。
        """
        
        let chatHistory = Array(messages.suffix(3).map { $0.toChatMessage() })
        
        AIMessageGenerator.shared.generateResponse(
            for: responsePrompt,
            oshi: responder,
            chatHistory: chatHistory
        ) { content, error in
            guard let content = content, !content.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.addAIMessage(from: responder, content: content)
            }
        }
    }

    private func checkForGroupReactions(originalSpeaker: Oshi, message: String) {
        let otherMembers = selectedMembers.filter { $0.id != originalSpeaker.id }
        
        // 30%の確率で他のメンバーが反応
        for member in otherMembers {
            if Double.random(in: 0...1) < 0.3 {
                let delay = Double.random(in: 2.0...5.0)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.generateGroupReaction(reactor: member, originalSpeaker: originalSpeaker, originalMessage: message)
                }
                
                break // 一度に一人だけ反応
            }
        }
    }

    private func generateGroupReaction(reactor: Oshi, originalSpeaker: Oshi, originalMessage: String) {
        let reactionPrompt = """
        \(originalSpeaker.name)がグループに向けて「\(originalMessage)」と言いました。
        あなた（\(reactor.name)）はグループの一員として、この発言に短く自然に反応してください。
        反応は1〜2文程度の短いものにしてください。
        """
        
        let chatHistory = Array(messages.suffix(3).map { $0.toChatMessage() })
        
        AIMessageGenerator.shared.generateResponse(
            for: reactionPrompt,
            oshi: reactor,
            chatHistory: chatHistory
        ) { content, error in
            guard let content = content, !content.isEmpty else { return }
            
            DispatchQueue.main.async {
                self.addAIMessage(from: reactor, content: content)
            }
        }
    }
    
    private func showRewardAd() {
        // リワード広告表示の実装
        // 既存のOshiAIChatViewのshowRewardAd()メソッドを参考に実装
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    OshiGroupChatView(groupId: "preview-group")
}
