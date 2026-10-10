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
    @Environment(\.colorScheme) var colorScheme
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var isFetchingMessages: Bool = true
    // 表示中の推しのチャット履歴の監視（差し替え・画面破棄で前の監視は解除される）
    @State private var messagesObservation: ChatMessagesObservation?
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
    /// 次に開くペイウォールの入口（オンボーディング時のみ切り替え、閉じたら戻す）
    @State private var paywallSource: PaywallSource = .chatLimit
    
    // 新しいUI用の状態管理
    @State private var showReadReceipt: Bool = false
    @State private var isTyping: Bool = false
    @State private var lastSentMessageId: String? = nil
    // ロールプレイ
    @State private var roleplaySituation = RoleplaySituation()
    @State private var showRoleplaySettings = false
    @State private var roleplayTrialStatus = RoleplayTrial.status
    // 関係性
    @StateObject private var relationshipFeed = RelationshipFeed()
    @State private var showRelationshipDetail = false
    /// ステージアップ演出を出す位置（直前のメッセージID → イベント）
    @State private var stageUpBanners: [String: RelationshipEvent] = [:]
    /// AI返信待ちの間は次のメッセージを送らせない（記憶・要約・関係性の更新が競合しないように）
    @State private var isAwaitingReply = false
    @ObservedObject private var tutorialManager = TutorialManager.shared
    @State private var showReplyErrorAlert = false
    @StateObject private var adjustmentStore = ConversationAdjustmentStore()
    @ObservedObject private var chatInterstitial = IndividualChatInterstitialManager.shared
    @State private var isChatVisible = false
    @ObservedObject private var appearanceStore = ChatAppearanceStore.shared
    @State private var showAppearanceSettings = false
    
    // モダンカラーパレット - ダークモード対応
    private let primaryAccent = Color(red: 0.91, green: 0.42, blue: 0.58) // ソフトピンク
    private let secondaryAccent = Color(red: 0.65, green: 0.45, blue: 0.85) // ラベンダー
    private var oshiBubbleColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color.white
    }
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
    /// 上限超過後に届いた、続きがぼかされている返信のID
    @State private var lockedReplyIds: Set<String> = []
    /// ぼかされた返信から制限画面を開いた場合、広告視聴後に解除する返信
    @State private var requestedUnlockReplyId: String?
    @State private var rewardedAd: RewardedAd?
    @State private var isLoadingAd = false
    @State private var showAdLoadFailedAlert = false
    var isEmbedded: Bool = false
    
    @State private var editingMessage: ChatMessage? = nil
    @State private var editingText: String = ""
    @State private var showEditAlert = false
    @State private var selectedMessageForDeletion: ChatMessage? = nil
    @State private var showDeleteAlert = false
    
    // private let adminUserIds = [
    //     "3UDNienzhkdheKIy77lyjMJhY4D3",
    //     "bZwehJdm4RTQ7JWjl20yaxTWS7l2"
    // ]

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

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

    @State private var isAdmin = false
    @State private var isCheckingAdminStatus = true

    private func checkAdminStatus() {
        isAdmin = false
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
            ChatAppearanceBackground(theme: appearanceStore.settings.background, photo: appearanceStore.photo)
                .ignoresSafeArea()
            
            chatContent
                .allowsHitTesting(!showRewardCompletedModal)
                .gesture(
                    showRewardCompletedModal ? nil :
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
                    remainingMessages: remainingMessages,
                    oshiName: viewModel.selectedOshi.name,
                    canWatchAd: !subscriptionManager.isSubscribed && !isAdmin,
                    isAdLoading: isLoadingAd,
                    unlocksReply: messages.contains {
                        !$0.isUser && $0.oshiId == viewModel.selectedOshi.id && lockedReplyIds.contains($0.id)
                    }
                )
                .alert(NSLocalizedString("reward_ad_load_failed", comment: "Couldn't load the ad"), isPresented: $showAdLoadFailedAlert) {
                    Button("OK", role: .cancel) {}
                }
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
        .environment(\.chatAppearance, appearanceStore.settings)
        .sheet(isPresented: $showAppearanceSettings) {
            ChatAppearanceSettingsView()
        }
        .background(editPersonalityLink)
        .overlay(adminAlerts)
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { keyboardHeight = height }
        }
        .dismissKeyboardOnTap()
        .onAppear {
            isChatVisible = true
            setupView()
            checkAdminStatus()
            tutorialManager.chatDidAppear()
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: subscriptionManager.isSubscribed)
            if shouldShowAd {
                loadRewardedAd()
                IndividualChatInterstitialManager.shared.preloadAd()
            }
            remainingMessages = MessageLimitManager.shared.getRemainingMessages()
            lockedReplyIds = MessageLimitManager.shared.lockedReplyIds()
            
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
        .onChange(of: showMessageLimitModal) { isPresented in
            if !isPresented { requestedUnlockReplyId = nil }
        }
        .onChange(of: authManager.user?.uid) { _ in
            adjustmentStore.load(oshiID: viewModel.selectedOshi.id)
        }
        .onChange(of: subscriptionManager.isSubscribed) { newValue in
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: newValue)
            remainingMessages = MessageLimitManager.shared.getRemainingMessages()
        }
        .onDisappear {
            isChatVisible = false
            cleanup()
            tutorialManager.chatDidDisappear()
        }
        .task(id: automaticAdjustmentCandidate) {
            guard automaticAdjustmentCandidate != nil else { return }
            do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
            adjustmentStore.offerAutomatically { canPresentAdjustment }
        }
        .onChange(of: adjustmentStore.item) { _ in shouldScrollToBottom = true }
        .onChange(of: adjustmentStore.selectingItem) { _ in shouldScrollToBottom = true }
        .navigationBarHidden(true)
        .sheet(isPresented: $showRoleplaySettings, onDismiss: { roleplayTrialStatus = RoleplayTrial.status }) {
            RoleplaySettingsView(oshi: viewModel.selectedOshi) { situation in
                roleplaySituation = situation
            }
        }
        .sheet(isPresented: $showRelationshipDetail) {
            RelationshipDetailView(oshi: viewModel.selectedOshi) { situation in
                roleplaySituation = situation
            }
        }
        .onChange(of: relationshipFeed.pendingEvent?.id) { _ in presentPendingStageUpIfPossible() }
        .onChange(of: isAwaitingReply) { _ in presentPendingStageUpIfPossible() }
        .onChange(of: isFetchingMessages) { _ in presentPendingStageUpIfPossible() }
        .onChange(of: adjustmentStore.isSaving) { _ in presentPendingStageUpIfPossible() }
        .alert(
            Bundle.main.localizedString(forKey: "roleplay_reply_error_title", value: "返信を受け取れませんでした", table: nil),
            isPresented: $showReplyErrorAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(Bundle.main.localizedString(forKey: "roleplay_reply_error_message", value: "通信状況を確認して、もう一度メッセージを送ってください。", table: nil))
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionPreView(source: paywallSource)
                .onDisappear {
                    paywallSource = .chatLimit
                    MessageLimitManager.shared.updateSubscriptionCacheAsync()
                    remainingMessages = MessageLimitManager.shared.getRemainingMessages()
                }
        }
    }
    
    private var canPresentAdjustment: Bool {
        isChatVisible && !isFetchingMessages && !isAwaitingReply && !isTyping && !isLoading
        && !isTextFieldFocused && inputText.isEmpty && keyboardHeight == 0
        && !showEditPersonality && !showRoleplaySettings && !showRelationshipDetail
        && !showAppearanceSettings
        && !showSubscriptionView && !showMessageLimitModal && !showRewardCompletedModal
        && !helpFlag && !showReplyErrorAlert && !showEditAlert && !showDeleteAlert
        && !showLimitAlert && !showAdLoadFailedAlert && !isLoadingAd
        && !tutorialManager.isShowingTutorial && tutorialManager.arrivedMessage == nil
        && !chatInterstitial.isPresenting && relationshipFeed.pendingEvent == nil
        && !adjustmentStore.isSaving
    }
    private var automaticAdjustmentCandidate: String? {
        guard canPresentAdjustment, adjustmentStore.item == nil, !adjustmentStore.selectingItem,
              adjustmentStore.notice == nil,
              let item = adjustmentStore.state?.nextItem(now: Date()) else { return nil }
        return "\(viewModel.selectedOshi.id)-\(item.rawValue)"
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
                                .fill(Color(.secondarySystemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                        )
                }
            }
            
            // プロフィール画像（外周リング = 次の関係までの進み具合）
            Button(action: openRelationshipDetail) {
                RelationshipAvatarRing(relationship: relationshipFeed.relationship) {
                    profileImage
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.selectedOshi.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .onTapGesture(perform: openRelationshipDetail)

                HStack(spacing: 4) {
                    if isTyping {
                        TypingIndicatorDots()
                        Text(L10n.typing)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(primaryAccent)
                            .padding(.vertical, 4)
                    } else {
                        RelationshipStatusLabel(relationship: relationshipFeed.relationship, action: openRelationshipDetail)
                            .fixedSize()
                        Text("·")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.6))
                        situationLabel
                    }
                }
            }
            
            Spacer()
            
            // Both routes use the existing header settings entry point.
            Menu {
                Button {
                    isTextFieldFocused = false
                    showAppearanceSettings = true
                } label: {
                    Label("chat_appearance_title", systemImage: "paintpalette")
                }
                Divider()
                Menu {
                    ForEach(RoleplayReplyLength.allCases) { length in
                        Button {
                            isTextFieldFocused = false
                            adjustmentStore.selectItem(.length)
                            adjustmentStore.choose(length.adjustmentChoice, viewModel: viewModel)
                        } label: {
                            if RoleplayReplyLength(choice: ConversationAdjustmentItem.length.savedChoice(in: viewModel.selectedOshi.speaking_style)) == length {
                                Label(length.title, systemImage: "checkmark")
                            } else {
                                Text(length.title)
                            }
                        }
                    }
                } label: {
                    Label("roleplay_reply_length_title", systemImage: "text.alignleft")
                }
                .disabled(adjustmentStore.isSaving || isAwaitingReply || isTyping)
                Button {
                    isTextFieldFocused = false
                    showRoleplaySettings = true
                } label: {
                    Label("roleplay_character_settings_entry", systemImage: "person.text.rectangle")
                }
                .disabled(adjustmentStore.isSaving || isAwaitingReply || isTyping)
                Button(ConversationAdjustmentText.string("adjustment_open")) {
                    isTextFieldFocused = false
                    adjustmentStore.openManually()
                    shouldScrollToBottom = true
                }
                .disabled(adjustmentStore.isSaving)
                Button(L10n.editPersonalityTraits) {
                    generateHapticFeedback()
                    isTextFieldFocused = false
                    showEditPersonality = true
                }
                .disabled(adjustmentStore.isSaving)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary.opacity(0.6))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
            }
            .accessibilityLabel(ConversationAdjustmentText.string("adjustment_settings"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
        )
    }
    
    private func openRelationshipDetail() {
        generateHapticFeedback()
        isTextFieldFocused = false
        showRelationshipDetail = true
    }

    // 現在のシチュエーション（タップでロールプレイ設定）
    private var situationLabel: some View {
        Button(action: {
            generateHapticFeedback()
            isTextFieldFocused = false
            showRoleplaySettings = true
        }) {
            let isPremium = subscriptionManager.isSubscribed
            // 無料ユーザーはお試し中だけシチュエーションが有効
            let isSet = !roleplaySituation.shortLabel.isEmpty && (isPremium || RoleplayTrial.isActive)
            HStack(spacing: 2) {
                if !isPremium && roleplayTrialStatus == .used {
                    // お試し済み: 続きはプレミアム限定
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }
                Text(situationChipText(isSet: isSet, isPremium: isPremium))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSet ? .secondary : primaryAccent)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAwaitingReply || isTyping)
        .accessibilityLabel(Bundle.main.localizedString(forKey: "roleplay_settings_title", value: "ロールプレイ設定", table: nil))
    }

    private func situationChipText(isSet: Bool, isPremium: Bool) -> String {
        let base = isSet
            ? roleplaySituation.shortLabel
            : Bundle.main.localizedString(forKey: "roleplay_chip_label", value: "ロールプレイ設定", table: nil)
        guard !isPremium else { return base }
        switch roleplayTrialStatus {
        case .available:
            return Bundle.main.localizedString(forKey: "roleplay_chip_trial_available", value: "ロールプレイを無料で体験", table: nil)
        case .active(let remaining):
            return base + String(format: Bundle.main.localizedString(forKey: "roleplay_chip_trial_remaining", value: "（残り%d回）", table: nil), remaining)
        case .used:
            return base
        }
    }

    private func loadRoleplaySituation() {
        roleplayTrialStatus = RoleplayTrial.status
        let oshiId = viewModel.selectedOshi.id
        RoleplayRepository.shared.fetchState(oshiId: oshiId) { state in
            DispatchQueue.main.async {
                guard viewModel.selectedOshi.id == oshiId else { return }
                roleplaySituation = state.situation
            }
        }
        relationshipFeed.start(oshiId: oshiId)
    }

    /// 未演出のステージアップがあれば、チャット上で演出してからキャラクターの反応（LLM生成）を出す。
    /// 返信待ち・読み込み中は待ち、終わった時点で改めて呼ばれる。
    private func presentPendingStageUpIfPossible() {
        guard let event = relationshipFeed.pendingEvent,
              !isAwaitingReply, !isTyping, !isFetchingMessages, !adjustmentStore.isSaving,
              let anchorId = messages.last?.id else { return }
        let oshi = viewModel.selectedOshi
        relationshipFeed.markHandled(event)
        isAwaitingReply = true

        RoleplayRepository.shared.claimEventAnnouncement(event, oshiId: oshi.id) { claimed in
            DispatchQueue.main.async {
                // 別端末・別画面で既に演出済み、または推しが切り替わった
                guard claimed, viewModel.selectedOshi.id == oshi.id else {
                    isAwaitingReply = false
                    return
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    stageUpBanners[anchorId] = event
                }
                shouldScrollToBottom = true
                generateHapticFeedback()

                let requestedAt = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if viewModel.selectedOshi.id == oshi.id {
                        withAnimation { isTyping = true }
                    }
                }
                RoleplayChatService.shared.generateStageUpReaction(event: event, oshi: oshi, chatHistory: messages) { reply in
                    // 演出を見てもらう時間を取ってから返す
                    let wait = max(3.0 - Date().timeIntervalSince(requestedAt), 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                        withAnimation { isTyping = false }
                        isAwaitingReply = false
                        guard let reply = reply, !reply.message.isEmpty else { return }
                        let aiMessage = ChatMessage(
                            id: UUID().uuidString,
                            content: reply.message,
                            isUser: false,
                            timestamp: Date().timeIntervalSince1970,
                            oshiId: oshi.id,
                            itemId: oshiItem?.id,
                            emotion: reply.emotion.rawValue,
                            action: reply.action,
                            innerThought: reply.innerThought
                        )
                        if viewModel.selectedOshi.id == oshi.id {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                messages.append(aiMessage)
                            }
                            shouldScrollToBottom = true
                        }
                        ChatDatabaseManager.shared.saveMessage(aiMessage) { error in
                            if let error = error {
                                print("❌ ステージアップ反応の保存エラー: \(error.localizedDescription)")
                            }
                        }
                    }
                }
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
                                onEdit: (isAdmin || isDeveloperMode) ? { startEditingMessage($0) } : nil,
                                // 編集は管理者だけ、削除は全ユーザーが使えるようにする。
                                onDelete: { confirmDeleteMessage($0) },
                                isLocked: !message.isUser && lockedReplyIds.contains(message.id) && !subscriptionManager.isSubscribed && !isAdmin,
                                onUnlock: {
                                    requestedUnlockReplyId = message.id
                                    showMessageLimitModal = true
                                }
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))

                            // 関係ステージが変わったときの演出（このメッセージの直後に出す）
                            if let event = stageUpBanners[message.id] {
                                RelationshipStageUpBanner(event: event, oshiName: viewModel.selectedOshi.name) {
                                    showRelationshipDetail = true
                                }
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                            }
                        }

                        // タイピングインジケーター
                        if isTyping {
                            TypingBubble(
                                oshiImageURL: viewModel.selectedOshi.imageUrl,
                                bubbleColor: oshiBubbleColor
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                    }
                    if adjustmentStore.item != nil || adjustmentStore.selectingItem || adjustmentStore.notice != nil {
                        ConversationAdjustmentCard(store: adjustmentStore, viewModel: viewModel, isReplyPending: isAwaitingReply || isTyping)
                    }
                    Color.clear
                        .frame(height: 20)
                        .id("bottomMarker")
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
                if shouldScroll {
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
                        .fill(Color(.secondarySystemBackground))
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
            
            if tutorialManager.isAt(.reply) {
                TutorialInlineTip(text: L10n.tutorialReplyHint, icon: "hand.point.down.fill")
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            HStack(spacing: 12) {
                // テキストフィールド
                HStack(spacing: 8) {
                    TextField(
                        L10n.messagePlaceholder(viewModel.selectedOshi.name), // ここを変更
                        text: $inputText,
                        axis: .vertical
                    )
                    .focused($isTextFieldFocused)
                    .chatMessageFont(sizeOffset: 1)
                    .lineLimit(1...5)
                    .onSubmit {
                        if canSend {
                            sendMessage()
                        }
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
    
    private var canSend: Bool {
        !inputText.isEmpty && !isLoading && !isAwaitingReply && !adjustmentStore.isSaving
    }

    private var sendButton: some View {
        Button(action: {
            if canSend {
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
        .disabled(!canSend)
        .opacity(isAwaitingReply ? 0.5 : 1.0)
        .scaleEffect(inputText.isEmpty ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: inputText.isEmpty)
    }
    
    // MARK: - 推し設定画面への遷移
    private var editPersonalityLink: some View {
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
            
        }
    }
    
    // MARK: - メッセージ送信（既読・タイピング機能付き）
    private func sendMessage() {
        guard !inputText.isEmpty, !isAwaitingReply, !adjustmentStore.isSaving else { return }
        
        let isSubscribed = subscriptionManager.isSubscribed
        
        if isSubscribed != MessageLimitManager.shared.isUserSubscribed() {
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: isSubscribed)
        }
        
        // 無料ユーザーの1日の上限チェック
        let isLimitedUser = !isSubscribed && !isAdmin
        let allowance = isLimitedUser ? MessageLimitManager.shared.sendAllowance() : .normal(isLast: false)
        if allowance == .blocked {
            isTextFieldFocused = false
            showMessageLimitModal = true
            return
        }
        if isLimitedUser {
            MessageLimitManager.shared.incrementCount()
        }
        remainingMessages = MessageLimitManager.shared.getRemainingMessages()
        let isLastMessageToday = allowance == .normal(isLast: true)
        
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
        // 返信待ちの間に推しが切り替わっても、返信は送信した推しのチャットに保存する
        let oshiId = viewModel.selectedOshi.id
        let sendingUserID = Auth.auth().currentUser?.uid
        isAwaitingReply = true
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
        tutorialManager.replyDidSend()
        
        // Firebaseに保存
        ChatDatabaseManager.shared.saveMessage(userMessage) { error in
            if let error = error {
                print("❌ ユーザーメッセージ保存エラー: \(error.localizedDescription)")
            }
        }

        // 5回に1回インタースティシャル広告を表示
        // 上限直前・ぼかし返信の回は上限モーダルが出るので、広告を重ねない
        if shouldShowAd && allowance == .normal(isLast: false) {
            IndividualChatInterstitialManager.shared.incrementAndShowIfNeeded()
        }

        // 少し間を置いて既読をつける
        let readDelay = Double.random(in: 2.5...5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + readDelay) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showReadReceipt = true
            }
            generateHapticFeedback()
        }

        // 既読後にタイピング開始
        let typingDelay = readDelay + Double.random(in: 2.0...3.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + typingDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isTyping = true
            }
        }

        let sendTime = Date()

        // AI応答を生成
        RoleplayChatService.shared.generateReply(for: userInput, oshi: viewModel.selectedOshi, chatHistory: messages) { reply, error, roleplayTrialEnded in
            // タイピング開始後、最低5秒は表示してから返信を出す
            let elapsed = Date().timeIntervalSince(sendTime)
            let minShowTime = typingDelay + 5.0
            let responseDelay = max(minShowTime - elapsed, 0.5)

            DispatchQueue.main.asyncAfter(deadline: .now() + responseDelay) {
                // タイピング終了
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isTyping = false
                }
                isAwaitingReply = false
                let isSameOshi = viewModel.selectedOshi.id == oshiId
                
                guard let reply = reply, !reply.message.isEmpty else {
                    print("❌ AI返信生成エラー: \(error?.localizedDescription ?? "empty reply")")
                    if isLimitedUser {
                        MessageLimitManager.shared.refundCount()
                        remainingMessages = MessageLimitManager.shared.getRemainingMessages()
                    }
                    if isSameOshi {
                        showReplyErrorAlert = true
                    }
                    tutorialManager.replyDidFail()
                    return
                }
                
                if let userID = sendingUserID, Auth.auth().currentUser?.uid == userID {
                    adjustmentStore.recordRound(userID: userID, oshiID: oshiId, messageID: userMessageId)
                }

                // AI返信を追加（content はセリフ本文、emotion / action は構造化データとして保持）
                let aiMessageId = UUID().uuidString
                let aiMessage = ChatMessage(
                    id: aiMessageId,
                    content: reply.message,
                    isUser: false,
                    timestamp: Date().timeIntervalSince1970,
                    oshiId: oshiId,
                    itemId: oshiItem?.id,
                    emotion: reply.emotion.rawValue,
                    action: reply.action,
                    innerThought: reply.innerThought
                )
                
                // 上限超過後の返信は途中までしか読めないようにする
                if allowance == .teaser {
                    MessageLimitManager.shared.lockReply(id: aiMessageId)
                    lockedReplyIds.insert(aiMessageId)
                }
                
                // 別の推しに切り替わっていたら画面には出さず保存だけする
                if isSameOshi {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        messages.append(aiMessage)
                    }
                    shouldScrollToBottom = true
                    generateHapticFeedback()
                    presentOnboardingPaywallIfNeeded()
                }
                tutorialManager.replyDidArrive()
                
                // Firebaseに保存
                ChatDatabaseManager.shared.saveMessage(aiMessage) { error in
                    if let error = error {
                        print("❌ AI返信保存エラー: \(error.localizedDescription)")
                    }
                }
                
                // 既読表示をリセット
                lastSentMessageId = nil
                showReadReceipt = false
                
                roleplayTrialStatus = RoleplayTrial.status
                guard isSameOshi else { return }
                if roleplayTrialEnded {
                    // ロールプレイのお試しを使い切った → 続きはプレミアムで
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isTextFieldFocused = false
                        paywallSource = .roleplay
                        showSubscriptionView = true
                    }
                } else if isLastMessageToday {
                    presentLastMessageFarewell(oshiId: oshiId)
                } else if allowance == .teaser {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isTextFieldFocused = false
                        showMessageLimitModal = true
                    }
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.markMessagesAsRead()
        }
    }
    
    /// 今日最後の1通への返信のあと、推しに名残惜しいセリフを言わせてから上限モーダルを出す
    private func presentLastMessageFarewell(oshiId: String) {
        // セリフ〜モーダルの間に次のメッセージを送らせない
        isAwaitingReply = true
        let oshi = viewModel.selectedOshi
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard viewModel.selectedOshi.id == oshiId else {
                isAwaitingReply = false
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isTyping = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTyping = false
            }
            guard viewModel.selectedOshi.id == oshiId else {
                isAwaitingReply = false
                return
            }
            let language = LanguageManager.shared.getConversationLanguage(for: oshi)
            // 会話履歴（Firebase）には保存しない、この場限りのセリフ
            let farewell = ChatMessage(
                id: UUID().uuidString,
                content: limitFarewellLine(for: oshi, language: language),
                isUser: false,
                timestamp: Date().timeIntervalSince1970,
                oshiId: oshiId,
                itemId: oshiItem?.id,
                emotion: CharacterEmotion.sad.rawValue,
                action: LanguageManager.shared.localizedString("limit_oshi_want_more_action", language: language, fallback: "")
            )
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                messages.append(farewell)
            }
            shouldScrollToBottom = true
            generateHapticFeedback()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isAwaitingReply = false
                guard viewModel.selectedOshi.id == oshiId else { return }
                isTextFieldFocused = false
                showMessageLimitModal = true
            }
        }
    }
    
    /// 推しの呼び方・話し方に合わせた「もっと話したいな…」のセリフ
    private func limitFarewellLine(for oshi: Oshi, language: String) -> String {
        let style = oshi.speaking_style?.lowercased() ?? ""
        let isPolite = ["敬語", "丁寧", "です", "polite", "formal"].contains { style.contains($0) }
        let nickname = oshi.user_nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = isPolite ? "limit_oshi_want_more_polite" : "limit_oshi_want_more_casual"
        if nickname.isEmpty {
            return LanguageManager.shared.localizedString("\(base)_no_name", language: language, fallback: "…")
        }
        let format = LanguageManager.shared.localizedString(base, language: language, fallback: "%@…")
        return String(format: format, nickname)
    }
    
    /// 最初の会話が盛り上がった直後（数回やりとりした後）に一度だけペイウォールを出す
    private func presentOnboardingPaywallIfNeeded() {
        guard PaywallCampaignManager.shared.registerAIReplyAndCheckOnboarding(
            isSubscribed: subscriptionManager.isSubscribed,
            isAdmin: isAdmin
        ) else { return }
        // 返信を読む時間を置いてから表示する
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard !showSubscriptionView, !subscriptionManager.isSubscribed else { return }
            paywallSource = .onboarding
            showSubscriptionView = true
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
                timestamp: editingMessage.timestamp,
                oshiId: editingMessage.oshiId,
                itemId: editingMessage.itemId,
                emotion: editingMessage.emotion,
                action: editingMessage.action,
                innerThought: editingMessage.innerThought
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
        loadRoleplaySituation()
        isFetchingMessages = true
        isInitialScrollComplete = false
        
        // 前の推しの監視を解除してから新しく監視する
        messagesObservation?.cancel()
        messagesObservation = nil
        let oshiId = viewModel.selectedOshi.id
        
        if let item = oshiItem {
            let itemId = item.id
            
            messagesObservation = ChatDatabaseManager.shared.fetchMessages(for: oshiId, itemId: itemId) { fetchedMessages, error in
                DispatchQueue.main.async {
                    // 別の推しに切り替わった後に届いた更新は反映しない
                    guard viewModel.selectedOshi.id == oshiId else { return }
                    if let error = error {
                        print("メッセージ読み込みエラー: \(error.localizedDescription)")
                        isFetchingMessages = false
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                        return
                    }
                    
                    if let messages = fetchedMessages, !messages.isEmpty {
                        let wasEmpty = self.messages.isEmpty
                        self.messages = messages
                        isFetchingMessages = false
                        if wasEmpty {
                            shouldScrollToBottom = true
                        }
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                    } else {
                        addInitialMessage(for: item)
                    }
                }
            }
        } else {
            messagesObservation = ChatDatabaseManager.shared.fetchMessages(for: oshiId) { fetchedMessages, error in
                DispatchQueue.main.async {
                    // 別の推しに切り替わった後に届いた更新は反映しない
                    guard viewModel.selectedOshi.id == oshiId else { return }
                    if let error = error {
                        print("メッセージ読み込みエラー: \(error.localizedDescription)")
                        isFetchingMessages = false
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                        return
                    }
                    
                    if let messages = fetchedMessages, !messages.isEmpty {
                        let wasEmpty = self.messages.isEmpty
                        self.messages = messages
                        isFetchingMessages = false
                        if wasEmpty {
                            shouldScrollToBottom = true
                        }
                        if messages.isEmpty {
                            isInitialScrollComplete = true
                        }
                    } else {
                        requestProactiveConversationStarter()
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

    private func requestProactiveConversationStarter() {
        isTyping = true

        RandomMessageManager.shared.sendProactiveMessageIfNeeded(for: viewModel.selectedOshi) { message in
            DispatchQueue.main.async {
                withAnimation {
                    isTyping = false
                }

                isFetchingMessages = false

                if message == nil {
                    isInitialScrollComplete = true
                } else {
                    self.markMessagesAsRead()
                }
            }
        }
    }
    
    private func resetViewState() {
        adjustmentStore.load(oshiID: viewModel.selectedOshi.id)
        requestedUnlockReplyId = nil
        messages = []
        isInitialScrollComplete = false
        isFetchingMessages = true
        isLoading = false
        shouldScrollToBottom = false
        hasMarkedAsRead = false
        isTyping = false
        showReadReceipt = false
        lastSentMessageId = nil
        stageUpBanners = [:]
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
            newOshi.user_nickname = data["user_nickname"] as? String
            newOshi.relationship_status = data["relationship_status"] as? String
            newOshi.relationship_detail = data["relationship_detail"] as? String
            newOshi.shared_memory = data["shared_memory"] as? String
            newOshi.signature_phrase = data["signature_phrase"] as? String
            newOshi.conversation_topics = data["conversation_topics"] as? [String]
            newOshi.forbidden_topics = data["forbidden_topics"] as? [String]
            newOshi.preferred_language = data["preferred_language"] as? String

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
            newOshi.relationship_status = oshiData["relationship_status"] as? String
            newOshi.relationship_detail = oshiData["relationship_detail"] as? String
            newOshi.shared_memory = oshiData["shared_memory"] as? String
            newOshi.signature_phrase = oshiData["signature_phrase"] as? String
            newOshi.conversation_topics = oshiData["conversation_topics"] as? [String]
            newOshi.forbidden_topics = oshiData["forbidden_topics"] as? [String]
            newOshi.preferred_language = oshiData["preferred_language"] as? String
            
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
                oshi.birthday = oshiData["birthday"] as? String
                oshi.hometown = oshiData["hometown"] as? String
                oshi.favorite_color = oshiData["favorite_color"] as? String
                oshi.favorite_food = oshiData["favorite_food"] as? String
                oshi.disliked_food = oshiData["disliked_food"] as? String
                oshi.interests = oshiData["interests"] as? [String]
                oshi.gender = oshiData["gender"] as? String
                oshi.height = oshiData["height"] as? Int
                oshi.user_nickname = oshiData["user_nickname"] as? String
                oshi.relationship_status = oshiData["relationship_status"] as? String
                oshi.relationship_detail = oshiData["relationship_detail"] as? String
                oshi.shared_memory = oshiData["shared_memory"] as? String
                oshi.signature_phrase = oshiData["signature_phrase"] as? String
                oshi.conversation_topics = oshiData["conversation_topics"] as? [String]
                oshi.forbidden_topics = oshiData["forbidden_topics"] as? [String]
                oshi.preferred_language = oshiData["preferred_language"] as? String

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
                    
                    var loadedOshi = Oshi(
                        id: id,
                        name: name,
                        imageUrl: oshiData["imageUrl"] as? String,
                        backgroundImageUrl: oshiData["backgroundImageUrl"] as? String,
                        memo: oshiData["memo"] as? String,
                        createdAt: oshiData["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                    )
                    loadedOshi.personality = oshiData["personality"] as? String
                    loadedOshi.speaking_style = oshiData["speaking_style"] as? String
                    loadedOshi.birthday = oshiData["birthday"] as? String
                    loadedOshi.hometown = oshiData["hometown"] as? String
                    loadedOshi.favorite_color = oshiData["favorite_color"] as? String
                    loadedOshi.favorite_food = oshiData["favorite_food"] as? String
                    loadedOshi.disliked_food = oshiData["disliked_food"] as? String
                    loadedOshi.interests = oshiData["interests"] as? [String]
                    loadedOshi.gender = oshiData["gender"] as? String
                    loadedOshi.height = oshiData["height"] as? Int
                    loadedOshi.user_nickname = oshiData["user_nickname"] as? String
                    loadedOshi.relationship_status = oshiData["relationship_status"] as? String
                    loadedOshi.relationship_detail = oshiData["relationship_detail"] as? String
                    loadedOshi.shared_memory = oshiData["shared_memory"] as? String
                    loadedOshi.signature_phrase = oshiData["signature_phrase"] as? String
                    loadedOshi.conversation_topics = oshiData["conversation_topics"] as? [String]
                    loadedOshi.forbidden_topics = oshiData["forbidden_topics"] as? [String]
                    loadedOshi.preferred_language = oshiData["preferred_language"] as? String
                    firstOshi = loadedOshi
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
    
    private func loadRewardedAd(completion: ((Bool) -> Void)? = nil) {
        guard !AdConfiguration.isDisabledForDevelopment else {
            rewardedAd = nil
            isLoadingAd = false
            completion?(false)
            return
        }

        let request = Request()
        RewardedAd.load(with: "ca-app-pub-4898800212808837/3373075660", request: request) { ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("リワード広告の読み込みに失敗しました: \(error.localizedDescription)")
                    completion?(false)
                    return
                }
                self.rewardedAd = ad
                completion?(ad != nil)
            }
        }
    }
    
    private func showRewardAd() {
        guard !isLoadingAd else { return }
        
        guard !AdConfiguration.isDisabledForDevelopment else {
            grantReward()
            return
        }

        // まだ読み込めていなければ、読み込み完了を待ってから表示する
        guard let rewardedAd = rewardedAd else {
            isLoadingAd = true
            loadRewardedAd { loaded in
                isLoadingAd = false
                if loaded, showMessageLimitModal {
                    showRewardAd()
                } else if !loaded {
                    showAdLoadFailedAlert = true
                }
            }
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        self.rewardedAd = nil
        rewardedAd.present(from: rootViewController) {
            DispatchQueue.main.async {
                grantReward()
                generateHapticFeedback()
            }
        }
        // 次の視聴に備えて先読み
        loadRewardedAd()
    }
    
    private func grantReward() {
        rewardAmount = MessageLimitManager.shared.grantRewardMessages()
        if rewardAmount > 0 {
            let lockedReplies = messages.filter {
                !$0.isUser && $0.oshiId == viewModel.selectedOshi.id && lockedReplyIds.contains($0.id)
            }
            let replyId = lockedReplies.first(where: { $0.id == requestedUnlockReplyId })?.id
                ?? lockedReplies.last?.id
            if let replyId {
                MessageLimitManager.shared.unlockReply(id: replyId)
                lockedReplyIds.remove(replyId)
            }
        }
        remainingMessages = MessageLimitManager.shared.getRemainingMessages()
        showMessageLimitModal = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showRewardCompletedModal = true
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
                oshi.relationship_status = data["relationship_status"] as? String
                oshi.relationship_detail = data["relationship_detail"] as? String
                oshi.shared_memory = data["shared_memory"] as? String
                oshi.signature_phrase = data["signature_phrase"] as? String
                oshi.conversation_topics = data["conversation_topics"] as? [String]
                oshi.forbidden_topics = data["forbidden_topics"] as? [String]
                oshi.preferred_language = data["preferred_language"] as? String

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
    /// 上限超過後の返信：途中までだけ見せて、続きはぼかす
    var isLocked: Bool = false
    var onUnlock: (() -> Void)? = nil
    
    @State private var showActionSheet = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    // メッセージバブル
                    Text(message.content)
                        .chatMessageFont()
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(userBubbleGradient)
                        .clipShape(ChatBubbleShape(isUser: true))
                        .shadow(color: Color(red: 0.91, green: 0.42, blue: 0.58).opacity(0.2), radius: 8, y: 4)
                        .onLongPressGesture {
                            if canShowActions {
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
                    // ロールプレイの動作描写
                    if let action = message.action, !action.isEmpty {
                        Text(action)
                            .chatMessageFont(sizeOffset: -3)
                            .italic()
                            .foregroundColor(.secondary)
                            .padding(.leading, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // メッセージバブル
                    oshiMessageText
                        .chatMessageFont()
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(oshiBubbleColor)
                        .clipShape(ChatBubbleShape(isUser: false))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                        .onLongPressGesture {
                            if canShowActions {
                                showActionSheet = true
                                generateHapticFeedback()
                            }
                        }
                    
                    if !isLocked, let thought = RoleplayReply.cleanInnerThought(message.innerThought) {
                        InnerThoughtView(thought: thought) {
                            replyMetadata
                        }
                        .id(message.id)
                    } else {
                        replyMetadata
                            .padding(.leading, 4)
                    }
                }
                
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, 2)
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text(onEdit == nil ? L10n.deleteMessageTitle : L10n.editMessageTitle),
                message: Text(onEdit == nil ? L10n.deleteMessageWarning : L10n.adminEditWarning),
                buttons: actionSheetButtons
            )
        }
    }

    private var canShowActions: Bool {
        onEdit != nil || onDelete != nil
    }

    private var replyMetadata: some View {
        HStack(spacing: 4) {
            Text(formatTime(timestamp: message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            if !message.characterEmotion.indicator.isEmpty {
                Text(message.characterEmotion.indicator)
                    .font(.system(size: 10))
            }
        }
        .fixedSize()
    }
    
    @ViewBuilder
    private var oshiMessageText: some View {
        if isLocked {
            let preview = lockedPreview
            VStack(alignment: .leading, spacing: 8) {
                Text(preview.visible + "…")
                Text(preview.hidden)
                    .blur(radius: 6)
                    .accessibilityHidden(true)
                Button(action: { onUnlock?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                        Text(NSLocalizedString("limit_locked_reply_unlock", comment: "Read the rest"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.91, green: 0.42, blue: 0.58),
                                    Color(red: 0.65, green: 0.45, blue: 0.85)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                }
                .buttonStyle(.plain)
            }
        } else {
            Text(message.content)
        }
    }
    
    /// 冒頭の3分の1ほど（最大40文字）だけ読めるようにする
    private var lockedPreview: (visible: String, hidden: String) {
        let chars = Array(message.content)
        let visibleCount = min(max(chars.count / 3, 1), 40)
        let visible = String(chars.prefix(visibleCount))
        var hidden = String(chars.dropFirst(visibleCount))
        // 短い返信でも「続きがある」ように見せる
        while hidden.count < 24 {
            hidden += hidden.isEmpty ? "……" : hidden
        }
        return (visible, hidden)
    }

    private var actionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if let onEdit = onEdit {
            buttons.append(.default(Text(L10n.edit)) { onEdit(message) })
        }
        if let onDelete = onDelete {
            buttons.append(.destructive(Text(L10n.delete)) { onDelete(message) })
        }
        buttons.append(.cancel(Text(L10n.cancel)))
        return buttons
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
    var bubbleColor: Color = Color(.secondarySystemBackground)
    
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
            .background(bubbleColor)
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
    @Environment(\.colorScheme) var colorScheme
    
    private var oshiBubbleColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color.white
    }
    
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
            oshiBubbleColor: oshiBubbleColor,
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
    @Environment(\.colorScheme) var colorScheme
    
    private var oshiBubbleColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color.white
    }
    
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
            oshiBubbleColor: oshiBubbleColor,
            onEdit: onEdit,
            onDelete: onDelete
        )
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let oshiName: String
    @Environment(\.colorScheme) var colorScheme
    
    private var oshiBubbleColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color(.systemGray6)
    }
    
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
            oshiBubbleColor: oshiBubbleColor,
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
