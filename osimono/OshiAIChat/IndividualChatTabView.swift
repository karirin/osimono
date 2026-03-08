//
//  IndividualChatTabView.swift
//  osimono
//
//  個人チャット専用のタブビュー - ライトモードUI/UXデザイン
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import FirebaseStorage

struct IndividualChatTabView: View {
    @StateObject private var coordinator = OshiChatCoordinator.shared
    @State private var searchText = ""
    @State private var oshiList: [Oshi] = []
    @State private var selectedOshiId: String = ""
    @State private var isLoading = true
    @State private var unreadCounts: [String: Int] = [:]
    @State private var lastMessages: [String: String] = [:]
    @State private var lastMessageTimes: [String: TimeInterval] = [:]
    @State private var showAddOshiForm = false
    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @State private var showDeleteOshiAlert = false
    @State private var oshiToDelete: Oshi?
    @State private var oshiToDeleteCompletely: Oshi?
    @State private var isDeletingOshi = false
    
    @State private var showSubscriptionPromotion = false
    @State private var helpFlag = false
    @State private var customerFlag = false
    @ObservedObject var authManager = AuthManager()
    
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    // Animation states
    @State private var headerOpacity: Double = 1
    @State private var contentAppeared = false
    
    private var shouldShowAd: Bool {
        return !isAdmin && !subscriptionManager.isSubscribed
    }
    
    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    
    // 明るいカラーパレット
    private let backgroundColor = Color(hex: "F8F9FD")
    private let surfaceColor = Color.white
    private let cardColor = Color.white
    private let textPrimary = Color(hex: "1A1D26")
    private let textSecondary = Color(hex: "6B7280")
    private let accentGradient = LinearGradient(
        colors: [Color(hex: "FF7EB3"), Color(hex: "FF758C")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let subtleGradient = LinearGradient(
        colors: [Color(hex: "FF7EB3").opacity(0.12), Color(hex: "FF758C").opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let softPink = Color(hex: "FFF0F5")
    private let softPurple = Color(hex: "F5F0FF")
    
    private let adminUserIds = [
        "3UDNienzhkdheKIy77lyjMJhY4D3",
        "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    ]
    
    private func checkAdminStatus() {
        guard let userID = Auth.auth().currentUser?.uid else {
            isAdmin = false
            isCheckingAdminStatus = false
            return
        }
        
        isAdmin = adminUserIds.contains(userID)
        isCheckingAdminStatus = false
        
        if isAdmin {
            print("🔑 管理者としてログイン中: \(userID)")
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundView
                
                VStack(spacing: 0) {
                    // Header
                    HeaderView
                    
                    // Ad banner (if applicable)
                    if !isAdmin && shouldShowAd {
                        BannerAdChatListView()
                            .frame(height: 60)
                            .background(surfaceColor)
                    }
                    
                    // Main content
                    if isLoading {
                        LoadingView
                    } else if oshiList.isEmpty {
                        EmptyStateView
                    } else {
                        ChatListView
                    }
                }
                
                // Deleting overlay
                if isDeletingOshi {
                    DeletingOverlay
                }
                
                // Modal overlays
                if helpFlag {
                    HelpModalView(isPresented: $helpFlag)
                }
                
                if customerFlag {
                    ReviewView(isPresented: $customerFlag, helpFlag: $helpFlag)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
            checkAdminStatus()
            checkSubscriptionPromotion()
            
            withAnimation(.easeOut(duration: 0.5)) {
                contentAppeared = true
            }
            
            authManager.fetchUserFlag { userFlag, error in
                if let error = error {
                    print(error.localizedDescription)
                } else if let userFlag = userFlag {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if userFlag == 0 {
                            executeProcessEveryThreeTimes()
                        }
                    }
                }
            }
        }
        .refreshable {
            loadData()
        }
        .alert(L10n.deleteChatHistory, isPresented: $showDeleteAlert) {
                Button(L10n.delete, role: .destructive) {
                    if let oshi = oshiToDelete {
                        deleteChatHistory(for: oshi)
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteChatHistoryMessage(oshiToDelete?.name ?? ""))
            }
            // MARK: - 修正箇所: アラートの多言語対応をL10nに統一
            .alert(L10n.deleteOshiTitle, isPresented: $showDeleteOshiAlert) {
                Button(L10n.delete, role: .destructive) {
                    if let oshi = oshiToDeleteCompletely {
                        deleteOshiCompletely(oshi)
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.deleteOshiConfirmationMessage(oshiToDeleteCompletely?.name ?? ""))
            }
            .fullScreenCover(isPresented: $showAddOshiForm, onDismiss: {
                loadData()
            }) {
                AddOshiView()
            }
            .sheet(isPresented: $showSubscriptionPromotion) {
                SubscriptionPreView()
            }
        }
    
    // MARK: - Background View
    private var backgroundView: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            // Soft gradient orbs
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color(hex: "FF7EB3").opacity(0.08))
                        .frame(width: 350, height: 350)
                        .blur(radius: 80)
                        .offset(x: -geo.size.width/3, y: -50)
                    
                    Circle()
                        .fill(Color(hex: "A78BFA").opacity(0.06))
                        .frame(width: 300, height: 300)
                        .blur(radius: 70)
                        .offset(x: geo.size.width/3, y: geo.size.height/3)
                    
                    Circle()
                        .fill(Color(hex: "60A5FA").opacity(0.05))
                        .frame(width: 250, height: 250)
                        .blur(radius: 60)
                        .offset(x: 0, y: geo.size.height * 0.7)
                }
            }
        }
    }
    
    // MARK: - Header
    private var HeaderView: some View {
        VStack(spacing: 0) {
            // Main header
            HStack(alignment: .center) {
                // Add button
                Button(action: {
                    generateHapticFeedback()
                    showAddOshiForm = true
                }) {
                    ZStack {
                        Circle()
                            .fill(subtleGradient)
                            .frame(width: 46, height: 46)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(accentGradient)
                    }
                }
                .buttonStyle(ChatScaleButtonStyle())
                .shadow(color: Color(hex: "FF7EB3").opacity(0.2), radius: 8, x: 0, y: 4)
                
                Spacer()
                
                // Title
                // MARK: - 修正箇所
                Text(L10n.individualChat)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                
                Spacer()
                
                // Edit button
                if hasAnyChats {
                    Button(action: {
                        generateHapticFeedback()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditing.toggle()
                        }
                    }) {
                        // MARK: - 修正箇所
                        Text(isEditing ? L10n.done : L10n.edit)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentGradient)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(subtleGradient)
                            )
                    }
                    .buttonStyle(ChatScaleButtonStyle())
                } else {
                    Spacer()
                        .frame(width: 46)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Search bar
            if !oshiList.isEmpty {
                SearchBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .background(
            surfaceColor
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
        )
    }
    
    // MARK: - Search Bar
    private var SearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(textSecondary.opacity(0.6))
            
            // MARK: - 修正箇所
            TextField("", text: $searchText, prompt: Text(L10n.searchText)
                .foregroundColor(textSecondary.opacity(0.5)))
                .font(.system(size: 16))
                .foregroundColor(textPrimary)
                .tint(Color(hex: "FF7EB3"))
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    hideKeyboard()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(textSecondary.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "F3F4F6"))
        )
    }
    
    // MARK: - Loading View
    private var LoadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "FF7EB3").opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(contentAppeared ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: contentAppeared)
            }
            
            // MARK: - 修正箇所
            Text(L10n.loading)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var EmptyStateView: some View {
        VStack(spacing: 32) {
            // Illustration
            ZStack {
                Circle()
                    .fill(softPink)
                    .frame(width: 140, height: 140)
                
                Circle()
                    .stroke(accentGradient.opacity(0.3), lineWidth: 2)
                    .frame(width: 160, height: 160)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(accentGradient)
            }
            .opacity(contentAppeared ? 1 : 0)
            .scaleEffect(contentAppeared ? 1 : 0.8)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: contentAppeared)
            
            VStack(spacing: 12) {
                // MARK: - 修正箇所
                Text(L10n.noChatsYet)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(textPrimary)
                
                // MARK: - 修正箇所
                Text(L10n.registerOshiToChat)
                    .font(.system(size: 15))
                    .foregroundColor(textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: contentAppeared)
            
            // CTA Button
            Button(action: {
                generateHapticFeedback()
                showAddOshiForm = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    // MARK: - 修正箇所
                    Text(L10n.registerOshiButton)
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(accentGradient)
                .clipShape(Capsule())
                .shadow(color: Color(hex: "FF7EB3").opacity(0.35), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(ChatScaleButtonStyle())
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: contentAppeared)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Chat List
    private var ChatListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Add oshi card
                AddOshiCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                
                // Chat list
                ForEach(Array(filteredOshiList.enumerated()), id: \.element.id) { index, oshi in
                    if isEditing {
                        EditableRow(oshi: oshi, index: index)
                    } else {
                        NavigationLink(destination: destinationView(for: oshi)) {
                            ChatRow(
                                oshi: oshi,
                                unreadCount: unreadCounts[oshi.id] ?? 0,
                                lastMessage: lastMessages[oshi.id] ?? "まだメッセージがありません",
                                lastMessageTime: lastMessageTimes[oshi.id] ?? 0,
                                isSelected: oshi.id == selectedOshiId,
                                accentGradient: accentGradient,
                                textPrimary: textPrimary,
                                textSecondary: textSecondary
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                        .opacity(contentAppeared ? 1 : 0)
                        .offset(x: contentAppeared ? 0 : -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.05), value: contentAppeared)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.clear)
    }
    
    // MARK: - Add Oshi Card
    private var AddOshiCard: some View {
            Button(action: {
                generateHapticFeedback()
                showAddOshiForm = true
            }) {
                HStack(spacing: 16) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(subtleGradient)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accentGradient)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // MARK: - 修正箇所
                        Text(L10n.addNewOshi)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                        
                        // MARK: - 修正箇所
                        Text(L10n.registerOshiToChat)
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textSecondary.opacity(0.5))
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(cardColor)
                        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "FF7EB3").opacity(0.2), Color(hex: "FF758C").opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ChatScaleButtonStyle())
        }
    
    // MARK: - Editable Row
    private func EditableRow(oshi: Oshi, index: Int) -> some View {
        HStack(alignment: .center, spacing: 12) { // spacingを8から12に広げて窮屈さを解消
            ChatRow(
                oshi: oshi,
                unreadCount: unreadCounts[oshi.id] ?? 0,
                lastMessage: lastMessages[oshi.id] ?? L10n.noMessagesYet,
                lastMessageTime: lastMessageTimes[oshi.id] ?? 0,
                isSelected: oshi.id == selectedOshiId,
                accentGradient: accentGradient,
                textPrimary: textPrimary,
                textSecondary: textSecondary
            )
            // ChatRowの外側にあるpadding(.vertical, 4)の影響を考慮
            .padding(.vertical, 4)
            
            // Delete buttons - 縦に中央揃え
            VStack(spacing: 6) { // 間隔を調整
                // Delete chat history
                Button(action: {
                    generateHapticFeedback()
                    oshiToDelete = oshi
                    showDeleteAlert = true
                }) {
                    VStack(spacing: 0) { // アイコンと文字の間隔を詰める
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.bottom, 2)
                        
                        Text(L10n.chatHistoryShort)
                            .font(.system(size: 8, weight: .bold)) // サイズを微調整
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(Color(hex: "F59E0B"))
                    .frame(width: 50, height: 40) // 幅を広げ、高さを46→40に縮小
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous) // 角丸を少し大きく
                            .fill(Color(hex: "FEF3C7"))
                    )
                }
                
                // Delete oshi
                Button(action: {
                    generateHapticFeedback()
                    oshiToDeleteCompletely = oshi
                    showDeleteOshiAlert = true
                }) {
                    VStack(spacing: 0) {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.bottom, 2)
                        
                        Text(L10n.deleteOshiButton)
                            .font(.system(size: 8, weight: .bold))
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(Color(hex: "EF4444"))
                    .frame(width: 50, height: 40) // 幅を広げ、高さを46→40に縮小
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hex: "FEE2E2"))
                    )
                }
            }
            .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        // アニメーション時の挙動を安定させる
        .contentShape(Rectangle())
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity.combined(with: .move(edge: .trailing))
        ))
    }
    
    // MARK: - Deleting Overlay
    private var DeletingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "FF7EB3").opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(contentAppeared ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: contentAppeared)
                }
                
                // MARK: - 修正箇所
                Text(L10n.deletingOshi)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textPrimary)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
        }
    }
    
    // MARK: - Helper Properties
    private var hasAnyChats: Bool {
        return oshiList.contains { oshi in
            if let lastTime = lastMessageTimes[oshi.id], lastTime > 0 {
                return true
            }
            return false
        }
    }
    
    private var filteredOshiList: [Oshi] {
        let filteredList = searchText.isEmpty ? oshiList : oshiList.filter {
            $0.name.lowercased().contains(searchText.lowercased())
        }
        
        return filteredList.sorted { oshi1, oshi2 in
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
    
    // MARK: - Functions
    private func checkSubscriptionPromotion() {
        if isAdmin || subscriptionManager.isSubscribed {
            return
        }
        
        let currentCount = UserDefaults.standard.integer(forKey: "chatListViewCount")
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: "chatListViewCount")
        
        if newCount % 5 == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showSubscriptionPromotion = true
            }
        }
    }
    
    func executeProcessEveryThreeTimes() {
        let count = UserDefaults.standard.integer(forKey: "launchCount") + 1
        UserDefaults.standard.set(count, forKey: "launchCount")
        
        if count % 10 == 0 {
            customerFlag = true
        }
    }
    
    private func destinationView(for oshi: Oshi) -> some View {
        let viewModel = OshiViewModel(oshi: oshi)
        return OshiAIChatView(viewModel: viewModel, oshiItem: nil)
            .onDisappear {
                loadUnreadCounts()
                loadLastMessages()
                loadSelectedOshiId()
            }
    }
    
    private func loadData() {
        isLoading = true
        loadOshiList()
        loadSelectedOshiId()
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
    
    private func deleteChatHistory(for oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
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
                    self.lastMessages[oshi.id] = "まだメッセージがありません"
                    self.lastMessageTimes[oshi.id] = 0
                    self.unreadCounts[oshi.id] = 0
                    
                    let userRef = Database.database().reference().child("users").child(userId)
                    userRef.child("lastReadTimestamps").child(oshi.id).removeValue()
                }
            }
        }
    }
    
    private func deleteOshiCompletely(_ oshi: Oshi) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isDeletingOshi = true
        
        let dispatchGroup = DispatchGroup()
        var deletionError: Error? = nil
        
        dispatchGroup.enter()
        let oshiRef = Database.database().reference().child("oshis").child(userId).child(oshi.id)
        oshiRef.removeValue { error, _ in
            if let error = error { deletionError = error }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let chatRef = Database.database().reference().child("oshiChats").child(userId).child(oshi.id)
        chatRef.removeValue { error, _ in
            if let error = error { deletionError = error }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let itemsRef = Database.database().reference().child("oshiItems").child(userId).child(oshi.id)
        itemsRef.removeValue { error, _ in
            if let error = error { deletionError = error }
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let storageRef = Storage.storage().reference().child("oshis").child(userId).child(oshi.id)
        storageRef.delete { _ in
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.child("lastReadTimestamps").child(oshi.id).removeValue { _, _ in
            dispatchGroup.leave()
        }
        
        dispatchGroup.enter()
        userRef.child("selectedOshiId").observeSingleEvent(of: .value) { snapshot in
            if let selectedOshiId = snapshot.value as? String, selectedOshiId == oshi.id {
                let oshisRef = Database.database().reference().child("oshis").child(userId)
                oshisRef.observeSingleEvent(of: .value) { oshiSnapshot in
                    var newSelectedId = "default"
                    
                    for child in oshiSnapshot.children {
                        if let childSnapshot = child as? DataSnapshot,
                           childSnapshot.key != oshi.id {
                            newSelectedId = childSnapshot.key
                            break
                        }
                    }
                    
                    userRef.updateChildValues(["selectedOshiId": newSelectedId]) { _, _ in
                        dispatchGroup.leave()
                    }
                }
            } else {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isDeletingOshi = false
            
            if deletionError == nil {
                if let index = self.oshiList.firstIndex(where: { $0.id == oshi.id }) {
                    self.oshiList.remove(at: index)
                }
                self.lastMessages.removeValue(forKey: oshi.id)
                self.lastMessageTimes.removeValue(forKey: oshi.id)
                self.unreadCounts.removeValue(forKey: oshi.id)
                
                if self.selectedOshiId == oshi.id {
                    self.selectedOshiId = self.oshiList.first?.id ?? ""
                }
                
                self.loadData()
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

// MARK: - Chat Row
struct ChatRow: View {
    let oshi: Oshi
    let unreadCount: Int
    let lastMessage: String
    let lastMessageTime: TimeInterval
    let isSelected: Bool
    let accentGradient: LinearGradient
    let textPrimary: Color
    let textSecondary: Color
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                if let imageUrl = oshi.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure(_):
                            defaultAvatar
                        case .empty:
                            ProgressView()
                                .tint(Color(hex: "FF7EB3"))
                        @unknown default:
                            defaultAvatar
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                } else {
                    defaultAvatar
                }
                
                // Selected indicator
                if isSelected {
                    Circle()
                        .stroke(accentGradient, lineWidth: 3)
                        .frame(width: 64, height: 64)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(oshi.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(textPrimary)
                    
                    if isSelected {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(accentGradient)
                    }
                    
                    Spacer()
                    
                    // Time
                    if lastMessageTime > 0 {
                        Text(formatTime(lastMessageTime))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary.opacity(0.7))
                    }
                }
                
                HStack {
                    Text(lastMessage)
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Unread badge
                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentGradient)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ?
                        AnyShapeStyle(accentGradient.opacity(0.4)) :
                        AnyShapeStyle(Color.clear),
                    lineWidth: 2
                )
        )
        .padding(.vertical, 4)
    }
    
    private var defaultAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FF7EB3").opacity(0.2), Color(hex: "FF758C").opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            
            Text(String(oshi.name.prefix(1)))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(accentGradient)
        }
    }
    
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000)
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return NSLocalizedString("yesterday", comment: "Yesterday")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Scale Button Style
struct ChatScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    IndividualChatTabView()
}
