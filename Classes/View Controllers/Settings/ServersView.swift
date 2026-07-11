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
            ForEach(viewModel.servers) { server in
                Button {
                    viewModel.select(server, coordinator: coordinator)
                } label: {
                    ServerRow(server: server, isCurrent: viewModel.isCurrent(server)) {
                        viewModel.serverToEdit = server
                    }
                }
            }
            .onDelete { offsets in
                viewModel.delete(at: offsets)
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
                    viewModel.addSheetPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier(AccessibilityId.serversAdd)
            }
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $viewModel.addSheetPresented) {
            ServerEditView()
        }
        .sheet(item: $viewModel.serverToEdit) { server in
            ServerEditView(serverToEdit: server)
        }
        .onAppear {
            viewModel.reload()
            if viewModel.servers.isEmpty {
                viewModel.addSheetPresented = true
            }
        }
    }
}

private struct ServerRow: View {
    let server: Server
    let isCurrent: Bool
    let editAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isCurrent ? Color.accentColor : Color(.tertiaryLabel))
                .accessibilityLabel(isCurrent ? "Current server" : "")

            VStack(alignment: .leading, spacing: 2) {
                Text(server.url.absoluteString)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ServerTypeBadge(type: server.type)
                    Text("username: \(server.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

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
