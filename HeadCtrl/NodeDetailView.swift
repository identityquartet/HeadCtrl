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
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
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
                LabeledContent("User", value: node.user.name)
                if let ls = node.lastSeenDate {
                    LabeledContent("Last Seen", value: ls.formatted(.relative(presentation: .named)))
                }
            }

            Section("Network") {
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

            if !node.availableRoutes.isEmpty {
                Section("Routes") {
                    ForEach(node.availableRoutes, id: \.self) { prefix in
                        HStack {
                            Text(prefix).monospaced()
                            Spacer()
                            if node.approvedRoutes.contains(prefix) {
                                Label("Approved", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .labelStyle(.iconOnly)
                            } else {
                                Label("Pending", systemImage: "clock.circle")
                                    .foregroundStyle(.orange)
                                    .labelStyle(.iconOnly)
                            }
                        }
                    }
                }
            }

            if !node.tags.isEmpty {
                Section("Tags") {
                    ForEach(node.tags, id: \.self) { Text($0) }
                }
            }

            if let err = error {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }

            Section("Actions") {
                Button("Rename Node") { renameText = node.displayName; showRename = true }
                Button("Expire Node", role: .destructive) { showExpireConfirm = true }
                Button("Delete Node", role: .destructive) { showDeleteConfirm = true }
            }
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
        .alert("Rename Node", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Rename") { Task { await rename() } }
            Button("Cancel", role: .cancel) {}
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
}
