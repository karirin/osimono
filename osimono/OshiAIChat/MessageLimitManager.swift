//
//  MessageLimitManager.swift
//  osimono
//
//  Created by Apple on 2025/05/21.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

class MessageLimitManager {
    // シングルトンインスタンス
    static let shared = MessageLimitManager()
    
    // 1日の最大メッセージ送信回数
    private let maxMessagesPerDay = 10
    
    // ユーザーデフォルトキー
    private let messageCountKey = "dailyMessageCount"
    private let lastResetDateKey = "lastResetDate"
    
    private init() {
        // アプリ起動時にカウントリセットを確認
        checkAndResetDailyCount()
    }
    
    // 現在の送信カウントを取得
    func getCurrentCount() -> Int {
        return UserDefaults.standard.integer(forKey: messageCountKey)
    }
    
    // カウントを増加させる
    func incrementCount() {
        // 日付変更の確認
        checkAndResetDailyCount()
        
        // カウントを増加
        let currentCount = getCurrentCount()
        UserDefaults.standard.set(currentCount + 1, forKey: messageCountKey)
    }
    
    // 制限に達したかどうかを確認
    func hasReachedLimit() -> Bool {
        return getCurrentCount() >= maxMessagesPerDay
    }
    
    // 残りのメッセージ数を取得
    func getRemainingMessages() -> Int {
        let currentCount = getCurrentCount()
        return max(0, maxMessagesPerDay - currentCount)
    }
    
    // 日付が変わっていたらカウントをリセット
    private func checkAndResetDailyCount() {
        let calendar = Calendar.current
        let now = Date()
        
        // 最後のリセット日を取得
        let lastResetTimeInterval = UserDefaults.standard.double(forKey: lastResetDateKey)
        let lastResetDate = Date(timeIntervalSince1970: lastResetTimeInterval)
        
        // 現在の日付と最後のリセット日が同じ日かチェック
        if !calendar.isDate(lastResetDate, inSameDayAs: now) {
            // 日付が変わっていたらカウントをリセット
            UserDefaults.standard.set(0, forKey: messageCountKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastResetDateKey)
        }
    }
    
    // カウントをリセット（テスト用）
    func resetCount() {
        UserDefaults.standard.set(0, forKey: messageCountKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastResetDateKey)
    }
    
    // カウントを特定の値に設定（テスト用）
    func setCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: messageCountKey)
    }
    
    func resetCountAfterReward() {
        UserDefaults.standard.set(0, forKey: messageCountKey)
        // リワード視聴回数を記録（1日1回まで等の制限を追加する場合）
        let rewardKey = "rewardWatchedToday"
        UserDefaults.standard.set(true, forKey: rewardKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastRewardDate")
    }
    
    // リワード広告が視聴可能かチェック
    func canWatchReward() -> Bool {
        let rewardKey = "rewardWatchedToday"
        let lastRewardTimestamp = UserDefaults.standard.double(forKey: "lastRewardDate")
        let lastRewardDate = Date(timeIntervalSince1970: lastRewardTimestamp)
        
        // 日付が変わっていたらリセット
        if !Calendar.current.isDate(lastRewardDate, inSameDayAs: Date()) {
            UserDefaults.standard.set(false, forKey: rewardKey)
            return true
        }
        
        return !UserDefaults.standard.bool(forKey: rewardKey)
    }
}
