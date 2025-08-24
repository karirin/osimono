//
//  MessageLimitModal.swift
//  osimono
//
//  Created by Apple on 2025/05/24.
//

import SwiftUI

struct MessageLimitModal: View {
    @Binding var isPresented: Bool
    let onWatchAd: () -> Void
    let onUpgrade: () -> Void // サブスクリプション画面への遷移
    let remainingMessages: Int
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.pink)
                
                Text(NSLocalizedString("daily_limit_reached_title", comment: "Daily conversation limit reached"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 10) {
                    Text(NSLocalizedString("free_plan_limit_description", comment: "Free plan allows up to 10 conversations per day"))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text(NSLocalizedString("premium_unlimited_description", comment: "Premium plan allows unlimited conversations!"))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    // プレミアムプラン案内ボタン（メイン）
                    Button(action: {
                        generateHapticFeedback()
                        onUpgrade()
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("premium_plan_upgrade", comment: "Upgrade to Premium"))
                                    .font(.system(size: 16, weight: .medium))
                                Text(NSLocalizedString("unlimited_chat", comment: "Unlimited Chat"))
                                    .font(.system(size: 18, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    
                    // 広告視聴ボタン（サブ）
                    Button(action: {
                        generateHapticFeedback()
                        onWatchAd()
                    }) {
                        HStack {
                            Image(systemName: "play.circle")
                                .font(.system(size: 20))
                            Text(NSLocalizedString("watch_ad_for_messages", comment: "Watch video to add 10 messages"))
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.blue, lineWidth: 1)
                                .background(Color.white)
                        )
                    }
                    
                    Button(action: { isPresented = false }) {
                        Text(NSLocalizedString("talk_again_tomorrow", comment: "Let's talk again tomorrow"))
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .padding(.horizontal)
            }
            .padding(30)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct MessageLimitModal_Previews: PreviewProvider {
    static var previews: some View {
        MessageLimitModal(
            isPresented: .constant(true),
            onWatchAd: {},
            onUpgrade: {},
            remainingMessages: 1
        )
    }
}
