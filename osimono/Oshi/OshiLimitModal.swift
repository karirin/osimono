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
    
    // 管理者の場合は特別な表示
    private var isAdminUser: Bool {
        OshiLimitManager.shared.isCurrentUserAdmin()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            if isAdminUser {
                // 管理者用の特別表示（実際には表示されないはずだが、念のため）
                adminView
            } else {
                // 一般ユーザー用の制限表示
                standardView
            }
        }
    }
    
    // 一般ユーザー用のビュー
    private var standardView: some View {
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
                    .multilineTextAlignment(.center)
                
                Text("プレミアムプランなら無制限で推しを登録できます！")
                    .font(.body)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            
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
    
    // 管理者用のビュー（デバッグ情報として）
    private var adminView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.yellow)
                
                Text("管理者権限")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Text("管理者権限により無制限で推しを登録できます")
                    .font(.body)
                    .multilineTextAlignment(.center)
                
                Text("現在 \(currentOshiCount) 人の推しが登録されています")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                // デバッグ情報
                Text("権限状態: \(OshiLimitManager.shared.getUserPermissionStatus())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            
            // 閉じるボタン
            Button(action: { isPresented = false }) {
                Text("閉じる")
                    .foregroundColor(.blue)
                    .font(.headline)
                    .padding()
            }
        }
        .padding(15)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 20)
        .padding(.horizontal, 10)
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
