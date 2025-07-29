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
                
                Text("本日の会話回数が上限に達しました")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 10) {
                    Text("無料プランでは1日10回まで推しと会話できます")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("プレミアムプランなら無制限で会話できます！")
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
                                Text("プレミアムプランで")
                                    .font(.system(size: 16, weight: .medium))
                                Text("無制限チャット")
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
                            Text("動画を見て10回追加")
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
                        Text("また明日話そう")
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
