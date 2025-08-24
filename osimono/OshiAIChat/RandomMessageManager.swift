//
//  RandomMessageManager.swift
//  osimono
//
//  Created by Claude on 2025/05/19.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

class RandomMessageManager {
    // シングルトンインスタンス
    static let shared = RandomMessageManager()
    
    // 初期化
    private init() {}
    
    // メッセージ送信の確率 (1/5 = 20%)
    private let messageProbability = 3
    
    // 最低間隔（時間単位）- Double型に変更
    private let minimumHoursBetweenMessages: Double = 24.0
    
    // 保存用キー
    private let lastMessageTimestampKey = "lastRandomMessageTimestamp"
    private let maxMessagesPerDay = 5
    private let dailyMessageCountKey = "dailyMessageCount"
    private let lastCountResetDateKey = "lastCountResetDate"
    
    // アプリ起動時にメッセージ送信をチェック
    func checkAndSendMessageIfNeeded(for oshi: Oshi) {
        let userDefaults = UserDefaults.standard
        let lastMessageTimestamp = userDefaults.double(forKey: lastMessageTimestampKey)
        let currentTime = Date().timeIntervalSince1970
        
        // 前回のメッセージから設定した時間以上経過しているか確認
        let hoursPassed = (currentTime - lastMessageTimestamp) / (60 * 60)
        if hoursPassed < minimumHoursBetweenMessages {
            return
        }
        
        // 日付が変わったかチェックし、変わっていれば送信カウントをリセット
        let today = Calendar.current.startOfDay(for: Date())
        let lastResetDateTimestamp = userDefaults.double(forKey: lastCountResetDateKey)
        let lastResetDate = Date(timeIntervalSince1970: lastResetDateTimestamp)
        
        let dailyCount: Int
        
        if !Calendar.current.isDate(lastResetDate, inSameDayAs: today) {
            // 日付が変わっていたらカウントリセット
            dailyCount = 0
            userDefaults.set(today.timeIntervalSince1970, forKey: lastCountResetDateKey)
        } else {
            // 同じ日なら現在のカウントを取得
            dailyCount = userDefaults.integer(forKey: dailyMessageCountKey)
        }
        
        // 1日の上限に達していたら送信しない
        if dailyCount >= maxMessagesPerDay {
            return
        }
        
        // 確率計算
        let random = Int.random(in: 1...messageProbability)
        if random == 1 {
            // 条件を満たした場合、メッセージを送信
            sendRandomAIMessage(for: oshi)
            
            // 最終送信日時を保存
            userDefaults.set(currentTime, forKey: lastMessageTimestampKey)
            
            // メッセージカウントを増やす
            userDefaults.set(dailyCount + 1, forKey: dailyMessageCountKey)
        }
    }
    
    // AIメッセージを送信する
    private func sendRandomAIMessage(for oshi: Oshi) {
        guard !oshi.id.isEmpty else {
            print(L10n.noValidOshiSelected) // 多言語化対応
            return
        }
        
        // AIメッセージ生成クラスのインスタンスを取得
        let generator = AIMessageGenerator.shared
        
        // メッセージのタイプをランダムに選択
        let messageType = getRandomMessageType()
        let userPrompt = getPromptForMessageType(messageType)
        
        // AIメッセージ生成（シミュレーションの場合は固定メッセージを使用）
        generator.generateResponse(for: userPrompt, oshi: oshi, chatHistory: []) { content, error in
            if let error = error {
                print("\(L10n.aiMessageGenerationError): \(error.localizedDescription)") // 多言語化対応
                return
            }
            
            guard let content = content else {
                print(L10n.aiMessageEmpty) // 多言語化対応
                return
            }
            
            // メッセージをFirebaseに保存
            let messageId = UUID().uuidString
            let message = ChatMessage(
                id: messageId,
                content: content,
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                oshiId: oshi.id
            )
            
            ChatDatabaseManager.shared.saveMessage(message) { error in
                if let error = error {
                    print("\(L10n.messageSaveError): \(error.localizedDescription)") // 多言語化対応
                } else {
                    print("\(L10n.randomAiMessageSent): \(content)") // 多言語化対応
                }
            }
        }
    }
    
    // ランダムにメッセージタイプを選択
    private func getRandomMessageType() -> String {
        let messageTypes = ["greeting", "encouragement", "update", "question"]
        return messageTypes.randomElement() ?? "greeting"
    }
    
    // メッセージタイプに応じたプロンプトを取得 - 多言語化対応
    private func getPromptForMessageType(_ type: String) -> String {
        switch type {
        case "greeting":
            return L10n.randomMessagePromptGreeting
        case "encouragement":
            return L10n.randomMessagePromptEncouragement
        case "update":
            return L10n.randomMessagePromptUpdate
        case "question":
            return L10n.randomMessagePromptQuestion
        default:
            return L10n.randomMessagePromptGreeting
        }
    }
    
    // テスト用：強制的にメッセージを送信
    func sendTestMessage(for oshi: Oshi, completion: @escaping (Bool) -> Void) {
        // AIメッセージ生成クラスのインスタンスを取得
        let generator = AIMessageGenerator.shared
        
        // テスト用プロンプト - 多言語化対応
        let userPrompt = L10n.testMessagePrompt
        
        // AIメッセージ生成
        generator.generateResponse(for: userPrompt, oshi: oshi, chatHistory: []) { content, error in
            if let error = error {
                print("\(L10n.aiMessageGenerationError): \(error.localizedDescription)") // 多言語化対応
                completion(false)
                return
            }
            
            guard let content = content else {
                print(L10n.aiMessageEmpty) // 多言語化対応
                completion(false)
                return
            }
            
            // メッセージをFirebaseに保存
            let messageId = UUID().uuidString
            let message = ChatMessage(
                id: messageId,
                content: content,
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                oshiId: oshi.id
            )
            
            ChatDatabaseManager.shared.saveMessage(message) { error in
                if let error = error {
                    print("\(L10n.messageSaveError): \(error.localizedDescription)") // 多言語化対応
                    completion(false)
                } else {
                    print("\(L10n.testMessageSent): \(content)") // 多言語化対応
                    completion(true)
                }
            }
        }
    }
}
