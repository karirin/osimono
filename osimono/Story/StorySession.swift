import Foundation
import Combine

protocol StorySaving {
    func save(_ record: StoryRecord, expectedRevision: Int?) async throws
}
protocol StoryGenerating {
    func generate(record: StoryRecord, decision: StoryDecision?) async throws -> StoryScene
}

/// Feature-local ownership. A candidate is exposed only after the server acknowledges its save.
@MainActor
final class StorySession: ObservableObject {
    enum Failure: Equatable {
        /// 生成できなかった。再試行は同じ行動で再生成する
        case generation
        /// 生成済みの場面を保存できなかった。再試行は再生成せずに再保存する
        case save
        /// AIの利用上限。広告・加入・日付変更で利用枠が戻るまで待つ
        case limit
        /// 競合・ユーザー不一致・保存データの不整合。再試行しても成功しないため、一覧から開き直す
        case needsReopen

        static func classify(_ error: Error, whileSaving: Bool) -> Failure {
            switch error as? StoryError {
            case .limit?: return .limit
            case .conflict?, .authentication?, .invalidSave?, .invalidProgress?: return .needsReopen
            default: return whileSaving ? .save : .generation
            }
        }
    }

    @Published private(set) var record: StoryRecord
    @Published private(set) var isBusy = false
    @Published private(set) var error: String?
    @Published private(set) var hasPendingSave = false
    @Published private(set) var savedOperationID: String?
    /// 直近の失敗の種類。画面の出し分け用（`error` の文言は従来どおり）
    @Published private(set) var failure: Failure?
    private let repository: StorySaving
    private let generator: StoryGenerating
    private let currentUserID: () -> String?
    private let reserveUsage: () throws -> Void
    private let refundUsage: () -> Void
    @Published private var pending: StoryRecord?
    private var pendingExpectedRevision: Int?
    private var lastDecision: StoryDecision?
    private var active = true
    private var generation = UUID()

    init(record: StoryRecord, repository: StorySaving, generator: StoryGenerating,
         currentUserID: @escaping () -> String?, reserveUsage: @escaping () throws -> Void = {},
         refundUsage: @escaping () -> Void = {}) {
        self.record = record
        self.repository = repository
        self.generator = generator
        self.currentUserID = currentUserID
        self.reserveUsage = reserveUsage
        self.refundUsage = refundUsage
    }

    /// 生成済みで保存の成功待ち（保存中・保存エラー）の場面。表示専用で、`record` は保存成功まで進めない
    var pendingScene: StoryScene? {
        guard let pending, pending.scenes.count > record.scenes.count else { return nil }
        return pending.currentScene
    }

    func activate() { active = currentUserID() == record.ownerID }
    func deactivate() {
        active = false
        generation = UUID()
        isBusy = false
    }
    func authenticationChanged() {
        guard currentUserID() != record.ownerID else { return }
        deactivate()
        pending = nil
        hasPendingSave = false
    }
    private func accepts(_ token: UUID) -> Bool {
        active && generation == token && currentUserID() == record.ownerID
    }

    /// For a new empty record. Retry keeps both the story ID and operation ID unchanged.
    func create() async {
        guard !isBusy else { return }
        guard active, currentUserID() == record.ownerID else {
            error = StoryError.authentication.localizedDescription
            failure = .needsReopen
            return
        }
        pending = record
        pendingExpectedRevision = nil
        hasPendingSave = true
        await savePending()
    }

    func advance(choiceIndex: Int? = nil, freeInput: String? = nil) async {
        guard !isBusy, !hasPendingSave, active, currentUserID() == record.ownerID, !record.isComplete else { return }
        let decision: StoryDecision?
        if let scene = record.currentScene {
            if let choiceIndex, scene.choices.indices.contains(choiceIndex) {
                decision = StoryDecision(sceneIndex: scene.index, intent: scene.choices[choiceIndex], choiceIndex: choiceIndex)
            } else if let freeInput, !freeInput.storyTrimmed.isEmpty, freeInput.storyTrimmed.count <= 300 {
                decision = StoryDecision(sceneIndex: scene.index, intent: freeInput.storyTrimmed, choiceIndex: nil)
            } else { return }
        } else { decision = nil }
        lastDecision = decision
        await generate(decision: decision)
    }

    func retry() async {
        guard !isBusy else { return }
        if hasPendingSave { await savePending() }
        else { await generate(decision: lastDecision) }
    }

    /// 利用枠が回復した後、上限に阻まれた行動を一度だけ再開する。
    func resumeAfterLimit() async {
        guard failure == .limit, !isBusy, !hasPendingSave else { return }
        await generate(decision: lastDecision)
    }

    private func generate(decision: StoryDecision?) async {
        guard active, !record.isComplete, currentUserID() == record.ownerID else { return }
        isBusy = true
        error = nil
        failure = nil
        let token = UUID()
        generation = token
        var reserved = false
        do {
            try record.validate()
            try reserveUsage()
            reserved = true
            let scene = try await generator.generate(record: record, decision: decision)
            guard accepts(token) else { return }
            pending = try record.advancing(with: scene, decision: decision)
            pendingExpectedRevision = record.revision
            hasPendingSave = true
            isBusy = false
            await savePending()
        } catch {
            guard accepts(token) else { return }
            if reserved { refundUsage() }
            self.error = error.localizedDescription
            failure = .classify(error, whileSaving: false)
            isBusy = false
        }
    }

    private func savePending() async {
        guard let candidate = pending, active, currentUserID() == record.ownerID, !isBusy else { return }
        isBusy = true
        error = nil
        failure = nil
        let token = UUID()
        generation = token
        do {
            try candidate.validate()
            try await repository.save(candidate, expectedRevision: pendingExpectedRevision)
            guard accepts(token) else { return }
            record = candidate
            savedOperationID = candidate.operationID
            pending = nil
            hasPendingSave = false
            isBusy = false
        } catch {
            guard accepts(token) else { return }
            self.error = error.localizedDescription
            failure = .classify(error, whileSaving: true)
            isBusy = false
        }
    }
}

/// The same check is used inside Firebase's transaction and in automated conflict/idempotence tests.
enum StoryCommit {
    static func accepts(existing: StoryRecord?, candidate: StoryRecord, expectedRevision: Int?) -> Bool {
        guard (try? candidate.validate()) != nil else { return false }
        if let existing {
            guard existing.id == candidate.id, existing.ownerID == candidate.ownerID else { return false }
            if existing.operationID == candidate.operationID { return existing == candidate }
            guard expectedRevision == existing.revision, candidate.revision == existing.revision + 1,
                  candidate.configuration == existing.configuration,
                  candidate.createdAt == existing.createdAt,
                  candidate.scenes.dropLast() == existing.scenes[...],
                  candidate.decisions.prefix(existing.decisions.count) == existing.decisions[...]
            else { return false }
            return true
        }
        return expectedRevision == nil && candidate.revision == 0
    }
}
