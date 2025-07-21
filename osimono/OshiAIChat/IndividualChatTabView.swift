//
//  IndividualChatTabView.swift
//  osimono
//
//  個人チャット専用のタブビュー
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

struct IndividualChatTabView: View {
    @StateObject private var coordinator = OshiChatCoordinator.shared
    @State private var searchText = ""
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshiId: String = ""
    @State private var isLoading = true
    @State private var unreadCounts: [String: Int] = [:]
    @State private var lastMessages: [String: String] = [:]
    @State private var lastMessageTimes: [String: TimeInterval] = [:]
    @State private var showAddOshiForm = false
    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @State private var showDeleteOshiAlert = false
    @State private var oshiToDelete: Oshi?
    @State private var oshiToDeleteCompletely: Oshi?
    @State private var isDeletingOshi = false
    
    @State private var helpFlag = false
    @State private var customerFlag = false
    @ObservedObject var authManager = AuthManager()
    
    // LINE風カラー設定
    let lineGrayBG = Color(UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0))
    let primaryColor = Color(.systemPink)
    
    var body: some View {
        NavigationView {
            ZStack {
                lineGrayBG.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // ヘッダー
                    headerView
                    
                    // 広告バナー
                    BannerAdChatListView()
                        .frame(height: 60)
                    
                    // メインコンテンツ
                    if isLoading {
                        loadingView
                    } else if oshiList.isEmpty {
                        emptyStateView
                    } else {
                        individualChatListView
                    }
                }
                
                if isDeletingOshi {
                    deletingOverlay
                }
                
                if helpFlag {
                    HelpModalView(isPresented: $helpFlag)
                }
                
                if customerFlag {
                    ReviewView(isPresented: $customerFlag, helpFlag: $helpFlag)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
            authManager.fetchUserFlag { userFlag, error in
                if let error = error {
                    print(error.localizedDescription)
                } else if let userFlag = userFlag {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if userFlag == 0 {
                            executeProcessEveryThreeTimes()
                        }
                    }
                }
            }
        }
        .refreshable {
            loadData()
        }
        .alert("チャット履歴を削除", isPresented: $showDeleteAlert) {
            Button("削除", role: .destructive) {
                if let oshi = oshiToDelete {
                    deleteChatHistory(for: oshi)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(oshiToDelete?.name ?? "")とのチャット履歴を削除しますか？この操作は元に戻せません。")
        }
        .alert("推しを削除", isPresented: $showDeleteOshiAlert) {
            Button("削除", role: .destructive) {
                if let oshi = oshiToDeleteCompletely {
                    deleteOshiCompletely(oshi)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(oshiToDeleteCompletely?.name ?? "")を完全に削除しますか？この操作は元に戻せません。\n関連するチャット履歴やアイテム記録もすべて削除されます。")
        }
        .fullScreenCover(isPresented: $showAddOshiForm, onDismiss: {
            loadData()
        }) {
            AddOshiView()
        }
    }
    
    func executeProcessEveryThreeTimes() {
        let count = UserDefaults.standard.integer(forKey: "launchCount") + 1
        UserDefaults.standard.set(count, forKey: "launchCount")
        
        if count % 10 == 0 {
            customerFlag = true
        }
    }
    
    // チャットが存在するかどうかを判定
    private var hasAnyChats: Bool {
        return oshiList.contains { oshi in
            if let lastTime = lastMessageTimes[oshi.id], lastTime > 0 {
                return true
            }
            return false
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    generateHapticFeedback()
                    showAddOshiForm = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(primaryColor)
                }
                .padding(.leading)
                
                Spacer()
                
                Text("個人チャット")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                if hasAnyChats {
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring()) { isEditing.toggle() }
                    }) {
                        Text(isEditing ? "完了" : "編集")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing)
                } else {
                    Spacer()
                        .frame(width: 44)
                        .padding(.trailing)
                }
            }
            .padding(.vertical, 12)
            .background(Color.white)
            
            if !oshiList.isEmpty {
                searchBarView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)
            
            TextField("推しを検索", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("読み込み中...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("まだ推しとのチャットがありません")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("推しを登録してチャットを始めよう！")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                generateHapticFeedback()
                showAddOshiForm = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    Text("推しを登録する")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(20)
                .shadow(color: primaryColor.opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var individualChatListView: some View {
        VStack(spacing: 0) {
            // 推し追加カード
            addOshiCardView
            
            // チャット一覧
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredOshiList, id: \.id) { oshi in
                        if isEditing {
                            HStack {
                                ChatRowView(
                                    oshi: oshi,
                                    unreadCount: unreadCounts[oshi.id] ?? 0,
                                    lastMessage: lastMessages[oshi.id] ?? "まだメッセージがありません",
                                    lastMessageTime: lastMessageTimes[oshi.id] ?? 0,
                                    isSelected: oshi.id == selectedOshiId
                                )
                                
                                editButtonsView(for: oshi)
                            }
                        } else {
                            NavigationLink(destination: destinationView(for: oshi)) {
                                ChatRowView(
                                    oshi: oshi,
                                    unreadCount: unreadCounts[oshi.id] ?? 0,
                                    lastMessage: lastMessages[oshi.id] ?? "まだメッセージがありません",
                                    lastMessageTime: lastMessageTimes[oshi.id] ?? 0,
                                    isSelected: oshi.id == selectedOshiId
                                )
                            }
                            .navigationBarHidden(true)
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Divider()
                            .padding(.leading, 80)
                            .background(Color.gray.opacity(0.3))
                    }
                }
            }
            .background(Color.white)
        }
    }
    
    private var addOshiCardView: some View {
        VStack(spacing: 12) {
            Button(action: {
                generateHapticFeedback()
                showAddOshiForm = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(primaryColor.opacity(0.1))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(primaryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("新しい推しを追加")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("推しを登録してチャットを始めよう")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color.white)
            
            Divider()
        }
        .background(Color.white)
    }
    
    private func editButtonsView(for oshi: Oshi) -> some View {
        VStack(spacing: -10) {
            Button(action: {
                generateHapticFeedback()
                oshiToDelete = oshi
                showDeleteAlert = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                    Text("履歴")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                .padding(8)
            }
            
            Button(action: {
                generateHapticFeedback()
                oshiToDeleteCompletely = oshi
                showDeleteOshiAlert = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    Text("推し")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
                .padding(8)
            }
        }
        .padding(.trailing, 12)
    }
    
    private var deletingOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("推しを削除中...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            )
    }
    
    // フィルタリングされた推しリスト
    private var filteredOshiList: [Oshi] {
        let filteredList = searchText.isEmpty ? oshiList : oshiList.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
        
        return filteredList.sorted { oshi1, oshi2 in
            let isOshi1Selected = oshi1.id == selectedOshiId
            let isOshi2Selected = oshi2.id == selectedOshiId
            
            if isOshi1Selected && !isOshi2Selected {
                return true
            } else if !isOshi1Selected && isOshi2Selected {
                return false
            } else {
                let time1 = lastMessageTimes[oshi1.id] ?? 0
                let time2 = lastMessageTimes[oshi2.id] ?? 0
                return time1 > time2
            }
        }
    }
    
    private func destinationView(for oshi: Oshi) -> some View {
        let viewModel = OshiViewModel(oshi: oshi)
        return OshiAIChatView(viewModel: viewModel, oshiItem: nil)
            .onDisappear {
                loadUnreadCounts()
                loadLastMessages()
                loadSelectedOshiId()
            }
    }
    
    // データロード関数群
    private func loadData() {
        isLoading = true
        loadOshiList()
        loadSelectedOshiId()
    }
    
    private func loadSelectedOshiId() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedId = snapshot.value as? String {
                DispatchQueue.main.async {
                    self.selectedOshiId = selectedId
                }
            }
        }
    }
    
    private func loadOshiList() {
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            var newOshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any] {
                    let id = childSnapshot.key
                    let name = value["name"] as? String ?? "名前なし"
                    let imageUrl = value["imageUrl"] as? String
                    let backgroundImageUrl = value["backgroundImageUrl"] as? String
                    let memo = value["memo"] as? String
                    let createdAt = value["createdAt"] as? TimeInterval
                    
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
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.loadUnreadCounts()
                self.loadLastMessages()
            }
        }
    }
    
    private func loadLastMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let dispatchGroup = DispatchGroup()
        var tempLastMessages: [String: String] = [:]
        var tempLastMessageTimes: [String: TimeInterval] = [:]
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            let chatRef = Database.database().reference()
                .child("oshiChats")
                .child(userId)
                .child(oshi.id)
            
            chatRef.queryOrdered(byChild: "timestamp")
                .queryLimited(toLast: 1)
                .observeSingleEvent(of: .value) { snapshot in
                    
                    var latestMessage: String = "まだメッセージがありません"
                    var latestTimestamp: TimeInterval = 0
                    
                    for child in snapshot.children {
                        if let childSnapshot = child as? DataSnapshot,
                           let messageDict = childSnapshot.value as? [String: Any],
                           let content = messageDict["content"] as? String,
                           let timestamp = messageDict["timestamp"] as? TimeInterval {
                            latestMessage = content
                            latestTimestamp = timestamp
                            break
                        }
                    }
                    
                    tempLastMessages[oshi.id] = latestMessage
                    tempLastMessageTimes[oshi.id] = latestTimestamp
                    
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.lastMessages = tempLastMessages
            self.lastMessageTimes = tempLastMessageTimes
            self.isLoading = false
        }
    }
    
    private func loadUnreadCounts() {
        let dispatchGroup = DispatchGroup()
        var tempUnreadCounts: [String: Int] = [:]
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            ChatDatabaseManager.shared.fetchUnreadMessageCount(for: oshi.id) { count, _ in
                tempUnreadCounts[oshi.id] = count
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.unreadCounts = tempUnreadCounts
        }
    }
    
    private func deleteChatHistory(for oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let chatRef = Database.database().reference()
            .child("oshiChats")
            .child(userId)
            .child(oshi.id)
        
        chatRef.removeValue { error, _ in
            DispatchQueue.main.async {
                if let error = error {
                    print("チャット履歴削除エラー: \(error.localizedDescription)")
                } else {
                    print("チャット履歴を削除しました: \(oshi.name)")
                    self.lastMessages[oshi.id] = "まだメッセージがありません"
                    self.lastMessageTimes[oshi.id] = 0
                    self.unreadCounts[oshi.id] = 0
                    
                    let userRef = Database.database().reference().child("users").child(userId)
                    userRef.child("lastReadTimestamps").child(oshi.id).removeValue()
                }
            }
        }
    }
    
    private func deleteOshiCompletely(_ oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeletingOshi = true
        
        let dispatchGroup = DispatchGroup()
        var deletionError: Error? = nil
        
        // 推しデータを削除
        dispatchGroup.enter()
        let oshiRef = Database.database().reference().child("oshis").child(userId).child(oshi.id)
        oshiRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("推しデータ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // チャット履歴を削除
        dispatchGroup.enter()
        let chatRef = Database.database().reference().child("oshiChats").child(userId).child(oshi.id)
        chatRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("チャット履歴削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // アイテム記録を削除
        dispatchGroup.enter()
        let itemsRef = Database.database().reference().child("oshiItems").child(userId).child(oshi.id)
        itemsRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("アイテム記録削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // ストレージの画像を削除
        dispatchGroup.enter()
        let storageRef = Storage.storage().reference().child("oshis").child(userId).child(oshi.id)
        storageRef.delete { error in
            if let error = error, (error as NSError).code != StorageErrorCode.objectNotFound.rawValue {
                print("ストレージ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 最後に読んだタイムスタンプを削除
        dispatchGroup.enter()
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadTimestamps").child(oshi.id).removeValue { error, _ in
            if let error = error {
                print("タイムスタンプ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 選択中の推しIDを更新（削除する推しが選択中の場合）
        dispatchGroup.enter()
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedOshiId = snapshot.value as? String, selectedOshiId == oshi.id {
                let oshisRef = Database.database().reference().child("oshis").child(userId)
                oshisRef.observeSingleEvent(of: .value) { oshiSnapshot in
                    var newSelectedId = "default"
                    
                    for child in oshiSnapshot.children {
                        if let childSnapshot = child as? DataSnapshot,
                           childSnapshot.key != oshi.id {
                            newSelectedId = childSnapshot.key
                            break
                        }
                    }
                    
                    userRef.updateChildValues(["selectedOshiId": newSelectedId]) { error, _ in
                        if let error = error {
                            print("選択中推しID更新エラー: \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isDeletingOshi = false
            
            if let error = deletionError {
                print("削除処理でエラーが発生しました: \(error.localizedDescription)")
            } else {
                print("推し「\(oshi.name)」を完全に削除しました")
                
                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                    self.oshiList.remove(at: index)
                }
                self.lastMessages.removeValue(forKey: oshi.id)
                self.lastMessageTimes.removeValue(forKey: oshi.id)
                self.unreadCounts.removeValue(forKey: oshi.id)
                
                if self.selectedOshiId == oshi.id {
                    self.selectedOshiId = self.oshiList.first?.id ?? ""
                }
                
                self.loadData()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

#Preview {
    IndividualChatTabView()
}
