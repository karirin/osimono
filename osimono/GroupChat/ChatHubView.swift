//
//  ChatHubView.swift
//  osimono
//
//  個人チャットとグループチャットを統合したハブ画面
//

import SwiftUI
import Firebase
import FirebaseAuth

struct ChatHubView: View {
    @StateObject private var coordinator = OshiChatCoordinator.shared
    @StateObject private var groupChatManager = GroupChatManager()
    @State private var selectedTab: ChatTabType = .individual
    @State private var isLoading = true
    @State private var showAddOshiForm = false
    @State private var showCreateGroup = false
    
    // 個人チャット関連
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshiId: String = ""
    @State private var unreadCounts: [String: Int] = [:]
    @State private var lastMessages: [String: String] = [:]
    @State private var lastMessageTimes: [String: TimeInterval] = [:]
    
    // グループチャット関連
    @State private var groupChats: [GroupChatInfo] = []
    @State private var groupUnreadCounts: [String: Int] = [:]
    
    @State private var searchText = ""
    @Environment(\.presentationMode) var presentationMode
    
    // LINE風カラー設定
    let lineGrayBG = Color(UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0))
    let primaryColor = Color(.systemPink)
    
    enum ChatTabType: String, CaseIterable {
        case individual = "個人"
        case group = "グループ"
        
        var icon: String {
            switch self {
            case .individual: return "person.circle"
            case .group: return "person.2.circle"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                lineGrayBG.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // ヘッダー
                    headerView
                    
                    // タブセレクター
                    tabSelectorView
                    
                    // 広告バナー
                    BannerAdChatListView()
                        .frame(height: 60)
                    
                    // メインコンテンツ
                    if isLoading {
                        loadingView
                    } else {
                        mainContentView
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadAllData()
        }
        .refreshable {
            loadAllData()
        }
        .fullScreenCover(isPresented: $showAddOshiForm, onDismiss: {
            loadAllData()
        }) {
            AddOshiView()
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupChatView(
                allOshiList: oshiList,
                onCreate: { groupInfo in
                    loadGroupChats()
                }
            )
        }
    }
    
    private var headerView: some View {
        HStack {
            // 推し追加ボタン
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
            
            Text("チャット")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            // グループ作成ボタン（グループタブ選択時のみ表示）
            if selectedTab == .group {
                Button(action: {
                    generateHapticFeedback()
                    showCreateGroup = true
                }) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(primaryColor)
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
        .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
    }
    
    private var tabSelectorView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ChatTabType.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                        generateHapticFeedback()
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16))
                                
                                Text(tab.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                
                                // 未読バッジ
                                if getTotalUnreadCount(for: tab) > 0 {
                                    Text("\(getTotalUnreadCount(for: tab))")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                        .scaleEffect(0.8)
                                }
                            }
                            .foregroundColor(selectedTab == tab ? primaryColor : .gray)
                            
                            Rectangle()
                                .fill(selectedTab == tab ? primaryColor : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // 検索バー（該当するチャットがある場合のみ表示）
            if hasChatsForCurrentTab() {
                searchBarView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
        .background(Color.white)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)
            
            TextField(selectedTab == .individual ? "推しを検索" : "グループを検索", text: $searchText)
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
    
    private var mainContentView: some View {
        TabView(selection: $selectedTab) {
            individualChatView
                .tag(ChatTabType.individual)
            
            groupChatView
                .tag(ChatTabType.group)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    private var individualChatView: some View {
        Group {
            if oshiList.isEmpty {
                emptyIndividualChatView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 推し追加用のカード
                        addOshiCardView
                        
                        // 既存のチャット一覧
                        ForEach(filteredOshiList, id: \.id) { oshi in
                            NavigationLink(destination: individualChatDestination(for: oshi)) {
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
                            
                            if oshi.id != filteredOshiList.last?.id {
                                Divider()
                                    .padding(.leading, 80)
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                    }
                }
                .background(Color.white)
            }
        }
    }
    
    private var groupChatView: some View {
        Group {
            if groupChats.isEmpty {
                emptyGroupChatView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // グループ作成用のカード
                        addGroupCardView
                        
                        // 既存のグループチャット一覧
                        ForEach(filteredGroupChats, id: \.id) { group in
                            NavigationLink(destination: groupChatDestination(for: group)) {
                                GroupChatRowView(
                                    group: group,
                                    unreadCount: groupUnreadCounts[group.id] ?? 0,
                                    allOshiList: oshiList
                                )
                            }
                            .navigationBarHidden(true)
                            .buttonStyle(PlainButtonStyle())
                            
                            if group.id != filteredGroupChats.last?.id {
                                Divider()
                                    .padding(.leading, 80)
                                    .background(Color.gray.opacity(0.3))
                            }
                        }
                    }
                }
                .background(Color.white)
            }
        }
    }
    
    private var emptyIndividualChatView: some View {
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
    
    private var emptyGroupChatView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("まだグループチャットがありません")
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text("複数の推しと一緒にチャットを楽しもう！")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            if oshiList.count >= 2 {
                Button(action: {
                    generateHapticFeedback()
                    showCreateGroup = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                        Text("グループを作成する")
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
            } else {
                VStack(spacing: 8) {
                    Text("グループチャットには2人以上の推しが必要です")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Button(action: {
                        generateHapticFeedback()
                        showAddOshiForm = true
                    }) {
                        Text("まず推しを追加する")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private var addGroupCardView: some View {
        VStack(spacing: 12) {
            Button(action: {
                generateHapticFeedback()
                showCreateGroup = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(primaryColor.opacity(0.1))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(primaryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("新しいグループを作成")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("複数の推しとグループチャットを楽しもう")
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
            .disabled(oshiList.count < 2)
            .opacity(oshiList.count < 2 ? 0.5 : 1.0)
            
            Divider()
        }
        .background(Color.white)
    }
    
    // フィルタリング
    private var filteredOshiList: [Oshi] {
        let filtered = searchText.isEmpty ? oshiList : oshiList.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
        
        return filtered.sorted { oshi1, oshi2 in
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
    
    private var filteredGroupChats: [GroupChatInfo] {
        return searchText.isEmpty ? groupChats : groupChats.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }
    
    // ナビゲーション先
    private func individualChatDestination(for oshi: Oshi) -> some View {
        let viewModel = OshiViewModel(oshi: oshi)
        return OshiAIChatView(viewModel: viewModel, oshiItem: nil)
            .onDisappear {
                loadIndividualChatData()
                loadSelectedOshiId()
            }
    }
    
    private func groupChatDestination(for group: GroupChatInfo) -> some View {
        return OshiGroupChatView(groupId: group.id)
            .onDisappear {
                loadGroupUnreadCounts()
            }
    }
    
    // ヘルパー関数
    private func hasChatsForCurrentTab() -> Bool {
        switch selectedTab {
        case .individual:
            return !oshiList.isEmpty
        case .group:
            return !groupChats.isEmpty
        }
    }
    
    private func getTotalUnreadCount(for tab: ChatTabType) -> Int {
        switch tab {
        case .individual:
            return unreadCounts.values.reduce(0, +)
        case .group:
            return groupUnreadCounts.values.reduce(0, +)
        }
    }
    
    // データ読み込み
    private func loadAllData() {
        isLoading = true
        loadOshiList()
        loadSelectedOshiId()
        loadGroupChats()
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
                    
                    let oshi = Oshi(
                        id: id,
                        name: name,
                        imageUrl: imageUrl,
                        backgroundImageUrl: backgroundImageUrl,
                        memo: memo,
                        createdAt: createdAt,
                        personality: value["personality"] as? String,
                        interests: value["interests"] as? [String],
                        speaking_style: value["speaking_style"] as? String,
                        birthday: value["birthday"] as? String,
                        height: value["height"] as? Int,
                        favorite_color: value["favorite_color"] as? String,
                        favorite_food: value["favorite_food"] as? String,
                        disliked_food: value["disliked_food"] as? String,
                        hometown: value["hometown"] as? String,
                        gender: value["gender"] as? String ?? "男性",
                        user_nickname: value["user_nickname"] as? String
                    )
                    newOshis.append(oshi)
                }
            }
            
            DispatchQueue.main.async {
                self.oshiList = newOshis
                self.loadIndividualChatData()
            }
        }
    }
    
    private func loadIndividualChatData() {
        loadUnreadCounts()
        loadLastMessages()
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
    
    private func loadGroupChats() {
        groupChatManager.fetchGroupList { groups, error in
            DispatchQueue.main.async {
                if let groups = groups {
                    self.groupChats = groups
                    self.loadGroupUnreadCounts()
                }
            }
        }
    }
    
    private func loadGroupUnreadCounts() {
        let dispatchGroup = DispatchGroup()
        var tempUnreadCounts: [String: Int] = [:]
        
        for group in groupChats {
            dispatchGroup.enter()
            
            groupChatManager.fetchUnreadMessageCount(for: group.id) { count, _ in
                tempUnreadCounts[group.id] = count
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.groupUnreadCounts = tempUnreadCounts
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
    ChatHubView()
}
