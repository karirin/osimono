//
//  ChatHubView.swift
//  osimono
//
//  個人チャットとグループチャットを統合したハブ画面 - 多言語対応版
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseStorage

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
    
    // 編集機能関連の新しい状態
    @State private var isEditingIndividual = false
    @State private var isEditingGroup = false
    @State private var showDeleteIndividualAlert = false
    @State private var showDeleteGroupAlert = false
    @State private var showDeleteOshiAlert = false
    @State private var individualToDelete: Oshi?
    @State private var groupToDelete: GroupChatInfo?
    @State private var oshiToDeleteCompletely: Oshi?
    @State private var isDeletingItem = false
    @State private var showEditGroupSheet = false
    @State private var groupToEdit: GroupChatInfo?
    
    @State private var selectedGroupId: String = ""
    
    // LINE風カラー設定
    let lineGrayBG = Color(UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0))
    let primaryColor = Color(.systemPink)
    
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    private var shouldShowAd: Bool {
        AdConfiguration.shouldShowAds(isAdmin: isAdmin, isSubscribed: subscriptionManager.isSubscribed)
    }
    
    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    
    // private let adminUserIds = [
    //     "3UDNienzhkdheKIy77lyjMJhY4D3",
    //     "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    // ]

    @State private var showDeleteHistoryAlert = false
    @State private var groupToDeleteHistory: GroupChatInfo?
    @State private var isDeletingHistory = false

    // 多言語対応版のChatTabType
    enum ChatTabType: String, CaseIterable {
        case individual = "individual"
        case group = "group"
        
        var displayName: String {
            switch self {
            case .individual:
                return L10n.individualChat
            case .group:
                return L10n.groupChat
            }
        }
        
        var icon: String {
            switch self {
            case .individual: return "person.circle"
            case .group: return "person.2.circle"
            }
        }
    }
    
    private func checkAdminStatus() {
        isAdmin = false
        isCheckingAdminStatus = false
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
                    if !isAdmin {
                        if shouldShowAd {
                            // 広告バナー
                            BannerAdChatListView()
                                .frame(height: 60)
                        }
                    }
                    
                    // メインコンテンツ
                    if isLoading {
                        loadingView
                    } else {
                        mainContentView
                    }
                }
                
                // 削除中のオーバーレイ
                if isDeletingItem || isDeletingHistory {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text(isDeletingHistory ? "履歴を削除中..." : L10n.deletingGroup)
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                        )
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
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
                    // 新規作成されたグループを選択
                    selectedGroupId = groupInfo.id
                    
                    // Firebaseに選択したグループIDを保存
                    saveSelectedGroupId(groupInfo.id)
                    
                    // グループタブに切り替え
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = .group
                    }
                    
                    // データを再読み込み
                    loadGroupChats()
                    
                    print("新規グループ作成完了 - 選択ID: \(groupInfo.id)")
                }
            )
        }
        .sheet(isPresented: $showEditGroupSheet) {
            if let group = groupToEdit {
                EditGroupChatView(
                    group: group,
                    allOshiList: oshiList,
                    onUpdate: { updatedGroup in
                        loadGroupChats()
                    }
                )
            }
        }
        .alert(L10n.deleteConfirmationTitle, isPresented: $showDeleteIndividualAlert) {
            Button(L10n.delete, role: .destructive) {
                if let oshi = individualToDelete {
                    deleteIndividualChatHistory(for: oshi)
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("delete_individual_chat_message", comment: "Delete individual chat message"), individualToDelete?.name ?? ""))
        }
        .alert(L10n.deleteGroupTitle, isPresented: $showDeleteGroupAlert) {
            Button(L10n.delete, role: .destructive) {
                if let group = groupToDelete {
                    deleteGroup(group)
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.deleteGroupMessage(groupToDelete?.name ?? ""))
        }
        .alert("履歴削除の確認", isPresented: $showDeleteHistoryAlert) {
            Button("削除", role: .destructive) {
                if let group = groupToDeleteHistory {
                    deleteGroupHistory(group)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(groupToDeleteHistory?.name ?? "")」の全ての履歴を削除しますか？この操作は取り消すことができません。")
        }
        .alert(NSLocalizedString("delete_oshi_title", comment: "Delete oshi title"), isPresented: $showDeleteOshiAlert) {
            Button(L10n.delete, role: .destructive) {
                if let oshi = oshiToDeleteCompletely {
                    deleteOshiCompletely(oshi)
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(String(format: NSLocalizedString("delete_oshi_message", comment: "Delete oshi message"), oshiToDeleteCompletely?.name ?? ""))
        }
    }
    
    // MARK: - グループID保存メソッド（新規追加）
    private func saveSelectedGroupId(_ groupId: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("users").child(userID)
        dbRef.updateChildValues(["selectedGroupId": groupId]) { error, _ in
            if let error = error {
                print("❌ グループID保存エラー: \(error.localizedDescription)")
            } else {
                print("✅ グループID保存成功: \(groupId)")
            }
        }
    }
    
    private func deleteGroupHistory(_ group: GroupChatInfo) {
        guard isAdmin else {
            print("管理者権限がないため履歴削除を実行できません")
            return
        }
        
        isDeletingHistory = true
        
        groupChatManager.deleteGroupChatHistory(for: group.id) { error in
            DispatchQueue.main.async {
                self.isDeletingHistory = false
                
                if let error = error {
                    print("履歴削除エラー: \(error.localizedDescription)")
                } else {
                    print("履歴削除成功: \(group.name)")
                    // 成功フィードバック
                    self.generateHapticFeedback()
                    
                    // グループリストを更新して最終メッセージ情報をリセット
                    self.loadGroupChats()
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // 左側ボタンエリア（固定幅）
            HStack {
                if selectedTab == .group {
                    Button(action: {
                        generateHapticFeedback()
                        showCreateGroup = true
                    }) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 20))
                            .foregroundColor(primaryColor)
                    }
                } else {
                    Button(action: {
                        generateHapticFeedback()
                        showAddOshiForm = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(primaryColor)
                    }
                }
            }
            .frame(width: 60, alignment: .leading) // 固定幅を設定
            .padding(.leading)
            
            // 中央タイトルエリア
            Spacer()
            
            VStack(spacing: 0) {
                Text(selectedTab.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            // 右側ボタンエリア（固定幅）
            HStack {
                if selectedTab == .group {
                    // 編集ボタン（グループがある場合のみ）
                    if !groupChats.isEmpty {
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring()) { isEditingGroup.toggle() }
                        }) {
                            Text(isEditingGroup ? L10n.done : L10n.edit)
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // 空のスペースを維持
                        Text("")
                            .font(.system(size: 16))
                    }
                } else {
                    // 個人チャットタブの編集ボタン
                    if hasIndividualChats {
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring()) { isEditingIndividual.toggle() }
                        }) {
                            Text(isEditingIndividual ? L10n.done : L10n.edit)
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    } else {
                        // 空のスペースを維持
                        Text("")
                            .font(.system(size: 16))
                    }
                }
            }
            .frame(width: 60, alignment: .trailing) // 固定幅を設定
            .padding(.trailing)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
    }
    
    // 個人チャットが存在するかどうかを判定
    private var hasIndividualChats: Bool {
        return oshiList.contains { oshi in
            if let lastTime = lastMessageTimes[oshi.id], lastTime > 0 {
                return true
            }
            return false
        }
    }
    
    private var tabSelectorView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ChatTabType.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                            // タブ変更時に編集モードを解除
                            isEditingIndividual = false
                            isEditingGroup = false
                        }
                        generateHapticFeedback()
                    }) {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 16))
                                
                                Text(tab.displayName)
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
            
            TextField(selectedTab == .individual ? L10n.searchOshi : L10n.searchGroups, text: $searchText)
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
            Text(L10n.loading)
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
                            if isEditingIndividual {
                                HStack {
                                    ChatRowView(
                                        oshi: oshi,
                                        unreadCount: unreadCounts[oshi.id] ?? 0,
                                        lastMessage: lastMessages[oshi.id] ?? L10n.noMessagesYet,
                                        lastMessageTime: lastMessageTimes[oshi.id] ?? 0,
                                        isSelected: oshi.id == selectedOshiId,
                                        showEditButtons: true,
                                        onDeleteChat: {
                                            generateHapticFeedback()
                                            individualToDelete = oshi
                                            showDeleteIndividualAlert = true
                                        },
                                        onDeleteOshi: {
                                            generateHapticFeedback()
                                            oshiToDeleteCompletely = oshi
                                            showDeleteOshiAlert = true
                                        }
                                    )
                                }
                            } else {
                                NavigationLink(destination: individualChatDestination(for: oshi)) {
                                    ChatRowView(
                                        oshi: oshi,
                                        unreadCount: unreadCounts[oshi.id] ?? 0,
                                        lastMessage: lastMessages[oshi.id] ?? L10n.noMessagesYet,
                                        lastMessageTime: lastMessageTimes[oshi.id] ?? 0,
                                        isSelected: oshi.id == selectedOshiId
                                    )
                                }
                                .navigationBarHidden(true)
                                .buttonStyle(PlainButtonStyle())
                            }
                            
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
                            if isEditingGroup {
                                HStack {
                                    GroupChatRowView(
                                        group: group,
                                        unreadCount: groupUnreadCounts[group.id] ?? 0,
                                        allOshiList: oshiList,
                                        showEditButtons: true,
                                        onEdit: {
                                            generateHapticFeedback()
                                            groupToEdit = group
                                            showEditGroupSheet = true
                                        },
                                        onDelete: {
                                            generateHapticFeedback()
                                            groupToDelete = group
                                            showDeleteGroupAlert = true
                                        },
                                        onDeleteHistory: isAdmin ? {  // 管理者の場合のみ履歴削除を有効化
                                            generateHapticFeedback()
                                            groupToDeleteHistory = group
                                            showDeleteHistoryAlert = true
                                        } : nil,
                                        isAdmin: isAdmin
                                    )
                                }
                            } else {
                                NavigationLink(destination: groupChatDestination(for: group)) {
                                    GroupChatRowView(
                                        group: group,
                                        unreadCount: groupUnreadCounts[group.id] ?? 0,
                                        allOshiList: oshiList,
                                        isAdmin: isAdmin
                                    )
                                }
                                .navigationBarHidden(true)
                                .buttonStyle(PlainButtonStyle())
                            }
                            
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
                Text(NSLocalizedString("no_individual_chats_title", comment: "No individual chats title"))
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(NSLocalizedString("register_oshi_to_chat", comment: "Register oshi to chat"))
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
                    Text(L10n.registerOshiButton)
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
                Text(L10n.noGroupChats)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(L10n.groupChatDescription)
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
                        Text(L10n.createGroupButton)
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
                    Text(L10n.minimumMembersRequired)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Button(action: {
                        generateHapticFeedback()
                        showAddOshiForm = true
                    }) {
                        Text(L10n.addOshiFirst)
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
                        Text(NSLocalizedString("add_new_oshi", comment: "Add new oshi"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(NSLocalizedString("register_oshi_to_chat", comment: "Register oshi to chat"))
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
                        Text(L10n.createNewGroup)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(L10n.groupChatDescription)
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
                // 個人チャット画面から戻った時に未読数を更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadIndividualChatData()
                    loadSelectedOshiId()
                }
            }
    }
    
    private func groupChatDestination(for group: GroupChatInfo) -> some View {
        OshiGroupChatView(groupId: $selectedGroupId)   // ←Binding を渡す
            .onAppear {                                // 画面遷移時に選択IDを更新
                selectedGroupId = group.id
            }
            .onDisappear {                             // ※既存の未読数更新はそのまま
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadGroupUnreadCounts()
                }
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
    
    // ... 残りのメソッドは同じため省略 ...
    
    // 削除関数やその他のメソッドは変更なし（元のコードと同じ）
    // データ読み込み系メソッドも変更なし
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    // MARK: - 削除関数とデータ読み込み関数（省略されていた部分）
    
    private func deleteIndividualChatHistory(for oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeletingItem = true
        
        let chatRef = Database.database().reference()
            .child("oshiChats")
            .child(userId)
            .child(oshi.id)
        
        chatRef.removeValue { error, _ in
            DispatchQueue.main.async {
                self.isDeletingItem = false
                
                if let error = error {
                    print("チャット履歴削除エラー: \(error.localizedDescription)")
                } else {
                    print("チャット履歴を削除しました: \(oshi.name)")
                    // ローカルの状態も更新
                    self.lastMessages[oshi.id] = L10n.noMessagesYet
                    self.lastMessageTimes[oshi.id] = 0
                    self.unreadCounts[oshi.id] = 0
                    
                    // 最後に読んだタイムスタンプもリセット
                    let userRef = Database.database().reference().child("users").child(userId)
                    userRef.child("lastReadTimestamps").child(oshi.id).removeValue()
                }
            }
        }
    }
    
    private func deleteGroup(_ group: GroupChatInfo) {
        isDeletingItem = true
        
        groupChatManager.deleteGroup(groupId: group.id) { error in
            DispatchQueue.main.async {
                self.isDeletingItem = false
                
                if let error = error {
                    print("グループ削除エラー: \(error.localizedDescription)")
                } else {
                    print("グループを削除しました: \(group.name)")
                    // ローカルの状態を更新
                    if let index = self.groupChats.firstIndex(where: { $0.id == group.id }) {
                        self.groupChats.remove(at: index)
                    }
                    self.groupUnreadCounts.removeValue(forKey: group.id)
                    self.loadGroupChats()
                }
            }
        }
    }
    
    private func deleteOshiCompletely(_ oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeletingItem = true
        
        let dispatchGroup = DispatchGroup()
        var deletionError: Error? = nil
        
        // 1. 推しデータを削除
        dispatchGroup.enter()
        let oshiRef = Database.database().reference().child("oshis").child(userId).child(oshi.id)
        oshiRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("推しデータ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 2. チャット履歴を削除
        dispatchGroup.enter()
        let chatRef = Database.database().reference().child("oshiChats").child(userId).child(oshi.id)
        chatRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("チャット履歴削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 3. アイテム記録を削除
        dispatchGroup.enter()
        let itemsRef = Database.database().reference().child("oshiItems").child(userId).child(oshi.id)
        itemsRef.removeValue { error, _ in
            if let error = error {
                deletionError = error
                print("アイテム記録削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 4. ストレージの画像を削除
        dispatchGroup.enter()
        let storageRef = Storage.storage().reference().child("oshis").child(userId).child(oshi.id)
        storageRef.delete { error in
            // 画像が存在しない場合のエラーは無視
            if let error = error, (error as NSError).code != StorageErrorCode.objectNotFound.rawValue {
                print("ストレージ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        
        // 5. 最後に読んだタイムスタンプを削除
        dispatchGroup.enter()
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadTimestamps").child(oshi.id).removeValue { error, _ in
            if let error = error {
                print("タイムスタンプ削除エラー: \(error.localizedDescription)")
            }
            dispatchGroup.leave()
        }
        dispatchGroup.enter()
          userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
              if let selectedOshiId = snapshot.value as? String, selectedOshiId == oshi.id {
                  // 削除する推しが選択中の場合、他の推しに変更するか、デフォルトに戻す
                  let oshisRef = Database.database().reference().child("oshis").child(userId)
                  oshisRef.observeSingleEvent(of: .value) { oshiSnapshot in
                      var newSelectedId = "default"
                      
                      // 他の推しが存在する場合、最初の推しを選択
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
        // すべての削除処理が完了したら
        dispatchGroup.notify(queue: .main) {
            self.isDeletingItem = false
            
            if let error = deletionError {
                print("削除処理でエラーが発生しました: \(error.localizedDescription)")
            } else {
                print("推し「\(oshi.name)」を完全に削除しました")
                
                // ローカルの状態を更新
                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                    self.oshiList.remove(at: index)
                }
                self.lastMessages.removeValue(forKey: oshi.id)
                self.lastMessageTimes.removeValue(forKey: oshi.id)
                self.unreadCounts.removeValue(forKey: oshi.id)
                
                // 選択中の推しIDが削除された場合はリセット
                if self.selectedOshiId == oshi.id {
                    self.selectedOshiId = self.oshiList.first?.id ?? ""
                }
                
                // データを再読み込み
                self.loadAllData()
            }
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
                    
                    var latestMessage: String = L10n.noMessagesYet
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
            print("グループ未読数更新完了: \(tempUnreadCounts)")
        }
    }
}

#Preview {
    ChatHubView()
}
