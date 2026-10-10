//
//  PaywallCampaignManager.swift
//  osimono
//
//  オンボーディング直後のペイウォールと、閉じた人向けの翌日24時間限定オファー（二段構え）
//

import Foundation
import StoreKit
import UserNotifications

@MainActor
final class PaywallCampaignManager: ObservableObject {
    static let shared = PaywallCampaignManager()

    // MARK: - 設定

    /// App Store Connect で作成したカスタムオファーコード（サブスクリプション > オファーコード）
    /// ※ ASC 側でこのコードを作成し、割引内容を下の `winBackOfferLabel` と合わせること
    static let winBackOfferCode = "OSHI24"
    /// オファー内容の表示文言（ASC のオファーコード設定と一致させる）
    static let winBackOfferLabel = "初月50%OFF"
    /// 何回目のAI返信のあとにオンボーディングペイウォールを出すか
    static let onboardingReplyThreshold = 3
    /// ペイウォールを閉じてからオファー開始までの時間
    static let winBackDelay: TimeInterval = 24 * 60 * 60
    /// オファーの有効時間
    static let winBackDuration: TimeInterval = 24 * 60 * 60

    // MARK: - 永続化キー

    private enum Key {
        static let aiReplyCount = "paywallCampaign.aiReplyCount"
        static let onboardingShown = "paywallCampaign.onboardingShown"
        static let winBackStart = "paywallCampaign.winBackStart"
        static let winBackPresented = "paywallCampaign.winBackPresented"
    }

    private static let notificationID = "paywallCampaign.winBackOffer"
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - 1. オンボーディングペイウォール

    /// AI返信を受け取るたびに呼ぶ。ペイウォールを出すべきタイミングなら true を返す（1回きり）
    func registerAIReplyAndCheckOnboarding(isSubscribed: Bool, isAdmin: Bool) -> Bool {
        guard !defaults.bool(forKey: Key.onboardingShown) else { return false }
        let count = defaults.integer(forKey: Key.aiReplyCount) + 1
        defaults.set(count, forKey: Key.aiReplyCount)

        guard count >= Self.onboardingReplyThreshold else { return false }
        // 課金済み・管理者には出さず、以降も判定しない
        defaults.set(true, forKey: Key.onboardingShown)
        return !isSubscribed && !isAdmin
    }

    /// オンボーディングペイウォールを購入せずに閉じたとき
    func onboardingPaywallDismissedWithoutPurchase() {
        guard defaults.object(forKey: Key.winBackStart) == nil else { return }
        let start = Date().addingTimeInterval(Self.winBackDelay)
        defaults.set(start.timeIntervalSince1970, forKey: Key.winBackStart)
        defaults.set(false, forKey: Key.winBackPresented)
        scheduleWinBackNotification(at: start)
    }

    // MARK: - 2. 翌日の24時間限定オファー

    var winBackWindow: (start: Date, end: Date)? {
        guard defaults.object(forKey: Key.winBackStart) != nil else { return nil }
        let start = Date(timeIntervalSince1970: defaults.double(forKey: Key.winBackStart))
        return (start, start.addingTimeInterval(Self.winBackDuration))
    }

    /// 今オファー期間中で、まだ自動表示していなければ終了日時を返す
    func winBackExpiryToPresent(now: Date = Date()) async -> Date? {
        guard let window = winBackWindow,
              now >= window.start, now < window.end,
              !defaults.bool(forKey: Key.winBackPresented) else { return nil }
        if await Self.hasActiveSubscription() {
            cancelWinBack()
            return nil
        }
        defaults.set(true, forKey: Key.winBackPresented)
        return window.end
    }

    /// 購読したらオファーを止める
    func cancelWinBack() {
        defaults.set(true, forKey: Key.winBackPresented)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func scheduleWinBackNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        let identifier = Self.notificationID
        let body = "推しとの時間をもっと特別に。今だけプレミアムが\(Self.winBackOfferLabel)です。"
        center.getNotificationSettings { settings in
            let schedule = {
                let content = UNMutableNotificationContent()
                content.title = "24時間限定のプレゼント🎁"
                content.body = body
                content.sound = .default
                let interval = max(date.timeIntervalSinceNow, 1)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
            }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { schedule() }
                }
            default:
                break // 通知不可でも、次回起動時にアプリ内で表示する
            }
        }
    }

    // MARK: - Helpers

    static func hasActiveSubscription() async -> Bool {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    #if DEBUG
    /// デバッグ用: キャンペーン状態をリセット
    func resetForDebug() {
        [Key.aiReplyCount, Key.onboardingShown, Key.winBackStart, Key.winBackPresented].forEach(defaults.removeObject(forKey:))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    /// デバッグ用: オファー期間を今すぐ開始
    func startWinBackNowForDebug() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.winBackStart)
        defaults.set(false, forKey: Key.winBackPresented)
    }
    #endif
}
