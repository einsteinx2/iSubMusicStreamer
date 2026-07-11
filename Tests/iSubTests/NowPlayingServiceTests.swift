//
//  NowPlayingServiceTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Remote command handler behavior (BUG-23), moved from the old static
// LockScreenAudioControls to the instance-based NowPlayingService (Phase 8.3).
// Constructing without calling setup() means no MPRemoteCommandCenter registration,
// the same isolation the old attach()/setup() split provided.
final class NowPlayingServiceTests: StoreTestCase {
    private var playQueue: PlayQueue!
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var service: NowPlayingService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        player = FakePlayer()
        let fakePlayer = player!
        TestContainer.register { fakePlayer as PlayerControlling }
        TestContainer.register { FakeStreamManager() as StreamManaging }
        TestContainer.register { FakeDownloadQueue() as DownloadQueueing }
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue

        service = NowPlayingService(settings: freshSettings,
                                    playQueue: freshPlayQueue,
                                    player: fakePlayer,
                                    jukebox: Jukebox(settings: freshSettings, store: store))
    }

    override func tearDownWithError() throws {
        service = nil
        playQueue = nil
        settings = nil
        player = nil
        try super.tearDownWithError()
    }

    private func seedQueue(_ count: Int) {
        for number in 1...count {
            let song = TestData.song(serverId: 1, id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            _ = store.add(song: song)
            XCTAssertTrue(store.add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId))
        }
    }

    func testNextAndPreviousTrackReturnSuccess_BUG23() {
        seedQueue(3)
        playQueue.currentIndex = 1

        XCTAssertEqual(service.handleNextTrack(), .success,
                       "a successful skip must not report .commandFailed to the OS")
        XCTAssertEqual(playQueue.currentIndex, 2)

        XCTAssertEqual(service.handlePreviousTrack(), .success)
        XCTAssertEqual(playQueue.currentIndex, 1)
    }

    func testNextTrackWithEmptyQueueIsNotActionable() {
        XCTAssertEqual(service.handleNextTrack(), .noActionableNowPlayingItem)
        XCTAssertEqual(service.handlePreviousTrack(), .noActionableNowPlayingItem)
    }

    func testChangePlaybackPositionSeeksLocalPlayer() {
        seedQueue(1)
        player.isPlaying = true

        XCTAssertEqual(service.handleChangePlaybackPosition(seconds: 42.5), .success)
        XCTAssertEqual(player.seeks.count, 1)
        XCTAssertEqual(player.seeks[0].seconds, 42.5, accuracy: 0.001)

        player.isPlaying = false
        XCTAssertEqual(service.handleChangePlaybackPosition(seconds: 10), .commandFailed)
    }

    func testChangePlaybackPositionInJukeboxModeSeeksJukebox_BUG23() throws {
        MockSubsonicServer.install()
        defer { MockSubsonicServer.uninstall() }
        try MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        let server = TestData.server(id: 1, urlString: "https://mock.example.com")
        XCTAssertTrue(store.add(server: server))
        settings.currentServer = server
        settings.isJukeboxEnabled = true

        let jukebox = Jukebox(settings: settings, store: store)
        jukebox.attach(playQueue: playQueue)
        service = NowPlayingService(settings: settings, playQueue: playQueue, player: player, jukebox: jukebox)
        defer { jukebox.getInfo(delay: 999_999) }

        XCTAssertEqual(service.handleChangePlaybackPosition(seconds: 42), .success,
                       "lock-screen scrubbing must drive the jukebox, not the (idle) local player")
        XCTAssertTrue(player.seeks.isEmpty)

        // Scan all received requests: the jukebox schedules a follow-up "get" 0.5s
        // after every command, so the seek is not necessarily the last request
        let deadline = Date(timeIntervalSinceNow: 5)
        var seekRequest: MockSubsonicServer.ReceivedRequest?
        repeat {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            seekRequest = MockSubsonicServer.receivedRequests(action: .jukeboxControl).first {
                $0.parameter("action") == "skip" && $0.parameter("offset") == "42"
            }
        } while seekRequest == nil && Date() < deadline
        XCTAssertNotNil(seekRequest, "no jukebox skip request with offset 42 was sent")
    }

    // MARK: New coverage for the handlers that used to be untestable closures

    func testPlayPauseToggleStopRouteToLocalPlayer() {
        seedQueue(1)

        player.isPlaying = false
        XCTAssertEqual(service.handlePlay(), .success)
        XCTAssertEqual(player.playPauseCount, 1)

        player.isPlaying = true
        XCTAssertEqual(service.handlePause(), .success)
        XCTAssertEqual(player.pauseCount, 1)

        XCTAssertEqual(service.handleTogglePlayPause(), .success)
        XCTAssertEqual(player.playPauseCount, 2)

        XCTAssertEqual(service.handleStop(), .success)
        XCTAssertEqual(player.stopCount, 1)
    }

    func testTransportHandlersWithEmptyQueueAreNotActionable() {
        XCTAssertEqual(service.handlePlay(), .noActionableNowPlayingItem)
        XCTAssertEqual(service.handlePause(), .noActionableNowPlayingItem)
        XCTAssertEqual(service.handleTogglePlayPause(), .noActionableNowPlayingItem)
        XCTAssertEqual(service.handleStop(), .noActionableNowPlayingItem)
    }

    func testPauseAndStopWhileIdleFail() {
        seedQueue(1)
        player.isPlaying = false
        XCTAssertEqual(service.handlePause(), .commandFailed)
        XCTAssertEqual(service.handleStop(), .commandFailed)
    }

    func testChangeRepeatModeWritesPlayQueue() {
        XCTAssertEqual(service.handleChangeRepeatMode(.one), .success)
        XCTAssertEqual(playQueue.repeatMode, .one)
        XCTAssertEqual(service.handleChangeRepeatMode(.all), .success)
        XCTAssertEqual(playQueue.repeatMode, .all)
        XCTAssertEqual(service.handleChangeRepeatMode(.off), .success)
        XCTAssertEqual(playQueue.repeatMode, RepeatMode.none)
    }
}
