import Foundation
import Supabase

// MARK: - APIClient

/// Async/await HTTP client for the Konotori Railway backend.
/// Attaches the current Supabase JWT as Bearer token on every request.
final class APIClient {

    // MARK: - Singleton

    static let shared = APIClient()

    // MARK: - Configuration

    private let baseURL: URL = {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String,
            let url = URL(string: urlString)
        else {
            fatalError("BACKEND_BASE_URL must be set in Info.plist")
        }
        return url
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // MARK: - Auth Header

    private func authorizationHeader() async throws -> String {
        let session = try await SupabaseClient.shared.auth.session
        return "Bearer \(session.accessToken)"
    }

    // MARK: - Request Builder

    private func makeRequest(
        method: String,
        path: String,
        body: Data? = nil
    ) async throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(try await authorizationHeader(), forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    // MARK: - Generic Perform

    private func perform<T: Decodable>(_ request: URLRequest, type: T.Type) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: serverMessage)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Babies Endpoints

    /// POST /babies — Creates a new baby profile on the backend.
    @discardableResult
    func createBaby(_ profile: BabyProfile) async throws -> BabyProfile {
        let body = try encoder.encode(profile)
        let request = try await makeRequest(method: "POST", path: "/babies", body: body)
        return try await perform(request, type: BabyProfile.self)
    }

    /// GET /babies — Returns all baby profiles for the authenticated user.
    func getBabies() async throws -> [BabyProfile] {
        let request = try await makeRequest(method: "GET", path: "/babies")
        return try await perform(request, type: [BabyProfile].self)
    }

    /// PUT /babies/:id — Updates an existing baby profile.
    @discardableResult
    func updateBaby(_ profile: BabyProfile) async throws -> BabyProfile {
        let body = try encoder.encode(profile)
        let request = try await makeRequest(method: "PUT", path: "/babies/\(profile.id)", body: body)
        return try await perform(request, type: BabyProfile.self)
    }

    // MARK: - Device Token

    /// POST /device-tokens — Registers the APNs device token for push notifications.
    func registerDeviceToken(_ token: String) async throws {
        struct TokenPayload: Encodable { let token: String; let platform: String }
        let payload = TokenPayload(token: token, platform: "ios")
        let body = try encoder.encode(payload)
        let request = try await makeRequest(method: "POST", path: "/device-tokens", body: body)

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
    }

    // MARK: - Subscription

    /// POST /subscription/verify — Sends StoreKit receipt/transaction ID for server-side verification.
    func verifySubscription(transactionID: String) async throws -> SubscriptionStatus {
        struct VerifyPayload: Encodable { let transactionID: String }
        let body = try encoder.encode(VerifyPayload(transactionID: transactionID))
        let request = try await makeRequest(method: "POST", path: "/subscription/verify", body: body)
        return try await perform(request, type: SubscriptionStatus.self)
    }
}

// MARK: - Supporting Types

struct SubscriptionStatus: Decodable {
    let isPremium: Bool
    let expiresAt: Date?
}

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "サーバーからの応答が無効です。"
        case .httpError(let code, let message):
            return "エラー \(code): \(message)"
        case .decodingError(let err):
            return "データの解析に失敗しました: \(err.localizedDescription)"
        case .unauthorized:
            return "ログインが必要です。"
        }
    }
}
