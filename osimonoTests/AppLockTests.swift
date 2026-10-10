import Foundation
import LocalAuthentication
import Testing
@testable import osimono

@MainActor
struct AppLockTests {
    private final class Authenticator: AppLockAuthenticating {
        var succeeds = true
        var error: Error?
        var onAuthenticate: (() -> Void)?
        var calls = 0
        var cancellations = 0

        func authenticate(reason: String) async throws -> Bool {
            calls += 1
            onAuthenticate?()
            if let error { throw error }
            return succeeds
        }

        func cancel() { cancellations += 1 }
    }

    private func defaults(enabled: Bool = false) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "AppLockTests.\(UUID().uuidString)")!
        defaults.set(enabled, forKey: AppLockManager.enabledKey)
        return defaults
    }

    @Test func freePlanCannotEnableOrAuthenticate() async {
        let auth = Authenticator()
        let lock = AppLockManager(defaults: defaults(enabled: true), isPremium: false, authenticator: auth)
        await lock.setEnabled(true)
        await lock.unlock()
        #expect(!lock.isEnabled && !lock.isLocked)
        #expect(auth.calls == 0)
    }

    @Test func enablingRequiresSuccessAndPersistsForTheNextLaunch() async {
        let store = defaults()
        let auth = Authenticator()
        let lock = AppLockManager(defaults: store, isPremium: true, authenticator: auth)
        auth.succeeds = false
        await lock.setEnabled(true)
        #expect(!lock.isEnabled && !store.bool(forKey: AppLockManager.enabledKey))
        auth.succeeds = true
        await lock.setEnabled(true)
        #expect(lock.isEnabled && !lock.isLocked)
        #expect(store.bool(forKey: AppLockManager.enabledKey))
        let nextLaunch = AppLockManager(defaults: store, isPremium: true, authenticator: auth)
        #expect(nextLaunch.isLocked)
    }

    @Test func failureAndCancellationKeepTheAppLockedThenRetryUnlocks() async {
        let auth = Authenticator()
        let lock = AppLockManager(defaults: defaults(enabled: true), isPremium: true, authenticator: auth)
        auth.succeeds = false
        await lock.unlock()
        #expect(lock.isLocked && lock.errorMessage != nil && !lock.isAuthenticating)
        auth.error = NSError(domain: LAError.errorDomain, code: LAError.userCancel.rawValue)
        await lock.unlock()
        #expect(lock.isLocked && lock.errorMessage != nil && !lock.isAuthenticating)
        auth.error = nil
        auth.succeeds = true
        await lock.unlock()
        #expect(!lock.isLocked && lock.errorMessage == nil)
        lock.didEnterBackground()
        #expect(lock.isLocked)
    }

    @Test func disablingAlsoRequiresAuthentication() async {
        let store = defaults(enabled: true)
        let auth = Authenticator()
        let lock = AppLockManager(defaults: store, isPremium: true, authenticator: auth)
        await lock.unlock()
        auth.succeeds = false
        await lock.setEnabled(false)
        #expect(lock.isEnabled && store.bool(forKey: AppLockManager.enabledKey))
        auth.succeeds = true
        await lock.setEnabled(false)
        lock.didEnterBackground()
        #expect(!lock.isEnabled && !lock.isLocked)
        #expect(!store.bool(forKey: AppLockManager.enabledKey))
    }

    @Test func backgroundRejectsLateAuthenticationSuccessAndAllowsRetry() async {
        let auth = Authenticator()
        let lock = AppLockManager(defaults: defaults(enabled: true), isPremium: true, authenticator: auth)
        auth.onAuthenticate = { lock.didEnterBackground() }
        await lock.unlock()
        #expect(lock.isLocked && !lock.isAuthenticating && auth.cancellations == 1)
        auth.onAuthenticate = nil
        await lock.unlock()
        #expect(!lock.isLocked)
    }

    @Test func backgroundRejectsLateSetupSuccess() async {
        let auth = Authenticator()
        let store = defaults()
        let lock = AppLockManager(defaults: store, isPremium: true, authenticator: auth)
        auth.onAuthenticate = { lock.didEnterBackground() }
        await lock.setEnabled(true)
        #expect(!lock.isEnabled && !store.bool(forKey: AppLockManager.enabledKey))
    }

    @Test func subscriptionExpirationDisablesLockAndRejectsPendingSetup() async {
        let auth = Authenticator()
        let store = defaults(enabled: true)
        let lock = AppLockManager(defaults: store, isPremium: true, authenticator: auth)
        lock.updatePremiumStatus(false)
        #expect(!lock.isEnabled && !lock.isLocked && !store.bool(forKey: AppLockManager.enabledKey))
        lock.updatePremiumStatus(true)
        auth.onAuthenticate = { lock.updatePremiumStatus(false) }
        await lock.setEnabled(true)
        #expect(!lock.isEnabled && !lock.isAuthenticating)
    }

    @Test func missingPasscodeNeverEnablesLock() async {
        let auth = Authenticator()
        auth.error = NSError(domain: LAError.errorDomain, code: LAError.passcodeNotSet.rawValue)
        let lock = AppLockManager(defaults: defaults(), isPremium: true, authenticator: auth)
        await lock.setEnabled(true)
        #expect(!lock.isEnabled && lock.errorMessage != nil && !lock.isAuthenticating)
    }
}
