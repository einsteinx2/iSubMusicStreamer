//
//  LocalPlaylistQueueTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-04: queue-positioning tests for LocalPlaylistStore — the localPlaylistSong
// position bookkeeping that backs everything PlayQueue does.
final class LocalPlaylistQueueTests: StoreTestCase {
    private let playlistId = 5
    private var playQueue: PlayQueue!
    private var settings: SavedSettings!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // LocalPlaylistStore resolves PlayQueue and SavedSettings from the container,
        // so register fresh instances backed by the test store/defaults
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        settings = freshSettings
        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue

        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: playlistId, name: "Test Queue")))
    }

    override func tearDownWithError() throws {
        playQueue = nil
        settings = nil
        try super.tearDownWithError()
    }

    // Adds numbered songs (ids "1"..."<count>") to the given playlist
    private func seedSongs(_ count: Int, playlistId: Int? = nil) {
        let targetPlaylistId = playlistId ?? self.playlistId
        for number in 1...count {
            let song = TestData.song(serverId: 1, id: "\(number)", title: "Song \(number)", path: "A/\(number).mp3")
            _ = store.add(song: song)
            XCTAssertTrue(store.add(song: song, localPlaylistId: targetPlaylistId))
        }
    }

    private func orderedSongIds(playlistId: Int? = nil) throws -> [String] {
        let targetPlaylistId = playlistId ?? self.playlistId
        return try store.pool.read { db in
            let sql: SQL = """
                SELECT songId
                FROM localPlaylistSong
                WHERE localPlaylistId = \(targetPlaylistId)
                ORDER BY position ASC
                """
            return try SQLRequest<String>(literal: sql).fetchAll(db)
        }
    }

    private func positions(playlistId: Int? = nil) throws -> [Int] {
        let targetPlaylistId = playlistId ?? self.playlistId
        return try store.pool.read { db in
            let sql: SQL = """
                SELECT position
                FROM localPlaylistSong
                WHERE localPlaylistId = \(targetPlaylistId)
                ORDER BY position ASC
                """
            return try SQLRequest<Int>(literal: sql).fetchAll(db)
        }
    }

    // MARK: Contiguous positions on add

    func testAddAssignsContiguousPositions() throws {
        seedSongs(4)
        XCTAssertEqual(try positions(), [0, 1, 2, 3])
        XCTAssertEqual(try orderedSongIds(), ["1", "2", "3", "4"])
        XCTAssertEqual(store.localPlaylist(id: playlistId)?.songCount, 4)
    }

    func testInsertAtPositionShiftsSubsequentSongs() throws {
        seedSongs(3)
        let newSong = TestData.song(serverId: 1, id: "99", title: "Inserted", path: "A/99.mp3")
        _ = store.add(song: newSong)

        XCTAssertTrue(store.add(song: newSong, localPlaylistId: playlistId, position: 1))

        XCTAssertEqual(try orderedSongIds(), ["1", "99", "2", "3"])
        XCTAssertEqual(try positions(), [0, 1, 2, 3])
        XCTAssertEqual(store.localPlaylist(id: playlistId)?.songCount, 4)
    }

    func testInsertAtEndPositionAppends() throws {
        seedSongs(2)
        let newSong = TestData.song(serverId: 1, id: "99", path: "A/99.mp3")
        _ = store.add(song: newSong)
        XCTAssertTrue(store.add(song: newSong, localPlaylistId: playlistId, position: 2))
        XCTAssertEqual(try orderedSongIds(), ["1", "2", "99"])
    }

    func testInsertPastEndFails() {
        seedSongs(2)
        let newSong = TestData.song(serverId: 1, id: "99", path: "A/99.mp3")
        _ = store.add(song: newSong)
        XCTAssertFalse(store.add(song: newSong, localPlaylistId: playlistId, position: 5))
    }

    // MARK: move(songAtPosition:toPosition:)

    func testMoveForwardPreservesRelativeOrder() throws {
        seedSongs(5)
        XCTAssertTrue(store.move(songAtPosition: 1, toPosition: 3, localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["1", "3", "4", "2", "5"])
        XCTAssertEqual(try positions(), [0, 1, 2, 3, 4])
    }

    func testMoveBackwardPreservesRelativeOrder() throws {
        seedSongs(5)
        XCTAssertTrue(store.move(songAtPosition: 3, toPosition: 1, localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["1", "4", "2", "3", "5"])
        XCTAssertEqual(try positions(), [0, 1, 2, 3, 4])
    }

    func testMoveToBoundaries() throws {
        seedSongs(3)
        XCTAssertTrue(store.move(songAtPosition: 2, toPosition: 0, localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["3", "1", "2"])
        XCTAssertTrue(store.move(songAtPosition: 0, toPosition: 2, localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["1", "2", "3"])
    }

    func testInvalidMovesAreRejected() throws {
        seedSongs(3)
        XCTAssertFalse(store.move(songAtPosition: 1, toPosition: 1, localPlaylistId: playlistId), "same position")
        XCTAssertFalse(store.move(songAtPosition: 1, toPosition: -1, localPlaylistId: playlistId), "negative target")
        XCTAssertFalse(store.move(songAtPosition: 1, toPosition: 3, localPlaylistId: playlistId), "target past the end")
        XCTAssertFalse(store.move(songAtPosition: 9, toPosition: 0, localPlaylistId: playlistId), "missing source")
        XCTAssertEqual(try orderedSongIds(), ["1", "2", "3"], "failed moves must not modify the playlist")
    }

    // MARK: remove(songsAtPositions:)

    func testRemoveSingleSongClosesGap() throws {
        seedSongs(4)
        XCTAssertTrue(store.remove(songsAtPositions: [1], localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["1", "3", "4"])
        XCTAssertEqual(try positions(), [0, 1, 2])
        XCTAssertEqual(store.localPlaylist(id: playlistId)?.songCount, 3)
    }

    func testRemoveMultipleSongsClosesGaps() throws {
        seedSongs(5)
        XCTAssertTrue(store.remove(songsAtPositions: [0, 2, 4], localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["2", "4"])
        XCTAssertEqual(try positions(), [0, 1])
        XCTAssertEqual(store.localPlaylist(id: playlistId)?.songCount, 2)
    }

    func testRemoveIgnoresInvalidPositions() throws {
        seedSongs(3)
        XCTAssertTrue(store.remove(songsAtPositions: [-1, 1, 99], localPlaylistId: playlistId))
        XCTAssertEqual(try orderedSongIds(), ["1", "3"])
        XCTAssertEqual(store.localPlaylist(id: playlistId)?.songCount, 2)
    }

    func testRemoveFromMissingPlaylistFails() {
        XCTAssertFalse(store.remove(songsAtPositions: [0], localPlaylistId: 999))
    }

    // MARK: getSongPosition

    func testGetSongPosition() {
        seedSongs(3)
        XCTAssertEqual(store.getSongPosition(localPlaylistId: playlistId, songId: "1"), 0)
        XCTAssertEqual(store.getSongPosition(localPlaylistId: playlistId, songId: "3"), 2)
        XCTAssertNil(store.getSongPosition(localPlaylistId: playlistId, songId: "42"))
        XCTAssertNil(store.getSongPosition(localPlaylistId: 999, songId: "1"))
        // NOTE: the query converts songId via Int(songId), so non-numeric Subsonic
        // ids never match (related to the BUG-19 column-affinity cleanup)
        XCTAssertNil(store.getSongPosition(localPlaylistId: playlistId, songId: "abc"))
    }

    // MARK: createShuffleQueue

    func testCreateShuffleQueueProducesPermutationWithCurrentSongFirst() throws {
        seedSongs(10, playlistId: LocalPlaylist.Default.playQueueId)

        XCTAssertTrue(store.createShuffleQueue(currentPosition: 4))

        let shuffled = try orderedSongIds(playlistId: LocalPlaylist.Default.shuffleQueueId)
        XCTAssertEqual(shuffled.count, 10)
        XCTAssertEqual(shuffled.first, "5", "current song must be first in the shuffle queue")
        XCTAssertEqual(Set(shuffled), Set((1...10).map(String.init)), "shuffle queue must be a permutation of the play queue")
        XCTAssertEqual(try positions(playlistId: LocalPlaylist.Default.shuffleQueueId), Array(0...9), "positions must be contiguous")
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.shuffleQueueId)?.songCount, 10)
        // The source play queue is untouched
        XCTAssertEqual(try orderedSongIds(playlistId: LocalPlaylist.Default.playQueueId), (1...10).map(String.init))
    }

    func testCreateShuffleQueueReplacesPreviousShuffleQueue() throws {
        seedSongs(3, playlistId: LocalPlaylist.Default.playQueueId)
        XCTAssertTrue(store.createShuffleQueue(currentPosition: 0))
        XCTAssertTrue(store.createShuffleQueue(currentPosition: 2))

        let shuffled = try orderedSongIds(playlistId: LocalPlaylist.Default.shuffleQueueId)
        XCTAssertEqual(shuffled.count, 3)
        XCTAssertEqual(shuffled.first, "3")
    }

    // MARK: clearPlayQueue scoping

    private func seedAllQueues() {
        let song = TestData.song(serverId: 1, id: "1", path: "A/1.mp3")
        _ = store.add(song: song)
        for queueId in 1...LocalPlaylist.Default.maxDefaultId {
            XCTAssertTrue(store.add(song: song, localPlaylistId: queueId))
        }
        _ = store.add(song: song, localPlaylistId: playlistId)
    }

    private func songCounts() -> [Int: Int] {
        var counts = [Int: Int]()
        for queueId in 1...LocalPlaylist.Default.maxDefaultId {
            counts[queueId] = store.songs(localPlaylistId: queueId).count
        }
        counts[playlistId] = store.songs(localPlaylistId: playlistId).count
        return counts
    }

    func testClearPlayQueueOnlyClearsNormalPlayQueue() {
        seedAllQueues()
        playQueue.isShuffle = false
        settings.isJukeboxEnabled = false

        XCTAssertTrue(store.clearPlayQueue())

        let counts = songCounts()
        XCTAssertEqual(counts[LocalPlaylist.Default.playQueueId], 0)
        XCTAssertEqual(counts[LocalPlaylist.Default.shuffleQueueId], 1)
        XCTAssertEqual(counts[LocalPlaylist.Default.jukeboxPlayQueueId], 1)
        XCTAssertEqual(counts[LocalPlaylist.Default.jukeboxShuffleQueueId], 1)
        XCTAssertEqual(counts[playlistId], 1, "regular playlists must never be cleared")
    }

    func testClearPlayQueueInShuffleModeAlsoClearsShuffleQueue() {
        seedAllQueues()
        playQueue.isShuffle = true
        settings.isJukeboxEnabled = false

        XCTAssertTrue(store.clearPlayQueue())

        let counts = songCounts()
        XCTAssertEqual(counts[LocalPlaylist.Default.playQueueId], 0)
        XCTAssertEqual(counts[LocalPlaylist.Default.shuffleQueueId], 0)
        XCTAssertEqual(counts[LocalPlaylist.Default.jukeboxPlayQueueId], 1)
        XCTAssertEqual(counts[LocalPlaylist.Default.jukeboxShuffleQueueId], 1)
    }

    func testClearPlayQueueInJukeboxModeClearsJukeboxQueue() {
        seedAllQueues()
        playQueue.isShuffle = false
        settings.isJukeboxEnabled = true

        XCTAssertTrue(store.clearPlayQueue())

        let counts = songCounts()
        XCTAssertEqual(counts[LocalPlaylist.Default.playQueueId], 1)
        XCTAssertEqual(counts[LocalPlaylist.Default.shuffleQueueId], 1)
        XCTAssertEqual(counts[LocalPlaylist.Default.jukeboxPlayQueueId], 0)
        XCTAssertEqual(counts[LocalPlaylist.Default.jukeboxShuffleQueueId], 1)
    }

    // MARK: song(localPlaylistId:position:)

    func testSongAtPosition() {
        seedSongs(3)
        XCTAssertEqual(store.song(localPlaylistId: playlistId, position: 0)?.id, "1")
        XCTAssertEqual(store.song(localPlaylistId: playlistId, position: 2)?.id, "3")
        XCTAssertNil(store.song(localPlaylistId: playlistId, position: 3))
        XCTAssertNil(store.song(localPlaylistId: 999, position: 0))
    }
}
