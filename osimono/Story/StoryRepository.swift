import Foundation
import FirebaseAuth
import FirebaseDatabase

final class StoryRepository: StorySaving {
    private let database: Database
    private let currentUserID: () -> String?

    init(database: Database = Database.database(), currentUserID: @escaping () -> String? = { Auth.auth().currentUser?.uid }) {
        self.database = database
        self.currentUserID = currentUserID
    }

    static func path(userID: String) -> String { "stories/\(userID)" }
    private func root(_ userID: String) -> DatabaseReference {
        database.reference().child(Self.path(userID: userID))
    }
    private func requireUser(_ id: String) throws {
        guard currentUserID() == id else { throw StoryError.authentication }
    }
    func list(userID: String) async throws -> [StoryRecord] {
        try requireUser(userID)
        let snapshot = try await root(userID).getData()
        try requireUser(userID)
        let records = try snapshot.children.allObjects.compactMap { child -> StoryRecord? in
            guard let child = child as? DataSnapshot else { return nil }
            let record = try StoryArchive.decode(child.value)
            guard record.id == child.key, record.ownerID == userID else { throw StoryError.invalidSave }
            return record
        }
        return records.sorted { $0.updatedAt > $1.updatedAt }
    }
    func cast(userID: String) async throws -> [StoryCharacter] {
        try requireUser(userID)
        let snapshot = try await database.reference().child("oshis").child(userID).getData()
        try requireUser(userID)
        return snapshot.children.allObjects.compactMap { child in
            guard let child = child as? DataSnapshot, let value = child.value as? [String: Any],
                  let name = value["name"] as? String else { return nil }
            let keys = ["personality", "speaking_style", "memo", "interests", "birthday", "height", "favorite_color", "favorite_food", "disliked_food", "hometown", "gender", "user_nickname", "relationship_status", "relationship_detail", "shared_memory", "signature_phrase", "conversation_topics", "forbidden_topics", "preferred_language"]
            var profile: [String: String] = [:]
            for key in keys {
                let text: String?
                if let strings = value[key] as? [String] { text = strings.joined(separator: ", ") }
                else if let string = value[key] as? String { text = string }
                else if let number = value[key] as? NSNumber { text = number.stringValue }
                else { text = nil }
                if let text { profile[key] = String(text.prefix(600)) }
            }
            let original = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            return StoryCharacter(id: child.key, name: name, imageURL: value["imageUrl"] as? String, profile: profile, role: "",
                                  sourceProfileJSON: original.map { String(decoding: $0, as: UTF8.self) })
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func save(_ record: StoryRecord, expectedRevision: Int?) async throws {
        try requireUser(record.ownerID)
        let value = try StoryArchive.encode(record)
        // Fixed captured user/story path. No callback resolves a fresh user ID for writes.
        let ref = root(record.ownerID).child(record.id)
        // getData() alone does not keep an event cache for the transaction's first
        // callback. Retain a value listener through the acknowledgement so an
        // existing story cannot be mistaken for an absent node and aborted locally.
        let cacheHandle = ref.observe(.value) { _ in }
        defer { ref.removeObserver(withHandle: cacheHandle) }
        _ = try await ref.getData()
        try requireUser(record.ownerID)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let acknowledgement = StorySaveAcknowledgement(continuation)
            let timeout = DispatchWorkItem { acknowledgement.finish(.failure(StoryError.saveTimeout)) }
            DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
            ref.runTransactionBlock({ data in
                let existing: StoryRecord?
                if data.value == nil || data.value is NSNull { existing = nil }
                else {
                    guard let decoded = try? StoryArchive.decode(data.value) else { return .abort() }
                    existing = decoded
                }
                guard StoryCommit.accepts(existing: existing, candidate: record, expectedRevision: expectedRevision) else { return .abort() }
                data.value = value
                return .success(withValue: data)
            }, andCompletionBlock: { error, committed, _ in
                timeout.cancel()
                if let error { acknowledgement.finish(.failure(error)) }
                else if !committed { acknowledgement.finish(.failure(StoryError.conflict)) }
                else { acknowledgement.finish(.success(())) }
            }, withLocalEvents: false)
        }
    }
}
