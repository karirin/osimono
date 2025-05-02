//
//  LoadingView.swift
//  osimono
//
//  Created by Apple on 2025/04/27.
//

import SwiftUI

import SwiftUI

struct LoadingView: View {
    // 3Dキューブのアニメーション用ステート
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0
    @State private var showContent = false
    
    // パーティクルエフェクト用
    @State private var particles: [Particle] = []
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "1A2980"),
                    Color(hex: "26D0CE")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            // パーティクル
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: 0.5)
            }
            
            VStack(spacing: 40) {
                // アプリタイトル
                Text("推しコレクション")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color(hex: "26D0CE").opacity(0.5), radius: 5, x: 0, y: 2)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : -20)
                    .animation(
                        Animation.spring(response: 0.6, dampingFraction: 0.7).delay(0.4),
                        value: showContent
                    )
                
                // 3Dキューブ
                ZStack {
                    // キューブの面
                    ForEach(0..<6) { index in
                        CubeFace(
                            rotationX: rotationX,
                            rotationY: rotationY,
                            faceIndex: index
                        )
                    }
                }
                .scaleEffect(scale)
                .opacity(opacity)
                
                // ローディングテキスト
                VStack(spacing: 15) {
                    Text("推し情報を整理しています")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("あなただけの推し空間がまもなく完成します")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(
                    Animation.easeOut(duration: 0.8).delay(0.6),
                    value: showContent
                )
            }
            .padding()
        }
        .onAppear {
            // キューブのアニメーション
            withAnimation(Animation.easeOut(duration: 1.0)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // 継続的な回転アニメーション
            withAnimation(
                Animation.linear(duration: 6)
                    .repeatForever(autoreverses: false)
            ) {
                rotationY = 360
            }
            
            withAnimation(
                Animation.linear(duration: 8)
                    .repeatForever(autoreverses: false)
            ) {
                rotationX = 360
            }
            
            // テキストのアニメーション
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showContent = true
            }
            
            // パーティクルの生成
            for _ in 0..<30 {
                particles.append(Particle())
            }
        }
    }
}

// パーティクルの定義
struct Particle: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
    
    init() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        self.position = CGPoint(
            x: CGFloat.random(in: 0...screenWidth),
            y: CGFloat.random(in: 0...screenHeight)
        )
        self.size = CGFloat.random(in: 2...4)
        self.opacity = Double.random(in: 0.3...0.7)
    }
}

// キューブの面
struct CubeFace: View {
    let rotationX: Double
    let rotationY: Double
    let faceIndex: Int
    
    // キューブのサイズ
    let size: CGFloat = 120
    
    var body: some View {
        ZStack {
            // 面の背景
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: colorsForFace()),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
            
            // 面のコンテンツ（アイコンなど）
            Image(systemName: iconForFace())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size * 0.4)
                .foregroundColor(.white)
                .opacity(0.9)
        }
        .frame(width: size, height: size)
        // 各面の位置調整
        .rotation3DEffect(
            .degrees(rotationX),
            axis: (x: 1, y: 0, z: 0)
        )
        .rotation3DEffect(
            .degrees(rotationY),
            axis: (x: 0, y: 1, z: 0)
        )
        .offset(offsetForFace())
    }
    
    // 面に応じた色
    private func colorsForFace() -> [Color] {
        switch faceIndex {
        case 0:
            return [Color(hex: "FF61D2"), Color(hex: "FE9090")]
        case 1:
            return [Color(hex: "02AABD"), Color(hex: "00CDAC")]
        case 2:
            return [Color(hex: "FDA085"), Color(hex: "F6D365")]
        case 3:
            return [Color(hex: "BFF098"), Color(hex: "6FD6FF")]
        case 4:
            return [Color(hex: "C79081"), Color(hex: "DFA579")]
        case 5:
            return [Color(hex: "30CFD0"), Color(hex: "330867")]
        default:
            return [Color.gray, Color.gray]
        }
    }
    
    // 面に応じたアイコン
    private func iconForFace() -> String {
        let icons = [
            "heart.fill", "star.fill", "music.note",
            "ticket.fill", "photo.fill", "person.crop.circle.fill"
        ]
        return icons[faceIndex % icons.count]
    }
    
    // 面の位置オフセット（3D効果）
    private func offsetForFace() -> CGSize {
        let halfSize = size / 2
        
        switch faceIndex {
        case 0: // 前面
            return CGSize(width: 0, height: 0)
        case 1: // 右面
            return CGSize(width: halfSize, height: 0)
        case 2: // 後面
            return CGSize(width: 0, height: 0)
        case 3: // 左面
            return CGSize(width: -halfSize, height: 0)
        case 4: // 上面
            return CGSize(width: 0, height: -halfSize)
        case 5: // 下面
            return CGSize(width: 0, height: halfSize)
        default:
            return CGSize.zero
        }
    }
}

struct LoadingView5: View {
    @State private var rotation = 0.0
    @State private var scale: CGFloat = 0.8
    @State private var blurRadius: CGFloat = 0
    @State private var progress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 華やかな背景
            ZStack {
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "FF87B2").opacity(0.4),
                        Color(hex: "4059AD").opacity(0.6)
                    ]),
                    center: .topLeading,
                    startRadius: 100,
                    endRadius: 600
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "97DFFC").opacity(0.5),
                        Color.clear
                    ]),
                    center: .bottomTrailing,
                    startRadius: 50,
                    endRadius: 400
                )
                
                // 装飾要素
                Circle()
                    .fill(Color(hex: "FF5DA2").opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                    .offset(x: -80, y: -200)
                
                Circle()
                    .fill(Color(hex: "6CD4FF").opacity(0.2))
                    .frame(width: 300, height: 300)
                    .blur(radius: 30)
                    .offset(x: 100, y: 200)
            }
            .edgesIgnoringSafeArea(.all)
            
            // グラスモーフィズムカード
            VStack(spacing: 30) {
                // メインカード
                ZStack {
                    // ガラス効果のある背景
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Color.white.opacity(0.15))
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(Color.white.opacity(0.1))
                                .blur(radius: 10)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.1),
                                            Color.clear,
                                            Color.white.opacity(0.2)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color(hex: "6E5773").opacity(0.1), radius: 20, x: 0, y: 10)
                        .scaleEffect(scale)
                        .blur(radius: blurRadius)
                    
                    // カードコンテンツ
                    VStack(spacing: 30) {
                        // アイコン
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "6A0572"),
                                            Color(hex: "AB83A1")
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "6A0572").opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            // 回転するアイコン
                            Image(systemName: "heart.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40)
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(rotation))
                                .animation(
                                    Animation.linear(duration: 10)
                                        .repeatForever(autoreverses: false),
                                    value: rotation
                                )
                        }
                        .padding(.top, 30)
                        
                        // アプリ名
                        Text("推し〜ず")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color(hex: "6A0572").opacity(0.5), radius: 4, x: 0, y: 2)
                        
                        // ローディングプログレス
                        VStack(spacing: 12) {
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            // グローエフェクト付きプログレスバー
                            ZStack(alignment: .leading) {
                                // バーの背景
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 200, height: 8)
                                
                                // プログレス部分
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color(hex: "FF9190"),
                                                Color(hex: "FFC371")
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 200 * progress, height: 8)
                                    .shadow(color: Color(hex: "FF9190").opacity(0.6), radius: 8, x: 0, y: 0)
                            }
                        }
                        
                        // ステータステキスト
                        Text("推し活データ同期中...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.bottom, 30)
                    }
                    .padding(.horizontal)
                }
                .frame(width: 300, height: 350)
                .scaleEffect(scale)
                
                // ガラスモーフィズムの小さなカード群
                HStack(spacing: 20) {
                    ForEach(0..<3) { index in
                        GlassCard(index: index)
                            .offset(y: index == 1 ? -15 : 0)
                    }
                }
                .offset(y: -30)
                .scaleEffect(scale)
            }
        }
        .onAppear {
            // アニメーション開始
            withAnimation(Animation.easeOut(duration: 1.0)) {
                scale = 1.0
                blurRadius = 0
            }
            
            // 回転アニメーション
            rotation = 360
            
            // プログレスバーのアニメーション
            withAnimation(Animation.easeInOut(duration: 3.0)) {
                progress = 1.0
            }
        }
    }
}

// ガラスのようなミニカード
struct GlassCard: View {
    let index: Int
    @State private var animateOpacity = false
    
    var body: some View {
        ZStack {
            // ガラスエフェクト
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.1))
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.05))
                        .blur(radius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.5),
                                    Color.clear,
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            
            // カードコンテンツ
            VStack(spacing: 10) {
                Image(systemName: iconName(for: index))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white.opacity(animateOpacity ? 1.0 : 0.7))
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: animateOpacity
                    )
                
                Text(titleName(for: index))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(15)
        }
        .frame(width: 80, height: 90)
        .onAppear {
            animateOpacity = true
        }
    }
    
    // アイコン名
    func iconName(for index: Int) -> String {
        let icons = ["music.note", "ticket.fill", "photo.on.rectangle"]
        return icons[index % icons.count]
    }
    
    // タイトル名
    func titleName(for index: Int) -> String {
        let titles = ["楽曲", "イベント", "写真"]
        return titles[index % titles.count]
    }
}

struct LoadingView4: View {
    @State private var animationAmount = 0.0
    @State private var textOpacity: [Double] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var showSubtext = false
    
    let title = "推し ログ"
    
    var body: some View {
        ZStack {
            // 洗練された背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "0A1128"),
                    Color(hex: "001F54")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // 背景のグロー効果
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "FF10F0").opacity(0.2),
                    Color.clear
                ]),
                center: .center,
                startRadius: 10,
                endRadius: 300
            )
            .blur(radius: 20)
            .scaleEffect(1.0 + 0.1 * sin(animationAmount))
            .animation(
                Animation.easeInOut(duration: 3)
                    .repeatForever(autoreverses: true),
                value: animationAmount
            )
            
            VStack(spacing: 40) {
                // アニメーションテキスト
                HStack(spacing: 3) {
                    ForEach(0..<title.count, id: \.self) { index in
                        Text(String(Array(title)[index]))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: Color(hex: "FF10F0").opacity(0.7), radius: 5, x: 0, y: 0)
                            .opacity(textOpacity[index])
                            .scaleEffect(textOpacity[index])
                            .offset(y: textOpacity[index] == 1 ? 0 : -20)
                    }
                }
                
                // 3Dローディングインジケーター
                FancySpinner()
                    .frame(width: 100, height: 100)
                    .padding(.top, 10)
                
                // サブテキスト
                VStack(spacing: 15) {
                    Text("あなたの推しライフを始めましょう")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("スケジュール・グッズ・ファンコミュニティ")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(showSubtext ? 1 : 0)
                .offset(y: showSubtext ? 0 : 20)
                .animation(
                    Animation.easeOut(duration: 0.8).delay(1.2),
                    value: showSubtext
                )
            }
            
            // 装飾エフェクト（星）
            ForEach(0..<15) { i in
                StarShape()
                    .fill(Color.white.opacity(Double.random(in: 0.3...0.6)))
                    .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .scaleEffect(1.0 + 0.2 * sin(animationAmount + Double(i)))
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 1.5...3.0))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...1.5)),
                        value: animationAmount
                    )
            }
        }
        .onAppear {
            // テキストのアニメーション
            for i in 0..<title.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        textOpacity[i] = 1
                    }
                }
            }
            
            // サブテキストのアニメーション
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showSubtext = true
            }
            
            // 背景のアニメーション
            animationAmount = 1.0
        }
    }
}

// 星の形状
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.4
        
        var path = Path()
        let points = 5
        
        for i in 0..<points * 2 {
            let angle = Double(i) * .pi / Double(points)
            let useRadius = i % 2 == 0 ? radius : innerRadius
            let x = center.x + CGFloat(cos(angle)) * useRadius
            let y = center.y + CGFloat(sin(angle)) * useRadius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// 3Dスピナー
struct FancySpinner: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 内側のリング
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FF10F0"),
                            Color(hex: "6C22BD")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .frame(width: 60, height: 60)
                .shadow(color: Color(hex: "FF10F0").opacity(0.5), radius: 10, x: 0, y: 0)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 3)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // 外側のリング
            Circle()
                .trim(from: 0.2, to: 0.8)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "00CCFF"),
                            Color(hex: "33F6FF")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 90, height: 90)
                .rotationEffect(Angle(degrees: isAnimating ? -360 : 0))
                .animation(
                    Animation.linear(duration: 5)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct LoadingView3: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            // 洗練された背景
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "1F3A5F"), Color(hex: "080F28")]),
                center: .center,
                startRadius: 5,
                endRadius: 500
            )
            .edgesIgnoringSafeArea(.all)
            
            // キラキラ効果（星）
            ForEach(0..<20) { i in
                Circle()
                    .fill(Color.white.opacity(Double.random(in: 0.1...0.3)))
                    .frame(width: CGFloat.random(in: 2...4))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 1...3))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...2)),
                        value: opacity
                    )
            }
            
            VStack(spacing: 40) {
                // メインコンテンツ
                ZStack {
                    // カード背景
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "6639A6"),
                                    Color(hex: "521262")
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 280, height: 320)
                        .shadow(color: Color(hex: "9D4EDD").opacity(0.6), radius: 15, x: 0, y: 10)
                        .rotation3DEffect(
                            .degrees(rotation),
                            axis: (x: 0.0, y: 1.0, z: 0.0)
                        )
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    // カードのコンテンツ
                    VStack(spacing: 25) {
                        // アプリアイコン
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(hex: "FF8500"),
                                            Color(hex: "FF49DB")
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 90, height: 90)
                                .shadow(color: Color(hex: "FF49DB").opacity(0.5), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "star.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 50)
                                .foregroundColor(.white)
                        }
                        .padding(.top, 20)
                        
                        // アプリ名
                        Text("OSHI LIFE")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        
                        // ローディングバー
                        GlowingProgressBar()
                            .frame(height: 30)
                            .padding(.horizontal, 30)
                        
                        // ローディングテキスト
                        VStack(spacing: 8) {
                            Text("推し活データ準備中")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("あなただけの推し空間を作成します")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .opacity(showDetails ? 1 : 0)
                        }
                        .padding(.bottom, 30)
                    }
                    .rotation3DEffect(
                        .degrees(rotation),
                        axis: (x: 0.0, y: 1.0, z: 0.0)
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                }
            }
        }
        .onAppear {
            withAnimation(Animation.easeOut(duration: 1.5)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // カードの3Dローテーションアニメーション
            withAnimation(
                Animation.easeInOut(duration: 3)
                    .repeatForever(autoreverses: true)
            ) {
                rotation = 5
            }
            
            // 詳細テキストを少し遅れて表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.8)) {
                    showDetails = true
                }
            }
        }
    }
}

// 光るプログレスバー
struct GlowingProgressBar: View {
    @State private var progress: CGFloat = 0.0
    @State private var glowOpacity: Double = 0.0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // バックグラウンド
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "3E1F47").opacity(0.7))
            
            // プログレス
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "F72585"),
                            Color(hex: "7209B7")
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: progress * UIScreen.main.bounds.width * 0.6)
                .shadow(color: Color(hex: "F72585").opacity(glowOpacity), radius: 8, x: 0, y: 0)
        }
        .onAppear {
            // プログレスバーのアニメーション
            withAnimation(Animation.easeInOut(duration: 3.0)) {
                progress = 0.75
            }
            
            // 光るエフェクトのアニメーション
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                glowOpacity = 0.8
            }
        }
    }
}

struct LoadingView2: View {
    // アイコンのアニメーション用ステート
    @State private var animateIcons = false
    @State private var showTitle = false
    
    // アイコン定義
    let icons = [
        "music.note", "heart.fill", "star.fill", "ticket.fill",
        "photo.fill", "mic.fill", "person.2.fill", "sparkles"
    ]
    
    var body: some View {
        ZStack {
            // 背景
//            Color(hex: "1A1A2E")
//                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 50) {
                // アプリ名
//                Text("推しラブ")
//                    .font(.system(size: 42, weight: .black, design: .rounded))
//                    .foregroundColor(.white)
//                    .shadow(color: Color(hex: "FF2E63").opacity(0.5), radius: 10, x: 0, y: 0)
//                    .opacity(showTitle ? 1 : 0)
//                    .scaleEffect(showTitle ? 1 : 0.8)
                
                // アイコングリッドアニメーション
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
                    ForEach(0..<6, id: \.self) { index in
                        Image(systemName: icons[index])
                            .font(.system(size: 24))
                            .foregroundColor(iconColor(for: index))
                            .frame(width: 60, height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
//                                    .fill(Color(hex: "16213E"))
                                    .fill(Color(.white))
                                    .shadow(color: Color(hex: "FF2E63").opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                            .offset(y: animateIcons ? 0 : 50)
                            .opacity(animateIcons ? 1 : 0)
                            .animation(
                                Animation.spring(response: 0.6, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.1),
                                value: animateIcons
                            )
                    }
                }
                .padding(.horizontal)
                
                // ローディングテキスト
//                Text("推し活データを取得中...")
//                    .font(.system(.body, design: .rounded))
//                    .foregroundColor(Color(hex: "EEEEEE"))
//                    .opacity(showTitle ? 1 : 0)
//                    .animation(
//                        Animation.easeIn.delay(0.8),
//                        value: showTitle
//                    )
                
                // プログレスインジケーター
//                FancyProgressIndicator()
                DotPulseLoadingView()
                    .padding(.top, 20)
            }
            .padding()
        }
        .onAppear {
            withAnimation {
                animateIcons = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation {
                        showTitle = true
                    }
                }
            }
        }
    }
    
    // アイコンごとに異なる色を設定
    func iconColor(for index: Int) -> Color {
        let colors = [
            Color(hex: "FF2E63"),
            Color(hex: "FF9A8B"),
            Color(hex: "B983FF"),
            Color(hex: "6A67CE"),
            Color(hex: "33D1FF"),
            Color(hex: "FF87CA")
        ]
        return colors[index % colors.count]
    }
}

// ファンシーなプログレスインジケーター
struct FancyProgressIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 背景のバー
            Capsule()
                .frame(width: 200, height: 6)
                .foregroundColor(Color(hex: "16213E"))
            
            // アニメーションするバー
            Capsule()
                .frame(width: 80, height: 6)
                .foregroundColor(Color(hex: "FF2E63"))
                .offset(x: isAnimating ? 60 : -60)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct LoadingView1: View {
    @State private var animateGradient = false
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // 動的なグラデーション背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "FF9FF3"),
                    Color(hex: "FEC3A6"),
                    Color(hex: "EAB0DC"),
                    Color(hex: "FFCCF9")
                ]),
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .edgesIgnoringSafeArea(.all)
            .hueRotation(.degrees(animateGradient ? 45 : 0))
            .animation(
                Animation.easeInOut(duration: 6.0)
                    .repeatForever(autoreverses: true),
                value: animateGradient
            )
            
            // コンテンツ
            VStack(spacing: 40) {
                // アプリロゴ
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .shadow(color: .pink.opacity(0.3), radius: 15, x: 0, y: 5)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50)
                        .foregroundColor(.white)
                        .shadow(color: .pink.opacity(0.5), radius: 5, x: 0, y: 2)
                        .scaleEffect(scale)
                        .animation(
                            Animation.easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true),
                            value: scale
                        )
                }
                
                // タイトル（モダンなスタイル）
                Text("OSHI KATSU")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(.white)
                    .shadow(color: .pink.opacity(0.5), radius: 2, x: 0, y: 1)
                
                // ローディングインジケーター
                LoadingDots()
                    .padding(.top, 20)
                
                // サブテキスト
                Text("あなたの推し活をサポートします")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 10)
            }
            .padding()
        }
        .onAppear {
            animateGradient = true
            scale = 1.1
        }
    }
}

// カスタムローディングドット
struct LoadingDots: View {
    @State private var firstDotScale: CGFloat = 1.0
    @State private var secondDotScale: CGFloat = 1.0
    @State private var thirdDotScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .scaleEffect(firstDotScale)
            
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .scaleEffect(secondDotScale)
            
            Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .scaleEffect(thirdDotScale)
        }
        .onAppear {
            let animation = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
            
            withAnimation(animation.delay(0.0)) {
                firstDotScale = 0.6
            }
            
            withAnimation(animation.delay(0.2)) {
                secondDotScale = 0.6
            }
            
            withAnimation(animation.delay(0.4)) {
                thirdDotScale = 0.6
            }
        }
    }
}


#Preview {
    LoadingView4()
}
