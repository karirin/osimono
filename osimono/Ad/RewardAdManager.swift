//
//  RewardAdManager.swift
//  osimono
//
//  Created by Apple on 2025/05/24.
//

import GoogleMobileAds

class RewardAdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    static let shared = RewardAdManager()
    
    @Published var isAdReady = false
    var rewardedAd: RewardedAd?
    private var completionHandler: ((Bool) -> Void)?
    private var failureHandler: (() -> Void)?
    private var earnedReward = false
    
    override init() {
        super.init()
        if !AdConfiguration.isDisabledForDevelopment {
            loadRewardedAd()
        }
    }
    
    /// completion には読み込めたかどうかを渡す（メインスレッドで呼ぶ）
    func loadRewardedAd(completion: ((Bool) -> Void)? = nil) {
        guard !AdConfiguration.isDisabledForDevelopment else {
            rewardedAd = nil
            isAdReady = false
            completion?(false)
            return
        }

        let request = GoogleMobileAds.Request()
        RewardedAd.load(
            with: "ca-app-pub-4898800212808837/3373075660",
            request: request
        ) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to load rewarded ad: \(error)")
                    self?.isAdReady = false
                    completion?(false)
                    return
                }
                self?.rewardedAd = ad
                self?.rewardedAd?.fullScreenContentDelegate = self
                self?.isAdReady = ad != nil
                completion?(ad != nil)
            }
        }
    }
    
    /// 報酬の有無は広告を閉じた後に返す。途中で閉じた場合も必ず完了する。
    func showAd(onFailure: (() -> Void)? = nil, completion: @escaping (Bool) -> Void) {
        guard !AdConfiguration.isDisabledForDevelopment else {
            completion(true)
            return
        }

        guard completionHandler == nil else {
            completion(false)
            onFailure?()
            return
        }
        guard let rewardedAd = rewardedAd,
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              var presenter = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            completion(false)
            onFailure?()
            return
        }
        while let presented = presenter.presentedViewController { presenter = presented }
        completionHandler = completion
        failureHandler = onFailure
        earnedReward = false
        self.rewardedAd = nil
        isAdReady = false
        
        rewardedAd.present(from: presenter) { [weak self] in
            self?.earnedReward = true
        }
    }
    
    // GADFullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
        if !AdConfiguration.isDisabledForDevelopment {
            loadRewardedAd() // 次の広告を準備
        }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let onFailure = failureHandler
        finishPresentation()
        onFailure?()
        loadRewardedAd()
    }

    private func finishPresentation() {
        let completion = completionHandler
        let reward = earnedReward
        completionHandler = nil
        failureHandler = nil
        earnedReward = false
        completion?(reward)
    }
}
