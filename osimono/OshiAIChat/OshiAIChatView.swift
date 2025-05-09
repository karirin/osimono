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
    let selectedOshi: Oshi
    let oshiItem: OshiItem? // チャットのきっかけとなったアイテム
    
    let primaryColor = Color(.systemPink)
    @State private var hasMarkedAsRead: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // チャットメッセージリスト
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 12) {
                                if isFetchingMessages {
                                    ProgressView("メッセージを読み込み中...")
                                        .padding()
                                } else if messages.isEmpty {
                                    Text("会話を始めましょう！")
                                        .foregroundColor(.gray)
                                        .padding(.top, 40)
                                } else {
                                    ForEach(messages, id: \.id) { message in
                                        ChatBubble(message: message, oshiName: selectedOshi.name)
                                            .id(message.id)
                                    }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: messages.count) { _ in
                            if !messages.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // 入力エリア
                    HStack(spacing: 12) {
                        TextField("\(selectedOshi.name)に話しかけてみよう", text: $inputText)
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(25)
                        
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(inputText.isEmpty || isLoading ? Color.gray : primaryColor)
                                .clipShape(Circle())
                        }
                        .disabled(inputText.isEmpty || isLoading)
                    }
                    .padding()
                }
                
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay(
                            VStack {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text("返信を作成中...")
                                    .foregroundColor(.white)
                                    .padding(.top, 10)
                            }
                        )
                }
            }
            .navigationTitle("\(selectedOshi.name)とチャット")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            loadMessages()
            markMessagesAsRead()
        }
        .onDisappear {
            // チャットを閉じる際にも最新状態を既読にマーク
            markMessagesAsRead()
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
        
        // 特定のアイテムに関連するチャットを読み込む場合
        if let item = oshiItem {
            // itemのidが存在することを確認
            let itemId = item.id
            
            ChatDatabaseManager.shared.fetchMessages(for: selectedOshi.id, itemId: itemId) { fetchedMessages, error in
                DispatchQueue.main.async {
                    isFetchingMessages = false
                    
                    if let error = error {
                        print("メッセージ読み込みエラー: \(error.localizedDescription)")
                        return
                    }
                    
                    if let messages = fetchedMessages, !messages.isEmpty {
                        self.messages = messages
                    } else {
                        // 関連するメッセージがない場合、初期メッセージを追加
                        addInitialMessage(for: item)
                    }
                }
            }
        } else {
            // 推し全体のチャット履歴を読み込む
            ChatDatabaseManager.shared.fetchMessages(for: selectedOshi.id) { fetchedMessages, error in
                DispatchQueue.main.async {
                    isFetchingMessages = false
                    
                    if let error = error {
                        print("メッセージ読み込みエラー: \(error.localizedDescription)")
                        return
                    }
                    
                    if let messages = fetchedMessages, !messages.isEmpty {
                        self.messages = messages
                    } else {
                        // チャット履歴がない場合、ウェルカムメッセージを追加
                        addWelcomeMessage()
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
        
        // メッセージをUIに追加
        messages.append(userMessage)
        
        // メッセージをデータベースに保存
        ChatDatabaseManager.shared.saveMessage(userMessage) { error in
            if let error = error {
                print("ユーザーメッセージ保存エラー: \(error.localizedDescription)")
            }
        }
        
        // 入力フィールドをクリア
        let userInput = inputText
        inputText = ""
        
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
        id: "1",
        name: "テストの推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: nil,
        createdAt: Date().timeIntervalSince1970
    )
    return OshiAIChatView(selectedOshi: dummyOshi, oshiItem: nil)
}
