//
//  RelationshipProgression.swift
//  osimono
//
//  親密度による関係性の進行（ステージ判定・連投対策・アンロック・ステージアップイベント）。
//  Firebase / SwiftUI に依存しない（Foundationのみ）。調整用の数値は RelationshipTuning に集約する。
//

import Foundation

// MARK: - Tuning

/// 関係性の進行に関する調整値。数値を変えたいときはここだけを編集する。
enum RelationshipTuning {
    struct Requirement: Equatable {
        let affection: Int
        let trust: Int
    }

    /// 各ステージに上がるための条件（affection と trust の両方を満たす必要がある）
    static let stageRequirements: [RelationshipStage: Requirement] = [
        .stranger: Requirement(affection: 0, trust: 0),
        .acquaintance: Requirement(affection: 15, trust: 0),
        .close: Requirement(affection: 35, trust: 25),
        .special: Requirement(affection: 60, trust: 50),
        .lover: Requirement(affection: 80, trust: 70)
    ]

    /// 新しく会話を始めたキャラクターの初期値（既存ユーザーの保存済みの値はそのまま使う）
    static let initialAffection = 5
    static let initialTrust = 10

    /// 1回の更新で動かせる最大幅（-3〜+3）
    static let maxDeltaPerUpdate = 3
    /// 1日に動かせる最大幅（上昇・下降とも）
    static let maxDailyChange = 10
    /// 1時間あたりの最大上昇幅（短時間の連続会話で一気に上がらないように）
    static let maxHourlyGain = 4
    /// ステージアップの最短間隔。同じ日に何段も上がらないようにする
    static let minIntervalBetweenStageUps: TimeInterval = 20 * 60 * 60

    /// 連投判定で比較する直前のユーザー発言数
    static let repetitionLookback = 20
    /// これ以上似ている発言は「同じ発言」とみなす（文字bigramのJaccard係数）
    static let repetitionSimilarity = 0.8

    /// prompt に載せるステージアップ履歴の件数
    static let promptHistoryLimit = 3
    /// ユーザーが設定できる特別な呼び方の最大文字数
    static let maxNicknameLength = 20
    /// 次のステージに上がるまでは進捗バーを満タンにしない
    static let maxDisplayedProgress = 0.95

    /// affection をLLM向けの意味に変換する表（min 以上で該当。上から順に判定）
    static let affectionMeanings: [(min: Int, ja: String, en: String)] = [
        (80, "心から大切に想っていて、そばにいたいと感じている", "cherishes the user deeply and wants to be by their side"),
        (60, "ユーザーを特別な存在として意識している", "sees the user as someone special"),
        (35, "一緒に話すのが楽しく、自然に好意を感じている", "enjoys talking with the user and naturally feels fond of them"),
        (15, "少し気になり始めていて、会話を楽しみにしている", "is starting to take an interest and looks forward to talking"),
        (0, "まだ相手のことをよく知らず、様子を見ている", "doesn't know the user well yet and is feeling things out")
    ]

    /// trust をLLM向けの意味に変換する表
    static let trustMeanings: [(min: Int, ja: String, en: String)] = [
        (70, "深く信頼していて、安心して何でも話せる", "trusts the user deeply and can talk about anything"),
        (50, "信頼していて、弱い部分や本音を見せることが増えている", "trusts the user and increasingly shows weaknesses and true feelings"),
        (25, "少しずつ打ち解けて、気軽に話せるようになってきた", "is opening up and can talk casually"),
        (0, "本音はまだあまり見せない", "doesn't show true feelings much yet")
    ]

    static func meaning(of value: Int, in table: [(min: Int, ja: String, en: String)], language: String) -> String {
        let row = table.first { value >= $0.min } ?? table[table.count - 1]
        return language == "ja" ? row.ja : row.en
    }
}

// MARK: - Stage

/// 関係ステージ。保存値（rawValue）は "stranger" などの文字列。
enum RelationshipStage: String, CaseIterable, Comparable {
    case stranger, acquaintance, close, special, lover

    init(rawOrStranger raw: String?) {
        self = raw.flatMap(RelationshipStage.init(rawValue:)) ?? .stranger
    }

    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: RelationshipStage, rhs: RelationshipStage) -> Bool {
        lhs.order < rhs.order
    }

    var next: RelationshipStage? {
        let all = Self.allCases
        return order + 1 < all.count ? all[order + 1] : nil
    }

    var requirement: RelationshipTuning.Requirement {
        RelationshipTuning.stageRequirements[self] ?? RelationshipTuning.Requirement(affection: 0, trust: 0)
    }

    /// 数値の条件を満たしている最も高いステージ
    static func qualified(affection: Int, trust: Int) -> RelationshipStage {
        allCases.last { affection >= $0.requirement.affection && trust >= $0.requirement.trust } ?? .stranger
    }

    func label(language: String) -> String {
        let ja = language == "ja"
        switch self {
        case .stranger: return ja ? "知り合い" : "Acquaintance"
        case .acquaintance: return ja ? "少し気になる" : "A little curious"
        case .close: return ja ? "親しい" : "Close"
        case .special: return ja ? "特別な存在" : "Someone special"
        case .lover: return ja ? "恋人" : "Lovers"
        }
    }

    /// LLMへ渡す距離感の目安（セリフは固定しない）
    func toneGuidance(language: String) -> String {
        let ja = language == "ja"
        switch self {
        case .stranger:
            return ja ? "まだ少し距離がある。踏み込みすぎず、相手の様子をうかがっている。"
                : "There is still some distance. Don't get too personal; you're still reading the user."
        case .acquaintance:
            return ja ? "打ち解け始めている。ときどき素の反応や小さな好意がのぞく。"
                : "Starting to open up. Your natural reactions and small signs of fondness sometimes show."
        case .close:
            return ja ? "自然に親しみを見せる。気軽に冗談を言ったり、相手のことを気にかけたりする。"
                : "Naturally friendly. You joke casually and look out for the user."
        case .special:
            return ja ? "ユーザーを特別に意識している。弱い部分や本音を少し見せることがある。"
                : "You're conscious of the user as someone special and sometimes show a bit of your vulnerable side and true feelings."
        case .lover:
            return ja ? "恋人として自然な距離感。性格の範囲で、好意を素直に表せる。"
                : "A natural lover's closeness. Within your personality, you can express affection honestly."
        }
    }
}

// MARK: - Repetition filter

/// 同じ・よく似た発言の繰り返しで親密度が上がらないようにするための判定
enum RelationshipRepetitionFilter {
    /// 記号・空白・絵文字・長音を除いて比較用に正規化する（"好き！！" と "好きー" は同じ）
    static func normalize(_ text: String) -> String {
        String(text.lowercased().filter { ($0.isLetter || $0.isNumber) && !"ーｰ〜~".contains($0) })
    }

    static func isSimilar(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard lhs.count >= 2, rhs.count >= 2 else { return false }
        let a = bigrams(lhs), b = bigrams(rhs)
        let union = a.union(b).count
        guard union > 0 else { return false }
        return Double(a.intersection(b).count) / Double(union) >= RelationshipTuning.repetitionSimilarity
    }

    private static func bigrams(_ text: String) -> Set<String> {
        let chars = Array(text)
        guard chars.count >= 2 else { return [String(chars)] }
        return Set((0..<(chars.count - 1)).map { String(chars[$0...$0 + 1]) })
    }

    /// 評価対象のユーザー発言のうち、直前の発言や同じ範囲の発言と重複しない「中身のある」発言の数。
    /// 0 のときは上昇させない（下降は通常どおり）。ユーザーには何も表示しない。
    static func substantiveTurns(pending: [String], previous: [String]) -> Int {
        var seen = previous.suffix(RelationshipTuning.repetitionLookback).map(normalize).filter { !$0.isEmpty }
        var count = 0
        for text in pending {
            let normalized = normalize(text)
            guard !normalized.isEmpty, !seen.contains(where: { isSimilar($0, normalized) }) else { continue }
            count += 1
            seen.append(normalized)
        }
        return count
    }
}

// MARK: - Unlock

enum RelationshipUnlockType: String, CaseIterable {
    case nickname
    case photo
    case relationshipSetting = "relationship_setting"
    case specialMessage = "special_message"
    case scenario
}

/// nickname アンロックの contentId
enum RelationshipNicknameStyle: String {
    /// 基本の呼び方を少しくだけた形にしてよい（〇〇さん → 〇〇）
    case casual
    /// ユーザーが設定した特別な呼び方を使ってよい
    case custom
}

/// photo アンロックの画像の参照先
enum RelationshipPhotoSource: Equatable {
    case remote(URL)
    case asset(String)
}

/// アンロックできるコンテンツの定義。Relationshipロジックには埋め込まず、データとして管理する
/// （既定は RelationshipUnlockCatalog.defaults、Firebase の relationshipUnlockCatalog で追加・上書きできる）
struct RelationshipUnlock: Identifiable, Equatable {
    /// characterId がこの値なら全キャラクター共通
    static let allCharacters = "*"

    let id: String
    var characterId: String = RelationshipUnlock.allCharacters
    var type: RelationshipUnlockType
    var requiredStage: RelationshipStage
    var requiredAffection: Int = 0
    var requiredTrust: Int = 0
    /// 種類ごとの中身の参照（nickname: casual/custom、photo: 画像URL・"asset:名前"・"oshi:image" など）
    var contentId: String
    /// 表示名（Localizable のキー、またはそのまま表示する文字列）
    var title: String
    var description: String = ""
    /// 種類ごとの追加データ（scenario: location/time/situation、special_message: hint、relationship_setting: label）
    var payload: [String: String] = [:]
    /// 同じステージ内の並び順
    var order: Int = 0

    init(id: String, characterId: String = RelationshipUnlock.allCharacters, type: RelationshipUnlockType, requiredStage: RelationshipStage,
         requiredAffection: Int = 0, requiredTrust: Int = 0, contentId: String, title: String, description: String = "",
         payload: [String: String] = [:], order: Int = 0) {
        self.id = id
        self.characterId = characterId
        self.type = type
        self.requiredStage = requiredStage
        self.requiredAffection = requiredAffection
        self.requiredTrust = requiredTrust
        self.contentId = contentId
        self.title = title
        self.description = description
        self.payload = payload
        self.order = order
    }

    init?(id: String, dictionary: [String: Any]) {
        guard let type = (dictionary["type"] as? String).flatMap(RelationshipUnlockType.init(rawValue:)),
              let stage = (dictionary["requiredStage"] as? String).flatMap(RelationshipStage.init(rawValue:)),
              let contentId = dictionary["contentId"] as? String,
              let title = dictionary["title"] as? String else {
            return nil
        }
        self.init(
            id: dictionary["id"] as? String ?? id,
            characterId: dictionary["characterId"] as? String ?? RelationshipUnlock.allCharacters,
            type: type,
            requiredStage: stage,
            requiredAffection: dictionary["requiredAffection"] as? Int ?? 0,
            requiredTrust: dictionary["requiredTrust"] as? Int ?? 0,
            contentId: contentId,
            title: title,
            description: dictionary["description"] as? String ?? "",
            payload: dictionary["payload"] as? [String: String] ?? [:],
            order: dictionary["order"] as? Int ?? 0
        )
    }

    func applies(to characterId: String) -> Bool {
        self.characterId == RelationshipUnlock.allCharacters || self.characterId == characterId
    }

    func isEligible(for relationship: RoleplayRelationship) -> Bool {
        relationship.stage >= requiredStage && relationship.affection >= requiredAffection && relationship.trust >= requiredTrust
    }

    var localizedTitle: String { Self.localized(title) }
    var localizedDescription: String { Self.localized(description) }
    /// language を指定すると、その言語の Localizable から引く（prompt は会話言語に合わせる）
    func localizedPayload(_ key: String, language: String? = nil) -> String { Self.localized(payload[key] ?? "", language: language) }

    var nicknameStyle: RelationshipNicknameStyle? {
        type == .nickname ? RelationshipNicknameStyle(rawValue: contentId) : nil
    }

    var scenario: RoleplaySituation? {
        guard type == .scenario else { return nil }
        return RoleplaySituation(location: localizedPayload("location"), time: localizedPayload("time"), situation: localizedPayload("situation"))
    }

    /// 写真の参照先。"oshi:image" / "oshi:background" は推しに登録済みの画像を使う
    func photoSource(oshiImageUrl: String?, oshiBackgroundImageUrl: String?) -> RelationshipPhotoSource? {
        guard type == .photo else { return nil }
        let reference: String?
        switch contentId {
        case "oshi:image": reference = oshiImageUrl
        case "oshi:background": reference = oshiBackgroundImageUrl
        default: reference = contentId
        }
        guard let reference = reference?.trimmingCharacters(in: .whitespacesAndNewlines), !reference.isEmpty else { return nil }
        if reference.hasPrefix("asset:") {
            let name = String(reference.dropFirst("asset:".count))
            return name.isEmpty ? nil : .asset(name)
        }
        guard reference.hasPrefix("https://") || reference.hasPrefix("http://"), let url = URL(string: reference) else { return nil }
        return .remote(url)
    }

    /// Localizable にキーがあれば翻訳を、なければそのままの文字列を返す（管理画面で直接書いた文言用）
    static func localized(_ key: String, language: String? = nil) -> String {
        guard !key.isEmpty else { return "" }
        let bundle = language
            .flatMap { Bundle.main.path(forResource: $0, ofType: "lproj") }
            .flatMap(Bundle.init(path:)) ?? Bundle.main
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

/// 解放済みコンテンツ（userId × characterId 単位で保存）
struct UnlockedContent: Equatable {
    let userId: String
    let characterId: String
    let unlockId: String
    let unlockedAt: TimeInterval

    init(userId: String, characterId: String, unlockId: String, unlockedAt: TimeInterval = Date().timeIntervalSince1970) {
        self.userId = userId
        self.characterId = characterId
        self.unlockId = unlockId
        self.unlockedAt = unlockedAt
    }

    init?(dictionary: [String: Any]) {
        guard let userId = dictionary["userId"] as? String,
              let characterId = dictionary["characterId"] as? String,
              let unlockId = dictionary["unlockId"] as? String else {
            return nil
        }
        self.init(userId: userId, characterId: characterId, unlockId: unlockId, unlockedAt: dictionary["unlockedAt"] as? TimeInterval ?? 0)
    }

    func toDictionary() -> [String: Any] {
        ["userId": userId, "characterId": characterId, "unlockId": unlockId, "unlockedAt": unlockedAt]
    }
}

// MARK: - Event

/// 関係性のイベント。ステージアップしたときだけ記録する（1ステージにつき1件）
struct RelationshipEvent: Identifiable, Equatable {
    enum EventType: String {
        case stageUp = "stage_up"
    }

    let id: String
    let type: EventType
    let from: RelationshipStage
    let to: RelationshipStage
    let createdAt: TimeInterval
    /// このステージアップで解放されたコンテンツ
    var unlockIds: [String] = []
    /// チャット上で演出・キャラクターの反応を出したか（複数端末で二重に出さないため）
    var announced: Bool = false

    /// ステージは下がらないので、到達したステージごとに1件。同じIDで書けば二重に記録されない
    static func stageUpId(to stage: RelationshipStage) -> String {
        "stage_up_\(stage.rawValue)"
    }

    init(from: RelationshipStage, to: RelationshipStage, createdAt: TimeInterval = Date().timeIntervalSince1970, unlockIds: [String] = [], announced: Bool = false) {
        self.id = Self.stageUpId(to: to)
        self.type = .stageUp
        self.from = from
        self.to = to
        self.createdAt = createdAt
        self.unlockIds = unlockIds
        self.announced = announced
    }

    init?(id: String, dictionary: [String: Any]) {
        guard let type = (dictionary["type"] as? String).flatMap(EventType.init(rawValue:)),
              let from = (dictionary["from"] as? String).flatMap(RelationshipStage.init(rawValue:)),
              let to = (dictionary["to"] as? String).flatMap(RelationshipStage.init(rawValue:)) else {
            return nil
        }
        self.id = id
        self.type = type
        self.from = from
        self.to = to
        self.createdAt = dictionary["createdAt"] as? TimeInterval ?? 0
        self.unlockIds = dictionary["unlockIds"] as? [String] ?? []
        self.announced = dictionary["announced"] as? Bool ?? false
    }

    func toDictionary() -> [String: Any] {
        [
            "type": type.rawValue,
            "from": from.rawValue,
            "to": to.rawValue,
            "createdAt": createdAt,
            "unlockIds": unlockIds,
            "announced": announced
        ]
    }
}

// MARK: - Evaluation

enum RelationshipUnlockEvaluator {
    /// このキャラクターに適用されるカタログ。キャラクター専用の定義は同じIDの共通定義を上書きする
    static func catalog(_ entries: [RelationshipUnlock], for characterId: String) -> [RelationshipUnlock] {
        var byId: [String: RelationshipUnlock] = [:]
        for entry in entries where entry.applies(to: characterId) {
            if let existing = byId[entry.id], existing.characterId != RelationshipUnlock.allCharacters, entry.characterId == RelationshipUnlock.allCharacters {
                continue
            }
            byId[entry.id] = entry
        }
        return byId.values.sorted { ($0.requiredStage.order, $0.order, $0.id) < ($1.requiredStage.order, $1.order, $1.id) }
    }

    /// 条件を満たしていて、まだ解放していないもの
    static func newlyEligible(catalog: [RelationshipUnlock], relationship: RoleplayRelationship, unlockedIds: Set<String>) -> [RelationshipUnlock] {
        catalog.filter { !unlockedIds.contains($0.id) && $0.isEligible(for: relationship) }
    }

    /// 解放済みレコードをカタログの定義に解決する（userId / characterId が違うレコードは無視する）
    static func unlockedEntries(catalog: [RelationshipUnlock], unlocked: [UnlockedContent], userId: String, characterId: String) -> [RelationshipUnlock] {
        let ids = Set(unlocked.filter { $0.userId == userId && $0.characterId == characterId }.map(\.unlockId))
        return catalog.filter { ids.contains($0.id) }
    }

    /// 現在有効な呼び方（custom は呼び方が設定されている場合のみ）
    static func nicknameStyle(unlocked: [RelationshipUnlock], specialNickname: String) -> RelationshipNicknameStyle? {
        let styles = Set(unlocked.compactMap(\.nicknameStyle))
        if styles.contains(.custom), !specialNickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .custom
        }
        return styles.contains(.casual) || styles.contains(.custom) ? .casual : nil
    }

    static func sanitizeNickname(_ text: String) -> String {
        let singleLine = text.components(separatedBy: .newlines).joined(separator: " ")
        return String(singleLine.trimmingCharacters(in: .whitespacesAndNewlines).prefix(RelationshipTuning.maxNicknameLength))
    }
}
