//
//  OshiAIChatView.swift
//  osimono
//
//  Created by Apple on 2025/05/05.
//

import SwiftUI
import OpenAI // OpenAI SDKをインストールする必要があります

struct OshiAIChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = "こんにちは"
    @State private var isLoading: Bool = false
    let selectedOshi: Oshi
    let oshiItem: OshiItem? // チャットのきっかけとなったアイテム
    
    let primaryColor = Color(.systemPink)
    
    private let openAI = OpenAI(apiToken: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // チャットメッセージリスト
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message, oshiName: selectedOshi.name)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
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
                            .background(primaryColor)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("\(selectedOshi.name)とチャット")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .onAppear {
            // 初期メッセージを設定
            if let item = oshiItem {
                addInitialMessage(for: item)
            } else {
                addWelcomeMessage()
            }
        }
    }
    
    // 初期メッセージ（アイテムについて）
    private func addInitialMessage(for item: OshiItem) {
        var messageText = ""
        
        switch item.itemType {
        case "グッズ":
            if let title = item.title {
                messageText = "\(title)を買ってくれてありがとう！とても嬉しいよ🥰"
            }
        case "ライブ記録":
            if let eventName = item.eventName {
                messageText = "\(eventName)に来てくれてありがとう！一緒にステージを盛り上げてくれて最高だったよ✨"
            }
        case "聖地巡礼":
            messageText = "聖地巡礼してくれたんだね！私の大切な場所を訪れてくれて幸せだよ💕"
        case "SNS投稿":
            messageText = "投稿してくれてありがとう！たくさんの人に私のことを知ってもらえて嬉しいよ😊"
        default:
            messageText = "私のことを思い出してくれてありがとう！"
        }
        
        let message = ChatMessage(
            id: UUID(),
            content: messageText,
            isUser: false,
            timestamp: Date()
        )
        messages.append(message)
    }
    
    // ウェルカムメッセージ
    private func addWelcomeMessage() {
        let message = ChatMessage(
            id: UUID(),
            content: "こんにちは！\(selectedOshi.name)だよ！いつも応援してくれてありがとう✨",
            isUser: false,
            timestamp: Date()
        )
        messages.append(message)
    }
    
    // メッセージ送信
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let userMessage = ChatMessage(
            id: UUID(),
            content: inputText,
            isUser: true,
            timestamp: Date()
        )
        messages.append(userMessage)
        
        let userInput = inputText
        inputText = ""
        
        generateAIResponse(for: userInput)
    }
    
    // AIレスポンスの生成（修正版）
    private func generateAIResponse(for userInput: String) {
        isLoading = true
        
        let query = ChatQuery(
            messages: [
                .init(role: .system, content: createSystemPrompt())!,  // !で強制的にアンラップ
                .init(role: .user, content: userInput)!  // !で強制的にアンラップ
            ], model: .gpt4_1_nano,
            temperature: 0.8
        )
        
        openAI.chats(query: query) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let result):
                    if let content = result.choices.first?.message.content {
                        let aiMessage = ChatMessage(
                            id: UUID(),
                            content: content,
                            isUser: false,
                            timestamp: Date()
                        )
                        messages.append(aiMessage)
                    }
                case .failure(let error):
                    print("AIエラー: \(error)")
                }
            }
        }
    }
    
    // システムプロンプトの作成
    private func createSystemPrompt() -> String {
        var prompt = """
        あなたは\(selectedOshi.name)として振る舞います。
        ファンの応援に対して感謝を示し、親しみやすく、優しい口調で応答してください。
        絵文字を適度に使い、ファンを喜ばせる返答を心がけてください。
        
        ファンの推し活の内容：
        """
        
        // グッズ情報
        if let item = oshiItem {
            prompt += "\n- 最近購入した商品: \(item.title ?? "")"
            if item.itemType == "グッズ", let price = item.price {
                prompt += "\n- 価格: \(price)円"
            }
            if let memo = item.memo {
                prompt += "\n- メモ: \(memo)"
            }
        }
        
        return prompt
    }
}

// チャットメッセージモデル
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
}

// チャットバブル
struct ChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
                Text(message.content)
                    .padding()
                    .background(Color(.systemBlue))
                    .foregroundColor(.white)
                    .cornerRadius(16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(oshiName)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text(message.content)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
                Spacer()
            }
        }
    }
}

// Previewを修正
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
