
import SwiftUI

struct GroupChatRewardAdModal: View {
    let onWatchAd: () -> Void
    let onUpgrade: () -> Void
    /// リワード広告の読み込み中
    var isAdLoading: Bool = false

    @State private var showBackground = false
    @State private var showCard = false
    @State private var showIcon = false
    @State private var showContent = false
    @State private var showButtons = false
    @State private var floatAnimation = false
    @State private var glowAnimation = false

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
            backgroundView

            if showBackground {
                floatingOrbsView
            }

            mainCard
                .scaleEffect(showCard ? 1 : 0.8)
                .opacity(showCard ? 1 : 0)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimationSequence()
        }
    }

    // MARK: - Background
    private var backgroundView: some View {
        ZStack {
            Color.black.opacity(showBackground ? 0.85 : 0)

            RadialGradient(
                colors: [Color(hex: "9D4EDD").opacity(0.15), Color.clear],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 400
            )
            .opacity(showBackground ? 1 : 0)

            RadialGradient(
                colors: [Color(hex: "FFD700").opacity(0.08), Color.clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 300
            )
            .opacity(showBackground ? 1 : 0)
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.4), value: showBackground)
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
            iconSection
                .padding(.top, 32)

            contentSection
                .padding(.top, 24)

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

    private var cardBackgroundView: some View {
        ZStack {
            cardBackground

            GeometryReader { geo in
                ZStack {
                    Ellipse()
                        .fill(Color(hex: "9D4EDD").opacity(0.15))
                        .frame(width: 300, height: 150)
                        .blur(radius: 60)
                        .offset(y: -100)

                    Ellipse()
                        .fill(Color(hex: "FFD700").opacity(0.08))
                        .frame(width: 200, height: 100)
                        .blur(radius: 40)
                        .offset(y: geo.size.height - 50)
                }
            }
        }
    }

    // MARK: - Icon
    private var iconSection: some View {
        ZStack {
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
                        .easeInOut(duration: 2).repeatForever(autoreverses: true).delay(Double(index) * 0.2),
                        value: glowAnimation
                    )
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "9D4EDD").opacity(0.3), Color(hex: "5A189A").opacity(0.1)],
                            center: .center,
                            startRadius: 20,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "E0AAFF"), Color(hex: "C77DFF")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(hex: "9D4EDD").opacity(0.5), radius: 10, x: 0, y: 4)
            }
            .scaleEffect(showIcon ? 1 : 0.5)
            .opacity(showIcon ? 1 : 0)
            .compositingGroup()
            .offset(y: floatAnimation ? -5 : 5)
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: floatAnimation)
        }
    }

    // MARK: - Content
    private var contentSection: some View {
        VStack(spacing: 16) {
            Text("グループチャットを続けるには")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.white, Color(hex: "E0AAFF")], startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

            VStack(spacing: 12) {
                Text("5通ごとに短い広告の視聴が必要です")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(goldAccent)

                    Text("プレミアムなら広告なしで無制限！")
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

    // MARK: - Buttons
    private var buttonsSection: some View {
        VStack(spacing: 14) {
            // プレミアムアップグレード（メイン）
            Button(action: {
                generateHapticFeedback()
                onUpgrade()
            }) {
                HStack(spacing: 12) {
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
                        Text("プレミアムにアップグレード")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(hex: "1A1A2E").opacity(0.7))
                        Text("広告なしで無制限チャット")
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
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 60)
                            .offset(x: glowAnimation ? geo.size.width + 60 : -60)
                            .animation(.linear(duration: 2.5).repeatForever(autoreverses: false), value: glowAnimation)
                        }
                        .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color(hex: "FFD700").opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(ScaleButtonStyle())

            // 広告を視聴（サブ）
            Button(action: {
                generateHapticFeedback()
                onWatchAd()
            }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "9D4EDD").opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(premiumGradient)
                    }

                    Text(isAdLoading ? NSLocalizedString("reward_ad_loading", comment: "Loading ad...") : "広告を視聴して続ける")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    if isAdLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "9D4EDD").opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color(hex: "9D4EDD").opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isAdLoading)
        }
        .opacity(showButtons ? 1 : 0)
        .offset(y: showButtons ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showButtons)
    }

    // MARK: - Animation
    private func startAnimationSequence() {
        withAnimation { showBackground = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showCard = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showIcon = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            floatAnimation = true
            glowAnimation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showContent = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showButtons = true }
    }

    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
