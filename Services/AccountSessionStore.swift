import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security

@MainActor
final class AccountSessionStore: ObservableObject {
    struct Profile: Equatable {
        let userIdentifier: String
        let displayName: String
        let email: String?
    }

    @Published private(set) var profile: Profile?
    @Published private(set) var isCheckingCredential = false
    @Published private(set) var isCloudAuthenticating = false
    @Published private(set) var cloudUserIdentifier: String?
    @Published private(set) var cloudLastAuthenticatedAt: Date?
    @Published var lastErrorMessage: String?

    private var pendingAppleRawNonce: String?

    private enum Keys {
        static let keychainService = "org.scriptingforschools.HomeMaintainer.account"
        static let keychainAccount = "appleUserIdentifier"
        static let cloudAccessTokenAccount = "supabaseAccessToken"
        static let cloudRefreshTokenAccount = "supabaseRefreshToken"
        static let displayName = "account.apple.displayName"
        static let email = "account.apple.email"
        static let cloudUserIdentifier = "account.supabase.userIdentifier"
        static let cloudExpiresAt = "account.supabase.expiresAt"
        static let cloudLastAuthenticatedAt = "account.supabase.lastAuthenticatedAt"
    }

    init() {
        restoreLocalProfile()
        restoreCloudSessionMetadata()
    }

    var isSignedIn: Bool { profile != nil }

    var isCloudConnected: Bool {
        SupabaseConfiguration.isConfigured &&
        cloudUserIdentifier != nil &&
        AccountKeychain.read(service: Keys.keychainService, account: Keys.cloudRefreshTokenAccount) != nil
    }

    var cloudStatusText: String {
        guard SupabaseConfiguration.isConfigured else { return "Setup Required" }
        if isCloudAuthenticating { return "Connecting…" }
        return isCloudConnected ? "Connected" : "Sign In Again"
    }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let rawNonce = Self.randomNonceString()
        pendingAppleRawNonce = rawNonce
        request.nonce = Self.sha256(rawNonce)
    }

    func handleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                lastErrorMessage = "Apple returned an unsupported sign-in credential. Please try again."
                return
            }

            let userIdentifier = credential.user
            guard AccountKeychain.save(userIdentifier, service: Keys.keychainService, account: Keys.keychainAccount) else {
                lastErrorMessage = "My Home Keeper could not securely save your Apple account identity."
                return
            }

            let defaults = UserDefaults.standard
            let existingName = defaults.string(forKey: Keys.displayName) ?? ""
            let resolvedName = formattedName(from: credential.fullName) ?? existingName
            let resolvedEmail = credential.email ?? defaults.string(forKey: Keys.email)

            if !resolvedName.isEmpty { defaults.set(resolvedName, forKey: Keys.displayName) }
            if let resolvedEmail, !resolvedEmail.isEmpty { defaults.set(resolvedEmail, forKey: Keys.email) }

            profile = Profile(
                userIdentifier: userIdentifier,
                displayName: resolvedName.isEmpty ? "Apple Account" : resolvedName,
                email: resolvedEmail
            )
            lastErrorMessage = nil

            if SupabaseConfiguration.isConfigured {
                guard let identityTokenData = credential.identityToken,
                      let identityToken = String(data: identityTokenData, encoding: .utf8),
                      let rawNonce = pendingAppleRawNonce else {
                    lastErrorMessage = "Apple sign-in succeeded locally, but the cloud identity token was unavailable. Sign out and sign in again to connect cloud sync."
                    return
                }

                Task {
                    do {
                        try await authenticateCloud(identityToken: identityToken, rawNonce: rawNonce)
                    } catch {
                        lastErrorMessage = "Apple sign-in succeeded on this device, but cloud sign-in could not be completed. \(error.localizedDescription)"
                    }
                }
            }

        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            lastErrorMessage = "Sign in with Apple could not be completed. \(error.localizedDescription)"
        }
    }

    func refreshCredentialState() {
        guard let userIdentifier = AccountKeychain.read(service: Keys.keychainService, account: Keys.keychainAccount) else {
            profile = nil
            clearCloudSession()
            return
        }

        isCheckingCredential = true
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { [weak self] state, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCheckingCredential = false

                if let error {
                    self.lastErrorMessage = "Apple account status could not be checked. \(error.localizedDescription)"
                    return
                }

                switch state {
                case .authorized:
                    self.restoreLocalProfile(userIdentifier: userIdentifier)
                    self.restoreCloudSessionMetadata()
                case .revoked, .notFound, .transferred:
                    self.clearLocalSession()
                @unknown default:
                    self.clearLocalSession()
                }
            }
        }
    }

    func validCloudAccessToken() async throws -> String {
        guard SupabaseConfiguration.isConfigured else { throw CloudSyncError.notConfigured }
        guard isSignedIn else { throw CloudSyncError.notSignedIn }

        let defaults = UserDefaults.standard
        let expiresAt = defaults.object(forKey: Keys.cloudExpiresAt) as? Date
        if let token = AccountKeychain.read(service: Keys.keychainService, account: Keys.cloudAccessTokenAccount),
           let expiresAt,
           expiresAt.timeIntervalSinceNow > 300 {
            return token
        }

        guard let refreshToken = AccountKeychain.read(service: Keys.keychainService, account: Keys.cloudRefreshTokenAccount) else {
            throw CloudSyncError.notSignedIn
        }
        return try await refreshCloudSession(refreshToken: refreshToken)
    }

    func signOut() {
        clearLocalSession()
        lastErrorMessage = nil
    }

    private func restoreLocalProfile() {
        guard let userIdentifier = AccountKeychain.read(service: Keys.keychainService, account: Keys.keychainAccount) else {
            profile = nil
            return
        }
        restoreLocalProfile(userIdentifier: userIdentifier)
    }

    private func restoreLocalProfile(userIdentifier: String) {
        let defaults = UserDefaults.standard
        let name = defaults.string(forKey: Keys.displayName)
        let email = defaults.string(forKey: Keys.email)
        profile = Profile(
            userIdentifier: userIdentifier,
            displayName: (name?.isEmpty == false ? name! : "Apple Account"),
            email: email
        )
    }

    private func restoreCloudSessionMetadata() {
        let defaults = UserDefaults.standard
        cloudUserIdentifier = defaults.string(forKey: Keys.cloudUserIdentifier)
        cloudLastAuthenticatedAt = defaults.object(forKey: Keys.cloudLastAuthenticatedAt) as? Date
    }

    private func clearLocalSession() {
        AccountKeychain.delete(service: Keys.keychainService, account: Keys.keychainAccount)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
        UserDefaults.standard.removeObject(forKey: Keys.email)
        profile = nil
        clearCloudSession()
    }

    private func clearCloudSession() {
        AccountKeychain.delete(service: Keys.keychainService, account: Keys.cloudAccessTokenAccount)
        AccountKeychain.delete(service: Keys.keychainService, account: Keys.cloudRefreshTokenAccount)
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.cloudUserIdentifier)
        defaults.removeObject(forKey: Keys.cloudExpiresAt)
        defaults.removeObject(forKey: Keys.cloudLastAuthenticatedAt)
        cloudUserIdentifier = nil
        cloudLastAuthenticatedAt = nil
    }

    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let value = PersonNameComponentsFormatter().string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func authenticateCloud(identityToken: String, rawNonce: String) async throws {
        guard let baseURL = SupabaseConfiguration.projectURL,
              let key = SupabaseConfiguration.publishableKey,
              let url = URL(string: "/auth/v1/token?grant_type=id_token", relativeTo: baseURL) else {
            throw CloudSyncError.notConfigured
        }

        isCloudAuthenticating = true
        defer { isCloudAuthenticating = false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "provider": "apple",
            "id_token": identityToken,
            "nonce": rawNonce
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudSyncError.invalidServerResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudSyncError.server(String(data: data, encoding: .utf8) ?? "Supabase sign-in failed.")
        }

        let session = try JSONDecoder().decode(CloudAuthSession.self, from: data)
        saveCloudSession(session)
        pendingAppleRawNonce = nil
    }

    private func refreshCloudSession(refreshToken: String) async throws -> String {
        guard let baseURL = SupabaseConfiguration.projectURL,
              let key = SupabaseConfiguration.publishableKey,
              let url = URL(string: "/auth/v1/token?grant_type=refresh_token", relativeTo: baseURL) else {
            throw CloudSyncError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudSyncError.invalidServerResponse }
        guard (200..<300).contains(http.statusCode) else {
            clearCloudSession()
            throw CloudSyncError.server(String(data: data, encoding: .utf8) ?? "Supabase session refresh failed.")
        }

        let session = try JSONDecoder().decode(CloudAuthSession.self, from: data)
        saveCloudSession(session)
        return session.access_token
    }

    private func saveCloudSession(_ session: CloudAuthSession) {
        guard AccountKeychain.save(session.access_token, service: Keys.keychainService, account: Keys.cloudAccessTokenAccount),
              AccountKeychain.save(session.refresh_token, service: Keys.keychainService, account: Keys.cloudRefreshTokenAccount) else {
            lastErrorMessage = "My Home Keeper could not securely save the cloud session."
            return
        }

        let now = Date()
        let defaults = UserDefaults.standard
        defaults.set(session.user.id, forKey: Keys.cloudUserIdentifier)
        defaults.set(now.addingTimeInterval(TimeInterval(session.expires_in)), forKey: Keys.cloudExpiresAt)
        defaults.set(now, forKey: Keys.cloudLastAuthenticatedAt)
        cloudUserIdentifier = session.user.id
        cloudLastAuthenticatedAt = now
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                fatalError("Unable to generate secure nonce. OSStatus \(status)")
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
        return result
    }
}

private struct CloudAuthSession: Decodable {
    struct User: Decodable { let id: String }
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let user: User
}

private enum AccountKeychain {
    static func save(_ value: String, service: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
