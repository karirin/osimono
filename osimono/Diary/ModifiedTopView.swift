//
//  ModifiedTopView.swift
//  osimono
//
//  Created by Apple on 2025/05/04.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

struct ModifiedTopView: View {
    @State private var selectedOshiId: String = "default"
    @ObservedObject var tutorialManager = TutorialManager.shared
    @State private var showWelcomeScreen = false
    @State private var helpFlag: Bool = false
    
    var body: some View {
        ZStack{
            TabView {
                HStack{
                    ContentView()
                }
                .tabItem {
                    Image(systemName: "rectangle.split.2x2")
                        .padding()
                    Text("推しログ")
                        .padding()
                }
                
                ZStack {
                    DiaryTabView()
                }
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("推し日記")
                }
                
                ZStack {
                    MapView(oshiId: selectedOshiId ?? "default")
                }
                .tabItem {
                    Image(systemName: "mappin.and.ellipse")
                    Text("聖地巡礼")
                }
                
                ZStack {
                    TimelineView(oshiId: selectedOshiId ?? "default")
                }
                .tabItem {
                    Image(systemName: "calendar.day.timeline.left")
                        .frame(width:1,height:1)
                    Text("タイムライン")
                }
                
                ZStack {
                    SettingsView()
                }
                .tabItem {
                    Image(systemName: "gear")
                        .frame(width:1,height:1)
                    Text("設定")
                }
            }
            if helpFlag {
                HelpModalView(isPresented: $helpFlag)
            }
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
        .onAppear{
            observeSelectedOshiId()
            if !UserDefaults.standard.bool(forKey: "appLaunchedBefore") {
                UserDefaults.standard.set(false, forKey: "tutorialCompleted")
                UserDefaults.standard.set(true, forKey: "appLaunchedBefore")
                
                // アプリの起動アニメーションを待ってからチュートリアルを表示
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        tutorialManager.startTutorial()
                    }
                }
            }
            AuthManager().fetchUserFlag { userFlag, error in
                if let error = error {
                    print(error.localizedDescription)
                } else if let userFlag = userFlag {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if userFlag == 0 {
                            executeProcessEveryfifTimes()
                        }
                    }
                }
            }
        }
    }
    
    func executeProcessEveryfifTimes() {
        // UserDefaultsからカウンターを取得
        let count = UserDefaults.standard.integer(forKey: "launchHelpCount") + 1
        
        // カウンターを更新
        UserDefaults.standard.set(count, forKey: "launchHelpCount")
        
        if count % 15 == 0 {
            helpFlag = true
        }
    }
    
    func observeSelectedOshiId() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            if let selectedOshiId = value["selectedOshiId"] as? String {
                DispatchQueue.main.async {
                    self.selectedOshiId = selectedOshiId
                }
            }
        }
    }
}
