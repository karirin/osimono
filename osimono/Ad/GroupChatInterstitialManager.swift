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
    
    // UserDefaultsキー
    private let sendCountKey = "GroupChatSendCount"
    
    override init() {
        super.init()
        loadSendCount()
        preloadInterstitialAd()
    }
    
    // MARK: - 送信カウント管理
    
    /// 送信カウントを読み込み
    private func loadSendCount() {
        sendCount = UserDefaults.standard.integer(forKey: sendCountKey)
    }
    
    /// 送信カウントを保存
    private func saveSendCount() {
        UserDefaults.standard.set(sendCount, forKey: sendCountKey)
    }
    
    /// 送信カウントをインクリメント
    func incrementSendCount() {
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
    
    // MARK: - 広告管理
    
    /// インタースティシャル広告を事前読み込み
    func preloadInterstitialAd() {
        guard !isLoading else { return }
        
        isLoading = true
        
        let request = Request()
        InterstitialAd.load(with: "ca-app-pub-3940256099942544/4411468910", // テスト用ID
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
    
    /// 強制的に広告を表示（デバッグ用）
    func forceShowInterstitial() {
        showInterstitialIfReady()
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
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("インタースティシャル広告表示エラー: \(error.localizedDescription)")
        
        // エラーが発生した場合も次の広告を事前読み込み
        self.interstitialAd = nil
        preloadInterstitialAd()
    }
}
