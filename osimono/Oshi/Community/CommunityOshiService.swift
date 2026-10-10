import Foundation
import FirebaseAuth
import FirebaseDatabase
import FirebaseFunctions

struct CommunityPage {
    let profiles: [CommunityOshi]
    let cursor: [String: Any]?
}

enum CommunityOshiError: LocalizedError, Equatable {
    case signedOut, invalidResponse, limitReached, unavailable
    var errorDescription: String? {
        switch self {
        case .signedOut: return communityText("ログイン状態を確認して、もう一度お試しください。", "Check your sign-in and try again.")
        case .invalidResponse: return communityText("データを読み込めませんでした。もう一度お試しください。", "Couldn't read the profile. Please try again.")
        case .limitReached: return communityText("推しの登録上限に達しています。推しを整理するか、プレミアムをご利用ください。", "Your character list is full. Remove a character or upgrade to Premium.")
        case .unavailable: return communityText("この推しは現在登録できません。公開が終了している可能性があります。", "This character is no longer available to add.")
        }
    }
}

final class CommunityOshiService {
    private var functions: Functions { Functions.functions(region: "asia-northeast1") }
    private let database: Database
    private let currentUserID: () -> String?
    private let loadPublicProfile: ((String) async throws -> CommunityOshi)?

    init(database: Database = Database.database(),
         currentUserID: @escaping () -> String? = { Auth.auth().currentUser?.uid },
         loadPublicProfile: ((String) async throws -> CommunityOshi)? = nil) {
        self.database = database
        self.currentUserID = currentUserID
        self.loadPublicProfile = loadPublicProfile
    }
    private var uid: String {
        get throws {
            guard let uid = currentUserID() else { throw CommunityOshiError.signedOut }
            return uid
        }
    }

    func call(_ action: String, _ data: [String: Any] = [:]) async throws -> [String: Any] {
        let userID = try uid
        var payload = data; payload["action"] = action
        let callable = functions.httpsCallable("communityOshi")
        callable.timeoutInterval = 45
        let result = try await callable.call(payload)
        guard currentUserID() == userID else { throw CommunityOshiError.signedOut }
        guard let dictionary = result.data as? [String: Any] else { throw CommunityOshiError.invalidResponse }
        return dictionary
    }

    private func decode(_ dictionary: [String: Any]) throws -> CommunityOshi {
        // Realtime Database omits empty arrays; normalize before Codable decoding.
        var data = dictionary
        data["tags"] = data["tags"] as? [String] ?? []
        return try JSONDecoder().decode(CommunityOshi.self, from: JSONSerialization.data(withJSONObject: data))
    }

    func list(search: String, category: String, cursor: [String: Any]?) async throws -> CommunityPage {
        var data: [String: Any] = ["search": search, "category": category]
        if let cursor { data["cursor"] = cursor }
        let response = try await call("list", data)
        guard let profiles = response["profiles"] as? [[String: Any]] else { throw CommunityOshiError.invalidResponse }
        return CommunityPage(profiles: try profiles.map(decode), cursor: response["cursor"] as? [String: Any])
    }

    func detail(_ id: String) async throws -> CommunityOshi {
        let response = try await call("detail", ["id": id])
        guard let profile = response["profile"] as? [String: Any] else { throw CommunityOshiError.invalidResponse }
        return try decode(profile)
    }

    func registrations() async throws -> [String: Any] {
        let userID = try uid
        let snapshot = try await database.reference().child("oshis").child(userID).getData()
        guard currentUserID() == userID else { throw CommunityOshiError.signedOut }
        return snapshot.value as? [String: Any] ?? [:]
    }

    /// Registration follows the app's existing client-side StoreKit limit, with an atomic duplicate/count check.
    func register(_ profile: CommunityOshi, limit: Int) async throws -> String {
        let userID = try uid
        let fresh: CommunityOshi
        if let loadPublicProfile { fresh = try await loadPublicProfile(profile.id) }
        else { fresh = try await detail(profile.id) }
        guard currentUserID() == userID else { throw CommunityOshiError.signedOut }
        let ref = database.reference().child("oshis").child(userID)
        // Keep the event cache warm for transactions; otherwise Firebase can initially call us with nil.
        let handle = ref.observe(.value) { _ in }
        defer { ref.removeObserver(withHandle: handle) }
        _ = try await ref.getData()
        let newData = fresh.registrationData(now: Date().timeIntervalSince1970)
        let localID: String = try await withCheckedThrowingContinuation { continuation in
            ref.runTransactionBlock({ mutable in
                guard self.currentUserID() == userID else { return .abort() }
                var records = mutable.value as? [String: Any] ?? [:]
                switch CommunityRegistration.decision(records: records, profile: fresh, limit: limit) {
                case .existing: return .success(withValue: mutable)
                case .limitReached: return .abort()
                case .insert:
                    records[fresh.localID] = newData
                    mutable.value = records
                    return .success(withValue: mutable)
                }
            }, andCompletionBlock: { error, committed, snapshot in
                guard self.currentUserID() == userID else {
                    continuation.resume(throwing: CommunityOshiError.signedOut); return
                }
                if let error { continuation.resume(throwing: error); return }
                guard committed else { continuation.resume(throwing: CommunityOshiError.limitReached); return }
                let records = snapshot?.value as? [String: Any] ?? [:]
                guard let id = CommunityRegistration.existingID(records: records, profile: fresh) else {
                    continuation.resume(throwing: CommunityOshiError.invalidResponse); return
                }
                continuation.resume(returning: id)
            }, withLocalEvents: false)
        }
        // Retrying after a selection failure finds the existing registration and never duplicates it.
        try await database.reference().child("users").child(userID).child("selectedOshiId").setValue(localID)
        guard currentUserID() == userID else { throw CommunityOshiError.signedOut }
        return localID
    }
}

@MainActor
final class CommunityDiscoveryModel: ObservableObject {
    @Published var profiles: [CommunityOshi] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasMore = false
    private var cursor: [String: Any]?
    private var generation = UUID()
    private let service = CommunityOshiService()

    func load(search: String, category: String, reset: Bool) async {
        if !reset && isLoading { return }
        if reset {
            generation = UUID(); profiles = []; cursor = nil; hasMore = false
        }
        let request = generation
        isLoading = true; errorMessage = nil
        do {
            let page = try await service.list(search: search, category: category, cursor: cursor)
            guard request == generation, !Task.isCancelled else {
                if request == generation { isLoading = false }
                return
            }
            let existing = Set(profiles.map(\.id))
            profiles += page.profiles.filter { !existing.contains($0.id) }
            cursor = page.cursor; hasMore = cursor != nil
        } catch {
            if request == generation && !Task.isCancelled { errorMessage = error.localizedDescription }
        }
        if request == generation { isLoading = false }
    }

    func remove(_ id: String) { profiles.removeAll { $0.id == id } }
}
