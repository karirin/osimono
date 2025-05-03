//
//  StartLoadingView.swift
//  osimono
//
//  Created by Apple on 2025/05/03.
//

import SwiftUI

struct StartLoadingView: View {
    @State private var animationAmount = 0.0
    @State private var textOpacity: [Double] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var textOffsets: [CGFloat] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var textScales: [CGFloat] = [0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8, 0.8]
    @State private var textRotations: [Double] = [0, 0, 0, 0, 0, 0, 0, 0]
    @State private var textColors: [Color] = Array(repeating: .white, count: 8)
    @State private var showSubtext = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoRotation: Double = 0
    @State private var dotsAnimation = 0
    
    @State private var subtextColors: [Color] = Array(repeating: .white, count: 7)
    @State private var subtextScales: [CGFloat] = Array(repeating: 1.0, count: 7)
    @State private var glowOpacity: Double = 0.0
    @State private var currentColorIndex: Int = 0
    
    let title = "推し ログ"
    let colorPalette: [Color] = [
        Color(hex: "FF10F0"),
        Color(hex: "FF61F5"),
        Color(hex: "6B10FF"),
        Color(hex: "10FFFF")
    ]
    
    // 点滅するドット用のタイマー
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // モダンな背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "08082B"),
                    Color(hex: "1A1A4D")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // 動的な背景エフェクト
            ZStack {
                // メインのグロー
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "FF10F0").opacity(0.25),
                        Color(hex: "6B10FF").opacity(0.15),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 10,
                    endRadius: 350
                )
                .blur(radius: 25)
                .scaleEffect(1.0 + 0.15 * sin(animationAmount))
                
                // セカンダリーのグロー
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "10FFFF").opacity(0.15),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.7, y: 0.3),
                    startRadius: 5,
                    endRadius: 200
                )
                .blur(radius: 20)
                .scaleEffect(1.0 + 0.1 * cos(animationAmount * 0.8))
            }
            .animation(
                Animation.easeInOut(duration: 4)
                    .repeatForever(autoreverses: true),
                value: animationAmount
            )
            
            // 背景の模様（ドット・線）
            BackgroundPatterns()
                .opacity(0.3)
            
            VStack(spacing: 40) {
                
                // より可愛いアニメーションテキスト
                HStack(spacing: 5) {
                    ForEach(0..<title.count, id: \.self) { index in
                        Text(String(Array(title)[index]))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(Color.white)
                            .shadow(color: colorPalette[index % colorPalette.count].opacity(0.7), radius: 5, x: 0, y: 0)
                            .opacity(textOpacity[index])
                            .scaleEffect(textScales[index])
                            .rotationEffect(.degrees(textRotations[index]))
                            .offset(y: textOffsets[index])
                    }
                }
                
                // 改良されたローディングインジケーター
                ModernSpinner()
                    .frame(width: 100, height: 100)
                    .padding(.top, 10)
                
                VStack{
                    HStack(spacing: 2) {
                        let subText = "アプリ起動中"
                        ForEach(0..<subText.count, id: \.self) { index in
                            Text(String(Array(subText)[index]))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(Color.white)
                                .scaleEffect(subtextScales[index])
                                .animation(
                                    Animation.spring(response: 0.4, dampingFraction: 0.6)
                                        .repeatForever()
                                        .delay(Double(index) * 0.1),
                                    value: subtextScales[index]
                                )
                        }
                    }
                    
                    // 点滅する3つの点
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(colorPalette[currentColorIndex])
                                .frame(width: 8, height: 8)
                                .scaleEffect(dotsAnimation == index ? 1.5 : 1.0)
                                .opacity(dotsAnimation == index ? 1.0 : 0.5)
                                .shadow(color: colorPalette[currentColorIndex].opacity(0.7), radius: dotsAnimation == index ? 5 : 0, x: 0, y: 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dotsAnimation)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 15)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.2))
                        
                        // キラキラエフェクト
                        ForEach(0..<5, id: \.self) { index in
                            Circle()
                                .fill(colorPalette[index % colorPalette.count])
                                .frame(width: 4, height: 4)
                                .offset(
                                    x: CGFloat.random(in: -60...60),
                                    y: CGFloat.random(in: -25...25)
                                )
                                .opacity(0.3)
                                .blur(radius: 1)
                        }
                        
                        // グロー効果
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        colorPalette[currentColorIndex].opacity(0.7),
                                        colorPalette[(currentColorIndex + 1) % colorPalette.count].opacity(0.5)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .blur(radius: 0.5)
                    }
                )
                .opacity(showSubtext ? 1 : 0)
                .offset(y: showSubtext ? 0 : 20)
                .animation(
                    Animation.spring(response: 0.6, dampingFraction: 0.7).delay(1.2),
                    value: showSubtext
                )
                // 「アプリ起動中。。。」に変更したサブテキスト
//                Text("アプリ起動中" + String(repeating: "。", count: min(dotsAnimation + 1, 3)))
//                    .font(.system(size: 18, weight: .semibold, design: .rounded))
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 30)
//                    .padding(.vertical, 15)
//                    .background(
//                        RoundedRectangle(cornerRadius: 20)
//                            .fill(Color.black.opacity(0.2))
//                            .overlay(
//                                RoundedRectangle(cornerRadius: 20)
//                                    .stroke(
//                                        LinearGradient(
//                                            gradient: Gradient(colors: [
//                                                Color(hex: "FF10F0").opacity(0.5),
//                                                Color(hex: "6B10FF").opacity(0.3)
//                                            ]),
//                                            startPoint: .topLeading,
//                                            endPoint: .bottomTrailing
//                                        ),
//                                        lineWidth: 1.5
//                                    )
//                            )
//                            .blur(radius: 0.5)
//                    )
//                    .opacity(showSubtext ? 1 : 0)
//                    .offset(y: showSubtext ? 0 : 20)
//                    .animation(
//                        Animation.spring(response: 0.6, dampingFraction: 0.7).delay(1.2),
//                        value: showSubtext
//                    )
//                    .onReceive(timer) { _ in
//                        withAnimation {
//                            dotsAnimation = (dotsAnimation + 1) % 4
//                        }
//                    }
            }
            
            // エフェクト（星と光の粒子）
//            ZStack {
//                // 星
//                ForEach(0..<20) { i in
//                    StarShape()
//                        .fill(Color.white.opacity(Double.random(in: 0.4...0.7)))
//                        .frame(width: CGFloat.random(in: 3...7), height: CGFloat.random(in: 3...7))
//                        .position(
//                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
//                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
//                        )
//                        .scaleEffect(1.0 + 0.3 * sin(animationAmount + Double(i) * 0.2))
//                        .animation(
//                            Animation.easeInOut(duration: Double.random(in: 2.0...4.0))
//                                .repeatForever(autoreverses: true)
//                                .delay(Double.random(in: 0...2.0)),
//                            value: animationAmount
//                        )
//                }
//                
//                // 光の粒子
////                ForEach(0..<15) { i in
////                    Circle()
////                        .fill(
////                            LinearGradient(
////                                gradient: Gradient(colors: [
////                                    Color(hex: "FF10F0").opacity(Double.random(in: 0.3...0.7)),
////                                    Color(hex: "6B10FF").opacity(Double.random(in: 0.3...0.7))
////                                ]),
////                                startPoint: .topLeading,
////                                endPoint: .bottomTrailing
////                            )
////                        )
////                        .frame(width: CGFloat.random(in: 3...6), height: CGFloat.random(in: 3...6))
////                        .blur(radius: 1)
////                        .position(
////                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
////                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
////                        )
////                        .scaleEffect(1.0 + 0.4 * sin(animationAmount * 0.8 + Double(i) * 0.3))
////                        .animation(
////                            Animation.easeInOut(duration: Double.random(in: 3.0...5.0))
////                                .repeatForever(autoreverses: true)
////                                .delay(Double.random(in: 0...2.0)),
////                            value: animationAmount
////                        )
////                }
//            }
        }
        .onReceive(timer) { _ in
            // ドットのアニメーション
            withAnimation {
                dotsAnimation = (dotsAnimation + 1) % 6
                
                // 色も定期的に変更
                if dotsAnimation == 0 {
                    currentColorIndex = (currentColorIndex + 1) % colorPalette.count
                }
                
                // サブテキストの文字もパルス
                for i in 0..<7 {
                    if i == dotsAnimation {
                        subtextColors[i] = colorPalette[currentColorIndex]
                        subtextScales[i] = 1.2
                    } else {
                        subtextColors[i] = .white
                        subtextScales[i] = 1.0
                    }
                }
            }
        }
        .onAppear {
            // 可愛いテキストアニメーション
            for i in 0..<title.count {
                // ランダム値を事前計算
                let randomScale = CGFloat.random(in: 0.7...1.3)
                let randomRotation = Double.random(in: -15...15)
                let randomOffset = CGFloat.random(in: -30...30)
                let randomColor = colorPalette[i % colorPalette.count]
                
                // 各文字の初期状態を設定
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    // まずテキストを表示
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        textOpacity[i] = 1
                        textColors[i] = randomColor
                        textOffsets[i] = randomOffset
                        textRotations[i] = randomRotation
                        textScales[i] = randomScale
                    }
                    
                    // 次に通常位置に戻す
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                            textOffsets[i] = 0
                            textRotations[i] = 0
                            textScales[i] = 1.0
                        }
                    }
                    
                    // ゆらゆらアニメーションを開始
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(
                            Animation.easeInOut(duration: 2.0 + Double(i) * 0.2)
                                .repeatForever(autoreverses: true)
                        ) {
                            textScales[i] = 1.0 + CGFloat.random(in: 0.05...0.15)
                            textOffsets[i] = CGFloat.random(in: -5...5)
                            textRotations[i] = Double.random(in: -5...5)
                        }
                    }
                }
            }
            
            // サブテキストのアニメーション
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showSubtext = true
            }
            
            // 背景のアニメーション
            withAnimation(.easeInOut(duration: 1.0)) {
                animationAmount = 1.0
            }
            
            // ロゴアニメーション
            withAnimation(Animation.spring(response: 1.0, dampingFraction: 0.6, blendDuration: 1.0).repeatForever(autoreverses: true)) {
                logoScale = 1.0
            }
            
            // ロゴの回転アニメーション
            withAnimation(Animation.linear(duration: 10).repeatForever(autoreverses: false)) {
                logoRotation = 360
            }
        }
    }
}

struct ModernSpinner: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 外側のリング
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FF10F0").opacity(0.2),
                            Color(hex: "6B10FF").opacity(0.6),
                            Color(hex: "10FFFF").opacity(0.2)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 80, height: 80)
            
            // 動くリング
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FF10F0"),
                            Color(hex: "6B10FF"),
                            Color(hex: "10FFFF")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 80, height: 80)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)
            
            // 内側のリング
            Circle()
                .trim(from: 0.4, to: 0.9)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "10FFFF"),
                            Color(hex: "FF10F0")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                .rotationEffect(Angle(degrees: isAnimating ? -360 : 0))
                .animation(Animation.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                
            // 中央のグロー
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "FF10F0").opacity(0.7),
                            Color(hex: "FF10F0").opacity(0)
                        ]),
                        center: .center,
                        startRadius: 1,
                        endRadius: 20
                    )
                )
                .frame(width: 15, height: 15)
                .blur(radius: 3)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// 背景のパターン
struct BackgroundPatterns: View {
    var body: some View {
        ZStack {
            // 水平線
            ForEach(0..<10) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: 1)
                    .foregroundColor(.white.opacity(0.3))
                    .offset(y: CGFloat(i * 80) - 200)
            }
            
            // 垂直線
            ForEach(0..<10) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 1, height: UIScreen.main.bounds.height * 0.8)
                    .foregroundColor(.white.opacity(0.3))
                    .offset(x: CGFloat(i * 40) - 180)
            }
            
            // ドット
//            ForEach(0..<40) { i in
//                Circle()
//                    .frame(width: 3, height: 3)
//                    .foregroundColor(.white.opacity(0.4))
//                    .position(
//                        x: CGFloat(i % 8) * 50,
//                        y: CGFloat(i / 8) * 50
//                    )
//                    .offset(x: -140, y: -80)
//            }
        }
    }
}

#Preview {
    StartLoadingView()
}
