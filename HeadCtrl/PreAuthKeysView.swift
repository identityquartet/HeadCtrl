import SwiftUI

struct PreAuthKeysView: View {
    let api: HeadscaleAPI
    @State private var keys: [HeadscalePreAuthKey] = []
    @State private var users: [HeadscaleUser] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var newKeyResult: HeadscalePreAuthKey?
    @State private var showNewKey = false
    @State private var filterUserId: String = ""

    var filtered: [HeadscalePreAuthKey] {
        guard !filterUserId.isEmpty else { return keys }
        return keys.filter { $0.user.id == filterUserId }
    }

    var body: some View {
        Group {
            if isLoading && keys.isEmpty {
                ProgressView()
            } else if let err = error {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle",
                                       description: Text(err))
            } else if filtered.isEmpty {
                ContentUnavailableView("No Pre-Auth Keys", systemImage: "key.slash",
                                       description: Text("Create keys to register new devices."))
            } else {
                List {
                    ForEach(filtered) { key in
                        PreAuthKeyRowView(api: api, key: key, onRefresh: load)
                    }
                }
                .refreshable { await load() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !users.isEmpty {
                    Picker("User", selection: $filterUserId) {
                        Text("All Users").tag("")
                        ForEach(users) { u in
                            Text(u.name).tag(u.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "plus") { showCreate = true }
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCreate) {
            CreatePreAuthKeySheet(api: api, users: users) { key in
                newKeyResult = key
                showCreate = false
                showNewKey = true
                Task { await load() }
            }
        }
        .alert("Pre-Auth Key Created", isPresented: $showNewKey, presenting: newKeyResult) { key in
            Button("Copy Key") { UIPasteboard.general.string = key.key }
            Button("Done", role: .cancel) {}
        } message: { key in
            Text("Copy this key now — it won\'t be shown again.\n\n\(key.key)")
        }
    }

    func load() async {
        isLoading = true; error = nil
        async let keysTask = api.listAllPreAuthKeys()
        async let usersTask = api.listUsers()
        do {
            let (k, u) = try await (keysTask, usersTask)
            keys = k.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            users = u
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct PreAuthKeyRowView: View {
    let api: HeadscaleAPI
    let key: HeadscalePreAuthKey
    let onRefresh: () async -> Void
    @State private var showExpire = false
    @State private var error: String?

    var statusColor: Color {
        if key.isExpired { return .red }
        if key.used { return .secondary }
        return .green
    }

    var statusLabel: String {
        if key.isExpired { return "Expired" }
        if key.used { return "Used" }
        return "Active"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(key.displayKey).font(.system(.subheadline, design: .monospaced))
                Spacer()
                Label(statusLabel, systemImage: key.isExpired ? "clock.badge.xmark" :
                      key.used ? "checkmark.circle" : "circle.fill")
                    .font(.caption)
                    .foregroundStyle(statusColor)
                    .labelStyle(.titleAndIcon)
            }

            HStack(spacing: 12) {
                Label(key.user.name, systemImage: "person").font(.caption).foregroundStyle(.secondary)

                if key.reusable {
                    Label("Reusable", systemImage: "repeat").font(.caption).foregroundStyle(.blue)
                }
                if key.ephemeral {
                    Label("Ephemeral", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                if let exp = key.expirationDate {
                    Text("Exp: \(exp.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(key.isExpired ? .red : .secondary)
                } else {
                    Text("No expiry").font(.caption2).foregroundStyle(.secondary)
                }
                if let created = key.createdAt, let date = created.headscaleDate() {
                    Text("Created: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if !key.aclTags.isEmpty {
                Text(key.aclTags.joined(separator: ", "))
                    .font(.caption2).foregroundStyle(.purple)
            }

            if let err = error {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing) {
            if !key.isExpired {
                Button("Expire", role: .destructive) { showExpire = true }
            }
        }
        .swipeActions(edge: .leading) {
            Button("Copy ID") { UIPasteboard.general.string = key.id }
                .tint(.blue)
        }
        .confirmationDialog("Expire key \(key.id)?", isPresented: $showExpire, titleVisibility: .visible) {
            Button("Expire", role: .destructive) { Task { await expire() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    func expire() async {
        do { try await api.expirePreAuthKey(key: key); await onRefresh() }
        catch { self.error = error.localizedDescription }
    }
}

struct CreatePreAuthKeySheet: View {
    let api: HeadscaleAPI
    let users: [HeadscaleUser]
    let onCreated: (HeadscalePreAuthKey) -> Void
    @State private var selectedUserId = ""
    @State private var reusable = false
    @State private var ephemeral = false
    @State private var hasExpiry = true
    @State private var expiry: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var aclTagsText = ""
    @State private var isCreating = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("User") {
                    Picker("Assign to", selection: $selectedUserId) {
                        ForEach(users) { u in
                            Text(u.name).tag(u.id)
                        }
                    }
                }

                Section("Options") {
                    Toggle("Reusable", isOn: $reusable)
                    Toggle("Ephemeral", isOn: $ephemeral)
                }

                Section("Expiry") {
                    Toggle("Set Expiry", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expires", selection: $expiry, in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section {
                    TextField("tag:server, tag:iot", text: $aclTagsText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("ACL Tags (optional)")
                } footer: {
                    Text("Comma-separated. Tags must be defined in your ACL policy.")
                }

                if let err = error {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Pre-Auth Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(selectedUserId.isEmpty || isCreating)
                }
            }
        }
        .onAppear {
            if selectedUserId.isEmpty, let first = users.first { selectedUserId = first.id }
        }
    }

    func create() async {
        isCreating = true; error = nil
        let tags = aclTagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        do {
            let key = try await api.createPreAuthKey(userId: selectedUserId, reusable: reusable,
                                                     ephemeral: ephemeral,
                                                     expiration: hasExpiry ? expiry : nil,
                                                     aclTags: tags)
            onCreated(key)
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}
