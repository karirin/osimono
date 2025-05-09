//
//  ChatBadgeView.swift
//  osimono
//
//  Created by Apple on 2025/05/09.
//

import SwiftUI

struct ChatBadgeView: View {
    let count: Int
    let hasNewMessages: Bool
    @State private var animateScale: Bool = false
    
    // カスタムカラー
    let badgeColor = Color(.systemRed)
    let pulsatingColor = Color(.systemPink)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // チャットアイコン
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.pink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                )
            
            // 未読メッセージまたは未読投稿がある場合にバッジを表示
            if hasNewMessages {
                ZStack {
                    // 背景の波紋エフェクト（アニメーション用）
                    if animateScale {
                        Circle()
                            .fill(pulsatingColor.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .scaleEffect(animateScale ? 1.5 : 1.0)
                            .opacity(animateScale ? 0 : 0.5)
                    }
                    
                    // バッジの背景
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [badgeColor, Color.red.opacity(0.7)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 22, height: 22)
                        .shadow(color: badgeColor.opacity(0.3), radius: 2, x: 0, y: 1)
                        .scaleEffect(animateScale ? 1.1 : 1.0)
                    
                    // カウント表示
                    if count > 0 {
                        Text("\(count > 99 ? "99+" : "\(count)")")
                            .font(.system(size: count > 99 ? 8 : 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        // カウントが0の場合は単に丸いインジケータを表示
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                    }
                }
                .offset(x: 6, y: -6)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        animateScale = true
                    }
                }
            }
        }
    }
}

// プレビュー
struct ChatBadgeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ChatBadgeView(count: 3, hasNewMessages: true)
            ChatBadgeView(count: 25, hasNewMessages: true)
            ChatBadgeView(count: 0, hasNewMessages: true)
            ChatBadgeView(count: 0, hasNewMessages: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
