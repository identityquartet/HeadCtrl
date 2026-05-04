import Foundation

@Observable
class HeadscaleAPI {
    var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "headctrl.serverURL") }
    }
    var apiKey: String {
        didSet { Keychain.write(apiKey, account: "headctrl.apiKey") }
    }

    init() {
        serverURL = UserDefaults.standard.string(forKey: "headctrl.serverURL") ?? "https://hs.blacktank.org"
        if let stored = Keychain.read("headctrl.apiKey") {
            apiKey = stored
        } else if let legacy = UserDefaults.standard.string(forKey: "headctrl.apiKey"), !legacy.isEmpty {
            apiKey = legacy
            Keychain.write(legacy, account: "headctrl.apiKey")
            UserDefaults.standard.removeObject(forKey: "headctrl.apiKey")
        } else {
            apiKey = ""
        }
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
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
            throw NSError(domain: "HeadscaleAPI", code: code,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "HTTP \(code)"])
        }
        return data
    }

    // MARK: - Nodes
    func listNodes() async throws -> [HeadscaleNode] {
        try JSONDecoder().decode(NodeListResponse.self, from: try await request("/node")).nodes
    }
    func getNode(_ id: String) async throws -> HeadscaleNode {
        try JSONDecoder().decode(NodeResponse.self, from: try await request("/node/\(id)")).node
    }
    func deleteNode(_ id: String) async throws {
        _ = try await request("/node/\(id)", method: "DELETE")
    }
    func expireNode(_ id: String) async throws {
        _ = try await request("/node/\(id)/expire", method: "POST")
    }
    func renameNode(_ id: String, newName: String) async throws -> HeadscaleNode {
        try JSONDecoder().decode(NodeResponse.self,
            from: try await request("/node/\(id)/rename/\(newName)", method: "POST")).node
    }
    func setNodeTags(_ id: String, tags: [String]) async throws -> HeadscaleNode {
        let body = try JSONSerialization.data(withJSONObject: ["tags": tags])
        return try JSONDecoder().decode(NodeResponse.self,
            from: try await request("/node/\(id)/tags", method: "POST", body: body)).node
    }
    func approveRoutes(_ nodeId: String, routes: [String]) async throws -> HeadscaleNode {
        let body = try JSONSerialization.data(withJSONObject: ["routes": routes])
        return try JSONDecoder().decode(NodeResponse.self,
            from: try await request("/node/\(nodeId)/approve_routes", method: "POST", body: body)).node
    }
    func registerNode(userId: String, nodeKey: String) async throws -> HeadscaleNode {
        let key = nodeKey.hasPrefix("nodekey:") ? nodeKey : "nodekey:\(nodeKey)"
        return try JSONDecoder().decode(NodeResponse.self,
            from: try await request("/node/register?user=\(userId)&key=\(key)", method: "POST")).node
    }

    // MARK: - Users
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
    func renameUser(userId: String, newName: String) async throws -> HeadscaleUser {
        return try JSONDecoder().decode(UserResponse.self,
            from: try await request("/user/\(userId)/rename/\(newName)", method: "POST")).user
    }

    // MARK: - Pre-Auth Keys
    func listPreAuthKeys(userId: String) async throws -> [HeadscalePreAuthKey] {
        let data = try await request("/preauthkey?user=\(userId)")
        return (try? JSONDecoder().decode(PreAuthKeyListResponse.self, from: data).preAuthKeys) ?? []
    }
    func listAllPreAuthKeys() async throws -> [HeadscalePreAuthKey] {
        let users = try await listUsers()
        var all: [HeadscalePreAuthKey] = []
        for user in users {
            let keys = (try? await listPreAuthKeys(userId: user.id)) ?? []
            all.append(contentsOf: keys)
        }
        return all
    }
    func createPreAuthKey(userId: String, reusable: Bool, ephemeral: Bool,
                          expiration: Date?, aclTags: [String]) async throws -> HeadscalePreAuthKey {
        var body: [String: Any] = ["user": userId, "reusable": reusable,
                                   "ephemeral": ephemeral, "aclTags": aclTags]
        if let exp = expiration {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            body["expiration"] = f.string(from: exp)
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(PreAuthKeyResponse.self,
            from: try await request("/preauthkey", method: "POST", body: bodyData)).preAuthKey
    }
    func expirePreAuthKey(key: HeadscalePreAuthKey) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["user": key.user.id, "key": key.key])
        _ = try await request("/preauthkey", method: "DELETE", body: body)
    }

    // MARK: - API Keys
    func listAPIKeys() async throws -> [HeadscaleAPIKey] {
        try JSONDecoder().decode(APIKeyListResponse.self, from: try await request("/apikey")).apiKeys
    }
    func createAPIKey(expiration: Date?) async throws -> String {
        var body: [String: Any] = [:]
        if let exp = expiration {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            body["expiration"] = f.string(from: exp)
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try JSONDecoder().decode(APIKeyCreateResponse.self,
            from: try await request("/apikey", method: "POST", body: bodyData)).apiKey
    }
    func expireAPIKey(prefix: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["prefix": prefix])
        _ = try await request("/apikey/expire", method: "POST", body: body)
    }
}
