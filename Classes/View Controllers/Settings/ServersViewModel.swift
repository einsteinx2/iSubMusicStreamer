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

    // Ping the server, persist its capabilities, make it current, and run the switch
    // teardown; on success the settings stack pops back to its root
    func select(_ server: Server, coordinator: SettingsCoordinator?) {
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
                server.type = responseData.serverType
                _ = store.add(server: server)

                settings.currentServer = server
                reload()
                serverSwitcher.switchServer()
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

        // Deletes the row plus all of the server's records and downloaded files
        _ = store.deleteServer(id: server.id)
        reload()

        // When the current server was deleted, automatically switch to another server,
        // or show the add-server sheet when none remain
        guard wasCurrentServer else { return }
        if let replacement = servers.first {
            settings.currentServer = replacement
            if settings.isPopupsEnabled {
                alert = AlertInfo(title: "Notice", message: "The active server was deleted, so iSub switched to \(replacement.url.absoluteString)")
            }
            serverSwitcher.switchServer()
        } else {
            settings.currentServer = nil
            // The deleted server's rows and files are already gone, but playback,
            // streams, the queues, and jukebox mode may still reference it — run the
            // same switch teardown as the replacement path. Keep the navigation
            // stacks though: popping would remove this ServersView and drop the
            // add-server sheet it is about to present.
            serverSwitcher.switchServer(resetTabs: false)
            sheet = .add
        }
    }
}
