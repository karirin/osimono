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
    
    // 1日の最大メッセージ送信回数（無料ユーザー用）
    private let maxMessagesPerDay = 10
    
    // ユーザーデフォルトキー
    private let messageCountKey = "dailyMessageCount"
    private let lastResetDateKey = "lastResetDate"
    private let subscriptionCacheKey = "isSubscribedCache"
    
    private init() {
        // アプリ起動時にカウントリセットを確認
        checkAndResetDailyCount()
        
        // 初期キャッシュ値を設定（デフォルトは無料ユーザー）
        if UserDefaults.standard.object(forKey: subscriptionCacheKey) == nil {
            UserDefaults.standard.set(false, forKey: subscriptionCacheKey)
            print("🔧 サブスクリプションキャッシュを初期化: false")
        }
    }
    
    // サブスクリプション状態を安全にチェック（キャッシュから取得）
    private func checkSubscriptionStatus() -> Bool {
        let cached = UserDefaults.standard.bool(forKey: subscriptionCacheKey)
        print("📖 キャッシュからサブスクリプション状態取得: \(cached)")
        return cached
    }
    
    // メインスレッドから実際のサブスクリプション状態を取得してキャッシュと比較
    @MainActor
    func syncSubscriptionStatus() -> Bool {
        let actual = SubscriptionManager.shared.isSubscribed
        let cached = UserDefaults.standard.bool(forKey: subscriptionCacheKey)
        
        print("🔍 サブスクリプション状態比較:")
        print("  - 実際の状態: \(actual)")
        print("  - キャッシュ状態: \(cached)")
        
        if actual != cached {
            print("⚠️ 状態不整合を検出！キャッシュを更新します")
            UserDefaults.standard.set(actual, forKey: subscriptionCacheKey)
            print("✅ キャッシュを更新: \(actual)")
        }
        
        return actual
    }
    
    // サブスクリプション状態のキャッシュを更新（メインスレッドから呼び出し）
    @MainActor
    func updateSubscriptionCache() {
        let isSubscribed = SubscriptionManager.shared.isSubscribed
        let oldValue = UserDefaults.standard.bool(forKey: subscriptionCacheKey)
        
        UserDefaults.standard.set(isSubscribed, forKey: subscriptionCacheKey)
        
        if oldValue != isSubscribed {
            print("🔄 サブスクリプション状態キャッシュ更新: \(oldValue) → \(isSubscribed)")
        } else {
            print("📋 サブスクリプション状態キャッシュ確認: \(isSubscribed) (変更なし)")
        }
    }
    
    // 非同期でキャッシュを更新
    func updateSubscriptionCacheAsync() {
        Task { @MainActor in
            updateSubscriptionCache()
        }
    }
    
    // 同期的にサブスクリプション状態を取得（メインスレッド専用）
    @MainActor
    func getSubscriptionStatusSync() -> Bool {
        return syncSubscriptionStatus()
    }
    
    // 現在の送信カウントを取得
    func getCurrentCount() -> Int {
        // サブスクリプション会員は常に0を返す（無制限表示用）
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員のため、カウント0を返却")
            return 0
        }
        let count = UserDefaults.standard.integer(forKey: messageCountKey)
        print("📊 現在のメッセージカウント: \(count)")
        return count
    }
    
    // カウントを増加させる
    func incrementCount() {
        // サブスクリプション会員はカウントしない
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員のため、カウント増加をスキップ")
            return
        }
        
        // 日付変更の確認
        checkAndResetDailyCount()
        
        // カウントを増加
        let currentCount = getCurrentCount()
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: messageCountKey)
        
        print("📊 メッセージカウント更新: \(currentCount) → \(newCount)/\(maxMessagesPerDay)")
    }
    
    // 制限に達したかどうかを確認
    func hasReachedLimit() -> Bool {
        // サブスクリプション会員は制限なし
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員: 制限なし")
            return false
        }
        
        let currentCount = getCurrentCount()
        let hasReached = currentCount >= maxMessagesPerDay
        
        if hasReached {
            print("⚠️ メッセージ制限に達しました: \(currentCount)/\(maxMessagesPerDay)")
        } else {
            print("✅ メッセージ制限内: \(currentCount)/\(maxMessagesPerDay)")
        }
        
        return hasReached
    }
    
    // 残りのメッセージ数を取得
    func getRemainingMessages() -> Int {
        // サブスクリプション会員は無制限
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員: 無制限")
            return 999 // 無制限を表す大きな数値
        }
        
        let currentCount = getCurrentCount()
        let remaining = max(0, maxMessagesPerDay - currentCount)
        print("📊 残りメッセージ数: \(remaining)")
        return remaining
    }
    
    // サブスクリプション状態の表示用文字列を取得
    func getRemainingMessagesText() -> String {
        if checkSubscriptionStatus() {
            return "無制限"
        } else {
            let remaining = getRemainingMessages()
            return "\(remaining)回"
        }
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
            let oldCount = UserDefaults.standard.integer(forKey: messageCountKey)
            
            // 日付が変わっていたらカウントをリセット
            UserDefaults.standard.set(0, forKey: messageCountKey)
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: lastResetDateKey)
            
            print("🗓️ 日付変更によりメッセージカウントをリセット: \(oldCount) → 0")
        }
    }
    
    // カウントをリセット（テスト用）
    func resetCount() {
        let oldCount = UserDefaults.standard.integer(forKey: messageCountKey)
        UserDefaults.standard.set(0, forKey: messageCountKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastResetDateKey)
        print("🔄 メッセージカウントを手動リセット: \(oldCount) → 0")
    }
    
    // カウントを特定の値に設定（テスト用）
    func setCount(_ count: Int) {
        // サブスクリプション会員は設定しない
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員のため、カウント設定をスキップ")
            return
        }
        let oldCount = UserDefaults.standard.integer(forKey: messageCountKey)
        UserDefaults.standard.set(count, forKey: messageCountKey)
        print("🔧 メッセージカウントを手動設定: \(oldCount) → \(count)")
    }
    
    func resetCountAfterReward() {
        // サブスクリプション会員はリワード不要
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員のため、リワード処理をスキップ")
            return
        }
        
        let oldCount = UserDefaults.standard.integer(forKey: messageCountKey)
        UserDefaults.standard.set(0, forKey: messageCountKey)
        
        // リワード視聴回数を記録（1日1回まで等の制限を追加する場合）
        let rewardKey = "rewardWatchedToday"
        UserDefaults.standard.set(true, forKey: rewardKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastRewardDate")
        
        print("🎁 リワード広告視聴後、メッセージカウントをリセット: \(oldCount) → 0")
    }
    
    // リワード広告が視聴可能かチェック
    func canWatchReward() -> Bool {
        // サブスクリプション会員はリワード広告不要
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員のため、リワード広告は不要")
            return false
        }
        
        let rewardKey = "rewardWatchedToday"
        let lastRewardTimestamp = UserDefaults.standard.double(forKey: "lastRewardDate")
        let lastRewardDate = Date(timeIntervalSince1970: lastRewardTimestamp)
        
        // 日付が変わっていたらリセット
        if !Calendar.current.isDate(lastRewardDate, inSameDayAs: Date()) {
            UserDefaults.standard.set(false, forKey: rewardKey)
            print("🗓️ 日付変更によりリワード視聴状態をリセット")
            return true
        }
        
        let canWatch = !UserDefaults.standard.bool(forKey: rewardKey)
        print("🎬 リワード広告視聴可能: \(canWatch)")
        return canWatch
    }
    
    // サブスクリプション会員かどうかを確認（外部向け）
    func isUserSubscribed() -> Bool {
        let result = checkSubscriptionStatus()
        print("🔍 外部からのサブスクリプション状態確認: \(result)")
        return result
    }
    
    // サブスクリプションキャッシュを強制更新（デバッグ用・緊急対応用）
    func forceUpdateSubscriptionCache(isSubscribed: Bool) {
        let oldValue = UserDefaults.standard.bool(forKey: subscriptionCacheKey)
        UserDefaults.standard.set(isSubscribed, forKey: subscriptionCacheKey)
        print("🔧 サブスクリプション状態を強制更新: \(oldValue) → \(isSubscribed)")
    }
    
    // デバッグ用：現在の状態を出力
    func printDebugInfo() {
        print("=== メッセージ制限状態デバッグ ===")
        print("サブスクリプション状態（キャッシュ）: \(checkSubscriptionStatus())")
        print("現在のカウント: \(getCurrentCount())")
        print("制限に達している: \(hasReachedLimit())")
        print("残りメッセージ数: \(getRemainingMessages())")
        print("残りメッセージ表示: \(getRemainingMessagesText())")
        print("リワード広告視聴可能: \(canWatchReward())")
        
        // キャッシュと日付情報も表示
        let lastResetDate = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: lastResetDateKey))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        print("最後のリセット日時: \(formatter.string(from: lastResetDate))")
        
        // UserDefaults値を直接確認
        print("--- UserDefaults値 ---")
        print("dailyMessageCount: \(UserDefaults.standard.integer(forKey: messageCountKey))")
        print("isSubscribedCache: \(UserDefaults.standard.bool(forKey: subscriptionCacheKey))")
        print("lastResetDate: \(UserDefaults.standard.double(forKey: lastResetDateKey))")
        print("===============================")
    }
    
    // 完全リセット（トラブルシューティング用）
    func resetAllData() {
        UserDefaults.standard.removeObject(forKey: messageCountKey)
        UserDefaults.standard.removeObject(forKey: lastResetDateKey)
        UserDefaults.standard.removeObject(forKey: subscriptionCacheKey)
        UserDefaults.standard.removeObject(forKey: "rewardWatchedToday")
        UserDefaults.standard.removeObject(forKey: "lastRewardDate")
        
        print("🗑️ MessageLimitManager: 全データをリセットしました")
        
        // 再初期化
        checkAndResetDailyCount()
        if UserDefaults.standard.object(forKey: subscriptionCacheKey) == nil {
            UserDefaults.standard.set(false, forKey: subscriptionCacheKey)
        }
    }
}
