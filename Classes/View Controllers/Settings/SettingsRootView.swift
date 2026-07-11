//
//  SettingsRootView.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import Resolver

// The top-level settings screen, styled like the iOS Settings app: Servers first,
// then one row per settings section, then About
struct SettingsRootView: View {
    @Environment(\.settingsCoordinator) private var coordinator

    private let settings: SavedSettings = Resolver.resolve()
    private let store: Store = Resolver.resolve()

    @State private var hasAutoShownServers = false

    var body: some View {
        List {
            Section {
                Button {
                    coordinator?.showServers()
                } label: {
                    SettingsRootRow(systemImage: "server.rack",
                                    iconColor: .blue,
                                    title: "Servers",
                                    subtitle: settings.currentServer?.url.absoluteString)
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
            // First run: no servers yet, so go straight to the server list, which
            // auto-presents the add-server sheet
            if !hasAutoShownServers && store.servers().isEmpty {
                hasAutoShownServers = true
                coordinator?.showServers()
            }
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
