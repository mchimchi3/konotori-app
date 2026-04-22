import SwiftUI
import AuthenticationServices

// MARK: - OnboardingView

struct OnboardingView: View {

    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject private var authState: AuthStateManager

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.currentStep {
                case .signIn:
                    signInStep
                case .babyInfo:
                    babyInfoStep
                }
            }
            .animation(.easeInOut, value: viewModel.currentStep)
        }
        .onChange(of: viewModel.isComplete) { completed in
            if completed {
                authState.isAuthenticated = true
            }
        }
    }

    // MARK: - Step 1: Sign In

    private var signInStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero
            VStack(spacing: 16) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("コウノトリ")
                    .font(.largeTitle.bold())

                Text("赤ちゃんの成長に合わせて\n必要なグッズをお知らせします")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Spacer()

            // Sign In Button
            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    viewModel.handleSignInWithAppleRequest(request)
                } onCompletion: { result in
                    viewModel.handleSignInWithAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)

                if viewModel.isLoading {
                    ProgressView()
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                #if targetEnvironment(simulator)
                Button("シミュレーター用テストログイン") {
                    viewModel.skipToNextStep()
                }
                .font(.caption)
                .foregroundColor(.secondary)
                #endif

                Text("続けることで[利用規約](https://example.com/terms)および[プライバシーポリシー](https://example.com/privacy)に同意したことになります。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .padding(.horizontal)
    }

    // MARK: - Step 2: Baby Info

    private var babyInfoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("赤ちゃんの情報を\n教えてください")
                        .font(.title2.bold())
                    Text("後から変更できます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Baby Name
                VStack(alignment: .leading, spacing: 8) {
                    Label("赤ちゃんのニックネーム", systemImage: "person.fill")
                        .font(.subheadline.bold())

                    TextField("例：たろうくん", text: $viewModel.babyName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                }

                // Date Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    Label("日付の種類", systemImage: "calendar")
                        .font(.subheadline.bold())

                    Picker("日付の種類", selection: $viewModel.dateType) {
                        ForEach(OnboardingViewModel.DateType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Date Picker
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        viewModel.dateType == .dueDate ? "出産予定日" : "誕生日",
                        systemImage: "calendar.badge.clock"
                    )
                    .font(.subheadline.bold())

                    DatePicker(
                        "日付を選択",
                        selection: $viewModel.selectedDate,
                        in: viewModel.minimumDate...viewModel.maximumDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.pink)
                }

                // Error
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                // Save Button
                Button {
                    Task { await viewModel.saveBabyProfile() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("はじめる")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .disabled(!viewModel.isSavable || viewModel.isLoading)
                .cornerRadius(12)
            }
            .padding(24)
        }
        .navigationBarBackButtonHidden()
        .environment(\.locale, Locale(identifier: "ja_JP"))
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AuthStateManager())
}
