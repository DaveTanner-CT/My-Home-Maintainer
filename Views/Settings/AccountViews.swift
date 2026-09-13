import AuthenticationServices
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var accountSession: AccountSessionStore

    var body: some View {
        List {
            if let profile = accountSession.profile {
                signedInSection(profile)
            } else {
                signedOutSection
            }

            Section("Household Sharing") {
                Label("Shared households are the next step", systemImage: "person.2.badge.gearshape")
                    .font(.subheadline.weight(.semibold))
                Text("This version establishes your account identity. Your existing home records remain stored locally on this device until household and cloud synchronization are added in the next phases.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("My Home Keeper stores your Apple account identifier securely in the device Keychain. Apple only supplies your name and email the first time you authorize the app, so My Home Keeper keeps the values you choose to share for future sessions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { accountSession.refreshCredentialState() }
        .alert("Account", isPresented: Binding(
            get: { accountSession.lastErrorMessage != nil },
            set: { if !$0 { accountSession.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { accountSession.lastErrorMessage = nil }
        } message: {
            Text(accountSession.lastErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func signedInSection(_ profile: AccountSessionStore.Profile) -> some View {
        Section("Signed In") {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Text(initials(for: profile.displayName))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.displayName)
                        .font(.headline)
                    if let email = profile.email, !email.isEmpty {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Signed in with Apple")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            LabeledContent("Status", value: "Connected")
            if accountSession.isCheckingCredential {
                HStack {
                    ProgressView()
                    Text("Checking Apple account status…")
                        .foregroundStyle(.secondary)
                }
            }

            Button("Sign Out", role: .destructive) {
                accountSession.signOut()
            }
        }
    }

    private var signedOutSection: some View {
        Section("My Home Keeper Account") {
            VStack(alignment: .leading, spacing: 14) {
                Label("Sign in to prepare for family sharing", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline)

                Text("Sign in with Apple creates a stable account identity for My Home Keeper. Your current home data will stay on this device for now; signing in will not replace or erase it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SignInWithAppleButton(.signIn) { request in
                    accountSession.configure(request)
                } onCompletion: { result in
                    accountSession.handleAuthorization(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .accessibilityLabel("Sign in with Apple")
            }
            .padding(.vertical, 6)
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "MH" : initials.uppercased()
    }
}
