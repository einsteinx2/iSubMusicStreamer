//
//  ServersView.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI

// The server list: tap a row to switch to that server (Wi-Fi-settings style), tap the
// info button to edit it, swipe (or use Edit mode) to delete. The add-server sheet
// auto-presents when no servers exist yet (first run).
struct ServersView: View {
    @Environment(\.settingsCoordinator) private var coordinator

    @State private var viewModel = ServersViewModel()

    var body: some View {
        @Bindable var viewModel = viewModel
        List {
            // Outside the servers ForEach so Edit mode's delete offsets stay aligned
            // and the row gets no delete affordance
            if viewModel.servers.count > 1 {
                Section {
                    CombinedLibraryRow(isCurrent: viewModel.isCombinedActive,
                                       serverCount: viewModel.servers.count,
                                       selectAction: { viewModel.selectCombined(coordinator: coordinator) })
                }
            }
            Section {
                ForEach(viewModel.servers) { server in
                    ServerRow(server: server,
                              isCurrent: viewModel.isCurrent(server),
                              selectAction: { viewModel.select(server, coordinator: coordinator) },
                              editAction: { viewModel.sheet = .edit(server) })
                }
                .onDelete { offsets in
                    viewModel.delete(at: offsets)
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier(AccessibilityId.serversList)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.sheet = .add
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier(AccessibilityId.serversAdd)
            }
        }
        .alert(item: $viewModel.alert) { alert in
            if let confirmTitle = alert.confirmTitle, let confirmAction = alert.confirmAction {
                Alert(title: Text(alert.title), message: Text(alert.message),
                      primaryButton: .default(Text(confirmTitle), action: confirmAction),
                      secondaryButton: .cancel())
            } else {
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
        .sheet(item: $viewModel.sheet) { sheet in
            ServerEditView(serverToEdit: sheet.serverToEdit)
        }
        .onAppear {
            viewModel.reload()
            if viewModel.servers.isEmpty {
                // First run: auto-present the add-server sheet. Presenting during this
                // screen's own push transition gets dropped by UIKit (the hosting
                // controller isn't in the window yet), so wait for it to finish.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    if viewModel.servers.isEmpty && viewModel.sheet == nil {
                        viewModel.sheet = .add
                    }
                }
            }
        }
    }
}

// The pinned Combined Library entry, shown only when there is something to combine
private struct CombinedLibraryRow: View {
    let isCurrent: Bool
    let serverCount: Int
    let selectAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCurrent ? Color.accentColor : Color(.tertiaryLabel))
                .accessibilityLabel(isCurrent ? "Current selection" : "")

            VStack(alignment: .leading, spacing: 2) {
                Text("Combined Library")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Browse all \(serverCount) servers as one library")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(Color.accentColor)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: selectAction)
        .accessibilityIdentifier(AccessibilityId.serversCombined)
    }
}

// Wi-Fi-settings-style row: tapping the content selects/switches to the server; the
// trailing info button edits it. The two are siblings (not nested buttons) so each
// gets a real hit area — nesting the info button inside a row-spanning Button left
// it without one, sending edit taps to the select action.
private struct ServerRow: View {
    let server: Server
    let isCurrent: Bool
    let selectAction: () -> Void
    let editAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCurrent ? Color.accentColor : Color(.tertiaryLabel))
                    .accessibilityLabel(isCurrent ? "Current server" : "")

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.displayLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        ServerTypeBadge(type: server.type)
                        Text("\(server.username) @ \(server.url.absoluteString)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: selectAction)

            Button(action: editAction) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(AccessibilityId.serversEdit)
        }
    }
}

// A small capsule naming the detected server type. Unknown/legacy servers show the
// generic Subsonic badge (their pings don't identify themselves).
struct ServerTypeBadge: View {
    let type: ServerType

    private var color: Color {
        switch type {
        case .none: return .gray
        case .subsonic: return .orange
        case .navidrome: return .blue
        case .airsonic: return .teal
        case .gonic: return .green
        case .lms: return .purple
        case .ampache: return .red
        case .openSubsonic: return .indigo
        }
    }

    var body: some View {
        Text(type.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}
