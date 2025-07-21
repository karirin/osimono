//
//  TestView.swift
//  osimono
//
//  Created by Apple on 2025/04/27.
//

import SwiftUI
import Foundation

// チュートリアルのステップを定義する列挙型
enum TutorialStep: Int, CaseIterable {
    case welcome = 0
    case selectOshi
    case addOshi
    case createPost
    case categories
    case message
    case completed
    
    var title: String {
        switch self {
        case .welcome: return "ようこそ"
        case .selectOshi: return "推しを登録"
        case .addOshi: return "推しを追加"
        case .createPost: return "聖地巡礼"
        case .categories: return "チャット"
        case .message: return "グループチャット"
        case .completed: return "完了"
        }
    }
    
    var message: String {
        switch self {
        case .welcome:
            return "「推しログ」へようこそ！\nあなたの推し活を記録するアプリです。\n基本的な使い方を説明します。"
        case .selectOshi:
            return "こちらから推しを登録できます。\nアイコン、背景、名前を保存しましょう。"
        case .addOshi:
            return "プラスボタンで推しに関する「グッズ」「聖地巡礼」を記録することができます。"
        case .createPost:
            return "登録した推しの聖地巡礼をマップで見ることができます。"
        case .categories:
            return "推しとチャットでやり取りすることができます。記録した内容にメッセージを送ってきてくれることも！"
        case .message:
            return "登録した複数の推しとグループチャットをすることができます。"
        case .completed:
            return "これでチュートリアルは完了です！\nあなたの推し活ライフをお楽しみください！"
        }
    }
    
    var iconName: String {
        switch self {
        case .welcome: return "heart.circle.fill"
        case .selectOshi: return "person.crop.circle.fill"
        case .addOshi: return "plus.circle.fill"
        case .createPost: return "mappin.and.ellipse"
        case .categories: return "message.fill"
        case .message: return "person.2"
        case .completed: return "checkmark.circle.fill"
        }
    }
    
    var highlightPosition: CGPoint {
        switch self {
        case .welcome: return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        case .selectOshi: return CGPoint(x: UIScreen.main.bounds.midX, y: isSmallDevice() ? 85 : isiPhone12Or13() ? 110 : 125)
        case .addOshi: return CGPoint(x: UIScreen.main.bounds.width - 44, y: isSmallDevice() ? UIScreen.main.bounds.height - 94 : UIScreen.main.bounds.height - 128) // Updated to bottom right
        case .createPost: return CGPoint(x: UIScreen.main.bounds.width * 0.3, y: isSmallDevice() ? UIScreen.main.bounds.height - 25 : UIScreen.main.bounds.height - 55)
        case .categories: return CGPoint(x: UIScreen.main.bounds.width * 0.5, y: isSmallDevice() ? UIScreen.main.bounds.height - 25 : UIScreen.main.bounds.height - 55)
        case .message: return CGPoint(x: UIScreen.main.bounds.width * 0.7, y: isSmallDevice() ? UIScreen.main.bounds.height - 25 : UIScreen.main.bounds.height - 55)
        case .completed: return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        }
    }
    
    var messagePosition: EdgeInsets {
        switch self {
        case .welcome, .completed:
            return EdgeInsets(top: 0, leading: 24, bottom: 40, trailing: 24) // Bottom centered
        case .selectOshi:
            return EdgeInsets(top: 0, leading: 24, bottom: 40, trailing: 24) // Bottom centered
        case .addOshi:
            // Position message in the center of the screen, above the plus button
            return EdgeInsets(top: 0, leading: 24, bottom: 150, trailing: 24)
        case .createPost, .categories, .message:
            return EdgeInsets(top: 0, leading: 24, bottom: 80, trailing: 24) // Bottom centered
        }
    }
    
    var highlightSize: CGFloat {
        switch self {
        case .welcome: return 0 // 全画面ハイライト
        case .selectOshi: return 150
        case .addOshi: return 80
        case .createPost: return 80
        case .categories: return 80
        case .message: return 80
        case .completed: return 0 // 全画面ハイライト
        }
    }
}

// 設定から読み取り/書き込みするためのクラス
class TutorialManager: ObservableObject {
    @Published var isShowingTutorial: Bool = false
    @Published var currentStep: TutorialStep = .welcome
//    @Published var currentStep: TutorialStep = .message
    
    static let shared = TutorialManager()
    
    private init() {
        // UserDefaultsからチュートリアル表示済みかどうかを読み込む
        isShowingTutorial = !UserDefaults.standard.bool(forKey: "tutorialCompleted")
    }
    
    func nextStep() {
        if let nextIndex = TutorialStep.allCases.firstIndex(of: currentStep)?.advanced(by: 1),
           let nextStep = TutorialStep(rawValue: nextIndex) {
            currentStep = nextStep
        } else {
            // 最後のステップだった場合はチュートリアルを終了
            completeTutorial()
        }
    }
    
    func prevStep() {
        if let prevIndex = TutorialStep.allCases.firstIndex(of: currentStep)?.advanced(by: -1),
           let prevStep = TutorialStep(rawValue: prevIndex) {
            currentStep = prevStep
        }
    }
    
    func startTutorial() {
        isShowingTutorial = true
        currentStep = .welcome
        //        currentStep = .addOshi
    }
    
    func completeTutorial() {
        isShowingTutorial = false
        // UserDefaultsにチュートリアル完了フラグを保存
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
    }
    
    func skipTutorial() {
        completeTutorial()
    }
}

// チュートリアルオーバーレイビュー
struct TutorialOverlayView: View {
    @ObservedObject var tutorialManager = TutorialManager.shared
    let closeAction: () -> Void
    
    // Haptic feedback generator
    func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .animation(.easeInOut, value: tutorialManager.currentStep)
                .overlay {
                    if tutorialManager.currentStep != .welcome &&
                        tutorialManager.currentStep != .completed {
                        Circle()
                            .frame(width: tutorialManager.currentStep.highlightSize,
                                   height: tutorialManager.currentStep.highlightSize)
                            .position(tutorialManager.currentStep.highlightPosition)
                            .animation(.easeInOut, value: tutorialManager.currentStep)
                            .blendMode(.destinationOut)
                    }
                }
                .ignoresSafeArea()
                .compositingGroup()
                .background(.clear)
            
            // Tutorial content
            VStack {
                Spacer()
                
                VStack(spacing: 15) {
                    // Icon and title
                    HStack {
                        Image(systemName: tutorialManager.currentStep.iconName)
                            .font(.system(size: 28))
                            .foregroundColor(Color(.systemPink))
                        
                        Text(tutorialManager.currentStep.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                    
                    // Message
                    Text(tutorialManager.currentStep.message)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    
                    // Buttons
                    HStack {
                        // Skip / Back button
                        if tutorialManager.currentStep == .welcome {
                            Button(action: {
                                generateHapticFeedback()
                                tutorialManager.skipTutorial()
                                closeAction()
                            }) {
                                Text("スキップ")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                        } else if tutorialManager.currentStep != .completed {
                            Button(action: {
                                generateHapticFeedback()
                                tutorialManager.prevStep()
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("戻る")
                                }
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        Spacer()
                        
                        // Next / Complete button
                        Button(action: {
                            generateHapticFeedback()
                            if tutorialManager.currentStep == .completed {
                                tutorialManager.completeTutorial()
                                closeAction()
                            } else {
                                tutorialManager.nextStep()
                            }
                        }) {
                            HStack {
                                Text(tutorialManager.currentStep == .completed ? "始める" : "次へ")
                                if tutorialManager.currentStep != .completed {
                                    Image(systemName: "chevron.right")
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color(.systemPink))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.black).opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.systemPink).opacity(0.3), lineWidth: 1)
                )
                .padding(tutorialManager.currentStep.messagePosition) // Use dynamic positioning
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: tutorialManager.isShowingTutorial)
    }
}

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
                    
                    Text("osimono")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // 説明文
                Text("あなたの推し活を記録し、思い出を\n大切に残すためのアプリです")
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
                        Text("チュートリアルを見る")
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
                        Text("スキップして始める")
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
