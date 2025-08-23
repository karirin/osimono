//
//  OshiAlertView.swift
//  osimono
//
//  Created by Apple on 2025/04/29.
//

import SwiftUI

struct OshiAlertView: View {
    let title: String
    let message: String
    let buttonText: String
    let action: () -> Void
    @Binding var isShowing: Bool
    
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }
            
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(primaryColor)
                
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                
                Button(action: {
                    generateHapticFeedback()
                    action()
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }) {
                    Text(buttonText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(primaryColor)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
                
                Button(action: {
                    generateHapticFeedback()
                    withAnimation(.spring()) {
                        isShowing = false
                    }
                }) {
                    Text(L10n.cancel)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
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
