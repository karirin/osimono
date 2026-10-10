import SwiftUI

// MARK: - 画面の状態

enum StoryLibraryPhase: Equatable {
    case loading
    case failed(String)
    case noOshi
    case noStories
    case list

    /// 物語が1件でもあれば一覧。0件なら推し0人を優先して空状態を出し分ける。
    static func resolve(records: [StoryRecord], castCount: Int, hasLoaded: Bool, error: String?) -> StoryLibraryPhase {
        if !records.isEmpty { return .list }
        if let error { return .failed(error) }
        if !hasLoaded { return .loading }
        return castCount == 0 ? .noOshi : .noStories
    }
}

// MARK: - ライブラリ（Firebase と接続するラッパー）

/// チャット一覧の入口からモーダルで開くストーリーライブラリ。
struct StoryModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var library = StoryLibrary()
    @State private var path: [String] = []
    @State private var showCreate = false
    @State private var showNoOshi = false
    @State private var showAddOshi = false
    @State private var registerAfterDismiss = false

    private var phase: StoryLibraryPhase {
        .resolve(records: library.records, castCount: library.cast.count, hasLoaded: library.hasLoaded, error: library.error)
    }

    var body: some View {
        NavigationStack(path: $path) {
            StoryLibraryScreen(
                phase: phase,
                records: library.records,
                refreshError: library.records.isEmpty ? nil : library.error,
                canCreate: library.ownerID != nil && !library.isLoading,
                onClose: { dismiss() },
                onNew: startNew,
                onRegister: { showAddOshi = true },
                onOpen: { path.append($0.id) },
                onRetry: { Task { await library.load() } }
            )
            .refreshable { await library.load() }
            .navigationDestination(for: String.self) { id in
                if let record = library.records.first(where: { $0.id == id }) {
                    StoryReaderView(record: record, ownerID: library.ownerID, onSaved: library.replace)
                }
            }
            .onAppear { if library.ownerID != nil { Task { await library.load() } } }
        }
        .preferredColorScheme(.light)
        .onAppear { library.start() }
        .onDisappear { library.stop() }
        .onChange(of: library.ownerID) { _ in
            path = []
            showCreate = false
            showNoOshi = false
            showAddOshi = false
        }
        .sheet(isPresented: $showCreate) {
            if let ownerID = library.ownerID {
                StoryCreationView(cast: library.cast, ownerID: ownerID,
                                  draft: StoryDraft.initial(cast: library.cast)) { record in
                    library.replace(record)
                    path.append(record.id)
                    showCreate = false
                }
            }
        }
        .sheet(isPresented: $showNoOshi, onDismiss: {
            if registerAfterDismiss { registerAfterDismiss = false; showAddOshi = true }
        }) {
            // 物語はあるが推しが0人のときの「新しい物語」
            NavigationStack {
                StoryEmptyStateView(kind: .noOshi, onPrimary: {
                    registerAfterDismiss = true
                    showNoOshi = false
                }, onClose: { showNoOshi = false })
                .background(StoryTheme.background.ignoresSafeArea())
                .storyNavigationTitle()
            }
            .preferredColorScheme(.light)
        }
        .fullScreenCover(isPresented: $showAddOshi, onDismiss: { Task { await library.load() } }) { AddOshiView() }
    }

    private func startNew() {
        if library.cast.isEmpty { showNoOshi = true } else { showCreate = true }
    }
}

// MARK: - ライブラリ（表示のみ）

struct StoryLibraryScreen: View {
    var phase: StoryLibraryPhase
    var records: [StoryRecord]
    /// 一覧表示中の再読み込み失敗
    var refreshError: String? = nil
    var canCreate = true
    var onClose: () -> Void = {}
    var onNew: () -> Void = {}
    var onRegister: () -> Void = {}
    var onOpen: (StoryRecord) -> Void = { _ in }
    var onRetry: () -> Void = {}

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(StoryTheme.background.ignoresSafeArea())
            .storyNavigationTitle()
            .toolbar {
                // 推し未登録では閉じるを下部に集約し、重複させない
                if phase != .noOshi {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: onClose) {
                            Text(StoryText.text("story_close"))
                                .font(.body)
                                .foregroundColor(StoryTheme.pinkText)
                                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        }
                    }
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView(StoryText.text("story_loading"))
                .tint(StoryTheme.primaryStart)
                .foregroundColor(StoryTheme.secondary)
        case .failed(let message):
            loadError(message)
        case .noOshi:
            StoryEmptyStateView(kind: .noOshi, onPrimary: onRegister, onClose: onClose)
        case .noStories:
            StoryEmptyStateView(kind: .noStories, onPrimary: onNew, onClose: onClose, isPrimaryEnabled: canCreate)
        case .list:
            list
        }
    }

    private var inProgress: [StoryRecord] { records.filter { !$0.isComplete } }
    private var completed: [StoryRecord] { records.filter(\.isComplete) }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(StoryText.text("story_concept"))
                    .font(.storySubheadline)
                    .foregroundColor(StoryTheme.body)
                    .storyLineHeight(1.65, fontSize: 15, relativeTo: .subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                StoryPrimaryButton(title: StoryText.text("story_new"), systemImage: "plus.circle.fill",
                                   isEnabled: canCreate, action: onNew)
                    .accessibilityIdentifier("story.new")
                    .padding(.top, 16)
                if let refreshError { refreshNotice(refreshError).padding(.top, 16) }
                section(StoryText.text("story_in_progress"), records: inProgress)
                section(StoryText.text("story_completed"), records: completed)
            }
            .padding(.horizontal, StoryTheme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 34)
        }
    }

    @ViewBuilder private func section(_ title: String, records: [StoryRecord]) -> some View {
        if !records.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.storyHeadline).foregroundColor(StoryTheme.text)
                Text("\(records.count)").font(.storyFootnote).foregroundColor(StoryTheme.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 4)
            .padding(.top, 28)
            .padding(.bottom, 12)
            VStack(spacing: 12) {
                ForEach(records) { record in
                    StoryLibraryCard(record: record) { onOpen(record) }
                }
            }
        }
    }

    private func refreshNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(StoryTheme.error).accessibilityHidden(true)
            Text(message).font(.storyFootnote).foregroundColor(StoryTheme.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(StoryText.text("story_retry"), action: onRetry)
                .font(.storyFootnote.weight(.semibold))
                .foregroundColor(StoryTheme.pinkText)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 14)
        .storyCardSurface(radius: StoryTheme.Radius.cardSmall)
    }

    private func loadError(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(StoryTheme.error)
                .accessibilityHidden(true)
            Text(message)
                .font(.storySubheadline)
                .foregroundColor(StoryTheme.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            StoryPrimaryButton(title: StoryText.text("story_retry"), systemImage: "arrow.clockwise", action: onRetry)
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }
}

extension View {
    /// ライブラリ共通のナビバー（中央タイトル 17 Semibold・Background）
    func storyNavigationTitle(_ title: String = StoryText.text("story_title")) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(StoryTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

// MARK: - ストーリーカード

struct StoryLibraryCard: View {
    var record: StoryRecord
    var action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isComplete: Bool { record.isComplete }
    private var cast: [StoryCharacter] { record.configuration.cast }
    private var castNames: String { cast.map(\.name).joined(separator: StoryText.text("story_name_separator")) }
    /// 読了した場面数（現在の場面の手前まで）
    private var readCount: Int { isComplete ? 9 : max(0, record.scenes.count - 1) }

    private var progressLabel: String {
        record.currentScene.map(StoryText.progress) ?? StoryText.text("story_ready")
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                cover
                VStack(alignment: .leading, spacing: 0) {
                    AvatarStack(characters: cast, size: dynamicTypeSize.isAccessibilitySize ? 36 : 44,
                                borderWidth: 3, overlap: 10)
                        .shadow(color: StoryTheme.text.opacity(0.08), radius: 3, y: 2)
                        .padding(.top, -22)
                    HStack(alignment: .center, spacing: 8) {
                        Text(record.configuration.title)
                            .storyFont(size: 18, weight: .bold, relativeTo: .headline)
                            .foregroundColor(StoryTheme.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isComplete ? Color(hex: "C4BBCC") : StoryTheme.chevron)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, 10)
                    Text(String(format: StoryText.text("story_cast_label"), castNames))
                        .font(.storyFootnote)
                        .foregroundColor(StoryTheme.secondary)
                        .padding(.top, 4)
                    if isComplete { completedLabel.padding(.top, 12) } else { progress.padding(.top, 14) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous).strokeBorder(StoryTheme.border, lineWidth: 1))
            .modifier(StoryLibraryCardShadow(isComplete: isComplete))
            .contentShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(StoryPressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        let status = isComplete
            ? StoryText.text("story_seal_complete") + " " + StoryText.text("story_reread")
            : progressLabel
        return [record.configuration.title, String(format: StoryText.text("story_cast_label"), castNames), status]
            .joined(separator: " ")
    }

    // 保存済みの場面に合う風景をカバーにも表示する。
    private var cover: some View {
        StorySceneryImage(backdrop: StoryBackdrop.resolve(
            setting: record.configuration.setting, scenes: record.scenes))
            .frame(height: 112)
            .overlay {
                LinearGradient(colors: [.clear, Color.white.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .topTrailing) {
                if isComplete {
                    CompletionSeal().padding(.top, 14).padding(.trailing, 16)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    @ViewBuilder private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            let count = Text(String(format: StoryText.text("story_scene_count"), readCount))
                .font(.storyCaption).foregroundColor(StoryTheme.secondary)
            let label = Text(progressLabel)
                .font(.storyFootnote.weight(.semibold)).foregroundColor(StoryTheme.pinkText)
            if dynamicTypeSize.isAccessibilitySize {
                label
                count
            } else {
                HStack(alignment: .firstTextBaseline) {
                    label
                    Spacer(minLength: 8)
                    count
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "F2EDF4"))
                    Capsule().fill(StoryTheme.gradient).frame(width: proxy.size.width * CGFloat(readCount) / 9)
                }
            }
            .frame(height: 4)
        }
    }

    private var completedLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color(hex: "7B62B8"), StoryTheme.softPurple)
                .font(.system(size: 16))
                .accessibilityHidden(true)
            Text(StoryText.text("story_the_end"))
                .font(.storyFootnote)
                .foregroundColor(StoryTheme.purpleText)
        }
    }
}

private struct StoryLibraryCardShadow: ViewModifier {
    var isComplete: Bool
    func body(content: Content) -> some View {
        if isComplete {
            content.storyShadow(.normal)
        } else {
            content.storyShadow(.pink(opacity: 0.10, radius: 20, y: 6))
        }
    }
}

/// 「完結」シール（56pt・白・破線ボーダー・-10°）
struct CompletionSeal: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white)
                .shadow(color: Color(hex: "6E5A9E").opacity(0.18), radius: 5, y: 3)
            Circle()
                .strokeBorder(Color(hex: "FF9BB3"), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
                .frame(width: 48, height: 48)
            VStack(spacing: 1) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(hex: "E85A7A"))
                Text(StoryText.text("story_seal_complete"))
                    .font(.system(size: 12, weight: .bold))
                    .kerning(1)
                    .foregroundColor(StoryTheme.pinkText)
            }
        }
        .frame(width: 56, height: 56)
        .rotationEffect(.degrees(-10))
        .accessibilityHidden(true)
    }
}

// MARK: - 空状態

struct StoryEmptyStateView: View {
    enum Kind { case noStories, noOshi }

    var kind: Kind
    var onPrimary: () -> Void
    var onClose: () -> Void = {}
    var isPrimaryEnabled = true

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .storyBounceOnlyWhenScrollable()
        }
    }

    /// 縦中央寄せの中身（イラスト→見出し→補足→CTA）
    var content: some View {
                VStack(spacing: 0) {
                    StoryEmptyIllustration(kind: kind == .noOshi ? .noOshi : .noStories)
                    Text(StoryText.text(kind == .noOshi ? "story_no_cast_title" : "story_empty_title"))
                        .font(.storyTitle2)
                        .foregroundColor(StoryTheme.text)
                        .multilineTextAlignment(.center)
                        .storyLineHeight(1.4, fontSize: 22, relativeTo: .title2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 24)
                    if kind == .noStories {
                        Text(StoryText.text("story_empty_body"))
                            .font(.storySubheadline)
                            .foregroundColor(StoryTheme.body)
                            .multilineTextAlignment(.center)
                            .storyLineHeight(1.65, fontSize: 15, relativeTo: .subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 300)
                            .padding(.top, 10)
                    }
                    Group {
                        if kind == .noOshi {
                            StoryPrimaryButton(title: StoryText.text("story_register"), systemImage: "person.fill.badge.plus",
                                               symbolRendering: .monochrome, action: onPrimary)
                        } else {
                            StoryPrimaryButton(title: StoryText.text("story_create_first"), systemImage: "sparkles",
                                               isEnabled: isPrimaryEnabled, action: onPrimary)
                                .accessibilityIdentifier("story.new")
                        }
                    }
                    .padding(.top, 32)
                    if kind == .noOshi {
                        SecondaryTextButton(title: StoryText.text("story_close"), height: 48, action: onClose)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, kind == .noOshi ? 40 : 60)
    }
}

private extension View {
    @ViewBuilder func storyBounceOnlyWhenScrollable() -> some View {
        if #available(iOS 16.4, *) { scrollBounceBehavior(.basedOnSize) } else { self }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("ライブラリ") {
    NavigationStack {
        StoryLibraryScreen(phase: .list, records: StoryPreviewData.libraryRecords)
    }
}

#Preview("空状態｜物語なし") {
    NavigationStack {
        StoryLibraryScreen(phase: .noStories, records: [])
    }
}

#Preview("空状態｜推し未登録") {
    NavigationStack {
        StoryLibraryScreen(phase: .noOshi, records: [])
    }
}

#Preview("読み込み中・エラー") {
    TabView {
        NavigationStack { StoryLibraryScreen(phase: .loading, records: []) }
            .tabItem { Text("読み込み中") }
        NavigationStack { StoryLibraryScreen(phase: .failed(StoryError.unavailable.localizedDescription), records: []) }
            .tabItem { Text("エラー") }
        NavigationStack {
            StoryLibraryScreen(phase: .list, records: StoryPreviewData.libraryRecords,
                               refreshError: StoryError.unavailable.localizedDescription)
        }
        .tabItem { Text("再読込エラー") }
    }
}

#Preview("ライブラリ｜AXサイズ") {
    NavigationStack {
        StoryLibraryScreen(phase: .list, records: StoryPreviewData.libraryRecords)
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
