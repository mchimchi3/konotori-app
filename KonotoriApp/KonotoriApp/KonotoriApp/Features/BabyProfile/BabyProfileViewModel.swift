import Foundation

// MARK: - BabyProfileViewModel

@MainActor
final class BabyProfileViewModel: ObservableObject {

    // MARK: - Published State

    @Published var profile: BabyProfile?
    @Published var editedName: String = ""
    @Published var editedDueDate: Date? = nil
    @Published var editedBirthDate: Date? = nil
    @Published var hasDueDate: Bool = false
    @Published var hasBirthDate: Bool = false
    @Published var dueDateValue: Date = Date()
    @Published var birthDateValue: Date = Date()

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var saveSuccess = false

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let rescheduleUseCase: RescheduleNotificationsUseCase

    // MARK: - Init

    init(
        apiClient: APIClient = .shared,
        rescheduleUseCase: RescheduleNotificationsUseCase = .init()
    ) {
        self.apiClient = apiClient
        self.rescheduleUseCase = rescheduleUseCase
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        #if targetEnvironment(simulator)
        let mock = BabyProfile(name: "テストちゃん", dueDate: Calendar.current.date(byAdding: .month, value: 2, to: Date()), birthDate: nil)
        self.profile = mock
        populateFields(from: mock)
        return
        #endif

        do {
            let profiles = try await apiClient.getBabies()
            if let p = profiles.first {
                self.profile = p
                populateFields(from: p)
            }
        } catch {
            errorMessage = "プロフィールの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    private func populateFields(from profile: BabyProfile) {
        editedName = profile.name
        if let due = profile.dueDate {
            hasDueDate = true
            dueDateValue = due
        }
        if let birth = profile.birthDate {
            hasBirthDate = true
            birthDateValue = birth
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasChanges: Bool {
        guard let profile = profile else { return true }
        let nameChanged = editedName != profile.name
        let dueDateChanged = (hasDueDate ? dueDateValue : nil) != profile.dueDate
        let birthDateChanged = (hasBirthDate ? birthDateValue : nil) != profile.birthDate
        return nameChanged || dueDateChanged || birthDateChanged
    }

    // MARK: - Save

    func save() async {
        guard isValid, let profile = profile else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        saveSuccess = false

        let updated = BabyProfile(
            id: profile.id,
            name: editedName.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDateValue : nil,
            birthDate: hasBirthDate ? birthDateValue : nil,
            createdAt: profile.createdAt
        )

        do {
            let saved = try await apiClient.updateBaby(updated)
            self.profile = saved

            // Re-schedule notifications with updated dates
            try? await rescheduleUseCase.execute(for: saved)

            saveSuccess = true
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Date Bounds

    var minimumDueDate: Date {
        Date()
    }

    var maximumDueDate: Date {
        Calendar.current.date(byAdding: .month, value: 10, to: Date()) ?? Date()
    }

    var minimumBirthDate: Date {
        Calendar.current.date(byAdding: .year, value: -3, to: Date()) ?? Date()
    }

    var maximumBirthDate: Date {
        Date()
    }
}
