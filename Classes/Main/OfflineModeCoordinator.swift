//
//  OfflineModeCoordinator.swift
//  iSub
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift

// Owns the online/offline transitions and the launch offline check, extracted
// from SceneDelegate so they run for whichever scene appears first — with
// CarPlay, the app can launch with no phone window at all. SceneDelegate keeps
// only the alert presentation (consumePendingLaunchAlertMessage).
final class OfflineModeCoordinator {
    private let settings: SavedSettings
    private let session: ServerSession
    private let networkStatus: NetworkStatus
    private let playbackCoordinator: PlaybackCoordinator
    private let analytics: Analytics

    // Lazy because AppServices constructs this coordinator before the container
    // registrations exist, and ServerChecker resolves its dependencies with
    // @Injected at creation. First touch happens at scene activation, the same
    // point SceneDelegate used to create it.
    private(set) lazy var serverChecker = ServerChecker()

    private(set) var hasPerformedLaunchOfflineCheck = false
    // The launch check's alert text when no phone window existed to present it
    // (e.g. a CarPlay-first launch); the phone scene consumes it when it appears
    private var pendingLaunchAlertMessage: String?

    init(settings: SavedSettings, session: ServerSession, networkStatus: NetworkStatus, playbackCoordinator: PlaybackCoordinator, analytics: Analytics) {
        self.settings = settings
        self.session = session
        self.networkStatus = networkStatus
        self.playbackCoordinator = playbackCoordinator
        self.analytics = analytics

        // Request-side notifications posted by settings/UI/NetworkMonitor; the
        // session posts the didEnter* fact notifications when the flip happens
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(enterOnlineMode), name: Notifications.goOnline)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(enterOfflineMode), name: Notifications.goOffline)
    }

    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }

    // MARK: Launch check

    // Reproduces the old app's launch behavior (moved from SceneDelegate): enter
    // offline mode when the force-offline switch is on, there's no network, or
    // we're on cellular with cellular usage disabled — and only check the server
    // when staying online. Runs once per process, from whichever scene connects
    // first. Returns the explanatory alert message (nil means staying online);
    // the message is also stashed for the phone scene to present later.
    @discardableResult
    func performLaunchOfflineCheckIfNeeded() -> String? {
        guard !hasPerformedLaunchOfflineCheck else { return nil }
        hasPerformedLaunchOfflineCheck = true

        let alertMessage = SceneDelegate.launchOfflineAlertMessage(isForceOfflineMode: settings.isForceOfflineMode,
                                                                   isNetworkReachable: networkStatus.isNetworkReachable,
                                                                   isWifi: networkStatus.isWifi,
                                                                   isDisableUsageOver3G: settings.isDisableUsageOver3G)
        if let alertMessage {
            if settings.isOfflineMode {
                // Already offline (the mode was set before any scene loaded): still
                // announce it so the offline indicator banner and controls update
                NotificationCenter.postOnMainThread(name: Notifications.didEnterOfflineMode)
            } else {
                enterOfflineMode()
            }
            pendingLaunchAlertMessage = alertMessage
        } else {
            serverChecker.checkServer()
        }
        return alertMessage
    }

    // The phone scene presents the launch alert whenever it gets around to
    // appearing — possibly long after a CarPlay-first launch ran the check
    func consumePendingLaunchAlertMessage() -> String? {
        defer { pendingLaunchAlertMessage = nil }
        return pendingLaunchAlertMessage
    }

    // MARK: Scene activation

    // Shared by the phone scene's sceneDidBecomeActive and CarPlayManager.connect
    func sceneBecameActive() {
        if !hasPerformedLaunchOfflineCheck {
            performLaunchOfflineCheckIfNeeded()
        } else if networkStatus.isNetworkReachable {
            serverChecker.checkServer()
        } else {
            enterOfflineMode()
        }
    }

    func cancelNextServerCheck() {
        serverChecker.cancelNextServerCheck()
    }

    // MARK: Transitions (moved verbatim from SceneDelegate)

    @objc private func enterOnlineMode() {
        session.enterOnlineMode(isNetworkReachable: networkStatus.isNetworkReachable,
                                isWifi: networkStatus.isWifi,
                                isForceOfflineMode: settings.isForceOfflineMode,
                                isDisableUsageOver3G: settings.isDisableUsageOver3G)
    }

    @objc private func enterOfflineMode() {
        guard session.enterOfflineMode() else { return }

        if settings.isJukeboxEnabled {
            playbackCoordinator.setJukeboxEnabled(false)
            analytics.log(event: .jukeboxDisabled)
        }
    }
}
