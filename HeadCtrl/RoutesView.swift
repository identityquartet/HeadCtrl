import SwiftUI

struct RoutesView: View {
    let api: HeadscaleAPI
    @State private var routes: [HeadscaleRoute] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && routes.isEmpty {
                    ProgressView()
                } else if let err = error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                          description: Text(err))
                } else if routes.isEmpty {
                    ContentUnavailableView("No Routes", systemImage: "arrow.triangle.branch")
                } else {
                    List(routes) { route in
                        RouteRowView(api: api, route: route, onRefresh: load)
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
        do { routes = try await api.listRoutes() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

struct RouteRowView: View {
    let api: HeadscaleAPI
    let route: HeadscaleRoute
    let onRefresh: () async -> Void
    @State private var isWorking = false
    @State private var showDelete = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(route.prefix).font(.headline).monospaced()
                Text(route.node.displayName).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    badge("Advertised", active: route.advertised, color: .blue)
                    badge("Enabled", active: route.enabled, color: .green)
                    if route.isPrimary { badge("Primary", active: true, color: .orange) }
                }
            }
            Spacer()
            if isWorking {
                ProgressView()
            } else {
                Menu {
                    if !route.enabled {
                        Button("Enable Route") { Task { await enable() } }
                    }
                    Button("Delete Route", role: .destructive) { showDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .confirmationDialog("Delete route \(route.prefix)?", isPresented: $showDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await deleteRoute() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    func badge(_ label: String, active: Bool, color: Color) -> some View {
        Text(label).font(.caption2)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(active ? color.opacity(0.15) : Color.gray.opacity(0.1))
            .foregroundStyle(active ? color : .gray)
            .clipShape(Capsule())
    }

    func enable() async {
        isWorking = true
        do { try await api.enableRoute(route.id); await onRefresh() } catch {}
        isWorking = false
    }

    func deleteRoute() async {
        isWorking = true
        do { try await api.deleteRoute(route.id); await onRefresh() } catch {}
        isWorking = false
    }
}
