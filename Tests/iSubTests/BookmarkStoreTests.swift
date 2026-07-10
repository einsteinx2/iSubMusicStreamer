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

// COV-03: CRUD tests for bookmarks and their snapshot local playlists.
//
// NOTE: Store.addBookmark cannot be exercised directly yet: it evaluates
// nextLocalPlaylistId/nextBookmarkId (each a pool.read) inside pool.write, which
// trips GRDB's uncatchable "Database methods are not reentrant" precondition
// (BUG-18). These tests build the same snapshot structure addBookmark produces
// and cover the read/delete paths; addBookmark's own test lands with the
// BUG-18 fix.
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
