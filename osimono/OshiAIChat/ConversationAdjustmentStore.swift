import Foundation
import FirebaseAuth
import Combine

final class ConversationAdjustmentStore: ObservableObject {
    @Published private(set) var state: ConversationAdjustmentState?
    @Published var item: ConversationAdjustmentItem?
    @Published var selectingItem = false
    @Published private(set) var undo: ConversationAdjustmentUndo?
    @Published private(set) var isSaving = false
    @Published private(set) var error: String?
    @Published private(set) var notice: String?
    private var scope: String = ""
    private var revision = UUID()
    private let stateKey = FirebaseConversationAdjustmentDatabase.stateKey
    private let database: ConversationAdjustmentDatabase
    private let currentUserID: () -> String?
    private let defaults: UserDefaults?

    init(database: ConversationAdjustmentDatabase = FirebaseConversationAdjustmentDatabase(),
         currentUserID: @escaping () -> String? = { Auth.auth().currentUser?.uid },
         defaults: UserDefaults? = .standard) {
        self.database = database
        self.currentUserID = currentUserID
        self.defaults = defaults
    }

    func load(oshiID: String) {
        revision = UUID()
        scope = oshiID
        state = nil; item = nil; undo = nil; notice = nil; error = nil; selectingItem = false; isSaving = false
        guard let userID = currentUserID() else { return }
        let token = revision
        database.fetchState(userID: userID, oshiID: oshiID) { result in
            DispatchQueue.main.async {
                guard self.revision == token, self.currentUserID() == userID else { return }
                if case .success(let data) = result {
                    self.updateState(ConversationAdjustmentState(dictionary: data))
                } else if let cached = self.defaults?.dictionary(forKey: self.cacheKey(userID: userID)) {
                    self.updateState(ConversationAdjustmentState(dictionary: cached))
                }
            }
        }
    }

    func recordRound(userID: String, oshiID: String, messageID: String) {
        database.transact(userID: userID, oshiID: oshiID, stateOnly: true) { data in
            var state = ConversationAdjustmentState(dictionary: data)
            state.recordRound(id: messageID)
            data = state.dictionary
            return true
        } completion: { result in
            DispatchQueue.main.async {
                guard case .success(let data) = result, self.scope == oshiID, self.currentUserID() == userID else { return }
                self.updateState(ConversationAdjustmentState(dictionary: data))
            }
        }
    }

    func offerAutomatically(canPresent: @escaping () -> Bool) {
        guard canPresent(), item == nil, !selectingItem, undo == nil, !isSaving,
              state?.nextItem(now: Date()) != nil, let userID = currentUserID() else { return }
        let oshiID = scope, token = revision
        let now = Date()
        let localState = state ?? ConversationAdjustmentState()
        var claimedItem: ConversationAdjustmentItem?
        database.transact(userID: userID, oshiID: oshiID, stateOnly: true) { data in
            var state = ConversationAdjustmentState(dictionary: data).merging(localState)
            guard let next = state.nextItem(now: now) else { return false }
            claimedItem = next
            state.markPresented(next, now: now, automatic: true)
            data = state.dictionary
            return true
        } completion: { result in
            DispatchQueue.main.async {
                guard self.revision == token, self.currentUserID() == userID else { return }
                guard case .success(let data) = result else { return }
                self.updateState(ConversationAdjustmentState(dictionary: data))
                // Idle can change while the server claims the daily question. Never interrupt typing.
                guard canPresent(), self.item == nil, !self.selectingItem, self.notice == nil else { return }
                self.item = claimedItem
            }
        }
    }

    func openManually() {
        guard !isSaving else { return }
        item = nil; selectingItem = true; undo = nil; notice = nil; error = nil
    }
    func selectItem(_ item: ConversationAdjustmentItem) {
        selectingItem = false; self.item = item; error = nil; notice = nil
    }
    func close() { guard !isSaving else { return }; item = nil; selectingItem = false; undo = nil; notice = nil; error = nil }

    func choose(_ choice: Int, viewModel: OshiViewModel) {
        guard let item, !isSaving else { return }
        mutate(viewModel: viewModel) { data, userID, oshiID in
            var state = ConversationAdjustmentState(dictionary: data[self.stateKey] as? [String: Any] ?? [:])
            // A manual choice also postpones automatic guidance for today, avoiding back-to-back cards.
            state.markPresented(item, now: Date(), automatic: true)
            state.suppress(item, days: choice == 0 ? 30 : 7, now: Date())
            data[self.stateKey] = state.dictionary
            return ConversationAdjustmentMutation.apply(to: &data, userID: userID, oshiID: oshiID,
                                                        item: item, choice: choice, language: Locale.preferredLanguages.first?.hasPrefix("ja") == true ? "ja" : "en")
        } success: { receipt in
            self.item = nil
            self.undo = receipt
            if receipt != nil { self.notice = String(format: ConversationAdjustmentText.string("adjustment_\(item.rawValue)_saved"), viewModel.selectedOshi.name) }
        }
    }
    func later(viewModel: OshiViewModel) {
        guard let item, !isSaving, scope == viewModel.selectedOshi.id,
              let userID = currentUserID() else { close(); return }
        let oshiID = scope, token = revision, now = Date()
        var local = state ?? ConversationAdjustmentState()
        local.markPresented(item, now: now, automatic: true)
        updateState(local)
        close()
        // Dismiss immediately: this action changes guidance metadata only, never character settings.
        database.transact(userID: userID, oshiID: oshiID, stateOnly: true) { data in
            var saved = ConversationAdjustmentState(dictionary: data)
            saved.markPresented(item, now: now, automatic: true)
            data = saved.dictionary
            return true
        } completion: { result in
            DispatchQueue.main.async {
                guard self.revision == token, self.currentUserID() == userID else { return }
                if case .success(let data) = result { self.updateState(ConversationAdjustmentState(dictionary: data)) }
            }
        }
    }
    func revert(viewModel: OshiViewModel) {
        guard let undo, !isSaving else { return }
        mutate(viewModel: viewModel) { data, userID, oshiID in
            guard undo.userID == userID, undo.oshiID == oshiID,
                  ConversationAdjustmentMutation.undo(undo, data: &data) else {
                throw NSError(domain: "ConversationAdjustment", code: 409)
            }
            return nil
        } success: { _ in
            self.undo = nil
            self.notice = ConversationAdjustmentText.string("adjustment_restored")
        }
    }
    private func cacheKey(userID: String) -> String { "ConversationAdjustment.\(userID).\(scope)" }
    private func updateState(_ newState: ConversationAdjustmentState) {
        guard let userID = currentUserID() else { return }
        let cached = ConversationAdjustmentState(dictionary: defaults?.dictionary(forKey: cacheKey(userID: userID)) ?? [:])
        let merged = newState.merging(cached).merging(state ?? ConversationAdjustmentState())
        state = merged
        defaults?.set(merged.dictionary, forKey: cacheKey(userID: userID))
    }

    private func mutate(viewModel: OshiViewModel,
                        change: @escaping (inout [String: Any], String, String) throws -> ConversationAdjustmentUndo?,
                        success: @escaping (ConversationAdjustmentUndo?) -> Void) {
        guard let userID = currentUserID(), scope == viewModel.selectedOshi.id else {
            error = ConversationAdjustmentText.string("adjustment_error"); return
        }
        let oshiID = scope, token = revision
        isSaving = true; error = nil
        var receipt: ConversationAdjustmentUndo?
        var conflict = false
        database.transact(userID: userID, oshiID: oshiID, stateOnly: false) { data in
            do {
                receipt = try change(&data, userID, oshiID)
                return true
            } catch { conflict = true; return false }
        } completion: { result in
            DispatchQueue.main.async {
                guard self.revision == token, self.currentUserID() == userID else { return }
                self.isSaving = false
                guard case .success(let data) = result else {
                    self.error = ConversationAdjustmentText.string(conflict ? "adjustment_undo_conflict" : "adjustment_error")
                    return
                }
                if viewModel.selectedOshi.id == oshiID {
                    viewModel.selectedOshi.speaking_style = data["speaking_style"] as? String
                    viewModel.selectedOshi.relationship_detail = data["relationship_detail"] as? String
                }
                self.updateState(ConversationAdjustmentState(dictionary: data[self.stateKey] as? [String: Any] ?? [:]))
                success(receipt)
            }
        }
    }
}
