//
//  OshiAlertView.swift
//  osimono
//
//  Created by Apple on 2025/04/29.
//

import SwiftUI

struct OshiAlertView: View {
    var title: String
    var message: String
    var buttonText: String
    var action: () -> Void
    @Binding var isShowing: Bool
    
    // 色の定義 - 推し活向けカラー
    let primaryColor = Color(.systemPink) // ピンク
    let accentColor = Color(.purple) // 紫
    
    var body: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }
            
            // アラートカード
            VStack(spacing: 20) {
                // アイコン
                Image(systemName: "person.crop.circle.badge.plus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(primaryColor)
                    .padding(.top, 30)
                
                // タイトル
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                
                // メッセージ
                Text(message)
                    .font(.system(size: 16))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                
                // メインボタン
                Button(action: {
                    generateHapticFeedback()
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                    action()
                }) {
                    Text(buttonText)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryColor, accentColor]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 40)
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    // 触覚フィードバック
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    OshiAlertView(
        title: "推しを登録しよう！",
        message: "推しグッズやSNS投稿を記録する前に、まずは推しを登録してください。",
        buttonText: "推しを登録する",
        action: { },
        isShowing: .constant(true)
    )
}
