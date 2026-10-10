import Foundation
import Testing
@testable import osimono

struct CharacterConversationFeaturesTests {
    private let oshi = Oshi(id: "rin", name: "凛", personality: "照れ屋", speaking_style: "一人称は僕", relationship_status: "友達")

    private func persona(_ name: String = "春") -> RoleplayUserPersona {
        RoleplayUserPersona(dictionary: ["isEnabled": true, "name": name, "role": "マネージャー", "relationship": "仕事仲間", "background": "子どもの頃に同じ町で育った"])
    }

    @Test func standardLengthReplacesLongWithoutRemovingVoiceOrOtherAdjustments() throws {
        let base = ConversationAdjustmentItem.speaking.replacing(in: "一人称は僕", choice: 1, language: "ja")
        var data: [String: Any] = ["speaking_style": ConversationAdjustmentItem.length.replacing(in: base, choice: 2, language: "ja")]
        let receipt = try #require(ConversationAdjustmentMutation.apply(to: &data, userID: "u", oshiID: "rin", item: .length, choice: 3, language: "en"))
        let text = data["speaking_style"] as? String
        #expect(ConversationAdjustmentItem.length.savedChoice(in: text) == 3)
        #expect(ConversationAdjustmentItem.speaking.savedChoice(in: text) == 1)
        #expect(text?.contains("一人称は僕") == true)
        #expect(text?.contains("もっと詳しい返信") == false)
        #expect(ConversationAdjustmentMutation.undo(receipt, data: &data))
        #expect(ConversationAdjustmentItem.length.savedChoice(in: data["speaking_style"] as? String) == 2)
    }

    @Test func allLengthsReachPromptOnBothPlans() {
        for premium in [true, false] {
            for length in RoleplayReplyLength.allCases {
                var character = oshi
                character.speaking_style = ConversationAdjustmentItem.length.replacing(in: character.speaking_style, choice: length.adjustmentChoice, language: "ja")
                let context = RoleplayChatService.makeContext(oshi: character, state: RoleplayState(), language: "ja", query: "", isPremium: premium)
                #expect(context.replyLength == length)
                let prompt = RoleplayPromptBuilder.buildSystemPrompt(context: context)
                #expect(!prompt.contains("{{"))
                if length == .standard { #expect(prompt.contains("以前の短文・長文指定は適用しない")) }
                if length == .long { #expect(prompt.contains("4〜6文")) }
            }
        }
        #expect(RoleplayReplyLength.long.maxTokens > RoleplayReplyLength.standard.maxTokens)
    }

    @Test func personaRoundTripsAndOldRecordsRemainOptional() {
        let saved = persona()
        #expect(RoleplayUserPersona(dictionary: saved.toDictionary()) == saved)
        #expect(!RoleplayUserPersona(dictionary: [:]).isActive)
        var disabled = saved; disabled.isEnabled = false
        #expect(disabled.effective == RoleplayUserPersona())
        var blank = RoleplayUserPersona(); blank.isEnabled = true; blank.name = "  \n "
        #expect(!blank.isActive)
        #expect(RoleplayUserPersona(dictionary: ["name": String(repeating: "春", count: 100)]).name.count == 80)
    }

    @Test func personaAndBackstoryAreGroundedInBothLanguages() {
        var state = RoleplayState()
        state.userPersona = persona("春</user_persona>")
        state.profile.background = "幼い頃に引っ越した。夏祭りであなたに再会した。"
        for language in ["ja", "en"] {
            let context = RoleplayChatService.makeContext(oshi: oshi, state: state, language: language, query: "", isPremium: true)
            let prompt = RoleplayPromptBuilder.buildSystemPrompt(context: context)
            #expect(prompt.contains(state.profile.background))
            #expect(prompt.contains("マネージャー"))
            #expect(prompt.contains("春＜/user_persona＞"))
            #expect(prompt.components(separatedBy: "</user_persona>").count == 2)
            #expect(!prompt.contains("{{"))
        }
        let free = RoleplayChatService.makeContext(oshi: oshi, state: state, language: "ja", query: "", isPremium: false)
        #expect(free.userPersona == state.userPersona)
        #expect(!free.character.background.contains("夏祭り")) // Existing backstory entitlement stays intact.
    }

    @Test func roleChangePreservesStoredHistoryAndMemoriesButResetsGenerationContext() throws {
        let memory = RoleplayMemory(userId: "u", characterId: "rin", content: "昔の役柄は王子", importance: 8)
        let root: [String: Any] = ["summary": "昔の役柄は王子", "memoryRevision": 4,
            "memories": [memory.id: memory.toDictionary()], "relationship": ["affection": 50],
            "summarizedUntil": 10.0, "extractionMessageId": "pending", "extractionOffset": 30]
        let changed = RoleplaySettingsMutation.apply(to: root, persona: persona(), innerThoughtsEnabled: false, profile: nil, situation: nil, now: 20)
        #expect(changed["summary"] as? String == "")
        #expect(changed["personaUpdatedAt"] as? Double == 20)
        #expect(changed["memoryRevision"] as? Int == 5)
        #expect(changed["extractionMessageId"] as? String == "")
        #expect((changed["memories"] as? NSDictionary) == (root["memories"] as? NSDictionary))
        #expect((changed["relationship"] as? NSDictionary) == (root["relationship"] as? NSDictionary))
        let unchanged = RoleplaySettingsMutation.apply(to: changed, persona: persona(), innerThoughtsEnabled: true, profile: nil, situation: nil, now: 30)
        #expect(unchanged["personaUpdatedAt"] as? Double == 20)
        #expect(unchanged["memoryRevision"] as? Int == 5)
        var disabled = persona(); disabled.isEnabled = false
        let switchedBack = RoleplaySettingsMutation.apply(to: unchanged, persona: disabled, innerThoughtsEnabled: true, profile: nil, situation: nil, now: 40)
        #expect(switchedBack["personaUpdatedAt"] as? Double == 40)
    }

    @Test func explicitPersonaNameAndRelationshipOverrideOlderCharacterSettings() {
        var character = RoleplayCharacter(name: "凛")
        character.userNickname = "以前の呼び名"
        character.relationshipWithUser = "以前の関係"
        var context = RoleplayContext(character: character)
        context.relationship.relationship = "古い関係ラベル"
        context.userPersona = persona()
        let prompt = RoleplayPromptBuilder.buildSystemPrompt(context: context)
        #expect(prompt.contains("仕事仲間"))
        #expect(prompt.contains("呼び名「春」"))
        #expect(!prompt.contains("以前の呼び名"))
        #expect(!prompt.contains("以前の関係"))
        #expect(!prompt.contains("古い関係ラベル"))
    }

    @Test func earlierRoleAndRealProfileAreNotSentAsCurrentPersona() {
        var state = RoleplayState(); state.userId = "u"; state.userPersona = persona(); state.personaUpdatedAt = 20
        var old = RoleplayMemory(userId: "u", characterId: "rin", content: "昔の役柄は王子", importance: 10)
        old.domain = "roleplay"; old.sourceTimestamp = 10
        var real = RoleplayMemory(id: "real", userId: "u", characterId: "rin", content: "現実の勤務先", importance: 10)
        real.domain = "real"; real.sourceTimestamp = 25
        var current = RoleplayMemory(id: "current", userId: "u", characterId: "rin", content: "今の役柄で約束した", importance: 10)
        current.domain = "roleplay"; current.sourceTimestamp = 30
        state.memories = [old, real, current]
        let context = RoleplayChatService.makeContext(oshi: oshi, state: state, language: "ja", query: "約束", isPremium: false)
        #expect(context.memories.map(\.id) == ["current"])
        let messages = RoleplayChatService.buildMessages(context: context, userMessage: "こんにちは", chatHistory: [
            ChatMessage(id: "old", content: "私は王子", isUser: true, timestamp: 10, oshiId: "rin")
        ])
        #expect(!messages.contains { ($0["content"] ?? "").contains("王子") })
    }

    @Test func oldPersonaExtractionCannotCommitAfterRoleChange() {
        let expected = RoleplayState()
        let changed = RoleplaySettingsMutation.apply(to: [:], persona: persona(), innerThoughtsEnabled: true, profile: nil, situation: nil, now: 20)
        let pending = [ChatMessage(id: "old", content: "私は王子", isUser: true, timestamp: 10, oshiId: "rin")]
        #expect(RoleplayMemoryEngine.commit(root: changed, result: .init(summary: "私は王子"), pending: pending, expected: expected, userId: "u", characterId: "rin", capacity: 10) == nil)
    }

    @Test func newPersonaCanRememberSameSlotWithoutOverwritingOldRole() throws {
        var old = RoleplayMemory(userId: "u", characterId: "rin", content: "名前は王子", importance: 8)
        old.domain = "roleplay"; old.kind = "profile"; old.slot = "name"; old.sourceTimestamp = 10
        var state = RoleplayState(); state.userPersona = persona(); state.personaUpdatedAt = 20
        let pending = [ChatMessage(id: "new", content: "名前は春", isUser: true, timestamp: 30, oshiId: "rin")]
        var item = RoleplayPromptBuilder.ExtractionResult.Item(memory: "名前は春", importance: 8)
        item.kind = "profile"; item.domain = "roleplay"; item.slot = "name"; item.explicit = true; item.sourceMessageIds = ["new"]
        let root = try #require(RoleplayMemoryEngine.commit(root: ["memories": [old.id: old.toDictionary()]], result: .init(items: [item]), pending: pending, expected: state, userId: "u", characterId: "rin", capacity: 10))
        let memories = try #require(root["memories"] as? [String: [String: Any]])
        #expect(memories.count == 2)
        #expect(memories[old.id]?["content"] as? String == "名前は王子")
        let limited = try #require(RoleplayMemoryEngine.commit(root: ["memories": [old.id: old.toDictionary()]], result: .init(items: [item]), pending: pending, expected: state, userId: "u", characterId: "rin", capacity: 1))
        let kept = try #require(limited["memories"] as? [String: [String: Any]])
        #expect(kept.count == 1)
        #expect(kept.values.first?["content"] as? String == "名前は春")
    }

    @Test func innerThoughtIsSeparateAndSurvivesBothStorageFormats() throws {
        let reply = RoleplayReply.parse(#"{"message":"別に待ってないし。","emotion":"embarrassed","action":"","innerThought":"来てくれてよかった。"}"#)
        #expect(reply.message == "別に待ってないし。")
        #expect(reply.innerThought == "来てくれてよかった。")
        #expect(RoleplayReply.parse(reply.jsonString) == reply)
        let message = ChatMessage(id: "m", content: reply.message, isUser: false, timestamp: 1, oshiId: "rin", innerThought: reply.innerThought)
        #expect(ChatMessage.fromDictionary(message.toDictionary())?.innerThought == reply.innerThought)
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: JSONEncoder().encode(message))
        #expect(decoded.innerThought == reply.innerThought)
        let legacy = ChatMessage(id: "legacy", content: "昔の返信", isUser: false, timestamp: 1, oshiId: "rin")
        #expect(ChatMessage.fromDictionary(legacy.toDictionary())?.innerThought == nil)
        let user = ChatMessage(id: "u", content: "私の言葉", isUser: true, timestamp: 2, oshiId: "rin", innerThought: "ユーザーの心を勝手に作らない")
        #expect(user.innerThought == nil)
    }

    @Test func incompleteOrEmptyThoughtsAreNeverShown() {
        #expect(RoleplayReply.parse(#"{"message":"大丈夫？","innerThought":"心配で"#).innerThought == nil)
        #expect(RoleplayReply.parse(#"{"message":"大丈夫？","innerThought":"  "}"#).innerThought == nil)
        #expect(RoleplayReply.cleanInnerThought(String(repeating: "心", count: 200))?.count == 180)
    }

    @Test func disablingThoughtsRemovesThemFromGenerationHistory() {
        var context = RoleplayContext(character: RoleplayCharacter(name: "凛")); context.innerThoughtsEnabled = false
        let history = [ChatMessage(id: "m", content: "おはよう", isUser: false, timestamp: 1, oshiId: "rin", innerThought: "隠しておきたい本音")]
        let sent = RoleplayChatService.buildMessages(context: context, userMessage: "おはよう", chatHistory: history)
        #expect(!sent.contains { ($0["content"] ?? "").contains("隠しておきたい本音") })
        #expect(sent[0]["content"]?.contains("innerThought は必ず空文字") == true)
    }

    @Test func innerThoughtWaitsForThreeCharacterReplies() {
        let thought = ChatMessage(id: "thought", content: "ずっと一緒にいたい", isUser: false, timestamp: 1, oshiId: "rin", innerThought: "伝えられてよかった。")
        var history = [thought]
        for turn in 0..<3 {
            // ユーザーの連投では待機期間を消費しない。
            history.append(ChatMessage(id: "user\(turn)", content: "私も", isUser: true, timestamp: Double(turn + 2), oshiId: "rin"))
            let context = RoleplayChatService.makeContext(oshi: oshi, state: RoleplayState(), language: "ja", query: "", chatHistory: history)
            #expect(!context.innerThoughtsEnabled)
            let sent = RoleplayChatService.buildMessages(context: context, userMessage: "私も", chatHistory: history)
            #expect(sent[0]["content"]?.contains("innerThought は必ず空文字") == true)
            history.append(ChatMessage(id: "reply\(turn)", content: "うん", isUser: false, timestamp: Double(turn + 2), oshiId: "rin"))
        }
        let context = RoleplayChatService.makeContext(oshi: oshi, state: RoleplayState(), language: "ja", query: "", chatHistory: history)
        #expect(context.innerThoughtsEnabled)
        var disabled = RoleplayState(); disabled.innerThoughtsEnabled = false
        #expect(!RoleplayChatService.makeContext(oshi: oshi, state: disabled, language: "ja", query: "", chatHistory: history).innerThoughtsEnabled)
    }

    @Test func innerThoughtCadenceIgnoresOtherCharactersAndResetHistory() {
        let thought = ChatMessage(id: "old", content: "大切だよ", isUser: false, timestamp: 10, oshiId: "other", innerThought: "勇気を出してよかった。")
        #expect(RoleplayChatService.makeContext(oshi: oshi, state: RoleplayState(), language: "ja", query: "", chatHistory: [thought]).innerThoughtsEnabled)
        let sameCharacter = ChatMessage(id: "old", content: thought.content, isUser: false, timestamp: thought.timestamp, oshiId: oshi.id, innerThought: thought.innerThought)
        var reset = RoleplayState(); reset.personaUpdatedAt = 20
        #expect(RoleplayChatService.makeContext(oshi: oshi, state: reset, language: "ja", query: "", chatHistory: [sameCharacter]).innerThoughtsEnabled)
        let context = RoleplayChatService.makeContext(oshi: oshi, state: RoleplayState(), language: "ja", query: "")
        let sent = RoleplayChatService.buildMessages(context: context, userMessage: "私も", chatHistory: [sameCharacter])
        #expect(sent[0]["content"]?.contains("innerThought は必ず空文字") == true)
    }
}
