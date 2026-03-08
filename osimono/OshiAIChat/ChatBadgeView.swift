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
    
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5
    
    var body: some View {
        ZStack {
            // グロー効果
            if hasNewMessages {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(glowOpacity * 0.5))
                    .frame(width: 50, height: 50)
                    .blur(radius: 8)
            }
            
            // メインボタン
            ZStack {
                Circle()
                    .fill(
                        hasNewMessages
                            ? DesignSystem.Colors.primaryGradient
                            : LinearGradient(
                                colors: [Color.white],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )
                    .frame(width: 40, height: 40)
                    .shadow(
                        color: hasNewMessages ? DesignSystem.Colors.primary.opacity(0.4) : Color.black.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                Image(systemName: hasNewMessages ? "message.fill" : "message")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(hasNewMessages ? .white : DesignSystem.Colors.primary)
            }
            .scaleEffect(scale)
            
            // バッジ
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, count > 9 ? 5 : 0)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.error)
                    )
                    .offset(x: 14, y: -14)
            }
        }
        .onAppear {
            if hasNewMessages {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                ) {
                    glowOpacity = 1.0
                }
                
                // バウンスアニメーション
                withAnimation(
                    .spring(response: 0.3, dampingFraction: 0.6)
                    .repeatCount(3, autoreverses: true)
                ) {
                    scale = 1.1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        scale = 1.0
                    }
                }
            }
        }
        .onChange(of: hasNewMessages) { newValue in
            if newValue {
                withAnimation(
                    .spring(response: 0.3, dampingFraction: 0.6)
                    .repeatCount(3, autoreverses: true)
                ) {
                    scale = 1.1
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        scale = 1.0
                    }
                }
            }
        }
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
            .frame(width: 140, height: 50)
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

// 三角形の形状を定義（吹き出しの矢印用）
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
        TopView()
    }
}
