//
//  CarPlayManagerTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/18/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import CarPlay
@testable import iSub_Beta

// CPInterfaceController has no public initializer, so CarPlayManager talks to the
// car through the CarPlayInterfaceControlling seam; this fake records the template
// stack. The CP template objects themselves construct fine in simulator unit tests.
private final class FakeCarPlayInterface: CarPlayInterfaceControlling {
    private(set) var stack = [CPTemplate]()
    var onStackChanged: (() -> Void)?

    private(set) var setRootCount = 0
    private(set) var popCount = 0
    private(set) var popToRootCount = 0

    var templates: [CPTemplate] { stack }
    var topTemplate: CPTemplate? { stack.last }
    var carTraitCollection: UITraitCollection { UITraitCollection() }

    func setRootTemplate(_ template: CPTemplate, animated: Bool) {
        stack = [template]
        setRootCount += 1
        onStackChanged?()
    }

    func pushTemplate(_ template: CPTemplate, animated: Bool) {
        stack.append(template)
        onStackChanged?()
    }

    func popTemplate(animated: Bool) {
        if stack.count > 1 {
            stack.removeLast()
        }
        popCount += 1
        onStackChanged?()
    }

    func popToRootTemplate(animated: Bool) {
        stack = Array(stack.prefix(1))
        popToRootCount += 1
        onStackChanged?()
    }
}

// No test here sets a currentServer, so the lazily created ServerChecker inside
// OfflineModeCoordinator never has a server to ping (no background network work).
final class CarPlayManagerTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var playQueue: PlayQueue!
    private var playbackCoordinator: PlaybackCoordinator!
    private var network: FakeNetworkStatus!
    private var interface: FakeCarPlayInterface!
    private var manager: CarPlayManager!

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
        self.playQueue = playQueue

        let playbackCoordinator = makeTestPlaybackCoordinator(queue: playQueue)
        TestContainer.register { playbackCoordinator }
        self.playbackCoordinator = playbackCoordinator

        let analytics = Analytics()
        TestContainer.register { analytics }

        network = FakeNetworkStatus()
        let offlineModeCoordinator = OfflineModeCoordinator(settings: settings,
                                                            session: session,
                                                            networkStatus: network,
                                                            playbackCoordinator: playbackCoordinator,
                                                            analytics: analytics)
        TestContainer.register { offlineModeCoordinator }

        interface = FakeCarPlayInterface()
        manager = CarPlayManager(interface: interface)
    }

    override func tearDownWithError() throws {
        manager?.disconnect()
        manager = nil
        interface = nil
        network = nil
        playbackCoordinator = nil
        playQueue = nil
        settings = nil
        session = nil
        try super.tearDownWithError()
    }

    private func tabTitles() -> [String] {
        guard let tabBar = interface.stack.first as? CPTabBarTemplate else { return [] }
        return tabBar.templates.compactMap { ($0 as? CPListTemplate)?.tabTitle }
    }

    private func seedQueue(_ count: Int) {
        for number in 1...count {
            let song = TestData.song(id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            XCTAssertTrue(store.add(song: song))
        }
    }

    // MARK: Tabs

    func testConnectBuildsOnlineTabOrder() {
        manager.connect()
        XCTAssertEqual(interface.setRootCount, 1)
        XCTAssertEqual(tabTitles(), ["Library", "Playlists", "Downloads", "Discover"])
        XCTAssertLessThanOrEqual(tabTitles().count, CPTabBarTemplate.maximumTabCount)
    }

    func testConnectOfflineReordersDownloadsFirst() {
        // No network at launch: the coordinator's launch check enters offline mode
        // before the tabs are built
        network.isNetworkReachable = false
        manager.connect()
        XCTAssertTrue(settings.isOfflineMode)
        XCTAssertEqual(tabTitles(), ["Downloads", "Playlists", "Library", "Discover"])
    }

    func testOfflineTransitionReordersLiveTabs() {
        manager.connect()
        XCTAssertEqual(tabTitles().first, "Library")

        network.isNetworkReachable = false
        NotificationCenter.postOnMainThread(name: Notifications.goOffline)
        XCTAssertTrue(settings.isOfflineMode)
        XCTAssertEqual(tabTitles().first, "Downloads",
                       "entering offline mode must reorder the live tab bar")
    }

    // MARK: Jukebox

    func testConnectDisablesJukebox() {
        settings.isJukeboxEnabled = true
        var disabledPosts = 0
        let observer = NotificationCenter.default.addObserver(forName: Notifications.jukeboxDisabled, object: nil, queue: nil) { _ in
            disabledPosts += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        manager.connect()
        XCTAssertFalse(settings.isJukeboxEnabled, "the car plays locally; jukebox would leave it silent")
        XCTAssertEqual(disabledPosts, 1)
    }

    // MARK: Row actions

    func testPlaySongIdsFillsQueueAndShowsNowPlaying() {
        seedQueue(3)
        manager.connect()

        var completions = 0
        manager.handleRowAction(.playSongIds(songIds: ["1", "2", "3"], serverId: 1, position: 1, shuffled: false)) {
            completions += 1
        }

        XCTAssertEqual(completions, 1)
        XCTAssertEqual(store.songs(localPlaylistId: LocalPlaylist.Default.playQueueId).map { $0.id }, ["1", "2", "3"])
        XCTAssertEqual(playQueue.currentIndex, 1)
        XCTAssertTrue(interface.topTemplate === CPNowPlayingTemplate.shared,
                      "a successful play must land on the Now Playing screen")
    }

    func testDrillPushesTemplateAndBackNavigationPrunes() {
        manager.connect()

        manager.handleRowAction(.drill(makeScreen: { CarPlayPlayQueueScreen() })) {}
        XCTAssertEqual(interface.stack.count, 2)

        // The user pressing the car's back button pops without going through the
        // manager; the stack-changed hook must prune the screen bookkeeping
        interface.popTemplate(animated: false)
        XCTAssertEqual(interface.stack.count, 1)

        // Server switch pops to root and rebuilds the tabs in place
        manager.handleRowAction(.drill(makeScreen: { CarPlayPlayQueueScreen() })) {}
        NotificationCenter.postOnMainThread(name: Notifications.serverSwitched)
        XCTAssertEqual(interface.popToRootCount, 1)
        XCTAssertEqual(interface.stack.count, 1)
        XCTAssertEqual(tabTitles(), ["Library", "Playlists", "Downloads", "Discover"])
    }

    func testPushReplacesTopAtDepthLimit() {
        manager.connect()
        for _ in 0..<4 {
            manager.handleRowAction(.drill(makeScreen: { CarPlayPlayQueueScreen() })) {}
        }
        XCTAssertEqual(interface.stack.count, CarPlayManager.maximumTemplateDepth)

        let topBefore = interface.topTemplate
        manager.handleRowAction(.drill(makeScreen: { CarPlayPlayQueueScreen() })) {}
        XCTAssertEqual(interface.stack.count, CarPlayManager.maximumTemplateDepth,
                       "audio apps may not exceed the template depth limit")
        XCTAssertFalse(interface.topTemplate === topBefore, "the top template is replaced, not stacked")
    }

    func testPlayQueuePositionFromUpNextPopsBackToNowPlaying() {
        seedQueue(2)
        manager.connect()

        // Land on Now Playing, then open the Up Next queue screen above it
        manager.handleRowAction(.playSongIds(songIds: ["1", "2"], serverId: 1, position: 0, shuffled: false)) {}
        XCTAssertTrue(interface.topTemplate === CPNowPlayingTemplate.shared)
        manager.nowPlayingTemplateUpNextButtonTapped(CPNowPlayingTemplate.shared)
        XCTAssertFalse(interface.topTemplate === CPNowPlayingTemplate.shared)

        // Tapping a queue row plays it and pops back down to Now Playing instead of
        // pushing a second shared template (which CarPlay rejects)
        manager.handleRowAction(.playQueuePosition(1)) {}
        XCTAssertEqual(playQueue.currentIndex, 1)
        XCTAssertTrue(interface.topTemplate === CPNowPlayingTemplate.shared)
    }
}
