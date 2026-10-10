//
//  RoleplayRepository.swift
//  osimono
//
//  ロールプレイ関連データの永続化（Firebase Realtime Database）
//
//  roleplay/{userId}/{oshiId}/
//      profile       : RoleplayProfile（追加キャラクター設定）
//      situation     : RoleplaySituation
//      relationship  : RoleplayRelationship
//      summary       : String（直近N件より前の会話要約）
//      summarizedUntil : TimeInterval（要約・記憶抽出に取り込み済みの最後のメッセージ時刻）
//      memories/{id} : RoleplayMemory
//      unlocks/{unlockId}          : UnlockedContent（解放済みコンテンツ。キーが unlockId なので二重に解放されない）
//      relationshipEvents/{eventId}: RelationshipEvent（stage_up。eventId は到達ステージごとに1つ）
//      specialNickname             : String（ユーザーが設定した特別な呼び方）
//
//  relationshipUnlockCatalog/{default | oshiId}/{unlockId} : RelationshipUnlock（管理側で編集するカタログ。読み取りのみ）
//
//  userId / oshiId でパスを分けているので、別ユーザー・別キャラの記憶・関係性・解放状況は混ざらない。
//

import Foundation
import FirebaseDatabase
import FirebaseAuth

/// Firebaseから読み込んだロールプレイ状態
struct RoleplayState {
    var profile = RoleplayProfile()
    var situation = RoleplaySituation()
    var relationship: RoleplayRelationship?
    var summary = ""
    /// 要約・記憶抽出に取り込み済みの最後のメッセージ時刻。これより後の会話が次回の抽出対象
    var summarizedUntil: TimeInterval = 0
    var memories: [RoleplayMemory] = []
    var userId = ""
    var memoryRevision = 0
    var summarizedBoundaryIds: Set<String> = []
    var extractionMessageId = ""
    var extractionOffset = 0
    var suppressHistoryBefore: TimeInterval = 0
    var hasDeletedMemories = false
    /// このキャラクターに適用されるアンロック定義（既定 + Firebase のカタログ）
    var catalog: [RelationshipUnlock] = RelationshipUnlockCatalog.defaults
    var unlocked: [UnlockedContent] = []
    var events: [RelationshipEvent] = []
    var specialNickname = ""
    var userPersona = RoleplayUserPersona()
    var innerThoughtsEnabled = true
    var personaUpdatedAt: TimeInterval = 0

    var contextHistoryStart: TimeInterval { max(suppressHistoryBefore, personaUpdatedAt) }
    var contextMemories: [RoleplayMemory] {
        memories.filter { (personaUpdatedAt == 0 || $0.sourceTimestamp > personaUpdatedAt)
            && (!userPersona.isActive || $0.domain == "roleplay") }
    }

    /// 解放済みのコンテンツ（カタログの定義に解決済み）
    func unlockedEntries(userId: String, characterId: String) -> [RelationshipUnlock] {
        RelationshipUnlockEvaluator.unlockedEntries(catalog: catalog, unlocked: unlocked, userId: userId, characterId: characterId)
    }
}

/// 関係性の更新結果（トランザクションで確定した前後の値）
struct RelationshipUpdateOutcome {
    let before: RoleplayRelationship
    let after: RoleplayRelationship

    var stageUp: (from: RelationshipStage, to: RelationshipStage)? {
        after.stage > before.stage ? (before.stage, after.stage) : nil
    }
}

final class RoleplayRepository {
    static let shared = RoleplayRepository()
    /// 保持する記憶の上限（超えたら重要度の低い古いものから削除）。プレミアムは多く覚えていられる
    static var maxStoredMemories: Int { PremiumFeatures.maxStoredMemories() }

    private let database = Database.database().reference()

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    /// 管理側のカタログを読み直す間隔
    private static let catalogCacheLifetime: TimeInterval = 10 * 60
    private var catalogCache: [String: (entries: [RelationshipUnlock], fetchedAt: Date)] = [:]
    private let catalogLock = NSLock()

    /// ユーザー × キャラクターのデータの置き場所。記憶・関係性・解放状況はすべてこの下にある
    static func rootPath(userId: String, oshiId: String) -> String {
        "roleplay/\(userId)/\(oshiId)"
    }

    private func rootRef(userId: String, oshiId: String) -> DatabaseReference {
        database.child(Self.rootPath(userId: userId, oshiId: oshiId))
    }

    private func authError() -> NSError {
        NSError(domain: "RoleplayRepository", code: 401, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"])
    }

    // MARK: - Read

    func fetchState(oshiId: String, completion: @escaping (RoleplayState) -> Void) {
        guard let userId = currentUserId, !oshiId.isEmpty else {
            completion(RoleplayState())
            return
        }

        rootRef(userId: userId, oshiId: oshiId).observeSingleEvent(of: .value, with: { snapshot in
            let value = snapshot.value as? [String: Any] ?? [:]
            var state = RoleplayState()
            guard self.currentUserId == userId else { completion(RoleplayState()); return }
            state.userId = userId
            state.memoryRevision = value["memoryRevision"] as? Int ?? 0
            state.summarizedBoundaryIds = Set(value["summarizedBoundaryIds"] as? [String] ?? [])
            state.extractionMessageId = value["extractionMessageId"] as? String ?? ""
            state.extractionOffset = value["extractionOffset"] as? Int ?? 0
            state.suppressHistoryBefore = value["suppressHistoryBefore"] as? TimeInterval ?? 0
            state.hasDeletedMemories = value["hasDeletedMemories"] as? Bool ?? false
            state.profile = RoleplayProfile(dictionary: value["profile"] as? [String: Any] ?? [:])
            state.userPersona = RoleplayUserPersona(dictionary: value["userPersona"] as? [String: Any] ?? [:])
            state.innerThoughtsEnabled = value["innerThoughtsEnabled"] as? Bool ?? true
            state.personaUpdatedAt = value["personaUpdatedAt"] as? TimeInterval ?? 0
            state.situation = RoleplaySituation(dictionary: value["situation"] as? [String: Any] ?? [:])
            if let relationship = value["relationship"] as? [String: Any] {
                state.relationship = RoleplayRelationship(dictionary: relationship)
            }
            state.summary = value["summary"] as? String ?? ""
            state.summarizedUntil = value["summarizedUntil"] as? TimeInterval ?? 0
            let memoryDicts = value["memories"] as? [String: Any] ?? [:]
            state.memories = memoryDicts.values
                .compactMap { ($0 as? [String: Any]).flatMap(RoleplayMemory.init(dictionary:)) }
                // パスでスコープ済みだが、念のためレコード側のIDでも分離を保証する
                .filter { $0.userId == userId && $0.characterId == oshiId }
                .sorted { $0.createdAt < $1.createdAt }
            state.unlocked = (value["unlocks"] as? [String: Any] ?? [:]).values
                .compactMap { ($0 as? [String: Any]).flatMap(UnlockedContent.init(dictionary:)) }
                .filter { $0.userId == userId && $0.characterId == oshiId }
                .sorted { $0.unlockedAt < $1.unlockedAt }
            state.events = Self.parseEvents(value["relationshipEvents"])
            state.specialNickname = value["specialNickname"] as? String ?? ""
            self.fetchCatalog(oshiId: oshiId) { catalog in
                state.catalog = catalog
                completion(self.currentUserId == userId ? state : RoleplayState())
            }
        }, withCancel: { error in
            print("❌ ロールプレイ状態の取得に失敗: \(error.localizedDescription)")
            completion(RoleplayState())
        })
    }

    static func parseEvents(_ value: Any?) -> [RelationshipEvent] {
        (value as? [String: Any] ?? [:])
            .compactMap { key, dict in (dict as? [String: Any]).flatMap { RelationshipEvent(id: key, dictionary: $0) } }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 既定のカタログに Firebase のカタログ（全キャラ共通の default と、このキャラ専用）を重ねたもの。
    /// 読み取れない場合（未設定・権限なし・オフライン）は既定のカタログだけを使う。
    func fetchCatalog(oshiId: String, completion: @escaping ([RelationshipUnlock]) -> Void) {
        catalogLock.lock()
        let cached = catalogCache[oshiId]
        catalogLock.unlock()
        if let cached = cached, Date().timeIntervalSince(cached.fetchedAt) < Self.catalogCacheLifetime {
            completion(cached.entries)
            return
        }

        let catalogRef = database.child("relationshipUnlockCatalog")
        var remote: [RelationshipUnlock] = []
        let group = DispatchGroup()
        let lock = NSLock()
        for scope in ["default", oshiId] {
            group.enter()
            catalogRef.child(scope).observeSingleEvent(of: .value, with: { snapshot in
                let entries = (snapshot.value as? [String: Any] ?? [:]).compactMap { key, dict -> RelationshipUnlock? in
                    guard var entry = (dict as? [String: Any]).flatMap({ RelationshipUnlock(id: key, dictionary: $0) }) else { return nil }
                    if scope != "default" { entry.characterId = oshiId }
                    return entry
                }
                lock.lock(); remote += entries; lock.unlock()
                group.leave()
            }, withCancel: { _ in
                group.leave()
            })
        }
        group.notify(queue: .global()) {
            // 既定 → Firebase(default) → Firebase(キャラ専用) の順に、同じIDは後のものが優先
            var byId: [String: RelationshipUnlock] = [:]
            for entry in RelationshipUnlockCatalog.defaults { byId[entry.id] = entry }
            for entry in remote where entry.characterId == RelationshipUnlock.allCharacters { byId[entry.id] = entry }
            for entry in remote where entry.characterId != RelationshipUnlock.allCharacters { byId[entry.id] = entry }
            let merged = RelationshipUnlockEvaluator.catalog(Array(byId.values), for: oshiId)
            self.catalogLock.lock()
            self.catalogCache[oshiId] = (merged, Date())
            self.catalogLock.unlock()
            completion(merged)
        }
    }

    // MARK: - Observe

    /// 関係性の変化を監視する（チャット画面のヘッダー表示用）
    func observeRelationship(oshiId: String, onChange: @escaping (RoleplayRelationship?) -> Void) -> DatabaseHandle? {
        guard let userId = currentUserId, !oshiId.isEmpty else { return nil }
        return rootRef(userId: userId, oshiId: oshiId).child("relationship").observe(.value) { snapshot in
            onChange((snapshot.value as? [String: Any]).map(RoleplayRelationship.init(dictionary:)))
        }
    }

    /// ステージアップイベントの追加・変更を監視する（チャット上の演出用）
    func observeEvents(oshiId: String, onChange: @escaping ([RelationshipEvent]) -> Void) -> DatabaseHandle? {
        guard let userId = currentUserId, !oshiId.isEmpty else { return nil }
        return rootRef(userId: userId, oshiId: oshiId).child("relationshipEvents").observe(.value) { snapshot in
            onChange(Self.parseEvents(snapshot.value))
        }
    }

    func removeObserver(_ handle: DatabaseHandle, oshiId: String, path: String) {
        guard let userId = currentUserId, !oshiId.isEmpty else { return }
        rootRef(userId: userId, oshiId: oshiId).child(path).removeObserver(withHandle: handle)
    }

    // MARK: - Write

    /// Acknowledged, atomic settings save. A stale editor cannot overwrite another device's changes.
    func saveSettings(oshiId: String, expected: RoleplayState, persona: RoleplayUserPersona,
                      innerThoughtsEnabled: Bool, profile: RoleplayProfile?, situation: RoleplaySituation?,
                      completion: @escaping (Error?) -> Void) {
        guard let userId = currentUserId, userId == expected.userId, !oshiId.isEmpty else {
            completion(authError()); return
        }
        let root = rootRef(userId: userId, oshiId: oshiId)
        let personaChanged = persona.normalized != expected.userPersona.normalized
        let thoughtsChanged = innerThoughtsEnabled != expected.innerThoughtsEnabled
        let now = Date().timeIntervalSince1970
        root.getData { error, snapshot in
            if let error { completion(error); return }
            guard self.currentUserId == userId else { completion(self.authError()); return }
            let existedOnServer = snapshot?.exists() == true
            root.runTransactionBlock({ data in
                guard self.currentUserId == userId else { return TransactionResult.abort() }
                if existedOnServer, data.value == nil || data.value is NSNull {
                    // Ask Firebase to retry against the server instead of treating a cold cache as a conflict.
                    return TransactionResult.success(withValue: data)
                }
                let value = data.value as? [String: Any] ?? [:]
                let currentPersona = RoleplayUserPersona(dictionary: value["userPersona"] as? [String: Any] ?? [:])
                let currentThoughts = value["innerThoughtsEnabled"] as? Bool ?? true
                guard !personaChanged || currentPersona == expected.userPersona,
                      !thoughtsChanged || currentThoughts == expected.innerThoughtsEnabled,
                      profile == nil || RoleplayProfile(dictionary: value["profile"] as? [String: Any] ?? [:]) == expected.profile,
                      situation == nil || RoleplaySituation(dictionary: value["situation"] as? [String: Any] ?? [:]) == expected.situation else {
                    return TransactionResult.abort()
                }
                data.value = RoleplaySettingsMutation.apply(to: value,
                    persona: personaChanged ? persona : currentPersona,
                    innerThoughtsEnabled: thoughtsChanged ? innerThoughtsEnabled : currentThoughts,
                    profile: profile, situation: situation, now: now)
                return TransactionResult.success(withValue: data)
            }, andCompletionBlock: { error, committed, snapshot in
                guard self.currentUserId == userId else { completion(self.authError()); return }
                if let error { completion(error); return }
                let saved = snapshot?.value as? [String: Any] ?? [:]
                let verified = committed && !saved.isEmpty
                    && (!personaChanged || RoleplayUserPersona(dictionary: saved["userPersona"] as? [String: Any] ?? [:]) == persona.normalized)
                    && (!thoughtsChanged || saved["innerThoughtsEnabled"] as? Bool == innerThoughtsEnabled)
                    && (profile == nil || RoleplayProfile(dictionary: saved["profile"] as? [String: Any] ?? [:]) == profile)
                    && (situation == nil || RoleplaySituation(dictionary: saved["situation"] as? [String: Any] ?? [:]) == situation)
                completion(verified ? nil : NSError(domain: "RoleplaySettings", code: 409,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("roleplay_settings_conflict", comment: "Settings changed elsewhere")]))
            }, withLocalEvents: false)
        }
    }

    func saveProfile(_ profile: RoleplayProfile, oshiId: String, completion: ((Error?) -> Void)? = nil) {
        setValue(profile.toDictionary(), path: "profile", oshiId: oshiId, completion: completion)
    }

    func saveSituation(_ situation: RoleplaySituation, oshiId: String, completion: ((Error?) -> Void)? = nil) {
        setValue(situation.toDictionary(), path: "situation", oshiId: oshiId, completion: completion)
    }

    /// 記憶・要約・取り込み位置を、同じスコープのFirebaseトランザクションでまとめて保存する。
    /// 途中で失敗しても「記憶だけ保存されて要約は古いまま」のような中途半端な状態にならない。
    func commitExtraction(result: RoleplayPromptBuilder.ExtractionResult, pending: [ChatMessage], state: RoleplayState, oshiId: String, partialMessageId: String = "", partialOffset: Int = 0, completion: @escaping (Error?) -> Void) {
        let userId = state.userId
        guard !userId.isEmpty, currentUserId == userId else { completion(authError()); return }
        let capacity = Self.maxStoredMemories
        // CAS on cursor and deletion revision: retries cannot duplicate records or resurrect deleted data.
        rootRef(userId: userId, oshiId: oshiId).runTransactionBlock({ data in
            guard self.currentUserId == userId,
                  let root = RoleplayMemoryEngine.commit(root: data.value as? [String: Any] ?? [:], result: result,
                      pending: pending, expected: state, userId: userId, characterId: oshiId, capacity: capacity, partialMessageId: partialMessageId, partialOffset: partialOffset) else {
                return TransactionResult.abort()
            }
            data.value = root
            return TransactionResult.success(withValue: data)
        }, andCompletionBlock: { error, committed, _ in
            completion(error ?? (committed ? nil : NSError(domain: "RoleplayRepository", code: 409,
                userInfo: [NSLocalizedDescriptionKey: "Memory state changed; retry from the persisted cursor."])))
        }, withLocalEvents: false)
    }

    /// 親密度・信頼度の変化をトランザクションで適用する（別端末や同時リクエストで古い値を元に上書きし合わないように）。
    /// completion には確定した前後の値を返す（失敗時は nil）。
    func applyRelationshipDelta(affectionDelta: Int, trustDelta: Int, userTurns: Int, substantiveTurns: Int, dayKey: String, hourKey: String, oshiId: String, completion: ((RelationshipUpdateOutcome?) -> Void)? = nil) {
        guard let userId = currentUserId, !oshiId.isEmpty else {
            completion?(nil)
            return
        }
        // トランザクションのブロックは競合時に最新の値で再実行される。最後に実行されたときの「前の値」が確定した値に対応する
        var lastBefore: RoleplayRelationship?
        rootRef(userId: userId, oshiId: oshiId).child("relationship").runTransactionBlock({ data in
            let current = (data.value as? [String: Any]).map(RoleplayRelationship.init(dictionary:)) ?? RoleplayRelationship()
            lastBefore = current
            let updated = current.applying(
                affectionDelta: affectionDelta, trustDelta: trustDelta,
                userTurns: userTurns, substantiveTurns: substantiveTurns,
                dayKey: dayKey, hourKey: hourKey
            )
            data.value = updated.toDictionary()
            return .success(withValue: data)
        }, andCompletionBlock: { error, committed, snapshot in
            if let error = error {
                print("❌ 関係性の更新に失敗: \(error.localizedDescription)")
            }
            guard committed, let before = lastBefore, let dict = snapshot?.value as? [String: Any] else {
                completion?(nil)
                return
            }
            completion?(RelationshipUpdateOutcome(before: before, after: RoleplayRelationship(dictionary: dict)))
        })
    }

    /// 関係性の更新後に、条件を満たしたコンテンツを解放し、ステージアップしていればイベントを記録する。
    /// 解放は unlocks/{unlockId} が無いときだけ書き込むトランザクションなので、同じコンテンツが2回解放されることはない。
    func processRelationshipUpdate(_ outcome: RelationshipUpdateOutcome, oshiId: String, completion: ((RelationshipEvent?) -> Void)? = nil) {
        guard let userId = currentUserId, !oshiId.isEmpty else {
            completion?(nil)
            return
        }
        let root = rootRef(userId: userId, oshiId: oshiId)

        root.child("unlocks").observeSingleEvent(of: .value, with: { snapshot in
            let known = Set((snapshot.value as? [String: Any] ?? [:]).keys)
            self.fetchCatalog(oshiId: oshiId) { catalog in
                let eligible = RelationshipUnlockEvaluator.newlyEligible(catalog: catalog, relationship: outcome.after, unlockedIds: known)
                var granted: [String] = []
                let lock = NSLock()
                let group = DispatchGroup()
                for entry in eligible {
                    group.enter()
                    let record = UnlockedContent(userId: userId, characterId: oshiId, unlockId: entry.id)
                    root.child("unlocks").child(entry.id).runTransactionBlock({ data in
                        guard data.value == nil || data.value is NSNull else { return .abort() }
                        data.value = record.toDictionary()
                        return .success(withValue: data)
                    }, andCompletionBlock: { _, committed, _ in
                        if committed {
                            lock.lock(); granted.append(entry.id); lock.unlock()
                        }
                        group.leave()
                    })
                }
                group.notify(queue: .global()) {
                    guard let stageUp = outcome.stageUp else {
                        completion?(nil)
                        return
                    }
                    self.recordStageUp(from: stageUp.from, to: stageUp.to, unlockIds: granted, root: root, completion: completion)
                }
            }
        }, withCancel: { _ in
            completion?(nil)
        })
    }

    private func recordStageUp(from: RelationshipStage, to: RelationshipStage, unlockIds: [String], root: DatabaseReference, completion: ((RelationshipEvent?) -> Void)?) {
        let event = RelationshipEvent(from: from, to: to, unlockIds: unlockIds)
        // 同じステージのイベントが既にあれば書き込まない（announced を上書きして演出を二重に出さないため）
        root.child("relationshipEvents").child(event.id).runTransactionBlock({ data in
            guard data.value == nil || data.value is NSNull else { return .abort() }
            data.value = event.toDictionary()
            return .success(withValue: data)
        }, andCompletionBlock: { error, committed, _ in
            if let error = error {
                print("❌ ステージアップの記録に失敗: \(error.localizedDescription)")
            }
            if committed {
                print("💗 関係ステージが変化: \(from.rawValue) → \(to.rawValue) 解放: \(unlockIds)")
            }
            completion?(committed ? event : nil)
        })
    }

    /// ステージアップの演出を出す権利を取る。複数端末・複数画面で同じイベントの演出を二重に出さないためのトランザクション
    func claimEventAnnouncement(_ event: RelationshipEvent, oshiId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUserId, !oshiId.isEmpty else {
            completion(false)
            return
        }
        rootRef(userId: userId, oshiId: oshiId).child("relationshipEvents").child(event.id).child("announced").runTransactionBlock({ data in
            if (data.value as? Bool) == true { return .abort() }
            data.value = true
            return .success(withValue: data)
        }, andCompletionBlock: { _, committed, _ in
            completion(committed)
        })
    }

    /// 演出を出さずに既読扱いにする（未表示のイベントが複数たまっていたときの古い方）
    func markEventAnnounced(_ event: RelationshipEvent, oshiId: String) {
        setValue(true, path: "relationshipEvents/\(event.id)/announced", oshiId: oshiId, completion: nil)
    }

    func saveSpecialNickname(_ nickname: String, oshiId: String, completion: ((Error?) -> Void)? = nil) {
        setValue(RelationshipUnlockEvaluator.sanitizeNickname(nickname), path: "specialNickname", oshiId: oshiId, completion: completion)
    }

    func deleteMemory(_ memory: RoleplayMemory, completion: ((Error?) -> Void)? = nil) {
        guard let userId = currentUserId, memory.userId == userId else {
            completion?(authError())
            return
        }
        let now = Date().timeIntervalSince1970
        rootRef(userId: userId, oshiId: memory.characterId).runTransactionBlock({ data in
            guard self.currentUserId == userId else { return TransactionResult.abort() }
            data.value = RoleplayMemoryEngine.deleting(memory, root: data.value as? [String: Any] ?? [:], now: now)
            return TransactionResult.success(withValue: data)
        }, andCompletionBlock: { error, committed, _ in
            completion?(error ?? (committed ? nil : self.authError()))
        }, withLocalEvents: false)
    }

    private func setValue(_ value: Any, path: String, oshiId: String, completion: ((Error?) -> Void)?) {
        guard let userId = currentUserId, !oshiId.isEmpty else {
            completion?(authError())
            return
        }
        rootRef(userId: userId, oshiId: oshiId).child(path).setValue(value) { error, _ in
            if let error = error {
                print("❌ ロールプレイ \(path) の保存に失敗: \(error.localizedDescription)")
            }
            completion?(error)
        }
    }
}

// MARK: - Oshi → RoleplayCharacter

extension RoleplayCharacter {
    /// 既存の推し設定（Oshi）とロールプレイ追加設定（RoleplayProfile）を統合する
    init(oshi: Oshi, profile: RoleplayProfile, language: String) {
        let ja = language == "ja"
        let separator = ja ? "、" : ", "

        func clean(_ text: String?) -> String {
            text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        func join(_ parts: [String], _ sep: String = "\n") -> String {
            parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: sep)
        }
        func list(_ items: [String]?) -> String {
            join(items ?? [], separator)
        }
        func labeled(_ labelJA: String, _ labelEN: String, _ value: String) -> String {
            value.isEmpty ? "" : (ja ? "\(labelJA): \(value)" : "\(labelEN): \(value)")
        }

        self.init(name: oshi.name)

        description = clean(profile.description).isEmpty ? clean(oshi.memo) : clean(profile.description)
        personality = clean(oshi.personality)
        for item in ConversationAdjustmentItem.allCases {
            let text = item == .interaction ? oshi.relationship_detail : oshi.speaking_style
            conversationAdjustments[item.rawValue] = item.savedChoice(in: text)
        }
        speakingStyle = join([
            clean(oshi.speaking_style),
            labeled("口癖（毎回は使わない）", "Catchphrase (don't overuse)", clean(oshi.signature_phrase))
        ])

        var genderText = clean(oshi.gender)
        for otherPrefix in ["その他：", "Other: "] where genderText.hasPrefix(otherPrefix) {
            genderText = String(genderText.dropFirst(otherPrefix.count))
        }
        background = join([
            clean(profile.background),
            labeled("性別", "Gender", genderText),
            labeled("誕生日", "Birthday", clean(oshi.birthday)),
            labeled("出身地", "Hometown", clean(oshi.hometown)),
            oshi.height.map { labeled("身長", "Height", "\($0)cm") } ?? ""
        ])
        worldSetting = clean(profile.worldSetting)
        relationshipWithUser = join([
            clean(oshi.relationship_status),
            clean(oshi.relationship_detail),
            labeled("二人の思い出", "Shared memory", clean(oshi.shared_memory))
        ])
        likes = join([
            clean(profile.likes),
            labeled("好きな食べ物", "Favorite food", clean(oshi.favorite_food)),
            labeled("好きな色", "Favorite color", clean(oshi.favorite_color)),
            labeled("趣味・興味", "Interests", list(oshi.interests)),
            labeled("よく話したがる話題", "Favorite topics", list(oshi.conversation_topics))
        ])
        dislikes = join([
            clean(profile.dislikes),
            labeled("苦手な食べ物", "Disliked food", clean(oshi.disliked_food)),
            labeled("自分からは広げたくない話題", "Topics to avoid bringing up", list(oshi.forbidden_topics))
        ])
        behaviorRules = clean(profile.behaviorRules)
        exampleDialogues = clean(profile.exampleDialogues)
        userNickname = clean(oshi.user_nickname)
        catchphrase = clean(oshi.signature_phrase)
    }
}
