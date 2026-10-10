import Foundation
import Testing
import SwiftUI
import XCTest
@testable import osimono

struct ConversationAdjustmentPolicyTests {
    @Test func fifthSuccessfulRoundOffersSpeakingAndRoundIDsAreIdempotent() {
        var state = ConversationAdjustmentState()
        for i in 1...4 { state.recordRound(id: "\(i)") }
        #expect(state.nextItem(now: Date()) == nil)
        state.recordRound(id: "5")
        state.recordRound(id: "5")
        #expect(state.completedRounds == 5)
        #expect(state.nextItem(now: Date()) == .speaking)
    }
    @Test func dailyClaimAndCooldownSurviveReload() {
        let now = Date()
        var state = ConversationAdjustmentState()
        for i in 1...5 { state.recordRound(id: "\(i)") }
        state.markPresented(.speaking, now: now, automatic: true)
        state.suppress(.speaking, days: 30, now: now)
        let reloaded = ConversationAdjustmentState(dictionary: state.dictionary)
        #expect(reloaded.nextItem(now: now) == nil)
        #expect(reloaded.nextItem(now: now.addingTimeInterval(86_400)) == .interaction)
        #expect(reloaded.suppressedUntil["speaking"] == now.addingTimeInterval(30 * 86_400).timeIntervalSince1970)
    }
    @Test func replacingOnlySelectedDimensionPreservesTraitsAndOtherAdjustment() {
        let base = "一人称は僕。絵文字を使う。\n\n口癖はおつかれ。"
        let short = ConversationAdjustmentItem.length.replacing(in: base, choice: 1, language: "ja")
        let casual = ConversationAdjustmentItem.speaking.replacing(in: short, choice: 1, language: "ja")
        let polite = ConversationAdjustmentItem.speaking.replacing(in: casual, choice: 2, language: "en")
        #expect(polite.hasPrefix(base))
        #expect(ConversationAdjustmentItem.length.savedChoice(in: polite) == 1)
        #expect(ConversationAdjustmentItem.speaking.savedChoice(in: polite) == 2)
        #expect(!polite.contains("もっとくだけた口調"))
        var repeated = polite
        for _ in 0..<100 { repeated = ConversationAdjustmentItem.speaking.replacing(in: repeated, choice: 2, language: "en") }
        #expect(repeated == polite)
    }
    @Test func targetedMutationAndExactUndoIncludingAbsentValue() throws {
        var data: [String: Any] = ["personality": "クール", "relationship_status": "友達", "speaking_style": "僕"]
        let original = data as NSDictionary
        let receipt = try #require(ConversationAdjustmentMutation.apply(to: &data, userID: "u", oshiID: "o", item: .interaction, choice: 1, language: "ja"))
        #expect(data["personality"] as? String == "クール")
        #expect(data["relationship_status"] as? String == "友達")
        #expect(data["speaking_style"] as? String == "僕")
        #expect(ConversationAdjustmentMutation.undo(receipt, data: &data))
        #expect(data as NSDictionary == original)
    }
    @Test func undoDoesNotOverwriteInterveningEdit() throws {
        var data: [String: Any] = ["speaking_style": "僕"]
        let receipt = try #require(ConversationAdjustmentMutation.apply(to: &data, userID: "u", oshiID: "o", item: .speaking, choice: 1, language: "ja"))
        data["speaking_style"] = "別画面からの編集"
        #expect(!ConversationAdjustmentMutation.undo(receipt, data: &data))
        #expect(data["speaking_style"] as? String == "別画面からの編集")
    }
    @Test func keepAndLaterCannotMutateSettings() {
        var data: [String: Any] = ["speaking_style": "僕", "personality": "クール"]
        let before = data as NSDictionary
        #expect(ConversationAdjustmentMutation.apply(to: &data, userID: "u", oshiID: "o", item: .speaking, choice: 0, language: "ja") == nil)
        #expect(ConversationAdjustmentMutation.apply(to: &data, userID: "u", oshiID: "o", item: .speaking, choice: -1, language: "ja") == nil)
        #expect(data as NSDictionary == before)
    }
    @Test func savedPreferencesReachNextPromptOnFreeAndPremiumPlans() {
        var oshi = Oshi(id: "test", name: "アキ", personality: "クール", speaking_style: "一人称は僕", relationship_status: "友達")
        oshi.speaking_style = ConversationAdjustmentItem.speaking.replacing(in: oshi.speaking_style, choice: 2, language: "ja")
        oshi.speaking_style = ConversationAdjustmentItem.length.replacing(in: oshi.speaking_style, choice: 2, language: "ja")
        oshi.relationship_detail = ConversationAdjustmentItem.interaction.replacing(in: "照れ屋", choice: 1, language: "ja")
        for premium in [false, true] {
            for language in ["ja", "en"] {
                let context = RoleplayChatService.makeContext(oshi: oshi, state: RoleplayState(), language: language, query: "こんにちは", isPremium: premium)
                let messages = RoleplayChatService.buildMessages(context: context, userMessage: "こんにちは", chatHistory: [], isPremium: premium)
                let prompt = messages[0]["content"] ?? ""
                #expect(context.character.personality == "クール")
                #expect(context.character.conversationAdjustments["speaking"] == 2)
                #expect(context.character.conversationAdjustments["interaction"] == 1)
                #expect(context.character.conversationAdjustments["length"] == 2)
                #expect(prompt.contains(language == "ja" ? "より丁寧な口調" : "more polite voice"))
                #expect(prompt.contains(language == "ja" ? "一律の1〜3文制限はありません" : "no fixed 1-3 sentence limit"))
                #expect(!prompt.contains(language == "ja" ? "セリフは基本1〜3文" : "Keep replies short (usually 1-3"))
                #expect(prompt.contains("友達"))
                #expect(!prompt.contains("{{replyLengthRule}}"))
            }
        }
    }
}

private final class AdjustmentTestDatabase: ConversationAdjustmentDatabase {
    var nodes: [String: [String: Any]] = [:]
    var failWrites = false
    var deferAcknowledgement = false
    var pendingAcknowledgement: (() -> Void)?
    func key(_ userID: String, _ oshiID: String) -> String { "\(userID)/\(oshiID)" }
    func fetchState(userID: String, oshiID: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        completion(.success(nodes[key(userID, oshiID)]?[FirebaseConversationAdjustmentDatabase.stateKey] as? [String: Any] ?? [:]))
    }
    func transact(userID: String, oshiID: String, stateOnly: Bool,
                  mutation: @escaping (inout [String: Any]) -> Bool,
                  completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let key = self.key(userID, oshiID)
        var root = nodes[key] ?? ["name": "アキ"]
        var data = stateOnly ? root[FirebaseConversationAdjustmentDatabase.stateKey] as? [String: Any] ?? [:] : root
        guard mutation(&data), !failWrites else {
            completion(.failure(NSError(domain: "test", code: 1))); return
        }
        let acknowledge = {
            if stateOnly { root[FirebaseConversationAdjustmentDatabase.stateKey] = data }
            else { root = data }
            self.nodes[key] = root
            completion(.success(data))
        }
        if deferAcknowledgement { pendingAcknowledgement = acknowledge }
        else { acknowledge() }
    }
}

@MainActor
struct ConversationAdjustmentStoreTests {
    private func drain() async {
        await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    }
    @Test func saveRequiresAcknowledgementThenUpdatesNextPromptAndUndo() async throws {
        let db = AdjustmentTestDatabase()
        db.nodes["u/test"] = ["name": "アキ", "speaking_style": "僕", "personality": "クール", "relationship_status": "友達"]
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        let vm = OshiViewModel(oshi: Oshi(id: "test", name: "アキ", personality: "クール", speaking_style: "僕", relationship_status: "友達"))
        store.load(oshiID: "test"); await drain()
        db.deferAcknowledgement = true
        store.selectItem(.speaking); store.choose(2, viewModel: vm)
        #expect(store.isSaving)
        #expect(store.notice == nil)
        #expect(vm.selectedOshi.speaking_style == "僕")
        db.pendingAcknowledgement?(); await drain()
        #expect(!store.isSaving)
        #expect(store.notice != nil)
        #expect(ConversationAdjustmentItem.speaking.savedChoice(in: vm.selectedOshi.speaking_style) == 2)
        #expect(vm.selectedOshi.personality == "クール")
        let context = RoleplayChatService.makeContext(oshi: vm.selectedOshi, state: RoleplayState(), language: "ja", query: "次の返信", isPremium: false)
        #expect(context.character.conversationAdjustments["speaking"] == 2)
        db.deferAcknowledgement = false
        store.revert(viewModel: vm); await drain()
        #expect(vm.selectedOshi.speaking_style == "僕")
        #expect(db.nodes["u/test"]?["speaking_style"] as? String == "僕")
        #expect(store.undo == nil)
    }
    @Test func failedSaveAndFailedUndoKeepRetryAvailable() async {
        let db = AdjustmentTestDatabase()
        db.nodes["u/test"] = ["name": "アキ", "speaking_style": "僕"]
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        let vm = OshiViewModel(oshi: Oshi(id: "test", name: "アキ", speaking_style: "僕"))
        store.load(oshiID: "test"); await drain()
        db.failWrites = true
        store.selectItem(.speaking); store.choose(1, viewModel: vm); await drain()
        #expect(store.error != nil)
        #expect(store.notice == nil)
        #expect(store.item == .speaking)
        #expect(store.undo == nil)
        #expect(vm.selectedOshi.speaking_style == "僕")
        db.failWrites = false
        store.choose(1, viewModel: vm); await drain()
        let changed = vm.selectedOshi.speaking_style
        db.failWrites = true
        store.revert(viewModel: vm); await drain()
        #expect(store.error != nil)
        #expect(store.undo != nil)
        #expect(vm.selectedOshi.speaking_style == changed)
        db.failWrites = false
        store.revert(viewModel: vm); await drain()
        #expect(vm.selectedOshi.speaking_style == "僕")
    }
    @Test func keepAndLaterPersistCooldownButLeaveFieldsUntouched() async {
        let db = AdjustmentTestDatabase()
        db.nodes["u/test"] = ["name": "アキ", "speaking_style": "僕", "relationship_detail": "照れ屋"]
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        let vm = OshiViewModel(oshi: Oshi(id: "test", name: "アキ", speaking_style: "僕", relationship_detail: "照れ屋"))
        store.load(oshiID: "test"); await drain()
        store.selectItem(.speaking); store.choose(0, viewModel: vm); await drain()
        #expect(vm.selectedOshi.speaking_style == "僕")
        #expect(store.notice == nil)
        #expect(store.undo == nil)
        #expect((store.state?.suppressedUntil["speaking"] ?? 0) > Date().addingTimeInterval(29 * 86_400).timeIntervalSince1970)
        store.selectItem(.interaction); store.later(viewModel: vm); await drain()
        #expect(vm.selectedOshi.relationship_detail == "照れ屋")
        #expect(store.item == nil)
        #expect(store.notice == nil)
    }
    @Test func laterClosesImmediatelyWithoutWaitingForMetadataAcknowledgement() async {
        let db = AdjustmentTestDatabase()
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        let vm = OshiViewModel(oshi: Oshi(id: "test", name: "アキ", speaking_style: "僕"))
        store.load(oshiID: "test"); await drain()
        db.deferAcknowledgement = true
        store.selectItem(.speaking); store.later(viewModel: vm)
        #expect(store.item == nil)
        #expect(!store.isSaving)
        #expect(store.notice == nil)
        #expect(vm.selectedOshi.speaking_style == "僕")
        db.pendingAcknowledgement?(); await drain()
    }
    @Test func failedDismissalMetadataStillSuppressesAfterReopening() async {
        let db = AdjustmentTestDatabase()
        let suite = "ConversationAdjustmentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: defaults)
        let vm = OshiViewModel(oshi: Oshi(id: "test", name: "アキ"))
        store.load(oshiID: "test"); await drain()
        for i in 1...5 { store.recordRound(userID: "u", oshiID: "test", messageID: "\(i)"); await drain() }
        db.failWrites = true
        store.selectItem(.speaking); store.later(viewModel: vm)
        let reopened = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: defaults)
        reopened.load(oshiID: "test"); await drain()
        #expect(reopened.state?.nextItem(now: Date()) == nil)
        #expect(reopened.state?.completedRounds == 5)
    }
    @Test func reopeningAndOtherScopesDoNotRepeatDailyQuestion() async {
        let db = AdjustmentTestDatabase()
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        store.load(oshiID: "a"); await drain()
        for i in 1...5 { store.recordRound(userID: "u", oshiID: "a", messageID: "\(i)"); await drain() }
        store.offerAutomatically { true }; await drain()
        #expect(store.item == .speaking)
        store.load(oshiID: "a"); await drain()
        store.offerAutomatically { true }; await drain()
        #expect(store.item == nil)
        #expect(store.state?.completedRounds == 5)
        store.load(oshiID: "b"); await drain()
        #expect(store.state?.completedRounds == 0)
        let otherUser = ConversationAdjustmentStore(database: db, currentUserID: { "other" }, defaults: nil)
        otherUser.load(oshiID: "a"); await drain()
        #expect(otherUser.state?.completedRounds == 0)
    }
    @Test func idleCheckPreventsInterruptionEvenWhenItChangesDuringClaim() async {
        let db = AdjustmentTestDatabase()
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        store.load(oshiID: "a"); await drain()
        for i in 1...5 { store.recordRound(userID: "u", oshiID: "a", messageID: "\(i)"); await drain() }
        store.offerAutomatically { false }; await drain()
        #expect(store.item == nil)
        #expect(store.state?.lastAutomaticDay == "")
        db.deferAcknowledgement = true
        var idle = true
        store.offerAutomatically { idle }
        idle = false
        db.pendingAcknowledgement?(); await drain()
        #expect(store.item == nil)
    }
    @Test func pendingAutomaticClaimCannotReplaceManualSelection() async {
        let db = AdjustmentTestDatabase()
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        store.load(oshiID: "a"); await drain()
        for i in 1...5 { store.recordRound(userID: "u", oshiID: "a", messageID: "\(i)"); await drain() }
        db.deferAcknowledgement = true
        store.offerAutomatically { true }
        store.openManually(); store.selectItem(.length)
        db.pendingAcknowledgement?(); await drain()
        #expect(store.item == .length)
    }
}

@MainActor
final class ConversationAdjustmentVisualTests: XCTestCase {
    func testCardsRenderInLightAndDarkAppearance() throws {
        let db = AdjustmentTestDatabase()
        let store = ConversationAdjustmentStore(database: db, currentUserID: { "u" }, defaults: nil)
        let vm = OshiViewModel(oshi: Oshi(id: "test", name: "アキ"))
        for scheme in [ColorScheme.light, .dark] {
            for item in ConversationAdjustmentItem.allCases {
                store.selectItem(item)
                let renderer = ImageRenderer(content: ConversationAdjustmentCard(store: store, viewModel: vm, isReplyPending: false)
                    .frame(width: 350).padding(12).background(Color(.systemGroupedBackground)).environment(\.colorScheme, scheme))
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertGreaterThan(image.size.height, 150)
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(item.rawValue)-\(scheme)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
