//
//  AnimatedRewardCompletedModal.swift
//  osimono
//
//  Created by Apple on 2025/05/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct AnimatedRewardCompletedModal: View {
    @Binding var isPresented: Bool
    let rewardAmount: Int
    @State private var showCheckmark = false
    @State private var showText = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                // アニメーション付きアイコン
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(showCheckmark ? 1.0 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showCheckmark)
                    
                    Image(systemName: "gift.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                        .scaleEffect(showCheckmark ? 1.0 : 0.1)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: showCheckmark)
                }
                
                // テキストアニメーション - 多言語化対応
                if showText {
                    VStack(spacing: 8) {
                        Text(L10n.rewardObtained)
                            .font(.title2)
                            .fontWeight(.bold)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        VStack(spacing: 4) {
                            Text(L10n.thankYouForWatching)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text(L10n.toTheEnd)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text(L10n.messagesAddedFormat(rewardAmount))
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            
                            Text(L10n.haveBeenAdded)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.easeOut(duration: 0.5).delay(0.5), value: showText)
                }
                
                // ボタン - 多言語化対応
                if showText {
                    Button(action: {
                        generateHapticFeedback()
                        isPresented = false
                    }) {
                        Text(L10n.ok)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3).delay(0.8), value: showText)
                }
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(40)
        }
        .onAppear {
            showCheckmark = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showText = true
            }
        }
    }
}
