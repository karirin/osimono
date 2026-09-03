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
    
    override init() {
        super.init()
        if !AdConfiguration.isDisabledForDevelopment {
            loadRewardedAd()
        }
    }
    
    func loadRewardedAd() {
        guard !AdConfiguration.isDisabledForDevelopment else {
            rewardedAd = nil
            isAdReady = false
            return
        }

        let request = GoogleMobileAds.Request()
        RewardedAd.load(
            with: "ca-app-pub-4898800212808837/3373075660",
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("Failed to load rewarded ad: \(error)")
                self?.isAdReady = false
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
            self?.isAdReady = true
        }
    }
    
    func showAd(completion: @escaping (Bool) -> Void) {
        guard !AdConfiguration.isDisabledForDevelopment else {
            completion(true)
            return
        }

        completionHandler = completion
        
        guard let rewardedAd = rewardedAd,
              let rootViewController = UIApplication.shared.windows.first?.rootViewController else {
            completion(false)
            return
        }
        
        rewardedAd.present(from: rootViewController) {
            // ユーザーが報酬を獲得
            completion(true)
        }
    }
    
    // GADFullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        if !AdConfiguration.isDisabledForDevelopment {
            loadRewardedAd() // 次の広告を準備
        }
    }
}
