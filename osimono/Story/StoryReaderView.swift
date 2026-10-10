import SwiftUI

/// 読む画面の非同期処理の状態
enum StoryReaderStatus: Equatable {
    case idle
    case generating
    case saving
    case generationError
    case saveError
    case limit
    /// 再試行しても成功しない失敗。理由の文言を持つ
    case needsReopen(String)

    var isBusy: Bool { self == .generating || self == .saving }
}

// MARK: - 読む画面（Firebase・AI と接続するラッパー）

struct StoryReaderView: View {
    @StateObject private var session: StorySession
    let ownerID: String?
    let onSaved: (StoryRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSubscription = false
    @State private var isAdLoading = false
    @State private var isAdPresented = false
    @State private var showAdLoadFailed = false
    @State private var isReaderVisible = false
    @State private var adRequestID = UUID()
    /// 生成・保存中に本文の末尾へ表示する、送信した行動
    @State private var submittedIntent: String?

    init(record: StoryRecord, ownerID: String?, onSaved: @escaping (StoryRecord) -> Void) {
        _session = StateObject(wrappedValue: StorySession.live(record: record))
        self.ownerID = ownerID
        self.onSaved = onSaved
    }

    private var status: StoryReaderStatus {
        if session.isBusy { return session.hasPendingSave ? .saving : .generating }
        switch session.failure {
        case .generation: return .generationError
        case .save: return .saveError
        case .limit: return .limit
        case .needsReopen: return .needsReopen(session.error ?? StoryError.conflict.localizedDescription)
        case nil: return .idle
        }
    }

    private var paywallCharacter: StoryCharacter? {
        let configuration = session.record.configuration
        return configuration.cast.first(where: { $0.id == configuration.leadID })
            ?? configuration.cast.first
    }

    var body: some View {
        StoryReaderScreen(
            record: session.record,
            status: status,
            generationErrorMessage: session.failure == .generation ? session.error : nil,
            submittedIntent: submittedIntent,
            pendingScene: session.pendingScene,
            canInteract: ownerID == session.record.ownerID,
            isAdLoading: isAdLoading,
            adRewardCount: PaywallConfig.shared.adRewardMessageCount,
            onStart: { Task { await session.advance() } },
            onAdvance: { choice, intent in
                submittedIntent = intent
                Task { await session.advance(choiceIndex: choice, freeInput: intent) }
            },
            onRetry: { Task { await session.retry() } },
            onBackToLibrary: { dismiss() },
            onUpgrade: { showSubscription = true },
            onWatchAd: watchRewardAd
        )
        .sheet(isPresented: $showSubscription, onDismiss: resumeAfterLimitIfAvailable) {
            SubscriptionPreView(source: .storyLimit, storyCharacter: paywallCharacter)
        }
        .alert(NSLocalizedString("reward_ad_load_failed", comment: "Couldn't load the ad"),
               isPresented: $showAdLoadFailed) {
            Button("OK", role: .cancel) {}
        }
        .onChange(of: session.record.revision) { _ in
            onSaved(session.record)
            submittedIntent = nil
        }
        .onAppear {
            isReaderVisible = true
            session.activate()
            resumeAfterLimitIfAvailable()
        }
        .onDisappear {
            // 広告の全画面表示で一時的に隠れた場合は、視聴後の再開を維持する。
            guard !isAdPresented else { return }
            isReaderVisible = false
            adRequestID = UUID()
            isAdLoading = false
            session.deactivate()
        }
        .onChange(of: ownerID) { _ in
            adRequestID = UUID()
            isAdLoading = false
            isAdPresented = false
            session.authenticationChanged()
        }
        .onChange(of: subscriptionManager.isSubscribed) { _ in
            if !showSubscription { resumeAfterLimitIfAvailable() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active { resumeAfterLimitIfAvailable() }
        }
    }

    private func resumeAfterLimitIfAvailable() {
        guard isReaderVisible, ownerID == session.record.ownerID, session.failure == .limit,
              !showSubscription, !isAdLoading else { return }
        MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: subscriptionManager.isSubscribed)
        guard !MessageLimitManager.shared.hasReachedLimit() else { return }
        Task { await session.resumeAfterLimit() }
    }

    private func watchRewardAd() {
        guard isReaderVisible, ownerID == session.record.ownerID, session.failure == .limit,
              !isAdLoading, !showSubscription else { return }
        if subscriptionManager.isSubscribed {
            resumeAfterLimitIfAvailable()
            return
        }
        isAdLoading = true
        let requestID = UUID()
        adRequestID = requestID
        let manager = RewardAdManager.shared
        let present = {
            guard adRequestID == requestID, isReaderVisible else { return }
            isAdPresented = true
            manager.showAd(onFailure: {
                guard adRequestID == requestID, isReaderVisible else { return }
                showAdLoadFailed = true
            }) { earnedReward in
                guard adRequestID == requestID, isReaderVisible else { return }
                isAdLoading = false
                isAdPresented = false
                if earnedReward {
                    MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: subscriptionManager.isSubscribed)
                    MessageLimitManager.shared.grantRewardMessages()
                    resumeAfterLimitIfAvailable()
                }
            }
        }
        if AdConfiguration.isDisabledForDevelopment || manager.isAdReady {
            present()
        } else {
            manager.loadRewardedAd { loaded in
                guard adRequestID == requestID, isReaderVisible else { return }
                if loaded { present() }
                else {
                    isAdLoading = false
                    showAdLoadFailed = true
                }
            }
        }
    }
}

// MARK: - 読む画面（表示のみ）

/// ビジュアルノベル風の縦スクロール。扉・読書中・章間・完結をひとつの ScrollView で表示する。
struct StoryReaderScreen: View {
    var record: StoryRecord
    var status: StoryReaderStatus = .idle
    var generationErrorMessage: String? = nil
    var submittedIntent: String? = nil
    /// 生成済みで保存待ちの場面（保存中・保存エラーのときだけ表示）
    var pendingScene: StoryScene? = nil
    var canInteract = true
    var isAdLoading = false
    var adRewardCount = 5
    var onStart: () -> Void = {}
    var onAdvance: (_ choice: Int?, _ intent: String) -> Void = { _, _ in }
    var onRetry: () -> Void = {}
    var onBackToLibrary: () -> Void = {}
    var onUpgrade: () -> Void = {}
    var onWatchAd: () -> Void = {}

    @State private var draft: StoryActionDraft
    /// 最初の位置合わせが済んだか（以降の移動はアニメーションする）
    @State private var hasPositioned = false

    init(record: StoryRecord, status: StoryReaderStatus = .idle, generationErrorMessage: String? = nil,
         submittedIntent: String? = nil,
         pendingScene: StoryScene? = nil, canInteract: Bool = true,
         isAdLoading: Bool = false, adRewardCount: Int = 5,
         draft: StoryActionDraft = StoryActionDraft(),
         onStart: @escaping () -> Void = {}, onAdvance: @escaping (_ choice: Int?, _ intent: String) -> Void = { _, _ in },
         onRetry: @escaping () -> Void = {}, onBackToLibrary: @escaping () -> Void = {},
         onUpgrade: @escaping () -> Void = {}, onWatchAd: @escaping () -> Void = {}) {
        self.record = record
        self.status = status
        self.generationErrorMessage = generationErrorMessage
        self.submittedIntent = submittedIntent
        self.pendingScene = pendingScene
        self.canInteract = canInteract
        self.isAdLoading = isAdLoading
        self.adRewardCount = adRewardCount
        self.onStart = onStart
        self.onAdvance = onAdvance
        self.onRetry = onRetry
        self.onBackToLibrary = onBackToLibrary
        self.onUpgrade = onUpgrade
        self.onWatchAd = onWatchAd
        _draft = State(initialValue: draft)
    }

    private enum Anchor: Hashable {
        case top, choices, bottom
        case scene(Int)
    }

    /// 操作に応じたスクロール要求（同じ位置への要求も毎回動くよう id を持つ）
    private struct ScrollRequest: Equatable {
        let target: Anchor
        let anchor: UnitPoint
        let id = UUID()
    }

    @State private var scrollRequest: ScrollRequest?

    /// 保存中・保存エラーでは、生成済みの場面も本文として見せる（`record` はまだ進んでいない）
    private var visiblePending: StoryScene? {
        switch status {
        case .saving, .saveError, .needsReopen: return pendingScene
        default: return nil
        }
    }
    /// ヘッダーと本文に使う場面（保存済み＋保存待ち）
    private var displayScenes: [StoryScene] { record.scenes + (visiblePending.map { [$0] } ?? []) }
    private var isPrologue: Bool { displayScenes.isEmpty }
    private var hasBottomBar: Bool {
        if status.isBusy { return true }
        guard status == .idle, canInteract, !record.isComplete else { return false }
        return isPrologue || !draft.isConfirmingChapter
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 0).id(Anchor.top)
                    if isPrologue {
                        StoryPrologueContent(configuration: record.configuration)
                    } else {
                        ForEach(record.scenes) { scene in
                            sceneBlock(scene).id(Anchor.scene(scene.index))
                        }
                    }
                    tail
                    Color.clear.frame(height: 1).id(Anchor.bottom)
                }
                .padding(.horizontal, StoryTheme.gutter)
                .padding(.top, isPrologue ? 12 : 20)
                .padding(.bottom, hasBottomBar ? StoryTheme.bottomBarClearance : 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !isPrologue { header }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .task(id: record.revision) {
                // 新しい場面と選択エリアのレイアウトが確定してから位置を決める
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                if !hasPositioned && record.isComplete {
                    // 完結した物語を開いたときは末尾（完結カード）から
                    proxy.scrollTo(Anchor.bottom, anchor: .bottom)
                } else if let scene = record.currentScene {
                    // 読書中は現在の場面の頭から。保存された新しい場面にも移動する
                    withAnimation(hasPositioned ? .easeInOut(duration: 0.3) : nil) {
                        proxy.scrollTo(Anchor.scene(scene.index), anchor: .top)
                    }
                }
                hasPositioned = true
            }
            .onChange(of: record.revision) { _ in
                draft = StoryActionDraft()
                guard let scene = record.currentScene else { return }
                StoryAccessibility.announce(String(format: StoryText.text("story_scene_ready"), StoryText.progress(scene)))
            }
            .onChange(of: status) { newStatus in
                guard newStatus != .idle else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(Anchor.bottom, anchor: .bottom) }
                }
            }
            .onChange(of: scrollRequest) { request in
                // 操作したときだけ動かす（場面の保存で下書きがリセットされても動かさない）
                guard let request else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo(request.target, anchor: request.anchor) }
                }
            }
            .environment(\.storyScrollToTop) {
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(Anchor.top, anchor: .top) }
            }
        }
        .background {
            readerBackground.ignoresSafeArea()
        }
        .navigationTitle(record.configuration.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(StoryTheme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .preferredColorScheme(.light)
    }

    @ViewBuilder private var readerBackground: some View {
        if isPrologue {
            StoryTheme.background
        } else {
            StorySceneryImage(backdrop: StoryBackdrop.resolve(
                setting: record.configuration.setting,
                scenes: displayScenes
            ))
            .overlay(StoryTheme.background.opacity(0.3))
            .allowsHitTesting(false)
        }
    }

    // MARK: 固定ヘッダー

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if let scene = displayScenes.last {
                    Text(StoryText.progress(scene))
                        .font(.storyFootnote.weight(.semibold))
                        .foregroundColor(StoryTheme.body)
                }
                if record.isComplete {
                    Text(StoryText.text("story_seal_complete"))
                        .font(.storyCaption.weight(.bold))
                        .foregroundColor(StoryTheme.pinkText)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 18)
                        .background(Capsule().fill(StoryTheme.softPink))
                }
            }
            .accessibilityElement(children: .combine)
            SceneProgressBar(readCount: record.isComplete ? 9 : max(0, displayScenes.count - 1),
                             currentIndex: record.isComplete ? nil : displayScenes.count - 1)
        }
        .padding(.horizontal, StoryTheme.gutter)
        .padding(.top, 2)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                StoryTheme.background.opacity(0.92)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(StoryTheme.border).frame(height: 0.5) }
    }

    // MARK: 本文

    private func sceneBlock(_ scene: StoryScene, isUnsaved: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 読み返しのとき、話の切れ目がわかるように
            if scene.sceneNumber == 1 && scene.episode > 1 {
                StoryEpisodeMarker(episode: scene.episode - 1)
            }
            SceneDivider(number: scene.sceneNumber,
                         isCurrent: !record.isComplete && scene.index == displayScenes.count - 1)
                .padding(.top, scene.index == 0 ? 0 : 8)
            NarrationCard(text: scene.narration, isUnsaved: isUnsaved)
            ForEach(Array(scene.lines.enumerated()), id: \.offset) { _, line in
                if let character = record.configuration.cast.first(where: { $0.id == line.speakerID }) {
                    DialogueCard(character: character, text: line.text)
                }
            }
            if let decision = record.decisions.first(where: { $0.sceneIndex == scene.index }) {
                UserActionCard(text: decision.intent)
            }
        }
    }

    @ViewBuilder private var tail: some View {
        if record.isComplete {
            StoryEndingDivider()
            StoryCompletionCardContainer(cast: record.configuration.cast, onBackToLibrary: onBackToLibrary)
            StoryRereadHint()
        } else if status != .idle {
            // 本文は消さず、送信した行動→（保存待ちの場面）→状態UI の順に末尾へ
            if let submittedIntent { UserActionCard(text: submittedIntent) }
            if let visiblePending {
                sceneBlock(visiblePending, isUnsaved: status != .saving)
                    .id(Anchor.scene(visiblePending.index))
            }
            statusCard.padding(.top, 8)
        } else if canInteract, let scene = record.currentScene {
            if draft.isConfirmingChapter, let intent = draft.intent(in: scene) {
                StoryChapterTransition(episode: scene.episode, intent: intent,
                                       onNext: { onAdvance(draft.effectiveChoice, intent) },
                                       onChange: {
                                           draft.isConfirmingChapter = false
                                           // 選び直すときは同じ場面の選択エリアへ戻る
                                           scrollRequest = ScrollRequest(target: .choices, anchor: .top)
                                       })
            } else {
                StoryChoicePanel(choices: scene.choices, draft: $draft)
                    .padding(.top, 8)
                    .id(Anchor.choices)
            }
        }
    }

    @ViewBuilder private var statusCard: some View {
        switch status {
        case .idle: EmptyView()
        case .generating: StatusCard(kind: .generating)
        case .saving: StatusCard(kind: .saving)
        case .generationError:
            // 最初の場面の生成では、選んだ行動はない
            StatusCard(kind: .generationError(keepsAction: submittedIntent != nil),
                       detail: generationErrorMessage, onRetry: onRetry)
        case .saveError:
            StatusCard(kind: .saveError(sceneNumber: pendingScene?.sceneNumber ?? record.scenes.count % 3 + 1), onRetry: onRetry)
        case .limit:
            StatusCard(kind: .limit, canResolveLimit: canInteract,
                       isAdLoading: isAdLoading, adRewardCount: adRewardCount,
                       onUpgrade: onUpgrade, onWatchAd: onWatchAd)
        case .needsReopen(let message): StatusCard(kind: .needsReopen(message: message), onBackToLibrary: onBackToLibrary)
        }
    }

    // MARK: 固定ボトムバー

    @ViewBuilder private var bottomBar: some View {
        if status.isBusy {
            StoryBottomBar {
                Label {
                    Text(StoryText.text(status == .saving ? "story_lock_saving" : "story_lock_generating"))
                } icon: {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundColor(StoryTheme.placeholder)
                }
                .font(.storyFootnote)
                .foregroundColor(StoryTheme.secondary)
                StoryPrimaryButton(title: StoryText.text(status == .saving ? "story_saving" : "story_busy_generating"),
                                   isEnabled: false) {}
            }
        } else if hasBottomBar {
            if isPrologue {
                prologueBar
            } else {
                actionBar
            }
        }
    }

    /// 扉のCTA（背景は Background へフェード）
    private var prologueBar: some View {
        StoryPrimaryButton(title: StoryText.text("story_start"), systemImage: "book.fill", action: onStart)
            .accessibilityIdentifier("story.start")
            .padding(.horizontal, StoryTheme.gutter)
            .padding(.top, 28)
            .padding(.bottom, 8)
            .background {
                LinearGradient(stops: [.init(color: StoryTheme.background.opacity(0), location: 0),
                                       .init(color: StoryTheme.background, location: 0.3)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            }
    }

    private var actionBar: some View {
        StoryBottomBar {
            HStack(spacing: 6) {
                if let scene = record.currentScene, let intent = draft.intent(in: scene) {
                    Text(draft.hasText ? StoryText.text("story_mode_free")
                         : String(format: StoryText.text("story_mode_choice"), StoryActionDraft.choiceKey(draft.choice ?? 0)))
                        .font(.storyCaption.weight(.bold))
                        .foregroundColor(StoryTheme.pinkText)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 20)
                        .background(Capsule().fill(StoryTheme.softPink))
                        .fixedSize()
                    Text(intent)
                        .font(.storyFootnote)
                        .foregroundColor(StoryTheme.text)
                        .lineLimit(1)
                } else {
                    Text(StoryText.text("story_bar_empty"))
                        .font(.storyFootnote)
                        .foregroundColor(StoryTheme.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 18)
            .accessibilityElement(children: .combine)
            StoryPrimaryButton(title: StoryText.text("story_send_action"), isEnabled: draft.canProceed, action: proceed)
                .accessibilityIdentifier("story.send")
        }
    }

    private func proceed() {
        guard let scene = record.currentScene, let intent = draft.intent(in: scene) else { return }
        if scene.sceneNumber == 3 && !scene.isFinal {
            // 章末は確認カードを挟む
            withAnimation(.easeOut(duration: 0.2)) { draft.isConfirmingChapter = true }
            scrollRequest = ScrollRequest(target: .bottom, anchor: .bottom)
        } else {
            onAdvance(draft.effectiveChoice, intent)
        }
    }
}

// MARK: - 先頭へのスクロール

private struct StoryScrollToTopKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    /// 完結カードの「最初から読み返す」から、第1話・場面1へ戻る
    var storyScrollToTop: () -> Void {
        get { self[StoryScrollToTopKey.self] }
        set { self[StoryScrollToTopKey.self] = newValue }
    }
}

private struct StoryCompletionCardContainer: View {
    var cast: [StoryCharacter]
    var onBackToLibrary: () -> Void
    @Environment(\.storyScrollToTop) private var scrollToTop

    var body: some View {
        StoryCompletionCard(cast: cast, onReread: scrollToTop, onBackToLibrary: onBackToLibrary)
    }
}

// MARK: - Previews

#if DEBUG
private func readerPreview(_ record: StoryRecord, status: StoryReaderStatus = .idle, submitted: String? = nil,
                           pending: StoryScene? = nil, draft: StoryActionDraft = StoryActionDraft()) -> some View {
    NavigationStack {
        StoryReaderScreen(record: record, status: status, submittedIntent: submitted, pendingScene: pending, draft: draft)
    }
}

#Preview("扉") { readerPreview(StoryPreviewData.record(sceneCount: 0)) }
#Preview("扉｜生成中") { readerPreview(StoryPreviewData.record(sceneCount: 0), status: .generating) }
#Preview("読書中｜未選択") { readerPreview(StoryPreviewData.record(sceneCount: 2)) }
#Preview("読書中｜選択肢B") { readerPreview(StoryPreviewData.record(sceneCount: 2), draft: StoryActionDraft(choice: 1)) }
#Preview("読書中｜自由入力") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), draft: StoryActionDraft(choice: 1, text: "その前に、みんなで屋上に行ってみない？と誘う"))
}
#Preview("章間トランジション") {
    readerPreview(StoryPreviewData.record(sceneCount: 3), draft: StoryActionDraft(choice: 0, isConfirmingChapter: true))
}
#Preview("第2話以降") { readerPreview(StoryPreviewData.record(sceneCount: 5)) }
#Preview("完結") { readerPreview(StoryPreviewData.record(sceneCount: 9)) }
#Preview("状態｜生成中") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .generating, submitted: "さくらの案に乗って、実行委員に相談しに行く")
}
#Preview("状態｜保存中") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .saving, submitted: "さくらの案に乗って、実行委員に相談しに行く",
                  pending: StoryPreviewData.scene(2))
}
#Preview("状態｜生成エラー") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .generationError, submitted: "さくらの案に乗って、実行委員に相談しに行く")
}
#Preview("状態｜保存エラー") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .saveError, submitted: "さくらの案に乗って、実行委員に相談しに行く",
                  pending: StoryPreviewData.scene(2))
}
#Preview("状態｜保存の競合") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .needsReopen(StoryError.conflict.localizedDescription),
                  submitted: "さくらの案に乗って、実行委員に相談しに行く", pending: StoryPreviewData.scene(2))
}
#Preview("状態｜AI利用上限") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .limit, submitted: "さくらの案に乗って、実行委員に相談しに行く")
}

#Preview("状態｜広告読み込み中") {
    NavigationStack {
        StoryReaderScreen(record: StoryPreviewData.record(sceneCount: 2), status: .limit,
                          submittedIntent: "さくらの案に乗る", isAdLoading: true)
    }
}

#Preview("状態｜AI利用上限・大きい文字") {
    readerPreview(StoryPreviewData.record(sceneCount: 2), status: .limit)
        .environment(\.dynamicTypeSize, .accessibility2)
}
#Preview("状態｜最初の場面を保存中") {
    readerPreview(StoryPreviewData.record(sceneCount: 0), status: .saving, pending: StoryPreviewData.scene(0))
}
#Preview("完結｜AXサイズ") {
    readerPreview(StoryPreviewData.record(sceneCount: 9)).environment(\.dynamicTypeSize, .accessibility2)
}
#endif
