//
//  ServerLabels.swift
//  iSub
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import Resolver

// Cached serverId → display label (nickname falling back to host) so list cells can
// badge rows without a database read per cell. Only the Combined Library shows
// badges: badgeText is nil otherwise, so cells call it unconditionally and stay
// badge-free in single-server mode. Invalidated when the server list or the active
// context changes.
@MainActor
final class ServerLabels {
    static let shared = ServerLabels()

    private var labelsByServerId: [Int: String]?
    private var observers = [NSObjectProtocol]()

    private var store: Store { Resolver.resolve() }
    private var settings: SavedSettings { Resolver.resolve() }

    init() {
        for name in [Notifications.reloadServerList, Notifications.serverSwitched] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.invalidate()
                }
            })
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // The display label for a server, or nil for ids that aren't servers (e.g. the
    // -1 on local playlist models)
    func label(serverId: Int) -> String? {
        if labelsByServerId == nil {
            labelsByServerId = Dictionary(uniqueKeysWithValues: store.servers().map { ($0.id, $0.displayLabel) })
        }
        return labelsByServerId?[serverId]
    }

    func badgeText(serverId: Int) -> String? {
        guard settings.isCombinedContext else { return nil }
        return label(serverId: serverId)
    }

    func invalidate() {
        labelsByServerId = nil
    }
}
