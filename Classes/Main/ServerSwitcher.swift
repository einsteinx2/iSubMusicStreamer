//
//  ServerSwitcher.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

// The teardown that runs when the active server changes, extracted from the old
// ServersViewController so the SwiftUI server list and edit screens share it: cancel
// caching, stop playback, exit jukebox/offline mode, clear the queues, reset the tab
// stacks, and post serverSwitched. The single-database Store needs no reset — all
// tables are serverId-scoped. Navigation within the settings screens is the caller's
// responsibility. Not final so tests can substitute a fake that skips the UIKit work.
class ServerSwitcher {
    private let streamManager: StreamManaging
    private let player: PlayerControlling
    private let playQueue: PlayQueue
    private let downloadQueue: DownloadQueueing
    private let settings: SavedSettings
    private let networkStatus: NetworkStatus

    init(streamManager: StreamManaging, player: PlayerControlling, playQueue: PlayQueue, downloadQueue: DownloadQueueing, settings: SavedSettings, networkStatus: NetworkStatus) {
        self.streamManager = streamManager
        self.player = player
        self.playQueue = playQueue
        self.downloadQueue = downloadQueue
        self.settings = settings
        self.networkStatus = networkStatus
    }

    // resetTabs: false keeps the navigation stacks in place — used when deleting the
    // last server, where popping would tear down the ServersView that is about to
    // present the add-server sheet
    func switchServer(resetTabs: Bool = true) {
        // The teardown below is all local — it must run even with no network, or a
        // server switch/delete leaves streams, the queue, and jukebox mode pointing
        // at the old server (the caller has already reassigned currentServer)

        // Cancel any caching
        streamManager.removeAllStreams()

        // Stop any playing song
        player.stop()
        settings.isRecover = false
        if settings.isJukeboxEnabled {
            // Post the mode-change notification instead of only flipping the raw
            // setting so JukeboxPlaybackMode deactivates (stopping the getInfo
            // polling chain from hitting the new server) and the window tint resets
            settings.isJukeboxEnabled = false
            NotificationCenter.postOnMainThread(name: Notifications.jukeboxDisabled)
        }

        // Only exit offline mode when the network is actually reachable
        if settings.isOfflineMode && networkStatus.isNetworkReachable {
            settings.isOfflineMode = false

            // The phone scene may not exist (e.g. a CarPlay-only launch); the UI
            // cleanup below is skipped, not required, in that case
            if UIDevice.isPad {
                SceneDelegate.shared?.padRootViewController?.menuViewController.toggleOfflineMode()
            } else if let window = SceneDelegate.shared?.window {
                for subview in window.subviews {
                    subview.removeFromSuperview()
                }
            }
        }

        // Reset the data model
        _ = playQueue.clear()
        _ = downloadQueue.clear()

        // Reset the tabs
        if resetTabs, !UIDevice.isPad, let viewControllers = SceneDelegate.shared?.tabBarController?.viewControllers {
            for controller in viewControllers {
                if let controller = controller as? UINavigationController {
                    controller.popToRootViewController(animated: true)
                }
            }
        }

        NotificationCenter.postOnMainThread(name: Notifications.serverSwitched)
    }
}
