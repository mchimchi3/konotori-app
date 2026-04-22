import Foundation
import UserNotifications

// MARK: - RescheduleNotificationsUseCase

/// Cancels all pending local notifications and regenerates them from a BabyProfile.
/// Respects the freemium limit: free users get max 1 notification per week (we schedule all
/// but throttle delivery via a per-week cap enforced at scheduling time).
final class RescheduleNotificationsUseCase {

    // MARK: - Dependencies

    private let notificationCenter: UNUserNotificationCenter
    private let userDefaultsManager: UserDefaultsManager

    // MARK: - Constants

    /// Maximum local notifications iOS allows: 64. We stay well under.
    private static let maxScheduledNotifications = 60

    // MARK: - Init

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaultsManager: UserDefaultsManager = .shared
    ) {
        self.notificationCenter = notificationCenter
        self.userDefaultsManager = userDefaultsManager
    }

    // MARK: - Execute

    /// Builds a fresh notification schedule from the given profile and schedules local notifications.
    /// - Parameter profile: The baby's profile containing dueDate and/or birthDate.
    /// - Returns: Array of NotificationSchedule objects that were successfully scheduled.
    @discardableResult
    func execute(for profile: BabyProfile) async throws -> [NotificationSchedule] {
        // 1. Verify permission is granted
        let settings = await notificationCenter.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            throw NotificationError.permissionDenied
        }

        // 2. Cancel all existing pending notifications
        notificationCenter.removeAllPendingNotificationRequests()

        // 3. Build the schedule
        let schedules = buildSchedule(for: profile)

        // 4. Filter to only future notifications
        let futureSchedules = schedules.filter { $0.isFuture }

        // 5. Apply freemium throttle: free users get 1 notification/week max
        let schedulesToApply: [NotificationSchedule]
        if userDefaultsManager.isPremium {
            schedulesToApply = Array(futureSchedules.prefix(Self.maxScheduledNotifications))
        } else {
            schedulesToApply = throttleToOnePerWeek(futureSchedules)
        }

        // 6. Schedule each notification
        for schedule in schedulesToApply {
            let content = schedule.makeNotificationContent()
            let triggerDate = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: schedule.scheduledDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            let request = UNNotificationRequest(
                identifier: schedule.id.uuidString,
                content: content,
                trigger: trigger
            )
            try await notificationCenter.add(request)
        }

        // 7. Record timestamp
        userDefaultsManager.lastNotificationScheduledAt = Date()

        print("[Notifications] Scheduled \(schedulesToApply.count) notifications for \(profile.name)")
        return schedulesToApply
    }

    // MARK: - Build Schedule

    private func buildSchedule(for profile: BabyProfile) -> [NotificationSchedule] {
        var schedules: [NotificationSchedule] = []

        for milestone in Milestone.allCases {
            // Pre-birth milestones need dueDate
            if milestone.usesPreBirthAnchor {
                guard let dueDate = profile.dueDate else { continue }
                let schedule = NotificationSchedule(
                    milestone: milestone,
                    referenceDate: dueDate,
                    babyProfileID: profile.id
                )
                schedules.append(schedule)
            } else {
                // Post-birth milestones prefer birthDate, fall back to dueDate
                guard let referenceDate = profile.referenceDate else { continue }
                let schedule = NotificationSchedule(
                    milestone: milestone,
                    referenceDate: referenceDate,
                    babyProfileID: profile.id
                )
                schedules.append(schedule)
            }
        }

        // Sort chronologically
        return schedules.sorted { $0.scheduledDate < $1.scheduledDate }
    }

    // MARK: - Freemium Throttle

    /// Returns at most 1 notification per calendar week.
    private func throttleToOnePerWeek(_ schedules: [NotificationSchedule]) -> [NotificationSchedule] {
        var result: [NotificationSchedule] = []
        var seenWeeks = Set<String>()

        for schedule in schedules {
            let weekKey = weekKey(for: schedule.scheduledDate)
            if !seenWeeks.contains(weekKey) {
                seenWeeks.insert(weekKey)
                result.append(schedule)
            }
            if result.count >= Self.maxScheduledNotifications { break }
        }
        return result
    }

    private func weekKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
}

// MARK: - Errors

enum NotificationError: LocalizedError {
    case permissionDenied
    case schedulingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "通知の許可が必要です。設定アプリから許可してください。"
        case .schedulingFailed(let underlying):
            return "通知のスケジューリングに失敗しました: \(underlying.localizedDescription)"
        }
    }
}
