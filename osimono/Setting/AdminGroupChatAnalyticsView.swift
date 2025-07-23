//
//  AdminGroupChatAnalyticsView.swift
//  osimono
//
//  管理者向けグループチャット分析画面
//

import SwiftUI
import Firebase
import FirebaseDatabase

struct AdminGroupChatAnalyticsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var users: [AdminUser] = []
    @State private var isLoading = true
    @State private var selectedUser: AdminUser?
    @State private var showingUserDetail = false
    @State private var searchText = ""
    
    private let primaryColor = Color(.systemPink)
    private let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                if isLoading {
                    loadingView
                } else {
                    // メインコンテンツ
                    mainContentView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadUsers()
        }
        .sheet(isPresented: $showingUserDetail) {
            if let user = selectedUser {
                AdminUserGroupChatDetailView(user: user)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("戻る")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("グループチャット分析")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 管理者バッジ
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                .frame(width: 60)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            // 検索バー
            if !users.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .padding(.leading, 12)
                    
                    TextField("ユーザーIDで検索", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.vertical, 8)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 12)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("ユーザーデータを読み込み中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var mainContentView: some View {
        VStack(spacing: 16) {
            // 統計サマリー
            statisticsSummaryView
            
            // ユーザーリスト
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredUsers, id: \.id) { user in
                        userRowView(user: user)
                            .onTapGesture {
                                selectedUser = user
                                showingUserDetail = true
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
    
    private var statisticsSummaryView: some View {
        HStack(spacing: 16) {
            StatCard1(
                title: "総ユーザー数",
                value: "\(users.count)",
                icon: "person.3.fill",
                color: .blue
            )
            
            StatCard1(
                title: "アクティブユーザー",
                value: "\(users.filter { !$0.groupChats.isEmpty }.count)",
                icon: "message.circle.fill",
                color: .green
            )
            
            StatCard1(
                title: "総グループ数",
                value: "\(users.reduce(0) { $0 + $1.groupChats.count })",
                icon: "person.2.circle.fill",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var filteredUsers: [AdminUser] {
        if searchText.isEmpty {
            return users.sorted { user1, user2 in
                let groupCount1 = user1.groupChats.count
                let groupCount2 = user2.groupChats.count
                return groupCount1 > groupCount2
            }
        } else {
            return users.filter { user in
                user.id.localizedCaseInsensitiveContains(searchText)
            }.sorted { user1, user2 in
                let groupCount1 = user1.groupChats.count
                let groupCount2 = user2.groupChats.count
                return groupCount1 > groupCount2
            }
        }
    }
    
    private func userRowView(user: AdminUser) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ユーザーID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(user.id)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("グループ数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(user.groupChats.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(user.groupChats.isEmpty ? .secondary : primaryColor)
                }
            }
            
            if !user.groupChats.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近のグループ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(user.groupChats.prefix(3)), id: \.id) { group in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(primaryColor.opacity(0.2))
                                .frame(width: 8, height: 8)
                            
                            Text(group.name.isEmpty ? "グループチャット" : group.name)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(group.memberIds.count)人")
                                .font(.system(size: 12))
//                                .foregroundColor(.tertiary)
                        }
                    }
                    
                    if user.groupChats.count > 3 {
                        Text("他 \(user.groupChats.count - 3) グループ")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.top, 4)
            }
            
            HStack {
                Spacer()
                
                HStack(spacing: 4) {
                    Text("詳細を見る")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.blue)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func loadUsers() {
        isLoading = true
        
        database.child("groupChats").observe(.value) { snapshot in
            var loadedUsers: [AdminUser] = []
            
            for userChild in snapshot.children {
                guard let userSnapshot = userChild as? DataSnapshot else { continue }
                
                let userId = userSnapshot.key
                var groupChats: [GroupChatInfo] = []
                
                for groupChild in userSnapshot.children {
                    guard let groupSnapshot = groupChild as? DataSnapshot,
                          let groupData = groupSnapshot.value as? [String: Any],
                          let infoData = groupData["info"] as? [String: Any],
                          let groupInfo = GroupChatInfo.fromDictionary(infoData) else {
                        continue
                    }
                    
                    groupChats.append(groupInfo)
                }
                
                let user = AdminUser(id: userId, groupChats: groupChats)
                loadedUsers.append(user)
            }
            
            DispatchQueue.main.async {
                self.users = loadedUsers
                self.isLoading = false
            }
        }
    }
}

struct StatCard1: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 18))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct AdminUser {
    let id: String
    let groupChats: [GroupChatInfo]
}

#Preview {
    AdminGroupChatAnalyticsView()
}
