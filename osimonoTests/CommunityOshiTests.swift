import Foundation
import Testing
@testable import osimono

struct CommunityOshiTests {
    private var profile: CommunityOshi {
        CommunityOshi(id: "public123", creatorID: "author", creatorName: "そら", name: "凛",
            introduction: "落ち着いた聞き上手", category: "gentle", tags: ["雑談"], personality: "優しい",
            speakingStyle: "穏やかな敬語", signaturePhrase: "無理しないで", sampleLine: "おかえりなさい。",
            imageUrl: "https://example.com/public.jpg", publishedAt: 1000)
    }

    @Test func importsOnlyCharacterSettingsAndProvenance() throws {
        let data = profile.registrationData(now: 100)
        #expect(Set(data.keys) == Set(["id", "name", "createdAt", "personality", "speaking_style", "signature_phrase", "communitySourceID", "communityCreatorName", "imageUrl"]))
        #expect(data["createdAt"] as? Double == 100)
        #expect(data["id"] as? String == "community_public123")
        let decoded = try JSONDecoder().decode(Oshi.self, from: JSONSerialization.data(withJSONObject: data))
        #expect(decoded.name == "凛")
        #expect(decoded.speaking_style == "穏やかな敬語")
        #expect(decoded.memo == nil && decoded.shared_memory == nil && decoded.user_nickname == nil)
        #expect(decoded.relationship_detail == nil && decoded.relationship_status == nil)
    }

    @Test func duplicateRegistrationDoesNotOverwritePersonalEditsEvenAtLimit() {
        let saved: [String: Any] = [profile.localID: ["name": "自分で編集した凛", "communitySourceID": profile.id]]
        #expect(CommunityRegistration.decision(records: saved, profile: profile, limit: 1) == .existing)
        #expect(CommunityRegistration.existingID(records: saved, profile: profile) == profile.localID)
        let migrated: [String: Any] = ["differentID": ["communitySourceID": profile.id]]
        #expect(CommunityRegistration.decision(records: migrated, profile: profile, limit: 1) == .existing)
        #expect(CommunityRegistration.existingID(records: migrated, profile: profile) == "differentID")
    }

    @Test func countIsReevaluatedOnTransactionRetryAndAfterRemoval() {
        var records: [String: Any] = [:]
        for index in 0..<4 { records["own\(index)"] = ["name": "own"] }
        #expect(CommunityRegistration.decision(records: records, profile: profile, limit: 5) == .insert)
        records["another-device"] = ["name": "another"]
        #expect(CommunityRegistration.decision(records: records, profile: profile, limit: 5) == .limitReached)
        #expect(CommunityRegistration.decision(records: records, profile: profile, limit: Int.max) == .insert)
        records.removeValue(forKey: "another-device")
        #expect(CommunityRegistration.decision(records: records, profile: profile, limit: 5) == .insert)
    }

    @Test func publicationRequiresNamesIntroductionAndValidLengths() {
        var draft = CommunityPublicationDraft()
        #expect(!draft.isValid)
        draft.name = "凛"; draft.creatorName = "そら"; draft.introduction = "聞き上手"
        #expect(draft.isValid)
        #expect(!draft.includeImage)
        draft.tagsText = "雑談、雑談, 癒し\n日常"
        #expect(draft.tags == ["雑談", "癒し", "日常"])
        draft.tagsText = "1,2,3,4,5,6"
        #expect(!draft.isValid)
        draft.tagsText = ""
        draft.speakingStyle = String(repeating: "a", count: 1501)
        #expect(!draft.isValid)
        draft.speakingStyle = ""
        draft.name = "　\n "
        #expect(!draft.isValid)
    }
}
