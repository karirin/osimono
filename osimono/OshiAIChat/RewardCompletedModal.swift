//
//  RewardCompletedModal.swift
//  osimono
//
//  Created by Apple on 2025/05/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct RewardCompletedModal: View {
    @Binding var isPresented: Bool
    let rewardAmount: Int
    
    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            // モーダル本体
            VStack(spacing: 20) {
                // 成功アイコン
                Image(systemName: "gift.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isPresented)
                
                // タイトル
                Text("報酬獲得！")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // 説明文
                VStack(spacing: 8) {
                    Text("広告を最後まで視聴していただき")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("ありがとうございました！")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text("\(rewardAmount)回分のメッセージが")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("追加されました ✨")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .multilineTextAlignment(.center)
                
                // 閉じるボタン
                Button(action: {
                    // ハプティックフィードバックを生成
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    isPresented = false
                }) {
                    Text("OK")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
            .scaleEffect(isPresented ? 1.0 : 0.8)
            .opacity(isPresented ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPresented)
        }
    }
}

#Preview {
    RewardCompletedModal(isPresented: .constant(true), rewardAmount: 20)
}
