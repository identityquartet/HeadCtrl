import Foundation

extension String {
    func headscaleDate() -> Date? {
        guard !isEmpty, self != "0001-01-01T00:00:00Z" else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: self) { return d }
        let trimmed = replacingOccurrences(of: #"\.(\d+)"#, with: ".000", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }
}

struct HeadscaleNode: Codable, Identifiable {
    let id: String
    let name: String
    let givenName: String?
    let user: HeadscaleUser
    let ipAddresses: [String]
    let lastSeen: String?
    let expiry: String?
    let online: Bool?
    let tags: [String]
    let approvedRoutes: [String]
    let availableRoutes: [String]

    var displayName: String { givenName?.isEmpty == false ? givenName! : name }
    var isExpired: Bool { expiryDate.map { $0 < Date() } ?? false }
    var expiryDate: Date? { expiry?.headscaleDate() }
    var lastSeenDate: Date? { lastSeen?.headscaleDate() }
}

struct HeadscaleUser: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: String?
}

struct HeadscaleAPIKey: Codable, Identifiable {
    let id: String
    let prefix: String
    let expiration: String?
    let createdAt: String?

    var expirationDate: Date? { expiration?.headscaleDate() }
    var isExpired: Bool { expirationDate.map { $0 < Date() } ?? false }
}

struct HeadscalePreAuthKey: Codable, Identifiable {
    let id: String
    let key: String
    let reusable: Bool
    let ephemeral: Bool
    let used: Bool
    let expiration: String?
    let createdAt: String?
    let user: HeadscaleUser
    let aclTags: [String]

    var expirationDate: Date? { expiration?.headscaleDate() }
    var isExpired: Bool { expirationDate.map { $0 < Date() } ?? false }
    var displayKey: String {
        let clean = key.replacingOccurrences(of: "-***", with: "")
        return String(clean.prefix(36)) + "..."
    }
}

struct RouteEntry: Identifiable {
    let id: String
    let node: HeadscaleNode
    let prefix: String
    let approved: Bool
}

struct NodeListResponse: Codable { let nodes: [HeadscaleNode] }
struct NodeResponse: Codable { let node: HeadscaleNode }
struct UserListResponse: Codable { let users: [HeadscaleUser] }
struct UserResponse: Codable { let user: HeadscaleUser }
struct APIKeyListResponse: Codable { let apiKeys: [HeadscaleAPIKey] }
struct APIKeyCreateResponse: Codable { let apiKey: String }
struct PreAuthKeyListResponse: Codable { let preAuthKeys: [HeadscalePreAuthKey] }
struct PreAuthKeyResponse: Codable { let preAuthKey: HeadscalePreAuthKey }
