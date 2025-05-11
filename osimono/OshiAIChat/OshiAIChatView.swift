//
//  OshiAIChatView.swift
//  osimono
//
//  Created by Apple on 2025/05/05.
//

import SwiftUI
import OpenAI
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
    let selectedOshi: Oshi
    let oshiItem: OshiItem?
    
    // LINE風カラー設定
    let lineBgColor = Color(UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1.0))
    let lineGreen = Color(UIColor(red: 0.0, green: 0.68, blue: 0.31, alpha: 1.0))
    let lineHeaderColor = Color(UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0))
    
    @State private var hasMarkedAsRead: Bool = false
    
    var body: some View {
        ZStack {
            // 背景色をLINE風に
            lineBgColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // LINE風ヘッダー
                HStack(spacing: 10) {
                    Button(action: {
                        generateHapticFeedback()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    // プロフィール画像（小さく表示）
                    profileImage
                        .frame(width: 36, height: 36)
                    
                    Text(selectedOshi.name)
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
                                    LineChatBubble(message: message, oshiName: selectedOshi.name, oshiImageURL: selectedOshi.imageUrl)
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
                        TextField("\(selectedOshi.name)に話しかけてみよう", text: $inputText)
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
            loadMessages()
            markMessagesAsRead()
        }
        .onDisappear {
            markMessagesAsRead()
        }
        .fullScreenCover(isPresented: $showEditPersonality) {
            EditOshiPersonalityView(oshi: selectedOshi, onUpdate: {
                // 必要に応じて更新時の処理を追加
                // 例えば、推しの情報を再読み込みするなど
            })
        }
        .navigationBarHidden(true) // ネイティブナビゲーションバーを非表示
    }
    
    // プロフィール画像コンポーネント
    private var profileImage: some View {
        Group {
            if let imageUrl = selectedOshi.imageUrl, let url = URL(string: imageUrl) {
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
        ChatDatabaseManager.shared.markMessagesAsRead(for: selectedOshi.id) { error in
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
             
             ChatDatabaseManager.shared.fetchMessages(for: selectedOshi.id, itemId: itemId) { fetchedMessages, error in
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
                         // 関連するメッセージがない場合、初期メッセージを追加
                         addInitialMessage(for: item)
                         // 注意: addInitialMessageの中でisFetchingMessagesがfalseに設定される
                     }
                 }
             }
         } else {
             // 推し全体のチャット履歴を読み込む
             ChatDatabaseManager.shared.fetchMessages(for: selectedOshi.id) { fetchedMessages, error in
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
        
        AIMessageGenerator.shared.generateInitialMessage(for: selectedOshi, item: item) { content, error in
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
                    oshiId: selectedOshi.id,
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
            content: "こんにちは！\(selectedOshi.name)だよ！いつも応援してくれてありがとう✨\n何か質問があれば話しかけてね！",
            isUser: false,
            timestamp: Date().timeIntervalSince1970,
            oshiId: selectedOshi.id
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
            content: "こんにちは！\(selectedOshi.name)だよ！何か聞きたいことがあれば教えてね💕",
            isUser: false,
            timestamp: Date().timeIntervalSince1970,
            oshiId: selectedOshi.id
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
            oshiId: selectedOshi.id,
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
        
        AIMessageGenerator.shared.generateResponse(for: userInput, oshi: selectedOshi, chatHistory: messages) { content, error in
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
                    oshiId: selectedOshi.id,
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
                        message.isUser
                        ? lineGreen  // 自分のメッセージは緑色
                        : Color.white // 相手のメッセージは白色
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
    return OshiAIChatView(selectedOshi: dummyOshi, oshiItem: nil)
//    TopView()
}
