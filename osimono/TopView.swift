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
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshi: Oshi? = nil
    @State private var viewModel: OshiViewModel? = nil
    @State private var showAddOshiFlag = false
    
    @State private var hasLoadedProfileImages = false
    @State private var cachedImageURLs: [String: String] = [:] // oshiId: imageUrl
    @State private var initialLoadCompleted = false
    let dummyOshi = Oshi(
        id: "1",
        name: "テストの推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: nil,
        createdAt: Date().timeIntervalSince1970
    )
    var body: some View {
        ZStack{
            TabView {
                HStack{
                    ContentView(oshiChange: $oshiChange)
                        .id(selectedOshiId)
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
                ZStack {
                    if let vm = viewModel {
                        if oshiList.isEmpty {
                            // 推しが登録されていない場合
                            OshiAlertView(
                                title: "推しを登録しよう！",
                                message: "推しグッズやSNS投稿を記録する前に、まずは推しを登録してください。",
                                buttonText: "推しを登録する",
                                action: {
                                    showAddOshiFlag = true
                                },
                                isShowing: $showAddOshiFlag
                            )
                            .transition(.opacity)
                        } else if vm.selectedOshi.id != "1" { // ダミー推しではない場合
                            OshiAIChatView(viewModel: vm, oshiItem: nil, showBackButton: false, isEmbedded: false)
                                .id(vm.selectedOshi.id) // 推しが変わったら再生成
                        }
                    }else{
                        // 推しが登録されていない場合
                        OshiAlertView(
                            title: "推しを登録しよう！",
                            message: "推しグッズやSNS投稿を記録する前に、まずは推しを登録してください。",
                            buttonText: "推しを登録する",
                            action: {
                                showAddOshiFlag = true
                            },
                            isShowing: $showAddOshiFlag
                        )
                        .transition(.opacity)
                    }
                }
                .tabItem {
                    Image(systemName: "message")
                        .frame(width:1,height:1)
                    Text("チャット")
                }
//                HStack{
//                    DiaryView(oshiId: selectedOshiId ?? "default")
////                    ContentView()
//                }
//
//                .tabItem {
//                    Image(systemName: "book.pages")
//                        .padding()
//                    Text("日記")
//                        .padding()
//                }
                ZStack {
//                    SettingsView(oshiChange: $oshiChange)
                    SubscriptionSettingsView()
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
        .fullScreenCover(isPresented: $showAddOshiFlag, onDismiss: {
            // 推し追加後に確実にデータを再取得
            fetchOshiList()
            
            // 少し遅らせてselectedOshiIdの監視を確実に再初期化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                observeSelectedOshiId()
                
                // タブビューのデータ更新をトリガー
                oshiChange.toggle()
            }
        }) {
            AddOshiView()
        }
        .onAppear {
            if !initialLoadCompleted {
                // 初回のみ完全にロード
                fetchOshiList()
                observeSelectedOshiId()
                initialLoadCompleted = true
                
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
            } else if oshiChange {
                // 推し変更されたときのみ再ロード
                fetchOshiList()
                oshiChange = false
            }
        }
    }
    
    func fetchOshiList() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let ref = Database.database().reference().child("oshis").child(userId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            var newOshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot {
                    if let value = childSnapshot.value as? [String: Any] {
                        let id = childSnapshot.key
                        let name = value["name"] as? String ?? "名前なし"
                        
                        // 画像URLは結果的にキャッシュする
                        let imageUrl = value["imageUrl"] as? String
                        if let imageUrl = imageUrl {
                            self.cachedImageURLs[id] = imageUrl
                        }
                        
                        let backgroundImageUrl = value["backgroundImageUrl"] as? String
                        let memo = value["memo"] as? String
                        let createdAt = value["createdAt"] as? TimeInterval
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl,
                            memo: memo,
                            createdAt: createdAt
                        )
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.hasLoadedProfileImages = true
                
                // 推しリストが取得できたら、選択中の推しを取得または設定
                if !newOshis.isEmpty {
                    // 選択中の推しIDがあれば、それを使う
                    if self.selectedOshiId != "default" {
                        self.loadSelectedOshi()
                    }
                    // まだ推しが選択されていない場合、最初の推しを選択
                    else if let firstOshi = newOshis.first, self.selectedOshi == nil {
                        self.selectedOshi = firstOshi
                        self.viewModel = OshiViewModel(oshi: firstOshi)
                        
                        // ユーザーのselectedOshiIdも更新しておく
                        if let userId = Auth.auth().currentUser?.uid {
                            let userRef = Database.database().reference().child("users").child(userId)
                            userRef.updateChildValues(["selectedOshiId": firstOshi.id])
                        }
                    }
                }
            }
        }
    }
    
    func loadSelectedOshi() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            if let selectedOshiId = value["selectedOshiId"] as? String {
                // 選択中の推しIDが存在する場合、oshiListから該当する推しを検索して設定
                if let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                    DispatchQueue.main.async {
                        self.selectedOshi = oshi
                        // 選択された推しでviewModelを更新
                        self.viewModel = OshiViewModel(oshi: oshi)
                    }
                }
            }
        }
    }
    
    func observeSelectedOshiId() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        
        // 既存の監視を解除（重複監視を防ぐ）
        dbRef.removeAllObservers()
        
        // 再度監視を設定
        dbRef.observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return }
            
            if let selectedOshiId = value["selectedOshiId"] as? String {
                
                DispatchQueue.main.async {
                    self.selectedOshiId = selectedOshiId
                    
                    // 選択中の推しIDに対応する推しオブジェクトを取得
                    if let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                        self.selectedOshi = oshi
                        // 選択された推しでviewModelを更新
                        self.viewModel = OshiViewModel(oshi: oshi)
                        
                        DispatchQueue.main.async {
                            self.oshiChange = !self.oshiChange
                        }
                    } else {
                        // 対応する推しが見つからない場合は再取得
                        self.fetchOshiList()
                    }
                }
            }
        }
    }
}

#Preview {
    TopView()
}
