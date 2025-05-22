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
            print("有効な推しが選択されていません")
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
                print("AIメッセージ生成エラー: \(error.localizedDescription)")
                return
            }
            
            guard let content = content else {
                print("AIメッセージが空です")
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
                    print("メッセージ保存エラー: \(error.localizedDescription)")
                } else {
                    print("ランダムAIメッセージを送信しました: \(content)")
                }
            }
        }
    }
    
    // ランダムにメッセージタイプを選択
    private func getRandomMessageType() -> String {
        let messageTypes = ["greeting", "encouragement", "update", "question"]
        return messageTypes.randomElement() ?? "greeting"
    }
    
    // メッセージタイプに応じたプロンプトを取得
    private func getPromptForMessageType(_ type: String) -> String {
        switch type {
        case "greeting":
            return "ファンに対して元気な挨拶メッセージを送ります"
        case "encouragement":
            return "ファンを応援する暖かいメッセージを送ります"
        case "update":
            return "最近の近況報告を一つだけして、ファンに感謝の気持ちを伝えます"
        case "question":
            return "ファンに対して簡単な質問をして、会話を始めます"
        default:
            return "ファンに対して元気な挨拶メッセージを送ります"
        }
    }
    
    // テスト用：強制的にメッセージを送信
    func sendTestMessage(for oshi: Oshi, completion: @escaping (Bool) -> Void) {
        // AIメッセージ生成クラスのインスタンスを取得
        let generator = AIMessageGenerator.shared
        
        // テスト用プロンプト
        let userPrompt = "ファンに対してテスト用のメッセージを送ります"
        
        // AIメッセージ生成
        generator.generateResponse(for: userPrompt, oshi: oshi, chatHistory: []) { content, error in
            if let error = error {
                print("AIメッセージ生成エラー: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let content = content else {
                print("AIメッセージが空です")
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
                    print("メッセージ保存エラー: \(error.localizedDescription)")
                    completion(false)
                } else {
                    print("テストメッセージを送信しました: \(content)")
                    completion(true)
                }
            }
        }
    }
}
