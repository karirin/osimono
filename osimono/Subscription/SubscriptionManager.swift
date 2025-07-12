//
//  SubscriptionManager.swift
//  osimono
//
//  Created by Apple on 2025/07/12.
//

import StoreKit
import SwiftUI
import Combine

// 型エイリアスで明確化
typealias SKTransaction = StoreKit.Transaction
typealias SKProduct = StoreKit.Product

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var subscriptionProducts: [SKProduct] = []
    @Published var isSubscribed: Bool = false
    @Published var currentSubscription: SKProduct?
    @Published var isLoading: Bool = false
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // サブスクリプションのプロダクトID（App Store Connectで設定したID）
    private let subscriptionIDs = [
        "com.yourapp.premium.monthly",  // 月額プラン
        "com.yourapp.premium.yearly"   // 年額プラン
    ]
    
    init() {
        // トランザクションの監視を開始
        updateListenerTask = listenForTransactions()
        
        Task {
            await requestProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 商品情報を取得
    func requestProducts() async {
        isLoading = true
        do {
            subscriptionProducts = try await SKProduct.products(for: subscriptionIDs)
            print("取得した商品数: \(subscriptionProducts.count)")
        } catch {
            print("商品情報の取得に失敗しました: \(error)")
        }
        isLoading = false
    }
    
    // 購入処理
    func purchase(_ product: SKProduct) async throws -> SKTransaction? {
        isLoading = true
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            isLoading = false
            return transaction
        case .userCancelled:
            print("ユーザーが購入をキャンセルしました")
            isLoading = false
            return nil
        case .pending:
            print("購入が保留中です")
            isLoading = false
            return nil
        default:
            print("不明な購入結果")
            isLoading = false
            return nil
        }
    }
    
    // サブスクリプション状態の更新
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var activeSubscription: SKProduct? = nil
        
        // 現在有効なエンタイトルメントをチェック
        for await result in SKTransaction.currentEntitlements {
            do {
                let transaction = checkVerified(result)
                
                // サブスクリプションIDに含まれているかチェック
                if subscriptionIDs.contains(transaction.productID) {
                    hasActiveSubscription = true
                    
                    // 対応するProductを見つける
                    if let product = subscriptionProducts.first(where: { $0.id == transaction.productID }) {
                        activeSubscription = product
                    }
                    break
                }
            } catch {
                print("トランザクションの検証に失敗しました: \(error)")
            }
        }
        
        self.isSubscribed = hasActiveSubscription
        self.currentSubscription = activeSubscription
        
        print("サブスクリプション状態: \(hasActiveSubscription ? "有効" : "無効")")
    }
    
    // トランザクションの監視
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in SKTransaction.updates {
                do {
                    let transaction = await self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("トランザクションの更新に失敗しました: \(error)")
                }
            }
        }
    }
    
    // トランザクションの検証
    func checkVerified<T>(_ result: VerificationResult<T>) -> T {
        switch result {
        case .unverified:
            print("未検証のトランザクションが検出されました")
            fatalError("未検証のトランザクション")
        case .verified(let safe):
            return safe
        }
    }
    
    // 購入復元
    func restorePurchases() async {
        isLoading = true
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        isLoading = false
    }
    
    // サブスクリプションの有効期限を取得
    func getExpirationDate() async -> Date? {
        guard let currentSubscription = currentSubscription,
              let subscription = currentSubscription.subscription else { return nil }
        
        do {
            guard let status = try await subscription.status.first else { return nil }
            let verifiedTx = checkVerified(status.transaction)
            return verifiedTx.expirationDate
        } catch {
            print("有効期限の取得に失敗しました: \(error)")
            return nil
        }
    }
    
    // 価格を表示用文字列で取得
    func getDisplayPrice(for product: SKProduct) -> String {
        return product.displayPrice
    }
    
    // プランのタイプを判定
    func getPlanType(for product: SKProduct) -> String {
        if product.id.contains("monthly") {
            return "月額プラン"
        } else if product.id.contains("yearly") {
            return "年額プラン"
        }
        return "プラン"
    }
    
    // サブスクリプションの詳細情報を取得
    func getSubscriptionDetails() async -> SubscriptionDetails? {
        guard let subscription = currentSubscription?.subscription else { return nil }
        
        do {
            guard let status = try await subscription.status.first else { return nil }
            let renewalInfo = checkVerified(status.renewalInfo)
            let verifiedTx = checkVerified(status.transaction)
            
            return SubscriptionDetails(
                isActive: isSubscribed,
                expirationDate: verifiedTx.expirationDate,
                willAutoRenew: renewalInfo.willAutoRenew,
                productID: renewalInfo.currentProductID
            )
        } catch {
            print("サブスクリプション詳細の取得に失敗しました: \(error)")
            return nil
        }
    }
    
    // デバッグ用：現在の状態を出力
    func printDebugInfo() {
        print("=== サブスクリプション状態 ===")
        print("商品数: \(subscriptionProducts.count)")
        print("サブスクリプション状態: \(isSubscribed)")
        print("現在のサブスクリプション: \(currentSubscription?.id ?? "なし")")
        
        for product in subscriptionProducts {
            print("商品: \(product.id) - \(product.displayName) - \(product.displayPrice)")
        }
    }
    
    // シングルトンパターン（必要に応じて使用）
    static let shared = SubscriptionManager()
}

// サブスクリプションの詳細情報
struct SubscriptionDetails {
    let isActive: Bool
    let expirationDate: Date?
    let willAutoRenew: Bool
    let productID: String?
}

// サブスクリプション状態の列挙型
enum SubscriptionStatus {
    case active
    case inactive
    case loading
    case error(String)
}
