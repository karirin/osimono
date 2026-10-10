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
    // 無料トライアル（導入オファー）の対象になっているプロダクトID
    @Published var introOfferEligibleProductIDs: Set<String> = []
    
    private var updateListenerTask: Task<Void, Error>? = nil
    
    // サブスクリプションのプロダクトID（App Store Connectで設定したID）
    private let subscriptionIDs = [
        "weeklySub",
        "monthlySub",
        "yearlySub"
    ]
    
    @Published var debugSubscriptionEnabled: Bool = PremiumFeatures.developmentPremiumEnabled {
        didSet {
            #if DEBUG
            UserDefaults.standard.set(debugSubscriptionEnabled, forKey: PremiumFeatures.developmentPremiumKey)
            #endif
            isSubscribed = PremiumFeatures.isActive
            Task {
                await updateSubscriptionStatus()
            }
        }
    }
    
    // アプリ全体で SubscriptionManager.shared の1つだけを使う
    // （画面ごとに作ると isSubscribed=false から始まり、課金ユーザーが一時的に無料扱いになるため）
    private init() {
        // StoreKit の確認が終わるまでは前回の状態を使う
        isSubscribed = PremiumFeatures.isActive
        
        // トランザクションの監視を開始
        updateListenerTask = listenForTransactions()
        
        Task {
            // 商品情報の取得（通信）を待たずに、まず購読状態を確定させる
            await updateSubscriptionStatus()
            await requestProducts()
            // currentSubscription を商品情報と紐付けるためにもう一度確認
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
        print("   - .storekitファイルでプロダクトID 'weeklySub', 'monthlySub', 'yearlySub' が設定されているか")
        
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
            
            // 期間順でソート（週間 → 月間 → 年間）
            subscriptionProducts.sort { product1, product2 in
                let order1 = getProductOrder(product1)
                let order2 = getProductOrder(product2)
                return order1 < order2
            }
            
            print("✅ 取得した商品数: \(subscriptionProducts.count)")
            
            await updateIntroOfferEligibility()
            
            if subscriptionProducts.isEmpty {
                #if targetEnvironment(simulator)
                errorMessage = "商品が見つかりません。StoreKit Configuration の設定を確認してください。"
                print("❌ シミュレーター：商品が見つかりません")
                print("🔧 StoreKit Configuration トラブルシューティング:")
                print("   1. Xcodeのスキーム設定でStoreKit Configurationファイルが選択されているか")
                print("   2. .storekitファイルでプロダクトID 'weeklySub', 'monthlySub', 'yearlySub' が設定されているか")
                print("   3. .storekitファイルでサブスクリプションタイプが正しく設定されているか")
                print("   4. Clean Build Folder後に再実行してみる")
                print("   5. Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration を確認")
                print("")
                print("🚨 緊急回避: デバッグモードボタンを押して動作確認可能")
                #else
                errorMessage = "商品が見つかりません。App Store Connectの設定を確認してください。"
                print("❌ 実機：商品が見つかりません")
                print("🔧 App Store Connect トラブルシューティング:")
                print("   1. App Store ConnectでプロダクトID 'weeklySub', 'monthlySub', 'yearlySub' が正しく設定されているか")
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
                    print("   生価格: \(product.price)")
                    print("   通貨コード: \(product.priceFormatStyle.currencyCode)")
                    print("   ロケール: \(product.priceFormatStyle.locale)")
                    print("   タイプ: \(product.type)")
                    print("   期間: \(getPlanType(for: product))")
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
    
    // 無料トライアルの対象かどうかを更新（同じグループで一度でも購読したユーザーは対象外）
    func updateIntroOfferEligibility() async {
        var eligibleIDs: Set<String> = []
        for product in subscriptionProducts {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer?.paymentMode == .freeTrial else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligibleIDs.insert(product.id)
            }
        }
        introOfferEligibleProductIDs = eligibleIDs
        print("🎁 無料トライアル対象: \(eligibleIDs)")
    }
    
    // 無料トライアルの日数（対象外・トライアルなし・Remote Config で訴求オフの場合はnil）
    func freeTrialDays(for product: SKProduct) -> Int? {
        guard PaywallConfig.shared.trialEnabled,
              introOfferEligibleProductIDs.contains(product.id),
              let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return period.value * offer.periodCount
        case .week: return period.value * 7 * offer.periodCount
        case .month: return period.value * 30 * offer.periodCount
        case .year: return period.value * 365 * offer.periodCount
        @unknown default: return nil
        }
    }
    
    // 商品の順序を取得（ソート用）
    private func getProductOrder(_ product: SKProduct) -> Int {
        if product.id.contains("weeklySub") {
            return 1
        } else if product.id.contains("monthlySub") {
            return 2
        } else if product.id.contains("yearlySub") {
            return 3
        }
        return 4
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
                let transaction = try checkVerified(verification)
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
                let transaction = try checkVerified(result)
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
        
        // 購入状態だけを保存し、開発用プレミアムが Release ビルドに引き継がれないようにする。
        UserDefaults.standard.set(hasActiveSubscription, forKey: PremiumFeatures.subscriptionCacheKey)
        self.isSubscribed = PremiumFeatures.isActive
        self.currentSubscription = activeSubscription
        if isSubscribed {
            // 購読済みなら翌日の限定オファー通知は不要
            PaywallCampaignManager.shared.cancelWinBack()
        }
        
        print("📊 サブスクリプション状態: \(isSubscribed ? "有効" : "無効")")
    }
    
    // トランザクションの監視
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            print("👂 トランザクション監視を開始")
            for await result in SKTransaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await self.checkVerified(result)
                    print("🔄 新しいトランザクション: \(transaction.productID)")
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("❌ トランザクションの更新に失敗しました: \(error)")
                }
            }
        }
    }
    
    enum VerificationError: Error {
        case unverified
    }
    
    // トランザクションの検証（未検証のものはクラッシュさせずに無視できるよう throw する）
    func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            print("⚠️ 未検証のトランザクションを無視します: \(error)")
            throw VerificationError.unverified
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
            let verifiedTx = try checkVerified(status.transaction)
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
    
    // 日本円フォーマットで価格を取得（デバッグ用途も含む）
    func getJPYFormattedPrice(for product: SKProduct) -> String {
        // まず製品の元の価格情報をログ出力
        print("🪙 価格情報: \(product.id)")
        print("   displayPrice: \(product.displayPrice)")
        print("   price: \(product.price)")
        print("   currencyCode: \(product.priceFormatStyle.currencyCode)")
        print("   locale: \(product.priceFormatStyle.locale)")
        
        // 日本円フォーマッターを使用
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.currencyCode = "JPY"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        let nsDecimalNumber = NSDecimalNumber(decimal: product.price)
        let formattedPrice = formatter.string(from: nsDecimalNumber)
        
        print("   JPY formatted: \(formattedPrice ?? "変換失敗")")
        
        return formattedPrice ?? product.displayPrice
    }
    
    // プランのタイプを判定
    func getPlanType(for product: SKProduct) -> String {
        if product.id.contains("weeklySub") {
            return "週間プラン"
        } else if product.id.contains("monthlySub") {
            return "月額プラン"
        } else if product.id.contains("yearlySub") {
            return "年額プラン"
        }
        return "プラン"
    }
    
    // プランの特徴を取得
    func getPlanDescription(for product: SKProduct) -> String {
        if product.id.contains("weeklySub") {
            return "お試しに最適"
        } else if product.id.contains("monthlySub") {
            return "最も人気"
        } else if product.id.contains("yearlySub") {
            return "最もお得"
        }
        return ""
    }
    
    // 年額プランの月額換算価格を計算
    func getMonthlyEquivalentPrice(for product: SKProduct) -> String? {
        guard product.id.contains("yearlySub") else { return nil }
        
        // 価格を12で割って月額換算
        let yearlyPrice = product.price
        let monthlyEquivalent = yearlyPrice / 12
        
        print("💰 年額換算計算: \(product.id)")
        print("   年額: \(yearlyPrice)")
        print("   月額換算: \(monthlyEquivalent)")
        
        // 日本円フォーマッターを使用
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.currencyCode = "JPY"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        // DecimalをNSDecimalNumberに変換
        let nsDecimalNumber = NSDecimalNumber(decimal: monthlyEquivalent)
        let result = formatter.string(from: nsDecimalNumber)
        
        print("   フォーマット結果: \(result ?? "変換失敗")")
        
        return result
    }
    
    // サブスクリプションの詳細情報を取得
    func getSubscriptionDetails() async -> SubscriptionDetails? {
        guard let subscription = currentSubscription?.subscription else { return nil }
        
        do {
            guard let status = try await subscription.status.first else { return nil }
            let renewalInfo = try checkVerified(status.renewalInfo)
            let verifiedTx = try checkVerified(status.transaction)
            
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
