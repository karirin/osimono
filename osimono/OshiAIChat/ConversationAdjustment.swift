import Foundation

/// These readable lines live in the existing editable Oshi fields. Only one line per item is kept.
enum ConversationAdjustmentItem: String, CaseIterable, Codable, Identifiable {
    case speaking, interaction, length
    var id: String { rawValue }
    var field: String { self == .interaction ? "relationship_detail" : "speaking_style" }
    var validChoices: ClosedRange<Int> { self == .length ? 1...3 : 1...2 }
    var title: String { ConversationAdjustmentText.string("adjustment_\(rawValue)_title") }
    var prefixes: [String] {
        switch self {
        case .speaking: return ["話し方の調整：", "Speaking adjustment: "]
        case .interaction: return ["接し方の調整：", "Interaction adjustment: "]
        case .length: return ["返信スタイル：", "Reply style: "]
        }
    }
    func optionTitle(_ choice: Int) -> String {
        ConversationAdjustmentText.string(choice == 0 ? "adjustment_keep" : "adjustment_\(rawValue)_\(choice)")
    }
    func question(name: String) -> String {
        String(format: ConversationAdjustmentText.string("adjustment_\(rawValue)_question"), name)
    }
    func line(choice: Int, language: String) -> String {
        let ja = language == "ja"
        let values: [String]
        switch self {
        case .speaking: values = ja ? ["もっとくだけた口調", "もっと丁寧な口調"] : ["More casual speech", "More polite speech"]
        case .interaction: values = ja ? ["もっと甘く接する", "もう少し控えめに接する"] : ["More affectionate", "More reserved"]
        case .length: values = ja ? ["もっと短い返信", "もっと詳しい返信", "標準の長さの返信"] : ["Shorter replies", "More detailed replies", "Standard length replies"]
        }
        guard validChoices.contains(choice) else { return "" }
        return prefixes[ja ? 0 : 1] + values[choice - 1]
    }
    func savedChoice(in text: String?) -> Int? {
        let lines = (text ?? "").components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        for choice in validChoices {
            if ["ja", "en"].contains(where: { lines.contains(line(choice: choice, language: $0)) }) { return choice }
        }
        return nil
    }
    func replacing(in text: String?, choice: Int, language: String) -> String {
        guard validChoices.contains(choice) else { return text ?? "" }
        var lines = (text ?? "").components(separatedBy: "\n")
        lines.removeAll { line in prefixes.contains { line.trimmingCharacters(in: .whitespaces).hasPrefix($0) } }
        if lines == [""] { lines = [] }
        lines.append(line(choice: choice, language: language))
        return lines.joined(separator: "\n")
    }
}

enum ConversationAdjustmentText {
    static func string(_ key: String) -> String { NSLocalizedString(key, comment: "Conversation adjustment") }
}

struct ConversationAdjustmentState {
    var completedRounds = 0
    var lastRoundID = ""
    var lastAutomaticDay = ""
    var presented: [String: TimeInterval] = [:]
    var suppressedUntil: [String: TimeInterval] = [:]
    init(dictionary: [String: Any] = [:]) {
        completedRounds = dictionary["completedRounds"] as? Int ?? 0
        lastRoundID = dictionary["lastRoundID"] as? String ?? ""
        lastAutomaticDay = dictionary["lastAutomaticDay"] as? String ?? ""
        presented = dictionary["presented"] as? [String: TimeInterval] ?? [:]
        suppressedUntil = dictionary["suppressedUntil"] as? [String: TimeInterval] ?? [:]
    }
    var dictionary: [String: Any] {
        ["completedRounds": completedRounds, "lastRoundID": lastRoundID,
         "lastAutomaticDay": lastAutomaticDay, "presented": presented, "suppressedUntil": suppressedUntil]
    }
    func merging(_ other: ConversationAdjustmentState) -> ConversationAdjustmentState {
        var result = completedRounds >= other.completedRounds ? self : other
        result.lastAutomaticDay = max(lastAutomaticDay, other.lastAutomaticDay)
        result.presented = presented.merging(other.presented, uniquingKeysWith: max)
        result.suppressedUntil = suppressedUntil.merging(other.suppressedUntil, uniquingKeysWith: max)
        return result
    }
    mutating func recordRound(id: String) {
        guard id != lastRoundID else { return }
        completedRounds += 1
        lastRoundID = id
    }
    func nextItem(now: Date) -> ConversationAdjustmentItem? {
        guard completedRounds >= 5, lastAutomaticDay != RoleplayChatService.dayKey(for: now) else { return nil }
        // Always introduce speaking first, then rotate to the least recently presented eligible item.
        return ConversationAdjustmentItem.allCases.filter {
            (suppressedUntil[$0.rawValue] ?? 0) <= now.timeIntervalSince1970
        }.min { (presented[$0.rawValue] ?? 0) < (presented[$1.rawValue] ?? 0) }
    }
    mutating func markPresented(_ item: ConversationAdjustmentItem, now: Date, automatic: Bool) {
        presented[item.rawValue] = now.timeIntervalSince1970
        if automatic { lastAutomaticDay = RoleplayChatService.dayKey(for: now) }
        suppress(item, days: 7, now: now)
    }
    mutating func suppress(_ item: ConversationAdjustmentItem, days: Int, now: Date) {
        suppressedUntil[item.rawValue] = now.addingTimeInterval(Double(days) * 86_400).timeIntervalSince1970
    }
}

struct ConversationAdjustmentUndo {
    let userID: String
    let oshiID: String
    let item: ConversationAdjustmentItem
    let before: String?
    let after: String
}

/// Pure mutation logic shared by Firebase transactions and tests.
enum ConversationAdjustmentMutation {
    static func apply(to data: inout [String: Any], userID: String, oshiID: String,
                      item: ConversationAdjustmentItem, choice: Int, language: String) -> ConversationAdjustmentUndo? {
        guard item.validChoices.contains(choice) else { return nil }
        let before = data[item.field] as? String
        let after = item.replacing(in: before, choice: choice, language: language)
        data[item.field] = after
        return ConversationAdjustmentUndo(userID: userID, oshiID: oshiID, item: item, before: before, after: after)
    }
    static func undo(_ undo: ConversationAdjustmentUndo, data: inout [String: Any]) -> Bool {
        // Refuse to overwrite an intervening edit, including one made on another device.
        guard data[undo.item.field] as? String == undo.after else { return false }
        data[undo.item.field] = undo.before
        return true
    }
}
