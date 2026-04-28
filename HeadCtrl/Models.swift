import Foundation

struct HeadscaleNode: Codable, Identifiable {
    let id: String
    let name: String
    let givenName: String?
    let user: HeadscaleUser
    let ipAddresses: [String]
    let lastSeen: String?
    let expiry: String?
    let online: Bool?
    let validTags: [String]
    let forcedTags: [String]

    var displayName: String { givenName?.isEmpty == false ? givenName! : name }

    var isExpired: Bool { expiryDate.map { $0 < Date() } ?? false }

    var expiryDate: Date? {
        guard let exp = expiry, !exp.isEmpty, exp != "0001-01-01T00:00:00Z" else { return nil }
        return parseDate(exp)
    }

    var lastSeenDate: Date? {
        guard let ls = lastSeen else { return nil }
        return parseDate(ls)
    }

    private func parseDate(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, user, online, expiry
        case givenName = "given_name"
        case ipAddresses = "ip_addresses"
        case lastSeen = "last_seen"
        case validTags = "valid_tags"
        case forcedTags = "forced_tags"
    }
}

struct HeadscaleUser: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }
}

struct HeadscaleRoute: Codable, Identifiable {
    let id: String
    let node: HeadscaleNode
    let prefix: String
    let advertised: Bool
    let enabled: Bool
    let isPrimary: Bool

    enum CodingKeys: String, CodingKey {
        case id, node, prefix, advertised, enabled
        case isPrimary = "is_primary"
    }
}

struct HeadscaleAPIKey: Codable, Identifiable {
    let id: String
    let prefix: String
    let expiration: String?
    let createdAt: String?

    var expirationDate: Date? {
        guard let exp = expiration, !exp.isEmpty, exp != "0001-01-01T00:00:00Z" else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: exp) ?? ISO8601DateFormatter().date(from: exp)
    }

    var isExpired: Bool { expirationDate.map { $0 < Date() } ?? false }

    enum CodingKeys: String, CodingKey {
        case id, prefix, expiration
        case createdAt = "created_at"
    }
}

struct NodeListResponse: Codable { let nodes: [HeadscaleNode] }
struct NodeResponse: Codable { let node: HeadscaleNode }
struct UserListResponse: Codable { let users: [HeadscaleUser] }
struct UserResponse: Codable { let user: HeadscaleUser }
struct RouteListResponse: Codable { let routes: [HeadscaleRoute] }
struct APIKeyListResponse: Codable {
    let apiKeys: [HeadscaleAPIKey]
    enum CodingKeys: String, CodingKey { case apiKeys = "apiKeys" }
}
struct APIKeyCreateResponse: Codable {
    let apiKey: String
    enum CodingKeys: String, CodingKey { case apiKey = "apiKey" }
}
