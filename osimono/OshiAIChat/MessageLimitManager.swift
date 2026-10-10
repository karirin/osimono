//
//  MessageLimitManager.swift
//  osimono
//
//  Created by Apple on 2025/05/21.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

/// 無料ユーザーが次の1通を送ったときの扱い
enum MessageSendAllowance: Equatable {
    /// 通常どおり送信・返信（isLast = 今日最後の1通）
    case normal(isLast: Bool)
    /// 上限超過後の1通だけ送れる。返信は途中までしか読めない
    case teaser
    /// 送信不可（上限モーダルを出す）
    case blocked
}

class MessageLimitManager {
    // シングルトンインスタンス
    static let shared = MessageLimitManager()
    
    // 1日の最大メッセージ送信回数（無料ユーザー用、Remote Config で切り替え）
    private var maxMessagesPerDay: Int { PaywallConfig.shared.freeDailyMessageLimit }
    
    // ユーザーデフォルトキー
    private let messageCountKey = "dailyMessageCount"
    private let lastResetDateKey = "lastResetDate"
    private let subscriptionCacheKey = PremiumFeatures.subscriptionCacheKey
    
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
        let cached = PremiumFeatures.isActive
        print("📖 キャッシュからサブスクリプション状態取得: \(cached)")
        return cached
    }
    
    // メインスレッドから実際のサブスクリプション状態を取得してキャッシュと比較
    @MainActor
    func syncSubscriptionStatus() -> Bool {
        let actual = SubscriptionManager.shared.isSubscribed
        let cached = PremiumFeatures.isActive
        
        print("🔍 サブスクリプション状態比較:")
        print("  - 実際の状態: \(actual)")
        print("  - キャッシュ状態: \(cached)")
        
        if actual != cached && !PremiumFeatures.developmentPremiumEnabled {
            print("⚠️ 状態不整合を検出！キャッシュを更新します")
            UserDefaults.standard.set(actual, forKey: subscriptionCacheKey)
            print("✅ キャッシュを更新: \(actual)")
        }
        
        return actual
    }
    
    // サブスクリプション状態のキャッシュを更新（メインスレッドから呼び出し）
    @MainActor
    func updateSubscriptionCache() {
        // 開発用プレミアムで実際の購入状態を上書きしない。
        guard !PremiumFeatures.developmentPremiumEnabled else { return }
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
        checkAndResetDailyCount()
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
    
    /// 返信を受け取れなかった送信分を戻す
    func refundCount() {
        if checkSubscriptionStatus() { return }
        let count = UserDefaults.standard.integer(forKey: messageCountKey)
        UserDefaults.standard.set(max(0, count - 1), forKey: messageCountKey)
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
    
    /// 次の1通の扱いを返す。
    /// 上限の1通前 → 最後の1通、上限ちょうど → 続きがぼかされた返信を1回だけ、それ以降 → 送信不可
    func sendAllowance() -> MessageSendAllowance {
        if checkSubscriptionStatus() {
            return .normal(isLast: false)
        }
        let count = getCurrentCount()
        if count < maxMessagesPerDay - 1 {
            return .normal(isLast: false)
        } else if count == maxMessagesPerDay - 1 {
            return .normal(isLast: true)
        } else if count == maxMessagesPerDay {
            return .teaser
        }
        return .blocked
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
            return NSLocalizedString("unlimited", comment: "unlimited")
        } else {
            let remaining = getRemainingMessages()
            let currentLanguage = Locale.current.languageCode ?? "en"
            
            if currentLanguage == "ja" {
                return "\(remaining)回"
            } else {
                return remaining == 1 ? "\(remaining) time" : "\(remaining) times"
            }
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
    
    /// リワード広告視聴後に送信回数を追加する。追加した回数を返す
    @discardableResult
    func grantRewardMessages() -> Int {
        // サブスクリプション会員はリワード不要
        if checkSubscriptionStatus() {
            print("👑 サブスクリプション会員のため、リワード処理をスキップ")
            return 0
        }
        
        checkAndResetDailyCount()
        let reward = PaywallConfig.shared.adRewardMessageCount
        let oldCount = UserDefaults.standard.integer(forKey: messageCountKey)
        // ぼかし返信で上限を超えている分は切り捨ててから差し引く
        let newCount = max(0, min(oldCount, maxMessagesPerDay) - reward)
        UserDefaults.standard.set(newCount, forKey: messageCountKey)
        
        print("🎁 リワード広告視聴後、メッセージカウントを更新: \(oldCount) → \(newCount)")
        return reward
    }
    
    // リワード広告が視聴可能かチェック（無料ユーザーは何度でも視聴できる）
    func canWatchReward() -> Bool {
        !checkSubscriptionStatus()
    }
    
    // MARK: - 続きがぼかされた返信
    private let lockedReplyIdsKey = "lockedTeaserReplyIds"
    
    /// 上限超過後に届いた返信のID（広告視聴またはプレミアム加入で読めるようになる）
    func lockedReplyIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: lockedReplyIdsKey) ?? [])
    }
    
    func lockReply(id: String) {
        var ids = lockedReplyIds()
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: lockedReplyIdsKey)
    }

    /// 広告視聴で解除した返信を、チャットを開き直した後も読めるようにする
    func unlockReply(id: String) {
        var ids = lockedReplyIds()
        ids.remove(id)
        UserDefaults.standard.set(Array(ids), forKey: lockedReplyIdsKey)
    }
    
    // サブスクリプション会員かどうかを確認（外部向け）
    func isUserSubscribed() -> Bool {
        let result = checkSubscriptionStatus()
        print("🔍 外部からのサブスクリプション状態確認: \(result)")
        return result
    }
    
    // サブスクリプションキャッシュを強制更新（デバッグ用・緊急対応用）
    func forceUpdateSubscriptionCache(isSubscribed: Bool) {
        guard !PremiumFeatures.developmentPremiumEnabled else { return }
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
        
        print("🗑️ MessageLimitManager: 全データをリセットしました")
        
        // 再初期化
        checkAndResetDailyCount()
        if UserDefaults.standard.object(forKey: subscriptionCacheKey) == nil {
            UserDefaults.standard.set(false, forKey: subscriptionCacheKey)
        }
    }
}
