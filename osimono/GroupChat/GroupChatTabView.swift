//
//  GroupChatTabView.swift
//  osimono
//
//  Created by Apple on 2025/07/21.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase

struct GroupChatTabView: View {
    @StateObject private var groupChatManager = GroupChatManager()
    @State private var searchText = ""
    @State private var groupChats: [GroupChatInfo] = []
    @State private var groupUnreadCounts: [String: Int] = [:]
    @State private var allOshiList: [Oshi] = []
    @State private var isLoading = true
    @State private var showCreateGroup = false
    @State private var isEditing = false
    @State private var showDeleteGroupAlert = false
    @State private var showEditGroupSheet = false
    @State private var groupToDelete: GroupChatInfo?
    @State private var groupToEdit: GroupChatInfo?
    @State private var isDeletingGroup = false
    
    @State private var openedGroupId: String = ""
    
    // private let adminUserIds = [
    //     "3UDNienzhkdheKIy77lyjMJhY4D3",
    //     "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    // ]

    @State private var isCheckingAdminStatus = true
    
    @State private var showDeleteHistoryAlert = false
    @State private var groupToDeleteHistory: GroupChatInfo?
    @State private var isDeletingHistory = false
    
    private func checkAdminStatus() {
        isAdmin = false
        isCheckingAdminStatus = false
    }
    
    @State private var isAdmin = false
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    private var shouldShowAd: Bool {
        AdConfiguration.shouldShowAds(isAdmin: isAdmin, isSubscribed: subscriptionManager.isSubscribed)
    }
    
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
                    if !isAdmin {
                        if shouldShowAd {
                            BannerAdChatListView()
                                .frame(height: 60)
                        }
                    }
                    
                    // メインコンテンツ
                    if isLoading {
                        loadingView
                    } else if groupChats.isEmpty {
                        emptyStateView
                    } else {
                        groupChatListView
                    }
                }
                
                if isDeletingGroup {
                    deletingOverlay
                }
                
                if isDeletingGroup || isDeletingHistory {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .tint(.white)
                                Text(isDeletingHistory ? "履歴を削除中..." : "グループを削除中...")
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
        .refreshable {
            loadAllData()
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupChatView(
                allOshiList: allOshiList,
                onCreate: { groupInfo in
                    // 新規作成されたグループを選択
                    openedGroupId = groupInfo.id
                    
                    // Firebaseに選択したグループIDを保存
                    saveSelectedGroupId(groupInfo.id)
                    
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
                    allOshiList: allOshiList,
                    onUpdate: { updatedGroup in
                        loadGroupChats()
                    }
                )
            }
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
    }
    
    private func deleteGroupHistory(_ group: GroupChatInfo) {
        guard isAdmin else {
            print("管理者権限がないため履歴削除を実行できません")
            return
        }
        
        isDeletingHistory = true
        
        let groupChatManager = GroupChatManager()
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
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    generateHapticFeedback()
                    showCreateGroup = true
                }) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(primaryColor)
                }
                .padding(.leading)
                
                Spacer()
                
                Text(L10n.groupChat)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                if !groupChats.isEmpty {
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
            
            if !groupChats.isEmpty {
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
            
            TextField(L10n.searchGroups, text: $searchText)
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
            Text(L10n.loading) // 修正: ハードコーディングされた文字列を多言語対応
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
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
            
            if allOshiList.count >= 2 {
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
                    
                    Text(L10n.addOshiFirst)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .underline()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var groupChatListView: some View {
        VStack(spacing: 0) {
            // グループ作成カード
            addGroupCardView
            
            // グループチャット一覧
            ScrollView {
                 LazyVStack(spacing: 0) {
                     ForEach(filteredGroupChats, id: \.id) { group in
                         if isEditing {
                             HStack {
                                 GroupChatRowView(
                                     group: group,
                                     unreadCount: groupUnreadCounts[group.id] ?? 0,
                                     allOshiList: allOshiList,
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
                                     allOshiList: allOshiList,
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
            .disabled(allOshiList.count < 2)
            .opacity(allOshiList.count < 2 ? 0.5 : 1.0)
            
            Divider()
        }
        .background(Color.white)
    }
    
    private func editButtonsView(for group: GroupChatInfo) -> some View {
        VStack(spacing: 5) {
            Button(action: {
                generateHapticFeedback()
                groupToEdit = group
                showEditGroupSheet = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                    Text(L10n.edit) // 修正: ハードコーディングされた文字列を多言語対応
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
            }
            
            Button(action: {
                generateHapticFeedback()
                groupToDelete = group
                showDeleteGroupAlert = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    Text(L10n.delete) // 修正: ハードコーディングされた文字列を多言語対応
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
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
                    Text("グループを削除中...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            )
    }
    
    private var filteredGroupChats: [GroupChatInfo] {
        return searchText.isEmpty ? groupChats : groupChats.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
    }
    
    private func groupChatDestination(for group: GroupChatInfo) -> some View {
        return  OshiGroupChatView(groupId: $openedGroupId)          // ←Binding を渡す
            .onAppear { openedGroupId = group.id }          // ←遷移前にIDをセット
            .onDisappear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadGroupUnreadCounts()
                }
            }
    }
    
    private func loadAllData() {
        isLoading = true
        loadOshiList()
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
                self.allOshiList = newOshis
            }
        }
    }
    
    private func loadGroupChats() {
        groupChatManager.fetchGroupList { groups, error in
            DispatchQueue.main.async {
                if let groups = groups {
                    self.groupChats = groups
                    self.loadGroupUnreadCounts()
                } else {
                    self.groupChats = []
                }
                self.isLoading = false
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
    
    private func deleteGroup(_ group: GroupChatInfo) {
        isDeletingGroup = true
        
        groupChatManager.deleteGroup(groupId: group.id) { error in
            DispatchQueue.main.async {
                self.isDeletingGroup = false
                
                if let error = error {
                    print("グループ削除エラー: \(error.localizedDescription)")
                } else {
                    print("グループを削除しました: \(group.name)")
                    
                    // 削除されたグループが選択中の場合、他のグループを選択
                    if self.openedGroupId == group.id {
                        let remainingGroups = self.groupChats.filter { $0.id != group.id }
                        self.openedGroupId = remainingGroups.first?.id ?? ""
                    }
                    
                    if let index = self.groupChats.firstIndex(where: { $0.id == group.id }) {
                        self.groupChats.remove(at: index)
                    }
                    self.groupUnreadCounts.removeValue(forKey: group.id)
                    self.loadGroupChats()
                }
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
