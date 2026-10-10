import Foundation

enum StorySetting: String, Codable, CaseIterable {
    case school, house, fantasy
    var titleKey: String { "story_setting_" + rawValue }
    var synopsisKey: String { "story_synopsis_" + rawValue }
    var roles: [String] {
        switch self {
        case .school: return ["classmate", "clubmate", "rival"]
        case .house: return ["housemate", "organizer", "neighbor"]
        case .fantasy: return ["adventurer", "mage", "guardian"]
        }
    }
}
enum StoryMood: String, Codable, CaseIterable { case gentle, youth, suspense }
enum StoryParticipation: String, Codable, CaseIterable { case protagonist, member }
enum StoryRelationship: String, Codable, CaseIterable { case strangers, friends, rivals }

struct StoryCharacter: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var imageURL: String?
    /// Independent start-time snapshot. Never writes back to the original Oshi.
    var profile: [String: String]
    var role: String
    /// Complete original database profile for archival; omitted from AI context.
    var sourceProfileJSON: String? = nil
}
struct StoryPair: Codable, Identifiable, Equatable {
    var firstID: String
    var secondID: String
    var relationship: StoryRelationship = .strangers
    var id: String { firstID + ":" + secondID }
}
struct StoryConfiguration: Codable, Equatable {
    var title: String
    var setting: StorySetting = .school
    var synopsis: String
    var mood: StoryMood = .gentle
    var romance = false
    var participation: StoryParticipation = .protagonist
    var leadID: String?
    var userName: String
    var userRole: String
    var language: String
    var cast: [StoryCharacter]
    var relationships: [StoryPair]

    func validate() throws {
        let ids = Set(cast.map(\.id))
        guard (1...3).contains(cast.count), ids.count == cast.count,
              cast.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 128 && !$0.name.storyTrimmed.isEmpty && $0.name.count <= 80 && !$0.role.storyTrimmed.isEmpty }),
              !title.storyTrimmed.isEmpty, title.count <= 80,
              !synopsis.storyTrimmed.isEmpty, synopsis.count <= 400,
              !userName.storyTrimmed.isEmpty, userName.count <= 40,
              !userRole.storyTrimmed.isEmpty, userRole.count <= 80,
              cast.allSatisfy({ $0.role.count <= 80 && $0.profile.count <= 24 && $0.profile.keys.allSatisfy { $0.count <= 50 } && $0.profile.values.allSatisfy { $0.count <= 600 } }),
              participation != .member || leadID.map(ids.contains) == true,
              relationships.count == cast.count * (cast.count - 1) / 2,
              Set(relationships.map { [$0.firstID, $0.secondID].sorted().joined(separator: ":") }).count == relationships.count,
              relationships.allSatisfy({ ids.contains($0.firstID) && ids.contains($0.secondID) && $0.firstID != $0.secondID })
        else { throw StoryError.invalidConfiguration }
    }
}

struct StoryLine: Codable, Equatable {
    var speakerID: String
    var text: String
}
struct StoryScene: Codable, Identifiable, Equatable {
    /// Assigned by the app, never by the AI.
    var index: Int
    var narration: String
    var lines: [StoryLine]
    var choices: [String]
    var id: Int { index }
    var episode: Int { index / 3 + 1 }
    var sceneNumber: Int { index % 3 + 1 }
    var isFinal: Bool { index == 8 }
}
struct StoryDecision: Codable, Equatable {
    var sceneIndex: Int
    var intent: String
    var choiceIndex: Int?
}
struct StoryRecord: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var ownerID: String
    var configuration: StoryConfiguration
    var createdAt = Date().timeIntervalSince1970
    var updatedAt = Date().timeIntervalSince1970
    var revision = 0
    var operationID = UUID().uuidString
    var scenes: [StoryScene] = []
    var decisions: [StoryDecision] = []
    var isComplete: Bool { scenes.count == 9 }
    var currentScene: StoryScene? { scenes.last }

    func validate() throws {
        try configuration.validate()
        guard !id.isEmpty, !ownerID.isEmpty, !operationID.isEmpty,
              (0...9).contains(scenes.count), revision == scenes.count,
              scenes.map(\.index) == Array(0..<scenes.count),
              decisions.count == max(0, scenes.count - 1),
              decisions.map(\.sceneIndex) == Array(0..<decisions.count)
        else { throw StoryError.invalidSave }
        for scene in scenes { try StoryResponse.validate(scene, castIDs: Set(configuration.cast.map(\.id))) }
        for decision in decisions {
            guard !decision.intent.storyTrimmed.isEmpty, decision.intent.count <= 300 else { throw StoryError.invalidSave }
            if let choice = decision.choiceIndex {
                guard scenes[decision.sceneIndex].choices.indices.contains(choice),
                      scenes[decision.sceneIndex].choices[choice] == decision.intent else { throw StoryError.invalidSave }
            }
        }
    }

    func advancing(with scene: StoryScene, decision: StoryDecision?) throws -> StoryRecord {
        try validate()
        guard !isComplete, scene.index == scenes.count else { throw StoryError.invalidProgress }
        if let current = currentScene {
            guard let decision, decision.sceneIndex == current.index,
                  !decision.intent.storyTrimmed.isEmpty, decision.intent.count <= 300 else { throw StoryError.invalidProgress }
            if let choice = decision.choiceIndex {
                guard current.choices.indices.contains(choice), current.choices[choice] == decision.intent else { throw StoryError.invalidProgress }
            }
        } else if decision != nil { throw StoryError.invalidProgress }
        try StoryResponse.validate(scene, castIDs: Set(configuration.cast.map(\.id)))
        var next = self
        next.scenes.append(scene)
        if let decision { next.decisions.append(decision) }
        next.revision += 1
        next.operationID = UUID().uuidString
        next.updatedAt = Date().timeIntervalSince1970
        return next
    }
}

enum StoryError: Error, LocalizedError {
    case invalidConfiguration, invalidResponse, invalidSave, invalidProgress, authentication, conflict, limit, unavailable, serviceConfiguration, saveTimeout
    var errorDescription: String? {
        let key: String
        switch self {
        case .invalidConfiguration: key = "story_error_configuration"
        case .invalidResponse: key = "story_error_response"
        case .invalidSave: key = "story_error_save"
        case .invalidProgress: key = "story_error_progress"
        case .authentication: key = "story_error_auth"
        case .conflict: key = "story_error_conflict"
        case .limit: key = "story_error_limit"
        case .unavailable: key = "story_error_unavailable"
        case .serviceConfiguration: key = "story_error_service_configuration"
        case .saveTimeout: key = "story_error_save_timeout"
        }
        return NSLocalizedString(key, comment: "")
    }
}

enum StoryResponse {
    private struct Payload: Decodable {
        var narration: String
        var lines: [StoryLine]
        var choices: [String]
    }
    /// `castNames` maps a cast member's name to its ID. The AI sometimes uses a name as speakerID,
    /// or writes a line for the user (e.g. speakerID "りょうや"). Names are mapped to IDs and
    /// lines from anyone outside the cast are dropped instead of rejecting the whole scene.
    static func parse(_ raw: String, index: Int, castIDs: Set<String>, castNames: [String: String] = [:]) throws -> StoryScene {
        guard raw.utf8.count <= 12000, let data = raw.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { throw StoryError.invalidResponse }
        let lines = payload.lines.compactMap { line -> StoryLine? in
            let speaker = line.speakerID.storyTrimmed
            guard let id = castIDs.contains(speaker) ? speaker : castNames[speaker] else { return nil }
            return StoryLine(speakerID: id, text: line.text.storyTrimmed)
        }
        let scene = StoryScene(index: index, narration: payload.narration.storyTrimmed,
                               lines: lines, choices: payload.choices.map(\.storyTrimmed))
        try validate(scene, castIDs: castIDs)
        return scene
    }
    static func validate(_ scene: StoryScene, castIDs: Set<String>) throws {
        guard (0...8).contains(scene.index), !scene.narration.storyTrimmed.isEmpty, scene.narration.count <= 160,
              (1...4).contains(scene.lines.count),
              scene.lines.allSatisfy({ castIDs.contains($0.speakerID) && !$0.text.storyTrimmed.isEmpty && $0.text.count <= 100 }),
              scene.choices.count == (scene.isFinal ? 0 : 3),
              Set(scene.choices).count == scene.choices.count,
              scene.choices.allSatisfy({ !$0.storyTrimmed.isEmpty && $0.count <= 60 }),
              scene.narration.count + scene.lines.reduce(0, { $0 + $1.text.count }) + scene.choices.joined().count <= 600
        else { throw StoryError.invalidResponse }
    }
}

extension String {
    var storyTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

enum StoryArchive {
    static let maxBytes = 120000
    static func encode(_ record: StoryRecord) throws -> [String: Any] {
        try record.validate()
        let data = try JSONEncoder().encode(record)
        guard data.count <= maxBytes else { throw StoryError.invalidSave }
        return ["payload": String(decoding: data, as: UTF8.self), "revision": record.revision,
                "ownerID": record.ownerID, "operationID": record.operationID]
    }
    static func decode(_ value: Any?) throws -> StoryRecord {
        guard let dictionary = value as? [String: Any], let payload = dictionary["payload"] as? String,
              payload.utf8.count <= maxBytes,
              let record = try? JSONDecoder().decode(StoryRecord.self, from: Data(payload.utf8)),
              dictionary["revision"] as? Int == record.revision,
              dictionary["ownerID"] as? String == record.ownerID,
              dictionary["operationID"] as? String == record.operationID else { throw StoryError.invalidSave }
        try record.validate()
        return record
    }
}

/// Firebase may acknowledge a queued write after the timeout. Resume its caller only once.
final class StorySaveAcknowledgement {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    init(_ continuation: CheckedContinuation<Void, Error>) { self.continuation = continuation }
    func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}
