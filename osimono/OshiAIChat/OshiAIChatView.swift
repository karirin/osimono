//
//  OshiAIChatView.swift
//  osimono
//
//  Created by Apple on 2025/05/05.
//

import SwiftUI
import OpenAISwift
import Firebase
import FirebaseAuth
import FirebaseDatabase
import GoogleMobileAds
import Combine

extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
        
        let willHide = NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }
        
        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

// MARK: - メインビュー
struct OshiAIChatView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isFetchingMessages: Bool = true
    @State private var isInitialScrollComplete: Bool = false
    @State private var shouldScrollToBottom: Bool = false
    @State private var showEditPersonality = false
    @State private var showLimitAlert = false
    @State private var remainingMessages = 10
    let oshiItem: OshiItem?
    @State private var editScreenID = UUID()
    @State private var showRewardCompletedModal = false
    @State private var rewardAmount = 0
    @State private var helpFlag: Bool = false
    @ObservedObject var authManager = AuthManager()
    @State private var showSubscriptionView = false
    
    // 新しいUI用の状態管理
    @State private var showReadReceipt: Bool = false
    @State private var isTyping: Bool = false
    @State private var lastSentMessageId: String? = nil
    
    // モダンカラーパレット
    private let bgGradientStart = Color(red: 0.98, green: 0.97, blue: 0.99)
    private let bgGradientEnd = Color(red: 0.95, green: 0.94, blue: 0.98)
    private let primaryAccent = Color(red: 0.91, green: 0.42, blue: 0.58) // ソフトピンク
    private let secondaryAccent = Color(red: 0.65, green: 0.45, blue: 0.85) // ラベンダー
    private let oshiBubbleColor = Color.white
    private let userBubbleGradient = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.42, blue: 0.58),
            Color(red: 0.78, green: 0.38, blue: 0.72)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    @State private var hasMarkedAsRead: Bool = false
    @ObservedObject var viewModel: OshiViewModel
    @State private var currentOshiId: String = ""
    @State private var loadCompleteOshiData: Bool = false
    var showBackButton: Bool = true
    @State private var showMessageLimitModal = false
    @State private var rewardedAd: RewardedAd?
    @State private var isLoadingAd = false
    var isEmbedded: Bool = false
    
    @State private var editingMessage: ChatMessage? = nil
    @State private var editingText: String = ""
    @State private var showEditAlert = false
    @State private var selectedMessageForDeletion: ChatMessage? = nil
    @State private var showDeleteAlert = false
    
    private let adminUserIds = [
        "3UDNienzhkdheKIy77lyjMJhY4D3",
        "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    ]
    
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    private var shouldShowAd: Bool {
        return !isAdmin && !subscriptionManager.isSubscribed
    }
    
    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true
    
    private func checkAdminStatus() {
        guard let userID = Auth.auth().currentUser?.uid else {
            isAdmin = false
            isCheckingAdminStatus = false
            return
        }
        isAdmin = adminUserIds.contains(userID)
        isCheckingAdminStatus = false
    }
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    init(viewModel: OshiViewModel, oshiItem: OshiItem?, showBackButton: Bool = true, isEmbedded: Bool = false) {
        self.viewModel = viewModel
        self.oshiItem = oshiItem
        self.showBackButton = showBackButton
        self.isEmbedded = isEmbedded
        _loadCompleteOshiData = State(initialValue: true)
    }

    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [bgGradientStart, bgGradientEnd],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            chatContent
                .allowsHitTesting(!(showMessageLimitModal || showRewardCompletedModal))
                .gesture(
                    (showMessageLimitModal || showRewardCompletedModal) ? nil :
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                if value.translation.width > 80 {
                                    isTextFieldFocused = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        presentationMode.wrappedValue.dismiss()
                                    }
                                }
                            }
                )

            // モーダル群
            if showMessageLimitModal {
                MessageLimitModal(
                    isPresented: $showMessageLimitModal,
                    onWatchAd: { showRewardAd() },
                    onUpgrade: {
                        showMessageLimitModal = false
                        showSubscriptionView = true
                    },
                    remainingMessages: remainingMessages
                )
                .zIndex(999)
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
        }
        .overlay(adminAlerts)
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { keyboardHeight = height }
        }
        .dismissKeyboardOnTap()
        .onAppear {
            setupView()
            checkAdminStatus()
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: subscriptionManager.isSubscribed)
            remainingMessages = MessageLimitManager.shared.getRemainingMessages()
            
            authManager.fetchUserFlag { userFlag, error in
                if let error = error {
                    print(error.localizedDescription)
                } else if let userFlag = userFlag {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        if userFlag == 0 {
                            executeProcessEveryfifTimes()
                        }
                    }
                }
            }
        }
        .onChange(of: viewModel.selectedOshi.id) { handleOshiChange(newId: $0) }
        .onChange(of: subscriptionManager.isSubscribed) { newValue in
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: newValue)
            remainingMessages = MessageLimitManager.shared.getRemainingMessages()
        }
        .onDisappear { cleanup() }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionPreView()
                .onDisappear {
                    MessageLimitManager.shared.updateSubscriptionCacheAsync()
                    remainingMessages = MessageLimitManager.shared.getRemainingMessages()
                }
        }
    }
    
    // MARK: - メイン画面コンテンツ
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
            if showBackButton {
                Button(action: {
                    generateHapticFeedback()
                    isTextFieldFocused = false
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
                                .fill(Color.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        )
                }
            }
            
            // プロフィール画像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [primaryAccent.opacity(0.3), secondaryAccent.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                
                profileImage
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedOshi.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    if isTyping {
                        TypingIndicatorDots()
                        Text(L10n.typing)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(primaryAccent)
                    }
                }
            }
            
            Spacer()
            
            // 設定ボタン
            Button(action: {
                generateHapticFeedback()
                isTextFieldFocused = false
                showEditPersonality = true
            }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    )
            }
            
            // 残りメッセージ表示
            subscriptionBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        )
    }
    
    // サブスクリプションバッジ
    private var subscriptionBadge: some View {
        Group {
            if subscriptionManager.isSubscribed {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11))
                    Text(L10n.unlimited)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.12))
                )
            } else {
                VStack(spacing: 0) {
                    Text("\(MessageLimitManager.shared.getRemainingMessagesText())")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(primaryAccent)
                    Text(L10n.remaining)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                )
            }
        }
    }
    
    // MARK: - チャットメッセージリスト
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    if messages.isEmpty && !isFetchingMessages {
                        emptyStateView
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            let showTimestamp = shouldShowTimestamp(for: index)
                            
                            if showTimestamp {
                                timestampDivider(for: message.timestamp)
                            }
                            
                            ModernChatBubble(
                                message: message,
                                oshiName: viewModel.selectedOshi.name,
                                oshiImageURL: viewModel.selectedOshi.imageUrl,
                                isAdmin: isAdmin,
                                showReadReceipt: message.id == lastSentMessageId && showReadReceipt,
                                userBubbleGradient: userBubbleGradient,
                                oshiBubbleColor: oshiBubbleColor,
                                onEdit: isAdmin ? { startEditingMessage($0) } : nil,
                                onDelete: isAdmin ? { confirmDeleteMessage($0) } : nil
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        // タイピングインジケーター
                        if isTyping {
                            TypingBubble(
                                oshiImageURL: viewModel.selectedOshi.imageUrl
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
                .opacity(isInitialScrollComplete ? 1 : 0)
            }
            .onChange(of: messages.count) { _ in
                if !isFetchingMessages && !messages.isEmpty && !isInitialScrollComplete {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isInitialScrollComplete = true
                            }
                        }
                    }
                }
            }
            .onChange(of: shouldScrollToBottom) { shouldScroll in
                if shouldScroll && !messages.isEmpty {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                    shouldScrollToBottom = false
                }
            }
            .onChange(of: isTyping) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottomMarker", anchor: .bottom)
                }
            }
            .onChange(of: keyboardHeight) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        proxy.scrollTo("bottomMarker", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // 空状態ビュー
    private var emptyStateView: some View {
        VStack(spacing: 20) {
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
                Text(L10n.startConversationWith(viewModel.selectedOshi.name))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(L10n.sendFirstMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 80)
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
                        .fill(Color.white.opacity(0.8))
                )
            
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.vertical, 12)
    }
    
    // 修正箇所: 文字列リテラルを L10n に変更
    private func formatDateForDivider(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        let currentLanguage = Locale.current.languageCode ?? "en"
        formatter.locale = Locale(identifier: currentLanguage == "ja" ? "ja_JP" : "en_US")
        
        if Calendar.current.isDateInToday(date) {
            return L10n.today // 変更: NSLocalizedString("today"...) -> L10n.today
        } else if Calendar.current.isDateInYesterday(date) {
            return L10n.yesterday // 変更: NSLocalizedString("yesterday"...) -> L10n.yesterday
        } else {
            formatter.dateFormat = currentLanguage == "ja" ? "M月d日(E)" : "MMM d, E"
            return formatter.string(from: date)
        }
    }
    
    private func shouldShowTimestamp(for index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentDate = Date(timeIntervalSince1970: messages[index].timestamp)
        let previousDate = Date(timeIntervalSince1970: messages[index - 1].timestamp)
        let calendar = Calendar.current
        return !calendar.isDate(currentDate, inSameDayAs: previousDate)
    }
    
    // MARK: - 入力エリア
    private var inputAreaView: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.3)
            
            HStack(spacing: 12) {
                // テキストフィールド
                HStack(spacing: 8) {
                    TextField(
                        L10n.messagePlaceholder(viewModel.selectedOshi.name), // ここを変更
                        text: $inputText,
                        axis: .vertical
                    )
                    .focused($isTextFieldFocused)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .onSubmit {
                        if !inputText.isEmpty && !isLoading {
                            sendMessage()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            isTextFieldFocused ? primaryAccent.opacity(0.4) : Color.clear,
                            lineWidth: 1.5
                        )
                )
                
                // 送信ボタン
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
            )
        }
        .opacity(isInitialScrollComplete ? 1 : 0)
    }
    
    private var sendButton: some View {
        Button(action: {
            if !inputText.isEmpty && !isLoading {
                generateHapticFeedback()
                sendMessage()
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        inputText.isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.2))
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [primaryAccent, secondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: inputText.isEmpty ? .clear : primaryAccent.opacity(0.3),
                        radius: 8,
                        y: 4
                    )
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(inputText.isEmpty ? .gray : .white)
                    .offset(y: -1)
            }
        }
        .disabled(inputText.isEmpty || isLoading)
        .scaleEffect(inputText.isEmpty ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputText.isEmpty)
    }
    
    // MARK: - オーバーレイ
    private var overlaysView: some View {
        ZStack {
            // ローディングオーバーレイ（初期ロード時のみ）
            if !isInitialScrollComplete {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        
                        Text(L10n.loadingChat)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.7))
                    )
                }
            }
            
            // NavigationLink
            NavigationLink(
                destination: FirebaseDataLoader(oshiId: viewModel.selectedOshi.id) { loadedOshi in
                    EditOshiPersonalityView(
                        viewModel: OshiViewModel(oshi: loadedOshi ?? viewModel.selectedOshi),
                        onSave: { updatedOshi in
                            self.viewModel.selectedOshi = updatedOshi
                        },
                        onUpdate: {
                            loadOshiData()
                        }
                    )
                }
                .id(editScreenID),
                isActive: $showEditPersonality,
                label: { EmptyView() }
            )
            .hidden()
        }
    }
    
    // MARK: - メッセージ送信（既読・タイピング機能付き）
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let isSubscribed = subscriptionManager.isSubscribed
        
        if isSubscribed != MessageLimitManager.shared.isUserSubscribed() {
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: isSubscribed)
        }
        
        if !isSubscribed {
            if MessageLimitManager.shared.hasReachedLimit() {
                showMessageLimitModal = true
                return
            }
            MessageLimitManager.shared.incrementCount()
        }
        
        remainingMessages = MessageLimitManager.shared.getRemainingMessages()
        
        // ユーザーメッセージを作成
        let userMessageId = UUID().uuidString
        let userMessage = ChatMessage(
            id: userMessageId,
            content: inputText,
            isUser: true,
            timestamp: Date().timeIntervalSince1970,
            oshiId: viewModel.selectedOshi.id,
            itemId: oshiItem?.id
        )
        
        let userInput = inputText
        lastSentMessageId = userMessageId
        showReadReceipt = false
        
        DispatchQueue.main.async {
            self.inputText = ""
        }
        
        // メッセージを追加（アニメーション付き）
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(userMessage)
        }
        shouldScrollToBottom = true
        
        // Firebaseに保存
        ChatDatabaseManager.shared.saveMessage(userMessage) { error in
            if let error = error {
                print("❌ ユーザーメッセージ保存エラー: \(error.localizedDescription)")
            }
        }
        
        // 1〜2秒後に既読をつける
        let readDelay = Double.random(in: 1.0...2.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + readDelay) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showReadReceipt = true
            }
            generateHapticFeedback()
        }
        
        // 既読後1〜2秒でタイピング開始
        let typingDelay = readDelay + Double.random(in: 1.0...2.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isTyping = true
            }
        }
        
        // AI応答を生成
        AIMessageGenerator.shared.generateResponse(for: userInput, oshi: viewModel.selectedOshi, chatHistory: messages) { content, error in
            // 5〜10秒のランダム遅延
            let responseDelay = Double.random(in: 5.0...10.0)
            let totalDelay = typingDelay + responseDelay - typingDelay // タイピング開始からの遅延
            
            DispatchQueue.main.asyncAfter(deadline: .now() + responseDelay) {
                // タイピング終了
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isTyping = false
                }
                
                if let error = error {
                    print("❌ AI返信生成エラー: \(error.localizedDescription)")
                    return
                }
                
                guard let content = content else {
                    return
                }
                
                // AI返信を追加
                let aiMessageId = UUID().uuidString
                let aiMessage = ChatMessage(
                    id: aiMessageId,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: viewModel.selectedOshi.id,
                    itemId: oshiItem?.id
                )
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    messages.append(aiMessage)
                }
                shouldScrollToBottom = true
                generateHapticFeedback()
                
                // Firebaseに保存
                ChatDatabaseManager.shared.saveMessage(aiMessage) { error in
                    if let error = error {
                        print("❌ AI返信保存エラー: \(error.localizedDescription)")
                    }
                }
                
                // 既読表示をリセット
                lastSentMessageId = nil
                showReadReceipt = false
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.markMessagesAsRead()
        }
    }
    
    // 以下は既存のコードを維持
    private func startEditingMessage(_ message: ChatMessage) {
        editingMessage = message
        editingText = message.content
        showEditAlert = true
    }
    
    private func confirmDeleteMessage(_ message: ChatMessage) {
        selectedMessageForDeletion = message
        showDeleteAlert = true
    }
    
    private func saveEditedMessage() {
        guard let editingMessage = editingMessage,
              !editingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        if let index = messages.firstIndex(where: { $0.id == editingMessage.id }) {
            let updatedMessage = ChatMessage(
                id: editingMessage.id,
                content: editingText,
                isUser: editingMessage.isUser,
                timestamp: Date().timeIntervalSince1970,
                oshiId: editingMessage.oshiId,
                itemId: editingMessage.itemId
            )
            messages[index] = updatedMessage
            
            ChatDatabaseManager.shared.updateMessage(updatedMessage) { error in
                if let error = error {
                    print("❌ メッセージ編集エラー: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.messages[index] = editingMessage
                    }
                }
            }
        }
        
        self.editingMessage = nil
        self.editingText = ""
    }
    
    private func deleteMessage() {
        guard let messageToDelete = selectedMessageForDeletion else { return }
        
        messages.removeAll { $0.id == messageToDelete.id }
        
        ChatDatabaseManager.shared.deleteMessage(messageToDelete) { error in
            if let error = error {
                print("❌ メッセージ削除エラー: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.messages.append(messageToDelete)
                    self.messages.sort { $0.timestamp < $1.timestamp }
                }
            }
        }
        
        selectedMessageForDeletion = nil
    }
    
    private var adminAlerts: some View {
        EmptyView()
            .alert(L10n.editMessageTitle, isPresented: $showEditAlert, actions: { // 変更
                TextField(L10n.messageContent, text: $editingText) // 変更
                Button(L10n.save) { saveEditedMessage() } // 変更
                Button(L10n.cancel, role: .cancel) { // 変更
                    editingMessage = nil
                    editingText = ""
                }
            }, message: {
                Text(L10n.adminEditWarning) // 変更
            })
            .alert(L10n.deleteMessageTitle, isPresented: $showDeleteAlert, actions: { // 変更
                Button(L10n.delete, role: .destructive) { deleteMessage() } // 変更
                Button(L10n.cancel, role: .cancel) { selectedMessageForDeletion = nil } // 変更
            }, message: {
                Text(L10n.deleteMessageWarning) // 変更
            })
    }
    
    func executeProcessEveryfifTimes() {
        let count = UserDefaults.standard.integer(forKey: "launchHelpCount") + 1
        UserDefaults.standard.set(count, forKey: "launchHelpCount")
        if count % 10 == 0 {
            helpFlag = true
        }
    }
    
    private func setupView() {
        if loadCompleteOshiData {
            loadCompleteOshiData = false
            loadFullOshiData()
        } else if viewModel.selectedOshi.id == "1" {
            loadActualOshiData()
        } else {
            currentOshiId = viewModel.selectedOshi.id
            resetViewState()
            loadMessages()
            markMessagesAsRead()
        }
        remainingMessages = MessageLimitManager.shared.getRemainingMessages()
        loadRewardedAd()
    }
    
    private func handleOshiChange(newId: String) {
        if currentOshiId != newId {
            currentOshiId = newId
            resetViewState()
            loadMessages()
        }
    }
    
    private func cleanup() {
        markMessagesAsRead()
        isTextFieldFocused = false
    }
    
    private var profileImage: some View {
        Group {
            if let imageUrl = viewModel.selectedOshi.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        defaultProfileImage
                    }
                }
            } else {
                defaultProfileImage
            }
        }
    }
    
    private var defaultProfileImage: some View {
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
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
            )
    }
    
    private func markMessagesAsRead() {
        ChatDatabaseManager.shared.markMessagesAsRead(for: viewModel.selectedOshi.id) { error in
            if let error = error {
                print("メッセージを既読にできませんでした: \(error.localizedDescription)")
            } else {
                self.hasMarkedAsRead = true
            }
        }
    }
    
    private func loadMessages() {
        isFetchingMessages = true
        isInitialScrollComplete = false
        
        if let item = oshiItem {
            let itemId = item.id
            
            ChatDatabaseManager.shared.fetchMessages(for: viewModel.selectedOshi.id, itemId: itemId) { fetchedMessages, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("メッセージ読み込みエラー: \(error.localizedDescription)")
                        isFetchingMessages = false
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                        return
                    }
                    
                    if let messages = fetchedMessages, !messages.isEmpty {
                        self.messages = messages
                        isFetchingMessages = false
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                    } else {
                        addInitialMessage(for: item)
                    }
                }
            }
        } else {
            ChatDatabaseManager.shared.fetchMessages(for: viewModel.selectedOshi.id) { fetchedMessages, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("メッセージ読み込みエラー: \(error.localizedDescription)")
                        isFetchingMessages = false
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                        return
                    }
                    
                    if let messages = fetchedMessages, !messages.isEmpty {
                        self.messages = messages
                        isFetchingMessages = false
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                    } else {
                        isFetchingMessages = false
                        isInitialScrollComplete = true
                    }
                }
            }
        }
    }
    
    private func addInitialMessage(for item: OshiItem) {
        isTyping = true
        
        AIMessageGenerator.shared.generateInitialMessage(for: viewModel.selectedOshi, item: item) { content, error in
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 2.0...4.0)) {
                withAnimation {
                    isTyping = false
                }
                
                if let error = error {
                    print("AIメッセージ生成エラー: \(error.localizedDescription)")
                    isFetchingMessages = false
                    isInitialScrollComplete = true
                    return
                }
                
                guard let content = content else {
                    isFetchingMessages = false
                    isInitialScrollComplete = true
                    return
                }
                
                let messageId = UUID().uuidString
                let message = ChatMessage(
                    id: messageId,
                    content: content,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: viewModel.selectedOshi.id,
                    itemId: item.id
                )
                
                ChatDatabaseManager.shared.saveMessage(message) { error in
                    if let error = error {
                        print("メッセージ保存エラー: \(error.localizedDescription)")
                    }
                }
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    messages.append(message)
                }
                isFetchingMessages = false
            }
        }
    }
    
    private func resetViewState() {
        messages = []
        isInitialScrollComplete = false
        isFetchingMessages = true
        isLoading = false
        shouldScrollToBottom = false
        hasMarkedAsRead = false
        isTyping = false
        showReadReceipt = false
        lastSentMessageId = nil
    }

    private func loadOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let dbRef = Database.database().reference().child("oshis").child(userID).child(viewModel.selectedOshi.id)
        dbRef.observeSingleEvent(of: .value) { snapshot in
            guard let data = snapshot.value as? [String: Any] else { return }
            
            var newOshi = Oshi(
                id: self.viewModel.selectedOshi.id,
                name: data["name"] as? String ?? self.viewModel.selectedOshi.name,
                imageUrl: data["imageUrl"] as? String ?? self.viewModel.selectedOshi.imageUrl,
                backgroundImageUrl: data["backgroundImageUrl"] as? String ?? self.viewModel.selectedOshi.backgroundImageUrl,
                memo: data["memo"] as? String ?? self.viewModel.selectedOshi.memo,
                createdAt: data["createdAt"] as? TimeInterval ?? self.viewModel.selectedOshi.createdAt
            )
            
            newOshi.personality = data["personality"] as? String
            newOshi.speaking_style = data["speaking_style"] as? String
            newOshi.birthday = data["birthday"] as? String
            newOshi.hometown = data["hometown"] as? String
            newOshi.favorite_color = data["favorite_color"] as? String
            newOshi.favorite_food = data["favorite_food"] as? String
            newOshi.disliked_food = data["disliked_food"] as? String
            newOshi.interests = data["interests"] as? [String]
            newOshi.gender = data["gender"] as? String
            newOshi.height = data["height"] as? Int
            
            DispatchQueue.main.async {
                self.viewModel.selectedOshi = newOshi
            }
        }
    }
    
    private func loadFullOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let oshiRef = Database.database().reference().child("oshis").child(userID).child(viewModel.selectedOshi.id)
        oshiRef.observeSingleEvent(of: .value) { snapshot in
            guard let oshiData = snapshot.value as? [String: Any] else {
                self.currentOshiId = self.viewModel.selectedOshi.id
                self.resetViewState()
                self.loadMessages()
                self.markMessagesAsRead()
                return
            }
            
            var newOshi = Oshi(
                id: self.viewModel.selectedOshi.id,
                name: oshiData["name"] as? String ?? self.viewModel.selectedOshi.name,
                imageUrl: oshiData["imageUrl"] as? String ?? self.viewModel.selectedOshi.imageUrl,
                backgroundImageUrl: oshiData["backgroundImageUrl"] as? String ?? self.viewModel.selectedOshi.backgroundImageUrl,
                memo: oshiData["memo"] as? String ?? self.viewModel.selectedOshi.memo,
                createdAt: oshiData["createdAt"] as? TimeInterval ?? self.viewModel.selectedOshi.createdAt
            )
            
            newOshi.personality = oshiData["personality"] as? String
            newOshi.speaking_style = oshiData["speaking_style"] as? String
            newOshi.birthday = oshiData["birthday"] as? String
            newOshi.hometown = oshiData["hometown"] as? String
            newOshi.favorite_color = oshiData["favorite_color"] as? String
            newOshi.favorite_food = oshiData["favorite_food"] as? String
            newOshi.disliked_food = oshiData["disliked_food"] as? String
            newOshi.interests = oshiData["interests"] as? [String]
            newOshi.gender = oshiData["gender"] as? String
            newOshi.height = oshiData["height"] as? Int
            newOshi.user_nickname = oshiData["user_nickname"] as? String
            
            DispatchQueue.main.async {
                self.viewModel.selectedOshi = newOshi
                self.currentOshiId = newOshi.id
                self.resetViewState()
                self.loadMessages()
                self.markMessagesAsRead()
            }
        }
    }
    
    private func loadActualOshiData() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let userRef = Database.database().reference().child("users").child(userID)
        userRef.observeSingleEvent(of: .value) { snapshot in
            guard let userData = snapshot.value as? [String: Any],
                  let selectedOshiId = userData["selectedOshiId"] as? String,
                  selectedOshiId != "default" && selectedOshiId != "1" else {
                self.loadFirstOshi()
                return
            }
            
            let oshiRef = Database.database().reference().child("oshis").child(userID).child(selectedOshiId)
            oshiRef.observeSingleEvent(of: .value) { snapshot in
                guard let oshiData = snapshot.value as? [String: Any] else {
                    self.loadFirstOshi()
                    return
                }
                
                var oshi = Oshi(
                    id: selectedOshiId,
                    name: oshiData["name"] as? String ?? L10n.noName,
                    imageUrl: oshiData["imageUrl"] as? String,
                    backgroundImageUrl: oshiData["backgroundImageUrl"] as? String,
                    memo: oshiData["memo"] as? String,
                    createdAt: oshiData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                )
                
                oshi.personality = oshiData["personality"] as? String
                oshi.speaking_style = oshiData["speaking_style"] as? String
                
                DispatchQueue.main.async {
                    self.viewModel.selectedOshi = oshi
                    self.currentOshiId = oshi.id
                    self.resetViewState()
                    self.loadMessages()
                    self.markMessagesAsRead()
                }
            }
        }
    }
    
    private func loadFirstOshi() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        
        let oshisRef = Database.database().reference().child("oshis").child(userID)
        oshisRef.observeSingleEvent(of: .value) { snapshot in
            var firstOshi: Oshi?
            
            for child in snapshot.children {
                if let childSnapshot = child as? DataSnapshot,
                   let oshiData = childSnapshot.value as? [String: Any] {
                    let id = childSnapshot.key
                    let name = oshiData["name"] as? String ?? L10n.noName
                    
                    firstOshi = Oshi(
                        id: id,
                        name: name,
                        imageUrl: oshiData["imageUrl"] as? String,
                        backgroundImageUrl: oshiData["backgroundImageUrl"] as? String,
                        memo: oshiData["memo"] as? String,
                        createdAt: oshiData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    )
                    break
                }
            }
            
            if let oshi = firstOshi {
                DispatchQueue.main.async {
                    self.viewModel.selectedOshi = oshi
                    self.currentOshiId = oshi.id
                    self.resetViewState()
                    self.loadMessages()
                    self.markMessagesAsRead()
                    
                    let userRef = Database.database().reference().child("users").child(userID)
                    userRef.updateChildValues(["selectedOshiId": oshi.id])
                }
            }
        }
    }
    
    private func loadRewardedAd() {
        let request = Request()
        RewardedAd.load(with: "ca-app-pub-4898800212808837/3373075660", request: request) { [self] ad, error in
            if let error = error {
                print("リワード広告の読み込みに失敗しました: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self.rewardedAd = ad
            }
        }
    }
    
    private func showRewardAd() {
        guard let rewardedAd = rewardedAd else {
            loadRewardedAd()
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        rewardedAd.present(from: rootViewController) {
            DispatchQueue.main.async {
                MessageLimitManager.shared.resetCountAfterReward()
                self.remainingMessages = MessageLimitManager.shared.getRemainingMessages()
                self.showMessageLimitModal = false
                self.rewardAmount = 10
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.showRewardCompletedModal = true
                }
                
                generateHapticFeedback()
                self.loadRewardedAd()
            }
        }
    }
    
    struct FirebaseDataLoader<Content: View>: View {
        let oshiId: String
        let content: (Oshi?) -> Content
        @State private var loadedOshi: Oshi? = nil
        @State private var isLoading: Bool = true
        
        init(oshiId: String, @ViewBuilder content: @escaping (Oshi?) -> Content) {
            self.oshiId = oshiId
            self.content = content
        }
        
        var body: some View {
            ZStack {
                if isLoading {
                    ProgressView()
                } else {
                    content(loadedOshi)
                }
            }
            .onAppear { loadOshiData() }
        }
        
        private func loadOshiData() {
            guard let userID = Auth.auth().currentUser?.uid else {
                isLoading = false
                return
            }
            
            let dbRef = Database.database().reference().child("oshis").child(userID).child(oshiId)
            dbRef.observeSingleEvent(of: .value) { snapshot in
                guard let data = snapshot.value as? [String: Any] else {
                    isLoading = false
                    return
                }
                
                var oshi = Oshi(
                    id: oshiId,
                    name: data["name"] as? String ?? L10n.noName,
                    imageUrl: data["imageUrl"] as? String,
                    backgroundImageUrl: data["backgroundImageUrl"] as? String,
                    memo: data["memo"] as? String,
                    createdAt: data["createdAt"] as? TimeInterval
                )
                
                oshi.personality = data["personality"] as? String
                oshi.speaking_style = data["speaking_style"] as? String
                oshi.birthday = data["birthday"] as? String
                oshi.hometown = data["hometown"] as? String
                oshi.favorite_color = data["favorite_color"] as? String
                oshi.favorite_food = data["favorite_food"] as? String
                oshi.disliked_food = data["disliked_food"] as? String
                oshi.interests = data["interests"] as? [String]
                oshi.gender = data["gender"] as? String
                oshi.height = data["height"] as? Int
                oshi.user_nickname = data["user_nickname"] as? String
                
                DispatchQueue.main.async {
                    self.loadedOshi = oshi
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - モダンチャットバブル
struct ModernChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    let oshiImageURL: String?
    let isAdmin: Bool
    let showReadReceipt: Bool
    let userBubbleGradient: LinearGradient
    let oshiBubbleColor: Color
    let onEdit: ((ChatMessage) -> Void)?
    let onDelete: ((ChatMessage) -> Void)?
    
    @State private var showActionSheet = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    // メッセージバブル
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(userBubbleGradient)
                        .clipShape(ChatBubbleShape(isUser: true))
                        .shadow(color: Color(red: 0.91, green: 0.42, blue: 0.58).opacity(0.2), radius: 8, y: 4)
                        .onLongPressGesture {
                            if isAdmin {
                                showActionSheet = true
                                generateHapticFeedback()
                            }
                        }
                    
                    // 時間と既読表示
                    HStack(spacing: 4) {
                        if showReadReceipt {
                            Text(L10n.readStatus)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(red: 0.91, green: 0.42, blue: 0.58))
                        }
                        Text(formatTime(timestamp: message.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                // 推しのアイコン
                oshiAvatar
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    // メッセージバブル
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(oshiBubbleColor)
                        .clipShape(ChatBubbleShape(isUser: false))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        .onLongPressGesture {
                            if isAdmin {
                                showActionSheet = true
                                generateHapticFeedback()
                            }
                        }
                    
                    // 時間表示
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
                title: Text(L10n.editMessageTitle), // 変更
                message: Text(L10n.adminEditWarning), // 変更
                buttons: [
                    .default(Text(L10n.edit)) { onEdit?(message) }, // 変更: "編集" -> L10n.edit
                    .destructive(Text(L10n.delete)) { onDelete?(message) }, // 変更: "削除" -> L10n.delete
                    .cancel(Text(L10n.cancel)) // 変更: "キャンセル" -> L10n.cancel
                ]
            )
        }
    }
    
    private var oshiAvatar: some View {
        Group {
            if let imageUrl = oshiImageURL, let url = URL(string: imageUrl) {
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
                    colors: [
                        Color(red: 0.91, green: 0.42, blue: 0.58).opacity(0.3),
                        Color(red: 0.65, green: 0.45, blue: 0.85).opacity(0.3)
                    ],
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
    
    private func formatTime(timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - チャットバブル形状
struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isUser {
            // 右下に小さな尻尾
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
            // 左下に小さな尻尾
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

// MARK: - タイピングインジケーター
struct TypingIndicatorDots: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color(red: 0.91, green: 0.42, blue: 0.58))
                    .frame(width: 5, height: 5)
                    .offset(y: animationOffset)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -3
        }
    }
}

// MARK: - タイピングバブル
struct TypingBubble: View {
    let oshiImageURL: String?
    
    @State private var dotAnimation: [Bool] = [false, false, false]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // アバター
            Group {
                if let imageUrl = oshiImageURL, let url = URL(string: imageUrl) {
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
            .frame(width: 36, height: 36)
            
            // タイピングインジケーター
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
            .background(Color.white)
            .clipShape(ChatBubbleShape(isUser: false))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
            
            Spacer()
        }
        .padding(.vertical, 2)
        .onAppear {
            startAnimation()
        }
    }
    
    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.91, green: 0.42, blue: 0.58).opacity(0.3),
                        Color(red: 0.65, green: 0.45, blue: 0.85).opacity(0.3)
                    ],
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

// MARK: - レガシーサポート（既存コードとの互換性）
struct LineChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    let oshiImageURL: String?
    
    var body: some View {
        ModernChatBubble(
            message: message,
            oshiName: oshiName,
            oshiImageURL: oshiImageURL,
            isAdmin: false,
            showReadReceipt: false,
            userBubbleGradient: LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.42, blue: 0.58),
                    Color(red: 0.78, green: 0.38, blue: 0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            oshiBubbleColor: .white,
            onEdit: nil,
            onDelete: nil
        )
    }
}

struct AdminLineChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    let oshiImageURL: String?
    let isAdmin: Bool
    let onEdit: (ChatMessage) -> Void
    let onDelete: (ChatMessage) -> Void
    
    var body: some View {
        ModernChatBubble(
            message: message,
            oshiName: oshiName,
            oshiImageURL: oshiImageURL,
            isAdmin: isAdmin,
            showReadReceipt: false,
            userBubbleGradient: LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.42, blue: 0.58),
                    Color(red: 0.78, green: 0.38, blue: 0.72)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            oshiBubbleColor: .white,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    
    var body: some View {
        ModernChatBubble(
            message: message,
            oshiName: oshiName,
            oshiImageURL: nil,
            isAdmin: false,
            showReadReceipt: false,
            userBubbleGradient: LinearGradient(
                colors: [.blue, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            oshiBubbleColor: Color.gray.opacity(0.1),
            onEdit: nil,
            onDelete: nil
        )
    }
}

// MARK: - プレビュー
#Preview {
    let dummyOshi = Oshi(
        id: "2E5C7468-E2AB-41D6-B7CE-901674CB2973",
        name: "テストの推し",
        imageUrl: nil,
        backgroundImageUrl: nil,
        memo: nil,
        createdAt: Date().timeIntervalSince1970
    )
    OshiAIChatView(viewModel: OshiViewModel(oshi: dummyOshi), oshiItem: nil)
}
