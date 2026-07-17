//
//  ServerSwitcherContextTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The real ServerSwitcher.switchContext flow against a real Store, PlayQueue,
// StateRestorer, and ServerSession (player/streams faked): every context keeps its own
// queue and playback state, restored paused and primed. resetTabs is always false here
// and offline mode off, so no UIKit path is reached.
final class ServerSwitcherContextTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var streamManager: FakeStreamManager!
    private var playQueue: PlayQueue!
    private var stateRestorer: StateRestorer!
    private var switcher: ServerSwitcher!
    private var serverOne: Server!
    private var serverTwo: Server!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = ServerSession()
        settings = SavedSettings(session: session)
        TestContainer.register { [settings] in settings! }
        player = FakePlayer()
        TestContainer.register { [player] in player! as PlayerControlling }
        streamManager = FakeStreamManager()
        playQueue = PlayQueue(store: store, settings: settings)
        TestContainer.register { [playQueue] in playQueue! }
        stateRestorer = StateRestorer(settings: settings, player: player, playQueue: playQueue)
        switcher = ServerSwitcher(streamManager: streamManager, player: player, settings: settings,
                                  session: session, store: store, stateRestorer: stateRestorer)
        serverOne = TestData.server(id: 1)
        serverTwo = TestData.server(id: 2, urlString: "https://two.example.com")
        XCTAssertTrue(store.add(server: serverOne))
        XCTAssertTrue(store.add(server: serverTwo))
    }

    override func tearDownWithError() throws {
        switcher = nil
        stateRestorer = nil
        playQueue = nil
        streamManager = nil
        player = nil
        settings = nil
        session = nil
        serverOne = nil
        serverTwo = nil
        try super.tearDownWithError()
    }

    private func seedAndQueue(ids: [String], serverId: Int = 1) throws {
        try store.pool.write { db in
            for id in ids {
                try TestData.song(serverId: serverId, id: id, path: "a/\(id).mp3").save(db)
            }
        }
        for id in ids {
            XCTAssertTrue(store.add(song: TestData.song(serverId: serverId, id: id, path: "a/\(id).mp3"),
                                    localPlaylistId: LocalPlaylist.Default.playQueueId))
        }
    }

    func testSwitchRoundTripRestoresQueueIndexAndSeek() throws {
        session.setActiveContext(.server(serverOne))
        try seedAndQueue(ids: ["10", "20", "30"])
        playQueue.normalIndex = 2
        player.isStarted = true
        player.progress = 42.5
        player.currentByteOffset = 9_999
        player.kiloBitrate = 192

        switcher.switchContext(to: .server(serverTwo), resetTabs: false)

        XCTAssertEqual(session.activeContext?.server?.id, 2)
        XCTAssertTrue(playQueue.songs().isEmpty, "server two starts with a clean queue")
        XCTAssertEqual(playQueue.normalIndex, 0)
        XCTAssertEqual(player.stopCount, 1)
        XCTAssertEqual(streamManager.removeAllStreamsCount, 1)
        XCTAssertFalse(testDefaults.bool(forKey: SavedSettings.Key.isPlaying.rawValue))

        // The player was stopped by the switch — a real player would now report zero
        // progress, which the capture fallback must not mistake for a new position
        player.isStarted = false
        player.progress = 0
        player.currentByteOffset = 0

        switcher.switchContext(to: .server(serverOne), resetTabs: false)

        XCTAssertEqual(session.activeContext?.server?.id, 1)
        XCTAssertEqual(playQueue.songs().map(\.id), ["10", "20", "30"], "server one's queue comes back")
        XCTAssertEqual(playQueue.normalIndex, 2, "the current index comes back")
        XCTAssertEqual(player.startSecondsOffset, 42.5, "the seek position comes back primed")
        XCTAssertEqual(player.startByteOffset, 9_999)
        XCTAssertTrue(player.startedSongs.isEmpty, "restore must never auto-start playback")
        XCTAssertFalse(testDefaults.bool(forKey: SavedSettings.Key.recover.rawValue))
    }

    func testPausedSwitchLoopKeepsSeekPosition() throws {
        session.setActiveContext(.server(serverOne))
        try seedAndQueue(ids: ["10"])
        player.isStarted = true
        player.progress = 42.5
        player.currentByteOffset = 9_999

        // A → B → A → B without ever pressing play
        switcher.switchContext(to: .server(serverTwo), resetTabs: false)
        player.isStarted = false
        player.progress = 0
        player.currentByteOffset = 0
        switcher.switchContext(to: .server(serverOne), resetTabs: false)
        switcher.switchContext(to: .server(serverTwo), resetTabs: false)
        switcher.switchContext(to: .server(serverOne), resetTabs: false)

        XCTAssertEqual(player.startSecondsOffset, 42.5, "a paused switch loop must not decay the saved seek")
        XCTAssertEqual(player.startByteOffset, 9_999)
    }

    func testSwitchSkipsSnapshotWhenOutgoingServerWasDeleted() throws {
        session.setActiveContext(.server(serverOne))
        try seedAndQueue(ids: ["10"])

        // The delete-active-server path removes the row before switching away
        XCTAssertTrue(store.deleteServer(id: 1))
        switcher.switchContext(to: .server(serverTwo), resetTabs: false)

        XCTAssertNil(store.contextQueueState(contextId: 1), "no snapshot may be saved for a deleted server")
        XCTAssertEqual(session.activeContext?.server?.id, 2)
    }

    func testSwitchForceDisablesJukeboxMode() {
        session.setActiveContext(.server(serverOne))
        settings.isJukeboxEnabled = true

        switcher.switchContext(to: .server(serverTwo), resetTabs: false)

        XCTAssertFalse(settings.isJukeboxEnabled, "jukebox mode never spans a context switch")
    }

    func testSwitchToNoContextClearsLiveQueue() throws {
        session.setActiveContext(.server(serverOne))
        try seedAndQueue(ids: ["10"])

        switcher.switchContext(to: nil, resetTabs: false)

        XCTAssertNil(session.activeContext)
        XCTAssertTrue(playQueue.songs().isEmpty)
        XCTAssertNil(testDefaults.object(forKey: SavedSettings.Key.activeContextId.rawValue))
    }

    func testCombinedContextPersistsAcrossRelaunch() {
        session.setActiveContext(.server(serverOne))

        switcher.switchContext(to: .combined, resetTabs: false)

        XCTAssertTrue(session.isCombinedContext)
        XCTAssertNil(session.currentServer, "the Combined Library has no single current server")
        XCTAssertEqual(session.currentServerId, -1)
        XCTAssertEqual(testDefaults.object(forKey: SavedSettings.Key.activeContextId.rawValue) as? Int, LibraryContext.combinedContextId)
        XCTAssertNil(testDefaults.object(forKey: SavedSettings.Key.currentServerId.rawValue))

        // Relaunch: a fresh session restores the Combined context from the defaults
        let relaunchedSession = ServerSession()
        relaunchedSession.setup(store: store)
        XCTAssertTrue(relaunchedSession.isCombinedContext)
    }

    func testSetupFallsBackToLegacyCurrentServerIdKey() {
        // An install from before library contexts has only the legacy key
        testDefaults.removeObject(forKey: SavedSettings.Key.activeContextId.rawValue)
        testDefaults.set(2, forKey: SavedSettings.Key.currentServerId.rawValue)

        let relaunchedSession = ServerSession()
        relaunchedSession.setup(store: store)

        XCTAssertEqual(relaunchedSession.currentServer?.id, 2)
    }

    func testSetupWithDeletedServerLandsOnNoContext() {
        testDefaults.set(99, forKey: SavedSettings.Key.activeContextId.rawValue)

        let relaunchedSession = ServerSession()
        relaunchedSession.setup(store: store)

        XCTAssertNil(relaunchedSession.activeContext)
    }

    func testSetupHealsInterruptedSwitch() throws {
        // Simulate a crash mid-switch: context 1's snapshot exists, the database swap
        // to context 2 committed (marker moved, live rows replaced), but the defaults
        // still say context 1 is active
        session.setActiveContext(.server(serverOne))
        try seedAndQueue(ids: ["10"])
        _ = store.swapLiveQueue(outgoingContextId: 1, outgoingState: stateRestorer.captureSnapshot(), incomingContextId: 2)
        XCTAssertEqual(store.liveQueueContextId(), 2)

        let relaunchedSession = ServerSession()
        relaunchedSession.setup(store: store)

        XCTAssertEqual(relaunchedSession.currentServer?.id, 1)
        XCTAssertEqual(store.liveQueueContextId(), 1, "setup re-restores the persisted context's queue")
        XCTAssertEqual(store.songs(localPlaylistId: LocalPlaylist.Default.playQueueId).map(\.id), ["10"])
    }
}
