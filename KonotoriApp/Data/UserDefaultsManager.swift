import Foundation
import SwiftUI

// MARK: - UserDefaultsManager

/// Centralised wrapper around UserDefaults / @AppStorage values.
/// Use `.shared` for imperative code; use `@AppStorage` directly in SwiftUI views for reactive binding.
final class UserDefaultsManager: ObservableObject {

    // MARK: - Singleton

    static let shared = UserDefaultsManager()

    // MARK: - Keys

    enum Key: String {
        case hasCompletedOnboarding = "hasCompletedOnboarding"
        case isPremium              = "isPremium"
        case lastNotificationScheduledAt = "lastNotificationScheduledAt"
        case cachedBabyProfileID    = "cachedBabyProfileID"
        case notificationsEnabled   = "notificationsEnabled"
    }

    // MARK: - Stored Properties

    @AppStorage("hasCompletedOnboarding")
    var hasCompletedOnboarding: Bool = false

    @AppStorage("isPremium")
    var isPremium: Bool = false

    @AppStorage("notificationsEnabled")
    var notificationsEnabled: Bool = true

    @AppStorage("cachedBabyProfileID")
    var cachedBabyProfileID: String = ""

    // Non-@AppStorage for Date (stored as TimeInterval)
    var lastNotificationScheduledAt: Date? {
        get {
            let interval = UserDefaults.standard.double(forKey: Key.lastNotificationScheduledAt.rawValue)
            guard interval > 0 else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            UserDefaults.standard.set(
                newValue?.timeIntervalSince1970 ?? 0,
                forKey: Key.lastNotificationScheduledAt.rawValue
            )
            objectWillChange.send()
        }
    }

    // MARK: - Helpers

    /// Returns true if notifications were scheduled within the last 7 days.
    var wasNotificationScheduledRecently: Bool {
        guard let last = lastNotificationScheduledAt else { return false }
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        return Date().timeIntervalSince(last) < sevenDays
    }

    /// Resets all stored values (e.g., on sign-out).
    func reset() {
        hasCompletedOnboarding = false
        isPremium = false
        notificationsEnabled = true
        cachedBabyProfileID = ""
        lastNotificationScheduledAt = nil
    }
}
