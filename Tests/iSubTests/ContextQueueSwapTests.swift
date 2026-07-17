//
//  ContextQueueSwapTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/17/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// The per-context queue snapshot swap: saving the live queue rows under the outgoing
// context, restoring the incoming context's rows and state in the same transaction,
// the ownership marker, and the crash-heal reconcile.
final class ContextQueueSwapTests: StoreTestCase {

    private func seedSongs(_ songs: [Song]) throws {
        try store.pool.write { db in
            for song in songs {
                try song.save(db)
            }
        }
    }

    private func queueSongs(_ songs: [Song], playlistId: Int) {
        for song in songs {
            XCTAssertTrue(store.add(song: song, localPlaylistId: playlistId))
        }
    }

    private func liveSongIds(playlistId: Int) -> [String] {
        store.songs(localPlaylistId: playlistId).map(\.id)
    }

    func testSwapSavesOutgoingAndRestoresItLater() throws {
        let songs = [TestData.song(serverId: 1, id: "10", path: "a/10.mp3"),
                     TestData.song(serverId: 2, id: "20", path: "a/20.mp3"),
                     TestData.song(serverId: 1, id: "30", path: "a/30.mp3")]
        try seedSongs(songs)
        queueSongs(songs, playlistId: LocalPlaylist.Default.playQueueId)
        queueSongs([songs[2], songs[0]], playlistId: LocalPlaylist.Default.shuffleQueueId)
        let state = PlayQueueStateSnapshot(isShuffle: true, repeatMode: .all, normalIndex: 2, shuffleIndex: 1,
                                           seekTime: 42.5, byteOffset: 9_999, kiloBitrate: 192)

        // Switch away from context 1 into context 7 (no snapshot yet)
        let incoming = store.swapLiveQueue(outgoingContextId: 1, outgoingState: state, incomingContextId: 7)

        XCTAssertEqual(incoming, PlayQueueStateSnapshot(), "a context without a snapshot restores clean defaults")
        XCTAssertTrue(liveSongIds(playlistId: LocalPlaylist.Default.playQueueId).isEmpty)
        XCTAssertTrue(liveSongIds(playlistId: LocalPlaylist.Default.shuffleQueueId).isEmpty)
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.playQueueId)?.songCount, 0)
        XCTAssertEqual(store.liveQueueContextId(), 7)

        // Switch back: the exact queue, shuffle order, counts, and state come back
        let restored = store.swapLiveQueue(outgoingContextId: 7, outgoingState: nil, incomingContextId: 1)

        XCTAssertEqual(restored, state)
        XCTAssertEqual(liveSongIds(playlistId: LocalPlaylist.Default.playQueueId), ["10", "20", "30"])
        XCTAssertEqual(liveSongIds(playlistId: LocalPlaylist.Default.shuffleQueueId), ["30", "10"])
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.playQueueId)?.songCount, 3)
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.shuffleQueueId)?.songCount, 2)
        XCTAssertEqual(store.liveQueueContextId(), 1)

        // Restoring copied — the snapshot survives for the next switch too
        XCTAssertEqual(store.contextQueueState(contextId: 1), state)
    }

    func testMixedServerRowsSurviveTheRoundTrip() throws {
        let songs = [TestData.song(serverId: 1, id: "1", path: "a/1.mp3"),
                     TestData.song(serverId: 2, id: "1", path: "b/1.mp3")]
        try seedSongs(songs)
        queueSongs(songs, playlistId: LocalPlaylist.Default.playQueueId)

        _ = store.swapLiveQueue(outgoingContextId: 0, outgoingState: nil, incomingContextId: 5)
        _ = store.swapLiveQueue(outgoingContextId: 5, outgoingState: nil, incomingContextId: 0)

        let restored = store.songs(localPlaylistId: LocalPlaylist.Default.playQueueId)
        XCTAssertEqual(restored.map(\.serverId), [1, 2], "the same song id on two servers must stay two distinct rows")
    }

    func testSecondSaveOverwritesTheContextSnapshot() throws {
        let first = [TestData.song(serverId: 1, id: "10", path: "a/10.mp3")]
        let second = [TestData.song(serverId: 1, id: "99", path: "a/99.mp3")]
        try seedSongs(first + second)
        queueSongs(first, playlistId: LocalPlaylist.Default.playQueueId)

        _ = store.swapLiveQueue(outgoingContextId: 1, outgoingState: nil, incomingContextId: 2)
        queueSongs(second, playlistId: LocalPlaylist.Default.playQueueId)
        _ = store.swapLiveQueue(outgoingContextId: 2, outgoingState: nil, incomingContextId: 1)
        _ = store.swapLiveQueue(outgoingContextId: 1, outgoingState: nil, incomingContextId: 2)

        XCTAssertEqual(liveSongIds(playlistId: LocalPlaylist.Default.playQueueId), ["99"],
                       "context 2's snapshot was overwritten by its second save")
    }

    func testJukeboxQueueRowsAreNotPartOfContextState() throws {
        let songs = [TestData.song(serverId: 1, id: "10", path: "a/10.mp3")]
        try seedSongs(songs)
        queueSongs(songs, playlistId: LocalPlaylist.Default.jukeboxPlayQueueId)

        _ = store.swapLiveQueue(outgoingContextId: 1, outgoingState: nil, incomingContextId: 2)

        XCTAssertEqual(liveSongIds(playlistId: LocalPlaylist.Default.jukeboxPlayQueueId), ["10"],
                       "jukebox rows are untouched by context switches, matching today's behavior")
    }

    func testReconcileHealsAMarkerMismatch() throws {
        let songs = [TestData.song(serverId: 1, id: "10", path: "a/10.mp3")]
        try seedSongs(songs)
        queueSongs(songs, playlistId: LocalPlaylist.Default.playQueueId)

        // Save context 1's snapshot, then simulate a crash mid-switch: the database
        // committed a swap to context 2, but the persisted active context is still 1
        _ = store.swapLiveQueue(outgoingContextId: 1, outgoingState: nil, incomingContextId: 2)
        XCTAssertEqual(store.liveQueueContextId(), 2)

        store.reconcileLiveQueue(activeContextId: 1)

        XCTAssertEqual(store.liveQueueContextId(), 1)
        XCTAssertEqual(liveSongIds(playlistId: LocalPlaylist.Default.playQueueId), ["10"],
                       "the persisted context's queue is restored from its snapshot")
    }

    func testReconcileLeavesLiveRowsAloneWhenMarkerMatches() throws {
        let songs = [TestData.song(serverId: 1, id: "10", path: "a/10.mp3"),
                     TestData.song(serverId: 1, id: "20", path: "a/20.mp3")]
        try seedSongs(songs)
        _ = store.swapLiveQueue(outgoingContextId: nil, outgoingState: nil, incomingContextId: 1)
        // Live rows mutated AFTER the last snapshot — they are fresher than it
        queueSongs(songs, playlistId: LocalPlaylist.Default.playQueueId)

        store.reconcileLiveQueue(activeContextId: 1)

        XCTAssertEqual(liveSongIds(playlistId: LocalPlaylist.Default.playQueueId), ["10", "20"],
                       "a matching marker must not clobber the live rows with the stale snapshot")
    }
}

// StateRestorer's context-switch half: capturing the live playback state (with the
// primed-offset fallback) and applying a snapshot as a paused, primed restore.
final class StateRestorerSnapshotTests: StoreTestCase {
    private var session: ServerSession!
    private var settings: SavedSettings!
    private var player: FakePlayer!
    private var playQueue: PlayQueue!
    private var restorer: StateRestorer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        session = ServerSession()
        settings = SavedSettings(session: session)
        player = FakePlayer()
        playQueue = PlayQueue(store: store, settings: settings)
        restorer = StateRestorer(settings: settings, player: player, playQueue: playQueue)
    }

    override func tearDownWithError() throws {
        restorer = nil
        playQueue = nil
        player = nil
        settings = nil
        session = nil
        try super.tearDownWithError()
    }

    func testCaptureReadsLivePlayerWhenStarted() {
        playQueue.isShuffle = true
        playQueue.repeatMode = .one
        playQueue.normalIndex = 3
        playQueue.shuffleIndex = 5
        player.isStarted = true
        player.progress = 42.5
        player.currentByteOffset = 9_999
        player.kiloBitrate = 192

        let snapshot = restorer.captureSnapshot()

        XCTAssertEqual(snapshot, PlayQueueStateSnapshot(isShuffle: true, repeatMode: .one, normalIndex: 3,
                                                        shuffleIndex: 5, seekTime: 42.5, byteOffset: 9_999, kiloBitrate: 192))
    }

    func testCaptureFallsBackToPrimedOffsetsWhenNotStarted() {
        // A stopped player reports progress/currentByteOffset of 0 — capturing those
        // would zero the saved seek of a context that was restored but never played
        player.isStarted = false
        player.progress = 0
        player.currentByteOffset = 0
        player.startSecondsOffset = 42.5
        player.startByteOffset = 9_999

        let snapshot = restorer.captureSnapshot()

        XCTAssertEqual(snapshot.seekTime, 42.5)
        XCTAssertEqual(snapshot.byteOffset, 9_999)
    }

    func testApplyRestoresPausedAndPrimed() {
        let snapshot = PlayQueueStateSnapshot(isShuffle: true, repeatMode: .all, normalIndex: 2,
                                              shuffleIndex: 4, seekTime: 42.5, byteOffset: 9_999, kiloBitrate: 192)
        testDefaults.set(true, forKey: SavedSettings.Key.isPlaying.rawValue)
        testDefaults.set(true, forKey: SavedSettings.Key.recover.rawValue)

        restorer.apply(snapshot: snapshot)

        XCTAssertTrue(playQueue.isShuffle)
        XCTAssertEqual(playQueue.repeatMode, .all)
        XCTAssertEqual(playQueue.normalIndex, 2)
        XCTAssertEqual(playQueue.shuffleIndex, 4)
        XCTAssertEqual(player.startSecondsOffset, 42.5)
        XCTAssertEqual(player.startByteOffset, 9_999)
        XCTAssertTrue(player.startedSongs.isEmpty, "apply must prime the player, never start it")

        XCTAssertFalse(testDefaults.bool(forKey: SavedSettings.Key.isPlaying.rawValue))
        XCTAssertFalse(testDefaults.bool(forKey: SavedSettings.Key.recover.rawValue))
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.normalPlaylistIndex.rawValue), 2)
        XCTAssertEqual(testDefaults.double(forKey: SavedSettings.Key.seekTime.rawValue), 42.5)
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.byteOffset.rawValue), 9_999)
    }

    func testPausedSwitchLoopKeepsSeekPosition() {
        // A→B→A→B without ever pressing play: capture-after-apply must round-trip the
        // same values (the primed-offset fallback), not decay them to zero
        let snapshot = PlayQueueStateSnapshot(isShuffle: false, repeatMode: .none, normalIndex: 1,
                                              shuffleIndex: 0, seekTime: 42.5, byteOffset: 9_999, kiloBitrate: 192)

        restorer.apply(snapshot: snapshot)
        let recaptured = restorer.captureSnapshot()

        XCTAssertEqual(recaptured, snapshot)
    }

    func testSaveStateTickAfterApplyKeepsAppliedSeek() {
        let snapshot = PlayQueueStateSnapshot(isShuffle: false, repeatMode: .none, normalIndex: 1,
                                              shuffleIndex: 0, seekTime: 42.5, byteOffset: 9_999, kiloBitrate: 192)
        restorer.apply(snapshot: snapshot)

        // The 3.3s tick diffs live values against the internal cache; a stopped player
        // reads 0 progress, and without the primed-offset fallback in saveState this
        // would clobber the just-applied seek back to 0 in the defaults
        restorer.saveState()

        XCTAssertEqual(testDefaults.double(forKey: SavedSettings.Key.seekTime.rawValue), 42.5,
                       "the tick must not clobber a paused context's primed seek")
        XCTAssertEqual(testDefaults.integer(forKey: SavedSettings.Key.byteOffset.rawValue), 9_999)
    }
}
