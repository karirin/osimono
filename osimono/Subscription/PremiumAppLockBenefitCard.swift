import SwiftUI

struct PremiumAppLockBenefitCard: View {
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [SubscriptionPreView.pink, SubscriptionPreView.lavender],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(gradient)
                    .frame(width: 48, height: 48)
                    .background(gradient.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("premium_app_lock_exclusive")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(gradient)
                    Text("app_lock_title")
                        .font(.headline)
                }
            }

            Text("premium_app_lock_summary")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                benefit("premium_app_lock_authentication", icon: "faceid")
                benefit("premium_app_lock_automatic", icon: "lock.rotation")
                benefit("premium_app_lock_privacy", icon: "eye.slash")
            }

            Divider()

            Label {
                Text("premium_app_lock_setup")
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "gearshape")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(gradient.opacity(0.2), lineWidth: 1)
        }
        .accessibilityIdentifier("premiumAppLockBenefitCard")
    }

    private func benefit(_ key: LocalizedStringKey, icon: String) -> some View {
        Label {
            Text(key).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(gradient)
        }
        .font(.subheadline)
    }
}

#Preview("App lock benefit") {
    ScrollView {
        PremiumAppLockBenefitCard().padding(20)
    }
    .background(Color(.systemGroupedBackground))
}
