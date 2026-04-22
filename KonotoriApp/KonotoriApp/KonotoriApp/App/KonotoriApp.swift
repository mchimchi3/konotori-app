import SwiftUI
import Supabase

@main
struct KonotoriApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authState = AuthStateManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authState.isLoading {
                    SplashView()
                } else if authState.isAuthenticated {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(authState)
            .task {
                await authState.startListening()
            }
        }
    }
}

// MARK: - Auth State Manager

@MainActor
final class AuthStateManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true

    private var authListenerTask: Task<Void, Never>?

    func startListening() async {
        // Immediately check current session
        if let _ = try? await SupabaseClient.shared.auth.session {
            isAuthenticated = true
        }
        isLoading = false

        // Listen for ongoing auth changes
        authListenerTask = Task {
            for await (event, session) in SupabaseClient.shared.auth.authStateChanges {
                switch event {
                case .signedIn:
                    isAuthenticated = session != nil
                case .signedOut, .userDeleted:
                    isAuthenticated = false
                    UserDefaultsManager.shared.hasCompletedOnboarding = false
                    UserDefaultsManager.shared.isPremium = false
                default:
                    break
                }
            }
        }
    }

    func signOut() async throws {
        try await SupabaseClient.shared.auth.signOut()
    }
}

// MARK: - Supabase Client Singleton

enum SupabaseClient {
    static let shared: Supabase.SupabaseClient = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            fatalError("Supabase URL and anon key must be set in Info.plist")
        }
        return Supabase.SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}

// MARK: - Content View (Tab bar after login)

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            BabyProfileView()
                .tabItem {
                    Label("プロフィール", systemImage: "person.crop.circle.fill")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(.pink)
    }
}

// MARK: - Splash View

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bird.fill")
                .font(.system(size: 72))
                .foregroundColor(.pink)
            Text("コウノトリ")
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
