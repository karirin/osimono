//
//  TestView.swift
//  osimono
//
//  Created by Apple on 2025/04/27.
//

import SwiftUI
import Foundation

// ContentViewの修正（既存のContentViewに追加）
struct ContentViewWithTutorial: View {
    @ObservedObject var tutorialManager = TutorialManager.shared
    @State private var showWelcomeScreen = false
    
    var body: some View {
        ZStack {
            // 元のContentView
            TopView()
            
            // チュートリアルオーバーレイを条件付きで表示
            if tutorialManager.isShowingTutorial {
                TutorialOverlayView(closeAction: {
                    withAnimation {
                        tutorialManager.isShowingTutorial = false
                    }
                })
                .zIndex(100) // 最前面に表示
            }
        }
        .onAppear {
            // 初回起動時のみチュートリアルを表示
            //            if !UserDefaults.standard.bool(forKey: "appLaunchedBefore") {
            //                UserDefaults.standard.set(false, forKey: "tutorialCompleted")
            //                UserDefaults.standard.set(true, forKey: "appLaunchedBefore")
            
            // アプリの起動アニメーションを待ってからチュートリアルを表示
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    tutorialManager.startTutorial()
                }
            }
            //            }
        }
    }
}

// ウェルカムスクリーン（オプション - 初回起動時に表示）
struct WelcomeScreen: View {
    @Binding var isPresented: Bool
    @ObservedObject var tutorialManager = TutorialManager.shared
    let primaryColor = Color(.systemPink)
    
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // ロゴ
                VStack(spacing: 10) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(primaryColor)
                    
                    Text(L10n.appTitle)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // 説明文
                Text(L10n.welcomeAppDescription)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding()
                
                Spacer()
                
                // ボタン
                VStack(spacing: 16) {
                    Button(action: {
                        generateHapticFeedback()
                        isPresented = false
                        tutorialManager.startTutorial()
                    }) {
                        Text(L10n.welcomeViewTutorial)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(primaryColor)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        generateHapticFeedback()
                        isPresented = false
                        tutorialManager.skipTutorial()
                    }) {
                        Text(L10n.welcomeSkipAndStart)
                            .font(.headline)
                            .foregroundColor(primaryColor)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
            .padding()
        }
    }
}

#Preview{
//    ContentViewWithTutorial()
    TopView()
}
