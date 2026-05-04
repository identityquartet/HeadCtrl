import SwiftUI

struct APIKeysView: View {
    let api: HeadscaleAPI
    @State private var keys: [HeadscaleAPIKey] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var newKeyResult: String?
    @State private var showNewKey = false

    var body: some View {
        Group {
            if isLoading && keys.isEmpty {
                ProgressView()
            } else if let err = error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                       description: Text(err))
            } else if keys.isEmpty {
                ContentUnavailableView("No API Keys", systemImage: "key.slash")
            } else {
                List(keys) { key in
                    APIKeyRowView(api: api, key: key, onRefresh: load)
                }
                .refreshable { await load() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showCreate = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            CreateAPIKeySheet(api: api) { key in
                newKeyResult = key
                showCreate = false
                showNewKey = true
                Task { await load() }
            }
        }
        .alert("New API Key Created", isPresented: $showNewKey, presenting: newKeyResult) { _ in
            Button("Copy to Clipboard") { UIPasteboard.general.string = newKeyResult }
            Button("Done", role: .cancel) {}
        } message: { key in
            Text("Copy this key now — it won\'t be shown again.\n\n\(key)")
        }
    }

    func load() async {
        isLoading = true; error = nil
        do { keys = try await api.listAPIKeys() }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

struct CreateAPIKeySheet: View {
    let api: HeadscaleAPI
    let onCreated: (String) -> Void
    @State private var expiry: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var hasExpiry = true
    @State private var isCreating = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Set Expiry Date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expires", selection: $expiry, in: Date()..., displayedComponents: .date)
                    }
                }
                if let err = error {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }.disabled(isCreating)
                }
            }
        }
    }

    func create() async {
        isCreating = true; error = nil
        do { onCreated(try await api.createAPIKey(expiration: hasExpiry ? expiry : nil)) }
        catch { self.error = error.localizedDescription }
        isCreating = false
    }
}

struct APIKeyRowView: View {
    let api: HeadscaleAPI
    let key: HeadscaleAPIKey
    let onRefresh: () async -> Void
    @State private var showExpire = false
    @State private var error: String?
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.prefix + "...").font(.headline).monospaced()
                Spacer()
                if key.isExpired {
                    Label("Expired", systemImage: "clock.badge.xmark")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            if let exp = key.expirationDate {
                Text("Expires \(exp.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption).foregroundStyle(key.isExpired ? .red : .secondary)
            } else {
                Text("No expiry").font(.caption).foregroundStyle(.secondary)
            }
            if let created = key.createdAt, let date = created.headscaleDate() {
                Text("Created \(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            if !key.isExpired {
                Button("Expire", role: .destructive) { showExpire = true }
            }
        }
        .confirmationDialog("Expire key \(key.prefix)?", isPresented: $showExpire,
                            titleVisibility: .visible) {
            Button("Expire", role: .destructive) { Task { await expire() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK", role: .cancel) {}
        } message: { err in
            Text(err)
        }
    }

    func expire() async {
        do { try await api.expireAPIKey(prefix: key.prefix); await onRefresh() }
        catch { self.error = error.localizedDescription; showError = true }
    }
}
