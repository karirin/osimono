import Foundation
import FirebaseDatabase

/// A small boundary allows acknowledgement/failure behavior to be tested without changing real accounts.
protocol ConversationAdjustmentDatabase {
    func fetchState(userID: String, oshiID: String, completion: @escaping (Result<[String: Any], Error>) -> Void)
    func transact(userID: String, oshiID: String, stateOnly: Bool,
                  mutation: @escaping (inout [String: Any]) -> Bool,
                  completion: @escaping (Result<[String: Any], Error>) -> Void)
}

struct FirebaseConversationAdjustmentDatabase: ConversationAdjustmentDatabase {
    static let stateKey = "conversationAdjustmentState"
    private func reference(userID: String, oshiID: String) -> DatabaseReference {
        Database.database().reference().child("oshis").child(userID).child(oshiID)
    }
    func fetchState(userID: String, oshiID: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        reference(userID: userID, oshiID: oshiID).child(Self.stateKey).getData { error, snapshot in
            if let error { completion(.failure(error)) }
            else { completion(.success(snapshot?.value as? [String: Any] ?? [:])) }
        }
    }
    func transact(userID: String, oshiID: String, stateOnly: Bool,
                  mutation: @escaping (inout [String: Any]) -> Bool,
                  completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let root = reference(userID: userID, oshiID: oshiID)
        let ref = stateOnly ? root.child(Self.stateKey) : root
        if stateOnly {
            commit(ref: ref, stateOnly: true, mutation: mutation, completion: completion)
        } else {
            // Read the whole record first; the cache may contain only the guidance child.
            ref.getData { error, snapshot in
                if let error { completion(.failure(error)); return }
                guard let data = snapshot?.value as? [String: Any], data["name"] != nil else {
                    completion(.failure(NSError(domain: "ConversationAdjustment", code: 404))); return
                }
                self.commit(ref: ref, stateOnly: false, mutation: mutation, completion: completion)
            }
        }
    }
    private func commit(ref: DatabaseReference, stateOnly: Bool,
                        mutation: @escaping (inout [String: Any]) -> Bool,
                        completion: @escaping (Result<[String: Any], Error>) -> Void) {
        ref.runTransactionBlock({ current in
            // A cold local cache must be retried against the server before touching registered settings.
            if !stateOnly, current.value == nil || current.value is NSNull {
                return TransactionResult.success(withValue: current)
            }
            var data = current.value as? [String: Any] ?? [:]
            if !stateOnly, data["name"] == nil { return TransactionResult.abort() }
            guard mutation(&data) else { return TransactionResult.abort() }
            current.value = data
            return TransactionResult.success(withValue: current)
        }, andCompletionBlock: { error, committed, snapshot in
            if let error { completion(.failure(error)) }
            else if committed, let data = snapshot?.value as? [String: Any] { completion(.success(data)) }
            else { completion(.failure(NSError(domain: "ConversationAdjustment", code: 409))) }
        }, withLocalEvents: false)
    }
}
