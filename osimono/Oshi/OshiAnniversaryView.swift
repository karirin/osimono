//
//  OshiAnniversaryView.swift
//  osimono
//
//  Created by Apple on 2025/04/29.
//

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
                
                VStack(spacing: 15) {
                    Text(L10n.congratulations)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(L10n.anniversaryMessage(days))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    
                    Text(L10n.daysWithOshi(days))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                }
                
                // 日数に応じたメッセージを表示
                if days % 100 == 0 {
                    // 100日単位の節目
                    Text("推し活マスター！")
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
                    Text("継続は力なり！")
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
                    Text(L10n.close)
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
