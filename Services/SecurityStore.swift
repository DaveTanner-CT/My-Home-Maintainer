import Combine
import CryptoKit
import Foundation
import LocalAuthentication
import Security

@MainActor
final class SecurityStore: ObservableObject {
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isAuthenticationInProgress = false

    private var automaticBiometricAttemptedForCurrentLock = false
    private var suppressLifecycleLockingUntil: Date?

    private enum Keys {
        static let keychainService = "org.scriptingforschools.HomeMaintainer.security"
        static let pinDigestAccount = "appLockPinDigest"
        static let pinSaltAccount = "appLockPinSalt"

        static let appLockEnabled = "security.appLockEnabled"
        static let biometricsEnabled = "security.biometricsEnabled"
        static let lockDelaySeconds = "security.lockDelaySeconds"
        static let backgroundedAt = "security.backgroundedAt"
    }

    init() {
        isUnlocked = !UserDefaults.standard.bool(forKey: Keys.appLockEnabled)
    }

    var isAppLockEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.appLockEnabled)
    }

    var biometricsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.biometricsEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.biometricsEnabled)
            objectWillChange.send()
        }
    }

    var lockDelaySeconds: Int {
        get {
            let stored = UserDefaults.standard.object(forKey: Keys.lockDelaySeconds) as? Int
            return stored ?? 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lockDelaySeconds)
            objectWillChange.send()
        }
    }

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    var biometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func setAppCode(_ code: String) -> Bool {
        guard isValidCode(code) else {
            lastErrorMessage = "Enter exactly four numbers."
            return false
        }

        var salt = Data(count: 16)
        let result = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, bytes.baseAddress!)
        }
        guard result == errSecSuccess else {
            lastErrorMessage = "My Home Keeper could not create a secure app code."
            return false
        }

        let digest = digestForCode(code, salt: salt)
        guard SecurityKeychain.saveData(salt, service: Keys.keychainService, account: Keys.pinSaltAccount),
              SecurityKeychain.saveData(digest, service: Keys.keychainService, account: Keys.pinDigestAccount) else {
            lastErrorMessage = "My Home Keeper could not securely save your app code."
            return false
        }

        UserDefaults.standard.set(true, forKey: Keys.appLockEnabled)
        isUnlocked = true
        lastErrorMessage = nil
        objectWillChange.send()
        return true
    }

    func validate(code: String) -> Bool {
        guard isValidCode(code),
              let salt = SecurityKeychain.readData(service: Keys.keychainService, account: Keys.pinSaltAccount),
              let storedDigest = SecurityKeychain.readData(service: Keys.keychainService, account: Keys.pinDigestAccount) else {
            return false
        }
        return digestForCode(code, salt: salt) == storedDigest
    }

    func unlock(code: String) -> Bool {
        guard validate(code: code) else {
            lastErrorMessage = "That code did not match."
            return false
        }
        completeUnlock()
        return true
    }

    func disableAppLock() {
        SecurityKeychain.delete(service: Keys.keychainService, account: Keys.pinDigestAccount)
        SecurityKeychain.delete(service: Keys.keychainService, account: Keys.pinSaltAccount)
        UserDefaults.standard.set(false, forKey: Keys.appLockEnabled)
        UserDefaults.standard.set(false, forKey: Keys.biometricsEnabled)
        UserDefaults.standard.removeObject(forKey: Keys.backgroundedAt)
        isUnlocked = true
        lastErrorMessage = nil
        objectWillChange.send()
    }

    func lockNow() {
        engageLock()
    }

    func unlockAfterDeviceOwnerAuthentication() {
        completeUnlock()
    }

    func applicationDidEnterBackground() {
        guard isAppLockEnabled else { return }

        // LocalAuthentication can generate lifecycle transitions while Face ID / Touch ID
        // is being presented or dismissed. Ignore those transitions so the biometric
        // sheet cannot create a fresh lock cycle.
        guard !isAuthenticationInProgress, !isLifecycleLockingSuppressed else { return }

        let now = Date()
        UserDefaults.standard.set(now, forKey: Keys.backgroundedAt)
        if lockDelaySeconds == 0 {
            engageLock(clearTimestamp: false)
        }
    }

    func applicationDidBecomeActive() {
        guard isAppLockEnabled else {
            isUnlocked = true
            clearBackgroundTimestamp()
            return
        }

        // Ignore activation transitions created by LocalAuthentication. A successful
        // biometric unlock sets a short suppression window so any delayed scene event
        // cannot immediately lock the app again.
        guard !isAuthenticationInProgress, !isLifecycleLockingSuppressed else {
            clearBackgroundTimestamp()
            return
        }

        guard let backgroundedAt = UserDefaults.standard.object(forKey: Keys.backgroundedAt) as? Date else {
            return
        }

        clearBackgroundTimestamp()

        if Date().timeIntervalSince(backgroundedAt) >= TimeInterval(lockDelaySeconds) {
            engageLock(clearTimestamp: false)
        }
    }

    func attemptAutomaticBiometricUnlockIfNeeded() async {
        guard isAppLockEnabled,
              !isUnlocked,
              biometricsEnabled,
              biometricsAvailable,
              !automaticBiometricAttemptedForCurrentLock,
              !isAuthenticationInProgress else { return }

        // This flag lives in the store rather than AppLockView so rebuilding the
        // SwiftUI lock screen cannot repeatedly trigger Face ID.
        automaticBiometricAttemptedForCurrentLock = true
        _ = await unlockWithBiometrics()
    }

    func unlockWithBiometrics() async -> Bool {
        guard biometricsEnabled, !isAuthenticationInProgress else { return false }
        let success = await authenticate(
            policy: .deviceOwnerAuthenticationWithBiometrics,
            reason: "Unlock My Home Keeper"
        )
        if success {
            completeUnlock()
        }
        return success
    }

    func authenticateDeviceOwner(reason: String) async -> Bool {
        await authenticate(policy: .deviceOwnerAuthentication, reason: reason)
    }

    func canAuthenticateDeviceOwner() -> Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    private func authenticate(policy: LAPolicy, reason: String) async -> Bool {
        guard !isAuthenticationInProgress else { return false }

        // Clear any pending background timestamp before presenting system authentication
        // and suppress lifecycle-based relocking while that UI is on screen.
        clearBackgroundTimestamp()
        suppressLifecycleLocking(for: 3)
        isAuthenticationInProgress = true
        defer {
            isAuthenticationInProgress = false
            suppressLifecycleLocking(for: 3)
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else {
            lastErrorMessage = error?.localizedDescription ?? "Device authentication is not available."
            return false
        }

        do {
            let result = try await context.evaluatePolicy(policy, localizedReason: reason)
            if !result {
                lastErrorMessage = "Authentication was not completed."
            }
            return result
        } catch {
            if let laError = error as? LAError, laError.code == .userCancel || laError.code == .appCancel {
                return false
            }
            lastErrorMessage = error.localizedDescription
            return false
        }
    }


    private func completeUnlock() {
        isUnlocked = true
        clearBackgroundTimestamp()
        suppressLifecycleLocking(for: 3)
        lastErrorMessage = nil
    }

    private func engageLock(clearTimestamp: Bool = true) {
        guard isAppLockEnabled else { return }
        if clearTimestamp {
            clearBackgroundTimestamp()
        }

        // Do not create another lock session while the lock screen is already showing.
        // Re-engaging an existing lock used to reset the one-time biometric flag, which
        // could cause Face ID to launch again every time a lifecycle event arrived.
        guard isUnlocked else { return }

        automaticBiometricAttemptedForCurrentLock = false
        isUnlocked = false
    }

    private var isLifecycleLockingSuppressed: Bool {
        guard let until = suppressLifecycleLockingUntil else { return false }
        if Date() < until {
            return true
        }
        suppressLifecycleLockingUntil = nil
        return false
    }

    private func suppressLifecycleLocking(for seconds: TimeInterval) {
        suppressLifecycleLockingUntil = Date().addingTimeInterval(seconds)
    }

    private func clearBackgroundTimestamp() {
        UserDefaults.standard.removeObject(forKey: Keys.backgroundedAt)
    }

    private func isValidCode(_ code: String) -> Bool {
        code.count == 4 && code.allSatisfy(\.isNumber)
    }

    private func digestForCode(_ code: String, salt: Data) -> Data {
        var data = Data()
        data.append(salt)
        data.append(Data(code.utf8))
        return Data(SHA256.hash(data: data))
    }
}

enum SecurityKeychain {
    static func saveData(_ value: Data, service: String, account: String) -> Bool {
        delete(service: service, account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: value
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func readData(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
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
