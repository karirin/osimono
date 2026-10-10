//
//  OshiGroupChatView.swift
//  osimono
//
//  複数の推しとのグループチャット機能 - モダンUI版
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseDatabase
import Combine

enum ConversationPattern {
    case aiToAI
    case aiToGroup
    case aiToUser
}

struct OshiGroupChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var groupChatManager = GroupChatManager()
    @State private var messages: [GroupChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isInitialLoadingComplete: Bool = false
    @State private var shouldScrollToBottom: Bool = false
    @State private var showMemberSelection: Bool = false
    @State private var showRewardCompletedModal = false
    @State private var rewardAmount = 0
    @ObservedObject private var appearanceStore = ChatAppearanceStore.shared
    @State private var showAppearanceSettings = false
    
    // 新しいUI用の状態管理
    @State private var typingMembers: [String] = [] // タイピング中のメンバーID
    @State private var showReadReceipt: Bool = false
    @State private var lastSentMessageId: String? = nil
    
    // モダンカラーパレット - ダークモード対応
    private let primaryAccent = Color(red: 0.91, green: 0.42, blue: 0.58)
    private let secondaryAccent = Color(red: 0.65, green: 0.45, blue: 0.85)
    private let userBubbleGradient = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.42, blue: 0.58),
            Color(red: 0.78, green: 0.38, blue: 0.72)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private var oshiBubbleColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color.white
    }
    
    @State private var showEditGroupSheet = false
    @State private var groupInfo: GroupChatInfo?
    @State private var selectedMembers: [Oshi] = []
    @State private var allOshiList: [Oshi] = []
    
    @Binding var groupId: String
    @State private var currentGroupId = ""
    let onShowGroupList: (() -> Void)?
    @State private var groupName: String = ""
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    @State private var hasMarkedAsRead: Bool = false
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    // グループチャット リワード広告
    @State private var groupChatSendCount: Int = 0
    private let groupChatSendCountKey = "GroupChatRewardSendCount"
    private let rewardAdRequiredKey = "GroupChatRewardAdRequired"
    @State private var rewardAdRequired: Bool = false  // 広告視聴が必須かどうか（UserDefaultsで永続化）

    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    @State private var showDeleteHistoryAlert = false
    @State private var isDeletingHistory = false
    @State private var isEditingMode = false
    @State private var editingMessage: GroupChatMessage? = nil
    @State private var editingText: String = ""
    @State private var showEditMessageAlert = false
    
    // private let adminUserIds = [
    //     "3UDNienzhkdheKIy77lyjMJhY4D3",
    //     "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    // ]

    private var shouldShowAd: Bool {
        AdConfiguration.shouldShowAds(isAdmin: isAdmin, isSubscribed: subscriptionManager.isSubscribed)
    }

    private var isDeveloperMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    @State private var helpFlag: Bool = false
    @State private var customerFlag: Bool = false
    @ObservedObject var authManager = AuthManager()
    @State private var showSubscriptionSheet = false
    @State private var showGroupRewardModal = false
    @State private var isLoadingGroupRewardAd = false
    @State private var showGroupAdLoadFailedAlert = false
    
    init(groupId: Binding<String>, onShowGroupList: (() -> Void)? = nil) {
        self._groupId = groupId
        self.onShowGroupList = onShowGroupList
        _currentGroupId = State(initialValue: groupId.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            ChatAppearanceBackground(theme: appearanceStore.settings.background, photo: appearanceStore.photo)
                .ignoresSafeArea()
            
            if isInitialLoadingComplete {
                chatContent
            } else {
                loadingView
            }
            
            // モーダル群
            if showMemberSelection {
                ModernGroupMemberSelectionView(
                    isPresented: $showMemberSelection,
                    allOshiList: allOshiList,
                    selectedMembers: $selectedMembers,
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    onSave: { updateGroupMembers() }
                )
            }
            
            if showRewardCompletedModal {
                RewardCompletedModal(
                    isPresented: $showRewardCompletedModal,
                    rewardAmount: rewardAmount
                )
            }
            
            if helpFlag {
                HelpModalView(isPresented: $helpFlag)
            }

            if customerFlag {
                ReviewView(isPresented: $customerFlag, helpFlag: $helpFlag)
            }

            // リワード広告モーダル（ZStackオーバーレイ）
            if shouldShowAd && (showGroupRewardModal || rewardAdRequired) {
                GroupChatRewardAdModal(
                    onWatchAd: {
                        showGroupRewardModal = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            showGroupChatRewardAd()
                        }
                    },
                    onUpgrade: {
                        showGroupRewardModal = false
                        // rewardAdRequired は維持（サブスク加入しなければブロック継続）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showSubscriptionSheet = true
                        }
                    },
                    isAdLoading: isLoadingGroupRewardAd
                )
                .zIndex(999)
                .allowsHitTesting(true)
                .alert(NSLocalizedString("reward_ad_load_failed", comment: "Couldn't load the ad"), isPresented: $showGroupAdLoadFailedAlert) {
                    Button("OK", role: .cancel) {}
                }
            }
            
            if isDeletingHistory {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text(L10n.deletingHistory)
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black.opacity(0.7))
                        )
                    )
            }
        }
        .environment(\.chatAppearance, appearanceStore.settings)
        .sheet(isPresented: $showAppearanceSettings) {
            ChatAppearanceSettingsView()
        }
        .alert(L10n.confirmDeleteHistory, isPresented: $showDeleteHistoryAlert) {
            Button(L10n.delete, role: .destructive) { deleteGroupChatHistory() }
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.deleteGroupHistoryWarning)
        }
        .alert(L10n.editMessageTitle, isPresented: $showEditMessageAlert) {
            TextField(L10n.messageContent, text: $editingText)
            Button(L10n.save) { saveEditedMessage() }
            Button(L10n.cancel, role: .cancel) {
                editingMessage = nil
                editingText = ""
            }
        } message: {
            Text(L10n.adminEditWarning)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { isTextFieldFocused = false }
        )
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width > 80 && isInitialLoadingComplete {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { keyboardHeight = height }
        }
        .onAppear {
            checkAdminStatus()
            setupGroupChat()
            groupChatSendCount = UserDefaults.standard.integer(forKey: groupChatSendCountKey)
            // タブ切り替え後もブロック状態を復元
            if shouldShowAd {
                rewardAdRequired = UserDefaults.standard.bool(forKey: rewardAdRequiredKey)
                if rewardAdRequired {
                    showGroupRewardModal = true
                }
                RewardAdManager.shared.loadRewardedAd()
            } else {
                rewardAdRequired = false
                showGroupRewardModal = false
            }
        }
        .onChange(of: groupId) { newValue in
            guard newValue != currentGroupId else { return }
            groupChatManager.removeMessageListener(for: currentGroupId)
            messages.removeAll()
            selectedMembers.removeAll()
            hasMarkedAsRead = false
            currentGroupId = newValue
            setupGroupChat()
        }
        .onDisappear {
            markAsReadWhenDisappear()
            groupChatManager.removeMessageListener(for: groupId)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showEditGroupSheet) {
            if let group = groupInfo {
                EditGroupChatView(
                    group: group,
                    allOshiList: allOshiList,
                    onUpdate: { updatedGroup in
                        self.groupInfo = updatedGroup
                        self.groupName = updatedGroup.name
                        self.loadGroupMembers { }
                    }
                )
            }
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionPreView(source: .groupChatLimit)
        }
    }
    
    // MARK: - ローディング画面
    private var loadingView: some View {
        VStack(spacing: 0) {
            headerViewLoading
            
            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [primaryAccent.opacity(0.2), secondaryAccent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    ProgressView()
                        .scaleEffect(1.3)
                        .progressViewStyle(CircularProgressViewStyle(tint: primaryAccent))
                }
                
                Text(groupName.isEmpty ? L10n.groupChat : groupName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    private var headerViewLoading: some View {
        HStack(spacing: 14) {
            Button(action: {
                generateHapticFeedback()
                isTextFieldFocused = false
                markAsReadWhenDisappear()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    presentationMode.wrappedValue.dismiss()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    )
            }
            
            modernGroupIconView
                .frame(width: 46, height: 46)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(groupName.isEmpty ? L10n.groupChat : groupName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(L10n.membersCount(selectedMembers.count))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        )
    }
    
    // MARK: - メインコンテンツ
    private var chatContent: some View {
        VStack(spacing: 0) {
            headerView
            chatMessagesView
            inputAreaView
        }
    }
    
    // MARK: - ヘッダー
    private var headerView: some View {
        HStack(spacing: 14) {
            Button(action: {
                generateHapticFeedback()
                onShowGroupList?()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary.opacity(0.7))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        )
                    
                    modernGroupIconView
                        .frame(width: 46, height: 46)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(groupName.isEmpty ? L10n.groupChat : groupName)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            if !typingMembers.isEmpty {
                                TypingIndicatorDots()
                                Text(getTypingText())
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(primaryAccent)
                            } else {
                                Text(L10n.membersCount(selectedMembers.count))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            HStack(spacing: 8) {
                if isAdmin && !messages.isEmpty && isEditingMode {
                    Button(action: {
                        generateHapticFeedback()
                        showDeleteHistoryAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                            )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button(action: {
                    generateHapticFeedback()
                    if isEditingMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isEditingMode = false
                        }
                    } else {
                        showEditGroupSheet = true
                    }
                }) {
                    Text(isEditingMode ? L10n.done : L10n.edit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(primaryAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(primaryAccent.opacity(0.1))
                        )
                }
                
                if !isEditingMode {
                    Menu {
                        Button {
                            isTextFieldFocused = false
                            showAppearanceSettings = true
                        } label: {
                            Label("chat_appearance_title", systemImage: "paintpalette")
                        }
                        Button {
                            generateHapticFeedback()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isEditingMode = true
                            }
                        } label: {
                            Label(L10n.editMessageTitle, systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(.secondarySystemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                            )
                    }
                    .accessibilityLabel(Text("chat_settings"))
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        )
    }
    
    // モダンなグループアイコン
    private var modernGroupIconView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [primaryAccent.opacity(0.3), secondaryAccent.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if selectedMembers.isEmpty {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if selectedMembers.count == 1 {
                if let imageUrl = selectedMembers[0].imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipShape(Circle())
                        default:
                            singleMemberPlaceholder(selectedMembers[0])
                        }
                    }
                } else {
                    singleMemberPlaceholder(selectedMembers[0])
                }
            } else {
                // 複数メンバーのグリッド表示
                GeometryReader { geo in
                    let size = geo.size.width * 0.45
                    ZStack {
                        ForEach(Array(selectedMembers.prefix(4).enumerated()), id: \.element.id) { index, oshi in
                            memberMiniAvatar(oshi, size: size)
                                .offset(
                                    x: index % 2 == 0 ? -size/3 : size/3,
                                    y: index < 2 ? -size/3 : size/3
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
    
    private func singleMemberPlaceholder(_ oshi: Oshi) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [primaryAccent.opacity(0.5), secondaryAccent.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
    
    private func memberMiniAvatar(_ oshi: Oshi, size: CGFloat) -> some View {
        Group {
            if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 1.5)
                            )
                    default:
                        miniPlaceholder(oshi, size: size)
                    }
                }
            } else {
                miniPlaceholder(oshi, size: size)
            }
        }
    }
    
    private func miniPlaceholder(_ oshi: Oshi, size: CGFloat) -> some View {
        Circle()
            .fill(primaryAccent.opacity(0.3))
            .frame(width: size, height: size)
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)
            )
            .overlay(
                Circle()
                    .stroke(Color(.systemBackground), lineWidth: 1.5)
            )
    }
    
    // MARK: - チャットメッセージ
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    if messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let showTimestamp = shouldShowTimestamp(for: index)
                            
                            if showTimestamp {
                                timestampDivider(for: message.timestamp)
                            }
                            
                            ModernGroupChatBubble(
                                message: message,
                                selectedMembers: selectedMembers,
                                showReadReceipt: message.id == lastSentMessageId && showReadReceipt,
                                userBubbleGradient: userBubbleGradient,
                                primaryAccent: primaryAccent,
                                secondaryAccent: secondaryAccent,
                                oshiBubbleColor: oshiBubbleColor,
                                onEdit: isDeveloperMode ? { startEditingMessage($0) } : nil
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        // タイピングインジケーター
                        if !typingMembers.isEmpty {
                            GroupTypingBubble(
                                typingMembers: typingMembers,
                                selectedMembers: selectedMembers,
                                primaryAccent: primaryAccent,
                                secondaryAccent: secondaryAccent,
                                bubbleColor: oshiBubbleColor
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        Color.clear
                            .frame(height: 20)
                            .id("bottomMarker")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 16)
            }
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
                markAsReadAfterDelay()
            }
            .onChange(of: shouldScrollToBottom) { shouldScroll in
                if shouldScroll && !messages.isEmpty {
                    scrollToBottom(proxy: proxy)
                    shouldScrollToBottom = false
                }
            }
            .onChange(of: typingMembers) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottomMarker", anchor: .bottom)
                }
            }
            .onChange(of: keyboardHeight) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !messages.isEmpty {
                        scrollToBottom(proxy: proxy, animated: false)
                    }
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
        }
    }
    
    // 空状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 60)
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryAccent.opacity(0.2), secondaryAccent.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text(L10n.startGroupChat)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                if selectedMembers.isEmpty {
                    Text(L10n.addMembersToStart)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                } else {
                    Text(L10n.chatWithMembers(selectedMembers.count))
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            if selectedMembers.isEmpty {
                Button(action: {
                    generateHapticFeedback()
                    showMemberSelection = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .medium))
                        Text(L10n.addMembers)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [primaryAccent, secondaryAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: primaryAccent.opacity(0.3), radius: 8, y: 4)
                    )
                }
            }
            
            Spacer()
        }
    }
    
    // タイムスタンプ区切り
    private func timestampDivider(for timestamp: TimeInterval) -> some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
            
            Text(formatDateForDivider(timestamp: timestamp))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                )
            
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.vertical, 12)
    }
    
    private func shouldShowTimestamp(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentDate = Date(timeIntervalSince1970: messages[index].timestamp)
        let previousDate = Date(timeIntervalSince1970: messages[index - 1].timestamp)
        return !Calendar.current.isDate(currentDate, inSameDayAs: previousDate)
    }
    
    // MARK: - 入力エリア
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)
            
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    TextField(L10n.enterMessage, text: $inputText, axis: .vertical)
                        .focused($isTextFieldFocused)
                        .chatMessageFont(sizeOffset: 1)
                        .lineLimit(1...5)
                        .onSubmit {
                            sendMessage()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isTextFieldFocused ? primaryAccent.opacity(0.4) : Color.clear,
                            lineWidth: 1.5
                        )
                )
                
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
            )
        }
    }
    
    private var sendButton: some View {
        Button(action: {
            sendMessage()
        }) {
            ZStack {
                Circle()
                    .fill(
                        (inputText.isEmpty || isLoading || selectedMembers.isEmpty)
                        ? LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: (inputText.isEmpty || isLoading || selectedMembers.isEmpty) ? .clear : primaryAccent.opacity(0.3),
                        radius: 8,
                        y: 4
                    )
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor((inputText.isEmpty || isLoading || selectedMembers.isEmpty) ? .gray : .white)
                    .offset(y: -1)
            }
        }
        .disabled(inputText.isEmpty || isLoading || selectedMembers.isEmpty)
        .scaleEffect((inputText.isEmpty || selectedMembers.isEmpty) ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputText.isEmpty)
    }
    
    // MARK: - グループチャット リワード広告

    private func incrementGroupChatCount() {
        groupChatSendCount += 1
        UserDefaults.standard.set(groupChatSendCount, forKey: groupChatSendCountKey)
        print("📊 グループチャット送信カウント: \(groupChatSendCount)")

        if groupChatSendCount % 5 == 0 {
            rewardAdRequired = true
            UserDefaults.standard.set(true, forKey: rewardAdRequiredKey)
            showGroupRewardModal = true
        }
    }

    private func showGroupChatRewardAd() {
        guard !isLoadingGroupRewardAd else { return }

        guard !AdConfiguration.isDisabledForDevelopment else {
            unlockGroupChatAfterReward()
            return
        }

        // まだ読み込めていなければ、読み込み完了を待ってから表示する
        guard let rewardedAd = RewardAdManager.shared.rewardedAd else {
            print("⚠️ リワード広告未ロード、読み込み完了後に表示")
            isLoadingGroupRewardAd = true
            RewardAdManager.shared.loadRewardedAd { loaded in
                isLoadingGroupRewardAd = false
                if loaded {
                    showGroupChatRewardAd()
                } else {
                    showGroupAdLoadFailedAlert = true
                }
            }
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.windows.first?.rootViewController else {
            print("❌ グループチャット リワード広告: rootViewController取得失敗")
            return
        }

        let top = findTopViewControllerForAd(from: root)

        // 同じ広告を二度表示しないよう手放す（閉じたら RewardAdManager が次を読み込む）
        RewardAdManager.shared.rewardedAd = nil
        rewardedAd.present(from: top) {
            DispatchQueue.main.async {
                unlockGroupChatAfterReward()
                print("✅ グループチャット リワード広告視聴完了")
            }
        }
    }

    private func unlockGroupChatAfterReward() {
        rewardAdRequired = false
        showGroupRewardModal = false
        UserDefaults.standard.set(false, forKey: rewardAdRequiredKey)
        generateHapticFeedback()
    }

    private func findTopViewControllerForAd(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewControllerForAd(from: presented)
        }
        if let nav = viewController as? UINavigationController,
           let top = nav.topViewController {
            return findTopViewControllerForAd(from: top)
        }
        if let tab = viewController as? UITabBarController,
           let selected = tab.selectedViewController {
            return findTopViewControllerForAd(from: selected)
        }
        return viewController
    }

    // MARK: - メッセージ送信（既読・タイピング機能付き）
    private func sendMessage() {
        guard !inputText.isEmpty, !isLoading, !selectedMembers.isEmpty else { return }
        // 送信ボタンとキーボードの送信を同じ広告条件で判定する
        if shouldShowAd && rewardAdRequired {
            showGroupRewardModal = true
            return
        }
        generateHapticFeedback()
        if shouldShowAd {
            incrementGroupChatCount()
        }
        
        let userMessage = GroupChatMessage(
            id: UUID().uuidString,
            content: inputText,
            isUser: true,
            timestamp: Date().timeIntervalSince1970,
            groupId: groupId,
            senderId: "user"
        )
        
        let userInput = inputText
        lastSentMessageId = userMessage.id
        showReadReceipt = false
        inputText = ""
        
        groupChatManager.saveMessage(userMessage) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("メッセージ保存エラー: \(error.localizedDescription)")
                    self.inputText = userInput
                } else {
                    // 少し間を置いて既読表示
                    let readDelay = Double.random(in: 2.5...5.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + readDelay) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showReadReceipt = true
                        }
                        generateHapticFeedback()
                    }
                    
                    // 返信メンバーを選択
                    let respondingMemberCount = min(2, selectedMembers.count)
                    let respondingMembers = Array(selectedMembers.shuffled().prefix(Int.random(in: 1...respondingMemberCount)))
                    
                    // 既読後にタイピング開始
                    let typingDelay = readDelay + Double.random(in: 1.5...3.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            typingMembers = respondingMembers.map { $0.id }
                        }
                    }
                    
                    // AI応答を生成
                    self.generateGroupResponseWithDelay(for: userInput, members: respondingMembers, startDelay: typingDelay)
                }
            }
        }
    }
    
    private func generateGroupResponseWithDelay(for userInput: String, members: [Oshi], startDelay: TimeInterval) {
        let dispatchGroup = DispatchGroup()
        var responses: [(oshi: Oshi, content: String)] = []
        let responseLock = NSLock()
        let groupMemberNames = selectedMembers.map(\.name)
        let recentResponderNames = messages
            .suffix(8)
            .compactMap { message in
                selectedMembers.first(where: { $0.id == message.senderId })?.name
            }
        
        for oshi in members {
            dispatchGroup.enter()
            
            let recentChatHistory = Array(messages.suffix(24).map { $0.toChatMessage() })
            
            AIMessageGenerator.shared.generateGroupResponse(
                for: userInput,
                oshi: oshi,
                chatHistory: recentChatHistory,
                groupMemberNames: groupMemberNames,
                recentResponderNames: recentResponderNames
            ) { content, error in
                if let content = content, !content.isEmpty {
                    responseLock.lock()
                    responses.append((oshi: oshi, content: content))
                    responseLock.unlock()
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            // 5〜10秒のランダム遅延後に返信
            let responseDelay = Double.random(in: 5.0...10.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + responseDelay) {
                // タイピング終了
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.typingMembers = []
                }
                
                // 返信を順次送信
                self.sendResponsesSequentiallyWithAnimation(responses: responses, index: 0) {
                    // 既読表示をリセット
                    self.lastSentMessageId = nil
                    self.showReadReceipt = false
                    
                    // 追加のリアクションをチェック
                    self.checkForAIReactions()
                }
            }
        }
    }
    
    private func sendResponsesSequentiallyWithAnimation(responses: [(oshi: Oshi, content: String)], index: Int, completion: @escaping () -> Void) {
        guard index < responses.count else {
            completion()
            return
        }
        
        let response = responses[index]
        let delay = index == 0 ? 0.0 : 1.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let aiMessage = GroupChatMessage(
                id: UUID().uuidString,
                content: response.content,
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                groupId: self.groupId,
                senderId: response.oshi.id,
                senderName: response.oshi.name,
                senderImageUrl: response.oshi.imageUrl
            )
            
            self.groupChatManager.saveMessage(aiMessage) { error in
                if error == nil {
                    generateHapticFeedback()
                }
                
                DispatchQueue.main.async {
                    self.sendResponsesSequentiallyWithAnimation(responses: responses, index: index + 1, completion: completion)
                }
            }
        }
    }
    
    // MARK: - ヘルパー関数
    private func getTypingText() -> String {
        let typingOshis = selectedMembers.filter { typingMembers.contains($0.id) }
        if typingOshis.count == 1 {
            return L10n.memberTyping(name: typingOshis[0].name)
        } else if typingOshis.count > 1 {
            return L10n.multipleTyping
        }
        return ""
    }
    
    private func formatDateForDivider(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        let currentLanguage = Locale.current.languageCode ?? "en"
        formatter.locale = Locale(identifier: currentLanguage == "ja" ? "ja_JP" : "en_US")
        
        if Calendar.current.isDateInToday(date) {
            return L10n.today
        } else if Calendar.current.isDateInYesterday(date) {
            return L10n.yesterday
        } else {
            formatter.dateFormat = currentLanguage == "ja" ? "M月d日(E)" : "MMM d, E"
            return formatter.string(from: date)
        }
    }
    
    // 以下は既存のヘルパーメソッド（変更なし）
    private func deleteGroupChatHistory() {
        guard isAdmin else { return }
        isDeletingHistory = true
        
        groupChatManager.deleteGroupChatHistory(for: groupId) { error in
            DispatchQueue.main.async {
                self.isDeletingHistory = false
                if error == nil {
                    self.messages.removeAll()
                    self.generateHapticFeedback()
                }
            }
        }
    }
    
    private func checkAdminStatus() {
        isAdmin = false
        isCheckingAdminStatus = false
    }
    
    func executeProcessEveryThreeTimes() {
        let count = UserDefaults.standard.integer(forKey: "launchCount") + 1
        UserDefaults.standard.set(count, forKey: "launchCount")
        if count % 10 == 0 {
            customerFlag = true
        }
    }
    
    private func markAsReadWhenAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            markGroupChatAsRead()
        }
    }
    
    private func markAsReadWhenDisappear() {
        markGroupChatAsRead()
    }
    
    private func markAsReadAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            markGroupChatAsRead()
        }
    }
    
    private func markGroupChatAsRead() {
        guard !hasMarkedAsRead else { return }
        hasMarkedAsRead = true
        
        groupChatManager.markGroupChatAsRead(for: groupId) { error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.hasMarkedAsRead = false
            }
        }
    }
    
    private func setupGroupChat() {
        isInitialLoadingComplete = false
        
        loadOshiList {
            self.loadMessages {
                self.loadGroupMembers {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.isInitialLoadingComplete = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.markAsReadWhenAppear()
                        }
                    }
                }
            }
        }
    }
    
    private func loadOshiList(completion: @escaping () -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion()
            return
        }
        
        let ref = Database.database().reference().child("oshis").child(userId)
        ref.observeSingleEvent(of: .value) { snapshot in
            var oshis: [Oshi] = []
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let value = childSnapshot.value as? [String: Any] {
                    let id = childSnapshot.key
                    let name = value["name"] as? String ?? L10n.noName
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
                completion()
            }
        }
    }
    
    private func loadMessages(completion: @escaping () -> Void) {
        groupChatManager.fetchMessages(for: groupId) { fetchedMessages, error in
            DispatchQueue.main.async {
                if let fetchedMessages = fetchedMessages {
                    self.messages = fetchedMessages
                    if !self.isInitialLoadingComplete {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.shouldScrollToBottom = true
                        }
                    }
                } else {
                    self.messages = []
                }
                completion()
            }
        }
    }

    private func startEditingMessage(_ message: GroupChatMessage) {
        editingMessage = message
        editingText = message.content
        showEditMessageAlert = true
    }

    private func saveEditedMessage() {
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let editingMessage = editingMessage, !trimmedText.isEmpty else {
            return
        }

        guard let index = messages.firstIndex(where: { $0.id == editingMessage.id }) else {
            self.editingMessage = nil
            editingText = ""
            return
        }

        let shouldUpdateLastMessage = messages.last?.id == editingMessage.id
        let updatedMessage = GroupChatMessage(
            id: editingMessage.id,
            content: trimmedText,
            isUser: editingMessage.isUser,
            timestamp: editingMessage.timestamp,
            groupId: editingMessage.groupId,
            senderId: editingMessage.senderId,
            senderName: editingMessage.senderName,
            senderImageUrl: editingMessage.senderImageUrl
        )

        messages[index] = updatedMessage
        groupChatManager.updateMessage(updatedMessage, shouldUpdateLastMessage: shouldUpdateLastMessage) { error in
            if let error = error {
                print("グループチャットメッセージ編集エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    if let rollbackIndex = self.messages.firstIndex(where: { $0.id == editingMessage.id }) {
                        self.messages[rollbackIndex] = editingMessage
                    }
                }
            }
        }

        self.editingMessage = nil
        editingText = ""
    }

    private func loadGroupMembers(completion: @escaping () -> Void) {
        groupChatManager.fetchGroupMembers(for: groupId) { memberIds, error in
            DispatchQueue.main.async {
                if let memberIds = memberIds, !memberIds.isEmpty {
                    self.selectedMembers = self.allOshiList.filter { memberIds.contains($0.id) }
                } else {
                    self.selectedMembers = []
                }
                self.loadGroupInfo { completion() }
            }
        }
    }

    private func loadGroupInfo(completion: @escaping () -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion()
            return
        }
        
        let groupInfoRef = Database.database().reference()
            .child("groupChats")
            .child(userId)
            .child(groupId)
            .child("info")
        
        groupInfoRef.observeSingleEvent(of: .value) { snapshot in
            if let groupData = snapshot.value as? [String: Any],
               let groupInfo = GroupChatInfo.fromDictionary(groupData) {
                DispatchQueue.main.async {
                    self.groupName = groupInfo.name
                    self.groupInfo = groupInfo
                    completion()
                }
            } else {
                DispatchQueue.main.async {
                    let defaultGroupInfo = GroupChatInfo(
                        id: self.groupId,
                        name: L10n.groupChat,
                        memberIds: self.selectedMembers.map { $0.id },
                        createdAt: Date().timeIntervalSince1970,
                        lastMessageTime: 0,
                        lastMessage: nil
                    )
                    self.groupInfo = defaultGroupInfo
                    self.groupName = defaultGroupInfo.name
                    completion()
                }
            }
        }
    }
    
    private func updateGroupMembers() {
        let memberIds = selectedMembers.map { $0.id }
        groupChatManager.updateGroupMembers(groupId: groupId, memberIds: memberIds) { error in
            if error == nil {
                DispatchQueue.main.async {
                    if var currentGroupInfo = self.groupInfo {
                        currentGroupInfo = GroupChatInfo(
                            id: currentGroupInfo.id,
                            name: currentGroupInfo.name,
                            memberIds: memberIds,
                            createdAt: currentGroupInfo.createdAt,
                            lastMessageTime: currentGroupInfo.lastMessageTime,
                            lastMessage: currentGroupInfo.lastMessage
                        )
                        self.groupInfo = currentGroupInfo
                    }
                }
            }
        }
    }
    
    private func checkForAIReactions() {
        let reactionProbability = 0.7
        
        guard let lastMessage = messages.last,
              !lastMessage.isUser,
              let _ = selectedMembers.first(where: { $0.id == lastMessage.senderId }) else {
            return
        }
        
        let otherMembers = selectedMembers.filter { $0.id != lastMessage.senderId }
        
        guard !otherMembers.isEmpty else { return }
        
        if let reactor = otherMembers.randomElement(),
           Double.random(in: 0...1) < reactionProbability {
            
            let delay = Double.random(in: 2.0...5.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.generateAIReactionWithTyping(reactor: reactor, originalMessage: lastMessage)
            }
        }
    }
    
    private func generateAIReactionWithTyping(reactor: Oshi, originalMessage: GroupChatMessage) {
        // タイピング表示
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            typingMembers = [reactor.id]
        }
        
        let originalSenderName = selectedMembers.first(where: { $0.id == originalMessage.senderId })?.name ?? L10n.someone
        
        let reactionPrompt = L10n.aiReactionPrompt(
            sender: originalSenderName,
            message: originalMessage.content,
            reactor: reactor.name
        )
        
        let recentChatHistory = Array(messages.suffix(24).map { $0.toChatMessage() })
        let groupMemberNames = selectedMembers.map(\.name)
        let recentResponderNames = messages
            .suffix(8)
            .compactMap { message in
                selectedMembers.first(where: { $0.id == message.senderId })?.name
            }
        
        AIMessageGenerator.shared.generateGroupResponse(
            for: reactionPrompt,
            oshi: reactor,
            chatHistory: recentChatHistory,
            groupMemberNames: groupMemberNames,
            recentResponderNames: recentResponderNames
        ) { content, error in
            // 3〜6秒後に返信
            let responseDelay = Double.random(in: 3.0...6.0)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + responseDelay) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.typingMembers = []
                }
                
                guard let content = content, !content.isEmpty else { return }
                
                let reactionMessage = GroupChatMessage(
                    id: UUID().uuidString,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    groupId: self.groupId,
                    senderId: reactor.id,
                    senderName: reactor.name,
                    senderImageUrl: reactor.imageUrl
                )
                
                self.groupChatManager.saveMessage(reactionMessage) { error in
                    if error == nil {
                        generateHapticFeedback()
                    }
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard !messages.isEmpty else { return }
        
        if animated {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                proxy.scrollTo("bottomMarker", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottomMarker", anchor: .bottom)
        }
    }
    
    private func generateHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - モダングループチャットバブル
struct ModernGroupChatBubble: View {
    let message: GroupChatMessage
    let selectedMembers: [Oshi]
    let showReadReceipt: Bool
    let userBubbleGradient: LinearGradient
    let primaryAccent: Color
    let secondaryAccent: Color
    var oshiBubbleColor: Color = Color(.secondarySystemBackground)
    let onEdit: ((GroupChatMessage) -> Void)?

    @State private var showActionSheet = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .chatMessageFont()
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(userBubbleGradient)
                        .clipShape(ModernBubbleShape(isUser: true))
                        .shadow(color: primaryAccent.opacity(0.2), radius: 8, y: 4)
                        .onLongPressGesture {
                            if onEdit != nil {
                                showActionSheet = true
                                generateHapticFeedback()
                            }
                        }
                    
                    HStack(spacing: 4) {
                        if showReadReceipt {
                            Text(L10n.readStatus)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(primaryAccent)
                        }
                        Text(formatTime(timestamp: message.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // 送信者アバター
                senderAvatar
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    // 送信者名
                    if let senderName = message.senderName {
                        Text(senderName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }
                    
                    Text(message.content)
                        .chatMessageFont()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(oshiBubbleColor)
                        .clipShape(ModernBubbleShape(isUser: false))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        .onLongPressGesture {
                            if onEdit != nil {
                                showActionSheet = true
                                generateHapticFeedback()
                            }
                        }
                    
                    Text(formatTime(timestamp: message.timestamp))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text(L10n.editMessageTitle),
                message: Text(L10n.adminEditWarning),
                buttons: [
                    .default(Text(L10n.edit)) { onEdit?(message) },
                    .cancel(Text(L10n.cancel))
                ]
            )
        }
    }
    
    private var senderAvatar: some View {
        Group {
            if let imageUrl = message.senderImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [primaryAccent.opacity(0.3), secondaryAccent.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(String(message.senderName?.prefix(1) ?? "?"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }
    
    private func formatTime(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - バブル形状
struct ModernBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isUser {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - tailSize, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + tailSize, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }
        
        return path
    }
}

// MARK: - グループタイピングバブル
struct GroupTypingBubble: View {
    let typingMembers: [String]
    let selectedMembers: [Oshi]
    let primaryAccent: Color
    let secondaryAccent: Color
    var bubbleColor: Color = Color(.secondarySystemBackground)
    
    @State private var dotAnimation: [Bool] = [false, false, false]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // タイピング中のメンバーのアバター
            typingMemberAvatar
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                // タイピング中のメンバー名
                if let typingMember = selectedMembers.first(where: { typingMembers.contains($0.id) }) {
                    Text(typingMember.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                }
                
                // タイピングドット
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotAnimation[index] ? 1.0 : 0.6)
                            .opacity(dotAnimation[index] ? 1.0 : 0.4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(bubbleColor)
                .clipShape(ModernBubbleShape(isUser: false))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
        .onAppear { startAnimation() }
    }
    
    private var typingMemberAvatar: some View {
        Group {
            if let typingMember = selectedMembers.first(where: { typingMembers.contains($0.id) }),
               let imageUrl = typingMember.imageUrl,
               let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    default:
                        defaultTypingAvatar
                    }
                }
            } else {
                defaultTypingAvatar
            }
        }
    }
    
    private var defaultTypingAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [primaryAccent.opacity(0.3), secondaryAccent.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
            )
    }
    
    private func startAnimation() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    dotAnimation[i] = true
                }
            }
        }
    }
}

// MARK: - モダンメンバー選択ビュー
struct ModernGroupMemberSelectionView: View {
    @Binding var isPresented: Bool
    let allOshiList: [Oshi]
    @Binding var selectedMembers: [Oshi]
    let primaryAccent: Color
    let secondaryAccent: Color
    let onSave: () -> Void
    
    @State private var tempSelectedMembers: [Oshi] = []
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
            
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.gray.opacity(0.1)))
                    }
                    
                    Spacer()
                    
                    Text(L10n.groupMembers)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        selectedMembers = tempSelectedMembers
                        onSave()
                        isPresented = false
                    }) {
                        Text(L10n.done)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [primaryAccent, secondaryAccent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Divider()
                
                // 選択済みメンバー表示
                if !tempSelectedMembers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(tempSelectedMembers, id: \.id) { oshi in
                                VStack(spacing: 4) {
                                    ZStack(alignment: .topTrailing) {
                                        if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 50, height: 50)
                                                        .clipShape(Circle())
                                                default:
                                                    selectedMemberPlaceholder(oshi)
                                                }
                                            }
                                        } else {
                                            selectedMemberPlaceholder(oshi)
                                        }
                                        
                                        Button(action: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                tempSelectedMembers.removeAll { $0.id == oshi.id }
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                                .background(Circle().fill(Color.gray))
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                    
                                    Text(oshi.name)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 60)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemBackground).opacity(0.5))
                }
                
                // メンバーリスト
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(allOshiList, id: \.id) { oshi in
                            memberRow(oshi)
                        }
                    }
                }
                
                // 説明テキスト
                Text(L10n.selectGroupMembersDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
        }
        .onAppear { tempSelectedMembers = selectedMembers }
    }
    
    private func selectedMemberPlaceholder(_ oshi: Oshi) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [primaryAccent.opacity(0.5), secondaryAccent.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
    }
    
    private func memberRow(_ oshi: Oshi) -> some View {
        let isSelected = tempSelectedMembers.contains(where: { $0.id == oshi.id })
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    tempSelectedMembers.removeAll { $0.id == oshi.id }
                } else {
                    tempSelectedMembers.append(oshi)
                }
            }
        }) {
            HStack(spacing: 14) {
                // アバター
                if let imageUrl = oshi.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        default:
                            memberPlaceholder(oshi)
                        }
                    }
                } else {
                    memberPlaceholder(oshi)
                }
                
                // 名前
                Text(oshi.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // チェックマーク
                ZStack {
                    Circle()
                        .stroke(isSelected ? primaryAccent : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [primaryAccent, secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? primaryAccent.opacity(0.05) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func memberPlaceholder(_ oshi: Oshi) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [primaryAccent.opacity(0.3), secondaryAccent.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 48, height: 48)
            .overlay(
                Text(String(oshi.name.prefix(1)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}

#Preview {
    OshiGroupChatView(groupId: .constant("123"))
}
