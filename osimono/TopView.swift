//
//  TopView.swift
//  osimono
//
//  Created by Apple on 2025/03/23.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct TopView: View {
    @State private var selectedOshiId: String = "default"
    @ObservedObject var tutorialManager = TutorialManager.shared
    @State private var showWelcomeScreen = false
    @State private var oshiChange: Bool = false
    
    var body: some View {
        ZStack{
            TabView {
                HStack{
//                    DiaryView(oshiId: selectedOshiId ?? "default")
                    ContentView(oshiChange: $oshiChange)
                }

                .tabItem {
                    Image(systemName: "rectangle.split.2x2")
                        .padding()
                    Text("推しログ")
                        .padding()
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
                HStack{
                    DiaryView(oshiId: selectedOshiId ?? "default")
//                    ContentView()
                }

                .tabItem {
                    Image(systemName: "book.pages")
                        .padding()
                    Text("日記")
                        .padding()
                }
                ZStack {
                    SettingsView(oshiChange: $oshiChange)
                }
                .tabItem {
                    Image(systemName: "gear")
                        .frame(width:1,height:1)
                    Text("設定")
                }
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

#Preview {
    TopView()
}
