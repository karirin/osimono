//
//  OshiAIChatView.swift
//  osimono
//
//  Created by Apple on 2025/05/05.
//

import SwiftUI
import OpenAI            // OpenAI SDK をインストールしておくこと

// MARK: - 共通クライアント
struct AIClient {
    /// プレビュー中・APIキー未設定時は `nil`
    static let shared: OpenAI? = {
//        #if DEBUG && targetEnvironment(simulator)
//        return nil                                 // ← プレビューでは無効化
//        #else
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
//        #endif
    }()
}

// MARK: - メインビュー
struct OshiAIChatView: View {
    @Environment(\.presentationMode) private var presentationMode

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = "こんにちは"
    @State private var isLoading  = false

    let selectedOshi: Oshi
    let oshiItem: OshiItem?            // チャットのきっかけになったアイテム

    private let openAI  = AIClient.shared
    private let primary = Color(.systemPink)

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ── チャットメッセージ一覧 ───────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message,
                                           oshiName: selectedOshi.name)
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

                // ── 入力エリア ───────────────────────────────────────
                HStack(spacing: 12) {
                    TextField("\(selectedOshi.name)に話しかけてみよう",
                              text: $inputText)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(25)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(primary)
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
            if let item = oshiItem {
                addInitialMessage(for: item)
            } else {
                addWelcomeMessage()
            }
        }
    }

    // MARK: - 初期メッセージ
    private func addInitialMessage(for item: OshiItem) {
        let text: String
        switch item.itemType {
        case "グッズ":
            text = "\(item.title ?? "グッズ")を買ってくれてありがとう！とても嬉しいよ🥰"
        case "ライブ記録":
            text = "\(item.eventName ?? "ライブ")に来てくれてありがとう！最高だったね✨"
        case "聖地巡礼":
            text = "聖地巡礼してくれたんだね！私の大切な場所を訪れてくれて幸せだよ💕"
        case "SNS投稿":
            text = "投稿してくれてありがとう！たくさんの人に私のことを知ってもらえて嬉しいよ😊"
        default:
            text = "私のことを思い出してくれてありがとう！"
        }
        appendAIMessage(text)
    }

    private func addWelcomeMessage() {
        appendAIMessage("こんにちは！\(selectedOshi.name)だよ！いつも応援してくれてありがとう✨")
    }

    // MARK: - 送信処理
    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        messages.append(.init(id: .init(),
                              content: inputText,
                              isUser: true,
                              timestamp: .now))

        let userInput = inputText
        inputText = ""

        generateAIResponse(for: userInput)
    }

    // MARK: - OpenAI 呼び出し
    private func generateAIResponse(for userInput: String) {
        guard let openAI else {
            appendSystemMessage("⚠️ APIキーが設定されていないため返信できません")
            return
        }

        guard
            let system = ChatQuery.ChatCompletionMessageParam(
                role: .system,
                content: createSystemPrompt()
            ),
            let user   = ChatQuery.ChatCompletionMessageParam(
                role: .user,
                content: userInput
            )
        else {
            appendSystemMessage("⚠️ メッセージ生成に失敗しました")
            return
        }

        let query = ChatQuery(messages: [system, user],
                              model: .gpt4_1_nano,
                              temperature: 0.8)

        isLoading = true
        openAI.chats(query: query) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let res):
                    let reply = res.choices.first?.message.content ?? "(空の返答)"
                    appendAIMessage(reply)
                case .failure(let err):
                    appendSystemMessage("AIエラー: \(err.localizedDescription)")
                }
            }
        }
    }

    // MARK: - メッセージ追加ユーティリティ
    private func appendAIMessage(_ text: String) {
        messages.append(.init(id: .init(), content: text,
                              isUser: false, timestamp: .now))
    }
    private func appendSystemMessage(_ text: String) {
        appendAIMessage(text)
    }

    // MARK: - システムプロンプト
    private func createSystemPrompt() -> String {
        var prompt = """
        あなたは\(selectedOshi.name)として振る舞います。
        ファンの応援に対して感謝を示し、親しみやすく、優しい口調で応答してください。
        絵文字を適度に使い、ファンを喜ばせる返答を心がけてください。

        ファンの推し活の内容：
        """

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

// MARK: - サブビュー・モデル
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
}

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
