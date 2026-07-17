//
//  ServerSwitcher.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import UIKit

// Switches the active library context (a server, or the Combined Library): saves the
// outgoing context's queue + playback state, restores the incoming context's, runs
// the teardown that must not span contexts (stream caching, playback, jukebox mode,
// offline mode), resets the tab stacks, and posts serverSwitched. The single-database
// Store needs no reset — all tables are serverId-scoped, and each context's playlists
// and bookmarks are contextId-scoped. Navigation within the settings screens is the
// caller's responsibility. Not final so tests can substitute a fake that skips the
// UIKit work.
class ServerSwitcher {
    private let streamManager: StreamManaging
    private let player: PlayerControlling
    private let settings: SavedSettings
    private let session: ServerSession
    private let store: Store
    private let stateRestorer: StateRestorer

    init(streamManager: StreamManaging, player: PlayerControlling, settings: SavedSettings, session: ServerSession, store: Store, stateRestorer: StateRestorer) {
        self.streamManager = streamManager
        self.player = player
        self.settings = settings
        self.session = session
        self.store = store
        self.stateRestorer = stateRestorer
    }

    // resetTabs: false keeps the navigation stacks in place — used when deleting the
    // last server, where popping would tear down the ServersView that is about to
    // present the add-server sheet
    func switchContext(to newContext: LibraryContext?, resetTabs: Bool = true) {
        // Everything below is local — it must run even with no network, or a context
        // switch/delete leaves streams, the queue, and jukebox mode pointing at the
        // old context

        // Capture the outgoing playback state BEFORE any teardown: once the player
        // stops, its live progress is gone (capture falls back to the primed offsets,
        // which are only right for a context that never started playing)
        let outgoingState = stateRestorer.captureSnapshot()

        // Never save a snapshot for a context whose server row is gone — the
        // delete-active-server path removes the row (and its snapshot) first
        let outgoingContextId: Int?
        switch session.activeContext {
        case .combined:
            outgoingContextId = LibraryContext.combinedContextId
        case .server(let server):
            outgoingContextId = store.server(id: server.id) != nil ? server.id : nil
        case nil:
            outgoingContextId = nil
        }

        // Save the outgoing queue + state and restore the incoming context's in one
        // transaction (the marker moves with it, so a crash here heals at launch)
        let incomingState = store.swapLiveQueue(outgoingContextId: outgoingContextId,
                                                outgoingState: outgoingState,
                                                incomingContextId: newContext?.contextId ?? LibraryContext.noContextId)

        session.setActiveContext(newContext)

        // Cancel any caching
        streamManager.removeAllStreams()

        // Stop any playing song
        player.stop()
        if settings.isJukeboxEnabled {
            // Post the mode-change notification instead of only flipping the raw
            // setting so JukeboxPlaybackMode deactivates (stopping the getInfo
            // polling chain from hitting the new server) and the window tint resets
            settings.isJukeboxEnabled = false
            NotificationCenter.postOnMainThread(name: Notifications.jukeboxDisabled)
        }

        // Only exit offline mode when the network is actually reachable
        if settings.isOfflineMode && SceneDelegate.shared.isNetworkReachable {
            settings.isOfflineMode = false

            if UIDevice.isPad {
                SceneDelegate.shared.padRootViewController?.menuViewController.toggleOfflineMode()
            } else if let window = SceneDelegate.shared.window {
                for subview in window.subviews {
                    subview.removeFromSuperview()
                }
            }
        }

        // NOTE: the queues are no longer cleared here — the incoming context's queue
        // was just restored by the swap, and queued downloads continue across
        // switches (the download engine is per-song)

        // Bring the incoming context back paused and primed at its saved position
        stateRestorer.apply(snapshot: incomingState)

        // Reset the tabs
        if resetTabs, !UIDevice.isPad, let viewControllers = SceneDelegate.shared.tabBarController?.viewControllers {
            for controller in viewControllers {
                if let controller = controller as? UINavigationController {
                    controller.popToRootViewController(animated: true)
                }
            }
        }

        NotificationCenter.postOnMainThread(name: Notifications.serverSwitched)
    }

    // The context membership changed while the context itself stays active (a server
    // was added or removed while the Combined Library is on): refresh every
    // serverSwitched observer without a queue save/restore cycle
    func reloadContext() {
        NotificationCenter.postOnMainThread(name: Notifications.serverSwitched)
    }
}
