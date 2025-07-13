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
    @State private var observerHandle: DatabaseHandle? // 監視ハンドルを追加
    
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
                            OshiChatListView()
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
        .onDisappear {
            // メモリリーク防止のために監視を解除
            removeObserver()
        }
    }
    
    // 監視ハンドル削除メソッドを追加
    private func removeObserver() {
        guard let userID = Auth.auth().currentUser?.uid,
              let handle = observerHandle else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.removeObserver(withHandle: handle)
        observerHandle = nil
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
                        
                        // 性格関連の属性も追加
                        let personality = value["personality"] as? String
                        let speakingStyle = value["speaking_style"] as? String
                        let birthday = value["birthday"] as? String
                        let height = value["height"] as? Int
                        let favoriteColor = value["favorite_color"] as? String
                        let favoriteFood = value["favorite_food"] as? String
                        let dislikedFood = value["disliked_food"] as? String
                        let hometown = value["hometown"] as? String
                        let interests = value["interests"] as? [String]
                        let gender = value["gender"] as? String ?? "男性"
                        let userNickname = value["user_nickname"] as? String
                        
                        let oshi = Oshi(
                            id: id,
                            name: name,
                            imageUrl: imageUrl,
                            backgroundImageUrl: backgroundImageUrl,
                            memo: memo,
                            createdAt: createdAt,
                            personality: personality,
                            interests: interests,
                            speaking_style: speakingStyle,
                            birthday: birthday,
                            height: height,
                            favorite_color: favoriteColor,
                            favorite_food: favoriteFood,
                            disliked_food: dislikedFood,
                            hometown: hometown,
                            gender: gender,
                            user_nickname: userNickname
                        )
                        newOshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.hasLoadedProfileImages = true
                
                print("✅ 推しリスト取得完了: \(newOshis.count)人")
                
                // 推しリストが取得できたら、選択中の推しを設定
                if !newOshis.isEmpty {
                    // 現在のselectedOshiIdがデフォルト値の場合は、最初の推しを選択
                    if self.selectedOshiId == "default" {
                        self.loadSelectedOshiFromFirebase(withFallback: newOshis.first!)
                    } else {
                        // selectedOshiIdがある場合は、該当する推しを検索
                        if let matchingOshi = newOshis.first(where: { $0.id == self.selectedOshiId }) {
                            self.updateSelectedOshi(matchingOshi)
                        } else {
                            // 該当する推しがない場合は最初の推しを選択
                            self.updateSelectedOshi(newOshis.first!)
                        }
                    }
                }
            }
        }
    }
    
    // 選択中の推しをFirebaseから取得し、フォールバックも設定
    func loadSelectedOshiFromFirebase(withFallback fallbackOshi: Oshi) {
        guard let userID = Auth.auth().currentUser?.uid else {
            // ユーザーIDがない場合はフォールバックを使用
            updateSelectedOshi(fallbackOshi)
            return
        }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedOshiId = snapshot.value as? String,
               selectedOshiId != "default",
               let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                // Firebaseに保存されている推しIDに該当する推しが見つかった場合
                DispatchQueue.main.async {
                    print("✅ Firebase保存済み推し: \(oshi.name)")
                    self.updateSelectedOshi(oshi)
                }
            } else {
                // Firebaseに保存されていないか、該当する推しがない場合はフォールバックを使用
                DispatchQueue.main.async {
                    print("✅ フォールバック推し: \(fallbackOshi.name)")
                    self.updateSelectedOshi(fallbackOshi)
                    // Firebaseにも保存
                    self.saveSelectedOshiId(fallbackOshi.id)
                }
            }
        }
    }
    
    // 選択中の推しを更新する共通メソッド
    func updateSelectedOshi(_ oshi: Oshi) {
        self.selectedOshi = oshi
        self.selectedOshiId = oshi.id
        self.viewModel = OshiViewModel(oshi: oshi)
        print("🎯 推し選択完了: \(oshi.name) (ID: \(oshi.id))")
    }
    
    // 推しIDをFirebaseに保存
    func saveSelectedOshiId(_ oshiId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedOshiId": oshiId]) { error, _ in
            if let error = error {
                print("❌ 推しID保存エラー: \(error.localizedDescription)")
            } else {
                print("✅ 推しID保存成功: \(oshiId)")
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
                        self.updateSelectedOshi(oshi)
                    }
                }
            }
        }
    }
    
    // 修正された observeSelectedOshiId メソッド
    func observeSelectedOshiId() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        
        // 既存の監視を解除（重複監視を防ぐ）
        removeObserver()
        
        // 再度監視を設定（selectedOshiIdのみを監視）
        observerHandle = dbRef.child("selectedOshiId").observe(.value) { snapshot in
            if let selectedOshiId = snapshot.value as? String {
                DispatchQueue.main.async {
                    print("🔄 selectedOshiId変更検知: \(selectedOshiId)")
                    
                    // 現在のIDと異なる場合のみ更新
                    if self.selectedOshiId != selectedOshiId {
                        self.selectedOshiId = selectedOshiId
                        
                        // 選択中の推しIDに対応する推しオブジェクトを取得
                        if let oshi = self.oshiList.first(where: { $0.id == selectedOshiId }) {
                            self.updateSelectedOshi(oshi)
                            
                            // タブビューのデータ更新をトリガー
                            DispatchQueue.main.async {
                                self.oshiChange.toggle()
                            }
                        } else {
                            // 対応する推しが見つからない場合は再取得
                            print("⚠️ 対応する推しが見つからないため、推しリストを再取得します")
                            self.fetchOshiList()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TopView()
}
