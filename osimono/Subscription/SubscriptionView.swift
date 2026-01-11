//
//  SubscriptionView.swift
//  osimono
//
//  Created by Apple on 2025/07/12.
//

import SwiftUI
import StoreKit

struct SubscriptionPreView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedProduct: Product?
    @State private var animateContent = false
    
    let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.95, green: 0.6, blue: 0.75),
            Color(red: 0.75, green: 0.55, blue: 0.95),
            Color(red: 0.55, green: 0.65, blue: 0.95)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    let accentColor = Color(red: 0.75, green: 0.55, blue: 0.95)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ヘッダーバナー画像
                        headerBannerSection
                        
                        // メインコンテンツ
                        VStack(spacing: 24) {
                            // タイトルセクション
                            titleSection
                            
                            // プレミアム特典（横スクロール）- 料金プランより上
                            featuresSection
                            
                            // 料金プランセクション
                            pricingSection
                            
                            // 購入ボタン
                            if selectedProduct != nil {
                                purchaseButtonSection
                            }
                            
                            // フッター
                            footerSection
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    dismissButton
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            animateOnAppear()
        }
        .onChange(of: subscriptionManager.subscriptionProducts) { products in
            if selectedProduct == nil, let monthly = products.first(where: { $0.id.contains("monthlySub") }) {
                selectedProduct = monthly
            } else if selectedProduct == nil, let firstProduct = products.first {
                selectedProduct = firstProduct
            }
        }
        .onChange(of: subscriptionManager.isSubscribed) { isSubscribed in
            if isSubscribed {
                alertMessage = "サブスクリプションが開始されました！"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    // MARK: - Header Banner Section
    private var headerBannerSection: some View {
        ZStack(alignment: .bottom) {
            Image("subscription_banner")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
            
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground).opacity(0),
                    Color(.systemGroupedBackground).opacity(0.5),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        }
        .frame(height: 200)
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(primaryGradient)
                
                Text("プレミアムプラン")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 15)
            .animation(.easeOut(duration: 0.5).delay(0.1), value: animateContent)
            
            Text("推しとの時間をもっと特別に")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(animateContent ? 1 : 0)
                .offset(y: animateContent ? 0 : 15)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: animateContent)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Features Section (横スクロール)
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プレミアム特典")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CompactFeatureCard(
                        icon: "infinity",
                        iconColor: .purple,
                        title: "チャット無制限",
                        description: "推しとのチャットが\n無制限で楽しめる"
                    )
                    
                    CompactFeatureCard(
                        icon: "rectangle.badge.xmark",
                        iconColor: .orange,
                        title: "広告非表示",
                        description: "全ての広告が\n非表示になります"
                    )
                    
                    CompactFeatureCard(
                        icon: "person.2.fill",
                        iconColor: .blue,
                        title: "推し登録無制限",
                        description: "何人でも推しを\n登録できます"
                    )
                }
                .padding(.horizontal, 20)
            }
            .opacity(animateContent ? 1 : 0)
            .offset(x: animateContent ? 0 : 30)
            .animation(.easeOut(duration: 0.5).delay(0.4), value: animateContent)
        }
    }
    
    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoading {
                LoadingPreView()
            } else if let errorMessage = subscriptionManager.errorMessage {
                ErrorView(
                    errorMessage: errorMessage,
                    primaryGradient: primaryGradient,
                    onRetry: {
                        Task { await subscriptionManager.requestProducts() }
                    },
                    onDebug: { subscriptionManager.printDebugInfo() }
                )
                .padding(.horizontal, 20)
            } else if subscriptionManager.subscriptionProducts.isEmpty {
                EmptyStatePreView(
                    primaryGradient: primaryGradient,
                    onReload: {
                        Task { await subscriptionManager.requestProducts() }
                    },
                    onDebug: { subscriptionManager.printDebugInfo() }
                )
                .padding(.horizontal, 20)
            } else {
                let sortedProducts = subscriptionManager.subscriptionProducts.sorted { p1, p2 in
                    if p1.id.contains("yearlySub") { return true }
                    if p2.id.contains("yearlySub") { return false }
                    if p1.id.contains("monthlySub") { return true }
                    return false
                }
                
                ForEach(Array(sortedProducts.enumerated()), id: \.element.id) { index, product in
                    CompactPlanCard(
                        product: product,
                        subscriptionManager: subscriptionManager,
                        isSelected: selectedProduct?.id == product.id,
                        onSelect: { selectedProduct = product },
                        primaryGradient: primaryGradient
                    )
                    .padding(.horizontal, 20)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.5 + Double(index) * 0.1), value: animateContent)
                }
            }
        }
    }
    
    // MARK: - Purchase Button Section
    private var purchaseButtonSection: some View {
        VStack(spacing: 16) {
            if let product = selectedProduct {
                Button(action: { purchaseSubscription(product) }) {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                            Text("プレミアムを始める")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(primaryGradient)
                    )
                    .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .disabled(isLoading)
                .padding(.horizontal, 20)
                .opacity(animateContent ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.8), value: animateContent)
            }
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button("購入を復元") {
                restorePurchases()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(accentColor)
            
            HStack(spacing: 20) {
                NavigationLink("利用規約", destination: TermsOfServiceView())
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                NavigationLink("プライバシーポリシー", destination: PrivacyView())
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            
            Text("購読は自動更新されます。解約はApp Storeの設定から可能です。")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Dismiss Button
    private var dismissButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
    }
    
    // MARK: - Helper Functions
    private func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation { animateContent = true }
        }
        
        if let monthly = subscriptionManager.subscriptionProducts.first(where: { $0.id.contains("monthlySub") }) {
            selectedProduct = monthly
        } else if let firstProduct = subscriptionManager.subscriptionProducts.first {
            selectedProduct = firstProduct
        }
    }
    
    private func purchaseSubscription(_ product: Product) {
        isLoading = true
        Task {
            do {
                let transaction = try await subscriptionManager.purchase(product)
                if transaction != nil {
                    generateHapticFeedback()
                } else {
                    alertMessage = "購入がキャンセルされました"
                    showAlert = true
                }
            } catch {
                alertMessage = "購入に失敗しました: \(error.localizedDescription)"
                showAlert = true
            }
            isLoading = false
        }
    }
    
    private func restorePurchases() {
        isLoading = true
        Task {
            await subscriptionManager.restorePurchases()
            alertMessage = subscriptionManager.isSubscribed ? "購入が復元されました" : "復元できる購入がありませんでした"
            showAlert = true
            isLoading = false
        }
    }
    
    private func generateHapticFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - Compact Feature Card (横スクロール用)
struct CompactFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // アイコンとタイトル
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            // 説明文
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)
        }
        .frame(width: 140)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Compact Plan Card
struct CompactPlanCard: View {
    let product: Product
    let subscriptionManager: SubscriptionManager
    let isSelected: Bool
    let onSelect: () -> Void
    let primaryGradient: LinearGradient
    
    var isYearly: Bool { product.id.contains("yearlySub") }
    var isMonthly: Bool { product.id.contains("monthlySub") }
    var isWeekly: Bool { product.id.contains("weeklySub") }
    
    var planName: String {
        if isYearly { return "年間プラン" }
        if isMonthly { return "月間プラン" }
        return "週間プラン"
    }
    
    var priceText: String {
        if isYearly { return "¥9,800/年" }
        if isMonthly { return "¥980/月" }
        return "¥480/週"
    }
    
    var badge: (text: String, color: LinearGradient)? {
        if isYearly {
            return ("2ヶ月分お得", LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
        }
        if isMonthly {
            return ("人気", LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
        }
        return nil
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // 選択インジケーター
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(primaryGradient)
                            .frame(width: 22, height: 22)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // プラン情報
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(planName)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge.text)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(badge.color))
                        }
                    }
                    
                    if isYearly {
                        Text("月額換算 ¥817")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 価格
                Text(priceText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? primaryGradient : LinearGradient(colors: [.primary], startPoint: .leading, endPoint: .trailing))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? primaryGradient : LinearGradient(colors: [Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: isSelected ? 2 : 1)
                    )
                    .shadow(color: isSelected ? Color.purple.opacity(0.12) : Color.clear, radius: 6, x: 0, y: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Loading View
struct LoadingPreView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(.purple)
            
            Text("プランを読み込み中...")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(height: 80)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let errorMessage: String
    let primaryGradient: LinearGradient
    let onRetry: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            Text("読み込みに失敗しました")
                .font(.system(size: 14, weight: .semibold))
            
            Text(errorMessage)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("再試行") { onRetry() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryGradient)
                    .cornerRadius(16)
                
                Button("デバッグ") { onDebug() }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
    }
}

// MARK: - Empty State View
struct EmptyStatePreView: View {
    let primaryGradient: LinearGradient
    let onReload: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 28))
                .foregroundColor(.gray)
            
            Text("利用可能なプランがありません")
                .font(.system(size: 14, weight: .semibold))
            
            HStack(spacing: 12) {
                Button("再読み込み") { onReload() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(primaryGradient)
                    .cornerRadius(16)
                
                Button("デバッグ") { onDebug() }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
        )
    }
}

#Preview {
    SubscriptionPreView()
}
