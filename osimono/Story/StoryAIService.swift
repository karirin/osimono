import Foundation
import FirebaseAuth
import FirebaseFunctions

final class StoryAIService: StoryGenerating {
    func generate(record: StoryRecord, decision: StoryDecision?) async throws -> StoryScene {
        guard Auth.auth().currentUser?.uid == record.ownerID else { throw StoryError.authentication }
        guard let client = AIClient.shared else { throw StoryError.unavailable }
        do {
            let scene = try await StoryGeneration.generate(record: record, decision: decision) { messages, maxTokens in
                guard Auth.auth().currentUser?.uid == record.ownerID else { throw StoryError.authentication }
                return try await withCheckedThrowingContinuation { continuation in
                    client.sendChat(messages: messages, temperature: 0.55, jsonMode: true,
                                    cacheKey: "story-v1-\(record.configuration.language)", maxTokens: maxTokens) { raw, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let raw { continuation.resume(returning: raw) }
                        else { continuation.resume(throwing: StoryError.invalidResponse) }
                    }
                }
            }
            guard Auth.auth().currentUser?.uid == record.ownerID else { throw StoryError.authentication }
            return scene
        } catch {
            let functionError = error as NSError
            let description = error.localizedDescription.lowercased()
            if (functionError.domain == FunctionsErrorDomain && functionError.code == FunctionsErrorCode.failedPrecondition.rawValue)
                || description.contains("invalid api key")
                || description.contains("api key has been invalidated") {
                throw StoryError.serviceConfiguration
            }
            throw error
        }
    }
}

@MainActor
extension StorySession {
    static func live(record: StoryRecord) -> StorySession {
        StorySession(record: record, repository: StoryRepository(), generator: StoryAIService(),
                     currentUserID: { Auth.auth().currentUser?.uid }, reserveUsage: {
            MessageLimitManager.shared.forceUpdateSubscriptionCache(isSubscribed: SubscriptionManager.shared.isSubscribed)
            guard !MessageLimitManager.shared.hasReachedLimit() else { throw StoryError.limit }
            MessageLimitManager.shared.incrementCount()
        }, refundUsage: { MessageLimitManager.shared.refundCount() })
    }
}
