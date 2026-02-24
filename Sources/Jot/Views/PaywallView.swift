import SwiftUI

struct JotPaywallScreen: View {
    @EnvironmentObject private var purchases: PurchaseStore
    @StateObject private var licenseStore = LicenseStore() // 仅用于直销版本

    private var buyTitle: String {
        if let price = purchases.lifetimePriceText {
            return "Unlock Lifetime (\(price))"
        }
        return "Unlock Lifetime"
    }

    var body: some View {
        Group {
            if isAppStoreBuild {
                // App Store 版本界面
                appStorePaywall
            } else {
                // 直销版本界面 (Paddle)
                LicenseView(licenseStore: licenseStore)
            }
        }
    }

    private var appStorePaywall: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Jot Pro")
                .font(.title2).bold()

            if purchases.isProUnlocked {
                Text("Lifetime access is active.")
                    .foregroundStyle(.secondary)
            } else if purchases.isTrialActive {
                Text("Welcome! Your 7-day free trial is active.")
                    .foregroundStyle(.secondary)
                Text("\(purchases.trialDaysRemaining) day(s) remaining.")
                    .foregroundStyle(.secondary)
            } else {
                Text("7-day trial ended. Unlock lifetime access with a one-time purchase.")
                    .foregroundStyle(.secondary)
            }

            if let statusMessage = purchases.statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if purchases.isLoadingProducts {
                Text("Loading product info...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !purchases.canPurchaseLifetime && !purchases.isProUnlocked {
                Text("Unable to load product. Check your network/VPN/DNS, then try again.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button(buyTitle) {
                    purchases.purchaseLifetime()
                }
                .buttonStyle(.borderedProminent)
                .disabled(purchases.isBusy || purchases.isProUnlocked || !purchases.canPurchaseLifetime)

                Button("Restore Purchases") {
                    purchases.restorePurchases()
                }
                .disabled(purchases.isBusy)
            }
        }
        .padding(18)
        .task {
            purchases.configureIfNeeded()
            purchases.refresh()
        }
    }
}
