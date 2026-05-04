import SwiftUI

struct ActivityView: View {
    @State private var log = ActivityLog.shared
    @State private var showClearConfirm = false
    @State private var filterAction: ActivityAction?
    @State private var showFailuresOnly = false

    var filtered: [ActivityEntry] {
        log.entries.filter { entry in
            if showFailuresOnly && entry.success { return false }
            if let f = filterAction, entry.action != f { return false }
            return true
        }
    }

    var grouped: [(Date, [ActivityEntry])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.timestamp) }
        return dict.keys.sorted(by: >).map { ($0, dict[$0] ?? []) }
    }

    var body: some View {
        Group {
            if log.entries.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Actions you take in HeadCtrl will appear here."))
            } else if filtered.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No entries match the current filter."))
            } else {
                List {
                    ForEach(grouped, id: \.0) { day, entries in
                        Section(day.formatted(date: .complete, time: .omitted)) {
                            ForEach(entries) { entry in
                                ActivityRowView(entry: entry)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Failures only", isOn: $showFailuresOnly)
                    Divider()
                    Button("All Actions") { filterAction = nil }
                    ForEach(ActivityAction.allCases, id: \.self) { action in
                        Button {
                            filterAction = action
                        } label: {
                            Label(action.displayName, systemImage: action.systemImage)
                        }
                    }
                    if !log.entries.isEmpty {
                        Divider()
                        Button("Clear All", systemImage: "trash", role: .destructive) {
                            showClearConfirm = true
                        }
                    }
                } label: {
                    Image(systemName: filterAction == nil && !showFailuresOnly
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .confirmationDialog("Clear Activity Log?",
                            isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { log.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all locally-recorded activity. The action cannot be undone.")
        }
    }
}

struct ActivityRowView: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.action.systemImage)
                .font(.body)
                .foregroundStyle(entry.success ? Color.blue : Color.red)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.action.displayName)
                        .font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Text(entry.target)
                    .font(.caption).foregroundStyle(.secondary).monospaced()
                if let detail = entry.detail {
                    Text(detail).font(.caption2).foregroundStyle(.tertiary)
                }
                if let err = entry.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.caption2).foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
