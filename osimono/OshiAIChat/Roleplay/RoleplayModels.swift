//
//  RoleplayModels.swift
//  osimono
//
//  ロールプレイ機能のデータモデル。
//  Firebase / SwiftUI に依存しない（Foundationのみ）ので単体でテスト・再利用できる。
//

import Foundation

// MARK: - Emotion

/// キャラクターの感情。将来の表情差分画像・アニメーション・音声切り替えのキーとして使う。
enum CharacterEmotion: String, Codable, CaseIterable {
    case neutral, happy, sad, angry, embarrassed, surprised, excited, worried, jealous, affectionate, confused

    /// 未知の値や空文字は neutral にフォールバック
    init(rawOrNeutral raw: String?) {
        let key = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        self = CharacterEmotion(rawValue: key) ?? .neutral
    }

    /// 表情差分画像を用意する場合のアセット名（例: "rin_embarrassed"）に使うサフィックス
    var assetSuffix: String { rawValue }

    /// 現段階のUI用の簡易インジケーター
    var indicator: String {
        switch self {
        case .neutral: return ""
        case .happy: return "😊"
        case .sad: return "😢"
        case .angry: return "😠"
        case .embarrassed: return "😳"
        case .surprised: return "😲"
        case .excited: return "✨"
        case .worried: return "😟"
        case .jealous: return "😤"
        case .affectionate: return "💗"
        case .confused: return "😕"
        }
    }
}

// MARK: - Reply

/// LLMの構造化レスポンス
struct RoleplayReply: Equatable {
    var message: String
    var emotion: CharacterEmotion
    var action: String?
    /// Fictional character narration, never a model's reasoning or spoken dialogue.
    var innerThought: String? = nil

    /// action の最大文字数（これを超えたら切り詰める）
    static let maxActionLength = 60

    /// LLMの生出力をパースする。
    /// - 正しいJSON → そのまま使う
    /// - JSONっぽいが壊れている（途中で切れた等）→ message だけ救出を試みる。救出できなければ message は空
    /// - JSONではない → 通常テキストとして扱う
    /// message が空の返答は呼び出し側で失敗として扱うこと（生のJSONを画面に出さないため）。
    static func parse(_ raw: String) -> RoleplayReply {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let json = extractJSONObject(from: trimmed) {
            return RoleplayReply(
                message: cleanMessage(json["message"] as? String ?? ""),
                emotion: CharacterEmotion(rawOrNeutral: json["emotion"] as? String),
                action: cleanAction(json["action"] as? String),
                innerThought: cleanInnerThought(json["innerThought"] as? String)
            )
        }

        if looksLikeJSON(trimmed) {
            let message = salvageStringField("message", from: trimmed).map(cleanMessage) ?? ""
            return RoleplayReply(
                message: message,
                emotion: CharacterEmotion(rawOrNeutral: salvageStringField("emotion", from: trimmed)),
                action: nil
            )
        }

        return RoleplayReply(message: cleanMessage(trimmed), emotion: .neutral, action: nil)
    }

    private static func looksLikeJSON(_ text: String) -> Bool {
        text.hasPrefix("{") || text.hasPrefix("```") || text.contains("\"message\"")
    }

    /// 壊れたJSONから "field": "..." の文字列値を取り出す。閉じ引用符が無い（途中で切れた）場合は末尾に…を付ける。
    static func salvageStringField(_ field: String, from text: String) -> String? {
        guard let keyRange = text.range(of: "\"\(field)\"") else { return nil }
        var index = keyRange.upperBound
        // : と空白を読み飛ばして開き引用符へ
        while index < text.endIndex, text[index] == ":" || text[index].isWhitespace {
            index = text.index(after: index)
        }
        guard index < text.endIndex, text[index] == "\"" else { return nil }
        index = text.index(after: index)

        var result = ""
        var escaping = false
        var closed = false
        while index < text.endIndex {
            let char = text[index]
            index = text.index(after: index)
            if escaping {
                switch char {
                case "n": result.append("\n")
                case "t": result.append("\t")
                case "u":
                    let hexEnd = text.index(index, offsetBy: 4, limitedBy: text.endIndex) ?? text.endIndex
                    if let code = UInt32(text[index..<hexEnd], radix: 16), let scalar = Unicode.Scalar(code) {
                        result.append(Character(scalar))
                    }
                    index = hexEnd
                default: result.append(char)
                }
                escaping = false
            } else if char == "\\" {
                escaping = true
            } else if char == "\"" {
                closed = true
                break
            } else {
                result.append(char)
            }
        }

        let value = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return closed ? value : value + "…"
    }

    /// 会話履歴としてLLMへ戻すときの表現（出力形式を安定させるため同じJSON形式にする）
    var jsonString: String {
        var dict: [String: String] = [
            "message": message,
            "emotion": emotion.rawValue,
            "action": action ?? ""
        ]
        if let innerThought = Self.cleanInnerThought(innerThought) { dict["innerThought"] = innerThought }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return message
        }
        return string
    }

    static func cleanInnerThought(_ text: String?) -> String? {
        guard let text else { return nil }
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return String(cleaned.prefix(180))
    }

    private static func extractJSONObject(from text: String) -> [String: Any]? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return nil
        }
        let candidate = String(text[start...end])
        guard let data = candidate.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// セリフ全体が「」で囲まれている場合は外す（UI側で装飾するため）
    static func cleanMessage(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("「"), result.hasSuffix("」") {
            let inner = String(result.dropFirst().dropLast())
            if !inner.contains("「") && !inner.contains("」") {
                result = inner.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // 対応の取れていない括弧の残骸（例: "…話？」」"）を取り除く
        while result.hasSuffix("」") && result.filter({ $0 == "」" }).count > result.filter({ $0 == "「" }).count {
            result = String(result.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        while result.hasPrefix("「") && result.filter({ $0 == "「" }).count > result.filter({ $0 == "」" }).count {
            result = String(result.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    /// 動作描写の前後にある *…* や （…） を外す
    static func cleanAction(_ text: String?) -> String? {
        guard var result = text?.trimmingCharacters(in: .whitespacesAndNewlines), !result.isEmpty else {
            return nil
        }
        let wrappers: [(String, String)] = [("*", "*"), ("（", "）"), ("(", ")"), ("【", "】")]
        for (open, close) in wrappers where result.hasPrefix(open) && result.hasSuffix(close) && result.count > open.count + close.count {
            result = String(result.dropFirst(open.count).dropLast(close.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if result.count > maxActionLength {
            result = String(result.prefix(maxActionLength)) + "…"
        }
        return result.isEmpty ? nil : result
    }
}

// MARK: - Situation

/// 会話ごとの現在のシチュエーション
struct RoleplaySituation: Equatable {
    var location: String = ""
    var time: String = ""
    var situation: String = ""

    var isEmpty: Bool {
        [location, time, situation].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// ヘッダー表示用の短い要約（例: "学校の屋上・放課後"）
    var shortLabel: String {
        [location, time]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "・")
    }

    init(location: String = "", time: String = "", situation: String = "") {
        self.location = location
        self.time = time
        self.situation = situation
    }

    init(dictionary: [String: Any]) {
        location = dictionary["location"] as? String ?? ""
        time = dictionary["time"] as? String ?? ""
        situation = dictionary["situation"] as? String ?? ""
    }

    func toDictionary() -> [String: Any] {
        ["location": location, "time": time, "situation": situation]
    }
}

// MARK: - Relationship

/// キャラクターとユーザーの関係性（userId × characterId 単位）。数値はユーザーには見せず、promptでは意味に変換して使う。
/// ステージ判定のしきい値・変化量の上限などは RelationshipTuning に集約している。
struct RoleplayRelationship: Equatable {
    static var defaultAffection: Int { RelationshipTuning.initialAffection }
    static var defaultTrust: Int { RelationshipTuning.initialTrust }
    static var maxDeltaPerUpdate: Int { RelationshipTuning.maxDeltaPerUpdate }
    static var maxDailyChange: Int { RelationshipTuning.maxDailyChange }

    var affection: Int = RoleplayRelationship.defaultAffection
    var trust: Int = RoleplayRelationship.defaultTrust
    /// "幼なじみ" などの関係ラベル。空の場合はキャラ設定の関係性を使う。
    var relationship: String = ""
    /// 保存されている関係ステージ。条件を満たしたときに1段ずつ上がり、下がらない（数値の低下は態度の温度で表す）
    var stage: RelationshipStage = .stranger
    /// 最後にステージが変わった時刻（ステージアップの最短間隔の判定用。0は未設定）
    var stageChangedAt: TimeInterval = 0
    var createdAt: TimeInterval = 0
    var updatedAt: TimeInterval = 0
    /// 日次上限の集計用（"yyyy-MM-dd"）と、その日に動いた量
    var dayKey: String = ""
    var dayAffectionChange: Int = 0
    var dayTrustChange: Int = 0
    /// 1時間あたりの上昇量の集計用（"yyyy-MM-dd-HH"）
    var hourKey: String = ""
    var hourAffectionGain: Int = 0
    var hourTrustGain: Int = 0

    /// stage を省略すると数値から判定する（保存前の新規レコード・テスト用）
    init(affection: Int = RoleplayRelationship.defaultAffection,
         trust: Int = RoleplayRelationship.defaultTrust,
         relationship: String = "",
         stage: RelationshipStage? = nil) {
        self.affection = min(max(affection, 0), 100)
        self.trust = min(max(trust, 0), 100)
        self.relationship = relationship
        self.stage = stage ?? RelationshipStage.qualified(affection: self.affection, trust: self.trust)
    }

    init(dictionary: [String: Any]) {
        affection = min(max(dictionary["affection"] as? Int ?? RoleplayRelationship.defaultAffection, 0), 100)
        trust = min(max(dictionary["trust"] as? Int ?? RoleplayRelationship.defaultTrust, 0), 100)
        relationship = dictionary["relationship"] as? String ?? ""
        // stage が無いのはこの機能より前に作られたレコード。今の数値から判定し、演出は出さない（今の距離感を保つ）
        stage = (dictionary["stage"] as? String).flatMap(RelationshipStage.init(rawValue:))
            ?? RelationshipStage.qualified(affection: affection, trust: trust)
        stageChangedAt = dictionary["stageChangedAt"] as? TimeInterval ?? 0
        createdAt = dictionary["createdAt"] as? TimeInterval ?? 0
        updatedAt = dictionary["updatedAt"] as? TimeInterval ?? 0
        dayKey = dictionary["dayKey"] as? String ?? ""
        dayAffectionChange = dictionary["dayAffectionChange"] as? Int ?? 0
        dayTrustChange = dictionary["dayTrustChange"] as? Int ?? 0
        hourKey = dictionary["hourKey"] as? String ?? ""
        hourAffectionGain = dictionary["hourAffectionGain"] as? Int ?? 0
        hourTrustGain = dictionary["hourTrustGain"] as? Int ?? 0
    }

    func toDictionary() -> [String: Any] {
        [
            "affection": affection,
            "trust": trust,
            "relationship": relationship,
            "stage": stage.rawValue,
            "stageChangedAt": stageChangedAt,
            "createdAt": createdAt,
            "updatedAt": updatedAt,
            "dayKey": dayKey,
            "dayAffectionChange": dayAffectionChange,
            "dayTrustChange": dayTrustChange,
            "hourKey": hourKey,
            "hourAffectionGain": hourAffectionGain,
            "hourTrustGain": hourTrustGain
        ]
    }

    /// 数値の条件は満たしているが、最短間隔のためにまだステージが上がっていない
    var isAwaitingStageUp: Bool {
        RelationshipStage.qualified(affection: affection, trust: trust) > stage
    }

    /// 次のステージまでの進み具合（0〜1）。affection と trust の遅れている方に合わせる。数値そのものは表示しない
    var progressToNextStage: Double {
        guard let next = stage.next else { return 1 }
        let from = stage.requirement, to = next.requirement
        func part(_ value: Int, _ lower: Int, _ upper: Int) -> Double {
            guard upper > lower else { return 1 }
            return min(max(Double(value - lower) / Double(upper - lower), 0), 1)
        }
        let progress = min(part(affection, from.affection, to.affection), part(trust, from.trust, to.trust))
        return min(progress, RelationshipTuning.maxDisplayedProgress)
    }

    /// 抽出結果の変化量を適用する。
    /// - userTurns: この抽出がカバーしたユーザー発言数。発言数が少ない抽出ほど動かせる幅を小さくする
    ///   （1〜2発言で±1、3〜4発言で±2、5発言以上で±3）。重要ワードで毎ターン抽出が走っても急上昇しない。
    /// - substantiveTurns: そのうち同じ・よく似た発言の繰り返しを除いた数。0なら上昇させない（nilなら userTurns と同じ）
    /// - dayKey / hourKey: 日次・時間ごとの上限の集計キー。キーが変わると集計をリセットする。
    /// - now: ステージアップの最短間隔・更新時刻の判定に使う
    func applying(affectionDelta: Int, trustDelta: Int, userTurns: Int = 6, substantiveTurns: Int? = nil,
                  dayKey: String = "", hourKey: String = "", now: TimeInterval = Date().timeIntervalSince1970) -> RoleplayRelationship {
        func turnCap(_ turns: Int) -> Int {
            min(RelationshipTuning.maxDeltaPerUpdate, max((turns + 1) / 2, 1))
        }
        let lossCap = turnCap(userTurns)
        let substantive = min(substantiveTurns ?? userTurns, userTurns)
        let gainCap = substantive <= 0 ? 0 : turnCap(substantive)
        let daily = RelationshipTuning.maxDailyChange
        let hourly = RelationshipTuning.maxHourlyGain

        var updated = self
        if updated.dayKey != dayKey {
            updated.dayKey = dayKey
            updated.dayAffectionChange = 0
            updated.dayTrustChange = 0
        }
        if updated.hourKey != hourKey {
            updated.hourKey = hourKey
            updated.hourAffectionGain = 0
            updated.hourTrustGain = 0
        }

        func step(_ value: Int, _ delta: Int, _ dayUsed: Int, _ hourGain: Int) -> (value: Int, dayUsed: Int, hourGain: Int) {
            var clamped = min(max(delta, -lossCap), gainCap)
            clamped = min(max(clamped, -daily - dayUsed), daily - dayUsed)
            if clamped > 0 {
                clamped = max(min(clamped, hourly - hourGain), 0)
            }
            let newValue = min(max(value + clamped, 0), 100)
            let change = newValue - value
            return (newValue, dayUsed + change, hourGain + max(change, 0))
        }

        (updated.affection, updated.dayAffectionChange, updated.hourAffectionGain) =
            step(updated.affection, affectionDelta, updated.dayAffectionChange, updated.hourAffectionGain)
        (updated.trust, updated.dayTrustChange, updated.hourTrustGain) =
            step(updated.trust, trustDelta, updated.dayTrustChange, updated.hourTrustGain)

        if updated.createdAt == 0 { updated.createdAt = now }
        updated.updatedAt = now
        return updated.advancingStage(now: now)
    }

    /// 条件を満たしていれば1段だけステージを上げる。前回のステージアップから最短間隔が空いていなければ待つ。
    func advancingStage(now: TimeInterval) -> RoleplayRelationship {
        guard isAwaitingStageUp, let next = stage.next else { return self }
        if stageChangedAt > 0 && now - stageChangedAt < RelationshipTuning.minIntervalBetweenStageUps {
            return self
        }
        var updated = self
        updated.stage = next
        updated.stageChangedAt = now
        return updated
    }
}

// MARK: - Memory

/// キャラクターとユーザーの長期記憶。userId × characterId でスコープされる。
struct RoleplayMemory: Identifiable, Equatable {
    let id: String
    let userId: String
    let characterId: String
    var content: String
    /// 1〜10
    var importance: Int
    let createdAt: TimeInterval
    // Optional additions preserve old records. Legacy facts remain available without inventing provenance.
    var kind = "legacy" // profile / event / legacy
    var domain = "unknown" // real / roleplay / unknown
    var slot = "" // stable profile field or event identity, scoped by domain
    var status = "active" // past / planned / ongoing / cancelled / resolved
    var sourceMessageIds: [String] = []
    var sourceTimestamp: TimeInterval = 0
    var eventDate = ""
    var searchTerms: [String] = []
    var relatedProfileSlots: [String] = []
    var change = "" // correction / change
    var previousContent = ""

    init(id: String = UUID().uuidString, userId: String, characterId: String, content: String, importance: Int, createdAt: TimeInterval = Date().timeIntervalSince1970) {
        self.id = id
        self.userId = userId
        self.characterId = characterId
        self.content = content
        self.importance = min(max(importance, 1), 10)
        self.createdAt = createdAt
    }

    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let userId = dictionary["userId"] as? String,
              let characterId = dictionary["characterId"] as? String,
              let content = dictionary["content"] as? String else {
            return nil
        }
        self.init(
            id: id,
            userId: userId,
            characterId: characterId,
            content: content,
            importance: dictionary["importance"] as? Int ?? 5,
            createdAt: dictionary["createdAt"] as? TimeInterval ?? 0
        )
        kind = dictionary["kind"] as? String ?? "legacy"
        domain = dictionary["domain"] as? String ?? "unknown"
        slot = dictionary["slot"] as? String ?? ""
        status = dictionary["status"] as? String ?? "active"
        sourceMessageIds = dictionary["sourceMessageIds"] as? [String] ?? []
        sourceTimestamp = dictionary["sourceTimestamp"] as? TimeInterval ?? 0
        eventDate = dictionary["eventDate"] as? String ?? ""
        searchTerms = dictionary["searchTerms"] as? [String] ?? []
        relatedProfileSlots = dictionary["relatedProfileSlots"] as? [String] ?? []
        change = dictionary["change"] as? String ?? ""
        previousContent = dictionary["previousContent"] as? String ?? ""
    }

    func toDictionary() -> [String: Any] {
        [
            "kind": kind, "domain": domain, "slot": slot, "status": status,
            "sourceMessageIds": sourceMessageIds, "sourceTimestamp": sourceTimestamp,
            "eventDate": eventDate, "searchTerms": searchTerms, "relatedProfileSlots": relatedProfileSlots, "change": change,
            "previousContent": previousContent,
            "id": id,
            "userId": userId,
            "characterId": characterId,
            "content": content,
            "importance": importance,
            "createdAt": createdAt
        ]
    }
}

// MARK: - Character

/// ロールプレイ用に追加で編集できるキャラクター設定（既存の Oshi にない項目）
struct RoleplayProfile: Equatable {
    var description: String = ""
    var background: String = ""
    var worldSetting: String = ""
    var likes: String = ""
    var dislikes: String = ""
    var behaviorRules: String = ""
    var exampleDialogues: String = ""

    var isEmpty: Bool {
        [description, background, worldSetting, likes, dislikes, behaviorRules, exampleDialogues]
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    init() {}

    init(dictionary: [String: Any]) {
        description = dictionary["description"] as? String ?? ""
        background = dictionary["background"] as? String ?? ""
        worldSetting = dictionary["worldSetting"] as? String ?? ""
        likes = dictionary["likes"] as? String ?? ""
        dislikes = dictionary["dislikes"] as? String ?? ""
        behaviorRules = dictionary["behaviorRules"] as? String ?? ""
        exampleDialogues = dictionary["exampleDialogues"] as? String ?? ""
    }

    func toDictionary() -> [String: Any] {
        [
            "description": description,
            "background": background,
            "worldSetting": worldSetting,
            "likes": likes,
            "dislikes": dislikes,
            "behaviorRules": behaviorRules,
            "exampleDialogues": exampleDialogues
        ]
    }
}

/// system prompt に流し込むキャラクター像（Oshi + RoleplayProfile を統合したもの）
struct RoleplayCharacter: Equatable {
    var name: String
    var description: String = ""
    var personality: String = ""
    var speakingStyle: String = ""
    var background: String = ""
    var worldSetting: String = ""
    var relationshipWithUser: String = ""
    var likes: String = ""
    var dislikes: String = ""
    var behaviorRules: String = ""
    var exampleDialogues: String = ""
    /// キャラクターがユーザーを呼ぶ呼び方
    var userNickname: String = ""
    /// 口癖（speakingStyle にも含まれる）。使いすぎ防止の判定に使う
    var catchphrase: String = ""
    /// Saved Oshi preferences, available on every plan.
    var conversationAdjustments: [String: Int] = [:]
}

/// 1回の生成に必要なロールプレイ文脈
struct RoleplayContext {
    var character: RoleplayCharacter
    var situation: RoleplaySituation = RoleplaySituation()
    var relationship: RoleplayRelationship = RoleplayRelationship()
    /// prompt に入れる（選別済みの）記憶
    var memories: [RoleplayMemory] = []
    /// 直近N件より前の会話の要約
    var summary: String = ""
    var suppressHistoryBefore: TimeInterval = 0
    var excludedMessageIds: Set<String> = []
    var hasDeletedMemories = false
    /// "ja" / "en" など
    var language: String = "ja"
    /// 解放済みのコンテンツ（呼び方・関係設定・特別な会話など）
    var unlocked: [RelationshipUnlock] = []
    /// ユーザーが設定した特別な呼び方（custom の呼び方が解放されているときだけ使う）
    var specialNickname: String = ""
    /// これまでのステージアップ履歴（古い順）
    var relationshipEvents: [RelationshipEvent] = []
    var userPersona = RoleplayUserPersona()
    var innerThoughtsEnabled = true

    var replyLength: RoleplayReplyLength {
        RoleplayReplyLength(choice: character.conversationAdjustments["length"])
    }
}
