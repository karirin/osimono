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
    
    @State private var isAnimating = false
    @State private var isAnimatingFlag = true
    
    // カスタムカラー - より明確な色を使用
    let badgeColor = Color(.systemRed)
    let pulsatingColor = Color(.systemRed)
    let tooltipColor = Color(.systemIndigo)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // チャットアイコン
            ZStack{
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 30))
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
                    .overlay(
                        Group{
                            if hasNewMessages {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [badgeColor, Color.red]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 20, height: 20)
                                    .shadow(color: badgeColor.opacity(0.4), radius: 3, x: 0, y: 1)
                                    .offset(x: 15,y: -15)
                                if isAnimatingFlag {
                                    ForEach(0..<3) { index in
                                        Circle()
                                            .stroke(lineWidth: 2)
                                            .foregroundColor(Color.purple.opacity(0.8))
                                            .scaleEffect(isAnimating ? 2 + CGFloat(index) * 0.5 : 1)
                                            .opacity(isAnimating ? 0 : 0.7)
                                            .animation(
                                                Animation.easeOut(duration: 1.5)
                                                    .repeatForever(autoreverses: false)
                                                    .delay(0.3 * Double(index)),
                                                value: isAnimating
                                            )
                                    }
                                }
                            }
                        }
                )
            }
            .onAppear {
                // アニメーションを開始
                withAnimation(Animation.easeInOut(duration: 1.0)) {
                    isAnimating = true
                }
                
                // 1秒後にアニメーションを停止
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        isAnimatingFlag = false
                    }
                }
            }
            // 未読メッセージがある場合にバッジを表示
            if hasNewMessages {
                ZStack {
//                            .offset(x: -10,y: 10)
                        
                    // カウント表示を改良
//                    if count > 0 {
//                        Text("\(count > 99 ? "99+" : "\(count)")")
//                            .font(.system(size: count > 99 ? 12 : 16, weight: .bold))
//                            .foregroundColor(.white)
//                    } else {
//                        // カウントが0の場合は白い点を大きくして視認性を向上
//                        Circle()
//                            .fill(Color.white)
//                            .frame(width: 8, height: 8)
//                    }
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
                    .offset(x: 50,y: 60)
                    .zIndex(1) // 確実に前面に表示
                    
                    // 自動的に消える
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
//                                showTooltip = false
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
