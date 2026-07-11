//
//  ServerSession.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

/// The active server connection state: which server the app is talking to, the redirect
/// URL negotiated for it, and whether the app is currently in offline mode.
///
/// Split out of SavedSettings (Phase 8.1) so session state has a single owner.
/// SavedSettings owns this instance strongly and forwards the legacy property names
/// (currentServer, currentServerId, currentServerRedirectUrlString, isOfflineMode) so
/// existing view controllers, services, and tests keep compiling untouched. That
/// SavedSettings→ServerSession ownership is a deliberate, acyclic compatibility shim —
/// new code should inject ServerSession directly.
final class ServerSession {
    // Shares the SavedSettings.defaults swap point so tests stay sandboxed
    private var defaults: UserDefaults { SavedSettings.defaults }

    var currentServerId: Int {
        return currentServer?.id ?? -1
    }

    var currentServer: Server? {
        didSet {
            currentServerRedirectUrlString = nil
            defaults.set(currentServer?.id, forKey: .currentServerId)
            defaults.synchronize()
        }
    }

    var currentServerRedirectUrlString: String?

    var isOfflineMode: Bool = false

    func setup(store: Store) {
        if let id = defaults.object(forKey: .currentServerId) as? Int {
            // Load the current server object
            currentServer = store.server(id: id)
        }
    }
}
