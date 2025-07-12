//
//  SubscriptionManager.swift
//  osimono
//
//  Created by Apple on 2025/07/12.
//

import StoreKit
import SwiftUI
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var subscriptionProducts: [Product] = []
    @Published var purchasedSubscriptions: [Product] = []
    @Published var subscriptionGroupStatus: RenewalState?
    @Published var isSubscribed: Bool = false
    
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
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // 商品情報を取得
    func requestProducts() async {
        do {
            subscriptionProducts = try await Product.products(for: subscriptionIDs)
        } catch {
            print("商品情報の取得に失敗しました: \(error)")
        }
    }
    
    // 購入処理
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    // サブスクリプション状態の更新
    func updateCustomerProductStatus() async {
        var purchasedSubscriptions: [Product] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = checkVerified(result)
                
                if let subscription = subscriptionProducts.first(where: { $0.id == transaction.productID }) {
                    purchasedSubscriptions.append(subscription)
                }
            } catch {
                print("トランザクションの検証に失敗しました")
            }
        }
        
        self.purchasedSubscriptions = purchasedSubscriptions
        self.isSubscribed = !purchasedSubscriptions.isEmpty
        
        // サブスクリプショングループの状態を確認
        if let subscription = purchasedSubscriptions.first {
            subscriptionGroupStatus = try? await subscription.subscription?.status.first?.state
        }
    }
    
    // トランザクションの監視
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = self.checkVerified(result)
                    await self.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    print("トランザクションの更新に失敗しました")
                }
            }
        }
    }
    
    // トランザクションの検証
    func checkVerified<T>(_ result: VerificationResult<T>) -> T {
        switch result {
        case .unverified:
            fatalError("未検証のトランザクション")
        case .verified(let safe):
            return safe
        }
    }
    
    // 購入復元
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }
    
    // サブスクリプションの有効期限を取得
    func getExpirationDate() async -> Date? {
        guard let subscription = purchasedSubscriptions.first?.subscription else { return nil }
        
        do {
            let status = try await subscription.status.first
            return status?.expirationDate
        } catch {
            return nil
        }
    }
    
    // 価格を日本円で表示
    func getDisplayPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    // プランのタイプを判定
    func getPlanType(for product: Product) -> String {
        if product.id.contains("monthly") {
            return "月額プラン"
        } else if product.id.contains("yearly") {
            return "年額プラン"
        }
        return "プラン"
    }
}

// サブスクリプションの状態
enum SubscriptionStatus {
    case notSubscribed
    case subscribed
    case expired
    case pending
}
