//
//  FirstOshiCongratsView.swift
//  osimono
//
//  Created by Apple on 2025/05/03.
//

import SwiftUI

struct FirstOshiCongratsView: View {
    @Binding var isShowing: Bool
    let imageUrl: String?
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var sparkleRotation: Double = 0
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // スパークルエフェクト
            ForEach(0..<6) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.warning)
                    .offset(
                        x: CGFloat(cos(Double(index) * .pi / 3 + sparkleRotation)) * 120,
                        y: CGFloat(sin(Double(index) * .pi / 3 + sparkleRotation)) * 120
                    )
                    .opacity(0.8)
            }
            
            // メインカード
            VStack(spacing: DesignSystem.Spacing.lg) {
                // アバター
                ZStack {
                    // グロー
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.5),
                                    DesignSystem.Colors.primary.opacity(0)
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                    
                    if let imageUrlString = imageUrl, let url = URL(string: imageUrlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 4)
                                    )
                            default:
                                defaultAvatar
                            }
                        }
                    } else {
                        defaultAvatar
                    }
                }
                
                // テキスト
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("🎊")
                        .font(.system(size: 50))
                    
                    Text("おめでとうございます！")
                        .font(DesignSystem.Typography.displaySmall())
                        .foregroundStyle(DesignSystem.Colors.primaryGradient)
                    
                    Text("最初の推しを登録しました")
                        .font(DesignSystem.Typography.headlineSmall())
                        .foregroundColor(.white)
                    
                    Text("これからの推し活を\n楽しみましょう！")
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // ボタン
                Button(action: {
                    generateHapticFeedback()
                    dismiss()
                }) {
                    Text("始める")
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
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
            
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                sparkleRotation = .pi * 2
            }
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primary,
                        DesignSystem.Colors.secondary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay(
                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 4)
            )
    }
    
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

// 改良版ステップ表示用の補助ビュー
struct ImprovedStepView: View {
    var icon: String
    var title: String
    var description: String
    var primaryColor: Color
    var secondaryColor: Color
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // 各機能へ移動する処理
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            isHovered.toggle()
        }) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryColor.opacity(0.2), secondaryColor.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(primaryColor)
                }
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isHovered)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(primaryColor.opacity(0.5))
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// プレビュー
struct FirstOshiCongratsView_Previews: PreviewProvider {
    static var previews: some View {
        FirstOshiCongratsView(isShowing: .constant(false), imageUrl: "")
    }
}
