import SwiftUI
import XCTest
@testable import osimono

@MainActor
final class AppLockVisualTests: XCTestCase {
    private final class SuccessfulAuthenticator: AppLockAuthenticating {
        func authenticate(reason: String) async throws -> Bool { true }
        func cancel() {}
    }

    func testCoverProtectsPresentedContentAndRelocksAfterBackground() async throws {
        let store = UserDefaults(suiteName: "AppLockWindowTests.\(UUID().uuidString)")!
        store.set(true, forKey: AppLockManager.enabledKey)
        let lock = AppLockManager(defaults: store, isPremium: true, authenticator: SuccessfulAuthenticator())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let contentWindow = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: Text("Private chat").background(AppLockWindowPresenter(lock: lock)))
        contentWindow.rootViewController = controller
        contentWindow.makeKeyAndVisible()
        defer {
            contentWindow.rootViewController = nil
            contentWindow.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        let cover = try XCTUnwrap(scene.windows.first {
            $0.windowLevel.rawValue == UIWindow.Level.normal.rawValue + 1 && !$0.isHidden
        })
        XCTAssertTrue(cover.rootViewController is UIHostingController<AppLockScreen>)
        XCTAssertTrue(cover.isKeyWindow)
        // Even a full-screen modal in the content window remains beneath the cover.
        let modal = UIViewController()
        modal.modalPresentationStyle = .fullScreen
        let textField = UITextField(frame: CGRect(x: 20, y: 80, width: 250, height: 44))
        textField.text = "Private draft"
        modal.view.addSubview(textField)
        controller.present(modal, animated: false)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(cover.isHidden)
        await lock.unlock()
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(cover.isHidden)
        XCTAssertTrue(textField.becomeFirstResponder())
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: scene)
        XCTAssertFalse(cover.isHidden, "The privacy cover must appear synchronously before the snapshot.")
        XCTAssertFalse(textField.isFirstResponder, "Dismiss the underlying chat keyboard while covered.")
        XCTAssertTrue(try XCTUnwrap((cover.rootViewController as? UIHostingController<AppLockScreen>)?.rootView).privacyOnly)
        NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification, object: scene)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        XCTAssertTrue(lock.isLocked)
        XCTAssertFalse(cover.isHidden)
        XCTAssertFalse(try XCTUnwrap((cover.rootViewController as? UIHostingController<AppLockScreen>)?.rootView).privacyOnly)
        lock.updatePremiumStatus(false)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(cover.isHidden)
        controller.dismiss(animated: false)
    }

    func testLockScreenAtStandardAndAccessibleSizes() throws {
        let store = UserDefaults(suiteName: "AppLockVisualTests.\(UUID().uuidString)")!
        let lock = AppLockManager(defaults: store, isPremium: true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        defer { previousWindow?.makeKeyAndVisible() }

        for (scheme, size, privacy) in [(ColorScheme.light, DynamicTypeSize.large, false),
                                       (.dark, .accessibility1, false), (.light, .large, true)] {
            let controller = UIHostingController(rootView: AppLockScreen(lock: lock, privacyOnly: privacy)
                .environment(\.locale, Locale(identifier: "ja"))
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, size))
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
            let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels))
            XCTAssertGreaterThan(Set(stride(from: 0, to: CFDataGetLength(pixels), by: 100).map { bytes[$0] }).count, 8)
            let attachment = XCTAttachment(image: image)
            attachment.name = "app-lock-\(scheme)-\(size)-privacy-\(privacy)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
    }
}
