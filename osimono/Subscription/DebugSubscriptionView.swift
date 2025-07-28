//
//  DebugSubscriptionView.swift
//  osimono
//
//  Created by Apple on 2025/07/26.
//

import SwiftUI
import StoreKit

struct DebugSubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 現在の状態表示
                    VStack(alignment: .leading, spacing: 12) {
                        Text("現在の状態")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("サブスクリプション:")
                            Spacer()
                            Text(subscriptionManager.isSubscribed ? "有効" : "無効")
                                .foregroundColor(subscriptionManager.isSubscribed ? .green : .red)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("デバッグモード:")
                            Spacer()
                            Text(subscriptionManager.debugSubscriptionEnabled ? "ON" : "OFF")
                                .foregroundColor(subscriptionManager.debugSubscriptionEnabled ? .orange : .gray)
                                .fontWeight(.bold)
                        }
                        
                        if let current = subscriptionManager.currentSubscription {
                            HStack {
                                Text("現在のプラン:")
                                Spacer()
                                Text(subscriptionManager.getPlanType(for: current))
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // デバッグ用コントロール
                    VStack(alignment: .leading, spacing: 12) {
                        Text("デバッグ用コントロール")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Button(action: {
                            subscriptionManager.toggleDebugSubscription()
                            generateHapticFeedback()
                        }) {
                            HStack {
                                Image(systemName: subscriptionManager.debugSubscriptionEnabled ? "stop.circle.fill" : "play.circle.fill")
                                Text(subscriptionManager.debugSubscriptionEnabled ? "デバッグモード OFF" : "デバッグモード ON")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(subscriptionManager.debugSubscriptionEnabled ? Color.orange : Color.blue)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            Task {
                                await subscriptionManager.updateSubscriptionStatus()
                                generateHapticFeedback()
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("状態を更新")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            subscriptionManager.printDebugInfo()
                            alertMessage = "デバッグ情報をコンソールに出力しました"
                            showAlert = true
                            generateHapticFeedback()
                        }) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("デバッグ情報を出力")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // 商品一覧
                    VStack(alignment: .leading, spacing: 12) {
                        Text("利用可能な商品")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if subscriptionManager.subscriptionProducts.isEmpty {
                            Text("商品が読み込まれていません")
                                .foregroundColor(.gray)
                                .italic()
                        } else {
                            ForEach(subscriptionManager.subscriptionProducts, id: \.id) { product in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(subscriptionManager.getPlanType(for: product))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(product.id)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(subscriptionManager.getDisplayPrice(for: product))
                                        .fontWeight(.bold)
                                    
                                    Button("購入") {
                                        purchaseProduct(product)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(subscriptionManager.isLoading)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3))
                                )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                    
                    // 購入復元
                    Button(action: {
                        Task {
                            await subscriptionManager.restorePurchases()
                            alertMessage = "購入復元が完了しました"
                            showAlert = true
                            generateHapticFeedback()
                        }
                    }) {
                        Text("購入を復元")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .disabled(subscriptionManager.isLoading)
                    
                    // テスト用の広告表示確認
                    VStack(alignment: .leading, spacing: 12) {
                        Text("広告表示テスト")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text(subscriptionManager.isSubscribed ? "広告は非表示になります" : "広告が表示されます")
                            .foregroundColor(subscriptionManager.isSubscribed ? .green : .red)
                            .fontWeight(.medium)
                        
                        // 模擬広告
                        Rectangle()
                            .fill(subscriptionManager.isSubscribed ? Color.green.opacity(0.3) : Color.red.opacity(0.3))
                            .frame(height: 60)
                            .overlay(
                                Text(subscriptionManager.isSubscribed ? "広告非表示" : "広告エリア")
                                    .fontWeight(.bold)
                                    .foregroundColor(subscriptionManager.isSubscribed ? .green : .red)
                            )
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding()
            }
            .navigationTitle("サブスクリプションテスト")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("通知"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            Task {
                await subscriptionManager.requestProducts()
            }
        }
    }
    
    private func purchaseProduct(_ product: Product) {
        Task {
            do {
                let transaction = try await subscriptionManager.purchase(product)
                if transaction != nil {
                    alertMessage = "購入が完了しました！"
                } else {
                    alertMessage = "購入がキャンセルされました"
                }
                showAlert = true
                generateHapticFeedback()
            } catch {
                alertMessage = "購入に失敗しました: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    DebugSubscriptionView()
}
