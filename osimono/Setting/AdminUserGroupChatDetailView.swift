
//
//  AdminUserGroupChatDetailView.swift
//  osimono
//
//  管理者向けユーザーのグループチャット詳細画面
//

import SwiftUI
import Firebase
import FirebaseDatabase

struct AdminUserGroupChatDetailView: View {
    @Environment(\.presentationMode) var presentationMode
    let user: AdminUser
    
    @State private var selectedGroup: GroupChatInfo?
    @State private var messages: [GroupChatMessage] = []
    @State private var isLoadingMessages = false
    @State private var userOshis: [Oshi] = []
    
    private let primaryColor = Color(.systemPink)
    private let database = Database.database().reference()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                
                if user.groupChats.isEmpty {
                    emptyStateView
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        // 左側：グループリスト
                        groupListView
                            .frame(width: UIScreen.main.bounds.width * 0.35)
                        
                        // 右側：チャット内容
                        if let group = selectedGroup {
                            chatContentView(group: group)
                                .frame(maxWidth: .infinity)
                        } else {
                            noGroupSelectedView
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadUserOshis()
            if let firstGroup = user.groupChats.first {
                selectedGroup = firstGroup
                loadMessages(for: firstGroup)
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
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
                
                VStack(spacing: 2) {
                    Text("ユーザーグループ詳細")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("ID: \(user.id)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                .frame(width: 60)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 統計情報
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(user.groupChats.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(primaryColor)
                    Text("グループ")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                VStack(spacing: 2) {
                    Text("\(totalMessages)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.green)
                    Text("総メッセージ")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                VStack(spacing: 2) {
                    Text("\(userOshis.count)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Text("推し")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
    
    private var totalMessages: Int {
        // この値は実際にはメッセージ数をカウントする必要がありますが、
        // ここでは簡単な推定値を使用
        return user.groupChats.count * 10 // 仮の値
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("グループチャットがありません")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("このユーザーはまだグループチャットを作成していません")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var groupListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // グループリストヘッダー
            Text("グループ一覧")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(user.groupChats, id: \.id) { group in
                        groupRowView(group: group)
                            .onTapGesture {
                                selectedGroup = group
                                loadMessages(for: group)
                            }
                        
                        if group.id != user.groupChats.last?.id {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(Color(.systemGray6))
    }
    
    private func groupRowView(group: GroupChatInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.name.isEmpty ? "グループチャット" : group.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if selectedGroup?.id == group.id {
                    Circle()
                        .fill(primaryColor)
                        .frame(width: 8, height: 8)
                }
            }
            
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("\(group.memberIds.count)人")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if group.lastMessageTime > 0 {
                    Text(formatDate(group.lastMessageTime))
                        .font(.system(size: 10))
//                        .foregroundColor(.tertiary)
                }
            }
            
            if let lastMessage = group.lastMessage, !lastMessage.isEmpty {
                Text(lastMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            selectedGroup?.id == group.id ?
            Color.blue.opacity(0.1) : Color.clear
        )
    }
    
    private var noGroupSelectedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("グループを選択してください")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("左側のリストからグループを選択すると、チャット内容が表示されます")
                .font(.subheadline)
//                .foregroundColor(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func chatContentView(group: GroupChatInfo) -> some View {
        VStack(spacing: 0) {
            // チャットヘッダー
            VStack(spacing: 8) {
                HStack {
                    Text(group.name.isEmpty ? "グループチャット" : group.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isLoadingMessages {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                HStack {
                    Text("メンバー: \(getMemberNames(memberIds: group.memberIds).joined(separator: ", "))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            Divider()
            
            // メッセージリスト
            if messages.isEmpty && !isLoadingMessages {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("メッセージがありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages, id: \.id) { message in
                            AdminMessageRow(
                                message: message,
                                oshis: userOshis
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    private func getMemberNames(memberIds: [String]) -> [String] {
        return memberIds.compactMap { memberId in
            userOshis.first(where: { $0.id == memberId })?.name ?? "不明"
        }
    }
    
    private func loadUserOshis() {
        database.child("oshis").child(user.id).observe(.value) { snapshot in
            var oshis: [Oshi] = []
            
            for child in snapshot.children {
                guard let childSnapshot = child as? DataSnapshot,
                      let value = childSnapshot.value as? [String: Any] else {
                    continue
                }
                
                let id = childSnapshot.key
                let name = value["name"] as? String ?? "名前なし"
                let imageUrl = value["imageUrl"] as? String
                
                let oshi = Oshi(
                    id: id,
                    name: name,
                    imageUrl: imageUrl,
                    backgroundImageUrl: value["backgroundImageUrl"] as? String,
                    memo: value["memo"] as? String,
                    createdAt: value["createdAt"] as? TimeInterval,
                    personality: value["personality"] as? String,
                    interests: value["interests"] as? [String],
                    speaking_style: value["speaking_style"] as? String,
                    birthday: value["birthday"] as? String,
                    height: value["height"] as? Int,
                    favorite_color: value["favorite_color"] as? String,
                    favorite_food: value["favorite_food"] as? String,
                    disliked_food: value["disliked_food"] as? String,
                    hometown: value["hometown"] as? String,
                    gender: value["gender"] as? String,
                    user_nickname: value["user_nickname"] as? String
                )
                
                oshis.append(oshi)
            }
            
            DispatchQueue.main.async {
                self.userOshis = oshis
            }
        }
    }
    
    private func loadMessages(for group: GroupChatInfo) {
        isLoadingMessages = true
        messages = []
        
        database.child("groupChats")
            .child(user.id)
            .child(group.id)
            .child("messages")
            .queryOrdered(byChild: "timestamp")
            .observe(.value) { snapshot in
                var loadedMessages: [GroupChatMessage] = []
                
                for child in snapshot.children {
                    guard let childSnapshot = child as? DataSnapshot,
                          let messageDict = childSnapshot.value as? [String: Any],
                          let message = GroupChatMessage.fromDictionary(messageDict) else {
                        continue
                    }
                    
                    loadedMessages.append(message)
                }
                
                DispatchQueue.main.async {
                    self.messages = loadedMessages.sorted { $0.timestamp < $1.timestamp }
                    self.isLoadingMessages = false
                }
            }
    }
    
    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨日"
        } else {
            formatter.dateFormat = "MM/dd"
        }
        
        return formatter.string(from: date)
    }
}

struct AdminMessageRow: View {
    let message: GroupChatMessage
    let oshis: [Oshi]
    
    private var senderInfo: (name: String, color: Color) {
        if message.isUser {
            return ("ユーザー", .blue)
        } else if let oshi = oshis.first(where: { $0.id == message.senderId }) {
            return (oshi.name, .pink)
        } else {
            return ("不明", .gray)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 送信者アイコン
            Circle()
                .fill(senderInfo.color.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(senderInfo.name.prefix(1)))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(senderInfo.color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // 送信者名と時間
                HStack {
                    Text(senderInfo.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(senderInfo.color)
                    
                    Spacer()
                    
                    Text(formatMessageTime(message.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // メッセージ内容
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
    
    private func formatMessageTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    AdminUserGroupChatDetailView(
        user: AdminUser(
            id: "sample-user-id",
            groupChats: [
                GroupChatInfo(
                    id: "group1",
                    name: "サンプルグループ1",
                    memberIds: ["oshi1", "oshi2"],
                    createdAt: Date().timeIntervalSince1970,
                    lastMessageTime: Date().timeIntervalSince1970,
                    lastMessage: "こんにちは！"
                )
            ]
        )
    )
}
