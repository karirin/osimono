//
//  LoadingView2.swift
//  osimono
//
//  Created by Apple on 2025/04/29.
//

import SwiftUI

import SwiftUI

struct SkeletonLoadingView<Content: View>: View {
    let placeholder: Content
    let animated: Bool
    @State private var phase: CGFloat = 0
    
    init(animated: Bool = true, @ViewBuilder placeholder: () -> Content) {
        self.placeholder = placeholder()
        self.animated = animated
    }
    
    var body: some View {
        ZStack {
            placeholder
                .opacity(0)
                .overlay(
                    GeometryReader { geometry in
                        ZStack {
                            Capsule()
                                .fill(Color.gray.opacity(0.3))
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                            
                            if animated {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                .gray.opacity(0.3),
                                                .gray.opacity(0.5),
                                                .gray.opacity(0.3)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: geometry.size.width,
                                        height: geometry.size.height
                                    )
                                    .offset(x: -geometry.size.width + (2 * geometry.size.width * phase))
                            }
                        }
                    }
                )
        }
        .onAppear {
            guard animated else { return }
            
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// ファンシーなスケルトンカードローディング
struct FancySkeletonCardLoadingView: View {
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // カードのヘッダー
            Text("コンテンツ読み込み中...")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            // ローディング中の場合
            if isLoading {
                VStack(spacing: 15) {
                    // アバター画像とタイトル
                    HStack(spacing: 15) {
                        // アバタープレースホルダー
                        SkeletonLoadingView {
                            Circle().frame(width: 50, height: 50)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            // タイトルプレースホルダー
                            SkeletonLoadingView {
                                Rectangle().frame(width: 150, height: 20)
                            }
                            
                            // サブタイトルプレースホルダー
                            SkeletonLoadingView {
                                Rectangle().frame(width: 100, height: 15)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // コンテンツテキストプレースホルダー
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonLoadingView {
                            Rectangle().frame(height: 15)
                        }
                        
                        SkeletonLoadingView {
                            Rectangle().frame(height: 15)
                        }
                        
                        SkeletonLoadingView {
                            Rectangle().frame(width: 250, height: 15)
                        }
                    }
                    .padding(.horizontal)
                    
                    // イメージプレースホルダー
                    SkeletonLoadingView {
                        Rectangle().frame(height: 200)
                    }
                    
                    // フッター
                    HStack(spacing: 20) {
                        ForEach(0..<3) { _ in
                            SkeletonLoadingView {
                                Capsule().frame(width: 80, height: 35)
                            }
                        }
                    }
                    .padding()
                }
            } else {
                // 実際のコンテンツはここに表示
                Text("コンテンツがロードされました！")
                    .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding()
        .frame(width: 350)
        .onAppear {
            // 5秒後にローディング状態を切り替え（デモ用）
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    isLoading = false
                }
            }
        }
    }
}

// パルジングスケルトンアニメーション
struct PulsingSkeletonLoadingView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // 背景
            Color.white
                .opacity(0.05)
                .cornerRadius(16)
            
            VStack(spacing: 16) {
                // ヘッダー
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .scaleEffect(isPulsing ? 1.2 : 0.8)
                                .opacity(isPulsing ? 0 : 0.5)
                        )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 12)
                        
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 8)
                    }
                    
                    Spacer()
                }
                
                // コンテンツ
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 10)
                    }
                    
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 250, height: 10)
                }
                
                // イメージプレースホルダー
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 160)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .white.opacity(0.2), .clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .offset(x: isPulsing ? 300 : -300)
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: 8)
                            .frame(height: 160)
                    )
                
                // アクションボタン
                HStack {
                    ForEach(0..<2) { _ in
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 30)
                    }
                }
            }
            .padding()
        }
        .frame(width: 350, height: 360)
        .onAppear {
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}

struct LoadingView10: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("スケルトンローディングのデモ")
                .font(.title)
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 30) {
                    FancySkeletonCardLoadingView()
                    
                    PulsingSkeletonLoadingView()
                }
            }
        }
        .padding()
    }
}

struct ParticleLoadingView1: View {
    let particleCount = 12
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 背景の光る円
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.3), .clear]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 0.8 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
            
            // パーティクル
            ForEach(0..<particleCount, id: \.self) { index in
                Particle1(index: index, particleCount: particleCount, isAnimating: $isAnimating)
            }
        }
        .frame(width: 150, height: 150)
        .onAppear {
            isAnimating = true
        }
    }
}

struct Particle1: View {
    let index: Int
    let particleCount: Int
    @Binding var isAnimating: Bool
    
    // パーティクルの色のバリエーション
    private var colors: [Color] {
        [.blue, .purple, .cyan, .indigo, .teal]
    }
    
    private var angle: Double {
        Double(index) * (360.0 / Double(particleCount))
    }
    
    private var delay: Double {
        Double(index) * (1.0 / Double(particleCount))
    }
    
    var body: some View {
        Circle()
            .fill(colors[index % colors.count])
            .frame(width: 10, height: 10)
            .offset(
                x: CGFloat(cos(angle * .pi / 180) * (isAnimating ? 50 : 20)),
                y: CGFloat(sin(angle * .pi / 180) * (isAnimating ? 50 : 20))
            )
            .opacity(isAnimating ? 1 : 0.3)
            .blur(radius: isAnimating ? 0 : 1)
            .animation(
                Animation.spring(response: 0.8, dampingFraction: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 3, height: 3)
                    .blur(radius: 0.5)
                    .opacity(isAnimating ? 0.8 : 0.2)
            )
    }
}

// スパークルトレイルアニメーション
struct SparkleTrailLoadingView: View {
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0
    let sparkleCount = 5
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // メインの円
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 20)
                .shadow(color: .purple.opacity(0.5), radius: 10)
                .offset(x: cos(rotationAngle) * 40, y: sin(rotationAngle) * 40)
                .scaleEffect(scale)
            
            // スパークルトレイル
            ForEach(1...sparkleCount, id: \.self) { i in
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.7 - (Double(i) * 0.1)),
                                                        .purple.opacity(0.5 - (Double(i) * 0.1))]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 15 - CGFloat(i) * 2, height: 15 - CGFloat(i) * 2)
                    .offset(
                        x: cos(rotationAngle - Double(i) * 0.2) * 40,
                        y: sin(rotationAngle - Double(i) * 0.2) * 40
                    )
                    .blur(radius: CGFloat(i) * 0.5)
            }
        }
        .frame(width: 100, height: 100)
        .onReceive(timer) { _ in
            // 円を回転させる
            withAnimation(.linear(duration: 0.05)) {
                rotationAngle += 0.05
            }
            
            // 周期的にサイズ変更
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                scale = scale == 1.0 ? 1.2 : 1.0
            }
        }
    }
}

// 使用例
struct BestLoadingView: View {
    var body: some View {
        VStack {
            
            ParticleLoadingView1()
        }
    }
}

struct LoadingView16: View {
    @State private var waveOffset = Angle(degrees: 0)
    @State private var waveHeight: CGFloat = 0.3
    @State private var progress: CGFloat = 0.5
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 外側の円形コンテナ
            Circle()
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 3)
                .background(
                    WaveShape(offset: waveOffset.radians, waveHeight: waveHeight, progress: progress)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple, .blue]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Circle())
                )
                .frame(width: 100, height: 100)
                .overlay(
                    // 進行状況テキスト
                    Text("\(Int(progress * 100))%")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                )
            
            // 外周のシャイニングエフェクト
            Circle()
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [.clear, .blue, .purple, .blue, .clear]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    lineWidth: 2
                )
                .frame(width: 120, height: 120)
                .rotationEffect(waveOffset)
        }
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.1)) {
                self.waveOffset += Angle(degrees: 5)
            }
            
            // 徐々に進行
            withAnimation(.easeInOut(duration: 3)) {
                if progress < 0.9 {
                    progress += 0.01
                } else {
                    progress = 0.2
                }
            }
        }
    }
}

// 波形状のシェイプ
struct WaveShape: Shape {
    var offset: Double
    var waveHeight: CGFloat
    var progress: CGFloat
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // スタート位置
        path.move(to: CGPoint(x: 0, y: rect.height * (1 - progress)))
        
        // 水面下の矩形
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * (1 - progress)))
        
        // 波の形状
        let waveWidth = rect.width
        let wavelength = waveWidth
        
        for x in stride(from: 0, through: waveWidth, by: 1) {
            let relativeX = x / wavelength
            
            let sine = sin(relativeX * 2 * .pi + offset)
            let y = waveHeight * sine
            let point = CGPoint(x: x, y: rect.height * (1 - progress) + y * 10)
            
            path.addLine(to: point)
        }
        
        return path
    }
}

struct RotatingSquaresLoadingView: View {
    @State private var isAnimating = false
    let squareCount = 5
    
    var body: some View {
        ZStack {
            ForEach(0..<squareCount, id: \.self) { index in
                Rectangle()
                    .stroke(lineWidth: 3)
                    .frame(width: 50, height: 50)
                    .foregroundColor(
                        Color(
                            hue: Double(index) / Double(squareCount),
                            saturation: 0.8,
                            brightness: 0.9
                        )
                    )
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 3)
                            .repeatForever(autoreverses: false)
                            .delay(0.15 * Double(index)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// 砂時計スタイルのアニメーション
struct HourglassLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "hourglass")
            .font(.system(size: 40))
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            )
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .animation(
                Animation.easeInOut(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// インタラクティブなLottieライクなアニメーション
struct LottieStyleLoadingView: View {
    @State private var offsetY: CGFloat = 0
    @State private var scale: CGFloat = 1
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 背景の円
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 100, height: 100)
            
            // 浮かび上がる球体
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 20, height: 20)
                .offset(y: offsetY)
                .scaleEffect(scale)
                .shadow(color: .purple.opacity(0.5), radius: 5)
            
            // 光の効果
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 10, height: 10)
                .offset(x: 3, y: offsetY - 5)
                .scaleEffect(scale)
                .opacity(scale * 0.8)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                offsetY = -20
                scale = 0.8
            }
            
            isAnimating = true
        }
    }
}

// 利用例
struct LoadingView13: View {
    var body: some View {
        VStack(spacing: 60) {
            VStack {
                Text("回転する正方形")
                    .font(.headline)
                RotatingSquaresLoadingView()
            }
            
            VStack {
                Text("砂時計アニメーション")
                    .font(.headline)
                HourglassLoadingView()
            }
            
            VStack {
                Text("Lottieスタイルアニメーション")
                    .font(.headline)
                LottieStyleLoadingView()
            }
        }
        .padding()
    }
}

struct DotPulseLoadingView: View {
    @State private var isAnimating = false
    let dotCount = 3
    let dotSize: CGFloat = 12
    let dotSpacing: CGFloat = 8
    
    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .opacity(isAnimating ? 1 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(0.2 * Double(index)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// 波紋エフェクト付きローディング
struct RippleLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
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
            
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 30)
                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 0)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            isAnimating = true
        }
    }
}

// 利用例
struct LoadingView12: View {
    var body: some View {
        VStack(spacing: 50) {
            VStack {
                Text("ドットパルス")
                    .font(.headline)
                DotPulseLoadingView()
            }
            
            VStack {
                Text("波紋エフェクト")
                    .font(.headline)
                RippleLoadingView()
            }
        }
    }
}

struct LoadingView11: View {
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5)
                .opacity(0.3)
                .foregroundColor(.blue)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple, .pink]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(Angle(degrees: isLoading ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isLoading
                )
        }
        .frame(width: 50, height: 50)
        .onAppear() {
            isLoading = true
        }
    }
}

#Preview {
    LoadingView12()
}
