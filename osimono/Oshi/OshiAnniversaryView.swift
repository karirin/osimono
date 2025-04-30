//
//  OshiAnniversaryView.swift
//  osimono
//
//  Created by Apple on 2025/04/29.
//

import SwiftUI
import Shimmer

struct ConfettiView1: View {
    @State private var isAnimating = false
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    let confettiCount = 100
    
    var body: some View {
        ZStack {
            ForEach(0..<confettiCount, id: \.self) { index in
                ConfettiPiece(color: colors[index % colors.count],
                              size: CGFloat.random(in: 5...15))
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let size: CGFloat
    
    // ランダムな形状を選択
    @State private var shape: ConfettiShape = ConfettiShape.allCases.randomElement() ?? .circle
    @State private var opacity: Double = 1.0
    
    // 噴水エフェクト用のプロパティ
    @State private var position: CGPoint = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
    @State private var finalPosition: CGPoint = .zero
    
    // ランダムな角度で飛び出す
    let angle: Double = Double.random(in: 0...360)
    let distance: CGFloat = CGFloat.random(in: 50...150)
    
    // 回転用
    @State private var rotation: Double = Double.random(in: 0...360)
    
    // スピードと遅延のランダム化
    let initialSpeed: Double = Double.random(in: 0.3...0.8)
    let fallSpeed: Double = Double.random(in: 1.0...2.0)
    let delay: Double = Double.random(in: 0...0.5)
    
    var body: some View {
        confettiShape
            .frame(width: size, height: size)
            .foregroundColor(color)
            .opacity(opacity)
            .position(position)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // 初期位置を画面中央に設定
                position = CGPoint(x: UIScreen.main.bounds.width / 2,
                                  y: UIScreen.main.bounds.height / 2)
                
                // 角度に基づいた初期の飛び出し方向を計算
                let radians = angle * .pi / 180
                let xDistance = cos(radians) * distance
                let yDistance = sin(radians) * distance
                
                // まず上方向に飛び出す最初のアニメーション
                withAnimation(Animation.easeOut(duration: initialSpeed).delay(delay)) {
                    // 角度に基づいて飛び出す
                    position = CGPoint(
                        x: UIScreen.main.bounds.width / 2 + xDistance,
                        y: UIScreen.main.bounds.height / 2 - abs(yDistance) // 必ず上方向に
                    )
                    rotation += 180
                }
                
                // 次に重力で落下するアニメーション
                withAnimation(Animation.timingCurve(0.2, 0.8, 0.8, 1.0, duration: fallSpeed)
                    .delay(delay + initialSpeed)) {
                    // 下方向に落ちる
                    position = CGPoint(
                        x: position.x + CGFloat.random(in: -20...20), // 少しランダムに揺れる
                        y: UIScreen.main.bounds.height + 50 // 画面外まで落下
                    )
                    rotation += 180
                }
                
                // フェードアウトのアニメーション (落下中に徐々に消える)
                let fadeDelay = delay + initialSpeed + (fallSpeed * 0.3)
                withAnimation(Animation.linear(duration: fallSpeed * 0.7).delay(fadeDelay)) {
                    opacity = 0
                }
            }
    }
    
    @ViewBuilder
    var confettiShape: some View {
        switch shape {
        case .circle:
            Circle()
        case .triangle:
            Triangle()
        case .square:
            Rectangle()
        case .star:
            Star(corners: 5, smoothness: 0.45)
        case .heart:
            Heart()
        }
    }
}

// 紙吹雪の形状
enum ConfettiShape: CaseIterable {
    case circle, triangle, square, star, heart
}

// 星形の形状
struct Star: Shape {
    let corners: Int
    let smoothness: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard corners >= 2 else { return Path() }
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * smoothness
        
        let path = Path { path in
            let adjustment = CGFloat.pi / 2
            let step = CGFloat.pi * 2 / CGFloat(corners) / 2
            
            let points: [CGPoint] = (0..<(2 * corners)).map { i in
                let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
                let angle = CGFloat(i) * step - adjustment
                let x = center.x + cos(angle) * radius
                let y = center.y + sin(angle) * radius
                return CGPoint(x: x, y: y)
            }
            
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        
        return path
    }
}

// ハート形の形状
struct Heart: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        
        let path = Path { p in
            p.move(to: CGPoint(x: width/2, y: height))
            p.addCurve(to: CGPoint(x: 0, y: height/4),
                      control1: CGPoint(x: width, y: height*3/4),
                      control2: CGPoint(x: width/2, y: 0))
            p.addCurve(to: CGPoint(x: width/2, y: height),
                      control1: CGPoint(x: -width/2, y: 0),
                      control2: CGPoint(x: 0, y: height*3/4))
        }
        
        return path
    }
}

// 以下のコードをOshiAnniversaryView.swiftに置き換えてください
// OshiAnniversaryView.swift

import SwiftUI
import Shimmer
import Confetti

struct OshiAnniversaryView: View {
    @Binding var isShowing: Bool
    var days: Int
    var oshiName: String
    var imageUrl: String?
    
    // 紙吹雪アニメーションの状態
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }
            
            VStack(spacing: 20) {
                // ヘッダー
                if let imageUrlString = imageUrl, let url = URL(string: imageUrlString) {
                    // 推しのアイコン画像を表示
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.pink, lineWidth: 3)
                                )
                                .shadow(color: Color.pink.opacity(0.5), radius: 10)
                                .padding(.top, 30)
                        default:
                            ZStack{
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                                    .padding(5)
                                    .shimmering(active: true)
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.white)
                            }.padding(.top)
                        }
                    }
                } else {
                    ZStack{
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 3)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                            .padding(5)
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.white)
                    }.padding(.top)
                }
                
                Text("🎉 おめでとう！ 🎉")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("\(oshiName)を推し続けて")
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text("\(days)日")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.pink)
                    .padding(.vertical, 10)
                
                Text("これからも推し活を楽しんでください！")
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 日数に応じたメッセージを表示
                if days % 100 == 0 {
                    // 100日単位の節目
                    Text("推し活マスターへの道！")
                        .foregroundColor(.yellow)
                        .font(.callout)
                        .italic()
                } else if days % 50 == 0 {
                    // 50日単位の節目
                    Text("立派な推しオタクの証♪")
                        .foregroundColor(.yellow)
                        .font(.callout)
                        .italic()
                } else if days % 30 == 0 {
                    // 30日(約1ヶ月)単位の節目
                    Text("推し活1ヶ月おめでとう！")
                        .foregroundColor(.yellow)
                        .font(.callout)
                        .italic()
                } else {
                    // その他の10日単位の節目
                    Text("継続は力なり！推し活頑張ってます！")
                        .foregroundColor(.yellow)
                        .font(.callout)
                        .italic()
                }
                
                Button(action: {
                    generateHapticFeedback()
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }) {
                    Text("閉じる")
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .shadow(color: Color.pink.opacity(0.5), radius: 5)
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .shadow(color: Color.pink.opacity(0.5), radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(LinearGradient(
                        gradient: Gradient(colors: [Color.pink, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: 3)
            )
            .padding()
            // 紙吹雪アニメーション
            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            generateHapticFeedback()
            // 少し遅延させてから紙吹雪アニメーションを開始
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                generateHapticFeedback()
                showConfetti = true
            }
        }
    }
    
    // 触覚フィードバック生成
    func generateHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// 2. 日付計算ユーティリティ
extension Date {
    static func daysBetween(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return components.day ?? 0
    }
}

#Preview {
    OshiAnniversaryView(isShowing: .constant(false), days: 10, oshiName: "アイドル〇〇ちゃん")
}
