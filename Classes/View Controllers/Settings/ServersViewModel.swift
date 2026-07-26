//
//  ServersViewModel.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import Resolver
import CocoaLumberjackSwift

// Backs the SwiftUI server list: loading the servers, switching the active server
// (ping + ServerSwitcher teardown), and deletion with the current-server replacement
// rules from the old ServersViewController.
@MainActor @Observable final class ServersViewModel {
    struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        // A confirm/cancel pair when set (the Combined Library intro and exit
        // notices); a plain OK alert otherwise
        var confirmTitle: String? = nil
        var confirmAction: (() -> Void)? = nil
    }

    // One sheet state for both flows — two chained .sheet modifiers on the same view
    // are unreliable, so add/edit share a single item-driven sheet
    enum Sheet: Identifiable {
        case add
        case edit(Server)

        var id: Int {
            switch self {
            case .add: return -1
            case .edit(let server): return server.id
            }
        }

        var serverToEdit: Server? {
            switch self {
            case .add: return nil
            case .edit(let server): return server
            }
        }
    }

    @ObservationIgnored @Injected private var store: Store
    @ObservationIgnored @Injected private var settings: SavedSettings
    @ObservationIgnored @Injected private var serverSwitcher: ServerSwitcher
    @ObservationIgnored @Injected private var redirects: ServerRedirectRegistry
    @ObservationIgnored @Injected private var downloadQueue: DownloadQueueing
    @ObservationIgnored @Injected private var playQueue: PlayQueue

    private(set) var servers = [Server]()
    var alert: AlertInfo?
    var sheet: Sheet?

    @ObservationIgnored private var checkTask: Task<Void, Never>?
    @ObservationIgnored private var observers = [NSObjectProtocol]()

    init() {
        reload()
        // The edit sheet posts reloadServerList after saving; serverSwitched fires
        // after any switch so the checkmark moves
        for name in [Notifications.reloadServerList, Notifications.serverSwitched] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reload()
                }
            })
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func reload() {
        servers = store.servers()
    }

    func isCurrent(_ server: Server) -> Bool {
        settings.currentServer == server
    }

    var isCombinedActive: Bool {
        settings.isCombinedContext
    }

    // Enter the Combined Library: a one-time explainer, then an instant context
    // switch — no blocking pings (each merged screen surfaces its own per-server
    // errors; the background check refreshes reachability and capabilities)
    func selectCombined(coordinator: SettingsCoordinator?) {
        guard !settings.isCombinedContext else {
            coordinator?.popSettings()
            return
        }
        guard settings.hasSeenCombinedIntro else {
            alert = AlertInfo(title: CombinedLibraryStrings.introTitle,
                              message: CombinedLibraryStrings.introMessage,
                              confirmTitle: CombinedLibraryStrings.introConfirm,
                              confirmAction: { [weak self] in
                                  self?.settings.hasSeenCombinedIntro = true
                                  self?.enterCombined(coordinator: coordinator)
                              })
            return
        }
        enterCombined(coordinator: coordinator)
    }

    private func enterCombined(coordinator: SettingsCoordinator?) {
        serverSwitcher.switchContext(to: .combined)
        reload()
        NotificationCenter.postOnMainThread(name: Notifications.checkServer)
        coordinator?.popSettings()
    }

    // Ping the server, persist its capabilities, make it current, and run the switch
    // teardown; on success the settings stack pops back to its root. Leaving the
    // Combined Library shows a one-time note that its state is kept.
    func select(_ server: Server, coordinator: SettingsCoordinator?) {
        if settings.isCombinedContext && !settings.hasSeenCombinedExitNote {
            alert = AlertInfo(title: CombinedLibraryStrings.exitTitle,
                              message: CombinedLibraryStrings.exitMessage,
                              confirmTitle: CombinedLibraryStrings.exitConfirm,
                              confirmAction: { [weak self] in
                                  self?.settings.hasSeenCombinedExitNote = true
                                  self?.startSelect(server, coordinator: coordinator)
                              })
            return
        }
        startSelect(server, coordinator: coordinator)
    }

    private func startSelect(_ server: Server, coordinator: SettingsCoordinator?) {
        checkTask?.cancel()

        let task = Task {
            do {
                defer {
                    HUD.hide()
                }

                let responseData = try await AsyncStatusLoader(server: server).load()
                try Task.checkCancellation()
                DDLogInfo("[ServersViewModel] server verification passed")

                server.isVideoSupported = responseData.isVideoSupported
                server.isNewSearchSupported = responseData.isNewSearchSupported
                server.isJsonSupported = responseData.isJsonSupported
                server.type = responseData.serverType
                _ = store.add(server: server)

                serverSwitcher.switchContext(to: .server(server))
                reload()
                coordinator?.popSettings()
            } catch {
                if error.isCanceled {
                    return
                }
                DDLogError("[ServersViewModel] server verification failed")

                let message: String
                if let error = error as? SubsonicError, case .badCredentials = error {
                    message = "Either your username or password is incorrect\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError code \(error.code):\n\(error.localizedDescription)"
                } else {
                    message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Choose a server to return to online mode. ☆☆\n\nError: \(error)"
                }
                alert = AlertInfo(title: "Server Unavailable", message: message)
            }
        }
        checkTask = task

        HUD.show(message: "Checking Server") {
            HUD.hide()
            task.cancel()
        }
    }

    func delete(at offsets: IndexSet) {
        for server in offsets.map({ servers[$0] }) {
            delete(server)
        }
    }

    private func delete(_ server: Server) {
        let wasCurrentServer = settings.currentServer == server

        // Stop an in-flight download for this server before its rows and files
        // vanish; start() below advances to the next remaining queued song
        let hadInFlightDownload = downloadQueue.currentQueuedSong?.serverId == server.id
        if hadInFlightDownload {
            downloadQueue.stop()
        }

        // Deletes the row plus all of the server's records and downloaded files
        _ = store.deleteServer(id: server.id)
        redirects.clearRedirect(serverId: server.id)
        reload()

        if hadInFlightDownload {
            downloadQueue.start()
        }

        // The cascade may have removed this server's songs from the live queue rows
        // (they can sit in any context's queue); re-clamp the in-memory index and let
        // the queue UI reload
        if playQueue.currentIndex >= playQueue.count {
            playQueue.currentIndex = max(0, playQueue.count - 1)
        }
        NotificationCenter.postOnMainThread(name: Notifications.currentPlaylistSongsQueued)

        // While the Combined Library is active every server is "in use": with two or
        // more remaining it stays active and the merged screens refresh; dropping to
        // one forces a switch to that server (no exit note — this wasn't a choice).
        // The notice presents BEFORE the switch pops the tab stacks: presenting from
        // a screen the pop is dismantling wedges the navigation state.
        if settings.isCombinedContext {
            if servers.count >= 2 {
                serverSwitcher.reloadContext()
            } else if let remaining = servers.first {
                if settings.isPopupsEnabled {
                    alert = AlertInfo(title: "Notice", message: CombinedLibraryStrings.forcedSwitchMessage(serverLabel: remaining.displayLabel))
                }
                // resetTabs: false — popping the settings stack out from under the
                // notice alert wedges the navigation (tab bar never returns), and the
                // merged root screens all refresh themselves on serverSwitched anyway
                serverSwitcher.switchContext(to: .server(remaining), resetTabs: false)
                reload()
            } else {
                serverSwitcher.switchContext(to: nil, resetTabs: false)
                sheet = .add
            }
            return
        }

        // When the current server was deleted, automatically switch to another server,
        // or show the add-server sheet when none remain. As above, the notice
        // presents before the switch's tab pops.
        guard wasCurrentServer else { return }
        if let replacement = servers.first {
            if settings.isPopupsEnabled {
                alert = AlertInfo(title: "Notice", message: "The active server was deleted, so iSub switched to \(replacement.displayLabel)")
            }
            serverSwitcher.switchContext(to: .server(replacement))
        } else {
            // The deleted server's rows and files are already gone, but playback,
            // streams, and jukebox mode may still reference it — run the same switch
            // teardown as the replacement path. Keep the navigation stacks though:
            // popping would remove this ServersView and drop the add-server sheet it
            // is about to present.
            serverSwitcher.switchContext(to: nil, resetTabs: false)
            sheet = .add
        }
    }
}
