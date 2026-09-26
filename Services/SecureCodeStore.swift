import Combine
import Foundation

struct SecureCodeEntry: Identifiable, Codable, Equatable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case access = "Access"
        case wifi = "Wi-Fi & Network"
        case security = "Security"
        case equipment = "Equipment"
        case other = "Other"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .access: return "key"
            case .wifi: return "wifi"
            case .security: return "shield"
            case .equipment: return "gearshape"
            case .other: return "lock"
            }
        }
    }

    var id: UUID
    var title: String
    var category: Category
    var username: String
    var notes: String
    var relatedItem: String
    var createdAt: Date
    var updatedAt: Date
}

@MainActor
final class SecureCodeStore: ObservableObject {
    @Published private(set) var entries: [SecureCodeEntry] = []

    private enum Keys {
        static let defaultsEntries = "secureCodes.entries.v1"
        static let keychainService = "org.scriptingforschools.HomeMaintainer.secureCodes"
    }

    init() {
        load()
    }

    func secret(for entry: SecureCodeEntry) -> String? {
        guard let data = SecurityKeychain.readData(
            service: Keys.keychainService,
            account: entry.id.uuidString
        ) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func add(
        title: String,
        category: SecureCodeEntry.Category,
        username: String,
        secret: String,
        notes: String,
        relatedItem: String
    ) -> Bool {
        let id = UUID()
        guard saveSecret(secret, id: id) else { return false }
        let now = Date()
        entries.append(
            SecureCodeEntry(
                id: id,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                relatedItem: relatedItem,
                createdAt: now,
                updatedAt: now
            )
        )
        sortAndPersist()
        return true
    }

    @discardableResult
    func update(
        _ entry: SecureCodeEntry,
        title: String,
        category: SecureCodeEntry.Category,
        username: String,
        secret: String,
        notes: String,
        relatedItem: String
    ) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }),
              saveSecret(secret, id: entry.id) else { return false }
        entries[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index].category = category
        entries[index].username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index].notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index].relatedItem = relatedItem
        entries[index].updatedAt = Date()
        sortAndPersist()
        return true
    }

    func delete(_ entry: SecureCodeEntry) {
        entries.removeAll { $0.id == entry.id }
        SecurityKeychain.delete(service: Keys.keychainService, account: entry.id.uuidString)
        persist()
    }

    private func saveSecret(_ secret: String, id: UUID) -> Bool {
        SecurityKeychain.saveData(
            Data(secret.utf8),
            service: Keys.keychainService,
            account: id.uuidString
        )
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Keys.defaultsEntries),
              let decoded = try? JSONDecoder().decode([SecureCodeEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func sortAndPersist() {
        entries.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Keys.defaultsEntries)
    }
}
