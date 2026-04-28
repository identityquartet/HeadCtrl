import SwiftUI

struct RoutesView: View {
    let api: HeadscaleAPI
    @State private var nodes: [HeadscaleNode] = []
    @State private var isLoading = false
    @State private var error: String?

    var routes: [RouteEntry] {
        var entries: [RouteEntry] = []
        for node in nodes {
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
                    List(routes) { route in
                        RouteRowView(route: route)
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
    let route: RouteEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.prefix).font(.headline).monospaced()
                Text(route.node.displayName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Label(route.approved ? "Approved" : "Pending",
                  systemImage: route.approved ? "checkmark.circle.fill" : "clock.circle")
                .font(.caption)
                .foregroundStyle(route.approved ? .green : .orange)
                .labelStyle(.iconOnly)
                .font(.title2)
        }
        .padding(.vertical, 2)
    }
}
