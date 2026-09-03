
import Foundation
import GoogleMobileAds
import UIKit

class IndividualChatInterstitialManager: NSObject, ObservableObject {
    static let shared = IndividualChatInterstitialManager()

    private var interstitialAd: InterstitialAd?
    private var isLoading = false

    // SwiftUIのナビゲーションと切り離すための独立ウィンドウ
    private var adWindow: UIWindow?

    private let triggerInterval: Int = 5
    private let sendCountKey = "IndividualChatSendCount"
    private let adShowCountKey = "IndividualChatAdShowCount"

    // 2回に1回サブスク画面を表示
    @Published var shouldShowSubscriptionSheet = false
    private let subscriptionSheetInterval: Int = 2

    // 個人チャット用インタースティシャル広告ユニットID
    private let adUnitID = "ca-app-pub-4898800212808837/1599022041"

    override init() {
        super.init()
        if !AdConfiguration.isDisabledForDevelopment {
            preloadAd()
        }
    }

    /// 送信時に呼び出す。5回ごとに広告を表示
    func incrementAndShowIfNeeded() {
        guard !AdConfiguration.isDisabledForDevelopment else { return }

        var count = UserDefaults.standard.integer(forKey: sendCountKey)
        count += 1
        UserDefaults.standard.set(count, forKey: sendCountKey)
        print("📊 個人チャット送信カウント: \(count)")

        if count % triggerInterval == 0 {
            // SwiftUIのレンダリング完了後に広告表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAdIfReady()
            }
        }
    }

    func preloadAd() {
        guard !AdConfiguration.isDisabledForDevelopment else { return }
        guard !isLoading else { return }
        isLoading = true

        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    print("❌ 個人チャット インタースティシャル広告読み込みエラー: \(error.localizedDescription)")
                    return
                }
                self?.interstitialAd = ad
                self?.interstitialAd?.fullScreenContentDelegate = self
                print("✅ 個人チャット インタースティシャル広告読み込み完了")
            }
        }
    }

    private func showAdIfReady() {
        guard !AdConfiguration.isDisabledForDevelopment else { return }

        guard let ad = interstitialAd else {
            print("⚠️ 個人チャット インタースティシャル広告が未準備")
            preloadAd()
            return
        }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        // SwiftUIのナビゲーション階層から完全に切り離した独立UIWindowで表示
        let window = UIWindow(windowScene: windowScene)
        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        window.rootViewController = rootVC
        window.windowLevel = .alert + 1
        window.makeKeyAndVisible()
        adWindow = window

        print("📺 個人チャット インタースティシャル広告表示")
        ad.present(from: rootVC)
    }
}

extension IndividualChatInterstitialManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // 独立ウィンドウを閉じる
        adWindow?.isHidden = true
        adWindow = nil
        interstitialAd = nil
        preloadAd()
        checkAndShowSubscriptionSheet()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ 個人チャット インタースティシャル広告表示エラー: \(error.localizedDescription)")
        adWindow?.isHidden = true
        adWindow = nil
        interstitialAd = nil
        preloadAd()
        checkAndShowSubscriptionSheet()
    }

    private func checkAndShowSubscriptionSheet() {
        var count = UserDefaults.standard.integer(forKey: adShowCountKey)
        count += 1
        UserDefaults.standard.set(count, forKey: adShowCountKey)
        print("📊 個人チャット 広告表示回数: \(count)")

        if count % subscriptionSheetInterval == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("💳 個人チャット サブスク画面表示")
                self.shouldShowSubscriptionSheet = true
            }
        }
    }
}
