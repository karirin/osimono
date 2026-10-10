import SwiftUI

struct AppLockSettingsSection: View {
    @ObservedObject private var lock = AppLockManager.shared
    var isPremium: Bool
    var showPremium: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("app_lock_section").foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.pink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("app_lock_title").font(.system(size: 16, weight: .medium))
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                            .accessibilityLabel(Text("premium_plan"))
                    }
                    Text("app_lock_description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if isPremium {
                    Toggle("app_lock_title", isOn: Binding(
                        get: { lock.isEnabled },
                        set: { value in Task { await lock.setEnabled(value) } }
                    ))
                    .labelsHidden()
                    .tint(.pink)
                    .disabled(lock.isAuthenticating)
                    .accessibilityIdentifier("appLockToggle")
                } else {
                    Button(action: showPremium) {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .padding(10)
                    }
                    .accessibilityLabel(Text("app_lock_upgrade"))
                    .accessibilityIdentifier("appLockUpgradeButton")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .contentShape(Rectangle())
            .onTapGesture { if !isPremium { showPremium() } }
        }
        .alert("app_lock_title", isPresented: Binding(
            get: { lock.errorMessage != nil && !lock.isLocked },
            set: { if !$0 { lock.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { lock.errorMessage = nil }
        } message: {
            Text(lock.errorMessage ?? "")
        }
    }
}
