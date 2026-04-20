import UIKit
import UserNotifications
import SafariServices

final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Application Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote Notifications (APNs)

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[APNs] Device token: \(tokenString)")

        // Upload token to backend
        Task {
            do {
                try await APIClient.shared.registerDeviceToken(tokenString)
            } catch {
                print("[APNs] Failed to register device token: \(error)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] Failed to register: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Called when a notification is delivered while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user taps a notification or a notification action.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo

        // Expect "productURL" key in the notification payload
        if let urlString = userInfo["productURL"] as? String,
           let url = URL(string: urlString) {
            openSafari(url: url)
        }
    }

    // MARK: - Private Helpers

    private func openSafari(url: URL) {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController else {
            return
        }

        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemPink
        safariVC.dismissButtonStyle = .close

        // Present on the top-most view controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(safariVC, animated: true)
    }
}

// MARK: - Notification Permission Helper

extension AppDelegate {
    static func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("[Notifications] Permission request failed: \(error)")
            return false
        }
    }
}
