import SwiftUI

// MARK: - HomeView

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.babyProfile == nil {
                    loadingView
                } else if let profile = viewModel.babyProfile {
                    contentView(profile: profile)
                } else {
                    emptyView
                }
            }
            .navigationTitle("ホーム")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
            .safariSheet(url: $viewModel.selectedProductURL)
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

    // MARK: - Content View

    private func contentView(profile: BabyProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Baby Profile Card
                babyCardView(profile: profile)

                // Next Notification Card
                if let next = viewModel.nextNotification {
                    nextNotificationCard(schedule: next)
                }

                // Milestone List
                milestoneListView
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Baby Card

    private func babyCardView(profile: BabyProfile) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.title2.bold())

                    Text(viewModel.babyAgeString(for: profile))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Image(systemName: profile.isBorn ? "figure.and.child.holdinghands" : "figure.pregnant")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom)
                    )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
    }

    // MARK: - Next Notification Card

    private func nextNotificationCard(schedule: NotificationSchedule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("次のお知らせ", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundColor(.pink)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(schedule.milestone.displayName)
                        .font(.title3.bold())

                    Text(viewModel.formattedScheduledDate(schedule.scheduledDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Days until badge
                VStack {
                    Text("\(viewModel.daysUntil(schedule.scheduledDate))")
                        .font(.title.bold())
                        .foregroundColor(.pink)
                    Text("日後")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(schedule.milestone.notificationBody)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if let url = schedule.productURL {
                Button {
                    viewModel.openProduct(url: url)
                } label: {
                    Label("おすすめ商品を見る", systemImage: "bag.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
    }

    // MARK: - Milestone List

    private var milestoneListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("マイルストーン")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(viewModel.upcomingMilestones) { item in
                milestoneRow(item: item)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
    }

    private func milestoneRow(item: HomeViewModel.MilestoneItem) -> some View {
        HStack(spacing: 12) {
            // Circle indicator
            ZStack {
                Circle()
                    .fill(item.isCompleted ? Color.pink : Color(.systemGray5))
                    .frame(width: 28, height: 28)

                if item.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.pink.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.schedule.milestone.displayName)
                    .font(.subheadline)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                    .strikethrough(item.isCompleted)

                Text(viewModel.formattedScheduledDate(item.schedule.scheduledDate))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !item.isPast {
                Text("あと\(viewModel.daysUntil(item.schedule.scheduledDate))日")
                    .font(.caption.bold())
                    .foregroundColor(.pink)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("読み込み中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("まだプロフィールがありません")
                .font(.headline)
            Text("プロフィールタブから赤ちゃんの情報を登録しましょう。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
