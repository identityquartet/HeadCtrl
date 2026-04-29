import SwiftUI

struct NodeDetailView: View {
    let api: HeadscaleAPI
    @State var node: HeadscaleNode
    let onRefresh: () async -> Void
    @State private var isWorking = false
    @State private var error: String?
    @State private var showDeleteConfirm = false
    @State private var showExpireConfirm = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showTags = false
    @State private var tagsText = ""
    @State private var approvedRouteSet: Set<String> = []
    @Environment(\..dismiss) private var dismiss

    var body: some View {
        List {
            statusSection
            networkSection
            expirySection
            if !node.availableRoutes.isEmpty { routesSection }
            if !node.tags.isEmpty || true { tagsSection }
            if let err = error {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            actionsSection
        }
        .navigationTitle(node.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isWorking {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .onAppear { approvedRouteSet = Set(node.approvedRoutes) }
        .alert("Rename Node", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Rename") { Task { await rename() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit Tags", isPresented: $showTags) {
            TextField("tag:example, tag:server", text: $tagsText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Save") { Task { await saveTags() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Comma-separated ACL tags (e.g. tag:server). Tags must be defined in ACL policy.")
        }
        .confirmationDialog("Expire Node?", isPresented: $showExpireConfirm, titleVisibility: .visible) {
            Button("Expire", role: .destructive) { Task { await expire() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The node will need to re-authenticate.") }
        .confirmationDialog("Delete Node?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This permanently removes the node from Headscale.") }
    }

    var statusSection: some View {
        Section("Status") {
            LabeledContent("Online") {
                HStack {
                    Circle()
                        .fill(node.online == true ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(node.online == true ? "Online" : "Offline")
                }
            }
            LabeledContent("Hostname", value: node.name)
            LabeledContent("Given Name", value: node.givenName ?? node.name)
            LabeledContent("User", value: node.user.name)
            LabeledContent("Node ID", value: node.id)
            if let ls = node.lastSeenDate {
                LabeledContent("Last Seen", value: ls.formatted(.relative(presentation: .named)))
            }
        }
    }

    var networkSection: some View {
        Section("IP Addresses") {
            ForEach(node.ipAddresses, id: \.self) { ip in
                HStack {
                    Text(ip).monospaced()
                    Spacer()
                    Button {
                        UIPasteboard.general.string = ip
                    } label: {
                        Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var expirySection: some View {
        Section("Expiry") {
            if let exp = node.expiryDate {
                LabeledContent("Expires", value: exp.formatted(date: .abbreviated, time: .shortened))
                if node.isExpired {
                    Label("This node has expired", systemImage: "clock.badge.xmark")
                        .foregroundStyle(.red)
                }
            } else {
                Text("Never expires").foregroundStyle(.secondary)
            }
        }
    }

    var routesSection: some View {
        Section {
            ForEach(node.availableRoutes, id: \.self) { prefix in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prefix).monospaced().font(.subheadline)
                        Text(routeLabel(prefix)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { approvedRouteSet.contains(prefix) },
                        set: { _ in Task { await toggleRoute(prefix) } }
                    ))
                    .labelsHidden()
                }
            }
        } header: {
            Text("Routes")
        } footer: {
            Text("Toggle to approve or revoke route advertising.")
        }
    }

    var tagsSection: some View {
        Section {
            if node.tags.isEmpty {
                Text("No tags").foregroundStyle(.tertiary)
            } else {
                ForEach(node.tags, id: \.self) { tag in
                    Label(tag, systemImage: "tag").font(.subheadline)
                }
            }
            Button("Edit Tags") {
                tagsText = node.tags.joined(separator: ", ")
                showTags = true
            }
        } header: { Text("ACL Tags") }
    }

    var actionsSection: some View {
        Section("Actions") {
            Button("Rename Node") { renameText = node.displayName; showRename = true }
            Button("Expire Node", role: .destructive) { showExpireConfirm = true }
            Button("Delete Node", role: .destructive) { showDeleteConfirm = true }
        }
    }

    func routeLabel(_ prefix: String) -> String {
        if prefix == "0.0.0.0/0" || prefix == "::/0" { return "Exit node" }
        return "Subnet"
    }

    func toggleRoute(_ prefix: String) async {
        var newSet = approvedRouteSet
        if newSet.contains(prefix) { newSet.remove(prefix) } else { newSet.insert(prefix) }
        isWorking = true; error = nil
        do {
            let updated = try await api.approveRoutes(node.id, routes: Array(newSet).sorted())
            node = updated
            approvedRouteSet = Set(updated.approvedRoutes)
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }

    func expire() async {
        isWorking = true; error = nil
        do { try await api.expireNode(node.id); await onRefresh(); dismiss() }
        catch { self.error = error.localizedDescription }
        isWorking = false
    }

    func delete() async {
        isWorking = true; error = nil
        do { try await api.deleteNode(node.id); await onRefresh(); dismiss() }
        catch { self.error = error.localizedDescription }
        isWorking = false
    }

    func rename() async {
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isWorking = true; error = nil
        do { node = try await api.renameNode(node.id, newName: name) }
        catch { self.error = error.localizedDescription }
        isWorking = false
    }

    func saveTags() async {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        isWorking = true; error = nil
        do { node = try await api.setNodeTags(node.id, tags: tags) }
        catch { self.error = error.localizedDescription }
        isWorking = false
    }
}
