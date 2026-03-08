//
//  RewardCompletedModal.swift
//  osimono
//
//  Created by Apple on 2025/05/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct RewardCompletedModal: View {
    @Binding var isPresented: Bool
    let rewardAmount: Int
    
    // Animation states
    @State private var showBackground = false
    @State private var showCard = false
    @State private var showIcon = false
    @State private var showContent = false
    @State private var showButton = false
    @State private var celebrationActive = false
    @State private var pulseAnimation = false
    
    // Theme colors - Celebration palette
    private let successGradient = LinearGradient(
        colors: [
            Color(hex: "00D9A5"),
            Color(hex: "00B386"),
            Color(hex: "00996B")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private let goldAccent = LinearGradient(
        colors: [
            Color(hex: "FFD700"),
            Color(hex: "FFAA00")
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    private let cardBackground = LinearGradient(
        colors: [
            Color(hex: "0A1628"),
            Color(hex: "132238"),
            Color(hex: "0D1B2A")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Celebration particles
            if celebrationActive {
                CelebrationParticlesView()
            }
            
            // Main card
            mainCard
                .scaleEffect(showCard ? 1 : 0.7)
                .opacity(showCard ? 1 : 0)
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            Color.black.opacity(showBackground ? 0.8 : 0)
            
            // Success glow
            RadialGradient(
                colors: [
                    Color(hex: "00D9A5").opacity(0.2),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 350
            )
            .opacity(showBackground ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.4), value: showBackground)
        .onTapGesture {
            dismissWithAnimation()
        }
    }
    
    // MARK: - Main Card
    private var mainCard: some View {
        VStack(spacing: 0) {
            // Success icon
            iconSection
                .padding(.top, 36)
            
            // Content
            contentSection
                .padding(.top, 24)
            
            // Button
            actionButton
                .padding(.top, 32)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .background(cardBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "00D9A5").opacity(0.5),
                            Color(hex: "00D9A5").opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color(hex: "00D9A5").opacity(0.25), radius: 40, x: 0, y: 20)
        .padding(.horizontal, 28)
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showCard)
    }
    
    // MARK: - Card Background
    private var cardBackgroundView: some View {
        ZStack {
            cardBackground
            
            // Ambient glow effects
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color(hex: "00D9A5").opacity(0.1))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width/4, y: -50)
                    
                    Circle()
                        .fill(Color(hex: "FFD700").opacity(0.08))
                        .frame(width: 150, height: 150)
                        .blur(radius: 50)
                        .offset(x: geo.size.width/3, y: geo.size.height - 100)
                }
            }
        }
    }
    
    // MARK: - Icon Section
    private var iconSection: some View {
        ZStack {
            // Animated success rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        successGradient.opacity(0.4 - Double(index) * 0.1),
                        lineWidth: 3 - CGFloat(index)
                    )
                    .frame(
                        width: 120 + CGFloat(index) * 25,
                        height: 120 + CGFloat(index) * 25
                    )
                    .scaleEffect(showIcon ? (pulseAnimation ? 1.05 : 1.0) : 0.5)
                    .opacity(showIcon ? 1 : 0)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: pulseAnimation
                    )
            }
            
            // Sparkles
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundStyle(goldAccent)
                    .offset(
                        x: cos(CGFloat(index) * .pi / 3) * 75,
                        y: sin(CGFloat(index) * .pi / 3) * 75
                    )
                    .scaleEffect(celebrationActive ? 1.2 : 0.8)
                    .opacity(showIcon ? (celebrationActive ? 1 : 0.6) : 0)
                    .animation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: celebrationActive
                    )
            }
            
            // Main icon container
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "00D9A5").opacity(0.4),
                                Color(hex: "00D9A5").opacity(0.1)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                    .blur(radius: 5)
                
                // Solid circle
                Circle()
                    .fill(successGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: Color(hex: "00D9A5").opacity(0.5), radius: 20, x: 0, y: 8)
                
                // Gift icon
                Image(systemName: "gift.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(hex: "E0FFF5")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .scaleEffect(showIcon ? (pulseAnimation ? 1.02 : 1.0) : 0.3)
            .opacity(showIcon ? 1 : 0)
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.6), value: showIcon)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 20) {
            // Success title
            Text(NSLocalizedString("reward_obtained", comment: "Reward Obtained!"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(successGradient)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            
            // Thank you message
            VStack(spacing: 8) {
                Text(NSLocalizedString("thank_you_for_watching", comment: "Thank you for watching the ad"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Text(NSLocalizedString("to_the_end", comment: "to the end!"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .multilineTextAlignment(.center)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 15)
            
            // Reward badge
            HStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(successGradient)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(rewardAmount)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(hex: "B0FFE0")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text(NSLocalizedString("have_been_added", comment: "have been added ✨"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "00D9A5").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(successGradient.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.9)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: showContent)
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismissWithAnimation()
        }) {
            Text(NSLocalizedString("ok", comment: "OK"))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "0A1628"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        successGradient
                        
                        // Shimmer
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.35), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 80)
                            .offset(x: pulseAnimation ? geo.size.width + 80 : -80)
                            .animation(
                                .linear(duration: 2).repeatForever(autoreverses: false),
                                value: pulseAnimation
                            )
                        }
                        .mask(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color(hex: "00D9A5").opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(RewardScaleButtonStyle())
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButton)
    }
    
    // MARK: - Animation Sequence
    private func startAnimationSequence() {
        withAnimation { showBackground = true }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showCard = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showIcon = true
            celebrationActive = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pulseAnimation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showContent = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            showButton = true
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: 0.15)) {
            showButton = false
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.15)) {
                showIcon = false
                celebrationActive = false
                showCard = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.15)) {
                showBackground = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
}

// MARK: - Celebration Particles View
struct CelebrationParticlesView: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { index in
                CelebrationParticle(
                    color: index % 3 == 0 ? Color(hex: "00D9A5") :
                           index % 3 == 1 ? Color(hex: "FFD700") :
                           Color(hex: "FF6B9D")
                )
                .position(
                    x: CGFloat.random(in: 0...geo.size.width),
                    y: CGFloat.random(in: 0...geo.size.height)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

struct CelebrationParticle: View {
    let color: Color
    @State private var yOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    private let size = CGFloat.random(in: 6...12)
    private let duration = Double.random(in: 2...4)
    
    var body: some View {
        Group {
            if Bool.random() {
                Circle()
                    .fill(color)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
            }
        }
        .frame(width: size, height: size)
        .opacity(opacity)
        .offset(y: yOffset)
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                yOffset = 500
                rotation = Double.random(in: 180...540)
            }
            withAnimation(.easeOut(duration: duration)) {
                opacity = 0
            }
        }
    }
}

// MARK: - Scale Button Style
struct RewardScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    RewardCompletedModal(isPresented: .constant(true), rewardAmount: 20)
}
