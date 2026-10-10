import Foundation
import Testing
@testable import osimono

private struct StoryTestRandomGenerator: RandomNumberGenerator {
    var state: UInt64 = 42

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

private func storyFixture(count: Int = 1, mode: StoryParticipation = .protagonist) -> StoryRecord {
    let cast = (0..<count).map { StoryCharacter(id: "cast-\($0)", name: "Favorite \($0)", imageURL: nil,
                                               profile: ["personality": "gentle", "speaking_style": "casual", "user_nickname": "friend"], role: "Companion") }
    var pairs: [StoryPair] = []
    for first in cast.indices {
        for second in cast.indices where second > first { pairs.append(StoryPair(firstID: cast[first].id, secondID: cast[second].id)) }
    }
    return StoryRecord(ownerID: "user-a", configuration: StoryConfiguration(title: "Story", synopsis: "Restore the town light",
                       participation: mode, leadID: mode == .member ? cast.first?.id : nil, userName: "You", userRole: "Friend",
                       language: "en", cast: cast, relationships: pairs))
}
private func storyScene(record: StoryRecord) -> StoryScene {
    let index = record.scenes.count
    return StoryScene(index: index, narration: "A new event, scene \(index).",
                      lines: [StoryLine(speakerID: record.configuration.cast[index % record.configuration.cast.count].id, text: "Let's work together.")],
                      choices: index == 8 ? [] : ["Help", "Ask a question", "Investigate"])
}

private actor StoryTestRepository: StorySaving {
    enum Failure { case beforeCommit, afterCommit }
    var stored: StoryRecord?
    var failure: Failure?
    var attempts = 0
    var commits = 0
    init(stored: StoryRecord? = nil) { self.stored = stored }
    func failNext(_ failure: Failure) { self.failure = failure }
    func value() -> StoryRecord? { stored }
    func counts() -> (Int, Int) { (attempts, commits) }
    func save(_ record: StoryRecord, expectedRevision: Int?) async throws {
        attempts += 1
        let failure = self.failure
        self.failure = nil
        if failure == .beforeCommit { throw StoryError.unavailable }
        guard StoryCommit.accepts(existing: stored, candidate: record, expectedRevision: expectedRevision) else { throw StoryError.conflict }
        if stored?.operationID != record.operationID { stored = record; commits += 1 }
        if failure == .afterCommit { throw StoryError.unavailable }
    }
}
private actor StoryTestGenerator: StoryGenerating {
    var requests: [(StoryRecord, StoryDecision?)] = []
    var shouldFail = false
    func failNext() { shouldFail = true }
    func history() -> [(StoryRecord, StoryDecision?)] { requests }
    func generate(record: StoryRecord, decision: StoryDecision?) async throws -> StoryScene {
        requests.append((record, decision))
        if shouldFail { shouldFail = false; throw StoryError.invalidResponse }
        return storyScene(record: record)
    }
}
private actor StoryGateGenerator: StoryGenerating {
    private var pending: CheckedContinuation<StoryScene, Error>?
    private var request: StoryRecord?
    private var waiter: CheckedContinuation<Void, Never>?
    private var started = false
    private var calls = 0
    func generate(record: StoryRecord, decision: StoryDecision?) async throws -> StoryScene {
        calls += 1
        request = record
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started = true
            waiter?.resume()
            waiter = nil
        }
    }
    func waitForStart() async {
        if !started { await withCheckedContinuation { waiter = $0 } }
    }
    func complete() {
        if let request { pending?.resume(returning: storyScene(record: request)) }
        pending = nil
    }
    func count() -> Int { calls }
}

private actor StoryGateRepository: StorySaving {
    private var pending: CheckedContinuation<Void, Error>?
    private var waiter: CheckedContinuation<Void, Never>?
    private var started = false
    private var candidate: StoryRecord?
    func save(_ record: StoryRecord, expectedRevision: Int?) async throws {
        candidate = record
        try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            started = true
            waiter?.resume()
            waiter = nil
        }
    }
    func waitForStart() async {
        if !started { await withCheckedContinuation { waiter = $0 } }
    }
    func complete() { pending?.resume(); pending = nil }
    func savedCandidate() -> StoryRecord? { candidate }
}

@MainActor
struct StoryTests {
    @Test(arguments: [1, 3]) func bothParticipationModesFinishAndRestore(count: Int) async throws {
        for mode in StoryParticipation.allCases {
            let initial = storyFixture(count: count, mode: mode)
            let repository = StoryTestRepository()
            let generator = StoryTestGenerator()
            let session = StorySession(record: initial, repository: repository, generator: generator, currentUserID: { "user-a" })
            await session.create()
            await session.advance()
            for index in 1...8 {
                if index.isMultiple(of: 2) { await session.advance(freeInput: "I help at scene \(index)") }
                else { await session.advance(choiceIndex: 1) }
            }
            #expect(session.record.isComplete)
            #expect(session.record.scenes.map(\.episode) == [1, 1, 1, 2, 2, 2, 3, 3, 3])
            #expect(session.record.currentScene?.choices.isEmpty == true)
            #expect(session.record.decisions.count == 8)
            #expect(Set(session.record.scenes.flatMap { $0.lines.map(\.speakerID) }).count == count)
            let requests = await generator.history()
            #expect(requests.count == 9)
            #expect(requests[1].1?.intent == "Ask a question")
            #expect(requests[2].1?.intent == "I help at scene 2")
            #expect(requests[8].0.decisions.count == 7)
            let restored = try JSONDecoder().decode(StoryRecord.self, from: JSONEncoder().encode(session.record))
            try restored.validate()
            #expect(restored == session.record)
            let reopened = StorySession(record: restored, repository: repository, generator: generator, currentUserID: { "user-a" })
            await reopened.advance(choiceIndex: 0)
            #expect(await generator.history().count == 9)
            #expect(restored.configuration.cast == initial.configuration.cast)
        }
    }

    @Test func savedSceneIsNotGeneratedOnResume() async throws {
        let initial = storyFixture()
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        let repository = StoryTestRepository(stored: first)
        let generator = StoryTestGenerator()
        let session = StorySession(record: first, repository: repository, generator: generator, currentUserID: { "user-a" })
        session.activate()
        #expect(session.record.currentScene == first.currentScene)
        #expect(await generator.history().isEmpty)
        await session.advance(freeInput: "I inspect the light")
        #expect(await generator.history().first?.0.scenes.count == 1)
        #expect(session.record.decisions.first?.intent == "I inspect the light")
    }

    @Test(arguments: [StoryTestRepository.Failure.beforeCommit, .afterCommit])
    fileprivate func saveRetryReusesSceneAndOperation(failure: StoryTestRepository.Failure) async throws {
        let initial = storyFixture()
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        let repository = StoryTestRepository(stored: first)
        let generator = StoryTestGenerator()
        let session = StorySession(record: first, repository: repository, generator: generator, currentUserID: { "user-a" })
        await repository.failNext(failure)
        await session.advance(choiceIndex: 0)
        #expect(session.error != nil)
        #expect(session.failure == .save)
        #expect(session.hasPendingSave)
        #expect(session.pendingScene?.index == 1)
        #expect(session.record == first)
        await session.advance(choiceIndex: 1)
        await session.retry()
        #expect(session.error == nil)
        #expect(session.failure == nil)
        #expect(!session.hasPendingSave)
        #expect(session.pendingScene == nil)
        #expect(session.record.scenes.count == 2)
        #expect(session.record.decisions.count == 1)
        #expect(session.record.decisions.first?.intent == "Help")
        #expect(await generator.history().count == 1)
        let counts = await repository.counts()
        #expect(counts.0 == 2)
        #expect(counts.1 == 1)
    }

    @Test func creationAcknowledgementFailureIsIdempotent() async {
        let initial = storyFixture()
        let repository = StoryTestRepository()
        let session = StorySession(record: initial, repository: repository, generator: StoryTestGenerator(), currentUserID: { "user-a" })
        await repository.failNext(.afterCommit)
        await session.create()
        #expect(session.hasPendingSave)
        // 設定だけの保存待ちは場面を持たない
        #expect(session.pendingScene == nil)
        #expect(session.savedOperationID == nil)
        await session.retry()
        #expect(session.error == nil)
        #expect(await repository.value()?.id == initial.id)
        #expect(await repository.counts().1 == 1)
        #expect(session.savedOperationID == initial.operationID)
    }

    @Test func creationForWrongUserCannotReportSuccessfulSave() async {
        let initial = storyFixture()
        let repository = StoryTestRepository()
        let session = StorySession(record: initial, repository: repository, generator: StoryTestGenerator(), currentUserID: { "user-b" })
        await session.create()
        #expect(session.error != nil)
        #expect(session.savedOperationID == nil)
        #expect(await repository.counts().0 == 0)
    }

    @Test func generationFailureKeepsPreviousSceneAndIntent() async throws {
        let initial = storyFixture()
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        let repository = StoryTestRepository(stored: first)
        let generator = StoryTestGenerator()
        var refunds = 0
        let session = StorySession(record: first, repository: repository, generator: generator,
                                   currentUserID: { "user-a" }, refundUsage: { refunds += 1 })
        await generator.failNext()
        await session.advance(freeInput: "I offer support")
        #expect(session.failure == .generation)
        #expect(session.pendingScene == nil)
        #expect(session.record == first)
        #expect(!session.hasPendingSave)
        #expect(refunds == 1)
        await session.retry()
        #expect(session.record.decisions.first?.intent == "I offer support")
        let requests = await generator.history()
        #expect(requests[0].1 == requests[1].1)
    }

    @Test func repeatedTapsDoNotGenerateTwice() async {
        let initial = storyFixture()
        let repository = StoryTestRepository(stored: initial)
        let generator = StoryGateGenerator()
        let session = StorySession(record: initial, repository: repository, generator: generator, currentUserID: { "user-a" })
        let task = Task { await session.advance() }
        await generator.waitForStart()
        await session.advance()
        await session.retry()
        #expect(await generator.count() == 1)
        await generator.complete()
        await task.value
        #expect(session.record.scenes.count == 1)
    }

    @Test(arguments: [true, false]) func lateReplyCannotSaveAfterClosingOrUserSwitch(userSwitch: Bool) async {
        let initial = storyFixture()
        let repository = StoryTestRepository(stored: initial)
        let generator = StoryGateGenerator()
        var user = "user-a"
        let session = StorySession(record: initial, repository: repository, generator: generator, currentUserID: { user })
        let task = Task { await session.advance() }
        await generator.waitForStart()
        if userSwitch { user = "user-b"; session.authenticationChanged() }
        else { session.deactivate() }
        await generator.complete()
        await task.value
        #expect(session.record == initial)
        #expect(await repository.counts().0 == 0)
    }

    @Test(arguments: [true, false]) func lateSaveAcknowledgementCannotUpdateClosedSessionOrNewUser(userSwitch: Bool) async {
        let initial = storyFixture()
        let repository = StoryGateRepository()
        var user = "user-a"
        let session = StorySession(record: initial, repository: repository, generator: StoryTestGenerator(), currentUserID: { user })
        let task = Task { await session.advance() }
        await repository.waitForStart()
        if userSwitch { user = "user-b"; session.authenticationChanged() }
        else { session.deactivate() }
        await repository.complete()
        await task.value
        #expect(session.record == initial)
        #expect(session.savedOperationID == nil)
        #expect(await repository.savedCandidate()?.ownerID == "user-a")
        #expect(await repository.savedCandidate()?.id == initial.id)
    }

    @Test func saveTimeoutAndLateAcknowledgementResumeOnlyOnce() async {
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let acknowledgement = StorySaveAcknowledgement(continuation)
                acknowledgement.finish(.failure(StoryError.saveTimeout))
                acknowledgement.finish(.success(()))
            }
            Issue.record("A timeout must remain a failure even when a late success arrives.")
        } catch {
            #expect(error as? StoryError == .saveTimeout)
        }
    }

    @Test func saveConflictAsksToReopenInsteadOfRetrying() async throws {
        let initial = storyFixture()
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        // 保存先に何もない＝期待するリビジョンと一致せず、競合として拒否される
        let repository = StoryTestRepository()
        let session = StorySession(record: first, repository: repository, generator: StoryTestGenerator(), currentUserID: { "user-a" })
        await session.advance(choiceIndex: 0)
        #expect(session.failure == .needsReopen)
        #expect(session.error == StoryError.conflict.localizedDescription)
        #expect(session.record == first)
        #expect(session.pendingScene?.index == 1)
    }

    @Test func failureClassification() {
        #expect(StorySession.Failure.classify(StoryError.limit, whileSaving: false) == .limit)
        #expect(StorySession.Failure.classify(StoryError.conflict, whileSaving: true) == .needsReopen)
        #expect(StorySession.Failure.classify(StoryError.authentication, whileSaving: false) == .needsReopen)
        #expect(StorySession.Failure.classify(StoryError.saveTimeout, whileSaving: true) == .save)
        #expect(StorySession.Failure.classify(StoryError.invalidResponse, whileSaving: false) == .generation)
        #expect(StorySession.Failure.classify(URLError(.notConnectedToInternet), whileSaving: true) == .save)
    }

    @Test func quotaFailureDoesNotCallAI() async {
        let initial = storyFixture()
        let generator = StoryTestGenerator()
        let session = StorySession(record: initial, repository: StoryTestRepository(stored: initial), generator: generator,
                                   currentUserID: { "user-a" }, reserveUsage: { throw StoryError.limit })
        await session.advance()
        #expect(session.error != nil)
        #expect(session.failure == .limit)
        #expect(await generator.history().isEmpty)
    }

    @Test(arguments: [false, true])
    func quotaRecoveryResumesOriginalActionOnce(freeInput: Bool) async throws {
        let initial = storyFixture()
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        let generator = StoryTestGenerator()
        let repository = StoryTestRepository(stored: first)
        var remaining = 0
        let session = StorySession(record: first, repository: repository, generator: generator,
                                   currentUserID: { "user-a" }, reserveUsage: {
            guard remaining > 0 else { throw StoryError.limit }
            remaining -= 1
        })
        await session.advance(choiceIndex: freeInput ? nil : 1, freeInput: freeInput ? "I inspect the light" : nil)
        #expect(session.failure == .limit)
        #expect(session.record == first)
        await session.resumeAfterLimit()
        #expect(await generator.history().isEmpty)
        // 広告の報酬、加入、日付変更で利用枠が回復した場合を再現する。
        remaining = 5
        await session.resumeAfterLimit()
        await session.resumeAfterLimit()
        let requests = await generator.history()
        #expect(requests.count == 1)
        #expect(requests.first?.1?.intent == (freeInput ? "I inspect the light" : "Ask a question"))
        #expect(requests.first?.1?.choiceIndex == (freeInput ? nil : 1))
        #expect(session.record.scenes.count == 2)
        #expect(session.record.decisions.count == 1)
        #expect(await repository.value() == session.record)
        #expect(remaining == 4)
        #expect(session.failure == nil)
    }

    @Test func quotaRecoveryResumesFirstScene() async {
        let initial = storyFixture()
        let generator = StoryTestGenerator()
        var available = false
        let session = StorySession(record: initial, repository: StoryTestRepository(stored: initial), generator: generator,
                                   currentUserID: { "user-a" }, reserveUsage: {
            if !available { throw StoryError.limit }
        })
        await session.advance()
        available = true
        await session.resumeAfterLimit()
        #expect(session.record.scenes.count == 1)
        #expect(session.record.decisions.isEmpty)
        #expect(await generator.history().count == 1)
    }

    @Test func quotaRecoveryDoesNotGenerateAfterLeavingOrSwitchingAccounts() async {
        for changeOwner in [false, true] {
            let initial = storyFixture()
            let generator = StoryTestGenerator()
            var available = false
            var userID = "user-a"
            let session = StorySession(record: initial, repository: StoryTestRepository(stored: initial), generator: generator,
                                       currentUserID: { userID }, reserveUsage: {
                if !available { throw StoryError.limit }
            })
            await session.advance()
            available = true
            if changeOwner { userID = "user-b"; session.authenticationChanged() }
            else { session.deactivate() }
            await session.resumeAfterLimit()
            #expect(await generator.history().isEmpty)
            #expect(session.record == initial)
        }
    }

    @Test func conflictDoesNotOverwriteOtherProgress() throws {
        let initial = storyFixture()
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        #expect(StoryCommit.accepts(existing: initial, candidate: first, expectedRevision: 0))
        #expect(StoryCommit.accepts(existing: first, candidate: first, expectedRevision: 0))
        var other = first
        other.operationID = UUID().uuidString
        #expect(!StoryCommit.accepts(existing: first, candidate: other, expectedRevision: 0))
        var stranger = first
        stranger.ownerID = "user-b"
        #expect(!StoryCommit.accepts(existing: initial, candidate: stranger, expectedRevision: 0))
        #expect(!StoryCommit.accepts(existing: nil, candidate: first, expectedRevision: 0))
    }

    @Test func responseValidationRejectsMalformedEmptyUnknownAndWrongEnding() throws {
        let valid = #"{"narration":"Morning.","lines":[{"speakerID":"cast-0","text":"Hello!"}],"choices":["Help","Ask","Wait"]}"#
        #expect(try StoryResponse.parse(valid, index: 0, castIDs: ["cast-0"]).choices.count == 3)
        let invalids = ["not JSON", "{}", "{\"narration\":\"cut", valid.replacingOccurrences(of: "Morning.", with: " "),
                        valid.replacingOccurrences(of: "cast-0", with: "unknown"), valid.replacingOccurrences(of: "Hello!", with: " "),
                        valid.replacingOccurrences(of: "Wait", with: "Help"), valid.replacingOccurrences(of: "Morning.", with: String(repeating: "a", count: 161))]
        for raw in invalids { #expect(throws: StoryError.self) { try StoryResponse.parse(raw, index: 0, castIDs: ["cast-0"]) } }
        #expect(throws: StoryError.self) { try StoryResponse.parse(valid, index: 8, castIDs: ["cast-0"]) }
        let ending = valid.replacingOccurrences(of: "[\"Help\",\"Ask\",\"Wait\"]", with: "[]")
        #expect(try StoryResponse.parse(ending, index: 8, castIDs: ["cast-0"]).isFinal)
        #expect(throws: StoryError.self) { try StoryResponse.parse(ending, index: 7, castIDs: ["cast-0"]) }
    }

    @Test func responseDropsUserLinesAndMapsCastNames() throws {
        let raw = #"{"narration":"Morning.","lines":[{"speakerID":"りょうや","text":"Roles?"},{"speakerID":"Leon","text":"Decor."},{"speakerID":"cast-1","text":"Guide."}],"choices":["Help","Ask","Wait"]}"#
        let scene = try StoryResponse.parse(raw, index: 1, castIDs: ["cast-0", "cast-1"], castNames: ["Leon": "cast-0"])
        #expect(scene.lines == [StoryLine(speakerID: "cast-0", text: "Decor."), StoryLine(speakerID: "cast-1", text: "Guide.")])
    }

    @Test func invalidAIReplyIsRegeneratedOnceWithFormatReminder() async throws {
        let record = storyFixture()
        let valid = #"{"narration":"Morning.","lines":[{"speakerID":"cast-0","text":"Hello!"}],"choices":["Help","Ask","Wait"]}"#
        var requests: [([[String: String]], Int)] = []
        let scene = try await StoryGeneration.generate(record: record, decision: nil) { messages, maxTokens in
            requests.append((messages, maxTokens))
            return requests.count == 1 ? #"{"narration":"incomplete""# : valid
        }
        #expect(scene.index == 0)
        #expect(scene.narration == "Morning.")
        #expect(requests.count == 2)
        #expect(requests[0].1 == 1600)
        #expect(requests[1].1 == 2000)
        #expect(Array(requests[1].0.prefix(2)) == requests[0].0)
        #expect(requests[1].0.last?["content"]?.contains("exactly 3 distinct choices") == true)
    }

    @Test func invalidAIReplyStopsAfterOneAutomaticRetry() async {
        var count = 0
        do {
            _ = try await StoryGeneration.generate(record: storyFixture(), decision: nil) { _, _ in
                count += 1
                return "not JSON"
            }
            Issue.record("An invalid second reply must fail.")
        } catch {
            #expect(error as? StoryError == .invalidResponse)
        }
        #expect(count == 2)
    }

    @Test func missingAIContentIsRegeneratedOnce() async throws {
        var count = 0
        let scene = try await StoryGeneration.generate(record: storyFixture(), decision: nil) { _, _ in
            count += 1
            if count == 1 { throw StoryError.invalidResponse }
            return #"{"narration":"Morning.","lines":[{"speakerID":"cast-0","text":"Hello!"}],"choices":["Help","Ask","Wait"]}"#
        }
        #expect(count == 2)
        #expect(scene.narration == "Morning.")
    }

    @Test func transportErrorDoesNotTriggerAutomaticRegeneration() async {
        var count = 0
        do {
            _ = try await StoryGeneration.generate(record: storyFixture(), decision: nil) { _, _ in
                count += 1
                throw URLError(.notConnectedToInternet)
            }
            Issue.record("A transport error must reach the reader.")
        } catch {
            #expect(error is URLError)
        }
        #expect(count == 1)
    }

    @Test func configurationAndProgressRejectDuplicatesInvalidLeadAndSkippedScene() throws {
        var initial = storyFixture(count: 3, mode: .member)
        initial.configuration.cast[1].id = initial.configuration.cast[0].id
        #expect(throws: StoryError.self) { try initial.validate() }
        initial = storyFixture(count: 3, mode: .member)
        initial.configuration.leadID = "missing"
        #expect(throws: StoryError.self) { try initial.validate() }
        initial = storyFixture()
        var skipped = storyScene(record: initial)
        skipped.index = 1
        #expect(throws: StoryError.self) { try initial.advancing(with: skipped, decision: nil) }
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        #expect(throws: StoryError.self) { try first.advancing(with: storyScene(record: first), decision: nil) }
    }

    @Test(arguments: [1, 2, 3]) func promptRandomizesSpeakingOrderWithoutChangingSavedStory(count: Int) throws {
        for mode in StoryParticipation.allCases {
            let initial = storyFixture(count: count, mode: mode)
            let record = try initial.advancing(with: storyScene(record: initial), decision: nil)
            let decision = StoryDecision(sceneIndex: 0, intent: "Help everyone", choiceIndex: nil)
            var generator = StoryTestRandomGenerator()
            var orders = Set<[String]>()

            for _ in 0..<32 {
                let messages = try StoryPrompt.messages(record: record, decision: decision, using: &generator)
                let context = try #require(messages[1]["content"])
                func field(_ name: String) throws -> Data {
                    let line = try #require(context.components(separatedBy: "\n").first { $0.hasPrefix(name + ": ") })
                    return Data(line.dropFirst(name.count + 2).utf8)
                }
                let order = try JSONDecoder().decode([String].self, from: field("speakingOrder"))
                let configuration = try JSONDecoder().decode(StoryConfiguration.self, from: field("configuration"))
                #expect(order.count == count)
                #expect(Set(order) == Set(record.configuration.cast.map(\.id)))
                #expect(configuration.cast.map(\.id) == order)
                #expect(configuration.leadID == record.configuration.leadID)
                #expect(configuration.relationships == record.configuration.relationships)
                #expect(try JSONDecoder().decode([StoryScene].self, from: field("savedScenes")) == record.scenes)
                #expect(messages[0]["content"]?.contains("The first line must be spoken by speakingOrder[0]") == true)
                orders.insert(order)
            }

            #expect(orders.count == (count == 1 ? 1 : count == 2 ? 2 : 6))
            #expect(record.configuration == initial.configuration)
        }
    }

    @Test func promptContainsCastSnapshotsModesProgressAndPriorChoicesWithinLimit() throws {
        let initial = storyFixture(count: 3, mode: .member)
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        let decision = StoryDecision(sceneIndex: 0, intent: "I support the protagonist", choiceIndex: nil)
        let messages = try StoryPrompt.messages(record: first, decision: decision)
        let context = messages[1]["content"] ?? ""
        #expect(context.contains("I support the protagonist"))
        #expect(context.contains("speaking_style"))
        #expect(context.contains("leadID"))
        #expect(context.contains("targetEpisode: 1, targetScene: 2, final: false"))
        #expect(context.count < 30000)
        #expect(messages.count == 2)
        #expect(!initial.configuration.romance)
    }

    @Test func archivePreservesOriginalSnapshotAndRejectsMetadataMismatchOrCorruption() throws {
        var record = storyFixture(count: 3)
        let original = #"{"personality":"original-archived-personality","customField":"archive-only"}"#
        record.configuration.cast[0].sourceProfileJSON = original
        let value = try StoryArchive.encode(record)
        let restored = try StoryArchive.decode(value)
        #expect(restored == record)
        #expect(restored.configuration.cast[0].sourceProfileJSON == original)
        let prompt = try StoryPrompt.messages(record: restored, decision: nil)[1]["content"] ?? ""
        #expect(!prompt.contains("original-archived-personality"))
        #expect(!prompt.contains("sourceProfileJSON"))
        for key in ["ownerID", "revision", "operationID", "payload"] {
            var corrupted = value
            corrupted[key] = "corrupt"
            #expect(throws: StoryError.self) { try StoryArchive.decode(corrupted) }
        }
        var invalidProgress = record
        invalidProgress.revision = 8
        #expect(throws: StoryError.self) { try StoryArchive.encode(invalidProgress) }
    }

    @Test func maximumProfilesAndHistoryStillFitTheAIContext() throws {
        var record = storyFixture(count: 3, mode: .member)
        for index in record.configuration.cast.indices {
            record.configuration.cast[index].profile = Dictionary(uniqueKeysWithValues: (0..<24).map { ("field-\($0)", String(repeating: "a", count: 600)) })
            record.configuration.cast[index].sourceProfileJSON = "archive-only"
        }
        for index in 0..<8 {
            let scene = StoryScene(index: index, narration: String(repeating: "n", count: 160),
                                   lines: [StoryLine(speakerID: "cast-0", text: String(repeating: "t", count: 100)),
                                           StoryLine(speakerID: "cast-1", text: String(repeating: "u", count: 100))],
                                   choices: [String(repeating: "a", count: 60), String(repeating: "b", count: 60), String(repeating: "c", count: 60)])
            let decision = index == 0 ? nil : StoryDecision(sceneIndex: index - 1, intent: String(repeating: "i", count: 300), choiceIndex: nil)
            record = try record.advancing(with: scene, decision: decision)
        }
        let messages = try StoryPrompt.messages(record: record, decision: StoryDecision(sceneIndex: 7, intent: String(repeating: "i", count: 300), choiceIndex: nil))
        #expect(messages.compactMap { $0["content"] }.joined().count <= 30000)
    }
}

#if canImport(FirebaseDatabase)
import FirebaseCore
import FirebaseDatabase

@MainActor
struct StoryFirebaseTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["STORY_DATABASE_EMULATOR_TEST"] == "1"))
    func coldCacheAdvanceRetryAndConflict() async throws {
        // A separate app/namespace and a loopback emulator keep production data untouched.
        let name = "story-test-" + UUID().uuidString
        let options = FirebaseOptions(googleAppID: "1:123456:ios:abcdef", gcmSenderID: "123456")
        options.apiKey = "AIza" + String(repeating: "0", count: 35)
        options.databaseURL = "https://demo-story-cache.firebaseio.com"
        options.projectID = "demo-story-cache"
        FirebaseApp.configure(name: name, options: options)
        let app = try #require(FirebaseApp.app(name: name))
        let database = Database.database(app: app)
        database.useEmulator(withHost: "127.0.0.1", port: 19000)
        defer { database.goOffline() }
        let initial = storyFixture()
        let path = StoryRepository.path(userID: initial.ownerID) + "/" + initial.id
        // Seed via REST so the SDK has no local write or listener cache.
        var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:19000/" + path + ".json?ns=demo-story-cache")))
        request.httpMethod = "PUT"
        request.httpBody = try JSONSerialization.data(withJSONObject: StoryArchive.encode(initial))
        let (_, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let repository = StoryRepository(database: database, currentUserID: { initial.ownerID })
        let first = try initial.advancing(with: storyScene(record: initial), decision: nil)
        try await repository.save(first, expectedRevision: 0)
        try await repository.save(first, expectedRevision: 0)
        var competitor = first
        competitor.operationID = UUID().uuidString
        do {
            try await repository.save(competitor, expectedRevision: 0)
            Issue.record("Competing progress must not overwrite the saved scene")
        } catch { #expect(error as? StoryError == .conflict) }
        let saved = try await repository.list(userID: initial.ownerID)
        #expect(saved.first(where: { $0.id == initial.id }) == first)
        try await database.reference().child(path).removeValue()
    }
}
#endif
