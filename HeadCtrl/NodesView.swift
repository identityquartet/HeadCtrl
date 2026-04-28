import SwiftUI

struct NodesView: View {
    let api: HeadscaleAPI
    @State private var nodes: [HeadscaleNode] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""

    var filtered: [HeadscaleNode] {
        guard !searchText.isEmpty else { return nodes }
        return nodes.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.user.name.localizedCaseInsensitiveContains(searchText)
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
                    if isLoading { ProgressView() }
                }
            }
        }
        .task { await load() }
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
            }
        }
        .padding(.vertical, 2)
    }
}
