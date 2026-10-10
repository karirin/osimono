//
//  PaywallAnalytics.swift
//  osimono
//
//  課金画面の計測（Firebase Analytics）と A/B テスト用設定（Firebase Remote Config）
//

import Foundation
import FirebaseAnalytics
import FirebaseRemoteConfig

// MARK: - 課金画面の入口
enum PaywallSource: String {
    case chatLimit = "chat_limit"                   // 個人チャットの上限・広告後
    case storyLimit = "story_limit"                 // 物語のAI利用上限
    case chatListPromo = "chat_list_promo"          // チャット一覧の定期プロモーション
    case groupChatLimit = "group_chat_limit"        // グループチャットの上限
    case oshiLimit = "oshi_limit"                   // 推し登録数の上限
    case settings = "settings"                      // 設定画面
    case subscriptionSettings = "subscription_settings" // サブスク管理画面
    case onboarding = "onboarding"                  // 最初の会話が盛り上がった直後
    case winBack = "win_back"                       // 閉じた人向けの翌日24時間限定オファー
    case roleplay = "roleplay"                      // ロールプレイ設定・お試し終了後
}

// MARK: - 計測イベント
enum PaywallAnalytics {
    static func logView(source: PaywallSource) {
        log("paywall_view", source: source)
    }

    static func logPlanSelect(source: PaywallSource, productID: String) {
        log("plan_select", source: source, extra: ["product_id": productID])
    }

    static func logPurchaseStart(source: PaywallSource, productID: String, hasTrial: Bool) {
        log("purchase_start", source: source, extra: [
            "product_id": productID,
            "has_trial": hasTrial ? 1 : 0
        ])
    }

    static func logPurchaseSuccess(source: PaywallSource, productID: String, price: Decimal, currency: String, hasTrial: Bool) {
        log("purchase_success", source: source, extra: [
            "product_id": productID,
            AnalyticsParameterValue: NSDecimalNumber(decimal: price).doubleValue,
            AnalyticsParameterCurrency: currency,
            "has_trial": hasTrial ? 1 : 0
        ])
    }

    // result: cancelled / pending / error
    static func logPurchaseFail(source: PaywallSource, productID: String, result: String) {
        log("purchase_fail", source: source, extra: ["product_id": productID, "result": result])
    }

    static func logDismiss(source: PaywallSource, secondsOnScreen: Int, selectedProductID: String?) {
        log("paywall_dismiss", source: source, extra: [
            "seconds_on_screen": secondsOnScreen,
            "product_id": selectedProductID ?? "none"
        ])
    }

    private static func log(_ name: String, source: PaywallSource, extra: [String: Any] = [:]) {
        var params: [String: Any] = [
            "source": source.rawValue,
            "variant": PaywallConfig.shared.variant
        ]
        params.merge(extra) { _, new in new }
        Analytics.logEvent(name, parameters: params)
        #if DEBUG
        print("📈 \(name): \(params)")
        #endif
    }
}

// MARK: - Remote Config
final class PaywallConfig {
    static let shared = PaywallConfig()

    private enum Key {
        static let trialEnabled = "paywall_trial_enabled"
        static let freeDailyMessageLimit = "free_daily_message_limit"
        static let adRewardMessageCount = "ad_reward_message_count"
        static let title = "paywall_title"
        static let subtitle = "paywall_subtitle"
        static let ctaText = "paywall_cta_text"
        static let variant = "paywall_variant"
    }

    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        // 空文字は「アプリ内の既定文言を使う」の意味
        remoteConfig.setDefaults([
            Key.trialEnabled: true as NSObject,
            Key.freeDailyMessageLimit: 10 as NSObject,
            Key.adRewardMessageCount: 5 as NSObject,
            Key.title: "" as NSObject,
            Key.subtitle: "" as NSObject,
            Key.ctaText: "" as NSObject,
            Key.variant: "default" as NSObject
        ])
    }

    // 起動時に呼ぶ。取得した値は次回以降の表示から反映（表示途中で文言が変わらないように）
    func fetch() {
        remoteConfig.fetch { [weak self] status, error in
            if let error = error {
                print("⚠️ Remote Config 取得失敗: \(error.localizedDescription)")
                return
            }
            guard status == .success else { return }
            self?.remoteConfig.activate { _, _ in
                print("✅ Remote Config 反映: variant=\(self?.variant ?? "-")")
            }
        }
    }

    var trialEnabled: Bool { remoteConfig[Key.trialEnabled].boolValue }

    var freeDailyMessageLimit: Int {
        let value = remoteConfig[Key.freeDailyMessageLimit].numberValue.intValue
        return value > 0 ? value : 10
    }

    /// リワード広告1回で増える送信回数（何回でも視聴可。プレミアムより不便に保つため少なめ）
    var adRewardMessageCount: Int {
        let value = remoteConfig[Key.adRewardMessageCount].numberValue.intValue
        return value > 0 ? value : 5
    }

    var title: String? { nonEmpty(Key.title) }
    var subtitle: String? { nonEmpty(Key.subtitle) }
    var ctaText: String? { nonEmpty(Key.ctaText) }
    var variant: String { nonEmpty(Key.variant) ?? "default" }

    private func nonEmpty(_ key: String) -> String? {
        let value = remoteConfig[key].stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
