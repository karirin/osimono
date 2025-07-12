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
    @State private var isLoading = true
    @State private var unreadCounts: [String: Int] = [:]
    @Environment(\.presentationMode) var presentationMode
    
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
    }
    
    // MARK: - ヘッダービュー
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    generateHapticFeedback()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.blue)
                }
                .padding(.leading)
                
                Spacer()
                
                Text("トーク")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button(action: {
                    generateHapticFeedback()
                    // 設定やその他のアクション
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
                .padding(.trailing)
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
                    NavigationLink(destination: destinationView(for: oshi)) {
                        ChatRowView(
                            oshi: oshi,
                            unreadCount: unreadCounts[oshi.id] ?? 0,
                            lastMessage: getLastMessage(for: oshi),
                            lastMessageTime: getLastMessageTime(for: oshi)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 80)
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .background(Color.white)
    }
    
    // MARK: - フィルタリングされた推しリスト
    private var filteredOshiList: [Oshi] {
        if searchText.isEmpty {
            return oshiList.sorted { oshi1, oshi2 in
                let time1 = getLastMessageTime(for: oshi1)
                let time2 = getLastMessageTime(for: oshi2)
                return time1 > time2
            }
        } else {
            return oshiList.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }.sorted { oshi1, oshi2 in
                let time1 = getLastMessageTime(for: oshi1)
                let time2 = getLastMessageTime(for: oshi2)
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
            }
    }
    
    // MARK: - データ読み込み
    private func loadData() {
        isLoading = true
        loadOshiList()
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
                self.isLoading = false
                self.loadUnreadCounts()
            }
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
    
    // MARK: - ヘルパーメソッド
    private func getLastMessage(for oshi: Oshi) -> String {
        // 実際の実装では、Firebaseから最新メッセージを取得
        // ここではサンプルメッセージを返す
        let sampleMessages = [
            "こんにちは！今日も一日お疲れ様でした✨",
            "お疲れ様！いつも応援してくれてありがとう💕",
            "今度の新しいグッズ、どう思う？",
            "今日はどんな一日だった？",
            "また今度話しかけてね！"
        ]
        return sampleMessages.randomElement() ?? "メッセージがありません"
    }
    
    private func getLastMessageTime(for oshi: Oshi) -> TimeInterval {
        // 実際の実装では、Firebaseから最新メッセージの時間を取得
        // ここではランダムな時間を返す
        let randomDays = Double.random(in: 0...7)
        return Date().timeIntervalSince1970 - (randomDays * 24 * 60 * 60)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - チャット行ビュー
struct ChatRowView: View {
    let oshi: Oshi
    let unreadCount: Int
    let lastMessage: String
    let lastMessageTime: TimeInterval
    
    var body: some View {
        HStack(spacing: 12) {
            // プロフィール画像
            profileImageView
                .frame(width: 56, height: 56)
            
            // メッセージ情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(oshi.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
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
        .background(Color.white)
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
    OshiChatListView()
}
