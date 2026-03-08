//
//  AnimatedRewardCompletedModal.swift
//  osimono
//
//  Created by Apple on 2025/05/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct AnimatedRewardCompletedModal: View {
    @Binding var isPresented: Bool
    let rewardAmount: Int
    
    // Animation states
    @State private var showBackground = false
    @State private var showCard = false
    @State private var showIcon = false
    @State private var showRings = false
    @State private var showText = false
    @State private var showButton = false
    @State private var pulseAnimation = false
    @State private var confettiTrigger = false
    @State private var sparkleRotation: Double = 0
    
    // Theme colors - Luxurious gradient palette
    private let accentGradient = LinearGradient(
        colors: [
            Color(hex: "FF6B9D"),
            Color(hex: "C44569"),
            Color(hex: "8B2F5F")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let goldGradient = LinearGradient(
        colors: [
            Color(hex: "FFD700"),
            Color(hex: "FFA500"),
            Color(hex: "FF8C00")
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let cardBackground = LinearGradient(
        colors: [
            Color(hex: "1A1A2E"),
            Color(hex: "16213E")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ZStack {
            // Animated background overlay
            backgroundOverlay
            
            // Floating particles
            if showBackground {
                FloatingParticlesView()
                    .opacity(0.6)
            }
            
            // Main card
            mainCard
                .scaleEffect(showCard ? 1 : 0.5)
                .opacity(showCard ? 1 : 0)
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Background Overlay
    private var backgroundOverlay: some View {
        ZStack {
            Color.black.opacity(showBackground ? 0.7 : 0)
                .animation(.easeOut(duration: 0.4), value: showBackground)
            
            // Radial glow effect
            RadialGradient(
                colors: [
                    Color(hex: "FF6B9D").opacity(0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .opacity(showBackground ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.2), value: showBackground)
        }
        .ignoresSafeArea()
        .onTapGesture {
            dismissWithAnimation()
        }
    }
    
    // MARK: - Main Card
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Top decorative element
            topDecoration
            
            // Icon section with rings
            iconSection
                .padding(.top, 24)
            
            // Text content
            textContent
                .padding(.top, 20)
            
            // Action button
            actionButton
                .padding(.top, 28)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(cardBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color(hex: "FF6B9D").opacity(0.3), radius: 40, x: 0, y: 20)
        .padding(.horizontal, 32)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCard)
    }
    
    // MARK: - Card Background
    private var cardBackgroundView: some View {
        ZStack {
            // Base gradient
            cardBackground
            
            // Mesh gradient overlay
            GeometryReader { geo in
                ZStack {
                    // Top-left glow
                    Circle()
                        .fill(Color(hex: "FF6B9D").opacity(0.15))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: -50, y: -50)
                    
                    // Bottom-right glow
                    Circle()
                        .fill(Color(hex: "8B2F5F").opacity(0.2))
                        .frame(width: 180, height: 180)
                        .blur(radius: 50)
                        .offset(x: geo.size.width - 80, y: geo.size.height - 80)
                }
            }
            
            // Noise texture overlay
            Rectangle()
                .fill(.white.opacity(0.02))
                .background(
                    Canvas { context, size in
                        for _ in 0..<100 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            context.fill(
                                Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                                with: .color(.white.opacity(0.1))
                            )
                        }
                    }
                )
        }
    }
    
    // MARK: - Top Decoration
    private var topDecoration: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(goldGradient)
                    .frame(width: 6, height: 6)
                    .opacity(showCard ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: showCard)
            }
        }
    }
    
    private var iconSection: some View {
        ZStack {
            iconRings
            iconSparkles
            iconMain
        }
    }
    
    private var iconRings: some View {
        ForEach(0..<3, id: \.self) { index in
            RingView(
                index: index,
                showRings: showRings,
                sparkleRotation: sparkleRotation
            )
        }
    }
    
    // 追加
    private var iconSparkles: some View {
        ForEach(0..<8, id: \.self) { index in
            SparkleView()
                .offset(sparkleOffset(for: index))
                .opacity(showRings ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.3 + Double(index) * 0.05), value: showRings)
        }
    }

    // 追加
    private func sparkleOffset(for index: Int) -> CGSize {
        let angle = CGFloat(index) * .pi / 4 + sparkleRotation / 30
        return CGSize(
            width: cos(angle) * 70,
            height: sin(angle) * 70
        )
    }

    // 追加
    private var iconMain: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD700"), Color(hex: "FF8C00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: Color(hex: "FFD700").opacity(0.5), radius: 20, x: 0, y: 8)
                .scaleEffect(showIcon ? (pulseAnimation ? 1.05 : 1.0) : 0.1)
                .opacity(showIcon ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.5), value: showIcon)

            Image(systemName: "gift.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Color(hex: "FFF8DC")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .scaleEffect(showIcon ? (pulseAnimation ? 1.1 : 1.0) : 0.1)
                .opacity(showIcon ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.4).delay(0.1), value: showIcon)
        }
    }
    
    // 追加
    private struct RingView: View {
        let index: Int
        let showRings: Bool
        let sparkleRotation: Double

        var body: some View {
            Circle()
                .stroke(ringStroke, lineWidth: ringLineWidth)
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(showRings ? 1 : 0.5)
                .opacity(showRings ? ringOpacity : 0)
                .rotationEffect(.degrees(ringRotation))
                .animation(
                    .spring(response: 0.8, dampingFraction: 0.6)
                        .delay(Double(index) * 0.1),
                    value: showRings
                )
        }

        private var ringStroke: LinearGradient {
            LinearGradient(
                colors: [
                    Color(hex: "FFD700").opacity(0.6 - Double(index) * 0.15),
                    Color(hex: "FF6B9D").opacity(0.4 - Double(index) * 0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private var ringLineWidth: CGFloat { 2 - CGFloat(index) * 0.5 }
        private var ringSize: CGFloat { 130 + CGFloat(index) * 20 }
        private var ringOpacity: Double { 1 - Double(index) * 0.25 }
        private var ringRotation: Double { sparkleRotation * (index.isMultiple(of: 2) ? 1 : -1) }
    }
    
    // MARK: - Text Content
    private var textContent: some View {
        VStack(spacing: 16) {
            // Title with gradient
            Text(L10n.rewardObtained)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(goldGradient)
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showText)
            
            // Subtitle
            VStack(spacing: 6) {
                Text(L10n.thankYouForWatching)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text(L10n.toTheEnd)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 15)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showText)
            
            // Reward amount badge
            HStack(spacing: 8) {
                Image(systemName: "message.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(goldGradient)
                
                Text("+\(rewardAmount)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(goldGradient)
                
                Text(L10n.messagesAddedFormat(rewardAmount).replacingOccurrences(of: "\(rewardAmount)", with: "").trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(goldGradient, lineWidth: 1.5)
                    )
            )
            .opacity(showText ? 1 : 0)
            .scaleEffect(showText ? 1 : 0.8)
            .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.2), value: showText)
        }
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            generateHapticFeedback()
            dismissWithAnimation()
        }) {
            Text(L10n.ok)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1A1A2E"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        goldGradient
                        
                        // Shimmer effect
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.3),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: pulseAnimation ? 200 : -200)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButton)
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        // Background
        withAnimation { showBackground = true }
        
        // Card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showCard = true
        }
        
        // Icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showIcon = true
        }
        
        // Rings
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showRings = true
            startSparkleAnimation()
        }
        
        // Text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showText = true
        }
        
        // Button
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            showButton = true
            startPulseAnimation()
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
    
    private func startSparkleAnimation() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            sparkleRotation = 360
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.2)) {
            showButton = false
            showText = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.2)) {
                showIcon = false
                showRings = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeIn(duration: 0.2)) {
                showCard = false
                showBackground = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
}

// MARK: - Sparkle View
struct SparkleView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 12))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .scaleEffect(isAnimating ? 1.2 : 0.8)
            .opacity(isAnimating ? 1 : 0.6)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Floating Particles View
struct FloatingParticlesView: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<20, id: \.self) { index in
                FloatingParticle()
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
            }
        }
    }
}

struct FloatingParticle: View {
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    private let size = CGFloat.random(in: 4...8)
    private let duration = Double.random(in: 3...6)
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "FFD700").opacity(0.6), Color(hex: "FF6B9D").opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    offset = CGFloat.random(in: -30...30)
                }
                withAnimation(.easeInOut(duration: duration / 2).repeatForever(autoreverses: true)) {
                    opacity = Double.random(in: 0.3...0.8)
                }
            }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    AnimatedRewardCompletedModal(isPresented: .constant(true), rewardAmount: 10)
}
