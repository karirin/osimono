//
//  RelationshipViews.swift
//  osimono
//
//  1対1チャットの関係性表示（ヘッダーのチップ・ステージアップ演出・関係性の詳細画面）。
//  生の数値は表示せず、ステージ名と「次の関係まで」のバーだけを見せる。
//

import SwiftUI
import FirebaseDatabase

private func relText(_ key: String, _ value: String) -> String {
    Bundle.main.localizedString(forKey: key, value: value, table: nil)
}

/// UI表示用の言語（ステージ名などのラベルに使う）
private var relationshipUILanguage: String {
    Bundle.main.preferredLocalizations.first?.hasPrefix("ja") == true ? "ja" : "en"
}

private let relationshipAccent = Color(red: 0.91, green: 0.42, blue: 0.58)
private let relationshipAccent2 = Color(red: 0.65, green: 0.45, blue: 0.85)

// MARK: - Feed

/// チャット画面で関係性とステージアップイベントを監視する
final class RelationshipFeed: ObservableObject {
    @Published private(set) var relationship: RoleplayRelationship?
    /// まだ演出していない最新のステージアップ
    @Published private(set) var pendingEvent: RelationshipEvent?

    private var oshiId = ""
    private var relationshipHandle: DatabaseHandle?
    private var eventsHandle: DatabaseHandle?
    /// この画面で処理済み（演出の権利取得を試みた）のイベント
    private var handledEventIds = Set<String>()

    func start(oshiId: String) {
        guard oshiId != self.oshiId || relationshipHandle == nil else { return }
        stop()
        self.oshiId = oshiId
        relationship = nil
        pendingEvent = nil
        let repository = RoleplayRepository.shared

        relationshipHandle = repository.observeRelationship(oshiId: oshiId) { [weak self] relationship in
            DispatchQueue.main.async {
                guard let self = self, self.oshiId == oshiId else { return }
                self.relationship = relationship
            }
        }
        eventsHandle = repository.observeEvents(oshiId: oshiId) { [weak self] events in
            DispatchQueue.main.async {
                guard let self = self, self.oshiId == oshiId else { return }
                let unannounced = events.filter { !$0.announced && !self.handledEventIds.contains($0.id) }
                // たまっていた場合は最新の1件だけ演出し、古いものは静かに既読にする
                for old in unannounced.dropLast() {
                    self.handledEventIds.insert(old.id)
                    repository.markEventAnnounced(old, oshiId: oshiId)
                }
                self.pendingEvent = unannounced.last
            }
        }
    }

    func stop() {
        let repository = RoleplayRepository.shared
        if let handle = relationshipHandle { repository.removeObserver(handle, oshiId: oshiId, path: "relationship") }
        if let handle = eventsHandle { repository.removeObserver(handle, oshiId: oshiId, path: "relationshipEvents") }
        relationshipHandle = nil
        eventsHandle = nil
        oshiId = ""
    }

    func markHandled(_ event: RelationshipEvent) {
        handledEventIds.insert(event.id)
        if pendingEvent?.id == event.id {
            pendingEvent = nil
        }
    }

    deinit {
        stop()
    }
}

// MARK: - Header chip

/// ヘッダーに出す「♡ 親しい ▰▰▱」
/// ヘッダーのアイコン外周に、次の関係までの進み具合をリングで表示する
struct RelationshipAvatarRing<Content: View>: View {
    let relationship: RoleplayRelationship?
    var size: CGFloat = 48
    var lineWidth: CGFloat = 3.5
    @ViewBuilder let content: () -> Content

    var body: some View {
        let relationship = self.relationship ?? RoleplayRelationship()
        // 最終段階はリングを満たしておく
        let progress = relationship.stage.next == nil ? 1 : relationship.progressToNextStage
        ZStack {
            Circle()
                .stroke(relationshipAccent.opacity(0.35), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(colors: [relationshipAccent, relationshipAccent2, relationshipAccent], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
            content()
                .frame(width: size - lineWidth * 2 - 4, height: size - lineWidth * 2 - 4)
                .clipShape(Circle())
        }
        .frame(width: size, height: size)
    }
}

/// ヘッダー2行目の「♥ 友達」表示（タップで詳細）
struct RelationshipStatusLabel: View {
    let relationship: RoleplayRelationship?
    let action: () -> Void

    var body: some View {
        let relationship = self.relationship ?? RoleplayRelationship()
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(relationshipAccent)
                Text(relationship.stage.label(language: relationshipUILanguage))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: relText("relationship_chip_accessibility", "今の関係: %@"), relationship.stage.label(language: relationshipUILanguage)))
    }
}

struct RelationshipProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(relationshipAccent.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [relationshipAccent, relationshipAccent2], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geometry.size.width * progress, progress > 0 ? geometry.size.height : 0))
            }
        }
        .animation(.easeOut(duration: 0.6), value: progress)
    }
}

// MARK: - Stage up banner

/// チャット上に出すステージアップの短い演出。ステージごとに文言を変える
struct RelationshipStageUpBanner: View {
    let event: RelationshipEvent
    let oshiName: String
    let action: () -> Void

    @State private var appeared = false

    static func message(for stage: RelationshipStage, oshiName: String) -> String {
        switch stage {
        case .stranger, .acquaintance:
            return relText("relationship_stage_up_acquaintance", "少しだけ、距離が縮まったみたい")
        case .close:
            return relText("relationship_stage_up_close", "二人の関係が少し変わったようです")
        case .special:
            return String(format: relText("relationship_stage_up_special", "%@にとって、あなたは特別な存在になりつつあるようです"), oshiName)
        case .lover:
            return relText("relationship_stage_up_lover", "二人の関係が、新しい一歩を踏み出したようです")
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .scaleEffect(appeared ? 1 : 0.4)
                    Text(Self.message(for: event.to, oshiName: oshiName))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                }
                .foregroundColor(relationshipAccent)
                if !event.unlockIds.isEmpty {
                    Text(relText("relationship_stage_up_unlocked", "新しい思い出が増えました（タップして確認）"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [relationshipAccent.opacity(0.10), relationshipAccent2.opacity(0.10)], startPoint: .leading, endPoint: .trailing))
            )
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(relationshipAccent.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

// MARK: - Detail

struct RelationshipDetailView: View {
    let oshi: Oshi
    var onSituationApplied: (RoleplaySituation) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true
    @State private var relationship = RoleplayRelationship()
    @State private var unlocked: [RelationshipUnlock] = []
    @State private var lockedCount = 0
    @State private var events: [RelationshipEvent] = []
    @State private var nicknameDraft = ""
    @State private var savedNickname = ""
    @State private var selectedPhoto: RelationshipPhotoSource?

    private var language: String { relationshipUILanguage }

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    content
                }
            }
            .navigationTitle(relText("relationship_detail_title", "二人の関係"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(relText("relationship_close", "閉じる")) { dismiss() }
                }
            }
        }
        .onAppear(perform: load)
        .sheet(item: Binding(get: { selectedPhoto.map(PhotoItem.init) }, set: { selectedPhoto = $0?.source })) { item in
            RelationshipPhotoView(source: item.source)
        }
    }

    private var content: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text(relText("relationship_current", "現在の関係"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill").foregroundColor(relationshipAccent)
                        Text("「\(relationship.stage.label(language: language))」")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                    if relationship.stage.next != nil {
                        VStack(spacing: 6) {
                            HStack {
                                Text(relText("relationship_next", "次の関係"))
                                Spacer()
                                Text("？？？").fontWeight(.semibold)
                            }
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            RelationshipProgressBar(progress: relationship.progressToNextStage)
                                .frame(height: 8)
                        }
                        Text(relText("relationship_next_hint", "会話を重ねるうちに、少しずつ変わっていきます"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text(relText("relationship_max_hint", "これからも二人の時間を大切に"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                if unlocked.isEmpty {
                    Text(relText("relationship_unlocked_empty", "まだありません。たくさん話してみてください。"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(unlocked) { entry in
                        unlockedRow(entry)
                    }
                }
                if lockedCount > 0 {
                    Label(String(format: relText("relationship_locked_count", "まだ見ぬ思い出があと%d個"), lockedCount), systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text(relText("relationship_unlocked_section", "解放済み"))
            }

            if !events.isEmpty {
                Section {
                    ForEach(events.reversed()) { event in
                        HStack {
                            Text(String(format: relText("relationship_history_item", "「%@」になった"), event.to.label(language: language)))
                            Spacer()
                            Text(Date(timeIntervalSince1970: event.createdAt), style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text(relText("relationship_history_section", "二人の歩み"))
                }
            }
        }
    }

    @ViewBuilder
    private func unlockedRow(_ entry: RelationshipUnlock) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(relationshipAccent)
                Text(entry.localizedTitle).font(.subheadline.weight(.semibold))
            }
            if !entry.localizedDescription.isEmpty {
                Text(entry.localizedDescription.replacingOccurrences(of: "%@", with: oshi.name))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            switch entry.type {
            case .photo:
                if let source = entry.photoSource(oshiImageUrl: oshi.imageUrl, oshiBackgroundImageUrl: oshi.backgroundImageUrl) {
                    Button { selectedPhoto = source } label: {
                        RelationshipPhotoImage(source: source)
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            case .nickname where entry.nicknameStyle == .custom:
                HStack {
                    TextField(relText("relationship_nickname_placeholder", "呼んでほしい名前"), text: $nicknameDraft)
                        .textFieldStyle(.roundedBorder)
                    Button(relText("relationship_nickname_save", "保存")) { saveNickname() }
                        .disabled(RelationshipUnlockEvaluator.sanitizeNickname(nicknameDraft) == savedNickname)
                }
            case .scenario:
                if let scenario = entry.scenario {
                    Button(relText("relationship_scenario_apply", "このシチュエーションで話す")) {
                        RoleplayRepository.shared.saveSituation(scenario, oshiId: oshi.id)
                        onSituationApplied(scenario)
                        dismiss()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(relationshipAccent)
                }
            default:
                EmptyView()
            }
        }
        .padding(.vertical, 2)
    }

    private func load() {
        RoleplayRepository.shared.fetchState(oshiId: oshi.id) { state in
            let userId = RoleplayRepository.shared.currentUserId ?? ""
            let entries = state.unlockedEntries(userId: userId, characterId: oshi.id)
            DispatchQueue.main.async {
                relationship = state.relationship ?? RoleplayRelationship()
                unlocked = entries
                lockedCount = max(state.catalog.count - entries.count, 0)
                events = state.events
                savedNickname = state.specialNickname
                nicknameDraft = state.specialNickname
                isLoading = false
            }
        }
    }

    private func saveNickname() {
        let nickname = RelationshipUnlockEvaluator.sanitizeNickname(nicknameDraft)
        RoleplayRepository.shared.saveSpecialNickname(nickname, oshiId: oshi.id)
        savedNickname = nickname
        nicknameDraft = nickname
    }

    private struct PhotoItem: Identifiable {
        let source: RelationshipPhotoSource
        var id: String {
            switch source {
            case .remote(let url): return url.absoluteString
            case .asset(let name): return "asset:" + name
            }
        }
    }
}

struct RelationshipPhotoImage: View {
    let source: RelationshipPhotoSource
    var contentMode: ContentMode = .fill

    var body: some View {
        switch source {
        case .asset(let name):
            Image(name).resizable().aspectRatio(contentMode: contentMode)
        case .remote(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: contentMode)
                } else {
                    Rectangle().fill(relationshipAccent.opacity(0.1)).overlay(ProgressView())
                }
            }
        }
    }
}

private struct RelationshipPhotoView: View {
    let source: RelationshipPhotoSource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            RelationshipPhotoImage(source: source, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
                    .padding()
            }
        }
    }
}
