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
    @State private var showTooltip: Bool = true
    
    // カスタムカラー - より明確な色を使用
    let badgeColor = Color(.systemRed)
    let pulsatingColor = Color(.systemRed)
    let tooltipColor = Color(.systemIndigo)
    
    var body: some View {
            ZStack(alignment: .topTrailing) {
                // チャットアイコン
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 34))
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
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    )
                
                // 未読メッセージがある場合にバッジを表示
                if hasNewMessages {
                    ZStack {
                        // 背景の波紋エフェクト（改良版）
                        if animateScale {
                            Circle()
                                .fill(pulsatingColor.opacity(0.6))
                                .frame(width: 30, height: 30)
                                .scaleEffect(animateScale ? 1.4 : 1.0)
                                .opacity(animateScale ? 0 : 0.6)
                        }
                        
                        // バッジの背景
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [badgeColor, Color.red]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 30, height: 30)
                            .shadow(color: badgeColor.opacity(0.4), radius: 3, x: 0, y: 1)
                            .scaleEffect(animateScale ? 1.1 : 1.0)
                        
                        // カウント表示を改良
                        if count > 0 {
                            Text("\(count > 99 ? "99+" : "\(count)")")
                                .font(.system(size: count > 99 ? 12 : 16, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            // カウントが0の場合は白い点を大きくして視認性を向上
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .offset(x: 10, y: -10) // 少し外側に配置して視認性向上
                    .onAppear {
                        // よりはっきりしたアニメーション
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            animateScale = true
                        }
                    }
                }
            }
            .overlay(
                Group {
                    // ツールチップ改良版
                    if hasNewMessages {
                        TooltipView(
                            isVisible: showTooltip,
                            text: "推しからメッセージが届いています",
                            tooltipColor: tooltipColor
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
//                        .animation(.spring(), value: showTooltip)
                        .offset(x: 50,y: 60)
                        .zIndex(1) // 確実に前面に表示
                        
                        // 自動的に消える
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showTooltip = false
                                }
                            }
                        }
                    }
                }
            )
    }
}

// ツールチップコンポーネント（改良版）
struct TooltipView: View {
    let isVisible: Bool
    let text: String
    let tooltipColor: Color
    
    var body: some View {
        if isVisible {
            HStack {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
            .frame(width: 140,height: 50)
            .background(
                ZStack {
                    // ツールチップの背景
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tooltipColor)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    // 上部の三角形（吹き出しの矢印部分）
                    TriangleBadge()
                        .fill(tooltipColor)
                        .frame(width: 16, height: 8)
                        .rotationEffect(.degrees(180))
                        .offset(y: -16)
                }
            )
        } else {
            EmptyView()
        }
    }
}

//// 三角形の形状を定義（吹き出しの矢印用）
struct TriangleBadge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// プレビュー
struct ChatBadgeView_Previews: PreviewProvider {
    static var previews: some View {
//        VStack(spacing: 20) {
//            ChatBadgeView(count: 3, hasNewMessages: true)
//            ChatBadgeView(count: 25, hasNewMessages: true)
//            ChatBadgeView(count: 0, hasNewMessages: true)
//            ChatBadgeView(count: 0, hasNewMessages: false)
//        }
//        .padding()
//        .previewLayout(.sizeThatFits)
        TopView()
    }
}
