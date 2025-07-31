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
    
    // グラデーションカラー
    let primaryGradient = LinearGradient(
        colors: [Color(.systemPink), Color(.systemPurple)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    let accentColor = Color(.systemPurple)
    
    @State private var showingPrivacySettings = false
    @State private var showingShareSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 32) {
                    // ヘッダー（グラデーション背景付き）
                    VStack(spacing: 20) {
                        // アニメーション付きクラウンアイコン
                        ZStack {
                            Circle()
                                .fill(primaryGradient)
                                .frame(width: 120, height: 120)
                                .shadow(color: Color.pink.opacity(0.4), radius: 20, x: 0, y: 10)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 50, weight: .medium))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            Text("プレミアムプラン")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(primaryGradient)
                            
                            Text("広告なしで推し活をもっと楽しく\n特別な機能で推しとの時間をより豊かに")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.top, 10)
                    
                    // 特典一覧（カード形式）
                    VStack(spacing: 20) {
                        HStack {
                            Text("プラン加入特典")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
//                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            FeatureCard(
                                icon: "star.bubble.fill",
                                title: "推しとのチャットが無制限に",
                                description: "どれだけ推しとチャットしても制限が無く\n広告も表示されません",
                                color: .purple
                            )
                            
                            FeatureCard(
                                icon: "rectangle.fill.badge.xmark",
                                title: "広告が非表示に",
                                description: "アプリ内で表示されている全ての広告が非表示になります",
                                color: .red
                            )
                            
                            FeatureCard(
                                icon: "person.2.badge.plus.fill",
                                title: "推しの登録が無制限に",
                                description: "何人推しを登録しても制限がかからなくなります",
                                color: .blue
                            )
//                        }
                    }
                    
                    // 料金プラン
                    VStack(spacing: 20) {
                        HStack {
                            Text("料金プラン")
                                .font(.title2)
                                .fontWeight(.bold)
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
                            VStack(spacing: 12) {
                                ForEach(subscriptionManager.subscriptionProducts, id: \.id) { product in
                                    ModernPlanCard(
                                        product: product,
                                        subscriptionManager: subscriptionManager,
                                        isSelected: selectedProduct?.id == product.id,
                                        onSelect: { selectedProduct = product }
                                    )
                                }
                            }
                        }
                    }
                    
                    // 購入ボタン
                    if let product = selectedProduct {
                        VStack(spacing: 16) {
                            Button(action: {
                                purchaseSubscription(product)
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("プレミアムプランを開始")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(primaryGradient)
                                .cornerRadius(28)
                                .shadow(color: Color.pink.opacity(0.3), radius: 10, x: 0, y: 5)
                            }
                            .disabled(isLoading)
                            .scaleEffect(isLoading ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: isLoading)
                        }
                    }
                    
                    // フッター
                    VStack(spacing: 20) {
                        Button("購入を復元") {
                            restorePurchases()
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(accentColor)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        )
                        
                        HStack(spacing: 32) {
                            NavigationLink("利用規約", destination: TermsOfServiceView())
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                            
                            NavigationLink("プライバシーポリシー", destination: PrivacyView())
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        Text("購読は自動更新されます。解約はApp Storeの設定から行えます。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("プレミアムプラン")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Circle().fill(Color(.systemGray5)))
                }
            )
//            .navigationDestination(isPresented: $showingPrivacySettings) {
//                PrivacyView()
//            }
//            .navigationDestination(isPresented: $showingShareSettings) {
//                TermsOfServiceView()
//            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let monthly = subscriptionManager.subscriptionProducts.first(where: { $0.id.contains("monthlySub") }) {
                    selectedProduct = subscriptionManager.subscriptionProducts.first(where: { $0.id.contains("monthlySub") })
                }
            }
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

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack{
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(color)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 20))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Modern Plan Card
struct ModernPlanCard: View {
    let product: Product
    let subscriptionManager: SubscriptionManager
    let isSelected: Bool
    let onSelect: () -> Void
    
    let primaryGradient = LinearGradient(
        colors: [Color(.systemPink), Color(.systemPurple)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
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
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack{
                                Text(subscriptionManager.getPlanType(for: product))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                if isYearly {
                                    HStack {
                                        Text("最もお得")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(LinearGradient(
                                                        colors: [.orange, .red],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ))
                                            )
                                        Spacer()
                                    }
                                    .zIndex(1)
                                } else if isMonthly {
                                    HStack {
                                        Text("人気")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(LinearGradient(
                                                        colors: [.blue, .purple],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    ))
                                            )
                                        Spacer()
                                    }
                                }
                            }
                            
                            HStack(alignment: .bottom, spacing: 4) {
                                if isYearly {
                                    
                                        Text("9,800円")
                                                                            .font(.title)
                                                                            .fontWeight(.bold)
                                                                            .foregroundStyle( .primary)
                                    Text("/年")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if isMonthly {
                                    Text("980円")
                                                                        .font(.title)
                                                                        .fontWeight(.bold)
                                                                        .foregroundStyle( .primary)
                                    Text("/月")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if isWeekly {
                                    Text("480円")
                                                                        .font(.title)
                                                                        .fontWeight(.bold)
                                                                        .foregroundStyle( .primary)
                                    Text("/週")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 料金の説明
                            if isYearly {
                                if let monthlyPrice = subscriptionManager.getMonthlyEquivalentPrice(for: product) {
                                    Text("月払いの2ヶ月分が無料")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("最もお得なプラン")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if isWeekly {
                                Text("お試しに最適")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if isMonthly {
                                Text("週間プランの50％オフ")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 2)
                                .frame(width: 28, height: 28)
                            
                            if isSelected {
                                Circle()
                                    .fill(primaryGradient)
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    Color.gray.opacity(0.2),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .shadow(
                            color: isSelected ? Color.pink.opacity(0.2) : Color.black.opacity(0.05),
                            radius: isSelected ? 12 : 4,
                            x: 0,
                            y: isSelected ? 6 : 2
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Loading View
struct LoadingPreView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("プランを読み込み中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let errorMessage: String
    let primaryGradient: LinearGradient
    let onRetry: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 12) {
                Text("商品の読み込みに失敗しました")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Button("再試行") {
                    onRetry()
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8)
        )
    }
}

// MARK: - Empty State View
struct EmptyStatePreView: View {
    let primaryGradient: LinearGradient
    let onReload: () -> Void
    let onDebug: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "cart.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 12) {
                Text("利用可能なプランがありません")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("App Store Connectでサブスクリプション商品が正しく設定されているか確認してください")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
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
