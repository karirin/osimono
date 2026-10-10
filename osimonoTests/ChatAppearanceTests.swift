import XCTest
import SwiftUI
@testable import osimono

@MainActor
final class ChatAppearanceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite: String!
    private var directory: URL!

    override func setUp() {
        super.setUp()
        suite = "ChatAppearanceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testPreferencesSurviveRestartAndFontSizeIsBounded() {
        let store = ChatAppearanceStore(defaults: defaults, directory: directory)
        store.setBackground(.mint)
        store.setFont(.serif)
        store.setFontSize(21)
        let restored = ChatAppearanceStore(defaults: defaults, directory: directory)
        XCTAssertEqual(restored.settings, store.settings)
        restored.setFontSize(100)
        XCTAssertEqual(restored.settings.fontSize, 23)
        restored.setFontSize(-20)
        XCTAssertEqual(restored.settings.fontSize, 13)
        restored.setFontSize(.nan)
        XCTAssertEqual(restored.settings.fontSize, 15)
    }

    func testPhotoPersistsAcrossThemeChangesAndResetDeletesIt() throws {
        let store = ChatAppearanceStore(defaults: defaults, directory: directory)
        try store.savePhoto(ChatBackgroundPhoto.prepare(photoData()))
        XCTAssertEqual(store.settings.background, .photo)
        store.setBackground(.rose)
        let restored = ChatAppearanceStore(defaults: defaults, directory: directory)
        XCTAssertNotNil(restored.photo)
        restored.setBackground(.photo)
        restored.setFont(.rounded)
        try restored.reset()
        let reset = ChatAppearanceStore(defaults: defaults, directory: directory)
        XCTAssertEqual(reset.settings, ChatAppearanceSettings())
        XCTAssertNil(reset.photo)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("background.jpg").path))
    }

    func testMissingPhotoAndCorruptPreferencesFallBackToDefault() throws {
        defaults.set(try JSONEncoder().encode(ChatAppearanceSettings(background: .photo, fontStyle: .serif, fontSize: 20)), forKey: ChatAppearanceStore.settingsKey)
        let store = ChatAppearanceStore(defaults: defaults, directory: directory)
        XCTAssertEqual(store.settings.background, .standard)
        XCTAssertEqual(store.settings.fontStyle, .serif)
        store.setBackground(.photo)
        XCTAssertEqual(store.settings.background, .standard)
        defaults.set(Data("invalid".utf8), forKey: ChatAppearanceStore.settingsKey)
        XCTAssertEqual(ChatAppearanceStore(defaults: defaults, directory: directory).settings, ChatAppearanceSettings())
    }

    func testPhotoImportDownsamplesAndInvalidPhotoPreservesPreviousSelection() throws {
        let prepared = try ChatBackgroundPhoto.prepare(photoData())
        let image = try XCTUnwrap(UIImage(data: prepared)?.cgImage)
        XCTAssertLessThanOrEqual(max(image.width, image.height), 1600)
        let store = ChatAppearanceStore(defaults: defaults, directory: directory)
        try store.savePhoto(prepared)
        XCTAssertThrowsError(try store.savePhoto(Data("not an image".utf8)))
        XCTAssertEqual(store.settings.background, .photo)
        XCTAssertNotNil(store.photo)
        try store.removePhoto()
        XCTAssertEqual(store.settings.background, .standard)
    }

    private func photoData() throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1800), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2400, height: 1800))
        }
        return try XCTUnwrap(image.jpegData(compressionQuality: 1))
    }

    func testSettingsRenderInLightDarkAndAccessibleSizes() throws {
        let store = ChatAppearanceStore(defaults: defaults, directory: directory)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        for (scheme, size, style) in [
            (ColorScheme.light, DynamicTypeSize.large, ChatFontStyle.standard),
            (.dark, .large, .serif),
            (.light, .accessibility1, .rounded)
        ] {
            store.setBackground(.sky)
            store.setFont(style)
            store.setFontSize(19)
            let controller = UIHostingController(rootView: ChatAppearanceSettingsView(store: store)
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size))
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "chat-appearance-\(scheme)-\(size)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
        previousWindow?.makeKeyAndVisible()
    }
}
