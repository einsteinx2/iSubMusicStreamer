//
//  BookmarkStoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-03/BUG-18: CRUD tests for bookmarks and their snapshot local playlists,
// including Store.addBookmark (which used to trip GRDB's reentrancy precondition
// by nesting pool.read inside pool.write).
final class BookmarkStoreTests: StoreTestCase {
    private var song: Song!

    override func setUpWithError() throws {
        try super.setUpWithError()
        song = TestData.song(serverId: 1, id: "42", title: "Bookmarked Song", path: "A/B/song.mp3")
        XCTAssertTrue(store.add(song: song))
    }

    override func tearDownWithError() throws {
        song = nil
        try super.tearDownWithError()
    }

    // Builds the structure addBookmark creates: a snapshot playlist of the play
    // queue plus the bookmark row pointing into it
    @discardableResult
    private func makeBookmark(id: Int, name: String = "My Bookmark", songIndex: Int = 0, offsetInSeconds: Double = 30.5, offsetInBytes: Int = 123456, songs: [Song]? = nil) throws -> Bookmark {
        let snapshotSongs = songs ?? [song!]
        let playlistId = try XCTUnwrap(store.nextLocalPlaylistId)
        var playlist = LocalPlaylist(id: playlistId, name: name, isBookmark: true)
        XCTAssertTrue(store.add(localPlaylist: playlist))
        for snapshotSong in snapshotSongs {
            _ = store.add(song: snapshotSong)
            XCTAssertTrue(store.add(song: snapshotSong, localPlaylistId: playlistId))
        }
        playlist.songCount = snapshotSongs.count

        let bookmark = Bookmark(id: id, song: snapshotSongs[songIndex], localPlaylist: playlist, songIndex: songIndex, offsetInSeconds: offsetInSeconds, offsetInBytes: offsetInBytes)
        try store.pool.write { db in
            try bookmark.save(db)
        }
        return bookmark
    }

    // MARK: addBookmark (BUG-18 regression)

    private func makePlayQueue(songCount: Int) -> PlayQueue {
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        for number in 1...songCount {
            let queueSong = TestData.song(serverId: 1, id: "q\(number)", title: "Queued \(number)", path: "q/\(number).mp3")
            _ = store.add(song: queueSong)
            XCTAssertTrue(store.add(song: queueSong, localPlaylistId: LocalPlaylist.Default.playQueueId))
        }
        return freshPlayQueue
    }

    func testAddBookmarkSnapshotsPlayQueue() throws {
        _ = makePlayQueue(songCount: 3)

        XCTAssertTrue(store.addBookmark(name: "My Bookmark", songIndex: 1, offsetInSeconds: 30.5, offsetInBytes: 123456))

        let bookmark = try XCTUnwrap(store.bookmarks().first)
        XCTAssertEqual(bookmark.songId, "q2", "the bookmark points at the song at the given index")
        XCTAssertEqual(bookmark.songServerId, 1)
        XCTAssertEqual(bookmark.songIndex, 1)
        XCTAssertEqual(bookmark.offsetInSeconds, 30.5, accuracy: 0.001)
        XCTAssertEqual(bookmark.offsetInBytes, 123456)

        // The play queue is snapshotted into a bookmark playlist, in order
        let playlist = try XCTUnwrap(store.localPlaylist(bookmark: bookmark))
        XCTAssertEqual(playlist.name, "My Bookmark")
        XCTAssertTrue(playlist.isBookmark)
        XCTAssertEqual(playlist.songCount, 3)
        XCTAssertEqual(store.songs(localPlaylistId: playlist.id).map(\.id), ["q1", "q2", "q3"])
    }

    func testAddBookmarkAllocatesSequentialIds() throws {
        _ = makePlayQueue(songCount: 2)

        XCTAssertTrue(store.addBookmark(name: "First", songIndex: 0, offsetInSeconds: 0, offsetInBytes: 0))
        XCTAssertTrue(store.addBookmark(name: "Second", songIndex: 1, offsetInSeconds: 5, offsetInBytes: 10))

        XCTAssertEqual(store.bookmarks().map(\.id), [2, 1])
        let first = try XCTUnwrap(store.bookmark(id: 1))
        let second = try XCTUnwrap(store.bookmark(id: 2))
        XCTAssertNotEqual(first.localPlaylistId, second.localPlaylistId, "each bookmark gets its own snapshot playlist")
        XCTAssertEqual(store.localPlaylists(isBookmark: true).count, 2)
    }

    func testAddBookmarkFailsForMissingSongIndex() {
        _ = makePlayQueue(songCount: 1)
        XCTAssertFalse(store.addBookmark(name: "Nope", songIndex: 5, offsetInSeconds: 0, offsetInBytes: 0))
        XCTAssertEqual(store.bookmarks().count, 0)
    }

    // MARK: id allocation

    func testNextBookmarkIdOnEmptyTableIsOne() {
        XCTAssertEqual(store.nextBookmarkId, 1)
    }

    func testNextBookmarkIdIsMaxPlusOne() throws {
        try makeBookmark(id: 3)
        try makeBookmark(id: 7)
        XCTAssertEqual(store.nextBookmarkId, 8)
    }

    func testBookmarkRoundTrip() throws {
        let bookmark = try makeBookmark(id: 1, songIndex: 0, offsetInSeconds: 30.5, offsetInBytes: 123456)

        let fetched = try XCTUnwrap(store.bookmark(id: 1))
        XCTAssertEqual(fetched, bookmark)
        XCTAssertEqual(fetched.songServerId, 1)
        XCTAssertEqual(fetched.songId, "42")
        XCTAssertEqual(fetched.songIndex, 0)
        XCTAssertEqual(fetched.offsetInSeconds, 30.5, accuracy: 0.001)
        XCTAssertEqual(fetched.offsetInBytes, 123456)
        XCTAssertNil(store.bookmark(id: 99))
    }

    func testBookmarksReturnsNewestFirst() throws {
        try makeBookmark(id: 1, name: "First")
        try makeBookmark(id: 2, name: "Second")
        try makeBookmark(id: 3, name: "Third")
        XCTAssertEqual(store.bookmarks().map(\.id), [3, 2, 1])
    }

    func testBookmarksCountForSong() throws {
        try makeBookmark(id: 1)
        try makeBookmark(id: 2)
        XCTAssertEqual(store.bookmarksCount(song: song), 2)

        let otherSong = TestData.song(serverId: 1, id: "43", path: "A/other.mp3")
        XCTAssertEqual(store.bookmarksCount(song: otherSong), 0)

        // Same song id on a different server must not count
        let otherServerSong = TestData.song(serverId: 2, id: "42", path: "A/B/song.mp3")
        XCTAssertEqual(store.bookmarksCount(song: otherServerSong), 0)
    }

    func testSongAndLocalPlaylistAccessors() throws {
        let bookmark = try makeBookmark(id: 1)
        XCTAssertEqual(store.song(bookmark: bookmark)?.id, "42")
        let playlist = try XCTUnwrap(store.localPlaylist(bookmark: bookmark))
        XCTAssertTrue(playlist.isBookmark)
        XCTAssertEqual(store.songs(localPlaylistId: playlist.id).map(\.id), ["42"])
    }

    func testDeleteBookmarkCascadesSnapshotPlaylist() throws {
        let songB = TestData.song(serverId: 1, id: "43", title: "Second", path: "A/second.mp3")
        let bookmark = try makeBookmark(id: 1, songs: [song, songB])
        let playlistId = bookmark.localPlaylistId

        XCTAssertTrue(store.delete(bookmark: bookmark))

        XCTAssertNil(store.bookmark(id: 1))
        XCTAssertNil(store.localPlaylist(id: playlistId), "snapshot playlist must be deleted with the bookmark")
        let orphanCount = try store.pool.read { db in
            try SQLRequest<Int>(literal: "SELECT COUNT(*) FROM localPlaylistSong WHERE localPlaylistId = \(playlistId)").fetchOne(db) ?? -1
        }
        XCTAssertEqual(orphanCount, 0, "snapshot playlist songs must be deleted with the bookmark")
    }

    func testDeleteByBookmarkIdOnlyAffectsThatBookmark() throws {
        try makeBookmark(id: 1)
        try makeBookmark(id: 2)

        XCTAssertTrue(store.delete(bookmarkId: 1))
        XCTAssertNil(store.bookmark(id: 1))
        XCTAssertNotNil(store.bookmark(id: 2))
        XCTAssertFalse(store.delete(bookmarkId: 99), "deleting a missing bookmark reports failure")
    }
}
