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

    init(streamManager: StreamManaging, player: PlayerControlling, playQueue: PlayQueue, downloadQueue: DownloadQueueing, settings: SavedSettings) {
        self.streamManager = streamManager
        self.player = player
        self.playQueue = playQueue
        self.downloadQueue = downloadQueue
        self.settings = settings
    }

    func switchServer() {
        guard SceneDelegate.shared.isNetworkReachable else { return }

        // Cancel any caching
        streamManager.removeAllStreams()

        // Stop any playing song
        player.stop()
        settings.isRecover = false
        settings.isJukeboxEnabled = false

        if settings.isOfflineMode {
            settings.isOfflineMode = false

            if UIDevice.isPad {
                SceneDelegate.shared.padRootViewController?.menuViewController.toggleOfflineMode()
            } else if let window = SceneDelegate.shared.window {
                for subview in window.subviews {
                    subview.removeFromSuperview()
                }
            }
        }

        // Reset the data model
        _ = playQueue.clear()
        _ = downloadQueue.clear()

        // Reset the tabs
        if !UIDevice.isPad, let viewControllers = SceneDelegate.shared.tabBarController?.viewControllers {
            for controller in viewControllers {
                if let controller = controller as? UINavigationController {
                    controller.popToRootViewController(animated: true)
                }
            }
        }

        NotificationCenter.postOnMainThread(name: Notifications.serverSwitched)
    }
}
