//
//  GroupChatListView.swift
//  osimono
//
//  グループチャット一覧画面
//

import SwiftUI
import Firebase
import FirebaseAuth

struct GroupChatListView: View {
    @StateObject private var groupChatManager = GroupChatManager()
    @State private var groupChats: [GroupChatInfo] = []
    @State private var isLoading = true
    @State private var showCreateGroup = false
    @State private var unreadCounts: [String: Int] = [:]
    @State private var allOshiList: [Oshi] = []
    @Environment(\.presentationMode) var presentationMode
    
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
                    
                    if isLoading {
                        loadingView
                    } else if groupChats.isEmpty {
                        emptyStateView
                    } else {
                        groupChatListView
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
        .sheet(isPresented: $showCreateGroup) {
            CreateGroupChatView(
                allOshiList: allOshiList,
                onCreate: { groupInfo in
                    loadData()
                }
            )
        }
    }
    
    private var headerView: some View {
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
            
            Text("グループチャット")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: {
                generateHapticFeedback()
                showCreateGroup = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(primaryColor)
            }
            .padding(.trailing)
        }
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 1, y: 1)
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var groupChatListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(groupChats, id: \.id) { group in
                    NavigationLink(destination: destinationView(for: group)) {
                        GroupChatRowView(
                            group: group,
                            unreadCount: unreadCounts[group.id] ?? 0,
                            allOshiList: allOshiList
                        )
                    }
                    .navigationBarHidden(true)
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 80)
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .background(Color.white)
    }
    
    private func destinationView(for group: GroupChatInfo) -> some View {
        OshiGroupChatView(groupId: group.id)
            .onDisappear {
                // グループチャット画面から戻った時に未読数を更新
                loadUnreadCounts()
            }
    }
    
    private func loadData() {
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
            var oshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any] {
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
            }
            
            DispatchQueue.main.async {
                self.allOshiList = oshis
            }
        }
    }
    
    private func loadGroupChats() {
        groupChatManager.fetchGroupList { groups, error in
            DispatchQueue.main.async {
                if let groups = groups {
                    self.groupChats = groups
                    self.loadUnreadCounts()
                }
                self.isLoading = false
            }
        }
    }
    
    private func loadUnreadCounts() {
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
            self.unreadCounts = tempUnreadCounts
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// グループチャット行ビュー
struct GroupChatRowView: View {
    let group: GroupChatInfo
    let unreadCount: Int
    let allOshiList: [Oshi]
    
    var groupMembers: [Oshi] {
        return allOshiList.filter { group.memberIds.contains($0.id) }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // グループアイコン
            groupIconView
                .frame(width: 56, height: 56)
            
            // グループ情報
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(group.name.isEmpty ? "グループチャット" : group.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(formatTime(group.lastMessageTime))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(group.lastMessage ?? "まだメッセージがありません")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        unreadBadge
                    }
                }
                
                // メンバー名表示
                Text(groupMembers.map { $0.name }.joined(separator: "、"))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
    
    private var groupIconView: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 56, height: 56)
            
            if groupMembers.isEmpty {
                Image(systemName: "person.2.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            } else if groupMembers.count == 1 {
                // 1人の場合は通常のプロフィール画像
                if let imageUrl = groupMembers[0].imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .overlay(
                                    Text(String(groupMembers[0].name.prefix(1)))
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Text(String(groupMembers[0].name.prefix(1)))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gray)
                        )
                }
            } else {
                // 複数人の場合は重ねて表示
                ForEach(Array(groupMembers.prefix(3).enumerated()), id: \.element.id) { index, oshi in
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(oshi.name.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.gray)
                        )
                        .offset(
                            x: index == 0 ? -8 : (index == 1 ? 8 : 0),
                            y: index == 0 ? -8 : (index == 1 ? -8 : 10)
                        )
                }
            }
        }
    }
    
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

#Preview {
    GroupChatListView()
}
