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
    @State private var animateFeatures = false
    
    // 改良されたグラデーション
    let primaryGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.3, blue: 0.6),
            Color(red: 0.6, green: 0.2, blue: 1.0),
            Color(red: 0.2, green: 0.4, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    let backgroundGradient = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(red: 0.98, green: 0.97, blue: 1.0),
            Color(red: 0.95, green: 0.95, blue: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    let accentColor = Color(red: 0.6, green: 0.2, blue: 1.0)
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 40) {
                    // 改良されたヘッダー
                    VStack(spacing: 24) {
                        // 3Dライクなクラウンアイコン
                        ZStack {
                            // 背景の輝き効果
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.yellow.opacity(0.8),
//                                            primaryGradient.opacity(0.8)
                                        ],
                                        center: .topLeading,
                                        startRadius: 20,
                                        endRadius: 80
                                    )
                                )
                                .frame(width: 140, height: 140)
                                .shadow(color: Color.pink.opacity(0.4), radius: 25, x: 0, y: 15)
                            
                            // グラデーションオーバーレイ
                            Circle()
                                .fill(primaryGradient.opacity(0.1))
                                .frame(width: 120, height: 120)
                            
                            // クラウンアイコン
                            Image(systemName: "crown.fill")
                                .font(.system(size: 55, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                        }
                        .scaleEffect(animateFeatures ? 1.0 : 0.8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateFeatures)
                        
                    VStack(spacing: 16) {
                            Text("プレミアムプラン")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryGradient)
                                .opacity(animateFeatures ? 1 : 0)
                                .offset(y: animateFeatures ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: animateFeatures)
                            
                            Text("広告なしで推し活をもっと楽しく\n特別な機能で推しとの時間をより豊かに")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                                .opacity(animateFeatures ? 1 : 0)
                                .offset(y: animateFeatures ? 0 : 20)
                                .animation(.easeOut(duration: 0.8).delay(0.4), value: animateFeatures)
                        }
                    }
                    
                    // アニメーション付き特典セクション
                    featuresSection
                    
                    // 料金プランセクション
                    pricingSection
                    
                    // 購入ボタン
                    if selectedProduct != nil {
                        purchaseButtonSection
                    }
                    
                    // フッターセクション
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .background(backgroundGradient.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: dismissButton
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            animateOnAppear()
        }
        .onChange(of: subscriptionManager.subscriptionProducts) { products in
            if selectedProduct == nil, let firstProduct = products.first {
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
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("プラン加入特典")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .opacity(animateFeatures ? 1 : 0)
                    .offset(x: animateFeatures ? 0 : -30)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: animateFeatures)
                Spacer()
            }
            
            VStack(spacing: 16) {
                ModernFeatureCard(
                    icon: "star.bubble.fill",
                    title: "推しとのチャットが無制限に",
                    description: "どれだけ推しとチャットしても制限が無く\n広告も表示されません",
                    gradient: LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                    delay: 0.8,
                    isVisible: $animateFeatures
                )
                
                ModernFeatureCard(
                    icon: "rectangle.fill.badge.xmark",
                    title: "広告が非表示に",
                    description: "アプリ内で表示されている全ての広告が非表示になります",
                    gradient: LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                    delay: 1.0,
                    isVisible: $animateFeatures
                )
                
                ModernFeatureCard(
                    icon: "person.2.badge.plus.fill",
                    title: "推しの登録が無制限に",
                    description: "何人推しを登録しても制限がかからなくなります",
                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                    delay: 1.2,
                    isVisible: $animateFeatures
                )
            }
        }
    }
    
    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("料金プラン")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Spacer()
            }
            
            if subscriptionManager.isLoading {
                LoadingPreView()
            } else if let errorMessage = subscriptionManager.errorMessage {
                ErrorView(
                    errorMessage: errorMessage,
                    primaryGradient: primaryGradient,
                    onRetry: {
                        Task {
                            await subscriptionManager.requestProducts()
                        }
                    },
                    onDebug: {
                        subscriptionManager.printDebugInfo()
                    }
                )
            } else if subscriptionManager.subscriptionProducts.isEmpty {
                EmptyStatePreView(
                    primaryGradient: primaryGradient,
                    onReload: {
                        Task {
                            await subscriptionManager.requestProducts()
                        }
                    },
                    onDebug: {
                        subscriptionManager.printDebugInfo()
                    }
                )
            } else {
                VStack(spacing: 16) {
                    ForEach(subscriptionManager.subscriptionProducts, id: \.id) { product in
                        UltraModernPlanCard(
                            product: product,
                            subscriptionManager: subscriptionManager,
                            isSelected: selectedProduct?.id == product.id,
                            onSelect: { selectedProduct = product },
                            primaryGradient: primaryGradient
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Purchase Button Section
    private var purchaseButtonSection: some View {
        VStack(spacing: 20) {
            if let product = selectedProduct {
                Button(action: {
                    purchaseSubscription(product)
                }) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        } else {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("プレミアムプランを開始")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 30)
                                .fill(primaryGradient)
                            
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .shadow(color: Color.pink.opacity(0.4), radius: 20, x: 0, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.6), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                }
                .disabled(isLoading)
                .scaleEffect(isLoading ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isLoading)
            }
        }
    }
    
    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 24) {
            Button("購入を復元") {
                restorePurchases()
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(accentColor)
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color(.systemBackground))
                    .shadow(color: accentColor.opacity(0.2), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(accentColor.opacity(0.3), lineWidth: 1.5)
                    )
            )
            
            HStack(spacing: 40) {
                NavigationLink("利用規約", destination: TermsOfServiceView())
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                
                NavigationLink("プライバシーポリシー", destination: PrivacyView())
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
            }
            
            Text("購読は自動更新されます。解約はApp Storeの設定から行えます。")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Dismiss Button
    private var dismissButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
        }
    }
    
    // MARK: - Helper Functions
    private func animateOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                animateFeatures = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if let monthly = subscriptionManager.subscriptionProducts.first(where: { $0.id.contains("monthlySub") }) {
                selectedProduct = monthly
            } else if let firstProduct = subscriptionManager.subscriptionProducts.first {
                selectedProduct = firstProduct
            }
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
            
            if subscriptionManager.isSubscribed {
                alertMessage = "購入が復元されました"
            } else {
                alertMessage = "復元できる購入がありませんでした"
            }
            showAlert = true
            isLoading = false
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Modern Feature Card
struct ModernFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let gradient: LinearGradient
    let delay: Double
    @Binding var isVisible: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 20) {
            // アイコン部分
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(gradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: .clear, radius: 12, x: 0, y: 6)
                
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            
            // テキスト部分
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(
                    color: .black.opacity(isHovered ? 0.15 : 0.08),
                    radius: isHovered ? 16 : 8,
                    x: 0,
                    y: isHovered ? 8 : 4
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white, .gray.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : 50)
        .animation(.easeOut(duration: 0.8).delay(delay), value: isVisible)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isHovered.toggle()
                }
            }
        }
    }
}

// MARK: - Ultra Modern Plan Card
struct UltraModernPlanCard: View {
    let product: Product
    let subscriptionManager: SubscriptionManager
    let isSelected: Bool
    let onSelect: () -> Void
    let primaryGradient: LinearGradient
    
    var isYearly: Bool {
        product.id.contains("yearlySub")
    }
    
    var isWeekly: Bool {
        product.id.contains("weeklySub")
    }
    
    var isMonthly: Bool {
        product.id.contains("monthlySub")
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // メインカード
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(subscriptionManager.getPlanType(for: product))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                    // バッジ
                                    if isYearly || isMonthly {
                                        HStack {
                                            HStack(spacing: 6) {
                                                Image(systemName: isYearly ? "star.fill" : "heart.fill")
                                                    .font(.system(size: 12, weight: .bold))
                                                Text(isYearly ? "最もお得" : "人気")
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(isYearly ?
                                                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing) :
                                                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                                                    )
                                                    .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                            )
                                            Spacer()
                                        }
                                        .zIndex(1)
                                    }
                            }
                            
                            HStack(alignment: .bottom, spacing: 4) {
                                Group {
                                    if isYearly {
                                        Text("9,800円")
                                    } else if isMonthly {
                                        Text("980円")
                                    } else if isWeekly {
                                        Text("480円")
                                    }
                                }
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryGradient)
                                
                                Group {
                                    if isYearly {
                                        Text("/年")
                                    } else if isMonthly {
                                        Text("/月")
                                    } else if isWeekly {
                                        Text("/週")
                                    }
                                }
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                            }
                            
                            // サブテキスト
                            Group {
                                if isYearly {
                                    Text("月払いの2ヶ月分が無料")
                                } else if isMonthly {
                                    Text("週間プランの50％オフ")
                                } else if isWeekly {
                                    Text("お試しに最適")
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 選択インジケーター
                        ZStack {
                            Circle()
                                .fill(
                                    isSelected ?
                                    primaryGradient :
                                    LinearGradient(colors: [.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 32, height: 32)
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .shadow(color:.clear, radius: 8)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected ? primaryGradient :
                                    LinearGradient(colors: [.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: .black.opacity(0.05),
                            radius: isSelected ? 20 : 8,
                            x: 0,
                            y: isSelected ? 10 : 4
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Loading View
struct LoadingPreView: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotationAngle)
            }
            
            Text("プランを読み込み中...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Error View (Enhanced)
struct ErrorView: View {
    let errorMessage: String
    let primaryGradient: LinearGradient
    let onRetry: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 16) {
                Text("商品の読み込みに失敗しました")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text(errorMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            VStack(spacing: 16) {
                Button("再試行") {
                    onRetry()
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(primaryGradient)
                .cornerRadius(25)
//                .shadow(color: primaryGradient.colors.first?.opacity(0.4) ?? .clear, radius: 12, x: 0, y: 6)
                
                Button("デバッグ情報") {
                    onDebug()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Empty State View (Enhanced)
struct EmptyStatePreView: View {
    let primaryGradient: LinearGradient
    let onReload: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.gray.opacity(0.3), .gray.opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "cart.badge.questionmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 16) {
                Text("利用可能なプランがありません")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                
                Text("App Store Connectでサブスクリプション商品が正しく設定されているか確認してください")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            
            VStack(spacing: 12) {
                Button("再読み込み") {
                    onReload()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(primaryGradient)
                .cornerRadius(20)
                
                Button("デバッグ情報") {
                    onDebug()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(24)
    }
}

#Preview {
    SubscriptionPreView()
}
