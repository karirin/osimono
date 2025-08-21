//
//  ApologyModalView.swift
//  osimono
//
//  Created by Apple on 2025/07/11.
//

import SwiftUI

struct ApologyModalView: View {
    @Binding var isPresented: Bool
    let primaryColor = Color(.systemPink)
    
    // UserDefaultsのキー
    private let apologyShownKey = "ai_message_apology_shown_v1"
    
    var body: some View {
        ZStack {
            // 半透明の背景
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 20) {
                // アイコン
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                // タイトル
                Text(L10n.apologyTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // メッセージ
                VStack(spacing: 12) {
                    Text(L10n.apologyMessage1)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(L10n.apologyMessage2)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(L10n.apologyMessage3)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(L10n.apologyMessage4)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    
                    Text(L10n.apologyMessage5)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                
                // 閉じるボタン
                Button(action: {
                    generateHapticFeedback()
                    // 表示済みフラグを保存
                    UserDefaults.standard.set(true, forKey: apologyShownKey)
                    withAnimation(.spring()) {
                        isPresented = false
                    }
                }) {
                    Text(L10n.confirm)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryColor)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.8)))
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // お詫びを表示すべきかチェックする静的メソッド
    static func shouldShowApology() -> Bool {
        let apologyShownKey = "ai_message_apology_shown_v1"
        return !UserDefaults.standard.bool(forKey: apologyShownKey)
    }
}
