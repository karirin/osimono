import Combine
import Foundation
import LocalAuthentication

@MainActor
protocol AppLockAuthenticating {
    func authenticate(reason: String) async throws -> Bool
    func cancel()
}

@MainActor
final class DeviceOwnerAuthenticator: AppLockAuthenticating {
    private var context: LAContext?

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        self.context = context
        defer { self.context = nil }
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        }
        return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
    }

    func cancel() {
        context?.invalidate()
    }
}

/// One lock session for the app. Never persist successful authentication across launches.
@MainActor
final class AppLockManager: ObservableObject {
    static let shared: AppLockManager = {
        let manager = AppLockManager()
        manager.subscriptionObserver = SubscriptionManager.shared.$isSubscribed
            .removeDuplicates()
            .sink { [weak manager] isPremium in
                manager?.updatePremiumStatus(isPremium)
            }
        return manager
    }()
    static let enabledKey = "premiumAppLockEnabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool
    @Published private(set) var isPremium: Bool
    @Published private(set) var isAuthenticating = false
    @Published var errorMessage: String?

    private let defaults: UserDefaults
    private let authenticator: AppLockAuthenticating
    private var operationID: UUID?
    private var subscriptionObserver: AnyCancellable?

    init(defaults: UserDefaults = .standard,
         isPremium: Bool = PremiumFeatures.isActive,
         authenticator: AppLockAuthenticating? = nil) {
        self.defaults = defaults
        self.authenticator = authenticator ?? DeviceOwnerAuthenticator()
        self.isPremium = isPremium
        let enabled = defaults.bool(forKey: Self.enabledKey) && isPremium
        isEnabled = enabled
        isLocked = enabled
    }

    func updatePremiumStatus(_ isPremium: Bool) {
        self.isPremium = isPremium
        guard !isPremium else { return }
        cancelAuthentication()
        isEnabled = false
        isLocked = false
        errorMessage = nil
        defaults.set(false, forKey: Self.enabledKey)
    }

    func didEnterBackground() {
        cancelAuthentication()
        errorMessage = nil
        isLocked = isEnabled && isPremium
    }

    /// Authenticate before changing either setting, so a failed setup never enables the lock.
    func setEnabled(_ enabled: Bool) async {
        guard isPremium, enabled != isEnabled, !isAuthenticating else { return }
        guard await authenticate(reason: NSLocalizedString("app_lock_settings_reason", comment: "")),
              isPremium else { return }
        isEnabled = enabled
        isLocked = false
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    func unlock() async {
        guard isEnabled, isPremium, isLocked, !isAuthenticating else { return }
        if await authenticate(reason: NSLocalizedString("app_lock_unlock_reason", comment: "")) {
            isLocked = false
        }
    }

    private func authenticate(reason: String) async -> Bool {
        let id = UUID()
        operationID = id
        isAuthenticating = true
        defer { isAuthenticating = false }
        errorMessage = nil
        do {
            let success = try await authenticator.authenticate(reason: reason)
            guard operationID == id else { return false }
            operationID = nil
            isAuthenticating = false
            if !success {
                errorMessage = NSLocalizedString("app_lock_auth_failed", comment: "")
            }
            return success
        } catch {
            guard operationID == id else { return false }
            operationID = nil
            isAuthenticating = false
            let code = (error as NSError).code
            switch code {
            case LAError.passcodeNotSet.rawValue:
                errorMessage = NSLocalizedString("app_lock_passcode_required", comment: "")
            case LAError.userCancel.rawValue, LAError.systemCancel.rawValue, LAError.appCancel.rawValue:
                errorMessage = NSLocalizedString("app_lock_auth_cancelled", comment: "")
            default:
                errorMessage = NSLocalizedString("app_lock_auth_failed", comment: "")
            }
            return false
        }
    }

    private func cancelAuthentication() {
        operationID = nil
        authenticator.cancel()
        // Keep the pending request busy until its callback returns, preventing overlapping contexts.
        // LocalAuthentication invalidation completes the pending request asynchronously.
    }
}
