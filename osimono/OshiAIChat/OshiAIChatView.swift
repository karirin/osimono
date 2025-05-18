//
//  OshiAIChatView.swift
//  osimono
//
//  Created by Apple on 2025/05/05.
//

import SwiftUI
import OpenAI
import Firebase
import FirebaseAuth
import FirebaseDatabase

// MARK: - 共通クライアント
struct AIClient {
    /// プレビュー中・APIキー未設定時は `nil`
    static let shared: OpenAI? = {
        let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        let plistKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        guard let key = (envKey?.isEmpty == false ? envKey : nil) ??
                        (plistKey?.isEmpty == false ? plistKey : nil) else {
            #if DEBUG
            print("⚠️ OPENAI_API_KEY が取得できませんでした")
            #endif
            return nil
        }
        return OpenAI(apiToken: key)
    }()
}

// MARK: - メインビュー
struct OshiAIChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isFetchingMessages: Bool = true
    @State private var isInitialScrollComplete: Bool = false
    @State private var shouldScrollToBottom: Bool = false
    @State private var showEditPersonality = false
    let oshiItem: OshiItem?
    
    // LINE風カラー設定
    let lineBgColor = Color(UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0))
    let lineGreen = Color(UIColor(red: 0.0, green: 0.68, blue: 0.31, alpha: 1.0))
    let lineHeaderColor = Color(UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0))
    
    @State private var hasMarkedAsRead: Bool = false
    @ObservedObject var viewModel: OshiViewModel
    @State private var currentOshiId: String = ""
    @State private var loadCompleteOshiData: Bool = false
    var showBackButton: Bool = true
    
    init(viewModel: OshiViewModel, oshiItem: OshiItem?, showBackButton: Bool = true) {
        self.viewModel = viewModel
        self.oshiItem = oshiItem
        self.showBackButton = showBackButton
        
        // 初期化時に完全なデータを取得
        _loadCompleteOshiData = State(initialValue: true)
    }

    var body: some View {
        ZStack {
            // 背景色をLINE風に
            lineBgColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // LINE風ヘッダー
                HStack(spacing: 10) {
                     // 戻るボタンを条件付きで表示
                     if showBackButton {
                         Button(action: {
                             generateHapticFeedback()
                             presentationMode.wrappedValue.dismiss()
                         }) {
                             Image(systemName: "chevron.left")
                                 .font(.system(size: 18, weight: .semibold))
                                 .foregroundColor(.blue)
                         }
                     }
                     
                     // プロフィール画像（小さく表示）
                     profileImage
                         .frame(width: 36, height: 36)
                     
                     Text(viewModel.selectedOshi.name)
                         .font(.system(size: 17, weight: .medium))
                     
                     Spacer()
                     
                     // LINE風メニューボタン
                     Button(action: {
                         generateHapticFeedback()
                         showEditPersonality = true
                     }) {
                         Image(systemName: "pencil")
                             .font(.system(size: 20))
                             .foregroundColor(.black)
                     }
                 }
                 .padding(.horizontal)
                 .padding(.vertical, 10)
                 .background(Color.white)
                 .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
                
                // チャットメッセージリスト
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            if messages.isEmpty {
                                Text("会話を始めましょう！")
                                    .foregroundColor(.gray)
                                    .padding(.top, 40)
                            } else {
                                ForEach(messages, id: \.id) { message in
                                    LineChatBubble(message: message, oshiName: viewModel.selectedOshi.name, oshiImageURL: viewModel.selectedOshi.imageUrl)
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
                        if !isFetchingMessages && !messages.isEmpty && !isInitialScrollComplete {
                            proxy.scrollTo("bottomMarker", anchor: .bottom)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isInitialScrollComplete = true
                            }
                        }
                    }
                    .onChange(of: shouldScrollToBottom) { shouldScroll in
                        if shouldScroll && !messages.isEmpty {
                            withAnimation {
                                proxy.scrollTo("bottomMarker", anchor: .bottom)
                            }
                            shouldScrollToBottom = false
                        }
                    }
                }
                
                // LINE風入力エリア
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 10) {
                        
                        // 入力フィールド
                        TextField("\(viewModel.selectedOshi.name)に話しかけてみよう", text: $inputText)
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        // 送信ボタン（LINE風）
                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(inputText.isEmpty || isLoading ? Color.gray.opacity(0.5) : lineGreen)
                        }
                        .disabled(inputText.isEmpty || isLoading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .background(Color.white)
                }
                .opacity(isInitialScrollComplete ? 1 : 0)
            }
            
            // ローディングオーバーレイ
            if !isInitialScrollComplete || isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text(!isInitialScrollComplete ? "チャットを読み込み中..." : "返信を作成中...")
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                    )
            }
        }
        .onAppear {
            // データを完全に取得
            if loadCompleteOshiData {
                loadCompleteOshiData = false
                loadFullOshiData()
            } else if viewModel.selectedOshi.id == "1" {
                loadActualOshiData()
            } else {
                currentOshiId = viewModel.selectedOshi.id
                resetViewState()
                loadMessages()
                markMessagesAsRead()
            }
        }
        .onChange(of: viewModel.selectedOshi.id) { newId in
            if currentOshiId != newId {
                currentOshiId = newId
                resetViewState()
                loadMessages()
            }
        }
        .onDisappear {
            markMessagesAsRead()
        }
        .fullScreenCover(isPresented: $showEditPersonality) {
            // 閉じた後に確実に最新データを取得
            loadOshiData()
        } content: {
            // この部分でFirebaseから直接データを取得
            FirebaseDataLoader(oshiId: viewModel.selectedOshi.id) { loadedOshi in
                EditOshiPersonalityView(
                    viewModel: OshiViewModel(oshi: loadedOshi ?? viewModel.selectedOshi),
                    onSave: { updatedOshi in
                        self.viewModel.selectedOshi = updatedOshi
                        print("編集後の推しデータ: \(updatedOshi.personality ?? "なし")")
                    },
                    onUpdate: {
                        loadOshiData()
                        print("onUpdate呼び出し")
                    }
                )
            }
            .id(UUID())
        }
        .navigationBarHidden(true) // ネイティブナビゲーションバーを非表示
    }
    
    struct FirebaseDataLoader<Content: View>: View {
        let oshiId: String
        let content: (Oshi?) -> Content
        @State private var loadedOshi: Oshi? = nil
        @State private var isLoading: Bool = true
        
        init(oshiId: String, @ViewBuilder content: @escaping (Oshi?) -> Content) {
            self.oshiId = oshiId
            self.content = content
        }
        
        var body: some View {
            ZStack {
                if isLoading {
                    ProgressView()
                } else {
                    content(loadedOshi)
                }
            }
            .onAppear {
                loadOshiData()
            }
        }
        
        private func loadOshiData() {
            guard let userID = Auth.auth().currentUser?.uid else {
                isLoading = false
                return
            }
            
            let dbRef = Database.database().reference().child("oshis").child(userID).child(oshiId)
            dbRef.observeSingleEvent(of: .value) { snapshot in
                guard let data = snapshot.value as? [String: Any] else {
                    isLoading = false
                    return
                }
                
                // 推しデータを構築
                var oshi = Oshi(
                    id: oshiId,
                    name: data["name"] as? String ?? "名前なし",
                    imageUrl: data["imageUrl"] as? String,
                    backgroundImageUrl: data["backgroundImageUrl"] as? String,
                    memo: data["memo"] as? String,
                    createdAt: data["createdAt"] as? TimeInterval
                )
                
                // 追加プロパティを設定
                oshi.personality = data["personality"] as? String
                oshi.speaking_style = data["speaking_style"] as? String
                oshi.birthday = data["birthday"] as? String
                oshi.hometown = data["hometown"] as? String
                oshi.favorite_color = data["favorite_color"] as? String
                oshi.favorite_food = data["favorite_food"] as? String
                oshi.disliked_food = data["disliked_food"] as? String
                oshi.interests = data["interests"] as? [String]
                oshi.gender = data["gender"] as? String
                oshi.height = data["height"] as? Int
                
                DispatchQueue.main.async {
                    self.loadedOshi = oshi
                    self.isLoading = false
                    print("FirebaseDataLoader - データ取得完了: \(oshi.personality ?? "なし")")
                }
            }
        }
    }
    
    private func loadFullOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let oshiRef = Database.database().reference().child("oshis").child(userID).child(viewModel.selectedOshi.id)
        oshiRef.observeSingleEvent(of: .value) { snapshot in
            guard let oshiData = snapshot.value as? [String: Any] else {
                // データが取得できなかった場合は通常の処理を続行
                self.currentOshiId = self.viewModel.selectedOshi.id
                self.resetViewState()
                self.loadMessages()
                self.markMessagesAsRead()
                return
            }
            
            // 推しデータの基本プロパティを設定
            var newOshi = Oshi(
                id: self.viewModel.selectedOshi.id,
                name: oshiData["name"] as? String ?? self.viewModel.selectedOshi.name,
                imageUrl: oshiData["imageUrl"] as? String ?? self.viewModel.selectedOshi.imageUrl,
                backgroundImageUrl: oshiData["backgroundImageUrl"] as? String ?? self.viewModel.selectedOshi.backgroundImageUrl,
                memo: oshiData["memo"] as? String ?? self.viewModel.selectedOshi.memo,
                createdAt: oshiData["createdAt"] as? TimeInterval ?? self.viewModel.selectedOshi.createdAt
            )
            
            // 全てのプロパティを設定
            newOshi.personality = oshiData["personality"] as? String
            newOshi.speaking_style = oshiData["speaking_style"] as? String
            newOshi.birthday = oshiData["birthday"] as? String
            newOshi.hometown = oshiData["hometown"] as? String
            newOshi.favorite_color = oshiData["favorite_color"] as? String
            newOshi.favorite_food = oshiData["favorite_food"] as? String
            newOshi.disliked_food = oshiData["disliked_food"] as? String
            newOshi.interests = oshiData["interests"] as? [String]
            newOshi.gender = oshiData["gender"] as? String
            newOshi.height = oshiData["height"] as? Int
            
            DispatchQueue.main.async {
                self.viewModel.selectedOshi = newOshi
                print("完全なデータ読み込み後: \(newOshi.personality ?? "なし"), \(newOshi.speaking_style ?? "なし")")
                
                // 通常の初期化処理を続行
                self.currentOshiId = newOshi.id
                self.resetViewState()
                self.loadMessages()
                self.markMessagesAsRead()
            }
        }
    }
    
    private func loadActualOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        // まずselectedOshiIdを取得
        let userRef = Database.database().reference().child("users").child(userID)
        userRef.observeSingleEvent(of: .value) { snapshot in
            guard let userData = snapshot.value as? [String: Any],
                  let selectedOshiId = userData["selectedOshiId"] as? String,
                  selectedOshiId != "default" && selectedOshiId != "1" else {
                // 有効なOshiIdがない場合は、最初の推しを取得してみる
                self.loadFirstOshi()
                return
            }
            
            // 選択中の推しデータを取得
            let oshiRef = Database.database().reference().child("oshis").child(userID).child(selectedOshiId)
            oshiRef.observeSingleEvent(of: .value) { snapshot in
                guard let oshiData = snapshot.value as? [String: Any] else {
                    self.loadFirstOshi()
                    return
                }
                
                // 推しデータからOshiオブジェクトを作成
                var oshi = Oshi(
                    id: selectedOshiId,
                    name: oshiData["name"] as? String ?? "名前なし",
                    imageUrl: oshiData["imageUrl"] as? String,
                    backgroundImageUrl: oshiData["backgroundImageUrl"] as? String,
                    memo: oshiData["memo"] as? String,
                    createdAt: oshiData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                )
                
                // 他のプロパティも設定
                oshi.personality = oshiData["personality"] as? String
                oshi.speaking_style = oshiData["speaking_style"] as? String
                // 他のプロパティも同様に設定
                
                // viewModelを更新
                DispatchQueue.main.async {
                    self.viewModel.selectedOshi = oshi
                    self.currentOshiId = oshi.id
                    self.resetViewState()
                    self.loadMessages()
                    self.markMessagesAsRead()
                }
            }
        }
    }
    
    // 最初の推しを取得する関数（オプション）
    private func loadFirstOshi() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let oshisRef = Database.database().reference().child("oshis").child(userID)
        oshisRef.observeSingleEvent(of: .value) { snapshot in
            var firstOshi: Oshi?
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let oshiData = childSnapshot.value as? [String: Any] {
                    let id = childSnapshot.key
                    let name = oshiData["name"] as? String ?? "名前なし"
                    
                    firstOshi = Oshi(
                        id: id,
                        name: name,
                        imageUrl: oshiData["imageUrl"] as? String,
                        backgroundImageUrl: oshiData["backgroundImageUrl"] as? String,
                        memo: oshiData["memo"] as? String,
                        createdAt: oshiData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    )
                    break
                }
            }
            
            if let oshi = firstOshi {
                DispatchQueue.main.async {
                    self.viewModel.selectedOshi = oshi
                    self.currentOshiId = oshi.id
                    self.resetViewState()
                    self.loadMessages()
                    self.markMessagesAsRead()
                    
                    // ユーザーのselectedOshiIdも更新
                    let userRef = Database.database().reference().child("users").child(userID)
                    userRef.updateChildValues(["selectedOshiId": oshi.id])
                }
            }
        }
    }
    
    private func resetViewState() {
        messages = []
        isInitialScrollComplete = false
        isFetchingMessages = true
        isLoading = false
        shouldScrollToBottom = false
        hasMarkedAsRead = false
    }

    private func loadOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("oshis").child(userID).child(viewModel.selectedOshi.id)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else {
                print("データが取得できませんでした")
                return
            }
            
            // 完全に新しいオブジェクトを作成（letからvarに変更）
            var newOshi = Oshi(
                id: self.viewModel.selectedOshi.id,
                name: data["name"] as? String ?? self.viewModel.selectedOshi.name,
                imageUrl: data["imageUrl"] as? String ?? self.viewModel.selectedOshi.imageUrl,
                backgroundImageUrl: data["backgroundImageUrl"] as? String ?? self.viewModel.selectedOshi.backgroundImageUrl,
                memo: data["memo"] as? String ?? self.viewModel.selectedOshi.memo,
                createdAt: data["createdAt"] as? TimeInterval ?? self.viewModel.selectedOshi.createdAt
            )
            
            // すべてのプロパティを設定
            newOshi.personality = data["personality"] as? String
            newOshi.speaking_style = data["speaking_style"] as? String
            newOshi.birthday = data["birthday"] as? String
            newOshi.hometown = data["hometown"] as? String
            newOshi.favorite_color = data["favorite_color"] as? String
            newOshi.favorite_food = data["favorite_food"] as? String
            newOshi.disliked_food = data["disliked_food"] as? String
            newOshi.interests = data["interests"] as? [String]
            newOshi.gender = data["gender"] as? String
            newOshi.height = data["height"] as? Int
            
            DispatchQueue.main.async {
                print("更新前: \(self.viewModel.selectedOshi.personality ?? "なし")")
                print("更新データ: \(newOshi.personality ?? "なし")")
                self.viewModel.selectedOshi = newOshi
                print("更新後: \(self.viewModel.selectedOshi.personality ?? "なし")")
            }
        }
    }

    // プロフィール画像コンポーネント
    private var profileImage: some View {
        Group {
            if let imageUrl = viewModel.selectedOshi.imageUrl, let url = URL(string: imageUrl) {
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
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16)
                                    .foregroundColor(.gray)
                            )
                    }
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private func markMessagesAsRead() {
        ChatDatabaseManager.shared.markMessagesAsRead(for: viewModel.selectedOshi.id) { error in
            if let error = error {
                print("メッセージを既読にできませんでした: \(error.localizedDescription)")
            } else {
                self.hasMarkedAsRead = true
            }
        }
    }
    
    // Firebaseからメッセージを読み込む
    private func loadMessages() {
         isFetchingMessages = true
         isInitialScrollComplete = false // 読み込み開始時にリセット
         
         // 特定のアイテムに関連するチャットを読み込む場合
         if let item = oshiItem {
             // itemのidが存在することを確認
             let itemId = item.id
             
             ChatDatabaseManager.shared.fetchMessages(for: viewModel.selectedOshi.id, itemId: itemId) { fetchedMessages, error in
                 DispatchQueue.main.async {
                     if let error = error {
                         print("メッセージ読み込みエラー: \(error.localizedDescription)")
                         isFetchingMessages = false
                         // エラー時にはローディング解除
                         if messages.isEmpty {
                             isInitialScrollComplete = true
                         }
                         return
                     }
                     
                     if let messages = fetchedMessages, !messages.isEmpty {
                         self.messages = messages
                         isFetchingMessages = false
                         // メッセージが存在するが空の場合は即座にローディング解除
                         if messages.isEmpty {
                             isInitialScrollComplete = true
                         }
                     } else {
                         addInitialMessage(for: item)
                     }
                 }
             }
         } else {
             // 推し全体のチャット履歴を読み込む
             ChatDatabaseManager.shared.fetchMessages(for: viewModel.selectedOshi.id) { fetchedMessages, error in
                 DispatchQueue.main.async {
                     if let error = error {
                         print("メッセージ読み込みエラー: \(error.localizedDescription)")
                         isFetchingMessages = false
                         // エラー時にはローディング解除
                         if messages.isEmpty {
                             isInitialScrollComplete = true
                         }
                         return
                     }
                     
                     if let messages = fetchedMessages, !messages.isEmpty {
                         self.messages = messages
                         isFetchingMessages = false
                         // メッセージが空の場合は即座にローディング解除
                         if messages.isEmpty {
                             isInitialScrollComplete = true
                         }
                     } else {
                         // チャット履歴がない場合、ウェルカムメッセージを追加
                         addWelcomeMessage()
                         isFetchingMessages = false
                         // isInitialScrollComplete はonChange内で更新される
                     }
                 }
             }
         }
     }
    
    // 初期メッセージ（アイテムについて）
    private func addInitialMessage(for item: OshiItem) {
        isLoading = true
        
        AIMessageGenerator.shared.generateInitialMessage(for: viewModel.selectedOshi, item: item) { content, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("AIメッセージ生成エラー: \(error.localizedDescription)")
                    // エラー時には簡単なメッセージを表示
                    addDefaultWelcomeMessage()
                    return
                }
                
                guard let content = content else {
                    // コンテンツがない場合も簡単なメッセージを表示
                    addDefaultWelcomeMessage()
                    return
                }
                
                // AIからのメッセージを作成・保存
                let messageId = UUID().uuidString
                let message = ChatMessage(
                    id: messageId,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: viewModel.selectedOshi.id,
                    itemId: item.id
                )
                
                // メッセージをデータベースに保存
                ChatDatabaseManager.shared.saveMessage(message) { error in
                    if let error = error {
                        print("メッセージ保存エラー: \(error.localizedDescription)")
                    }
                }
                
                // 画面に表示
                messages.append(message)
                isFetchingMessages = false  // ここでフェッチ完了を設定
            }
        }
    }
    
    // ウェルカムメッセージ
    private func addWelcomeMessage() {
        let messageId = UUID().uuidString
        let message = ChatMessage(
            id: messageId,
            content: "こんにちは！\(viewModel.selectedOshi.name)だよ！いつも応援してくれてありがとう✨\n何か質問があれば話しかけてね！",
            isUser: false,
            timestamp: Date().timeIntervalSince1970,
            oshiId: viewModel.selectedOshi.id
        )
        
        // メッセージをデータベースに保存
        ChatDatabaseManager.shared.saveMessage(message) { error in
            if let error = error {
                print("メッセージ保存エラー: \(error.localizedDescription)")
            }
        }
        
        // 画面に表示
        messages.append(message)
    }
    
    // エラー時などのデフォルトメッセージ
    private func addDefaultWelcomeMessage() {
        let messageId = UUID().uuidString
        let message = ChatMessage(
            id: messageId,
            content: "こんにちは！\(viewModel.selectedOshi.name)だよ！何か聞きたいことがあれば教えてね💕",
            isUser: false,
            timestamp: Date().timeIntervalSince1970,
            oshiId: viewModel.selectedOshi.id
        )
        
        messages.append(message)
        
        // データベースに保存
        ChatDatabaseManager.shared.saveMessage(message) { error in
            if let error = error {
                print("メッセージ保存エラー: \(error.localizedDescription)")
            }
        }
    }
    
    // メッセージ送信
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        // ユーザーメッセージを作成
        let userMessageId = UUID().uuidString
        let userMessage = ChatMessage(
            id: userMessageId,
            content: inputText,
            isUser: true,
            timestamp: Date().timeIntervalSince1970,
            oshiId: viewModel.selectedOshi.id,
            itemId: oshiItem?.id
        )
        
        // 入力フィールドをクリア（メッセージ追加前に行う）
        let userInput = inputText
        inputText = ""
        
        // メッセージをUIに追加
        messages.append(userMessage)
        
        // 送信後にスクロールするようフラグをセット
        shouldScrollToBottom = true
        
        // メッセージをデータベースに保存
        ChatDatabaseManager.shared.saveMessage(userMessage) { error in
            if let error = error {
                print("ユーザーメッセージ保存エラー: \(error.localizedDescription)")
            }
        }
        
        // AIの返信を生成
        isLoading = true
        
        AIMessageGenerator.shared.generateResponse(for: userInput, oshi: viewModel.selectedOshi, chatHistory: messages) { content, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("AI返信生成エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let content = content else {
                    print("AI返信が空です")
                    return
                }
                
                // AIからの返信を作成
                let aiMessageId = UUID().uuidString
                let aiMessage = ChatMessage(
                    id: aiMessageId,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: viewModel.selectedOshi.id,
                    itemId: oshiItem?.id
                )
                
                // メッセージをUIに追加
                messages.append(aiMessage)
                
                // AI返信後にもスクロールするようフラグをセット
                shouldScrollToBottom = true
                
                // メッセージをデータベースに保存
                ChatDatabaseManager.shared.saveMessage(aiMessage) { error in
                    if let error = error {
                        print("AI返信保存エラー: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.markMessagesAsRead()
        }
    }
}

struct LineChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    let oshiImageURL: String?
    let primaryColor = Color(.systemPink) // ピンク
    let accentColor = Color(.purple) // 紫
    
    // LINE風カラー
    let lineGreen = Color(UIColor(red: 0.0, green: 0.68, blue: 0.31, alpha: 1.0))
    
    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                // 相手のメッセージの場合、アイコンを表示（オプション）
                if !message.isUser {
                    Group {
                        if let imageUrl = oshiImageURL, let url = URL(string: imageUrl) {
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
                                            Image(systemName: "person.crop.circle")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 16)
                                                .foregroundColor(.gray)
                                        )
                                }
                            }
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "person.crop.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                        .frame(width: 30, height: 30)
                        .padding(.top,5)
                }
                
            
            if message.isUser {
                Spacer()
            }
                // メッセージ本文
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        (message.isUser
                         ? AnyShapeStyle(primaryColor.opacity(0.8))
//                         AnyShapeStyle(LinearGradient(gradient: Gradient(colors: [primaryColor.opacity(1), accentColor.opacity(1)]),
//                                                         startPoint: .topLeading,
//                                                         endPoint: .bottomTrailing))
                         : AnyShapeStyle(Color.white))
                    )
                    .foregroundColor(message.isUser ? .white : .black)
                    .cornerRadius(18)
                if !message.isUser {
                    Spacer()
                }
            }
            
            // タイムスタンプ
            Text(formatDate(timestamp: message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.horizontal, message.isUser ? 0 : 38)
        }
        .padding(.horizontal, 0)
        .padding(.vertical, 2)
    }
    
    // タイムスタンプのフォーマット
    private func formatDate(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        // 今日の日付と比較
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isUser {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("あなた")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                    
                    Text(message.content)
                        .padding(12)
                        .background(Color(.systemBlue))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(oshiName)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
                    
                    Text(message.content)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - プレビュー
#Preview {
    let dummyOshi = Oshi(
        id: "2E5C7468-E2AB-41D6-B7CE-901674CB2973",
        name: "テストの推し",
        imageUrl: "https://firebasestorage.googleapis.com:443/v0/b/osimono.firebasestorage.app/o/oshis%2FbZwehJdm4RTQ7JWjl20yaxTWS7l2%2F2E5C7468-E2AB-41D6-B7CE-901674CB2973%2Fprofile.jpg?alt=media&token=37b4ccb5-430b-4db7-94b9-d5e2c389c402",
        backgroundImageUrl: nil,
        memo: nil,
        createdAt: Date().timeIntervalSince1970
    )
//    OshiAIChatView(viewModel.selectedOshi: .constant(dummyOshi), oshiItem: nil)
    TopView()
}
