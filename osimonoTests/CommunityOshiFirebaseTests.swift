import Foundation
import Testing
import FirebaseCore
import FirebaseDatabase
@testable import osimono

@MainActor
struct CommunityOshiFirebaseTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["COMMUNITY_DATABASE_EMULATOR_TEST"] == "1"))
    func registrationHandlesColdCacheConcurrencyLimitsAndUnavailableProfiles() async throws {
        let options = FirebaseOptions(googleAppID: "1:123456:ios:abcdef", gcmSenderID: "123456")
        options.apiKey = "AIza" + String(repeating: "0", count: 35)
        options.databaseURL = "https://demo-community-swift.firebaseio.com"
        options.projectID = "demo-community-swift"
        let name = "community-test-" + UUID().uuidString
        FirebaseApp.configure(name: name, options: options)
        let app = try #require(FirebaseApp.app(name: name))
        let database = Database.database(app: app)
        database.useEmulator(withHost: "127.0.0.1", port: 19010)
        defer { database.goOffline() }
        let uid = UUID().uuidString
        let initial = Dictionary(uniqueKeysWithValues: (0..<4).map { ("own\($0)", ["name": "Own character"]) })
        var request = URLRequest(url: try #require(URL(string: "http://127.0.0.1:19010/oshis/\(uid).json?ns=demo-community-swift")))
        request.httpMethod = "PUT"; request.httpBody = try JSONSerialization.data(withJSONObject: initial)
        let (_, response) = try await URLSession.shared.data(for: request)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let profile = CommunityOshi(id: "fixture", creatorID: "creator", creatorName: "そら", name: "凛", introduction: "聞き上手", category: "gentle", tags: [], personality: "優しい", speakingStyle: "穏やか", signaturePhrase: "", sampleLine: "", publishedAt: 0)
        let service = CommunityOshiService(database: database, currentUserID: { uid }, loadPublicProfile: { _ in profile })
        async let first = service.register(profile, limit: 5)
        async let second = service.register(profile, limit: 5)
        let ids = try await [first, second]
        #expect(Set(ids) == Set([profile.localID]))
        let saved = try await service.registrations()
        #expect(saved.count == 5)
        #expect(saved["own0"] != nil)
        #expect((saved[profile.localID] as? [String: Any])?["speaking_style"] as? String == "穏やか")
        try await database.reference().child("oshis/\(uid)/\(profile.localID)/name").setValue("自分で変更した名前")
        _ = try await service.register(profile, limit: 5)
        let edited = try await service.registrations()
        #expect((edited[profile.localID] as? [String: Any])?["name"] as? String == "自分で変更した名前")
        let different = CommunityOshi(id: "another", creatorID: "creator", creatorName: "そら", name: "陽向", introduction: "明るい", category: "cheerful", tags: [], personality: "明るい", speakingStyle: "", signaturePhrase: "", sampleLine: "", publishedAt: 0)
        let anotherService = CommunityOshiService(database: database, currentUserID: { uid }, loadPublicProfile: { _ in different })
        do {
            _ = try await anotherService.register(different, limit: 5)
            Issue.record("A concurrent new registration must respect the count limit")
        } catch { #expect(error as? CommunityOshiError == .limitReached) }
        let unavailable = CommunityOshiService(database: database, currentUserID: { uid }, loadPublicProfile: { _ in throw CommunityOshiError.unavailable })
        do {
            _ = try await unavailable.register(different, limit: Int.max)
            Issue.record("An unpublished profile must not be registered")
        } catch { #expect(error as? CommunityOshiError == .unavailable) }
        #expect(try await service.registrations().count == 5)
        let selection = try await database.reference().child("users/\(uid)/selectedOshiId").getData()
        #expect(selection.value as? String == profile.localID)
        try await database.reference().child("oshis/\(uid)/\(profile.localID)").removeValue()
        _ = try await service.register(profile, limit: 5)
        #expect(try await service.registrations().count == 5)
        try await database.reference().updateChildValues(["oshis/\(uid)": NSNull(), "users/\(uid)": NSNull()])
    }
}
