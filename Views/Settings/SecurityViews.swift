import Foundation
import SwiftData
import SwiftUI
import UIKit

struct AppLockSettingsView: View {
    @EnvironmentObject private var securityStore: SecurityStore
    @State private var showingSetCode = false
    @State private var changingCode = false
    @State private var showDisableConfirmation = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("App Lock") {
                LabeledContent("4-Digit App Code") {
                    if securityStore.isAppLockEnabled {
                        Text("On")
                    } else {
                        Text("Off")
                            .foregroundStyle(.secondary)
                    }
                }

                if securityStore.isAppLockEnabled {
                    Picker("Lock app after", selection: Binding(
                        get: { securityStore.lockDelaySeconds },
                        set: { securityStore.lockDelaySeconds = $0 }
                    )) {
                        Text("Immediately").tag(0)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                        Text("15 minutes").tag(900)
                    }

                    if securityStore.biometricsAvailable {
                        Toggle(
                            "Use \(securityStore.biometryName)",
                            isOn: Binding(
                                get: { securityStore.biometricsEnabled },
                                set: { securityStore.biometricsEnabled = $0 }
                            )
                        )
                    }

                    Button("Change 4-Digit App Code") {
                        Task {
                            let authorized: Bool
                            if securityStore.canAuthenticateDeviceOwner() {
                                authorized = await securityStore.authenticateDeviceOwner(reason: "Change your My Home Keeper app code")
                            } else {
                                authorized = securityStore.isUnlocked
                            }
                            if authorized {
                                changingCode = true
                                showingSetCode = true
                            }
                        }
                    }

                    Button("Lock Now") {
                        securityStore.lockNow()
                    }

                    Button("Turn Off App Lock", role: .destructive) {
                        showDisableConfirmation = true
                    }
                } else {
                    Button("Set Up App Lock") {
                        changingCode = false
                        showingSetCode = true
                    }
                }
            }

            Section {
                Text("Your app code is stored only in the iPhone or iPad Keychain. It is not included in household iCloud sharing or exports.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Security")
        .sheet(isPresented: $showingSetCode) {
            NavigationStack {
                AppCodeSetupView(isChanging: changingCode) { code in
                    if securityStore.setAppCode(code) {
                        if securityStore.biometricsAvailable {
                            securityStore.biometricsEnabled = true
                        }
                        showingSetCode = false
                        message = changingCode ? "Your app code was changed." : "App Lock is now on."
                    }
                }
                .environmentObject(securityStore)
            }
            .interactiveDismissDisabled()
        }
        .confirmationDialog(
            "Turn Off App Lock?",
            isPresented: $showDisableConfirmation,
            titleVisibility: .visible
        ) {
            Button("Turn Off App Lock", role: .destructive) {
                Task {
                    let authorized: Bool
                    if securityStore.canAuthenticateDeviceOwner() {
                        authorized = await securityStore.authenticateDeviceOwner(
                            reason: "Turn off My Home Keeper App Lock"
                        )
                    } else {
                        authorized = securityStore.isUnlocked
                    }
                    if authorized {
                        securityStore.disableAppLock()
                        message = "App Lock was turned off."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your saved Passwords & Codes will remain protected by device authentication when you reveal or copy them.")
        }
        .alert("Security", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }
}

private struct AppCodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var securityStore: SecurityStore
    let isChanging: Bool
    let onComplete: (String) -> Void

    @State private var firstCode = ""
    @State private var currentCode = ""
    @State private var confirming = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 44))
                Text(confirming ? "Confirm App Code" : (isChanging ? "New App Code" : "Create App Code"))
                    .font(.title2.bold())
                Text(confirming ? "Enter the same four numbers again." : "Choose four numbers you can remember.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            AppCodeDots(count: currentCode.count)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            AppCodeKeypad(code: $currentCode) {
                submitCurrentCode()
            }

            Spacer(minLength: 0)
        }
        .padding()
        .navigationTitle("App Lock")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func submitCurrentCode() {
        guard currentCode.count == 4 else { return }
        if confirming {
            guard currentCode == firstCode else {
                errorMessage = "The codes did not match. Try again."
                currentCode = ""
                return
            }
            onComplete(currentCode)
        } else {
            firstCode = currentCode
            currentCode = ""
            confirming = true
            errorMessage = nil
        }
    }
}

struct AppLockView: View {
    @EnvironmentObject private var securityStore: SecurityStore
    @State private var code = ""
    @State private var errorMessage: String?
    @State private var attemptedBiometrics = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "house.and.flag.fill")
                    .font(.system(size: 52))
                Text("My Home Keeper")
                    .font(.title.bold())
                Text("Enter your 4-digit app code")
                    .foregroundStyle(.secondary)

                AppCodeDots(count: code.count)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                AppCodeKeypad(code: $code) {
                    if securityStore.unlock(code: code) {
                        code = ""
                        errorMessage = nil
                    } else {
                        code = ""
                        errorMessage = "That code did not match."
                    }
                }

                if securityStore.biometricsEnabled && securityStore.biometricsAvailable {
                    Button {
                        Task { _ = await securityStore.unlockWithBiometrics() }
                    } label: {
                        Label("Use \(securityStore.biometryName)", systemImage: "faceid")
                    }
                    .buttonStyle(.bordered)
                }

                Button("Forgot App Code?") {
                    Task {
                        if await securityStore.authenticateDeviceOwner(reason: "Unlock My Home Keeper so you can change your app code") {
                            // Device-owner authentication proves access to this device.
                            // Unlock this session; the code can then be changed in Settings > Security.
                            securityStore.unlockAfterDeviceOwnerAuthentication()
                            errorMessage = nil
                        } else {
                            errorMessage = securityStore.lastErrorMessage ?? "Device authentication was not completed."
                        }
                    }
                }
                .font(.footnote)

                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .task {
            guard !attemptedBiometrics,
                  securityStore.biometricsEnabled,
                  securityStore.biometricsAvailable else { return }
            attemptedBiometrics = true
            _ = await securityStore.unlockWithBiometrics()
        }
    }
}

private struct AppCodeDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.primary : Color.clear)
                    .overlay(Circle().stroke(Color.secondary, lineWidth: 1.5))
                    .frame(width: 16, height: 16)
            }
        }
        .accessibilityLabel("\(count) of 4 digits entered")
    }
}

private struct AppCodeKeypad: View {
    @Binding var code: String
    let completed: () -> Void

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(row, id: \.self) { digit in
                        keyButton(digit)
                    }
                }
            }
            HStack(spacing: 18) {
                Color.clear.frame(width: 68, height: 54)
                keyButton("0")
                Button {
                    if !code.isEmpty { code.removeLast() }
                } label: {
                    Image(systemName: "delete.left")
                        .font(.title2)
                        .frame(width: 68, height: 54)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func keyButton(_ digit: String) -> some View {
        Button {
            guard code.count < 4 else { return }
            code.append(digit)
            if code.count == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    completed()
                }
            }
        } label: {
            Text(digit)
                .font(.title2.weight(.semibold))
                .frame(width: 68, height: 54)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

struct PasswordsAndCodesView: View {
    @EnvironmentObject private var securityStore: SecurityStore
    @StateObject private var store = SecureCodeStore()
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                Text("Home-related passwords and codes are stored only on this device. They are not included in household iCloud sync, sharing, or data exports in version 0.50.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if store.entries.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Passwords or Codes",
                        systemImage: "key.horizontal",
                        description: Text("Save things such as Wi-Fi passwords, garage codes, alarm codes, lockbox codes, and equipment PINs.")
                    )
                }
            } else {
                ForEach(SecureCodeEntry.Category.allCases) { category in
                    let categoryEntries = store.entries.filter { $0.category == category }
                    if !categoryEntries.isEmpty {
                        Section(category.rawValue) {
                            ForEach(categoryEntries) { entry in
                                NavigationLink {
                                    SecureCodeDetailView(entryID: entry.id, store: store)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: category.systemImage)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.title)
                                            if !entry.relatedItem.isEmpty {
                                                Text(entry.relatedItem)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Text("••••••")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Passwords & Codes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add password or code")
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                SecureCodeFormView(store: store)
            }
        }
    }
}

private struct SecureCodeDetailView: View {
    @EnvironmentObject private var securityStore: SecurityStore
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @ObservedObject var store: SecureCodeStore

    @State private var revealedSecret: String?
    @State private var showingEdit = false
    @State private var showingDelete = false
    @State private var message: String?

    private var entry: SecureCodeEntry? {
        store.entries.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                List {
                    Section("Details") {
                        LabeledContent("Category", value: entry.category.rawValue)
                        if !entry.username.isEmpty {
                            LabeledContent("Username / Email", value: entry.username)
                        }
                        if !entry.relatedItem.isEmpty {
                            LabeledContent("Related to", value: entry.relatedItem)
                        }
                    }

                    Section("Password / Code") {
                        HStack {
                            if let revealedSecret {
                                Text(revealedSecret)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                            } else {
                                Text("••••••••••")
                                    .font(.body.monospaced())
                            }
                            Spacer()
                            Button(revealedSecret == nil ? "Show" : "Hide") {
                                if revealedSecret == nil {
                                    reveal(entry)
                                } else {
                                    revealedSecret = nil
                                }
                            }
                        }

                        Button {
                            copySecret(entry)
                        } label: {
                            Label("Copy Password / Code", systemImage: "doc.on.doc")
                        }
                    }

                    if !entry.notes.isEmpty {
                        Section("Notes") {
                            Text(entry.notes)
                        }
                    }

                    Section {
                        Button("Delete", role: .destructive) {
                            showingDelete = true
                        }
                    }
                }
                .navigationTitle(entry.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            Task {
                                if await authorize(reason: "Edit \(entry.title)") {
                                    showingEdit = true
                                }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingEdit) {
                    NavigationStack {
                        SecureCodeFormView(store: store, entry: entry)
                    }
                }
                .confirmationDialog("Delete \(entry.title)?", isPresented: $showingDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        Task {
                            if await authorize(reason: "Delete \(entry.title)") {
                                store.delete(entry)
                                dismiss()
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the saved entry and its secret from this device.")
                }
            } else {
                ContentUnavailableView("Entry Not Found", systemImage: "key.slash")
            }
        }
        .onDisappear { revealedSecret = nil }
        .alert("Passwords & Codes", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func reveal(_ entry: SecureCodeEntry) {
        Task {
            guard await authorize(reason: "Reveal \(entry.title)") else { return }
            revealedSecret = store.secret(for: entry) ?? ""
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            revealedSecret = nil
        }
    }

    private func copySecret(_ entry: SecureCodeEntry) {
        Task {
            guard await authorize(reason: "Copy \(entry.title)") else { return }
            guard let secret = store.secret(for: entry) else {
                message = "The saved password or code could not be read."
                return
            }
            UIPasteboard.general.setItems(
                [["public.utf8-plain-text": secret]],
                options: [
                    .expirationDate: Date().addingTimeInterval(60),
                    .localOnly: true
                ]
            )
            message = "Copied. The clipboard copy will expire in about one minute."
        }
    }

    private func authorize(reason: String) async -> Bool {
        if securityStore.canAuthenticateDeviceOwner() {
            return await securityStore.authenticateDeviceOwner(reason: reason)
        }
        if securityStore.isAppLockEnabled && securityStore.isUnlocked {
            return true
        }
        message = "Turn on App Lock in Settings before storing sensitive information on a device without device authentication."
        return false
    }
}

private struct SecureCodeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.name) private var rooms: [Room]
    @Query(sort: \HomeSystem.name) private var systems: [HomeSystem]
    @Query(sort: \Appliance.name) private var appliances: [Appliance]
    @Query(sort: \Detector.name) private var detectors: [Detector]

    @ObservedObject var store: SecureCodeStore
    let entry: SecureCodeEntry?

    @State private var title: String
    @State private var category: SecureCodeEntry.Category
    @State private var username: String
    @State private var secret: String
    @State private var notes: String
    @State private var relatedItem: String
    @State private var showSecret = false
    @State private var saveError = false

    init(store: SecureCodeStore, entry: SecureCodeEntry? = nil) {
        self.store = store
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _category = State(initialValue: entry?.category ?? .access)
        _username = State(initialValue: entry?.username ?? "")
        _secret = State(initialValue: entry.flatMap { store.secret(for: $0) } ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _relatedItem = State(initialValue: entry?.relatedItem ?? "")
    }

    var body: some View {
        Form {
            Section("Saved Item") {
                TextField("Name", text: $title)
                Picker("Category", selection: $category) {
                    ForEach(SecureCodeEntry.Category.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }

            Section("Sign-In / Code") {
                TextField("Username or email (optional)", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Group {
                        if showSecret {
                            TextField("Password or code", text: $secret)
                        } else {
                            SecureField("Password or code", text: $secret)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Button {
                        showSecret.toggle()
                    } label: {
                        Image(systemName: showSecret ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Related Home Item") {
                Picker("Related to", selection: $relatedItem) {
                    Text("None").tag("")
                    if !rooms.isEmpty {
                        Section("Rooms") {
                            ForEach(rooms) { room in
                                Text(room.name).tag("Room: \(room.name)")
                            }
                        }
                    }
                    if !systems.isEmpty {
                        Section("Systems") {
                            ForEach(systems) { system in
                                Text(system.name).tag("System: \(system.name)")
                            }
                        }
                    }
                    if !appliances.isEmpty {
                        Section("Devices & Equipment") {
                            ForEach(appliances) { appliance in
                                Text(appliance.name).tag("Equipment: \(appliance.name)")
                            }
                        }
                    }
                    if !detectors.isEmpty {
                        Section("Detectors") {
                            ForEach(detectors) { detector in
                                Text(detector.name).tag("Detector: \(detector.name)")
                            }
                        }
                    }
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Text("The password or code is stored in the iOS Keychain. The descriptive information is stored locally on this device. This entry is not part of household iCloud sharing or exports.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(entry == nil ? "Add Password or Code" : "Edit Password or Code")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || secret.isEmpty)
            }
        }
        .alert("Could Not Save", isPresented: $saveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("My Home Keeper could not securely save this password or code in the device Keychain.")
        }
    }

    private func save() {
        let success: Bool
        if let entry {
            success = store.update(
                entry,
                title: title,
                category: category,
                username: username,
                secret: secret,
                notes: notes,
                relatedItem: relatedItem
            )
        } else {
            success = store.add(
                title: title,
                category: category,
                username: username,
                secret: secret,
                notes: notes,
                relatedItem: relatedItem
            )
        }

        if success {
            dismiss()
        } else {
            saveError = true
        }
    }
}
