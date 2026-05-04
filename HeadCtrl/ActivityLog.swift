import Foundation

enum ActivityAction: String, Codable, CaseIterable {
    case createUser
    case deleteUser
    case renameUser
    case deleteNode
    case expireNode
    case renameNode
    case registerNode
    case setNodeTags
    case approveRoutes
    case createPreAuthKey
    case expirePreAuthKey
    case createAPIKey
    case expireAPIKey

    var displayName: String {
        switch self {
        case .createUser: "Create User"
        case .deleteUser: "Delete User"
        case .renameUser: "Rename User"
        case .deleteNode: "Delete Node"
        case .expireNode: "Expire Node"
        case .renameNode: "Rename Node"
        case .registerNode: "Register Node"
        case .setNodeTags: "Set Tags"
        case .approveRoutes: "Update Routes"
        case .createPreAuthKey: "Create Pre-Auth Key"
        case .expirePreAuthKey: "Expire Pre-Auth Key"
        case .createAPIKey: "Create API Key"
        case .expireAPIKey: "Expire API Key"
        }
    }

    var systemImage: String {
        switch self {
        case .createUser: "person.badge.plus"
        case .deleteUser: "person.badge.minus"
        case .renameUser: "person.crop.square.filled.and.at.rectangle"
        case .deleteNode: "trash"
        case .expireNode, .expirePreAuthKey, .expireAPIKey: "clock.badge.xmark"
        case .renameNode: "pencil"
        case .registerNode: "plus.circle"
        case .setNodeTags: "tag"
        case .approveRoutes: "arrow.triangle.branch"
        case .createPreAuthKey, .createAPIKey: "key.fill"
        }
    }
}

struct ActivityEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let action: ActivityAction
    let target: String
    let detail: String?
    let errorMessage: String?

    var success: Bool { errorMessage == nil }
}

@Observable
final class ActivityLog {
    static let shared = ActivityLog()

    private(set) var entries: [ActivityEntry] = []
    private let maxEntries = 1000

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("activity-log.json")
    }()

    init() { load() }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([ActivityEntry].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    nonisolated func record(_ action: ActivityAction, target: String, detail: String? = nil, error: Error? = nil) {
        let entry = ActivityEntry(
            id: UUID(),
            timestamp: Date(),
            action: action,
            target: target,
            detail: detail,
            errorMessage: error?.localizedDescription
        )
        Task { @MainActor in
            self.entries.insert(entry, at: 0)
            if self.entries.count > self.maxEntries {
                self.entries.removeLast(self.entries.count - self.maxEntries)
            }
            self.save()
        }
    }

    @MainActor
    func clear() {
        entries.removeAll()
        save()
    }
}
