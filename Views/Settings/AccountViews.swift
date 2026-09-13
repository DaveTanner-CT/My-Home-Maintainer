import AuthenticationServices
import SwiftData
import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var accountSession: AccountSessionStore
    @Query private var households: [Household]

    var body: some View {
        List {
            if let profile = accountSession.profile {
                signedInSection(profile)
            } else {
                signedOutSection
            }

            Section("Household Sharing") {
                NavigationLink {
                    HouseholdSetupView()
                } label: {
                    HStack {
                        Label("Household", systemImage: "person.2")
                        Spacer()
                        Text(households.first?.name ?? "Set Up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let household = households.first {
                    Text("This device is prepared for household sharing with \(household.members.count) member\(household.members.count == 1 ? "" : "s"). Private iCloud synchronization is available from Settings → iCloud Sync.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Create a household around the home already on this device. Your existing records will not be moved, duplicated, or erased.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Privacy") {
                Text("My Home Keeper stores your Sign in with Apple identifier securely in the device Keychain. Home cloud data is stored separately in your private iCloud CloudKit database. The developer does not receive that private household database through the app backend.")
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
