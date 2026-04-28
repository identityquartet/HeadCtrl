import SwiftUI

struct UsersView: View {
    let api: HeadscaleAPI
    @State private var users: [HeadscaleUser] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var newUserName = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && users.isEmpty {
                    ProgressView()
                } else if let err = error {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                          description: Text(err))
                } else if users.isEmpty {
                    ContentUnavailableView("No Users", systemImage: "person.slash")
                } else {
                    List {
                        ForEach(users) { user in
                            UserRowView(api: api, user: user, onDelete: load)
                        }
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { showCreate = true }
                }
            }
        }
        .task { await load() }
        .alert("New User", isPresented: $showCreate) {
            TextField("Username", text: $newUserName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Create") { Task { await createUser() } }
            Button("Cancel", role: .cancel) { newUserName = "" }
        }
    }

    func load() async {
        isLoading = true; error = nil
        do { users = try await api.listUsers() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }

    func createUser() async {
        let name = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        newUserName = ""
        guard !name.isEmpty else { return }
        do { _ = try await api.createUser(name: name); await load() }
        catch { self.error = error.localizedDescription }
    }
}

struct UserRowView: View {
    let api: HeadscaleAPI
    let user: HeadscaleUser
    let onDelete: () async -> Void
    @State private var showDelete = false

    var body: some View {
        HStack {
            Image(systemName: "person.circle").font(.title2).foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(user.name).font(.headline)
                if let created = user.createdAt, let date = parseDate(created) {
                    Text("Created \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) { showDelete = true }
        }
        .confirmationDialog("Delete \(user.name)?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    func delete() async {
        do { try await api.deleteUser(name: user.name); await onDelete() } catch {}
    }

    func parseDate(_ str: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }
}
