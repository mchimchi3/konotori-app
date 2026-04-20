import Foundation
import AuthenticationServices
import Supabase

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Step

    enum Step {
        case signIn
        case babyInfo
    }

    // MARK: - Published State

    @Published var currentStep: Step = .signIn
    @Published var babyName: String = ""
    @Published var dateType: DateType = .dueDate
    @Published var selectedDate: Date = Calendar.current.date(byAdding: .month, value: 2, to: Date()) ?? Date()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isComplete = false

    // MARK: - Date Type

    enum DateType: String, CaseIterable {
        case dueDate   = "予定日"
        case birthDate = "誕生日"
    }

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let userDefaultsManager: UserDefaultsManager
    private let rescheduleUseCase: RescheduleNotificationsUseCase

    // MARK: - Init

    init(
        apiClient: APIClient = .shared,
        userDefaultsManager: UserDefaultsManager = .shared,
        rescheduleUseCase: RescheduleNotificationsUseCase = .init()
    ) {
        self.apiClient = apiClient
        self.userDefaultsManager = userDefaultsManager
        self.rescheduleUseCase = rescheduleUseCase
    }

    // MARK: - Sign In With Apple

    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple IDの認証情報を取得できませんでした。"
                return
            }
            Task { await signInWithSupabase(identityToken: identityToken) }

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Sign in with Appleに失敗しました: \(error.localizedDescription)"
        }
    }

    private func signInWithSupabase(identityToken: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseClient.shared.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: identityToken)
            )
            currentStep = .babyInfo
        } catch {
            errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Date Bounds

    var minimumDate: Date {
        switch dateType {
        case .dueDate:
            // Due date must be at least today
            return Date()
        case .birthDate:
            // Birth date can be up to 2 years ago
            return Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        }
    }

    var maximumDate: Date {
        switch dateType {
        case .dueDate:
            // Due date within 10 months from now
            return Calendar.current.date(byAdding: .month, value: 10, to: Date()) ?? Date()
        case .birthDate:
            return Date()
        }
    }

    // MARK: - Save Baby Profile

    var isSavable: Bool {
        !babyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveBabyProfile() async {
        guard isSavable else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let trimmedName = babyName.trimmingCharacters(in: .whitespacesAndNewlines)

        let profile = BabyProfile(
            name: trimmedName,
            dueDate: dateType == .dueDate ? selectedDate : nil,
            birthDate: dateType == .birthDate ? selectedDate : nil
        )

        do {
            let saved = try await apiClient.createBaby(profile)
            userDefaultsManager.cachedBabyProfileID = saved.id.uuidString

            // Request notification permission then schedule
            let granted = await AppDelegate.requestNotificationPermission()
            if granted {
                try await rescheduleUseCase.execute(for: saved)
            }

            userDefaultsManager.hasCompletedOnboarding = true
            isComplete = true
        } catch {
            errorMessage = "プロフィールの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}
