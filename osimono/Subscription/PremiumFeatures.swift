//
//  PremiumFeatures.swift
//  osimono
//
//  プレミアム限定機能の判定と、プラン別の上限値をまとめる。
//  バックグラウンドのAI処理からも参照するため、SubscriptionManager（MainActor）ではなく
//  UserDefaults のキャッシュ（isSubscribedCache）を読む。
//

import Foundation

enum PremiumFeatures {
    /// MessageLimitManager と共有しているサブスク状態のキャッシュキー
    static let subscriptionCacheKey = "isSubscribedCache"

    /// 開発用のプラン切り替えは、実際の購入状態と別に保存する。
    static let developmentPremiumKey = "developmentPremiumEnabled"

    static var developmentPremiumEnabled: Bool {
        #if DEBUG
        // 開発者モードでは、初回起動からプレミアムを利用できる。
        return UserDefaults.standard.object(forKey: developmentPremiumKey) as? Bool ?? true
        #else
        return false
        #endif
    }

    static var isActive: Bool {
        developmentPremiumEnabled || UserDefaults.standard.bool(forKey: subscriptionCacheKey)
    }

    // MARK: - 記憶の拡張

    /// LLMへ送る直近メッセージ数
    static func recentMessageLimit(isPremium: Bool = isActive) -> Int {
        isPremium ? 40 : RoleplayPromptBuilder.recentMessageLimit
    }

    /// system prompt に入れる記憶の最大数
    static func promptMemoryLimit(isPremium: Bool = isActive) -> Int {
        isPremium ? 24 : RoleplayPromptBuilder.memoryLimit
    }

    /// 保持する記憶の上限
    static func maxStoredMemories(isPremium: Bool = isActive) -> Int {
        isPremium ? 500 : 150
    }
}

// MARK: - ロールプレイのお試し

/// 無料ユーザーはロールプレイを1回だけ体験できる（設定を1回保存 → 推しの返信 replyLimit 回まで）。
/// 使い切ったあとはシチュエーション・キャラクター詳細を prompt に入れず、続きはプレミアムで再開できる（設定は残す）。
enum RoleplayTrial {
    static let replyLimit = 10

    private static let startedKey = "roleplayTrialStarted"
    private static let usedRepliesKey = "roleplayTrialUsedReplies"

    enum Status: Equatable {
        case available          // まだ体験していない
        case active(remaining: Int)
        case used               // 体験済み
    }

    static var status: Status {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: startedKey) else { return .available }
        let remaining = replyLimit - defaults.integer(forKey: usedRepliesKey)
        return remaining > 0 ? .active(remaining: remaining) : .used
    }

    static var isActive: Bool {
        if case .active = status { return true }
        return false
    }

    /// お試しを開始する（無料ユーザーがロールプレイ設定を保存したとき）
    static func start() {
        guard status == .available else { return }
        UserDefaults.standard.set(true, forKey: startedKey)
        UserDefaults.standard.set(0, forKey: usedRepliesKey)
    }

    /// お試し中のロールプレイ返信を1回消費する。消費したことで使い切った場合 true
    @discardableResult
    static func consumeReply() -> Bool {
        guard isActive else { return false }
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: usedRepliesKey) + 1, forKey: usedRepliesKey)
        return status == .used
    }

    /// シチュエーション・キャラクター詳細を返信に反映してよいか
    static func canUseRoleplay(isPremium: Bool = PremiumFeatures.isActive) -> Bool {
        isPremium || isActive
    }
}
