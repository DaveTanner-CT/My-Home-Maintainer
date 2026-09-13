import Combine
import AuthenticationServices
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
    @Published var lastErrorMessage: String?

    private enum Keys {
        static let keychainService = "org.scriptingforschools.HomeMaintainer.account"
        static let keychainAccount = "appleUserIdentifier"
        static let displayName = "account.apple.displayName"
        static let email = "account.apple.email"
    }

    init() {
        restoreLocalProfile()
    }

    var isSignedIn: Bool { profile != nil }

    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
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
                case .revoked, .notFound, .transferred:
                    self.clearLocalSession()
                @unknown default:
                    self.clearLocalSession()
                }
            }
        }
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

    private func clearLocalSession() {
        AccountKeychain.delete(service: Keys.keychainService, account: Keys.keychainAccount)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
        UserDefaults.standard.removeObject(forKey: Keys.email)
        profile = nil
    }

    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let value = PersonNameComponentsFormatter().string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
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
