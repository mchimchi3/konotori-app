import Foundation
import UserNotifications

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published State

    @Published var babyProfile: BabyProfile?
    @Published var nextNotification: NotificationSchedule?
    @Published var upcomingMilestones: [MilestoneItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedProductURL: URL?

    // MARK: - Milestone Item (for the list)

    struct MilestoneItem: Identifiable {
        let id: UUID
        let schedule: NotificationSchedule
        var isCompleted: Bool
        var isPast: Bool { schedule.scheduledDate < Date() }
    }

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let rescheduleUseCase: RescheduleNotificationsUseCase
    private let notificationCenter: UNUserNotificationCenter

    // MARK: - Init

    init(
        apiClient: APIClient = .shared,
        rescheduleUseCase: RescheduleNotificationsUseCase = .init(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.apiClient = apiClient
        self.rescheduleUseCase = rescheduleUseCase
        self.notificationCenter = notificationCenter
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let profiles = try await apiClient.getBabies()
            guard let profile = profiles.first else { return }
            self.babyProfile = profile
            await buildMilestoneItems(for: profile)
        } catch {
            errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Milestone Building

    private func buildMilestoneItems(for profile: BabyProfile) async {
        guard let referenceDate = profile.referenceDate else { return }

        var items: [MilestoneItem] = []

        for milestone in Milestone.allCases {
            let anchorDate: Date
            if milestone.usesPreBirthAnchor {
                guard let dueDate = profile.dueDate else { continue }
                anchorDate = dueDate
            } else {
                anchorDate = referenceDate
            }

            let schedule = NotificationSchedule(
                milestone: milestone,
                referenceDate: anchorDate,
                babyProfileID: profile.id
            )

            let item = MilestoneItem(
                id: schedule.id,
                schedule: schedule,
                isCompleted: schedule.scheduledDate < Date()
            )
            items.append(item)
        }

        // Sort chronologically
        items.sort { $0.schedule.scheduledDate < $1.schedule.scheduledDate }
        upcomingMilestones = items

        // The next upcoming (future) notification
        nextNotification = items.first { !$0.isPast }?.schedule
    }

    // MARK: - Pending Notifications

    func pendingNotificationCount() async -> Int {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.count
    }

    // MARK: - Formatted Dates

    func formattedScheduledDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func daysUntil(_ date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        return max(0, days)
    }

    func babyAgeString(for profile: BabyProfile) -> String {
        guard let ref = profile.referenceDate else { return "" }
        let components = Calendar.current.dateComponents([.month, .day], from: ref, to: Date())
        let months = components.month ?? 0
        let days = components.day ?? 0

        if profile.isBorn {
            if months > 0 {
                return "生後\(months)ヶ月\(days)日"
            } else {
                return "生後\(days)日"
            }
        } else {
            // Before birth: show countdown
            let remaining = Calendar.current.dateComponents([.day], from: Date(), to: ref).day ?? 0
            return "出産まであと\(remaining)日"
        }
    }

    // MARK: - Open Product

    func openProduct(url: URL) {
        selectedProductURL = url
    }
}
