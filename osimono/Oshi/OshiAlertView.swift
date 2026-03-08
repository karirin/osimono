//
//  AlertViews.swift
//  osimono
//
//   Alert Views - 2025 Update
//

import SwiftUI

// MARK: -  Oshi Alert View

struct OshiAlertView: View {
    let title: String
    let message: String
    let buttonText: String
    let action: () -> Void
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // アラートカード
            VStack(spacing: DesignSystem.Spacing.lg) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primary.opacity(0.2),
                                    DesignSystem.Colors.secondary.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DesignSystem.Colors.primaryGradient)
                }
                
                // テキスト
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.headlineLarge())
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // ボタン
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // キャンセルボタン
                    Button(action: dismiss) {
                        Text(L10n.cancel)
                            .font(DesignSystem.Typography.labelLarge())
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                    .fill(DesignSystem.Colors.surfaceSecondary)
                            )
                    }
                    
                    // アクションボタン
                    Button(action: {
                        action()
                        dismiss()
                    }) {
                        Text(buttonText)
                    }
                    .primaryButton()
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(DesignSystem.Colors.surface)
            )
            .applyShadow(DesignSystem.Shadows.large)
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.bouncy) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func dismiss() {
        withAnimation(DesignSystem.Animation.quick) {
            scale = 0.8
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowing = false
        }
    }
}

// MARK: -  Apology Modal View

struct ApologyModalView: View {
    @Binding var isPresented: Bool
    
    private let apologyShownKey = "ai_message_apology_shown_v1"
    
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // モーダルカード
            VStack(spacing: DesignSystem.Spacing.lg) {
                // アイコン
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.warning.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DesignSystem.Colors.warning)
                }
                
                // タイトル
                Text(L10n.apologyTitle)
                    .font(DesignSystem.Typography.headlineLarge())
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                // メッセージ
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text(L10n.apologyMessage1)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(L10n.apologyMessage2)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(L10n.apologyMessage3)
                        .font(DesignSystem.Typography.bodyMedium())
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(L10n.apologyMessage4)
                        .font(DesignSystem.Typography.bodyMedium())
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(.top, DesignSystem.Spacing.xs)
                    
                    Text(L10n.apologyMessage5)
                        .font(DesignSystem.Typography.labelSmall())
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .padding(.top, DesignSystem.Spacing.xxs)
                }
                .multilineTextAlignment(.center)
                
                // ボタン
                Button(action: {
                    generateHapticFeedback()
                    UserDefaults.standard.set(true, forKey: apologyShownKey)
                    dismiss()
                }) {
                    Text(L10n.confirm)
                }
                .primaryButton()
                .padding(.top, DesignSystem.Spacing.xs)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .fill(DesignSystem.Colors.surface)
            )
            .applyShadow(DesignSystem.Shadows.large)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.bouncy) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func dismiss() {
        withAnimation(DesignSystem.Animation.quick) {
            scale = 0.8
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    static func shouldShowApology() -> Bool {
        let apologyShownKey = "ai_message_apology_shown_v1"
        return !UserDefaults.standard.bool(forKey: apologyShownKey)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3).ignoresSafeArea()
        
        VStack(spacing: 30) {
            ChatBadgeView(count: 5, hasNewMessages: true)
            
            Button("Show Alert") {}
        }
    }
}
