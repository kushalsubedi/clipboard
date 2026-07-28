import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ClipboardStore
    @State private var expandedClipId: Int64?
    @State private var showingNewSession = false
    @State private var newSessionName = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            searchBar
            if store.filteredClips.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(store.filteredClips) { clip in
                            ClipRow(
                                clip: clip,
                                isExpanded: expandedClipId == clip.id,
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        expandedClipId = (expandedClipId == clip.id) ? nil : clip.id
                                    }
                                }
                            )
                        }
                    }
                    .padding(10)
                }
            }
            Divider().opacity(0.2)
            footer
        }
        .frame(width: 360, height: 480)
        .background(.ultraThinMaterial)
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundStyle(.tint)
            Text("Clipboard")
                .font(.system(.headline, design: .rounded))
            Spacer()
            sessionMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var sessionMenu: some View {
        Menu {
            ForEach(store.sessions) { session in
                Button {
                    store.switchSession(to: session.id)
                } label: {
                    if session.id == store.currentSessionId {
                        Label(session.name, systemImage: "checkmark")
                    } else {
                        Text(session.name)
                    }
                }
            }
            Divider()
            Button("New Session…") { showingNewSession = true }
            if store.sessions.count > 1, let current = store.currentSession {
                Button("Delete “\(current.name)”", role: .destructive) {
                    store.deleteSession(current)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(store.currentSession?.name ?? "Session")
                    .font(.system(.caption, design: .rounded))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .popover(isPresented: $showingNewSession) {
            newSessionPopover
        }
    }

    private var newSessionPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("New Session").font(.headline)
            TextField("Session name", text: $newSessionName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { createSession() }
            HStack {
                Spacer()
                Button("Cancel") { showingNewSession = false }
                Button("Create") { createSession() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 240)
    }

    private func createSession() {
        store.createSession(name: newSessionName)
        newSessionName = ""
        showingNewSession = false
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clips…", text: $store.searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(store.searchText.isEmpty ? "Copy something to get started" : "No matches")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(store.filteredClips.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Clear Unpinned") { store.clearUnpinned() }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Divider().frame(height: 12)
            Menu {
                Toggle("Open on Hover", isOn: $store.openOnHover)
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Settings")
            Divider().frame(height: 12)
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
