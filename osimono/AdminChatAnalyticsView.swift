//
//  AdminChatAnalyticsView.swift
//  osimono
//
//  Created by Developer on 2025/06/22.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase

// 管理者用チャット分析ビュー
struct AdminChatAnalyticsView: View {
    @StateObject private var viewModel = AdminChatAnalyticsViewModel()
    @State private var selectedTimeRange = TimeRange.last24Hours
    @State private var selectedOshi: String = "all"
    @State private var searchText = ""
    @State private var showingChatDetail = false
    @State private var selectedChatSession: ChatAnalyticsData?
    
    enum TimeRange: String, CaseIterable {
        case last24Hours = "24時間"
        case lastWeek = "1週間"
        case lastMonth = "1ヶ月"
        case all = "全期間"
        
        var timeInterval: TimeInterval {
            switch self {
            case .last24Hours: return 24 * 60 * 60
            case .lastWeek: return 7 * 24 * 60 * 60
            case .lastMonth: return 30 * 24 * 60 * 60
            case .all: return 0
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // フィルター部分
                    filterSection
                    
                    // 統計情報
                    if !viewModel.isLoading {
                        statisticsSection
                    }
                    
                    // 検索バー
                    SearchBar(text: $searchText)
                        .padding(.horizontal)
                    
                    // ローディング表示 or チャット一覧
                    if viewModel.isLoading {
                        ProgressView("読み込み中...")
                            .frame(height: 200)
                    } else {
                        chatListSection
                    }
                }
            }
            .navigationTitle("チャット分析")
            .onAppear {
                loadData()
            }
            .onChange(of: selectedTimeRange) { _ in loadData() }
            .onChange(of: selectedOshi) { _ in loadData() }
            .sheet(isPresented: $showingChatDetail) {
                if let session = selectedChatSession {
                    ChatDetailView(chatSession: session)
                }
            }
            .refreshable {
                loadData()
            }
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 12) {
            // 時間範囲選択
            Picker("期間", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // 推し選択
            HStack {
                Text("推し:")
                Picker("推し選択", selection: $selectedOshi) {
                    Text("全ての推し").tag("all")
                    ForEach(viewModel.oshiList, id: \.id) { oshi in
                        Text(oshi.name).tag(oshi.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var statisticsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(title: "総会話数", value: "\(viewModel.totalChats)")
            StatCard(title: "アクティブユーザー", value: "\(viewModel.activeUsers)")
            StatCard(title: "平均会話長", value: String(format: "%.1f", viewModel.averageConversationLength))
        }
        .padding(.horizontal)
    }
    
    private var chatListSection: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredChatSessions) { session in
                AdminChatSessionRow(session: session)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    .onTapGesture {
                        selectedChatSession = session
                        showingChatDetail = true
                    }
            }
            
            // データが空の場合の表示
            if filteredChatSessions.isEmpty && !viewModel.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("チャットデータがありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("条件を変更して再度お試しください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            }
        }
    }
    
    private var filteredChatSessions: [ChatAnalyticsData] {
        let sessions = viewModel.chatSessions
        
        if searchText.isEmpty {
            return sessions
        } else {
            return sessions.filter { session in
                session.oshiName.localizedCaseInsensitiveContains(searchText) ||
                session.lastMessage.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func loadData() {
        viewModel.loadAnalyticsData(
            timeRange: selectedTimeRange.timeInterval,
            oshiId: selectedOshi == "all" ? nil : selectedOshi
        )
    }
}

// 統計カード
struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// 検索バー
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("推しの名前やメッセージで検索", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

// 管理者用チャットセッション行
struct AdminChatSessionRow: View {
    let session: ChatAnalyticsData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.oshiName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(formatDate(session.lastMessageTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(session.messageCount)件")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            
            Text(session.lastMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
            
            HStack {
                Label("ユーザー: \(session.anonymizedUserId)", systemImage: "person.crop.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if session.hasUserPersonalInfo {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .help("個人情報が含まれている可能性があります")
                }
            }
        }
        .padding()
    }
    
    private func formatDate(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

// チャット詳細ビュー
struct ChatDetailView: View {
    let chatSession: ChatAnalyticsData
    @StateObject private var detailViewModel = ChatDetailViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // セッション情報
                VStack(alignment: .leading, spacing: 8) {
                    Text("推し: \(chatSession.oshiName)")
                        .font(.headline)
                    Text("ユーザー: \(chatSession.anonymizedUserId)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("メッセージ数: \(chatSession.messageCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                
                // メッセージ一覧
                if detailViewModel.isLoading {
                    ProgressView("メッセージを読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(detailViewModel.messages, id: \.id) { message in
                                AdminChatBubble(message: message)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("チャット詳細")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("閉じる") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .onAppear {
            detailViewModel.loadMessages(
                userId: chatSession.userId,
                oshiId: chatSession.oshiId
            )
        }
    }
}

// 管理者用チャットバブル
struct AdminChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top) {
            if message.isUser {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.content)
                        .padding(12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                Spacer()
            }
        }
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }
}

// MARK: - ViewModels

class AdminChatAnalyticsViewModel: ObservableObject {
    @Published var chatSessions: [ChatAnalyticsData] = []
    @Published var oshiList: [Oshi] = []
    @Published var isLoading = false
    @Published var totalChats = 0
    @Published var activeUsers = 0
    @Published var averageConversationLength: Double = 0.0
    
    private let database = Database.database().reference()
    
    func loadAnalyticsData(timeRange: TimeInterval, oshiId: String?) {
        isLoading = true
        
        // まず推しリストを取得
        loadOshiList { [weak self] in
            self?.loadChatAnalytics(timeRange: timeRange, oshiId: oshiId)
        }
    }
    
    private func loadOshiList(completion: @escaping () -> Void) {
        database.child("oshis").observeSingleEvent(of: .value) { [weak self] snapshot in
            var oshis: [Oshi] = []
            
            for userSnapshot in snapshot.children {
                guard let userSnapshot = userSnapshot as? DataSnapshot else { continue }
                
                for oshiSnapshot in userSnapshot.children {
                    guard let oshiSnapshot = oshiSnapshot as? DataSnapshot,
                          let oshiData = oshiSnapshot.value as? [String: Any] else { continue }
                    
                    let oshi = Oshi(
                        id: oshiSnapshot.key,
                        name: oshiData["name"] as? String ?? "名前なし",
                        imageUrl: oshiData["imageUrl"] as? String,
                        backgroundImageUrl: oshiData["backgroundImageUrl"] as? String,
                        memo: oshiData["memo"] as? String,
                        createdAt: oshiData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    )
                    
                    // 重複チェック
                    if !oshis.contains(where: { $0.name == oshi.name }) {
                        oshis.append(oshi)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self?.oshiList = oshis.sorted { $0.name < $1.name }
                completion()
            }
        }
    }
    
    private func loadChatAnalytics(timeRange: TimeInterval, oshiId: String?) {
        let currentTime = Date().timeIntervalSince1970
        let cutoffTime = timeRange > 0 ? currentTime - timeRange : 0
        
        database.child("oshiChats").observeSingleEvent(of: .value) { [weak self] snapshot in
            var sessions: [ChatAnalyticsData] = []
            var userIds = Set<String>()
            var totalMessages = 0
            var conversationLengths: [Int] = []
            
            for userSnapshot in snapshot.children {
                guard let userSnapshot = userSnapshot as? DataSnapshot else { continue }
                let userId = userSnapshot.key
                userIds.insert(userId)
                
                for oshiSnapshot in userSnapshot.children {
                    guard let oshiSnapshot = oshiSnapshot as? DataSnapshot else { continue }
                    let currentOshiId = oshiSnapshot.key
                    
                    // 特定の推しでフィルターする場合
                    if let filterOshiId = oshiId, filterOshiId != currentOshiId {
                        continue
                    }
                    
                    var messages: [ChatMessage] = []
                    var lastMessageTime: TimeInterval = 0
                    var lastMessageContent = ""
                    
                    for messageSnapshot in oshiSnapshot.children {
                        guard let messageSnapshot = messageSnapshot as? DataSnapshot,
                              let messageData = messageSnapshot.value as? [String: Any],
                              let message = ChatMessage.fromDictionary(messageData) else { continue }
                        
                        // 時間範囲でフィルター
                        if message.timestamp >= cutoffTime {
                            messages.append(message)
                            totalMessages += 1
                            
                            if message.timestamp > lastMessageTime {
                                lastMessageTime = message.timestamp
                                lastMessageContent = message.content
                            }
                        }
                    }
                    
                    if !messages.isEmpty {
                        conversationLengths.append(messages.count)
                        
                        // 推し名を取得
                        let oshiName = self?.oshiList.first(where: { $0.id == currentOshiId })?.name ?? "不明な推し"
                        
                        let sessionData = ChatAnalyticsData(
                            id: "\(userId)_\(currentOshiId)",
                            userId: userId,
                            oshiId: currentOshiId,
                            oshiName: oshiName,
                            messageCount: messages.count,
                            lastMessage: lastMessageContent,
                            lastMessageTime: lastMessageTime,
                            anonymizedUserId: self?.anonymizeUserId(userId) ?? "匿名ユーザー",
                            hasUserPersonalInfo: self?.detectPersonalInfo(in: messages) ?? false
                        )
                        
                        sessions.append(sessionData)
                    }
                }
            }
            
            // 統計計算
            let avgLength = conversationLengths.isEmpty ? 0.0 : Double(conversationLengths.reduce(0, +)) / Double(conversationLengths.count)
            
            DispatchQueue.main.async {
                self?.chatSessions = sessions.sorted { $0.lastMessageTime > $1.lastMessageTime }
                self?.totalChats = sessions.count
                self?.activeUsers = userIds.count
                self?.averageConversationLength = avgLength
                self?.isLoading = false
            }
        }
    }
    
    private func anonymizeUserId(_ userId: String) -> String {
        let hash = userId.hash
        return "User_\(String(abs(hash)).prefix(6))"
    }
    
    private func detectPersonalInfo(in messages: [ChatMessage]) -> Bool {
        let personalInfoPatterns = [
            "電話番号", "住所", "メール", "本名", "年齢", "生年月日",
            "@", "tel:", "http", "www"
        ]
        
        return messages.contains { message in
            personalInfoPatterns.contains { pattern in
                message.content.lowercased().contains(pattern.lowercased())
            }
        }
    }
}

class ChatDetailViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    private let database = Database.database().reference()
    
    func loadMessages(userId: String, oshiId: String) {
        isLoading = true
        
        let chatRef = database.child("oshiChats").child(userId).child(oshiId)
        chatRef.queryOrdered(byChild: "timestamp").observeSingleEvent(of: .value) { [weak self] snapshot in
            var messages: [ChatMessage] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let messageDict = childSnapshot.value as? [String: Any],
                   let message = ChatMessage.fromDictionary(messageDict) {
                    messages.append(message)
                }
            }
            
            DispatchQueue.main.async {
                self?.messages = messages.sorted { $0.timestamp < $1.timestamp }
                self?.isLoading = false
            }
        }
    }
}

// MARK: - Data Models

struct ChatAnalyticsData: Identifiable {
    let id: String
    let userId: String
    let oshiId: String
    let oshiName: String
    let messageCount: Int
    let lastMessage: String
    let lastMessageTime: TimeInterval
    let anonymizedUserId: String
    let hasUserPersonalInfo: Bool
}

// MARK: - Preview

#Preview {
    AdminChatAnalyticsView()
}
