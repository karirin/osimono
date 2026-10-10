import XCTest

/// Opt-in smoke test: uses the app's existing Firebase sign-in, but never requests story AI or writes a story.
final class StoryNavigationUITests: XCTestCase {
    @MainActor
    func testStoryEntryOpensLibraryAndReturnsToChat() throws {
        guard ProcessInfo.processInfo.environment["STORY_UI_SMOKE"] == "1" else {
            throw XCTSkip("Set TEST_RUNNER_STORY_UI_SMOKE=1 to check navigation with Firebase authentication.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let skip = app.buttons["スキップ"]
        if skip.waitForExistence(timeout: 8) { skip.tap() }
        let chat = app.tabBars.buttons["チャット"]
        XCTAssertTrue(chat.waitForExistence(timeout: 30), "Existing Firebase sign-in must complete before opening a tab.")
        chat.tap()
        let entry = app.buttons["story.entry"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.buttons["story.new"].waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Story library from existing chat tab"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["閉じる"].firstMatch.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
    }
}
