//
//  PlayQueueTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-05: PlayQueue navigation, shuffle, edit, and state-persistence tests using
// the protocol seams (FakePlayer/FakeStreamManager/FakeDownloadQueue) and the
// in-memory store.
final class PlayQueueTests: StoreTestCase {
    private var playQueue: PlayQueue!
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var streamManager: FakeStreamManager!
    private var downloadQueue: FakeDownloadQueue!
    private var coordinator: PlaybackCoordinator!
    private var stateRestorer: StateRestorer!

    override func setUpWithError() throws {
        try super.setUpWithError()

        player = FakePlayer()
        streamManager = FakeStreamManager()
        downloadQueue = FakeDownloadQueue()
        let fakePlayer = player!
        let fakeStreamManager = streamManager!
        let fakeDownloadQueue = downloadQueue!
        TestContainer.register { fakePlayer as PlayerControlling }
        TestContainer.register { fakeStreamManager as StreamManaging }
        TestContainer.register { fakeDownloadQueue as DownloadQueueing }

        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings

        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue
        coordinator = makeTestPlaybackCoordinator(queue: freshPlayQueue)

        stateRestorer = StateRestorer(settings: settings, player: player, playQueue: playQueue)
    }

    override func tearDownWithError() throws {
        stateRestorer = nil
        coordinator = nil
        playQueue = nil
        settings = nil
        player = nil
        streamManager = nil
        downloadQueue = nil
        try super.tearDownWithError()
    }

    // Seeds numbered songs (ids "1"..."<count>") into the normal play queue
    private func seedQueue(_ count: Int, playlistId: Int = LocalPlaylist.Default.playQueueId) {
        for number in 1...count {
            let song = TestData.song(serverId: 1, id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            _ = store.add(song: song)
            XCTAssertTrue(store.add(song: song, localPlaylistId: playlistId))
        }
    }

    // MARK: index(offset:fromIndex:)

    func testIndexOffsetRepeatNoneWithinBounds() {
        seedQueue(5)
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.index(offset: 2, fromIndex: 1), 3)
        XCTAssertEqual(playQueue.index(offset: 0, fromIndex: 4), 4)
        XCTAssertEqual(playQueue.index(offset: -1, fromIndex: 3), 2)
    }

    func testIndexOffsetRepeatNonePastEndReturnsFirstIndexPastEnd() {
        // StreamManager prefetch relies on getting songCount (one past the end) back
        seedQueue(5)
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.index(offset: 3, fromIndex: 3), 5)
        XCTAssertEqual(playQueue.index(offset: 10, fromIndex: 0), 5)
    }

    func testIndexOffsetRepeatNoneNegativeClampsToZero_BUG10() {
        seedQueue(5)
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.index(offset: -2, fromIndex: 1), 0, "negative results must clamp to 0")
        XCTAssertEqual(playQueue.index(offset: -10, fromIndex: 4), 0, "negative results must clamp to 0")
    }

    func testIndexOffsetRepeatOneAlwaysReturnsFromIndex() {
        seedQueue(5)
        playQueue.repeatMode = .one
        XCTAssertEqual(playQueue.index(offset: 3, fromIndex: 2), 2)
        XCTAssertEqual(playQueue.index(offset: -2, fromIndex: 2), 2)
        XCTAssertEqual(playQueue.index(offset: 0, fromIndex: 4), 4)
    }

    func testIndexOffsetRepeatAllWrapsBothDirections() {
        seedQueue(5)
        playQueue.repeatMode = .all
        XCTAssertEqual(playQueue.index(offset: 2, fromIndex: 4), 1, "wraps past the end")
        XCTAssertEqual(playQueue.index(offset: -2, fromIndex: 0), 3, "wraps below zero")
        XCTAssertEqual(playQueue.index(offset: -12, fromIndex: 0), 3, "wraps multiple times below zero")
        XCTAssertEqual(playQueue.index(offset: 12, fromIndex: 0), 2, "wraps multiple times past the end")
        XCTAssertEqual(playQueue.index(offset: 1, fromIndex: 2), 3, "no wrap needed")
    }

    func testIndexOffsetEmptyQueueReturnsZero() {
        playQueue.repeatMode = .all
        XCTAssertEqual(playQueue.index(offset: -3, fromIndex: 0), 0, "empty queue must not wrap or hang")
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.index(offset: 3, fromIndex: 0), 0)
    }

    // MARK: nextIndex / prevIndex / nextIndexIgnoringRepeatMode

    func testNextIndexPerRepeatMode() {
        seedQueue(3)
        playQueue.currentIndex = 1

        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.nextIndex, 2)
        playQueue.repeatMode = .one
        XCTAssertEqual(playQueue.nextIndex, 1)
        playQueue.repeatMode = .all
        XCTAssertEqual(playQueue.nextIndex, 2)

        // At the last song
        playQueue.currentIndex = 2
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.nextIndex, 3, "first index past the end")
        playQueue.repeatMode = .all
        XCTAssertEqual(playQueue.nextIndex, 0, "wraps to the beginning")

        // Past the end of the playlist
        playQueue.currentIndex = 3
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.nextIndex, 3, "stays past the end")
    }

    func testPrevIndexPerRepeatMode() {
        seedQueue(3)

        playQueue.currentIndex = 1
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.prevIndex, 0)
        playQueue.repeatMode = .one
        XCTAssertEqual(playQueue.prevIndex, 1)
        playQueue.repeatMode = .all
        XCTAssertEqual(playQueue.prevIndex, 0)

        playQueue.currentIndex = 0
        playQueue.repeatMode = .none
        XCTAssertEqual(playQueue.prevIndex, 0, "stays at the first song")
        playQueue.repeatMode = .all
        XCTAssertEqual(playQueue.prevIndex, 2, "wraps to the last song")
    }

    func testNextIndexIgnoringRepeatMode() {
        seedQueue(3)
        playQueue.repeatMode = .one
        playQueue.currentIndex = 1
        XCTAssertEqual(playQueue.nextIndexIgnoringRepeatMode, 2, "repeat one must be ignored")
        playQueue.currentIndex = 3
        XCTAssertEqual(playQueue.nextIndexIgnoringRepeatMode, 3, "stays past the end")
    }

    // MARK: nextSong / prevSong / currentSong

    func testSongAccessors() {
        seedQueue(3)
        playQueue.repeatMode = .none
        playQueue.currentIndex = 1

        XCTAssertEqual(playQueue.currentSong?.id, "2")
        XCTAssertEqual(playQueue.nextSong?.id, "3")
        XCTAssertEqual(playQueue.prevSong?.id, "1")
        XCTAssertEqual(playQueue.count, 3)

        // Past the end there's no current song, but the display song falls back to prev
        playQueue.currentIndex = 3
        XCTAssertNil(playQueue.currentSong)
        XCTAssertEqual(playQueue.currentDisplaySong?.id, "3")
    }

    // MARK: currentIndex across the shuffle branch

    func testCurrentIndexTracksShuffleState() {
        seedQueue(3)
        playQueue.normalIndex = 2
        playQueue.shuffleIndex = 1

        playQueue.isShuffle = false
        XCTAssertEqual(playQueue.currentIndex, 2)
        playQueue.isShuffle = true
        XCTAssertEqual(playQueue.currentIndex, 1)

        playQueue.currentIndex = 0
        XCTAssertEqual(playQueue.shuffleIndex, 0)
        XCTAssertEqual(playQueue.normalIndex, 2, "setting the index in shuffle mode must not touch the normal index")

        playQueue.isShuffle = false
        playQueue.currentIndex = 1
        XCTAssertEqual(playQueue.normalIndex, 1)
        XCTAssertEqual(playQueue.shuffleIndex, 0, "setting the index in normal mode must not touch the shuffle index")
    }

    // MARK: playSong / playNextSong / playPrevSong

    func testPlaySongStartsSongAtPosition() throws {
        seedQueue(3)
        let played = coordinator.play(position: 1)
        XCTAssertEqual(played?.id, "2")
        XCTAssertEqual(playQueue.currentIndex, 1)
        // Streams for other songs are cleared before starting
        XCTAssertEqual(streamManager.removeAllStreamsExceptSongs.map(\.id), ["2"])
        XCTAssertEqual(player.stopCount, 1, "the player is stopped before starting a new song")
    }

    func testPlaySongPastEndReturnsNil() {
        seedQueue(3)
        XCTAssertNil(coordinator.play(position: 5))
        XCTAssertEqual(playQueue.currentIndex, 5)
    }

    func testPlayPrevSongRestartsWhenPastTenSeconds() {
        seedQueue(3)
        playQueue.currentIndex = 1
        player.progress = 15.0

        let played = coordinator.playPrevious()

        XCTAssertEqual(played?.id, "2", "past 10 seconds the current song restarts")
        XCTAssertEqual(playQueue.currentIndex, 1)
    }

    func testPlayPrevSongGoesToPreviousWithinTenSeconds() {
        seedQueue(3)
        playQueue.currentIndex = 1
        player.progress = 5.0

        let played = coordinator.playPrevious()

        XCTAssertEqual(played?.id, "1", "within 10 seconds playback moves to the previous song")
        XCTAssertEqual(playQueue.currentIndex, 0)
    }

    func testPlayNextSongAdvances() {
        seedQueue(3)
        playQueue.repeatMode = .none
        playQueue.currentIndex = 0

        let played = coordinator.playNext()

        XCTAssertEqual(played?.id, "2")
        XCTAssertEqual(playQueue.currentIndex, 1)
    }

    // MARK: playSong from a local playlist (STUB-04)

    func testPlaySongFromLocalPlaylistFillsQueueAndStartsAtPosition() {
        // A saved local playlist with three songs
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Saved")))
        for number in 1...3 {
            let song = TestData.song(serverId: 1, id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            _ = store.add(song: song)
            XCTAssertTrue(store.add(song: song, localPlaylistId: 5))
        }
        // A pre-existing play queue that must be replaced
        let old = TestData.song(serverId: 1, id: "99", title: "Old", path: "B/99.mp3")
        _ = store.add(song: old)
        XCTAssertTrue(store.add(song: old, localPlaylistId: LocalPlaylist.Default.playQueueId))

        let played = coordinator.play(localPlaylistId: 5, position: 1)

        XCTAssertEqual(played?.id, "2")
        XCTAssertEqual(playQueue.currentIndex, 1)
        XCTAssertFalse(playQueue.isShuffle)
        XCTAssertEqual(playQueue.songs().map(\.id), ["1", "2", "3"],
                       "the play queue must be replaced by the playlist's songs in order")
        XCTAssertEqual(playQueue.count, 3, "the play queue's songCount must be updated")
        XCTAssertGreaterThan(player.stopCount, 0, "the player restarts for the new song")
    }

    func testPlaySongFromLocalPlaylistWithShuffleOnFillsNormalQueue_STUB09() {
        // With shuffle enabled, currentPlaylistId points at the shuffle queue; playing a
        // local playlist must turn shuffle off FIRST so the songs land in the play queue
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Saved")))
        for number in 1...3 {
            let song = TestData.song(serverId: 1, id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            _ = store.add(song: song)
            XCTAssertTrue(store.add(song: song, localPlaylistId: 5))
        }
        playQueue.isShuffle = true

        let played = coordinator.play(localPlaylistId: 5, position: 0)

        XCTAssertEqual(played?.id, "1")
        XCTAssertFalse(playQueue.isShuffle)
        XCTAssertEqual(playQueue.songs().map(\.id), ["1", "2", "3"],
                       "the songs must fill the normal play queue, not the shuffle queue")
        XCTAssertEqual(store.songs(localPlaylistId: LocalPlaylist.Default.shuffleQueueId).count, 0,
                       "nothing may leak into the shuffle queue")
    }

    // MARK: shuffleToggle

    func testShuffleToggleOnCreatesShuffleQueueKeepingCurrentSong() {
        seedQueue(5)
        playQueue.normalIndex = 2

        coordinator.shuffleToggle()

        XCTAssertTrue(playQueue.isShuffle)
        XCTAssertEqual(playQueue.shuffleIndex, 0)
        XCTAssertEqual(playQueue.currentSong?.id, "3", "the playing song must be first in the shuffle queue")
        XCTAssertEqual(playQueue.count, 5)
        XCTAssertEqual(Set(playQueue.songs().map(\.id)), Set((1...5).map(String.init)), "shuffle queue must be a permutation")
        XCTAssertEqual(streamManager.fillStreamQueueCalls, [true])
        XCTAssertEqual(streamManager.removeAllStreamsExceptSongs.map(\.id), ["3"],
                       "only the playing song's stream survives the queue swap")
    }

    func testShuffleTogglePostsNotificationOnBothTransitions_BUG14() {
        seedQueue(3)
        playQueue.normalIndex = 1

        let enabled = expectation(forNotification: Notifications.currentPlaylistShuffleToggled, object: nil)
        coordinator.shuffleToggle()
        wait(for: [enabled], timeout: 5)
        XCTAssertTrue(playQueue.isShuffle)

        let disabled = expectation(forNotification: Notifications.currentPlaylistShuffleToggled, object: nil)
        coordinator.shuffleToggle()
        wait(for: [disabled], timeout: 5)
        XCTAssertFalse(playQueue.isShuffle)
    }

    func testShuffleToggleInJukeboxModeReplacesRemotePlaylistAndSkips_BUG14() throws {
        MockSubsonicServer.install()
        defer { MockSubsonicServer.uninstall() }
        try MockSubsonicServer.stub(.jukeboxControl, fixture: "XML/jukeboxControl_status.xml")

        let server = TestData.server(id: 1, urlString: "https://mock.example.com")
        XCTAssertTrue(store.add(server: server))
        settings.currentServer = server
        settings.isJukeboxEnabled = true

        let jukebox = Jukebox(settings: settings)
        TestContainer.register { jukebox }
        // Push the periodic getInfo far past the process lifetime on the way out
        defer { jukebox.getInfo(delay: 999_999) }

        // The play queue must capture this test's jukebox, so build a local one now
        // that the jukebox is registered (the composition root wires this in the app)
        let playQueue = makeTestPlayQueue()
        TestContainer.register { playQueue }

        seedQueue(3)
        playQueue.normalIndex = 0

        // The coordinator must wrap this test's local queue and jukebox
        let coordinator = makeTestPlaybackCoordinator(queue: playQueue)
        coordinator.shuffleToggle()
        XCTAssertTrue(playQueue.isShuffle)

        // The jukebox's remote playlist is replaced (clear) and playback starts at the
        // current index (skip)
        let deadline = Date(timeIntervalSinceNow: 5)
        var actions = [String]()
        repeat {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            actions = MockSubsonicServer.receivedRequests(action: .jukeboxControl).compactMap { $0.parameter("action") }
        } while !(actions.contains("clear") && actions.contains("skip")) && Date() < deadline
        XCTAssertTrue(actions.contains("clear"), "shuffle toggle must replace the remote jukebox playlist")
        XCTAssertTrue(actions.contains("skip"), "shuffle toggle must start the jukebox at the current index")
    }

    func testShuffleToggleOffRestoresNormalIndexOfCurrentSong() {
        seedQueue(5)
        playQueue.normalIndex = 2
        coordinator.shuffleToggle()
        XCTAssertTrue(playQueue.isShuffle)

        coordinator.shuffleToggle()

        XCTAssertFalse(playQueue.isShuffle)
        XCTAssertEqual(playQueue.normalIndex, 2, "the current song's position in the normal queue is restored")
        XCTAssertEqual(playQueue.currentSong?.id, "3")
    }

    // MARK: moveSong index correction

    func testMoveSongCorrectsCurrentIndex() {
        seedQueue(5)
        playQueue.currentIndex = 2

        // Moving the current song follows it
        XCTAssertTrue(coordinator.moveSong(fromIndex: 2, toIndex: 4))
        XCTAssertEqual(playQueue.currentIndex, 4)
        XCTAssertEqual(playQueue.currentSong?.id, "3")

        // Moving a song from before the current one to after decrements the index
        XCTAssertTrue(coordinator.moveSong(fromIndex: 0, toIndex: 4))
        XCTAssertEqual(playQueue.currentIndex, 3)
        XCTAssertEqual(playQueue.currentSong?.id, "3")

        // Moving a song from after the current one to before increments the index
        XCTAssertTrue(coordinator.moveSong(fromIndex: 4, toIndex: 0))
        XCTAssertEqual(playQueue.currentIndex, 4)
        XCTAssertEqual(playQueue.currentSong?.id, "3")

        // Moving songs entirely after the current one leaves it alone
        playQueue.currentIndex = 0
        XCTAssertTrue(coordinator.moveSong(fromIndex: 3, toIndex: 4))
        XCTAssertEqual(playQueue.currentIndex, 0)
    }

    func testMoveSongFailureDoesNotTouchIndex() {
        seedQueue(3)
        playQueue.currentIndex = 1
        XCTAssertFalse(coordinator.moveSong(fromIndex: 1, toIndex: 9))
        XCTAssertEqual(playQueue.currentIndex, 1)
    }

    // MARK: removeSongs

    func testRemoveSongsResetsIndexWhenCurrentSongDeleted() {
        seedQueue(5)
        playQueue.currentIndex = 2

        XCTAssertTrue(coordinator.removeSongs(indexes: [1, 2]))

        XCTAssertEqual(player.stopCount, 1, "deleting the playing song stops the player")
        XCTAssertEqual(playQueue.currentIndex, 0)
        XCTAssertEqual(playQueue.songs().map(\.id), ["1", "4", "5"])
    }

    func testRemoveSongsKeepsPlayingWhenOtherSongsDeleted() {
        seedQueue(5)
        playQueue.currentIndex = 2

        XCTAssertTrue(coordinator.removeSongs(indexes: [4]))

        XCTAssertEqual(player.stopCount, 0)
        XCTAssertEqual(playQueue.currentIndex, 2)
        XCTAssertEqual(playQueue.songs().count, 4)
    }

    // MARK: StateRestorer state persistence

    func testSaveStatePersistsPlayerAndQueueState() {
        seedQueue(3)
        player.isPlaying = true
        player.isStarted = true
        player.progress = 42.5
        player.currentByteOffset = 123456
        player.kiloBitrate = 192
        playQueue.isShuffle = true
        playQueue.normalIndex = 2
        playQueue.shuffleIndex = 1
        playQueue.repeatMode = .all

        stateRestorer.saveState()

        XCTAssertTrue(testDefaults.bool(forKey: SavedSettings.Key.isPlaying.rawValue))
        XCTAssertTrue(testDefaults.bool(forKey: SavedSettings.Key.isShuffle.rawValue))
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.normalPlaylistIndex.rawValue), 2)
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.shufflePlaylistIndex.rawValue), 1)
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.repeatMode.rawValue), RepeatMode.all.rawValue)
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.kiloBitrate.rawValue), 192)
        XCTAssertEqual(testDefaults.double(forKey: SavedSettings.Key.seekTime.rawValue), 42.5, accuracy: 0.001)
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.byteOffset.rawValue), 123456)
        XCTAssertTrue(testDefaults.bool(forKey: SavedSettings.Key.recover.rawValue), "playing with recoverSetting 0 must set the recover flag")
    }

    func testSaveStateRoundTripsEveryRepeatMode() {
        // BUG-01 regression: saveState used to write the RepeatMode enum itself to
        // UserDefaults (not a plist type), raising NSInvalidArgumentException
        seedQueue(3)
        for mode in [RepeatMode.one, .all, .none] {
            playQueue.repeatMode = mode
            stateRestorer.saveState()
            XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.repeatMode.rawValue), mode.rawValue)

            playQueue.repeatMode = .none
            stateRestorer.loadState()
            XCTAssertEqual(playQueue.repeatMode, mode, "repeatMode must survive a saveState/loadState round-trip")
        }
    }

    func testLoadStateRestoresQueueAndPlayerOffsets() {
        seedQueue(3)
        testDefaults.set(true, forKey: SavedSettings.Key.isShuffle.rawValue)
        testDefaults.set(2, forKey: SavedSettings.Key.normalPlaylistIndex.rawValue)
        testDefaults.set(1, forKey: SavedSettings.Key.shufflePlaylistIndex.rawValue)
        testDefaults.set(RepeatMode.all.rawValue, forKey: SavedSettings.Key.repeatMode.rawValue)
        testDefaults.set(654321, forKey: SavedSettings.Key.byteOffset.rawValue)
        testDefaults.set(33.25, forKey: SavedSettings.Key.seekTime.rawValue)

        stateRestorer.loadState()

        XCTAssertTrue(playQueue.isShuffle)
        XCTAssertEqual(playQueue.normalIndex, 2)
        XCTAssertEqual(playQueue.shuffleIndex, 1)
        XCTAssertEqual(playQueue.repeatMode, .all)
        XCTAssertEqual(player.startByteOffset, 654321)
        XCTAssertEqual(player.startSecondsOffset, 33.25, accuracy: 0.001)
    }

    func testSaveThenLoadStateRoundTrip() {
        seedQueue(3)
        player.isPlaying = true
        player.isStarted = true
        player.progress = 10.0
        player.currentByteOffset = 999
        playQueue.isShuffle = true
        playQueue.normalIndex = 1
        playQueue.shuffleIndex = 2
        stateRestorer.saveState()

        // Simulate a fresh launch: new queue/player/settings reading the same defaults
        let newPlayer = FakePlayer()
        TestContainer.register { newPlayer as PlayerControlling }
        let newPlayQueue = makeTestPlayQueue()
        TestContainer.register { newPlayQueue }
        let newSettings = SavedSettings()
        TestContainer.register { newSettings }
        let newStateRestorer = StateRestorer(settings: newSettings, player: newPlayer, playQueue: newPlayQueue)

        newStateRestorer.loadState()

        XCTAssertTrue(newPlayQueue.isShuffle)
        XCTAssertEqual(newPlayQueue.normalIndex, 1)
        XCTAssertEqual(newPlayQueue.shuffleIndex, 2)
        XCTAssertEqual(newPlayer.startByteOffset, 999)
        XCTAssertEqual(newPlayer.startSecondsOffset, 10.0, accuracy: 0.001)
    }

    func testLoadStateInvalidRepeatModeFallsBackToNone() {
        testDefaults.set(99, forKey: SavedSettings.Key.repeatMode.rawValue)
        stateRestorer.loadState()
        XCTAssertEqual(playQueue.repeatMode, RepeatMode.none)
    }
}

