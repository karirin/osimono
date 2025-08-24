//
//  GroupChatListModalView.swift
//  osimono
//
//  グループチャット一覧モーダル - 多言語対応版
//

import SwiftUI
import Firebase
import FirebaseAuth

struct GroupChatListModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var groupChats: [GroupChatInfo]
    @Binding var selectedGroupId: String
    let allOshiList: [Oshi]
    
    @StateObject private var groupChatManager = GroupChatManager()
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var showCreateGroup = false
    @State private var isEditing = false
    @State private var showDeleteGroupAlert = false
    @State private var showEditGroupSheet = false
    @State private var groupToDelete: GroupChatInfo?
    @State private var groupToEdit: GroupChatInfo?
    @State private var isDeletingGroup = false
    @State private var groupUnreadCounts: [String: Int] = [:]
    
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
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadGroupUnreadCounts()
        }
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupChatView(
                allOshiList: allOshiList,
                onCreate: { groupInfo in
                    // 新規作成されたグループを選択
                    selectedGroupId = groupInfo.id
                    
                    // Firebaseに選択したグループIDを保存
                    saveSelectedGroupId(groupInfo.id)
                    
                    // データを再読み込み
                    loadGroupChats()
                    
                    print("新規グループ作成完了（モーダル） - 選択ID: \(groupInfo.id)")
                }
            )
        }
        .sheet(item: $groupToEdit) { group in
            EditGroupChatView(
                group: group,
                allOshiList: allOshiList,
                onUpdate: { _ in
                    loadGroupChats()
                }
            )
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
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                // 閉じるボタン
                Button(action: {
                    generateHapticFeedback()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
                .padding(.leading)
                
                Spacer()
                
                Text(L10n.groupChatListTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                // グループ作成/編集ボタン
                HStack(spacing: 8) {
                    // 編集ボタン（グループがある場合のみ）
                    if !groupChats.isEmpty {
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring()) { isEditing.toggle() }
                        }) {
                            Text(isEditing ? L10n.done : L10n.edit)
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            generateHapticFeedback()
                            withAnimation(.spring()) { isEditing.toggle() }
                        }) {
                            Text(isEditing ? L10n.done : L10n.edit)
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }.opacity(0)
                    }
                }
                .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(Color.white)
            
            // 検索バー
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
            Text(L10n.loading)
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
                
                Text(L10n.noGroupChatsDescription)
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
                    Text(L10n.needMoreMembers)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Text(L10n.registerMoreOshi)
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
                                groupRowView(for: group)
                                editButtonsView(for: group)
                            }
                        } else {
                            Button(action: {
                                selectGroup(group)
                            }) {
                                groupRowView(for: group)
                            }
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
                        
                        Text(L10n.noGroupChatsDescription)
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
    
    private func groupRowView(for group: GroupChatInfo) -> some View {
        HStack(spacing: 12) {
            // 選択中のグループには特別なインジケーターを表示
            ZStack {
                GroupChatRowView(
                    group: group,
                    unreadCount: groupUnreadCounts[group.id] ?? 0,
                    allOshiList: allOshiList
                )
                
                // 選択中のグループには境界線を表示
                if group.id == selectedGroupId {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(primaryColor, lineWidth: 2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                }
            }
        }
    }
    
    // 選択中のグループIDを保存
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
                    Text(L10n.edit)
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
                    Text(L10n.delete)
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
                    Text(L10n.deletingGroup)
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
    
    private func selectGroup(_ group: GroupChatInfo) {
        generateHapticFeedback()
        selectedGroupId = group.id
        
        // Firebaseに選択したグループIDを保存
        saveSelectedGroupId(group.id)
        
        // 少し遅延してからモーダルを閉じる（選択の視覚的フィードバックのため）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func loadGroupChats() {
        isLoading = true
        
        groupChatManager.fetchGroupList { groups, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let groups = groups {
                    self.groupChats = groups
                    self.loadGroupUnreadCounts()
                    
                    // 選択中のグループが削除された場合は新しいグループを選択
                    if !groups.contains(where: { $0.id == self.selectedGroupId }) {
                        self.selectedGroupId = groups.first?.id ?? ""
                    }
                } else {
                    self.groupChats = []
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
                    if self.selectedGroupId == group.id {
                        let remainingGroups = self.groupChats.filter { $0.id != group.id }
                        self.selectedGroupId = remainingGroups.first?.id ?? ""
                    }
                    
                    // ローカルの状態を更新
                    if let index = self.groupChats.firstIndex(where: { $0.id == group.id }) {
                        self.groupChats.remove(at: index)
                    }
                    self.groupUnreadCounts.removeValue(forKey: group.id)
                    
                    // データを再読み込み
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

#Preview {
    GroupChatListModalView(
        groupChats: .constant([
            GroupChatInfo(
                id: "1",
                name: "推し全員",
                memberIds: ["oshi1", "oshi2"],
                createdAt: Date().timeIntervalSince1970,
                lastMessageTime: Date().timeIntervalSince1970,
                lastMessage: "こんにちは！"
            ),
            GroupChatInfo(
                id: "2",
                name: "お気に入りグループ",
                memberIds: ["oshi1", "oshi3"],
                createdAt: Date().timeIntervalSince1970,
                lastMessageTime: Date().timeIntervalSince1970 - 3600,
                lastMessage: "楽しかったね！"
            )
        ]),
        selectedGroupId: .constant("1"),
        allOshiList: [
            Oshi(id: "oshi1", name: "推し1", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
            Oshi(id: "oshi2", name: "推し2", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil),
            Oshi(id: "oshi3", name: "推し3", imageUrl: nil, backgroundImageUrl: nil, memo: nil, createdAt: nil)
        ]
    )
}
