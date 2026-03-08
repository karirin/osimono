//
//  StartLoadingView.swift
//  osimono
//
//  Created by Apple on 2025/05/03.
//  Updated with modern design
//

import SwiftUI

struct StartLoadingView: View {
    // MARK: - Animation States
    @State private var animationPhase: Double = 0
    @State private var titleCharacters: [CharacterState] = []
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var orbRotation: Double = 0
    @State private var particleOffset: CGFloat = 0
    @State private var activeLoadingDot = 0
    @State private var meshPhase: Double = 0
    
    // MARK: - Constants
    let title = "推しログ"
    
    let neonColors: [Color] = [
        Color(hex: "FF2D92"),  // ホットピンク
        Color(hex: "00F5FF"),  // シアン
        Color(hex: "BF5AF2"),  // パープル
        Color(hex: "FF375F"),  // レッド
        Color(hex: "64D2FF"),  // スカイブルー
    ]
    
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Background Layer
                backgroundLayer(geometry: geometry)
                
                // MARK: - Floating Particles
                floatingParticles(geometry: geometry)
                
                // MARK: - Main Content
                VStack(spacing: 40) {
                    Spacer()
                    
                    // ロゴエリア
                    logoSection
                    
                    // タイトル
                    titleSection
                    
                    Spacer()
                    
                    // ローディングインジケーター
                    loadingIndicator
                    
                    Spacer()
                        .frame(height: 60)
                }
                .opacity(showContent ? 1 : 0)
                .scaleEffect(showContent ? 1 : 0.9)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            setupAnimations()
        }
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                activeLoadingDot = (activeLoadingDot + 1) % 3
            }
        }
    }
    
    // MARK: - Background
    @ViewBuilder
    private func backgroundLayer(geometry: GeometryProxy) -> some View {
        ZStack {
            // ベースグラデーション - 深いダークブルー
            LinearGradient(
                colors: [
                    Color(hex: "0A0A1A"),
                    Color(hex: "12122A"),
                    Color(hex: "1A1A3A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // メッシュグラデーション風エフェクト
            meshGradientEffect(geometry: geometry)
            
            // 波紋エフェクト
            rippleEffect(geometry: geometry)
            
            // グリッドオーバーレイ
            gridOverlay(geometry: geometry)
        }
    }
    
    @ViewBuilder
    private func meshGradientEffect(geometry: GeometryProxy) -> some View {
        ZStack {
            // メインのグローブロブ
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                neonColors[index].opacity(0.4),
                                neonColors[index].opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .blur(radius: 60)
                    .offset(
                        x: cos(meshPhase + Double(index) * 2.1) * 100,
                        y: sin(meshPhase * 0.7 + Double(index) * 1.5) * 150 - 100
                    )
                    .animation(
                        .easeInOut(duration: 8 + Double(index) * 2)
                        .repeatForever(autoreverses: true),
                        value: meshPhase
                    )
            }
        }
    }
    
    @ViewBuilder
    private func rippleEffect(geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                neonColors[0].opacity(0.3),
                                neonColors[1].opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .frame(
                        width: 200 + CGFloat(index) * 150,
                        height: 200 + CGFloat(index) * 150
                    )
                    .scaleEffect(pulseScale + CGFloat(index) * 0.1)
                    .opacity(0.5 - Double(index) * 0.15)
                    .animation(
                        .easeInOut(duration: 3)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.5),
                        value: pulseScale
                    )
            }
        }
        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
    }
    
    @ViewBuilder
    private func gridOverlay(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            // 縦線
            for i in stride(from: 0, to: size.width, by: 40) {
                var path = Path()
                path.move(to: CGPoint(x: i, y: 0))
                path.addLine(to: CGPoint(x: i, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
            }
            // 横線
            for i in stride(from: 0, to: size.height, by: 40) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: i))
                path.addLine(to: CGPoint(x: size.width, y: i))
                context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 0.5)
            }
        }
    }
    
    // MARK: - Floating Particles
    @ViewBuilder
    private func floatingParticles(geometry: GeometryProxy) -> some View {
        ForEach(0..<20, id: \.self) { index in
            ParticleView(
                color: neonColors[index % neonColors.count],
                size: CGFloat.random(in: 2...6),
                initialX: CGFloat.random(in: 0...geometry.size.width),
                initialY: CGFloat.random(in: 0...geometry.size.height),
                duration: Double.random(in: 4...8)
            )
        }
    }
    
    // MARK: - Logo Section
    @ViewBuilder
    private var logoSection: some View {
        ZStack {
            // 外側のオーブリング
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                neonColors[index].opacity(0.8),
                                neonColors[(index + 1) % neonColors.count].opacity(0.4),
                                Color.clear,
                                Color.clear,
                                neonColors[index].opacity(0.8)
                            ],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 120 + CGFloat(index) * 30, height: 120 + CGFloat(index) * 30)
                    .rotationEffect(.degrees(orbRotation + Double(index) * 60))
                    .animation(
                        .linear(duration: 6 + Double(index) * 2)
                        .repeatForever(autoreverses: false),
                        value: orbRotation
                    )
            }
            
            // 中央のグロー
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            neonColors[0].opacity(0.8),
                            neonColors[2].opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 60
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 20)
            
            // アイコン（ハートスター）
            ZStack {
                // グラス背景
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.5),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 80, height: 80)
                
                // スターハートアイコン
                Image(systemName: "star.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [neonColors[0], neonColors[2]],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: neonColors[0].opacity(0.8), radius: 10)
            }
            .scaleEffect(pulseScale * 0.95 + 0.05)
            .animation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true),
                value: pulseScale
            )
        }
    }
    
    // MARK: - Title Section
    @ViewBuilder
    private var titleSection: some View {
        VStack(spacing: 12) {
            // メインタイトル
            HStack(spacing: 4) {
                ForEach(Array(title.enumerated()), id: \.offset) { index, char in
                    Text(String(char))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    .white,
                                    neonColors[index % neonColors.count].opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: neonColors[index % neonColors.count].opacity(0.8), radius: 15, x: 0, y: 0)
                        .shadow(color: neonColors[index % neonColors.count].opacity(0.4), radius: 30, x: 0, y: 5)
                        .offset(y: titleCharacters.indices.contains(index) ? titleCharacters[index].offset : 0)
                        .scaleEffect(titleCharacters.indices.contains(index) ? titleCharacters[index].scale : 1)
                        .opacity(titleCharacters.indices.contains(index) ? titleCharacters[index].opacity : 0)
                }
            }
            
            // サブタイトル
            Text("あなたの推し活をもっと楽しく")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .tracking(2)
        }
    }
    
    // MARK: - Loading Indicator
    @ViewBuilder
    private var loadingIndicator: some View {
        VStack(spacing: 16) {
            // プログレスバー風デザイン
            ZStack(alignment: .leading) {
                // 背景
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 200, height: 4)
                
                // アニメーションバー
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [neonColors[0], neonColors[1], neonColors[2]],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 60, height: 4)
                    .offset(x: particleOffset)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: particleOffset
                    )
            }
            
            // ローディングテキスト
            HStack(spacing: 4) {
                Text("Loading")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                // アニメーションドット
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(activeLoadingDot == index ? neonColors[0] : .white.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(activeLoadingDot == index ? 1.3 : 1.0)
                            .shadow(
                                color: activeLoadingDot == index ? neonColors[0].opacity(0.8) : .clear,
                                radius: 5
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Setup Animations
    private func setupAnimations() {
        // タイトル文字の初期化
        titleCharacters = Array(repeating: CharacterState(), count: title.count)
        
        // コンテンツ表示
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }
        
        // タイトルアニメーション
        for i in 0..<title.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1 + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    titleCharacters[i].opacity = 1
                    titleCharacters[i].offset = 0
                    titleCharacters[i].scale = 1
                }
            }
            
            // 継続的な浮遊アニメーション
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(
                    .easeInOut(duration: 2 + Double(i) * 0.2)
                    .repeatForever(autoreverses: true)
                ) {
                    titleCharacters[i].offset = CGFloat.random(in: -3...3)
                }
            }
        }
        
        // 各種アニメーション開始
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
            orbRotation = 360
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            particleOffset = 140
        }
        
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            meshPhase = .pi * 2
        }
    }
}

// MARK: - Supporting Types
struct CharacterState {
    var opacity: Double = 0
    var offset: CGFloat = 20
    var scale: CGFloat = 0.8
}

// MARK: - Particle View
struct ParticleView: View {
    let color: Color
    let size: CGFloat
    let initialX: CGFloat
    let initialY: CGFloat
    let duration: Double
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size / 3)
            .position(x: initialX, y: initialY + offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    offset = -100
                    opacity = Double.random(in: 0.3...0.7)
                }
            }
    }
}

// MARK: - Preview
#Preview {
    StartLoadingView()
}
