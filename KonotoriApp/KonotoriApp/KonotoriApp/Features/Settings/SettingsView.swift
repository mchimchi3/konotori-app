import SwiftUI
import StoreKit

// MARK: - SettingsView

struct SettingsView: View {

    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject private var authState: AuthStateManager
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                subscriptionSection
                notificationsSection
                legalSection
                appInfoSection
                signOutSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.load() }
            .safariSheet(url: Binding(
                get: { viewModel.showPrivacyPolicy ? viewModel.privacyPolicyURL : nil },
                set: { if $0 == nil { viewModel.showPrivacyPolicy = false } }
            ))
            .safariSheet(url: Binding(
                get: { viewModel.showTerms ? viewModel.termsURL : nil },
                set: { if $0 == nil { viewModel.showTerms = false } }
            ))
            .alert("エラー", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog("サインアウトしますか？", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("サインアウト", role: .destructive) {
                    Task {
                        try? await viewModel.signOut()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            if viewModel.isPremium {
                premiumStatusRow
            } else {
                freeTierRow
                if let product = viewModel.subscriptionProduct {
                    purchaseRow(product: product)
                }
                restoreRow
            }
        } header: {
            Text("プラン")
        }
    }

    private var premiumStatusRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("プレミアムプラン", systemImage: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.headline)
                Spacer()
                Text("有効")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
            if let expiry = viewModel.formattedExpiryDate {
                Text("次回更新日: \(expiry)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var freeTierRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("無料プラン", systemImage: "sparkles")
                Spacer()
                Text("現在のプラン")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("週1件の通知 / 月3件の商品紹介")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func purchaseRow(product: Product) -> some View {
        Button {
            Task { await viewModel.purchase() }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("プレミアムにアップグレード")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("無制限の通知 + 毎週の商品提案")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if viewModel.isPurchasing {
                    ProgressView()
                } else {
                    VStack(alignment: .trailing) {
                        Text(product.displayPrice)
                            .font(.headline.bold())
                            .foregroundColor(.pink)
                        Text("/ 月")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .disabled(viewModel.isPurchasing)
    }

    private var restoreRow: some View {
        Button {
            Task { await viewModel.restorePurchases() }
        } label: {
            HStack {
                Text("購入を復元する")
                    .foregroundColor(.accentColor)
                Spacer()
                if viewModel.isRestoringPurchases {
                    ProgressView()
                }
            }
        }
        .disabled(viewModel.isRestoringPurchases)
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            HStack {
                Label("通知", systemImage: "bell.fill")
                Spacer()
                switch viewModel.notificationAuthStatus {
                case .authorized:
                    Toggle("", isOn: $viewModel.notificationsEnabled)
                        .tint(.pink)
                        .onChange(of: viewModel.notificationsEnabled) { _ in
                            Task { await viewModel.toggleNotifications() }
                        }
                case .denied:
                    Button("設定で許可する") {
                        viewModel.openNotificationSettings()
                    }
                    .font(.subheadline)
                default:
                    Button("許可する") {
                        Task { await viewModel.toggleNotifications() }
                    }
                    .font(.subheadline)
                }
            }

            if viewModel.notificationAuthStatus == .denied {
                Text("「設定」アプリから通知を許可してください。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("通知設定")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            Button {
                viewModel.showPrivacyPolicy = true
            } label: {
                Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                    .foregroundColor(.primary)
            }

            Button {
                viewModel.showTerms = true
            } label: {
                Label("利用規約", systemImage: "doc.text.fill")
                    .foregroundColor(.primary)
            }

            Button {
                viewModel.showAffiliateDisclosure = true
            } label: {
                Label("アフィリエイト開示", systemImage: "link")
                    .foregroundColor(.primary)
            }
            .sheet(isPresented: $viewModel.showAffiliateDisclosure) {
                affiliateDisclosureSheet
            }
        } header: {
            Text("法的情報")
        }
    }

    private var affiliateDisclosureSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("""
                        本アプリ「コウノトリ」は、Amazonアソシエイトプログラムに参加しています。

                        アプリ内で紹介する商品リンクはAmazon.co.jpのアフィリエイトリンクであり、リンクを経由してご購入いただいた場合、当社は紹介料を受け取ることがあります。

                        ご購入者様への追加費用は一切発生しません。

                        商品の選定にあたっては、赤ちゃんの月齢や発達段階に合わせた有益な情報提供を最優先としており、紹介料の有無に関わらず、おすすめ度の高い商品をご紹介しています。

                        ご不明な点がございましたら、設定画面のお問い合わせよりご連絡ください。
                        """)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding(24)
            }
            .navigationTitle("アフィリエイト開示")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { viewModel.showAffiliateDisclosure = false }
                }
            }
        }
    }

    // MARK: - App Info Section

    private var appInfoSection: some View {
        Section {
            HStack {
                Text("バージョン")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("アプリ情報")
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("サインアウト")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AuthStateManager())
}
