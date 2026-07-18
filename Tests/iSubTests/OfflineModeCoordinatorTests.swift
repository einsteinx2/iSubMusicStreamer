//
//  OfflineModeCoordinatorTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The launch offline check and online/offline transition handling, extracted from
// SceneDelegate so CarPlay-only launches behave. The truth table itself is covered
// by the SceneDelegate.launchOfflineAlertMessage tests in SingletonLifecycleTests;
// these cover the coordinator's once-semantics, alert handoff, and side effects.
final class OfflineModeCoordinatorTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var network: FakeNetworkStatus!
    private var playbackCoordinator: PlaybackCoordinator!
    private var coordinator: OfflineModeCoordinator!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = ServerSession()
        let settings = SavedSettings(session: session)
        settings.setup(store: store)
        TestContainer.register { settings }
        self.settings = settings

        let jukebox = Jukebox(settings: settings)
        TestContainer.register { jukebox }

        let playQueue = makeTestPlayQueue()
        TestContainer.register { playQueue }

        playbackCoordinator = makeTestPlaybackCoordinator(queue: playQueue)
        network = FakeNetworkStatus()
        coordinator = OfflineModeCoordinator(settings: settings,
                                             session: session,
                                             networkStatus: network,
                                             playbackCoordinator: playbackCoordinator,
                                             analytics: Analytics())
    }

    override func tearDownWithError() throws {
        coordinator = nil
        playbackCoordinator = nil
        network = nil
        settings = nil
        session = nil
        try super.tearDownWithError()
    }

    func testLaunchCheckEntersOfflineOnceAndStashesAlert() {
        network.isNetworkReachable = false

        let message = coordinator.performLaunchOfflineCheckIfNeeded()
        XCTAssertEqual(message, "No network detected, entering offline mode.")
        XCTAssertTrue(settings.isOfflineMode)

        // The phone scene consumes the stashed alert exactly once (it may connect
        // long after a CarPlay-only launch ran the check)
        XCTAssertEqual(coordinator.consumePendingLaunchAlertMessage(), message)
        XCTAssertNil(coordinator.consumePendingLaunchAlertMessage())

        // Once per process, no matter which scene asks again
        XCTAssertNil(coordinator.performLaunchOfflineCheckIfNeeded())
    }

    func testForceOfflineSettingWinsEvenWithNetwork() {
        network.isNetworkReachable = true
        settings.isForceOfflineMode = true

        XCTAssertNotNil(coordinator.performLaunchOfflineCheckIfNeeded())
        XCTAssertTrue(settings.isOfflineMode)
    }

    func testSceneBecameActiveAfterCheckEntersOfflineWhenUnreachable() {
        network.isNetworkReachable = true
        settings.currentServer = nil
        coordinator.performLaunchOfflineCheckIfNeeded()
        XCTAssertFalse(settings.isOfflineMode)

        network.isNetworkReachable = false
        coordinator.sceneBecameActive()
        XCTAssertTrue(settings.isOfflineMode)
    }

    func testGoOfflineNotificationDisablesJukebox() {
        settings.isJukeboxEnabled = true
        var disabledPosts = 0
        let observer = NotificationCenter.default.addObserver(forName: Notifications.jukeboxDisabled, object: nil, queue: nil) { _ in
            disabledPosts += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        NotificationCenter.postOnMainThread(name: Notifications.goOffline)

        XCTAssertTrue(settings.isOfflineMode)
        XCTAssertFalse(settings.isJukeboxEnabled, "offline mode cannot drive the remote jukebox")
        XCTAssertEqual(disabledPosts, 1)
    }
}
