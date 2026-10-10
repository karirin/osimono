import Foundation

/// Uses the existing saved conversation adjustment so both settings entry points stay in sync.
enum RoleplayReplyLength: String, CaseIterable, Identifiable {
    case short, standard, long

    var id: String { rawValue }
    var title: String { NSLocalizedString("roleplay_reply_length_\(rawValue)", comment: "Reply length") }
    var adjustmentChoice: Int {
        switch self {
        case .short: return 1
        case .standard: return 3
        case .long: return 2
        }
    }
    init(choice: Int?) {
        switch choice {
        case 1: self = .short
        case 2: self = .long
        default: self = .standard
        }
    }

    /// Includes room for JSON, the action, and a short fictional inner voice.
    var maxTokens: Int {
        switch self {
        case .short: return 450
        case .standard: return 650
        case .long: return 1200
        }
    }
}

/// A fictional counterpart for one user × oshi. Never the account's public profile.
struct RoleplayUserPersona: Equatable {
    var isEnabled = false
    var name = ""
    var age = ""
    var role = ""
    var personality = ""
    var relationship = ""
    var background = ""

    init() {}

    init(dictionary: [String: Any]) {
        isEnabled = dictionary["isEnabled"] as? Bool ?? false
        name = Self.clean(dictionary["name"] as? String ?? "", limit: 80)
        age = Self.clean(dictionary["age"] as? String ?? "", limit: 40)
        role = Self.clean(dictionary["role"] as? String ?? "", limit: 200)
        personality = Self.clean(dictionary["personality"] as? String ?? "", limit: 800)
        relationship = Self.clean(dictionary["relationship"] as? String ?? "", limit: 400)
        background = Self.clean(dictionary["background"] as? String ?? "", limit: 1500)
    }

    var isActive: Bool { isEnabled && ![name, age, role, personality, relationship, background].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    var normalized: Self { Self(dictionary: toDictionary()) }
    var effective: Self { isActive ? normalized : Self() }

    func toDictionary() -> [String: Any] {
        ["isEnabled": isEnabled, "name": Self.clean(name, limit: 80), "age": Self.clean(age, limit: 40),
         "role": Self.clean(role, limit: 200), "personality": Self.clean(personality, limit: 800),
         "relationship": Self.clean(relationship, limit: 400), "background": Self.clean(background, limit: 1500)]
    }

    private static func clean(_ text: String, limit: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }
}

/// Applies only fields edited by this screen, preserving concurrent memory/relationship updates.
enum RoleplaySettingsMutation {
    static func apply(to root: [String: Any], persona: RoleplayUserPersona, innerThoughtsEnabled: Bool,
                      profile: RoleplayProfile?, situation: RoleplaySituation?, now: TimeInterval) -> [String: Any] {
        var updated = root
        let oldPersona = RoleplayUserPersona(dictionary: root["userPersona"] as? [String: Any] ?? [:])
        updated["userPersona"] = persona.toDictionary()
        updated["innerThoughtsEnabled"] = innerThoughtsEnabled
        if let profile { updated["profile"] = profile.toDictionary() }
        if let situation { updated["situation"] = situation.toDictionary() }
        if oldPersona.effective != persona.effective {
            // Keep visible history and saved memories, but start a fresh context for the new role.
            updated["personaUpdatedAt"] = now
            updated["summary"] = ""
            updated["summarizedUntil"] = max(root["summarizedUntil"] as? TimeInterval ?? 0, now)
            updated["summarizedBoundaryIds"] = [String]()
            updated["extractionMessageId"] = ""
            updated["extractionOffset"] = 0
            updated["memoryRevision"] = (root["memoryRevision"] as? Int ?? 0) + 1
        }
        return updated
    }
}
