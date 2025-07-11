//
//  OshiChatListView.swift
//  osimono
//
//  推しとのチャット一覧画面
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase

struct OshiChatListView: View {
    @StateObject private var coordinator = OshiChatCoordinator.shared
    @State private var searchText = ""
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshiId: String = "" // 選択中の推しIDを追加
    @State private var isLoading = true
    @State private var unreadCounts: [String: Int] = [:]
    @State private var lastMessages: [String: String] = [:]
    @State private var lastMessageTimes: [String: TimeInterval] = [:]
    @State private var showDeleteAlert = false
    @State private var oshiToDelete: Oshi?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var isEditing = false
    
    // LINE風カラー設定
    let lineGrayBG = Color(UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0))
    let lineGreen = Color(UIColor(red: 0.0, green: 0.68, blue: 0.31, alpha: 1.0))
    
    var body: some View {
        NavigationView {
            ZStack {
                lineGrayBG
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // ヘッダー
                    headerView
                    
                    // メインコンテンツ
                    if isLoading {
                        loadingView
                    } else if oshiList.isEmpty {
                        emptyStateView
                    } else {
                        chatListView
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
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
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // チャットが存在する場合のみ編集ボタンを表示
                if hasAnyChats {
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring()) { isEditing.toggle() }
                    }) {
                        Text(isEditing ? "完了" : "編集")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .opacity(0)
                    .padding(.leading)
                } else {
                    // チャットがない場合は空のスペーサー
                    Spacer()
                        .frame(width: 44) // ボタンと同じ幅を確保
                        .opacity(0)
                        .padding(.leading)
                }
                
                Spacer()
                
                Text("トーク")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                // チャットが存在する場合のみ編集ボタンを表示
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
                    // チャットがない場合は空のスペーサー
                    Spacer()
                        .frame(width: 44) // ボタンと同じ幅を確保
                        .padding(.trailing)
                }
            }
            .padding(.vertical, 12)
            .background(Color.white)
            
            // 検索バー
            if !oshiList.isEmpty {
                searchBarView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.white)
            }
            
            // 区切り線
            Divider()
                .background(Color.gray.opacity(0.3))
        }
    }
    
    // MARK: - 検索バー
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
    
    // MARK: - ローディング表示
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
    
    // MARK: - 空の状態表示
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
                // 推し登録画面へ遷移
            }) {
                Text("推しを登録する")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(lineGreen)
                    .cornerRadius(20)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - チャット一覧
    private var chatListView: some View {
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
                            Spacer(minLength: 0)
                            Button(role: .destructive) {
                                generateHapticFeedback()
                                oshiToDelete = oshi
                                showDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                    .padding(.trailing, 12)
                            }
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
    
    
    // MARK: - フィルタリングされた推しリスト（修正版）
    private var filteredOshiList: [Oshi] {
        let filteredList = searchText.isEmpty ? oshiList : oshiList.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
        
        // 選択中の推しを一番上に表示するためのソート
        return filteredList.sorted { oshi1, oshi2 in
            // まず選択中の推しかどうかで比較
            let isOshi1Selected = oshi1.id == selectedOshiId
            let isOshi2Selected = oshi2.id == selectedOshiId
            
            if isOshi1Selected && !isOshi2Selected {
                return true // oshi1が選択中で、oshi2が選択中でない場合、oshi1を上に
            } else if !isOshi1Selected && isOshi2Selected {
                return false // oshi2が選択中で、oshi1が選択中でない場合、oshi2を上に
            } else {
                // どちらも選択中、またはどちらも非選択の場合は、最新メッセージ時間でソート
                let time1 = lastMessageTimes[oshi1.id] ?? 0
                let time2 = lastMessageTimes[oshi2.id] ?? 0
                return time1 > time2
            }
        }
    }
    
    // MARK: - 遷移先ビュー
    private func destinationView(for oshi: Oshi) -> some View {
        let viewModel = OshiViewModel(oshi: oshi)
        return OshiAIChatView(viewModel: viewModel, oshiItem: nil)
            .onDisappear {
                // チャット画面から戻った時に未読数を更新
                loadUnreadCounts()
                loadLastMessages()
                loadSelectedOshiId() // 選択中の推しIDも再取得
            }
    }
    
    // MARK: - チャット履歴削除
    private func deleteChatHistory(for oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Firebaseからチャット履歴を削除
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
                    // ローカルの状態も更新
                    self.lastMessages[oshi.id] = "まだメッセージがありません"
                    self.lastMessageTimes[oshi.id] = 0
                    self.unreadCounts[oshi.id] = 0
                    
                    // 最後に読んだタイムスタンプもリセット
                    let userRef = Database.database().reference().child("users").child(userId)
                    userRef.child("lastReadTimestamps").child(oshi.id).removeValue()
                }
            }
        }
    }
    
    // MARK: - データ読み込み
    private func loadData() {
        isLoading = true
        loadOshiList()
        loadSelectedOshiId() // 選択中の推しIDを取得
    }
    
    // 選択中の推しIDを取得する新しいメソッド
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
                    
                    // 性格関連の属性を追加
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
    
    // MARK: - 実際のFirebaseデータを取得する修正されたメソッド
    private func loadLastMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let dispatchGroup = DispatchGroup()
        var tempLastMessages: [String: String] = [:]
        var tempLastMessageTimes: [String: TimeInterval] = [:]
        
        for oshi in oshiList {
            dispatchGroup.enter()
            
            // 各推しの最新メッセージを取得
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - チャット行ビュー（修正版）
struct ChatRowView: View {
    let oshi: Oshi
    let unreadCount: Int
    let lastMessage: String
    let lastMessageTime: TimeInterval
    let isSelected: Bool // 選択中かどうかのフラグを追加

    var body: some View {
        HStack(spacing: 12) {
            // プロフィール画像
            ZStack {
                profileImageView
                    .frame(width: 56, height: 56)
                
                // 選択中の推しには特別なインジケーターを表示
                if isSelected {
                    Circle()
                        .stroke(Color.pink, lineWidth: 3)
                        .frame(width: 56, height: 56)
                }
            }
            
            // メッセージ情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 6) {
                        Text(oshi.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        // 選択中の推しにはバッジを表示
                        if isSelected {
                            Text("選択中")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.pink)
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                    
                    Text(formatTime(lastMessageTime))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.pink.opacity(0.05) : Color.white) // 選択中は背景色を変更
    }
    
    // プロフィール画像
    private var profileImageView: some View {
        Group {
            if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    default:
                        defaultProfileImage
                    }
                }
            } else {
                defaultProfileImage
            }
        }
    }
    
    private var defaultProfileImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.gray)
            )
    }
    
    // 未読バッジ
    private var unreadBadge: some View {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, unreadCount > 9 ? 6 : 8)
            .padding(.vertical, 4)
            .background(Color.red)
            .clipShape(Capsule())
            .scaleEffect(0.9)
    }
    
    // 時間フォーマット
    private func formatTime(_ timestamp: TimeInterval) -> String {
        if timestamp == 0 {
            return ""
        }
        
        let date = Date(timeIntervalSince1970: timestamp)
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "昨日"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - プレビュー
#Preview {
//    OshiChatListView()
    TopView()
}
