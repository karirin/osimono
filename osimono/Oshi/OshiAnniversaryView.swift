//
//  OshiAnniversaryView.swift
//  osimono
//
//  Created by Apple on 2025/04/29.
//

import SwiftUI
import Shimmer
import Confetti

struct OshiAnniversaryView: View {
    @Binding var isShowing: Bool
    let days: Int
    let oshiName: String
    let imageUrl: String?
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var confettiOpacity: Double = 0
    @State private var confettiOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // 紙吹雪エフェクト
            confettiView
            
            // メインカード
            VStack(spacing: DesignSystem.Spacing.lg) {
                // アバター
                if let imageUrlString = imageUrl, let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    DesignSystem.Colors.primary,
                                                    DesignSystem.Colors.secondary
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 4
                                        )
                                )
                                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        default:
                            avatarPlaceholder
                        }
                    }
                } else {
                    avatarPlaceholder
                }
                
                // タイトル
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("🎉")
                        .font(.system(size: 40))
                    
                    Text(L10n.congratulations)
                        .font(DesignSystem.Typography.displaySmall())
                        .foregroundStyle(DesignSystem.Colors.primaryGradient)
                    
                    Text(L10n.daysWithOshi(days))
                        .font(DesignSystem.Typography.headlineMedium())
                        .foregroundColor(.white)
                }
                
                // メッセージ
                Text(L10n.anniversaryMessage(days))
                    .font(DesignSystem.Typography.bodyMedium())
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // ボタン
                Button(action: {
                    generateHapticFeedback()
                    dismiss()
                }) {
                    Text(L10n.close)
                }
                .primaryButton()
                .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.bouncy) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                confettiOpacity = 1.0
                confettiOffset = 200
            }
        }
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primary.opacity(0.5),
                        DesignSystem.Colors.secondary.opacity(0.5)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 100, height: 100)
            .overlay(
                Text(String(oshiName.prefix(1)))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
    
    private var confettiView: some View {
        GeometryReader { geometry in
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(confettiColors[index % confettiColors.count])
                    .frame(width: CGFloat.random(in: 8...16), height: CGFloat.random(in: 8...16))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: -20 + confettiOffset
                    )
                    .opacity(confettiOpacity)
            }
        }
    }
    
    private let confettiColors: [Color] = [
        DesignSystem.Colors.primary,
        DesignSystem.Colors.secondary,
        DesignSystem.Colors.tertiary,
        DesignSystem.Colors.success,
        DesignSystem.Colors.warning
    ]
    
    private func dismiss() {
        withAnimation(DesignSystem.Animation.quick) {
            scale = 0.5
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowing = false
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// 2. 日付計算ユーティリティ
extension Date {
    static func daysBetween(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 0
    }
}

#Preview {
    OshiAnniversaryView(isShowing: .constant(false), days: 10, oshiName: "アイドル〇〇ちゃん", imageUrl: "")
}
