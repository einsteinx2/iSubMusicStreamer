//
//  ServerSession.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

/// The active server connection state: which server the app is talking to and whether
/// the app is currently in offline mode. (Redirect URLs are per-server state and live
/// in ServerRedirectRegistry.)
///
/// Split out of SavedSettings (Phase 8.1) so session state has a single owner.
/// SavedSettings owns this instance strongly and forwards the legacy property names
/// (currentServer, currentServerId, isOfflineMode) so existing view controllers,
/// services, and tests keep compiling untouched. That SavedSettings→ServerSession
/// ownership is a deliberate, acyclic compatibility shim — new code should inject
/// ServerSession directly.
final class ServerSession {
    // Shares the SavedSettings.defaults swap point so tests stay sandboxed
    private var defaults: UserDefaults { SavedSettings.defaults }

    // The library context the app is operating in: a single server, the Combined
    // Library, or none (fresh install). ServerSwitcher.switchContext is the one
    // mutation path in production; the legacy currentServer setter maps onto it for
    // old callers and tests.
    private(set) var activeContext: LibraryContext?

    var activeContextId: Int {
        return activeContext?.contextId ?? LibraryContext.noContextId
    }

    var isCombinedContext: Bool {
        return activeContext == .combined
    }

    var currentServerId: Int {
        return currentServer?.id ?? -1
    }

    // The single active server; nil while the Combined Library is active (per-item
    // code paths use each model's own serverId instead)
    var currentServer: Server? {
        get { activeContext?.server }
        set { setActiveContext(newValue.map { .server($0) }) }
    }

    func setActiveContext(_ context: LibraryContext?) {
        activeContext = context
        defaults.set(context?.contextId, forKey: .activeContextId)
        // The legacy key stays in sync (nil while Combined): it feeds the per-server
        // media-folder defaults key names and the UI-test seeding path
        defaults.set(context?.server?.id, forKey: .currentServerId)
        defaults.synchronize()
    }

    var isOfflineMode: Bool = false

    func setup(store: Store) {
        // activeContextId is the source of truth; fall back to the legacy
        // currentServerId key for installs that predate library contexts
        let storedContextId = (defaults.object(forKey: .activeContextId) as? Int)
            ?? (defaults.object(forKey: .currentServerId) as? Int)
        switch storedContextId {
        case .some(LibraryContext.combinedContextId):
            // Combined requires servers to combine; an empty install falls to first-run
            activeContext = store.servers().isEmpty ? nil : .combined
        case .some(let id) where id > 0:
            // A deleted server resolves to nil, landing on the first-run screen
            activeContext = store.server(id: id).map { .server($0) }
        default:
            activeContext = nil
        }

        // Heal the live queue rows if a crash interrupted a context switch between
        // the database swap and the defaults write above
        store.reconcileLiveQueue(activeContextId: activeContextId)
    }

    // MARK: Offline-mode transitions (Phase 8.11)
    // The goOnline/goOffline request notifications are observed by SceneDelegate,
    // which forwards here with its network context; these flip the mode and post the
    // didEnter* fact notifications. Both return whether a transition happened.

    @discardableResult
    func enterOnlineMode(isNetworkReachable: Bool, isWifi: Bool, isForceOfflineMode: Bool, isDisableUsageOver3G: Bool) -> Bool {
        guard isOfflineMode && !isForceOfflineMode && isNetworkReachable && (isWifi || !isDisableUsageOver3G) else { return false }
        isOfflineMode = false
        NotificationCenter.postOnMainThread(name: Notifications.didEnterOnlineMode)
        return true
    }

    @discardableResult
    func enterOfflineMode() -> Bool {
        guard !isOfflineMode else { return false }
        isOfflineMode = true
        NotificationCenter.postOnMainThread(name: Notifications.didEnterOfflineMode)
        return true
    }
}
