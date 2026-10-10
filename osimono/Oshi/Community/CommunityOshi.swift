import Foundation

/// A deliberately small, public profile. Personal memories and relationship settings never enter this model.
struct CommunityOshi: Identifiable, Codable, Equatable {
    let id: String
    let creatorID: String
    let creatorName: String
    var name: String
    var introduction: String
    var category: String
    var tags: [String]
    var personality: String
    var speakingStyle: String
    var signaturePhrase: String
    var sampleLine: String
    var imageUrl: String?
    var publishedAt: Double

    var localID: String { "community_" + id }

    func registrationData(now: Double) -> [String: Any] {
        var data: [String: Any] = [
            "id": localID, "name": name, "createdAt": now,
            "personality": personality, "speaking_style": speakingStyle,
            "signature_phrase": signaturePhrase,
            "communitySourceID": id, "communityCreatorName": creatorName
        ]
        if let imageUrl { data["imageUrl"] = imageUrl }
        return data
    }
}

enum CommunityCategory: String, CaseIterable, Identifiable {
    case gentle, cheerful, cool, sweet, fantasy, other
    var id: String { rawValue }
    var title: String {
        switch self {
        case .gentle: return communityText("癒し", "Comfort")
        case .cheerful: return communityText("元気", "Cheerful")
        case .cool: return communityText("クール", "Cool")
        case .sweet: return communityText("甘め", "Sweet")
        case .fantasy: return communityText("ファンタジー", "Fantasy")
        case .other: return communityText("その他", "Other")
        }
    }
}

func communityText(_ japanese: String, _ english: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("ja") == true ? japanese : english
}

struct CommunityPublicationDraft {
    var name = ""
    var creatorName = ""
    var introduction = ""
    var category = CommunityCategory.gentle.rawValue
    var tagsText = ""
    var personality = ""
    var speakingStyle = ""
    var signaturePhrase = ""
    var sampleLine = ""
    var includeImage = false

    var tags: [String] {
        var seen = Set<String>()
        return tagsText.components(separatedBy: CharacterSet(charactersIn: ",、\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.utf16.count <= 60 &&
        !creatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && creatorName.utf16.count <= 40 &&
        !introduction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && introduction.utf16.count <= 240 &&
        personality.utf16.count <= 1500 && speakingStyle.utf16.count <= 1500 &&
        signaturePhrase.utf16.count <= 200 && sampleLine.utf16.count <= 300 &&
        tags.count <= 5 && tags.allSatisfy { $0.utf16.count <= 20 }
    }
    var payload: [String: Any] {
        ["name": name, "creatorName": creatorName, "introduction": introduction,
         "category": category, "tags": tags, "personality": personality,
         "speakingStyle": speakingStyle, "signaturePhrase": signaturePhrase,
         "sampleLine": sampleLine, "includeImage": includeImage]
    }
}

enum CommunityRegistration {
    enum Decision: Equatable { case insert, existing, limitReached }
    /// Evaluated again on every transaction retry, including concurrent imports from another device.
    static func decision(records: [String: Any], profile: CommunityOshi, limit: Int) -> Decision {
        if records[profile.localID] != nil || records.values.contains(where: {
            ($0 as? [String: Any])?["communitySourceID"] as? String == profile.id
        }) { return .existing }
        return records.count >= limit ? .limitReached : .insert
    }
    static func existingID(records: [String: Any], profile: CommunityOshi) -> String? {
        if records[profile.localID] != nil { return profile.localID }
        return records.first { ($0.value as? [String: Any])?["communitySourceID"] as? String == profile.id }?.key
    }
}
