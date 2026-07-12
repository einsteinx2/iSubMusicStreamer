//
//  SettingsRootView.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import Combine
import Resolver

// The top-level settings screen, styled like the iOS Settings app: Servers first,
// then one row per settings section, then About
struct SettingsRootView: View {
    @Environment(\.settingsCoordinator) private var coordinator

    private let settings: SavedSettings = Resolver.resolve()
    private let analytics: Analytics = Resolver.resolve()

    // The current server URL is plain state refreshed on appear and on the server
    // notifications — reading settings.currentServer directly in body would be
    // evaluated once and go stale after adding/switching servers (SavedSettings is
    // not observable)
    @State private var currentServerURL: String?

    var body: some View {
        List {
            Section {
                Button {
                    coordinator?.showServers()
                } label: {
                    SettingsRootRow(systemImage: "server.rack",
                                    iconColor: .blue,
                                    title: "Servers",
                                    subtitle: currentServerURL)
                }
                .accessibilityIdentifier(AccessibilityId.settingsSectionServers)
            }

            Section {
                ForEach(SettingsSection.allCases.filter { $0 != .about }) { section in
                    Button {
                        coordinator?.showSection(section)
                    } label: {
                        SettingsRootRow(systemImage: section.systemImage,
                                        iconColor: section.iconColor,
                                        title: section.title)
                    }
                    .accessibilityIdentifier(section.accessibilityId)
                }
            }

            Section {
                Button {
                    coordinator?.showSection(.about)
                } label: {
                    SettingsRootRow(systemImage: SettingsSection.about.systemImage,
                                    iconColor: SettingsSection.about.iconColor,
                                    title: SettingsSection.about.title)
                }
                .accessibilityIdentifier(SettingsSection.about.accessibilityId)
            }
        }
        .listStyle(.insetGrouped)
        .onAppear {
            currentServerURL = settings.currentServer?.url.absoluteString
            analytics.log(event: .settingsTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notifications.serverSwitched).receive(on: RunLoop.main)) { _ in
            currentServerURL = settings.currentServer?.url.absoluteString
        }
        .onReceive(NotificationCenter.default.publisher(for: Notifications.reloadServerList).receive(on: RunLoop.main)) { _ in
            currentServerURL = settings.currentServer?.url.absoluteString
        }
    }
}

// An iOS-Settings-style row: tinted icon tile, title, optional subtitle, chevron
struct SettingsRootRow: View {
    let systemImage: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 6.5))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

extension SettingsSection {
    var iconColor: Color {
        switch self {
        case .network: return .blue
        case .downloads: return .green
        case .playback: return .pink
        case .appearanceBehavior: return .purple
        case .about: return .gray
        }
    }

    var accessibilityId: String {
        switch self {
        case .network: return "settings.section.network"
        case .downloads: return "settings.section.downloads"
        case .playback: return "settings.section.playback"
        case .appearanceBehavior: return "settings.section.appearanceBehavior"
        case .about: return "settings.section.about"
        }
    }
}
