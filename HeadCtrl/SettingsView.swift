import SwiftUI

struct SettingsView: View {
    @Bindable var api: HeadscaleAPI
    let isInitialSetup: Bool
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult: Bool?
    @State private var testError: String?
    @State private var nodeCount: Int?
    @State private var userCount: Int?

    var body: some View {
        NavigationStack {
            Form {
                if isInitialSetup {
                    Section {
                        Label("Enter your Headscale server URL and API key to get started.",
                              systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Server") {
                    TextField("URL", text: $serverURL,
                              prompt: Text("https://headscale.example.com"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }

                Section("Authentication") {
                    SecureField("API Key", text: $apiKey, prompt: Text("Paste API key here"))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Button("Save") { save() }
                        .disabled(serverURL.isEmpty || apiKey.isEmpty)
                    Button("Test Connection") { Task { await test() } }
                        .disabled(serverURL.isEmpty || apiKey.isEmpty || isTesting)
                }

                if isTesting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Testing connection…").foregroundStyle(.secondary)
                        }
                    }
                } else if let result = testResult {
                    Section {
                        if result {
                            Label("Connection successful", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            if let nc = nodeCount, let uc = userCount {
                                LabeledContent("Nodes", value: "\(nc)")
                                LabeledContent("Users", value: "\(uc)")
                            }
                        } else {
                            Label(testError ?? "Connection failed", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }

                if !isInitialSetup {
                    Section {
                        NavigationLink {
                            ActivityView()
                        } label: {
                            Label("Activity Log", systemImage: "list.bullet.clipboard")
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Server", value: api.serverURL.isEmpty ? "Not configured" : api.serverURL)
                    LabeledContent("API Version", value: "v1")
                }
            }
            .navigationTitle(isInitialSetup ? "Setup" : "Settings")
        }
        .onAppear {
            serverURL = api.serverURL
            apiKey = api.apiKey
        }
    }

    func save() {
        api.serverURL = serverURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        api.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        testResult = nil
    }

    func test() async {
        let url = serverURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let reqURL = URL(string: "\(url)/api/v1/node") else {
            testResult = false; testError = "Invalid URL"; return
        }
        isTesting = true; testResult = nil; testError = nil; nodeCount = nil; userCount = nil
        var req = URLRequest(url: reqURL)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if (200...299).contains(code) {
                testResult = true
                if let decoded = try? JSONDecoder().decode(NodeListResponse.self, from: data) {
                    nodeCount = decoded.nodes.count
                }
                if let userURL = URL(string: "\(url)/api/v1/user") {
                    var ureq = URLRequest(url: userURL)
                    ureq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                    if let (udata, _) = try? await URLSession.shared.data(for: ureq),
                       let decoded = try? JSONDecoder().decode(UserListResponse.self, from: udata) {
                        userCount = decoded.users.count
                    }
                }
            } else {
                testResult = false; testError = "Server returned HTTP \(code)"
            }
        } catch {
            testResult = false; testError = error.localizedDescription
        }
        isTesting = false
    }
}
