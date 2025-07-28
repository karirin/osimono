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
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // サブスクリプションのプロダクトID（App Store Connectで設定したID）
    private let subscriptionIDs = [
        "monthlySub"
    ]
    
    @Published var debugSubscriptionEnabled: Bool = false {
        didSet {
            if debugSubscriptionEnabled {
                isSubscribed = true
                print("🐛 デバッグモード: サブスクリプション有効")
            } else {
                // 実際の状態を確認
                Task {
                    await updateSubscriptionStatus()
                }
            }
        }
    }
    
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
    
    func toggleDebugSubscription() {
        debugSubscriptionEnabled.toggle()
    }
    
    // 商品情報を取得（改良版）
    func requestProducts() async {
        isLoading = true
        errorMessage = nil
        
        print("🔍 商品情報を取得中...")
        print("📱 App Store接続状況を確認中...")
        
        // Bundle ID確認
        if let bundleID = Bundle.main.bundleIdentifier {
            print("📱 現在のBundle ID: \(bundleID)")
        } else {
            print("❌ Bundle IDが取得できません")
        }
        
        // App Store接続確認
        #if targetEnvironment(simulator)
        print("⚠️ シミュレーターで実行中 - StoreKit Configuration を使用")
        print("💡 確認事項:")
        print("   - Xcodeでスキーム編集 → Options → StoreKit Configuration が選択されているか")
        print("   - .storekitファイルでプロダクトID 'monthly' が設定されているか")
        
        // StoreKit Configuration の状態をチェック
        if let url = Bundle.main.url(forResource: "Configuration", withExtension: "storekit") {
            print("✅ StoreKit Configuration ファイルが見つかりました: \(url.lastPathComponent)")
        } else if let url = Bundle.main.url(forResource: "Products", withExtension: "storekit") {
            print("✅ StoreKit Configuration ファイルが見つかりました: \(url.lastPathComponent)")
        } else {
            print("❌ StoreKit Configuration ファイルが見つかりません")
            print("💡 作成方法: File → New → File → StoreKit Configuration File")
        }
        #else
        print("📱 実機環境で実行中 - App Store Connect の商品情報を使用")
        print("💡 確認事項:")
        print("   - App Store Connect でサブスクリプション商品が設定されているか")
        print("   - Sandboxテスターアカウントでログインしているか")
        #endif
        
        do {
            print("📋 要求するプロダクトID: \(subscriptionIDs)")
            
            // StoreKitの設定ファイルが存在するか確認（シミュレーター用）
            subscriptionProducts = try await SKProduct.products(for: subscriptionIDs)
            
            print("✅ 取得した商品数: \(subscriptionProducts.count)")
            
            if subscriptionProducts.isEmpty {
                #if targetEnvironment(simulator)
                errorMessage = "商品が見つかりません。StoreKit Configuration の設定を確認してください。"
                print("❌ シミュレーター：商品が見つかりません")
                print("🔧 StoreKit Configuration トラブルシューティング:")
                print("   1. Xcodeのスキーム設定でStoreKit Configurationファイルが選択されているか")
                print("   2. .storekitファイルでプロダクトID 'monthly' が設定されているか")
                print("   3. .storekitファイルでサブスクリプションタイプが正しく設定されているか")
                print("   4. Clean Build Folder後に再実行してみる")
                print("   5. Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration を確認")
                print("")
                print("🚨 緊急回避: デバッグモードボタンを押して動作確認可能")
                #else
                errorMessage = "商品が見つかりません。App Store Connectの設定を確認してください。"
                print("❌ 実機：商品が見つかりません")
                print("🔧 App Store Connect トラブルシューティング:")
                print("   1. App Store ConnectでプロダクトID 'monthly' が正しく設定されているか")
                print("   2. 商品のステータスが「準備完了」になっているか")
                print("   3. 契約・税務・銀行情報が完了しているか")
                print("   4. Bundle IDが一致しているか")
                print("   5. Sandboxテスターアカウントでログインしているか")
                print("   6. App Store Connect で商品が承認されているか")
                #endif
            } else {
                // 取得した商品の詳細を出力
                for product in subscriptionProducts {
                    print("📦 商品詳細:")
                    print("   ID: \(product.id)")
                    print("   表示名: \(product.displayName)")
                    print("   説明: \(product.description)")
                    print("   価格: \(product.displayPrice)")
                    print("   タイプ: \(product.type)")
                }
            }
            
        } catch let error as StoreKitError {
            let errorMsg = handleStoreKitError(error)
            errorMessage = errorMsg
            print("❌ StoreKitエラー: \(errorMsg)")
        } catch let error as NSError {
            // NSErrorの場合の詳細なエラー処理
            print("❌ NSError発生:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")
            
            if error.domain == "ASDErrorDomain" {
                // App Store関連のエラー
                switch error.code {
                case 500:
                    errorMessage = "App Storeに接続できません。ネットワーク接続を確認してください。"
                case 1004:
                    errorMessage = "商品が見つかりません。App Store Connectの設定を確認してください。"
                default:
                    errorMessage = "App Storeエラー (コード: \(error.code)): \(error.localizedDescription)"
                }
            } else {
                errorMessage = "エラーが発生しました: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "予期しないエラーが発生しました: \(error.localizedDescription)"
            print("❌ 予期しないエラー: \(error)")
            print("   エラータイプ: \(type(of: error))")
            print("   詳細: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // StoreKitエラーの詳細処理
    private func handleStoreKitError(_ error: StoreKitError) -> String {
        switch error {
        case .userCancelled:
            return "ユーザーがキャンセルしました"
        case .notEntitled:
            return "購入権限がありません"
        case .networkError(let underlyingError):
            return "ネットワークエラー: \(underlyingError.localizedDescription)"
        case .systemError(let underlyingError):
            return "システムエラー: \(underlyingError.localizedDescription)"
        case .unknown:
            return "不明なエラーが発生しました"
        @unknown default:
            return "予期しないStoreKitエラー: \(error.localizedDescription)"
        }
    }
    
    // 購入処理
    func purchase(_ product: SKProduct) async throws -> SKTransaction? {
        isLoading = true
        errorMessage = nil
        
        print("💳 購入開始: \(product.displayName)")
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                print("✅ 購入成功")
                let transaction = checkVerified(verification)
                await updateSubscriptionStatus()
                await transaction.finish()
                isLoading = false
                return transaction
            case .userCancelled:
                print("👤 ユーザーが購入をキャンセルしました")
                isLoading = false
                return nil
            case .pending:
                print("⏳ 購入が保留中です")
                isLoading = false
                return nil
            default:
                print("❓ 不明な購入結果")
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            throw error
        }
    }
    
    // サブスクリプション状態の更新
    func updateSubscriptionStatus() async {
        print("🔄 サブスクリプション状態を更新中...")
        
        var hasActiveSubscription = false
        var activeSubscription: SKProduct? = nil
        
        // 現在有効なエンタイトルメントをチェック
        for await result in SKTransaction.currentEntitlements {
            do {
                let transaction = checkVerified(result)
                print("📋 エンタイトルメント確認: \(transaction.productID)")
                
                // サブスクリプションIDに含まれているかチェック
                if subscriptionIDs.contains(transaction.productID) {
                    hasActiveSubscription = true
                    print("✅ アクティブなサブスクリプション発見: \(transaction.productID)")
                    
                    // 対応するProductを見つける
                    if let product = subscriptionProducts.first(where: { $0.id == transaction.productID }) {
                        activeSubscription = product
                    }
                    break
                }
            } catch {
                print("❌ トランザクションの検証に失敗しました: \(error)")
            }
        }
        
        self.isSubscribed = hasActiveSubscription
        self.currentSubscription = activeSubscription
        
        print("📊 サブスクリプション状態: \(hasActiveSubscription ? "有効" : "無効")")
    }
    
    // トランザクションの監視
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            print("👂 トランザクション監視を開始")
            for await result in SKTransaction.updates {
                do {
                    let transaction = await self.checkVerified(result)
                    print("🔄 新しいトランザクション: \(transaction.productID)")
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("❌ トランザクションの更新に失敗しました: \(error)")
                }
            }
        }
    }
    
    // トランザクションの検証
    func checkVerified<T>(_ result: VerificationResult<T>) -> T {
        switch result {
        case .unverified:
            print("⚠️ 未検証のトランザクションが検出されました")
            fatalError("未検証のトランザクション")
        case .verified(let safe):
            return safe
        }
    }
    
    // 購入復元
    func restorePurchases() async {
        isLoading = true
        print("🔄 購入を復元中...")
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ 購入復元完了")
        } catch {
            print("❌ 購入復元エラー: \(error)")
            errorMessage = "購入復元に失敗しました: \(error.localizedDescription)"
        }
        
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
            print("❌ 有効期限の取得に失敗しました: \(error)")
            return nil
        }
    }
    
    // 価格を表示用文字列で取得
    func getDisplayPrice(for product: SKProduct) -> String {
        return product.displayPrice
    }
    
    // プランのタイプを判定
    func getPlanType(for product: SKProduct) -> String {
        if product.id.contains("monthlySub") {
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
            print("❌ サブスクリプション詳細の取得に失敗しました: \(error)")
            return nil
        }
    }
    
    // デバッグ用：現在の状態を出力
    func printDebugInfo() {
        print("=== サブスクリプション状態 ===")
        print("商品数: \(subscriptionProducts.count)")
        print("サブスクリプション状態: \(isSubscribed)")
        print("現在のサブスクリプション: \(currentSubscription?.id ?? "なし")")
        print("エラーメッセージ: \(errorMessage ?? "なし")")
        
        for product in subscriptionProducts {
            print("商品: \(product.id) - \(product.displayName) - \(product.displayPrice)")
        }
        
        #if targetEnvironment(simulator)
        print("⚠️ シミュレーター環境で実行中")
        #else
        print("📱 実機環境で実行中")
        #endif
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
