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
    let tags: [String]
    let approvedRoutes: [String]
    let availableRoutes: [String]
    // All fields are camelCase matching the Headscale v0.28 API — no CodingKeys needed

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
        if let d = f.date(from: str) { return d }
        // Fallback: trim sub-millisecond digits (Headscale uses nanosecond precision)
        let trimmed = str.replacingOccurrences(of: #"\.\d+"#, with: ".000",
                                               options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }
}

struct HeadscaleUser: Codable, Identifiable {
    let id: String
    let name: String
    let createdAt: String?
    // camelCase — no CodingKeys needed
}

struct HeadscaleAPIKey: Codable, Identifiable {
    let id: String
    let prefix: String
    let expiration: String?
    let createdAt: String?
    // camelCase — no CodingKeys needed

    var expirationDate: Date? {
        guard let exp = expiration, !exp.isEmpty, exp != "0001-01-01T00:00:00Z" else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: exp) { return d }
        let trimmed = exp.replacingOccurrences(of: #"\.\d+"#, with: ".000",
                                               options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }

    var isExpired: Bool { expirationDate.map { $0 < Date() } ?? false }
}

// A flattened route entry built from node data (no standalone /routes endpoint in v0.28)
struct RouteEntry: Identifiable {
    let id: String
    let node: HeadscaleNode
    let prefix: String
    let approved: Bool
}

// Response wrappers
struct NodeListResponse: Codable { let nodes: [HeadscaleNode] }
struct NodeResponse: Codable { let node: HeadscaleNode }
struct UserListResponse: Codable { let users: [HeadscaleUser] }
struct UserResponse: Codable { let user: HeadscaleUser }
struct APIKeyListResponse: Codable { let apiKeys: [HeadscaleAPIKey] }
struct APIKeyCreateResponse: Codable { let apiKey: String }
