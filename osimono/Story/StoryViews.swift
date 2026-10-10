import SwiftUI

enum StoryText {
    static func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }
    static func progress(_ scene: StoryScene) -> String {
        String(format: text("story_progress"), scene.episode, scene.sceneNumber)
    }
}
