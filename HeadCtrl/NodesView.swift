import SwiftUI

struct NodesView: View {
    let api: HeadscaleAPI
    @State private var nodes: [HeadscaleNode] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var showRegister = false

    var filtered: [HeadscaleNode] {
        guard !searchText.isEmpty else { return nodes }
        return nodes.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.user.name.localizedCaseInsensitiveContains(searchText) ||
            $0.ipAddresses.contains { $0.contains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && nodes.isEmpty {
                    ProgressView()
                } else if let err = error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                          description: Text(err))
                } else if filtered.isEmpty {
                    ContentUnavailableView("No Nodes", systemImage: "network.slash")
                } else {
                    List(filtered) { node in
                        NavigationLink(destination: NodeDetailView(api: api, node: node,
                                                                   onRefresh: { await load() })) {
                            NodeRowView(node: node)
                        }
                    }
                    .searchable(text: $searchText)
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Nodes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if isLoading { ProgressView() }
                        Button("Register", systemImage: "plus.circle") { showRegister = true }
                    }
                }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showRegister) {
            RegisterNodeSheet(api: api, onRegistered: { await load() })
        }
    }

    func load() async {
        isLoading = true; error = nil
        do { nodes = try await api.listNodes() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

struct NodeRowView: View {
    let node: HeadscaleNode

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(node.online == true ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(node.displayName).font(.headline)
                HStack {
                    Text(node.user.name).font(.caption).foregroundStyle(.secondary)
                    if let ip = node.ipAddresses.first {
                        Text("·").foregroundStyle(.tertiary)
                        Text(ip).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if node.isExpired {
                    Label("Expired", systemImage: "clock.badge.xmark")
                        .font(.caption).foregroundStyle(.red)
                }
                if !node.availableRoutes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption2).foregroundStyle(.blue)
                        Text("\(node.availableRoutes.count) route(s)")
                            .font(.caption2).foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct RegisterNodeSheet: View {
    let api: HeadscaleAPI
    let onRegistered: () async -> Void
    @State private var users: [HeadscaleUser] = []
    @State private var selectedUserId = ""
    @State private var nodeKey = ""
    @State private var isLoading = false
    @State private var isRegistering = false
    @State private var error: String?
    @State private var registered: HeadscaleNode?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Node Key") {
                    TextField("nodekey:...", text: $nodeKey, axis: .vertical)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(3...6)
                }

                Section("User") {
                    if isLoading {
                        HStack { ProgressView(); Text("Loading users…").foregroundStyle(.secondary) }
                    } else {
                        Picker("Assign to", selection: $selectedUserId) {
                            ForEach(users) { u in
                                Text(u.name).tag(u.id)
                            }
                        }
                    }
                }

                if let err = error {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }

                if let node = registered {
                    Section("Registered") {
                        LabeledContent("Name", value: node.displayName)
                        ForEach(node.ipAddresses, id: \.self) { ip in
                            LabeledContent("IP", value: ip)
                        }
                    }
                }
            }
            .navigationTitle("Register Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register") { Task { await register() } }
                        .disabled(nodeKey.isEmpty || selectedUserId.isEmpty || isRegistering)
                }
            }
        }
        .task { await loadUsers() }
    }

    func loadUsers() async {
        isLoading = true
        users = (try? await api.listUsers()) ?? []
        if selectedUserId.isEmpty, let first = users.first { selectedUserId = first.id }
        isLoading = false
    }

    func register() async {
        let key = nodeKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !selectedUserId.isEmpty else { return }
        isRegistering = true; error = nil
        do {
            let node = try await api.registerNode(userId: selectedUserId, nodeKey: key)
            registered = node
            await onRegistered()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isRegistering = false
    }
}
