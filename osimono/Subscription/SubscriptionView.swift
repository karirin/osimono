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
    
    let primaryColor = Color(.systemPink)
    let accentColor = Color(.systemPurple)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(primaryColor)
                        
                        Text("推しアプリ プレミアム")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("広告なしで推し活をもっと楽しく")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // 特典一覧
                    VStack(alignment: .leading, spacing: 16) {
                        Text("プレミアム特典")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        FeatureRow(icon: "xmark.circle.fill", title: "広告非表示", description: "すべての広告が表示されません")
                        FeatureRow(icon: "sparkles", title: "限定機能", description: "プレミアム限定の特別な機能が使用可能")
                        FeatureRow(icon: "icloud.fill", title: "無制限バックアップ", description: "推しのデータを無制限でクラウド保存")
                        FeatureRow(icon: "heart.fill", title: "優先サポート", description: "お問い合わせに優先的に対応")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10)
                    )
                    
                    // 料金プラン
                    VStack(spacing: 16) {
                        Text("料金プラン")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if subscriptionManager.isLoading {
                            VStack(spacing: 12) {
                                ProgressView("プランを読み込み中...")
                                    .frame(height: 60)
                                
                                Button("デバッグ情報を出力") {
                                    subscriptionManager.printDebugInfo()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        } else if let errorMessage = subscriptionManager.errorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)
                                
                                Text("商品の読み込みに失敗しました")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("再試行") {
                                    Task {
                                        await subscriptionManager.requestProducts()
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(primaryColor)
                                .cornerRadius(20)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                                    )
                            )
                        } else if subscriptionManager.subscriptionProducts.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "cart.badge.questionmark")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("利用可能なプランがありません")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text("App Store Connectでサブスクリプション商品が正しく設定されているか確認してください")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 8) {
                                    Button("再読み込み") {
                                        Task {
                                            await subscriptionManager.requestProducts()
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(primaryColor)
                                    .cornerRadius(20)
                                    
                                    Button("デバッグ情報") {
                                        subscriptionManager.printDebugInfo()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding()
                        } else {
                            ForEach(subscriptionManager.subscriptionProducts, id: \.id) { product in
                                PlanCard(
                                    product: product,
                                    subscriptionManager: subscriptionManager,
                                    isSelected: selectedProduct?.id == product.id,
                                    onSelect: { selectedProduct = product }
                                )
                            }
                        }
                    }
                    
                    // 購入ボタン
                    if let product = selectedProduct {
                        Button(action: {
                            purchaseSubscription(product)
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text("購読を開始")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(primaryColor)
                            .cornerRadius(25)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal)
                    }
                    
                    // 購入復元・利用規約など
                    VStack(spacing: 12) {
                        Button("購入を復元") {
                            restorePurchases()
                        }
                        .foregroundColor(accentColor)
                        
                        HStack(spacing: 20) {
                            Button("利用規約") {
                                // 利用規約を表示
                            }
                            .foregroundColor(.secondary)
                            
                            Button("プライバシーポリシー") {
                                // プライバシーポリシーを表示
                            }
                            .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        
                        Text("購読は自動更新されます。解約はApp Storeの設定から行えます。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
                .foregroundColor(primaryColor),
                trailing: Button("🐛") {
                    subscriptionManager.printDebugInfo()
                }
                .foregroundColor(.blue)
            )
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            // 最初のプロダクトを選択
            if let firstProduct = subscriptionManager.subscriptionProducts.first {
                selectedProduct = firstProduct
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
                    // 購入成功
                    generateHapticFeedback()
                } else {
                    // ユーザーがキャンセル
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PlanCard: View {
    let product: Product
    let subscriptionManager: SubscriptionManager
    let isSelected: Bool
    let onSelect: () -> Void
    
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscriptionManager.getPlanType(for: product))
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(subscriptionManager.getDisplayPrice(for: product))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(primaryColor)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(primaryColor)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
                
                if product.id.contains("yearly") {
                    HStack {
                        Text("お得")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(8)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? primaryColor : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? primaryColor.opacity(0.1) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionPreView()
}
