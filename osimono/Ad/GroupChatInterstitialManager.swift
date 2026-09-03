//
//  GroupChatInterstitialManager.swift
//  osimono
//
//  Created by Apple on 2025/07/21.
//

import Foundation
import GoogleMobileAds
import UIKit

class GroupChatInterstitialManager: NSObject, ObservableObject {
    static let shared = GroupChatInterstitialManager()
    
    private var interstitialAd: InterstitialAd?
    private var isLoading = false
    
    // 送信カウント管理
    @Published var sendCount: Int = 0
    private let triggerInterval: Int = 5 // 5回ごとに広告表示
    
    // サブスクリプション画面表示管理
    @Published var shouldShowSubscriptionSheet = false
    private var subscriptionSheetCounter: Int = 0
    private let subscriptionSheetInterval: Int = 2 // 2回に1回サブスクリプション画面を表示
    
    // UserDefaultsキー
    private let sendCountKey = "GroupChatSendCount"
    private let subscriptionCounterKey = "GroupChatSubscriptionCounter"
    
    override init() {
        super.init()
        loadSendCount()
        loadSubscriptionCounter()
        if !AdConfiguration.isDisabledForDevelopment {
            preloadInterstitialAd()
        }
    }
    
    // MARK: - 送信カウント管理
    
    /// 送信カウントを読み込み
    private func loadSendCount() {
        sendCount = UserDefaults.standard.integer(forKey: sendCountKey)
        print("📊 送信カウント読み込み: \(sendCount)")
    }
    
    /// サブスクリプションカウンターを読み込み
    private func loadSubscriptionCounter() {
        subscriptionSheetCounter = UserDefaults.standard.integer(forKey: subscriptionCounterKey)
        print("📊 サブスクリプションカウンター読み込み: \(subscriptionSheetCounter)")
    }
    
    /// 送信カウントを保存
    private func saveSendCount() {
        UserDefaults.standard.set(sendCount, forKey: sendCountKey)
        UserDefaults.standard.synchronize()
    }
    
    /// サブスクリプションカウンターを保存
    private func saveSubscriptionCounter() {
        UserDefaults.standard.set(subscriptionSheetCounter, forKey: subscriptionCounterKey)
        UserDefaults.standard.synchronize()
    }
    
    /// 送信カウントをインクリメント
    func incrementSendCount() {
        guard !AdConfiguration.isDisabledForDevelopment else { return }

        sendCount += 1
        saveSendCount()
        
        print("グループチャット送信カウント: \(sendCount)")
        
        // 5回ごとに広告表示をチェック
        if sendCount % triggerInterval == 0 {
            showInterstitialIfReady()
        }
    }
    
    /// 送信カウントをリセット（デバッグ用）
    func resetSendCount() {
        sendCount = 0
        saveSendCount()
    }
    
    /// カウンターをリセット（デバッグ用）
    func resetCounters() {
        sendCount = 0
        subscriptionSheetCounter = 0
        saveSendCount()
        saveSubscriptionCounter()
        shouldShowSubscriptionSheet = false
        print("🔄 カウンターをリセットしました")
    }
    
    // MARK: - 広告管理
    
    /// インタースティシャル広告を事前読み込み
    func preloadInterstitialAd() {
        guard !AdConfiguration.isDisabledForDevelopment else { return }
        guard !isLoading else { return }
        
        isLoading = true
        
        let request = Request()
        InterstitialAd.load(with: "ca-app-pub-4898800212808837/1599022041", // テスト用ID
                              request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("インタースティシャル広告読み込みエラー: \(error.localizedDescription)")
                    return
                }
                
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                print("インタースティシャル広告読み込み完了")
            }
        }
    }
    
    /// 広告が準備できていれば表示
    private func showInterstitialIfReady() {
        guard !AdConfiguration.isDisabledForDevelopment else { return }

        guard let interstitialAd = interstitialAd else {
            print("インタースティシャル広告が準備されていません")
            // 広告が読み込まれていない場合は再読み込み
            preloadInterstitialAd()
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("ルートビューコントローラーが見つかりません")
            return
        }
        
        // 現在表示されているビューコントローラーを取得
        let presentingViewController = findTopViewController(from: rootViewController)
        
        print("インタースティシャル広告を表示します（送信回数: \(sendCount)）")
        interstitialAd.present(from: presentingViewController)
    }
    
    /// 強制的に広告を表示（デバッグ用）
    func forceShowInterstitial() {
        showInterstitialIfReady()
    }
    
    /// 最前面のビューコントローラーを取得
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presentedViewController = viewController.presentedViewController {
            return findTopViewController(from: presentedViewController)
        }
        
        if let navigationController = viewController as? UINavigationController,
           let topViewController = navigationController.topViewController {
            return findTopViewController(from: topViewController)
        }
        
        if let tabBarController = viewController as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return findTopViewController(from: selectedViewController)
        }
        
        return viewController
    }
    
    // MARK: - サブスクリプション画面表示判定
    
    /// サブスクリプション画面表示判定
    private func checkAndShowSubscriptionSheet() {
        subscriptionSheetCounter += 1
        saveSubscriptionCounter()
        
        print("📊 サブスクリプションシート判定: \(subscriptionSheetCounter)")
        
        // 2回に1回の頻度でサブスクリプション画面を表示
        if subscriptionSheetCounter % subscriptionSheetInterval == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("💳 サブスクリプション画面表示")
                self.shouldShowSubscriptionSheet = true
            }
        }
    }
}

// MARK: - GADFullScreenContentDelegate

extension GroupChatInterstitialManager: FullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("インタースティシャル広告が表示されます")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("インタースティシャル広告が閉じられました")
        
        // 広告が閉じられたら次の広告を事前読み込み
        self.interstitialAd = nil
        preloadInterstitialAd()
        
        // サブスクリプション画面表示判定
        checkAndShowSubscriptionSheet()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("インタースティシャル広告表示エラー: \(error.localizedDescription)")
        
        // エラーが発生した場合も次の広告を事前読み込み
        self.interstitialAd = nil
        preloadInterstitialAd()
        
        // サブスクリプション画面表示判定（広告が表示できなかった場合も）
        checkAndShowSubscriptionSheet()
    }
}
