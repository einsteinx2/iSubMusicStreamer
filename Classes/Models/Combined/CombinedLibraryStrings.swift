//
//  CombinedLibraryStrings.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// User-facing copy for the Combined Library flows, shared by the alerts and their
// tests. The intro and exit notices show once (SavedSettings.hasSeenCombinedIntro /
// hasSeenCombinedExitNote); the forced-switch notice shows whenever deleting servers
// leaves fewer than two while Combined is active.
enum CombinedLibraryStrings {
    static let introTitle = "Combined Library"
    static let introConfirm = "Enable"
    static let introMessage = """
        Combined Library merges every saved server into one library. Artists, folders, \
        search, and browse lists show items from all of your servers, each labeled with \
        its server.

        Combined Library keeps its own play queue, local playlists, and bookmarks, \
        separate from each server's. A few per-server features — jukebox mode, server \
        chat, and saving playlists to a server — are unavailable while it's active.

        You can switch back to a single server anytime from this screen.
        """

    static let exitTitle = "Switching to a Single Server"
    static let exitConfirm = "Switch"
    static let exitMessage = """
        Your Combined Library play queue, local playlists, and bookmarks are saved. \
        They'll be right where you left them the next time you open Combined Library.
        """

    static func forcedSwitchMessage(serverLabel: String) -> String {
        "Combined Library needs at least two servers, so iSub switched to \(serverLabel)."
    }
}
