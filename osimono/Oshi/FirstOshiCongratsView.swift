//
//  FirstOshiCongratsView.swift
//  osimono
//
//  Created by Apple on 2025/05/03.
//

import SwiftUI
import Confetti

struct FirstOshiCongratsView: View {
    @Binding var isShowing: Bool
    @State private var isAnimating = false
    var imageUrl: String?
    @State private var showConfetti = false
    
    // カラーテーマ（推しのジャンルによって変更可能）
    let primaryColor = Color(.systemPink)
    let secondaryColor = Color(.systemPurple)
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                gradient: Gradient(colors: [primaryColor.opacity(0.1), secondaryColor.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
                isShowing = false
            }
            
            VStack(spacing: 24) {
                // ヘッダー（アニメーション付き）
                Text("初めての推し登録おめでとう！")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(.center)
                
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
                
                // メッセージ
                VStack(spacing: 12) {
                    Text("あなたの推し活第一歩を踏み出しました！")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                    
                    Text("これからの素敵な思い出を一緒に記録していきましょう✨")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
                
                // 閉じるボタン（グラデーション付き）
                Button(action: {
                    generateHapticFeedback()
                    isShowing = false
                }) {
                    Text("推し活をはじめる")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryColor, secondaryColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: primaryColor.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
            }
            .padding()
            .padding(.vertical)
            .background(Color.white.opacity(0.95))
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
            
            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            withAnimation {
                isAnimating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    generateHapticFeedback()
                    showConfetti = true
                }
            }
        }
    }
    
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// 改良版ステップ表示用の補助ビュー
struct ImprovedStepView: View {
    var icon: String
    var title: String
    var description: String
    var primaryColor: Color
    var secondaryColor: Color
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            // 各機能へ移動する処理
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            isHovered.toggle()
        }) {
            HStack(spacing: 15) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryColor.opacity(0.2), secondaryColor.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(primaryColor)
                }
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isHovered)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(primaryColor.opacity(0.5))
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// プレビュー
struct FirstOshiCongratsView_Previews: PreviewProvider {
    static var previews: some View {
        FirstOshiCongratsView(isShowing: .constant(false))
    }
}
