//
//  RandomMessageManager.swift
//  osimono
//
//  Created by Claude on 2025/05/19.
//

import Foundation

class RandomMessageManager {
    static let shared = RandomMessageManager()

    private init() {}

    private let followUpIdleInterval: TimeInterval = 12 * 60 * 60
    private let followUpCooldown: TimeInterval = 12 * 60 * 60
    private let lastProactiveMessageKeyPrefix = "lastProactiveMessageTimestamp_"
    private let stateQueue = DispatchQueue(label: "RandomMessageManager.state")
    private var inFlightOshiIds: Set<String> = []
    private var pendingCompletions: [String: [(ChatMessage?) -> Void]] = [:]

    // 既存の呼び出し口。新規会話の開始も、無通信時の再連絡もここで面倒を見る。
    func checkAndSendMessageIfNeeded(for oshi: Oshi) {
        sendProactiveMessageIfNeeded(for: oshi)
    }

    func sendProactiveMessageIfNeeded(for oshi: Oshi, completion: ((ChatMessage?) -> Void)? = nil) {
        guard !oshi.id.isEmpty else {
            print(L10n.noValidOshiSelected)
            completion?(nil)
            return
        }

        guard startRequest(for: oshi.id, completion: completion) else {
            return
        }

        ChatDatabaseManager.shared.fetchRecentMessagesOnce(for: oshi.id, limit: 24) { [weak self] messages, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ プロアクティブメッセージ用の履歴取得に失敗: \(error.localizedDescription)")
                self.finishRequest(for: oshi.id, message: nil)
                return
            }

            let chatHistory = messages ?? []
            let isFirstMessage = chatHistory.isEmpty
            let now = Date().timeIntervalSince1970

            if !isFirstMessage {
                let lastMessageTimestamp = chatHistory.last?.timestamp ?? 0
                let lastProactiveTimestamp = UserDefaults.standard.double(forKey: self.lastProactiveMessageKey(for: oshi.id))

                if now - lastMessageTimestamp < self.followUpIdleInterval ||
                    now - lastProactiveTimestamp < self.followUpCooldown {
                    self.finishRequest(for: oshi.id, message: nil)
                    return
                }
            }

            AIMessageGenerator.shared.generateProactiveMessage(
                for: oshi,
                chatHistory: chatHistory,
                isFirstMessage: isFirstMessage
            ) { content, error in
                if let error = error {
                    print("\(L10n.aiMessageGenerationError): \(error.localizedDescription)")
                    self.finishRequest(for: oshi.id, message: nil)
                    return
                }

                guard let content = content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
                    print(L10n.aiMessageEmpty)
                    self.finishRequest(for: oshi.id, message: nil)
                    return
                }

                let message = ChatMessage(
                    id: UUID().uuidString,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: oshi.id
                )

                ChatDatabaseManager.shared.saveMessage(message) { error in
                    if let error = error {
                        print("\(L10n.messageSaveError): \(error.localizedDescription)")
                        self.finishRequest(for: oshi.id, message: nil)
                    } else {
                        UserDefaults.standard.set(message.timestamp, forKey: self.lastProactiveMessageKey(for: oshi.id))
                        print("\(L10n.randomAiMessageSent): \(content)")
                        self.finishRequest(for: oshi.id, message: message)
                    }
                }
            }
        }
    }

    private func startRequest(for oshiId: String, completion: ((ChatMessage?) -> Void)?) -> Bool {
        stateQueue.sync {
            if inFlightOshiIds.contains(oshiId) {
                if let completion {
                    pendingCompletions[oshiId, default: []].append(completion)
                }
                return false
            }

            inFlightOshiIds.insert(oshiId)
            if let completion {
                pendingCompletions[oshiId] = [completion]
            }
            return true
        }
    }

    private func finishRequest(for oshiId: String, message: ChatMessage?) {
        let completions = stateQueue.sync {
            inFlightOshiIds.remove(oshiId)
            return pendingCompletions.removeValue(forKey: oshiId) ?? []
        }

        guard !completions.isEmpty else {
            return
        }

        DispatchQueue.main.async {
            completions.forEach { $0(message) }
        }
    }

    private func lastProactiveMessageKey(for oshiId: String) -> String {
        lastProactiveMessageKeyPrefix + oshiId
    }

    // テスト用：強制的にメッセージを送信
    func sendTestMessage(for oshi: Oshi, completion: @escaping (Bool) -> Void) {
        let generator = AIMessageGenerator.shared
        let userPrompt = L10n.testMessagePrompt

        generator.generateResponse(for: userPrompt, oshi: oshi, chatHistory: []) { content, error in
            if let error = error {
                print("\(L10n.aiMessageGenerationError): \(error.localizedDescription)")
                completion(false)
                return
            }

            guard let content = content else {
                print(L10n.aiMessageEmpty)
                completion(false)
                return
            }

            let message = ChatMessage(
                id: UUID().uuidString,
                content: content,
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                oshiId: oshi.id
            )

            ChatDatabaseManager.shared.saveMessage(message) { error in
                if let error = error {
                    print("\(L10n.messageSaveError): \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("\(L10n.testMessageSent): \(content)")
                    completion(true)
                }
            }
        }
    }
}
