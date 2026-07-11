//
//  SettingsMetadata.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// The top-level groups shown on the settings root screen. Servers is not listed here
// because it's a hand-built screen backed by the server store, not by SavedSettings.
enum SettingsSection: Int, CaseIterable, Identifiable {
    case network
    case downloads
    case playback
    case appearanceBehavior
    case about

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .network: return "Network & Streaming"
        case .downloads: return "Downloads & Cache"
        case .playback: return "Playback"
        case .appearanceBehavior: return "Appearance & Behavior"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .network: return "antenna.radiowaves.left.and.right"
        case .downloads: return "arrow.down.circle"
        case .playback: return "play.circle"
        case .appearanceBehavior: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

// Display metadata attached to a @UserDefault property. A property with a SettingUI
// automatically appears as a row in the settings UI (see SettingsRegistry); a property
// without one is internal-only.
struct SettingUI {
    enum Kind {
        // A Bool switch row
        case toggle
        // An Int stored as the index into labels
        case picker(labels: [String])
        // An Int stored as the value at the same position as its label (e.g. quick
        // skip stores seconds, not an index)
        case pickerMapped(labels: [String], values: [Int])
        // A Float in 0...1 shown as a slider with a live percent label
        case percentSlider
    }

    // An alert shown before a toggle is turned ON; canceling leaves it off. Turning
    // the toggle off never prompts.
    struct Confirmation {
        let title: String
        let message: String
    }

    let title: String
    let section: SettingsSection
    let kind: Kind
    var footer: String? = nil
    var accessibilityId: String? = nil
    var confirmation: Confirmation? = nil
    // When set, the row is disabled unless this Bool setting is true
    var dependsOn: SavedSettings.Key? = nil
}
