import Foundation
import CryptoKit

/// Pure memory operations shared by Firebase transactions and regression tests.
/// No new service: meaning tags from the existing extraction call + local concept expansion.
enum RoleplayMemoryEngine {
    static let profileSlots: Set<String> = ["name", "birthday", "job", "hobbies", "likes", "dislikes", "favorite_animal", "food_dislikes", "location"]

    static func stableID(_ parts: [String]) -> String {
        SHA256.hash(data: Data(parts.joined(separator: "\u{001F}").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func scoped(_ memories: [RoleplayMemory], userId: String, characterId: String) -> [RoleplayMemory] {
        memories.filter { $0.userId == userId && $0.characterId == characterId }
    }

    static func retrievalQuery(_ input: String, history: [ChatMessage]) -> String {
        // Includes both speakers so "that promise" can refer to a topic introduced by the character.
        (history.suffix(8).map { String($0.content.prefix(400)) } + [String(input.prefix(1200))]).joined(separator: "\n")
    }

    static func concepts(_ text: String) -> Set<String> {
        let text = text.lowercased()
        let groups: [[String]] = [
            ["name", "名前", "呼び名", "呼んで", "nickname"],
            ["birthday", "誕生日", "生まれ", "生年月日", "バースデー"],
            ["promise", "約束", "予定", "計画", "一緒に行", "出かけ", "お出かけ", "待ち合わせ", "plan", "visit"],
            ["food_dislikes", "苦手", "食べられ", "嫌い", "食べ物", "食事", "dislike", "food", "eat"],
            ["favorite_animal", "動物", "猫", "ねこ", "犬", "いぬ", "ペット", "cat", "dog", "pet", "animal"],
            ["job", "仕事", "職業", "勤務", "働", "work", "occupation"],
            ["hobbies", "趣味", "休日", "楽しみ", "hobby", "hobbies"],
            ["consultation", "相談", "悩み", "困って", "不安", "解決", "worry", "resolved"],
            ["anniversary", "記念日", "記念", "anniversary"]
        ]
        return Set(groups.filter { group in group.contains { text.contains($0) } }.compactMap(\.first))
    }

    static func select(_ memories: [RoleplayMemory], query: String, limit: Int, now: TimeInterval) -> [RoleplayMemory] {
        guard limit > 0 else { return [] }
        let qt = RoleplayPromptBuilder.tokens(query)
        let qc = concepts(query)
        func score(_ m: RoleplayMemory) -> Double {
            let text = m.content + " " + m.slot + " " + m.searchTerms.joined(separator: " ")
            let overlap = Double(RoleplayPromptBuilder.tokens(text).intersection(qt).count)
            let meaning = Double(concepts(text).intersection(qc).count)
            return min(overlap, 5) + meaning * 8 + Double(m.importance) * 0.5 + 1 / (1 + max(0, now - m.sourceTimestamp) / 604800)
        }
        func ranked(_ list: [RoleplayMemory]) -> [RoleplayMemory] {
            list.sorted { score($0) == score($1) ? $0.id < $1.id : score($0) > score($1) }
        }
        // Reserve space for durable basic facts; related episodes compete separately.
        let profiles = ranked(memories.filter { $0.kind == "profile" })
        let basics = Array(profiles.prefix(min(8, max(1, limit / 2))))
        let ids = Set(basics.map(\.id))
        return basics + ranked(memories.filter { !ids.contains($0.id) }).prefix(limit - basics.count)
    }

    static func materialize(_ items: [RoleplayPromptBuilder.ExtractionResult.Item], pending: [ChatMessage], existing: [RoleplayMemory], userId: String, characterId: String) -> [RoleplayMemory] {
        let byID = Dictionary(pending.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var all = scoped(existing, userId: userId, characterId: characterId)
        for item in items {
            // Production requires traceable evidence. Old extraction responses are not promoted to profile facts.
            let sources = item.sourceMessageIds.compactMap { byID[$0] }
            guard !sources.isEmpty, sources.count == Set(item.sourceMessageIds).count else { continue }
            if item.kind == "profile" {
                guard sources.allSatisfy(\.isUser), item.explicit, profileSlots.contains(item.slot), item.domain != "unknown" else { continue }
            }
            let target = all.first { old in
                (old.domain == item.domain && old.kind == item.kind && old.slot == item.slot && !item.slot.isEmpty)
                    || (!item.replacesId.isEmpty && old.id == item.replacesId && (old.kind == "legacy" || (old.kind == item.kind && old.domain == item.domain)))
            }
            // A conflicting value must explicitly declare whether this is a correction or a change over time.
            if let old = target, RoleplayPromptBuilder.normalizedMemory(old.content) != RoleplayPromptBuilder.normalizedMemory(item.memory),
               !["correction", "change"].contains(item.change) { continue }
            let time = sources.map(\.timestamp).max() ?? 0
            if let old = target, old.sourceTimestamp > time { continue }
            let id = target?.id ?? stableID([userId, characterId, item.domain, item.kind, item.slot, item.sourceMessageIds.sorted().joined(separator: ",")])
            if target == nil && all.contains(where: { RoleplayPromptBuilder.normalizedMemory($0.content) == RoleplayPromptBuilder.normalizedMemory(item.memory) && $0.domain == item.domain }) { continue }
            var m = RoleplayMemory(id: id, userId: userId, characterId: characterId, content: String(item.memory.prefix(400)), importance: item.importance, createdAt: target?.createdAt ?? time)
            m.kind = item.kind; m.domain = item.domain; m.slot = item.slot; m.status = item.status
            m.sourceMessageIds = Array(Set((target?.sourceMessageIds ?? []) + item.sourceMessageIds)).sorted()
            m.sourceTimestamp = time; m.eventDate = item.eventDate.isEmpty ? target?.eventDate ?? "" : String(item.eventDate.prefix(80))
            m.searchTerms = Array(item.searchTerms.prefix(12)).map { String($0.prefix(60)) }
            m.relatedProfileSlots = Array(Set(item.relatedProfileSlots.filter { profileSlots.contains($0) })).sorted()
            m.change = item.change
            // Corrections invalidate the old value; temporal changes retain one prior value as historical data only.
            m.previousContent = item.change == "change" ? target?.content ?? "" : ""
            all.removeAll { $0.id == id }; all.append(m)
        }
        return all
    }

    struct ExtractionBatch {
        var messages: [ChatMessage] = []
        var partialMessageId = ""
        var partialOffset = 0
    }

    /// Long single messages are streamed through bounded fragments without advancing beyond unread text.
    static func extractionBatch(history: [ChatMessage], state: RoleplayState, limit: Int = 40, budget: Int = 16000) -> ExtractionBatch {
        let ordered = history.filter {
            $0.timestamp > state.summarizedUntil
                || ($0.timestamp == state.summarizedUntil && (!state.summarizedBoundaryIds.isEmpty || !state.extractionMessageId.isEmpty) && !state.summarizedBoundaryIds.contains($0.id))
                || $0.id == state.extractionMessageId
        }.sorted { ($0.timestamp, $0.id) < ($1.timestamp, $1.id) }
        var batch = ExtractionBatch()
        var remaining = max(1, budget)
        for original in ordered.prefix(max(0, limit)) {
            let offset = original.id == state.extractionMessageId ? state.extractionOffset : 0
            let unread = String(original.content.dropFirst(offset))
            // Leave ordinary messages whole when they can fit in a fresh batch.
            if unread.count > remaining && !batch.messages.isEmpty { break }
            let fragment = String(unread.prefix(remaining))
            batch.messages.append(ChatMessage(id: original.id, content: fragment, isUser: original.isUser,
                timestamp: original.timestamp, oshiId: original.oshiId, itemId: original.itemId, emotion: original.emotion, action: original.action))
            if fragment.count < unread.count {
                batch.partialMessageId = original.id; batch.partialOffset = offset + fragment.count
                break
            }
            remaining -= fragment.count
            if remaining == 0 { break }
        }
        return batch
    }

    static func validMutations(_ items: [RoleplayPromptBuilder.ExtractionResult.Item], existing: [RoleplayMemory]) -> Bool {
        var slots = Set<String>()
        for item in items {
            if !slots.insert(item.domain + ":" + item.kind + ":" + item.slot).inserted { return false }
            if !item.replacesId.isEmpty && !existing.contains(where: { $0.id == item.replacesId && ($0.kind == "legacy" || ($0.domain == item.domain && $0.kind == item.kind)) }) { return false }
            let old = existing.first { ($0.id == item.replacesId && !item.replacesId.isEmpty)
                || ($0.kind == item.kind && $0.domain == item.domain && $0.slot == item.slot && !item.slot.isEmpty) }
            if let old, (RoleplayPromptBuilder.normalizedMemory(old.content) != RoleplayPromptBuilder.normalizedMemory(item.memory) || old.status != item.status),
               !["correction", "change"].contains(item.change) { return false }
        }
        return true
    }

    static func commit(root: [String: Any], result: RoleplayPromptBuilder.ExtractionResult, pending: [ChatMessage], expected: RoleplayState, userId: String, characterId: String, capacity: Int, partialMessageId: String = "", partialOffset: Int = 0) -> [String: Any]? {
        guard let last = pending.last,
              (root["memoryRevision"] as? Int ?? 0) == expected.memoryRevision,
              (root["summarizedUntil"] as? TimeInterval ?? 0) == expected.summarizedUntil,
              Set(root["summarizedBoundaryIds"] as? [String] ?? []) == expected.summarizedBoundaryIds,
              (root["extractionMessageId"] as? String ?? "") == expected.extractionMessageId,
              (root["extractionOffset"] as? Int ?? 0) == expected.extractionOffset else { return nil }
        let old = (root["memories"] as? [String: Any] ?? [:]).values.compactMap { ($0 as? [String: Any]).flatMap(RoleplayMemory.init(dictionary:)) }
        let relevant = scoped(old, userId: userId, characterId: characterId).filter {
            (expected.personaUpdatedAt == 0 || $0.sourceTimestamp > expected.personaUpdatedAt)
                && (!expected.userPersona.isActive || $0.domain == "roleplay")
        }
        guard validMutations(result.items, existing: relevant),
              !expected.userPersona.isActive || result.items.allSatisfy({ $0.domain == "roleplay" }) else { return nil }
        let relevantIds = Set(relevant.map(\.id))
        var all = materialize(result.items, pending: pending, existing: relevant, userId: userId, characterId: characterId)
        all += scoped(old, userId: userId, characterId: characterId).filter { !relevantIds.contains($0.id) }
        // Current-role facts get space before archived roles within the existing plan capacity.
        func rank(_ memory: RoleplayMemory) -> (Int, Int, Int, TimeInterval) {
            let current = (expected.personaUpdatedAt == 0 || memory.sourceTimestamp > expected.personaUpdatedAt)
                && (!expected.userPersona.isActive || memory.domain == "roleplay")
            return (current ? 1 : 0, memory.kind == "profile" ? 1 : 0, memory.importance, memory.sourceTimestamp)
        }
        all.sort { rank($0) > rank($1) }
        all = Array(all.prefix(capacity))
        var updated = root
        updated["memories"] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.toDictionary()) })
        updated["summarizedUntil"] = last.timestamp
        let boundary = pending.filter { $0.timestamp == last.timestamp && $0.id != partialMessageId }.map(\.id)
        updated["extractionMessageId"] = partialMessageId
        updated["extractionOffset"] = partialOffset
        updated["summarizedBoundaryIds"] = Array(Set(boundary).union(last.timestamp == expected.summarizedUntil ? expected.summarizedBoundaryIds : []))
        updated["summary"] = result.summary.isEmpty ? root["summary"] as? String ?? "" : String(result.summary.prefix(1600))
        updated["memoryRevision"] = expected.memoryRevision + 1
        return updated
    }

    static func deleting(_ memory: RoleplayMemory, root: [String: Any], now: TimeInterval) -> [String: Any] {
        var updated = root
        var memories = root["memories"] as? [String: Any] ?? [:]
        let sourceIDs = Set(memory.sourceMessageIds)
        // Remove related derivatives, including retained previous values.
        memories = memories.filter { key, value in
            guard key != memory.id, let d = value as? [String: Any], let other = RoleplayMemory(dictionary: d) else { return false }
            let dependentProfile = memory.kind == "profile" && (other.domain == memory.domain || other.domain == "unknown")
                && (other.relatedProfileSlots.contains(memory.slot) || concepts(other.content + " " + other.searchTerms.joined(separator: " ")).contains(memory.slot))
            return !dependentProfile && sourceIDs.isDisjoint(with: other.sourceMessageIds)
                && !(other.domain == memory.domain && !memory.slot.isEmpty && other.slot == memory.slot)
        }
        updated["memories"] = memories
        updated["summary"] = "" // A lossy summary cannot safely be selectively redacted.
        updated["hasDeletedMemories"] = true
        // A conservative cutoff also protects legacy records with no provenance and paraphrases in AI replies.
        updated["suppressHistoryBefore"] = max(root["suppressHistoryBefore"] as? TimeInterval ?? 0, now)
        updated["summarizedUntil"] = max(root["summarizedUntil"] as? TimeInterval ?? 0, now)
        updated["summarizedBoundaryIds"] = [String]()
        updated["extractionMessageId"] = ""
        updated["extractionOffset"] = 0
        updated["memoryRevision"] = (root["memoryRevision"] as? Int ?? 0) + 1
        return updated
    }
}
