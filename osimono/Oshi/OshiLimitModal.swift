//
//  OshiLimitModal.swift
//  osimono
//
//  推しの登録数制限に達した際に表示するモーダル
//

import SwiftUI

struct OshiLimitModal: View {
    @Binding var isPresented: Bool
    let currentOshiCount: Int
    let onUpgrade: () -> Void
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 24) {
                // アイコンとタイトル
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.pink)
                    
                    Text("推しの登録数が上限に達しました")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                
                // 説明文
                VStack(spacing: 12) {
                    Text(OshiLimitManager.shared.getLimitMessage(currentOshiCount: currentOshiCount))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("プレミアムプランなら無制限で推しを登録できます！")
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                
                // プレミアム特典
                VStack(alignment: .leading, spacing: 8) {
                    Text("プレミアム特典")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack {
                        Image(systemName: "infinity")
                            .foregroundColor(.green)
                        Text("推しを無制限で登録")
                    }
                    
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.green)
                        Text("すべての広告が非表示")
                    }
                    
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.green)
                        Text("無制限でAIチャット")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.green.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
                
                // ボタン群
                VStack(spacing: 12) {
                    // プレミアムプラン案内ボタン（メイン）
                    Button(action: {
                        generateHapticFeedback()
                        onUpgrade()
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                            Text("プレミアムプランで無制限登録")
                                .font(.system(size: 16, weight: .bold))
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
                        .shadow(color: .purple.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    
                    // 閉じるボタン
                    Button(action: { isPresented = false }) {
                        Text("後で")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
            .padding(15)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 10)
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    OshiLimitModal(
        isPresented: .constant(true),
        currentOshiCount: 5,
        onUpgrade: {}
    )
}
