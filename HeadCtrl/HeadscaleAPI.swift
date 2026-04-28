import Foundation

@Observable
class HeadscaleAPI {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "headctrl.serverURL") }
    }
    var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "headctrl.apiKey") }
    }

    init() {
        serverURL = UserDefaults.standard.string(forKey: "headctrl.serverURL") ?? "https://hs.blacktank.org"
        apiKey = UserDefaults.standard.string(forKey: "headctrl.apiKey") ?? ""
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(serverURL)/api/v1\(path)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200...299).contains(code) else {
            throw NSError(domain: "HeadscaleAPI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
        }
        return data
    }

    // MARK: Nodes
    func listNodes() async throws -> [HeadscaleNode] {
        try JSONDecoder().decode(NodeListResponse.self, from: try await request("/node")).nodes
    }
    func expireNode(_ id: String) async throws {
        _ = try await request("/node/\(id)/expire", method: "POST")
    }
    func deleteNode(_ id: String) async throws {
        _ = try await request("/node/\(id)", method: "DELETE")
    }
    func renameNode(_ id: String, newName: String) async throws -> HeadscaleNode {
        try JSONDecoder().decode(NodeResponse.self,
            from: try await request("/node/\(id)/rename/\(newName)", method: "POST")).node
    }

    // MARK: Users
    func listUsers() async throws -> [HeadscaleUser] {
        try JSONDecoder().decode(UserListResponse.self, from: try await request("/user")).users
    }
    func createUser(name: String) async throws -> HeadscaleUser {
        let body = try JSONSerialization.data(withJSONObject: ["name": name])
        return try JSONDecoder().decode(UserResponse.self,
            from: try await request("/user", method: "POST", body: body)).user
    }
    func deleteUser(name: String) async throws {
        _ = try await request("/user/\(name)", method: "DELETE")
    }

    // MARK: Routes
    func listRoutes() async throws -> [HeadscaleRoute] {
        try JSONDecoder().decode(RouteListResponse.self, from: try await request("/routes")).routes
    }
    func enableRoute(_ id: String) async throws {
        _ = try await request("/routes/\(id)/enable", method: "POST")
    }
    func deleteRoute(_ id: String) async throws {
        _ = try await request("/routes/\(id)", method: "DELETE")
    }

    // MARK: API Keys
    func listAPIKeys() async throws -> [HeadscaleAPIKey] {
        try JSONDecoder().decode(APIKeyListResponse.self, from: try await request("/apikey")).apiKeys
    }
    func createAPIKey(expiration: Date?) async throws -> String {
        var body: [String: Any] = [:]
        if let exp = expiration { body["expiration"] = ISO8601DateFormatter().string(from: exp) }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(APIKeyCreateResponse.self,
            from: try await request("/apikey", method: "POST", body: bodyData)).apiKey
    }
    func expireAPIKey(prefix: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["prefix": prefix])
        _ = try await request("/apikey/expire", method: "POST", body: body)
    }
}
