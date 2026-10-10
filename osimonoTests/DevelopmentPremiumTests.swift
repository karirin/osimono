import Foundation
import Testing
@testable import osimono

@Suite(.serialized)
struct DevelopmentPremiumTests {
    @Test func switchingPlanUpdatesPremiumFeaturesAndOshiLimits() {
        let defaults = UserDefaults.standard
        let developmentValue = defaults.object(forKey: PremiumFeatures.developmentPremiumKey)
        let subscriptionValue = defaults.object(forKey: PremiumFeatures.subscriptionCacheKey)
        defer {
            if let developmentValue {
                defaults.set(developmentValue, forKey: PremiumFeatures.developmentPremiumKey)
            } else {
                defaults.removeObject(forKey: PremiumFeatures.developmentPremiumKey)
            }
            if let subscriptionValue {
                defaults.set(subscriptionValue, forKey: PremiumFeatures.subscriptionCacheKey)
            } else {
                defaults.removeObject(forKey: PremiumFeatures.subscriptionCacheKey)
            }
        }

        defaults.set(false, forKey: PremiumFeatures.subscriptionCacheKey)
        defaults.set(true, forKey: PremiumFeatures.developmentPremiumKey)
        let limits = OshiLimitManager.shared

        #if DEBUG
        #expect(PremiumFeatures.developmentPremiumEnabled)
        #expect(PremiumFeatures.isActive)
        #expect(limits.canAddNewOshi(currentOshiCount: limits.freeUserOshiLimit, isSubscribed: false))
        #expect(limits.getOshiLimit(isSubscribed: false) == Int.max)
        #else
        #expect(!PremiumFeatures.developmentPremiumEnabled)
        #expect(!PremiumFeatures.isActive)
        #expect(!limits.canAddNewOshi(currentOshiCount: limits.freeUserOshiLimit, isSubscribed: false))
        #endif
        #expect(!defaults.bool(forKey: PremiumFeatures.subscriptionCacheKey))

        defaults.set(false, forKey: PremiumFeatures.developmentPremiumKey)
        #expect(!PremiumFeatures.developmentPremiumEnabled)
        #expect(!PremiumFeatures.isActive)
        #expect(limits.getOshiLimit(isSubscribed: false) == limits.freeUserOshiLimit)
        #expect(limits.canAddNewOshi(currentOshiCount: limits.freeUserOshiLimit - 1, isSubscribed: false))
        #expect(!limits.canAddNewOshi(currentOshiCount: limits.freeUserOshiLimit, isSubscribed: false))
        #expect(limits.hasReachedOshiLimit(currentOshiCount: limits.freeUserOshiLimit, isSubscribed: false))
        #expect(limits.getRemainingOshiCount(currentOshiCount: limits.freeUserOshiLimit, isSubscribed: false) == 0)
        #expect(defaults.object(forKey: PremiumFeatures.developmentPremiumKey) as? Bool == false)

        // 開発用プレミアムをオフにしても、購入済みのプレミアムは有効。
        defaults.set(true, forKey: PremiumFeatures.subscriptionCacheKey)
        #expect(PremiumFeatures.isActive)
        #expect(limits.getOshiLimit(isSubscribed: PremiumFeatures.isActive) == Int.max)
    }
}
