import Foundation
import Combine
import FirebaseAuth

@MainActor
final class StoryLibrary: ObservableObject {
    @Published private(set) var records: [StoryRecord] = []
    @Published private(set) var cast: [StoryCharacter] = []
    @Published private(set) var ownerID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    /// 現在のユーザーで一度でも読み込みに成功したか（初回表示で空状態を一瞬出さないため）
    @Published private(set) var hasLoaded = false
    private var handle: AuthStateDidChangeListenerHandle?
    private var requestID = UUID()
    private let repository = StoryRepository()

    func start() {
        guard handle == nil else { return }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self, self.handle != nil else { return }
                if self.ownerID != user?.uid {
                    self.requestID = UUID()
                    self.records = []
                    self.cast = []
                    self.error = nil
                    self.hasLoaded = false
                    self.ownerID = user?.uid
                }
                await self.load()
            }
        }
    }
    func stop() {
        requestID = UUID()
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
        handle = nil
    }
    func load() async {
        guard let ownerID, Auth.auth().currentUser?.uid == ownerID else {
            error = StoryError.authentication.localizedDescription
            isLoading = false
            return
        }
        let token = UUID()
        requestID = token
        isLoading = true
        error = nil
        do {
            async let saved = repository.list(userID: ownerID)
            async let registered = repository.cast(userID: ownerID)
            let (records, cast) = try await (saved, registered)
            guard requestID == token, self.ownerID == ownerID, Auth.auth().currentUser?.uid == ownerID else { return }
            self.records = records
            self.cast = cast
            hasLoaded = true
            isLoading = false
        } catch {
            guard requestID == token, self.ownerID == ownerID, Auth.auth().currentUser?.uid == ownerID else { return }
            self.error = error.localizedDescription
            isLoading = false
        }
    }
    func replace(_ record: StoryRecord) {
        guard record.ownerID == ownerID, Auth.auth().currentUser?.uid == ownerID else { return }
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
    }
}
