import Foundation
import StoreKit
import UserNotifications

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isPremium: Bool = false
    @Published var notificationsEnabled: Bool = true
    @Published var notificationAuthStatus: UNAuthorizationStatus = .notDetermined

    @Published var isLoadingSubscription = false
    @Published var isPurchasing = false
    @Published var isRestoringPurchases = false

    @Published var subscriptionProduct: Product?
    @Published var subscriptionExpiresAt: Date?

    @Published var errorMessage: String?
    @Published var showPrivacyPolicy = false
    @Published var showTerms = false
    @Published var showAffiliateDisclosure = false

    // MARK: - Constants

    let privacyPolicyURL = URL(string: "https://example.com/privacy")!
    let termsURL = URL(string: "https://example.com/terms")!

    static let premiumProductID = "com.konotori.premium.monthly"

    // MARK: - Dependencies

    private let userDefaultsManager: UserDefaultsManager
    private let apiClient: APIClient

    // MARK: - Init

    init(
        userDefaultsManager: UserDefaultsManager = .shared,
        apiClient: APIClient = .shared
    ) {
        self.userDefaultsManager = userDefaultsManager
        self.apiClient = apiClient
        self.isPremium = userDefaultsManager.isPremium
        self.notificationsEnabled = userDefaultsManager.notificationsEnabled
    }

    // MARK: - Load

    func load() async {
        await checkNotificationStatus()
        await fetchSubscriptionProduct()
        await updateTransactionStatus()
    }

    // MARK: - Notifications

    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationAuthStatus = settings.authorizationStatus
    }

    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func toggleNotifications() async {
        if notificationAuthStatus == .authorized {
            notificationsEnabled.toggle()
            userDefaultsManager.notificationsEnabled = notificationsEnabled
        } else {
            await AppDelegate.requestNotificationPermission()
            await checkNotificationStatus()
        }
    }

    // MARK: - StoreKit 2

    private func fetchSubscriptionProduct() async {
        isLoadingSubscription = true
        defer { isLoadingSubscription = false }

        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            subscriptionProduct = products.first
        } catch {
            print("[StoreKit] Failed to fetch products: \(error)")
        }
    }

    func purchase() async {
        guard let product = subscriptionProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await verifyWithBackend(transactionID: String(transaction.id))
                case .unverified:
                    errorMessage = "購入の検証に失敗しました。"
                }
            case .pending:
                // Awaiting parent approval or SCA
                errorMessage = "購入が保留中です。承認後に再度確認してください。"
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateTransactionStatus()
        } catch {
            errorMessage = "購入の復元に失敗しました: \(error.localizedDescription)"
        }
    }

    private func updateTransactionStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.premiumProductID,
               transaction.revocationDate == nil {
                isPremium = true
                subscriptionExpiresAt = transaction.expirationDate
                userDefaultsManager.isPremium = true
                return
            }
        }
        // No active entitlement found
        isPremium = false
        userDefaultsManager.isPremium = false
    }

    private func verifyWithBackend(transactionID: String) async {
        do {
            let status = try await apiClient.verifySubscription(transactionID: transactionID)
            isPremium = status.isPremium
            subscriptionExpiresAt = status.expiresAt
            userDefaultsManager.isPremium = status.isPremium
        } catch {
            // Fall back to local StoreKit verification
            await updateTransactionStatus()
        }
    }

    // MARK: - Sign Out

    func signOut() async throws {
        let authState = AuthStateManager()
        try await authState.signOut()
        userDefaultsManager.reset()
    }

    // MARK: - Formatted Expiry

    var formattedExpiryDate: String? {
        guard let date = subscriptionExpiresAt else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        return f.string(from: date)
    }

    // MARK: - App Version

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
