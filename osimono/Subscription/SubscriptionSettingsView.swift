//
//  SubscriptionSettingsView.swift
//  osimono
//
//  Created by Apple on 2025/07/12.
//

import SwiftUI

struct SubscriptionSettingsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var showSubscriptionView = false
    @State private var expirationDate: Date?
    
    let primaryColor = Color(.systemPink)
    let accentColor = Color(.systemPurple)
    
    var body: some View {
        VStack(spacing: 20) {
            if subscriptionManager.isSubscribed {
                // サブスクリプション中の表示
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(primaryColor)
                        
                        VStack(alignment: .leading) {
                            Text("プレミアム会員")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("すべての機能をご利用いただけます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("有効")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(primaryColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryColor, lineWidth: 1)
                            )
                    )
                    
                    if let date = expirationDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("次回更新日")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(formatDate(date))
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    Button(action: {
                        openAppStoreSettings()
                    }) {
                        Text("サブスクリプションの管理")
                            .font(.subheadline)
                            .foregroundColor(accentColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(accentColor, lineWidth: 1)
                            )
                    }
                }
            } else {
                // 未加入の表示
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Image(systemName: "crown")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("プレミアムプランで\nもっと推し活を楽しもう")
                            .font(.headline)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("• 広告非表示\n• 限定機能の利用\n• 無制限バックアップ")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    
                    Button(action: {
                        showSubscriptionView = true
                    }) {
                        Text("プレミアムプランを見る")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(primaryColor)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding()
        .onAppear {
            Task {
                expirationDate = await subscriptionManager.getExpirationDate()
            }
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionPreView()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private func openAppStoreSettings() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SubscriptionSettingsView()
}

