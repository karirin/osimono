import SwiftUI
import UIKit
import Combine

struct AppLockRoot<Content: View>: View {
    @ObservedObject private var lock = AppLockManager.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(AppLockWindowPresenter(lock: lock))
    }
}

struct AppLockScreen: View {
    @ObservedObject var lock: AppLockManager
    var privacyOnly = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            LinearGradient(colors: [.pink.opacity(0.12), .purple.opacity(0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.pink)
                    .padding(28)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
                VStack(spacing: 10) {
                    Text("app_lock_locked_title")
                        .font(.title2.bold())
                    Text("app_lock_locked_description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if !privacyOnly {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        HStack(spacing: 10) {
                            if lock.isAuthenticating {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "lock.open.fill")
                            }
                            Text(lock.isAuthenticating ? "app_lock_authenticating" : "app_lock_unlock")
                                .font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Capsule().fill(Color.pink))
                    }
                    .disabled(lock.isAuthenticating)
                    .accessibilityIdentifier("appLockUnlockButton")
                    if let error = lock.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("appLockError")
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 420)
        }
        .accessibilityIdentifier("appLockScreen")
    }
}

/// A scene window covers presented sheets as well as the root content.
/// Cover synchronously before the app switcher takes its snapshot.
struct AppLockWindowPresenter: UIViewRepresentable {
    @ObservedObject var lock: AppLockManager

    func makeCoordinator() -> Coordinator { Coordinator(lock: lock) }

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.onAttach = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        return view
    }

    func updateUIView(_ uiView: AttachmentView, context: Context) {
        if let window = uiView.window { context.coordinator.attach(to: window) }
        context.coordinator.refresh()
    }

    static func dismantleUIView(_ uiView: AttachmentView, coordinator: Coordinator) {
        coordinator.remove()
    }

    final class AttachmentView: UIView {
        var onAttach: ((UIWindow) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window { onAttach?(window) }
        }
    }

    @MainActor
    final class Coordinator {
        private let lock: AppLockManager
        private weak var contentWindow: UIWindow?
        private var coverWindow: UIWindow?
        private var hostingController: UIHostingController<AppLockScreen>?
        private var observers: [NSObjectProtocol] = []
        private var isSceneActive = false
        private var lockObserver: AnyCancellable?

        init(lock: AppLockManager) {
            self.lock = lock
            // A full-screen sheet can suspend SwiftUI updates in the underlying content.
            // Observe independently, after @Published has committed its new value.
            lockObserver = lock.objectWillChange.sink { [weak self] _ in
                DispatchQueue.main.async { self?.refresh() }
            }
        }

        func attach(to window: UIWindow) {
            guard coverWindow == nil, let scene = window.windowScene else { return }
            contentWindow = window
            isSceneActive = scene.activationState == .foregroundActive
            let cover = UIWindow(windowScene: scene)
            cover.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
            cover.backgroundColor = .systemBackground
            cover.accessibilityViewIsModal = true
            coverWindow = cover
            observe(UIScene.willDeactivateNotification, scene: scene) { coordinator in
                coordinator.isSceneActive = false
                coordinator.refresh()
            }
            observe(UIScene.didEnterBackgroundNotification, scene: scene) { coordinator in
                coordinator.lock.didEnterBackground()
                coordinator.refresh()
            }
            observe(UIScene.didActivateNotification, scene: scene) { coordinator in
                coordinator.isSceneActive = true
                coordinator.refresh()
            }
            refresh()
        }

        private func observe(_ name: Notification.Name, scene: UIWindowScene,
                             action: @escaping (Coordinator) -> Void) {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: scene, queue: .main) {
                [weak self] _ in
                // UIKit scene notifications are delivered on the main thread.
                MainActor.assumeIsolated {
                    if let self { action(self) }
                }
            })
        }

        func refresh() {
            guard let coverWindow else { return }
            let visible = lock.isEnabled && lock.isPremium && (lock.isLocked || !isSceneActive)
            if visible {
                if let hostingController {
                    if hostingController.rootView.privacyOnly != !isSceneActive {
                        hostingController.rootView = AppLockScreen(lock: lock, privacyOnly: !isSceneActive)
                    }
                } else {
                    let host = UIHostingController(rootView: AppLockScreen(lock: lock, privacyOnly: !isSceneActive))
                    hostingController = host
                    coverWindow.rootViewController = host
                }
                if coverWindow.isHidden {
                    contentWindow?.endEditing(true)
                    coverWindow.makeKeyAndVisible()
                }
                coverWindow.layoutIfNeeded()
            } else if !coverWindow.isHidden {
                coverWindow.isHidden = true
                contentWindow?.makeKey()
            }
        }

        func remove() {
            lockObserver?.cancel()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            if coverWindow?.isKeyWindow == true { contentWindow?.makeKey() }
            coverWindow?.isHidden = true
            coverWindow = nil
            hostingController = nil
        }
    }
}

#Preview("Locked") {
    AppLockScreen(lock: AppLockManager(isPremium: true))
}

#Preview("App switcher privacy") {
    AppLockScreen(lock: AppLockManager(isPremium: true), privacyOnly: true)
}
