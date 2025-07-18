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
        
        // ランダムに返信する推しを選択（1〜2人）
        let respondingMembers = selectedMembers.shuffled().prefix(Int.random(in: 1...min(2, selectedMembers.count)))
        
        let dispatchGroup = DispatchGroup()
        var responses: [(oshi: Oshi, content: String)] = []
        
        for oshi in respondingMembers {
            dispatchGroup.enter()
            
            // 各推しの個性に応じた返信を生成
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
            
            // 少し時間差をつけて返信を表示
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
                    
                    // メッセージを保存
                    self.groupChatManager.saveMessage(aiMessage) { error in
                        if let error = error {
                            print("AI返信保存エラー: \(error.localizedDescription)")
                        }
                    }
                }
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
