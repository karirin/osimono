//
//  MessageLimitModal.swift
//  osimono
//
//  Created by Apple on 2025/05/24.
//

import SwiftUI

struct MessageLimitModal: View {
    @Binding var isPresented: Bool
    let onWatchAd: () -> Void
    let onUpgrade: () -> Void
    let remainingMessages: Int
    /// 指定すると「◯◯ともっと話そう」のように推しの名前入りのタイトルにする
    var oshiName: String? = nil
    /// リワード広告の控えめなリンクを出すか
    var canWatchAd: Bool = false
    /// リワード広告の読み込み中
    var isAdLoading: Bool = false
    /// 広告視聴でぼかし返信も解除される場合
    var unlocksReply: Bool = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    // Animation states
    @State private var showBackground = false
    @State private var showCard = false
    @State private var showIcon = false
    @State private var showContent = false
    @State private var showButtons = false
    @State private var floatAnimation = false
    @State private var glowAnimation = false
    
    // Theme colors - Deep purple luxury palette
    private let premiumGradient = LinearGradient(
        colors: [
            Color(hex: "9D4EDD"),
            Color(hex: "7B2CBF"),
            Color(hex: "5A189A")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let goldAccent = LinearGradient(
        colors: [
            Color(hex: "FFD700"),
            Color(hex: "FFC300"),
            Color(hex: "FFB700")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let cardBackground = LinearGradient(
        colors: [
            Color(hex: "0D0D1A"),
            Color(hex: "1A1A2E"),
            Color(hex: "0F0F23")
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Floating orbs
            if showBackground {
                floatingOrbsView
            }
            
            // Main card
            mainCard
                .scaleEffect(showCard ? 1 : 0.8)
                .opacity(showCard ? 1 : 0)
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            Color.black.opacity(showBackground ? 0.85 : 0)
            
            // Gradient mesh effect
            RadialGradient(
                colors: [
                    Color(hex: "9D4EDD").opacity(0.15),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
            .opacity(showBackground ? 1 : 0)
            
            RadialGradient(
                colors: [
                    Color(hex: "FFD700").opacity(0.08),
                    Color.clear
                ],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 300
            )
            .opacity(showBackground ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.4), value: showBackground)
        .onTapGesture {
            dismissWithAnimation()
        }
    }
    
    // MARK: - Floating Orbs
    private var floatingOrbsView: some View {
        GeometryReader { geo in
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (index % 2 == 0 ? Color(hex: "9D4EDD") : Color(hex: "FFD700")).opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .offset(
                        x: CGFloat.random(in: -geo.size.width/3...geo.size.width/3),
                        y: floatAnimation ?
                            CGFloat.random(in: -geo.size.height/3...geo.size.height/3) :
                            CGFloat.random(in: -geo.size.height/4...geo.size.height/4)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...5))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.3),
                        value: floatAnimation
                    )
            }
        }
        .opacity(0.6)
    }
    
    // MARK: - Main Card
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Icon section
            iconSection
                .padding(.top, 32)
            
            // Title and description
            contentSection
                .padding(.top, 24)
            
            // Action buttons
            buttonsSection
                .padding(.top, 28)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(cardBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "9D4EDD").opacity(0.5),
                            Color(hex: "FFD700").opacity(0.3),
                            Color(hex: "9D4EDD").opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "9D4EDD").opacity(0.3), radius: 40, x: 0, y: 20)
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCard)
    }
    
    // MARK: - Card Background
    private var cardBackgroundView: some View {
        ZStack {
            cardBackground
            
            // Subtle pattern overlay
            GeometryReader { geo in
                ZStack {
                    // Top accent glow
                    Ellipse()
                        .fill(Color(hex: "9D4EDD").opacity(0.15))
                        .frame(width: 300, height: 150)
                        .blur(radius: 60)
                        .offset(y: -100)
                    
                    // Bottom accent
                    Ellipse()
                        .fill(Color(hex: "FFD700").opacity(0.08))
                        .frame(width: 200, height: 100)
                        .blur(radius: 40)
                        .offset(y: geo.size.height - 50)
                }
            }
        }
    }
    
    // MARK: - Icon Section
    private var iconSection: some View {
        ZStack {
            // Animated glow rings
            // (ここは変更なし)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        premiumGradient.opacity(0.3 - Double(index) * 0.1),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(index) * 30, height: 120 + CGFloat(index) * 30)
                    .scaleEffect(glowAnimation ? 1.1 : 1.0)
                    .opacity(showIcon ? (glowAnimation ? 0.5 : 0.8) : 0)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: glowAnimation
                    )
            }
            
            // Main icon container
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "9D4EDD").opacity(0.3),
                                Color(hex: "5A189A").opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
              
                // Icon
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "E0AAFF"),
                                Color(hex: "C77DFF")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "9D4EDD").opacity(0.5), radius: 10, x: 0, y: 4)
            }
            .scaleEffect(showIcon ? 1 : 0.5)
            .opacity(showIcon ? 1 : 0)
            .compositingGroup() // ←【修正箇所】これを追加！
            .offset(y: floatAnimation ? -5 : 5)
            .animation(
                .easeInOut(duration: 3).repeatForever(autoreverses: true),
                value: floatAnimation
            )
        }
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 16) {
            // Title
            Text(titleText)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(hex: "E0AAFF")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            
            // Description
            VStack(spacing: 12) {
                Text(NSLocalizedString("free_plan_limit_description", comment: "Free plan allows up to 10 conversations per day"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                // Premium highlight
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(goldAccent)
                    
                    Text(NSLocalizedString("premium_unlimited_description", comment: "Premium plan allows unlimited conversations!"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(goldAccent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "FFD700").opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "FFD700").opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
    
    private var titleText: String {
        if let name = oshiName, !name.isEmpty {
            return String(format: NSLocalizedString("limit_modal_title_with_oshi", comment: "Keep talking with %@"), name)
        }
        return NSLocalizedString("daily_limit_reached_title", comment: "Daily conversation limit reached")
    }
    
    // MARK: - Buttons Section
    private var buttonsSection: some View {
        VStack(spacing: 14) {
            // Premium upgrade button (Primary)
            Button(action: {
                generateHapticFeedback()
                onUpgrade()
            }) {
                HStack(spacing: 12) {
                    // Crown icon with glow
                    ZStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(goldAccent)
                            .blur(radius: 8)
                        
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "1A1A2E"))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("premium_plan_upgrade", comment: "Upgrade to Premium"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A2E").opacity(0.7))
                        
                        Text(NSLocalizedString("unlimited_chat", comment: "Unlimited Chat"))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "1A1A2E"))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E").opacity(0.5))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        goldAccent
                        
                        // Shimmer effect
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [
                                    .clear,
                                    .white.opacity(0.4),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 60)
                            .offset(x: glowAnimation ? geo.size.width + 60 : -60)
                            .animation(
                                .linear(duration: 2.5).repeatForever(autoreverses: false),
                                value: glowAnimation
                            )
                        }
                        .mask(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // 広告はアップグレードより目立たせない、控えめなテキストリンク
            if canWatchAd {
                Button(action: {
                    onWatchAd()
                }) {
                    Text(isAdLoading
                         ? NSLocalizedString("reward_ad_loading", comment: "Loading ad...")
                         : String(
                            format: NSLocalizedString(
                                unlocksReply ? "limit_watch_ad_and_unlock_link" : "limit_watch_ad_link",
                                comment: "Watch an ad to continue chatting"
                            ),
                            PaywallConfig.shared.adRewardMessageCount
                         ))
                        .font(.system(size: 13, weight: .medium))
                        .underline(!isAdLoading)
                        .foregroundColor(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .disabled(isAdLoading)
                .padding(.top, 2)
            }
            
            // Dismiss button
            Button(action: {
                dismissWithAnimation()
            }) {
                Text(NSLocalizedString("talk_again_tomorrow", comment: "Let's talk again tomorrow"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.vertical, 12)
            }
        }
        .opacity(showButtons ? 1 : 0)
        .offset(y: showButtons ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        withAnimation { showBackground = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showCard = true
        }
        
        // 修正箇所: ここでまずはアイコンを表示だけさせる（ループアニメーションはまだ）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showIcon = true
        }
        
        // 追加箇所: 表示から少しだけ遅らせて(0.15秒後)、ふわふわ/グローのアニメーションを開始する
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            floatAnimation = true
            glowAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { // タイミングを少し後ろに調整
            showContent = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { // タイミングを少し後ろに調整
            showButtons = true
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.15)) {
            showButtons = false
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.15)) {
                showIcon = false
                showCard = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.15)) {
                showBackground = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Scale Button Style (if not already defined)
struct MessageLimitScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Color Extension (if not already defined)
extension Color {
    init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct MessageLimitModal_Previews: PreviewProvider {
    static var previews: some View {
        MessageLimitModal(
            isPresented: .constant(true),
            onWatchAd: {},
            onUpgrade: {},
            remainingMessages: 1
        )
    }
}
