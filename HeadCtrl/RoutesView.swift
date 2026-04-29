import SwiftUI

struct RoutesView: View {
    let api: HeadscaleAPI
    @State private var nodes: [HeadscaleNode] = []
    @State private var isLoading = false
    @State private var error: String?

    var routes: [RouteEntry] {
        var entries: [RouteEntry] = []
        for node in nodes where !node.availableRoutes.isEmpty {
            for prefix in node.availableRoutes {
                let approved = node.approvedRoutes.contains(prefix)
                entries.append(RouteEntry(id: "\(node.id)-\(prefix)", node: node,
                                          prefix: prefix, approved: approved))
            }
        }
        return entries.sorted { $0.prefix < $1.prefix }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && nodes.isEmpty {
                    ProgressView()
                } else if let err = error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                          description: Text(err))
                } else if routes.isEmpty {
                    ContentUnavailableView("No Routes", systemImage: "arrow.triangle.branch",
                                          description: Text("No nodes are advertising routes."))
                } else {
                    List {
                        let grouped = Dictionary(grouping: routes, by: { $0.node.displayName })
                        ForEach(grouped.keys.sorted(), id: \.self) { nodeName in
                            Section(nodeName) {
                                ForEach(grouped[nodeName] ?? []) { route in
                                    RouteRowView(api: api, route: route, nodes: nodes,
                                                 onUpdated: { updated in
                                        if let idx = nodes.firstIndex(where: { $0.id == updated.id }) {
                                            nodes[idx] = updated
                                        }
                                    })
                                }
                            }
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Routes")
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

struct RouteRowView: View {
    let api: HeadscaleAPI
    let route: RouteEntry
    let nodes: [HeadscaleNode]
    let onUpdated: (HeadscaleNode) -> Void
    @State private var isWorking = false
    @State private var error: String?

    var isExitNode: Bool { route.prefix == "0.0.0.0/0" || route.prefix == "::/0" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: isExitNode ? "globe" : "network")
                            .foregroundStyle(isExitNode ? .purple : .blue)
                            .font(.caption)
                        Text(route.prefix).font(.subheadline).monospaced()
                    }
                    Text(isExitNode ? "Exit Node" : "Subnet Route")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isWorking {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button {
                        Task { await toggle() }
                    } label: {
                        Label(route.approved ? "Revoke" : "Approve",
                              systemImage: route.approved ? "checkmark.circle.fill" : "circle")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .foregroundStyle(route.approved ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let err = error {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
    }

    func toggle() async {
        guard let node = nodes.first(where: { $0.id == route.node.id }) else { return }
        var newSet = Set(node.approvedRoutes)
        if newSet.contains(route.prefix) { newSet.remove(route.prefix) } else { newSet.insert(route.prefix) }
        isWorking = true; error = nil
        do {
            let updated = try await api.approveRoutes(node.id, routes: Array(newSet).sorted())
            onUpdated(updated)
        } catch {
            self.error = error.localizedDescription
        }
        isWorking = false
    }
}
