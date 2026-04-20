import SwiftUI

// MARK: - BabyProfileView

struct BabyProfileView: View {

    @StateObject private var viewModel = BabyProfileViewModel()
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    formView
                }
            }
            .navigationTitle("赤ちゃんのプロフィール")
            .navigationBarTitleDisplayMode(.large)
            .toolbar { saveButton }
            .task { await viewModel.load() }
            .alert("保存しました", isPresented: $viewModel.saveSuccess) {
                Button("OK") {}
            }
            .alert("エラー", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            // Name Section
            Section {
                HStack {
                    Label("ニックネーム", systemImage: "person.fill")
                    Spacer()
                    TextField("例：はなちゃん", text: $viewModel.editedName)
                        .multilineTextAlignment(.trailing)
                        .focused($nameFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFieldFocused = false }
                }
            } header: {
                Text("基本情報")
            }

            // Due Date Section
            Section {
                Toggle(isOn: $viewModel.hasDueDate) {
                    Label("出産予定日を設定", systemImage: "calendar.badge.plus")
                }
                .tint(.pink)

                if viewModel.hasDueDate {
                    DatePicker(
                        "出産予定日",
                        selection: $viewModel.dueDateValue,
                        in: viewModel.minimumDueDate...viewModel.maximumDueDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(.pink)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
            } header: {
                Text("出産予定日")
            } footer: {
                Text("妊娠中の方はこちらを設定してください。出産後は誕生日と両方設定できます。")
                    .font(.caption)
            }

            // Birth Date Section
            Section {
                Toggle(isOn: $viewModel.hasBirthDate) {
                    Label("誕生日を設定", systemImage: "gift.fill")
                }
                .tint(.pink)

                if viewModel.hasBirthDate {
                    DatePicker(
                        "誕生日",
                        selection: $viewModel.birthDateValue,
                        in: viewModel.minimumBirthDate...viewModel.maximumBirthDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .tint(.pink)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                }
            } header: {
                Text("誕生日")
            } footer: {
                Text("誕生日を設定すると、出産後のマイルストーンが自動で更新されます。")
                    .font(.caption)
            }

            // Info Section
            if let profile = viewModel.profile {
                Section {
                    HStack {
                        Text("登録日")
                        Spacer()
                        Text(profile.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("プロフィールID")
                        Spacer()
                        Text(profile.id.uuidString.prefix(8) + "...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("プロフィール情報")
                }
            }
        }
    }

    // MARK: - Save Button

    @ToolbarContentBuilder
    private var saveButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if viewModel.isSaving {
                ProgressView()
            } else {
                Button("保存") {
                    nameFieldFocused = false
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.isValid || !viewModel.hasChanges)
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BabyProfileView()
}
