//
//  PlaylistStoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-03: CRUD tests for local playlists (basic lifecycle; the queue-positioning
// suite is COV-04) and server playlists with their song snapshots.
final class LocalPlaylistStoreCRUDTests: StoreTestCase {
    func testDefaultPlaylistsExistAfterMigration() {
        for id in 1...LocalPlaylist.Default.maxDefaultId {
            XCTAssertNotNil(store.localPlaylist(id: id), "default playlist \(id) missing")
        }
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.playQueueId)?.name, "Play Queue")
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.shuffleQueueId)?.name, "Shuffle Queue")
    }

    func testNextLocalPlaylistIdSkipsDefaults() {
        // The four default playlists occupy ids 1-4
        XCTAssertEqual(store.nextLocalPlaylistId, LocalPlaylist.Default.maxDefaultId + 1)
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 10, name: "Mine")))
        XCTAssertEqual(store.nextLocalPlaylistId, 11)
    }

    func testLocalPlaylistsExcludesDefaultsAndBookmarks() {
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Regular")))
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 6, name: "Bookmark Snapshot", isBookmark: true)))

        XCTAssertEqual(store.localPlaylists().map(\.name), ["Regular"])
        XCTAssertEqual(store.localPlaylists(isBookmark: true).map(\.name), ["Bookmark Snapshot"])
        XCTAssertEqual(store.localPlaylistsCount(), 1)
        XCTAssertEqual(store.localPlaylistsCount(isBookmark: true), 1)
    }

    func testAddAndFetchLocalPlaylistRoundTrip() throws {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Road Trip", songCount: 0, isBookmark: false, createdDate: created)))
        let fetched = try XCTUnwrap(store.localPlaylist(id: 5))
        XCTAssertEqual(fetched.name, "Road Trip")
        XCTAssertEqual(fetched.songCount, 0)
        XCTAssertFalse(fetched.isBookmark)
        XCTAssertEqual(fetched.createdDate.timeIntervalSince1970, created.timeIntervalSince1970, accuracy: 0.001)
    }

    func testAddSongsAndFetchInOrder() {
        let songA = TestData.song(serverId: 1, id: "1", title: "First", path: "a/1.mp3")
        let songB = TestData.song(serverId: 1, id: "2", title: "Second", path: "a/2.mp3")
        _ = store.add(song: songA)
        _ = store.add(song: songB)
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "List")))

        XCTAssertTrue(store.add(song: songA, localPlaylistId: 5))
        XCTAssertTrue(store.add(song: songB, localPlaylistId: 5))

        XCTAssertEqual(store.localPlaylist(id: 5)?.songCount, 2)
        XCTAssertEqual(store.song(localPlaylistId: 5, position: 0)?.id, "1")
        XCTAssertEqual(store.song(localPlaylistId: 5, position: 1)?.id, "2")
        XCTAssertNil(store.song(localPlaylistId: 5, position: 2))
        XCTAssertEqual(store.songs(localPlaylistId: 5).count, 2)
    }

    func testLocalPlaylistNameLookupIgnoresDefaultsAndBookmarks_STUB10() {
        // The overwrite check must not match the fixed queue playlists or bookmark snapshots
        XCTAssertNil(store.localPlaylist(name: "Play Queue"), "default playlists must not match")

        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Road Trip")))
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 6, name: "Snapshot", isBookmark: true)))

        XCTAssertEqual(store.localPlaylist(name: "Road Trip")?.id, 5)
        XCTAssertNil(store.localPlaylist(name: "Snapshot"), "bookmark snapshots must not match")
        XCTAssertNil(store.localPlaylist(name: "Missing"))
    }

    func testSongIdsAreScopedByServerAndOrderedByPosition() {
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "Mixed Servers")))
        // Interleave songs from two servers; positions are assigned in add order
        _ = store.add(song: TestData.song(serverId: 1, id: "30", path: "a/30.mp3"), localPlaylistId: 5)
        _ = store.add(song: TestData.song(serverId: 2, id: "99", path: "b/99.mp3"), localPlaylistId: 5)
        _ = store.add(song: TestData.song(serverId: 1, id: "10", path: "a/10.mp3"), localPlaylistId: 5)

        XCTAssertEqual(store.songIds(localPlaylistId: 5, serverId: 1), ["30", "10"], "must be ordered by position and exclude other servers")
        XCTAssertEqual(store.songIds(localPlaylistId: 5, serverId: 2), ["99"])
        XCTAssertEqual(store.songIds(localPlaylistId: 5, serverId: 3), [])
    }

    func testDeleteLocalPlaylistCascadesSongs() throws {
        let song = TestData.song(serverId: 1, id: "1", path: "a/1.mp3")
        _ = store.add(song: song)
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "List")))
        XCTAssertTrue(store.add(song: song, localPlaylistId: 5))

        store.delete(localPlaylistId: 5)

        XCTAssertNil(store.localPlaylist(id: 5))
        let orphanCount = try store.pool.read { db in
            try SQLRequest<Int>(literal: "SELECT COUNT(*) FROM localPlaylistSong WHERE localPlaylistId = 5").fetchOne(db) ?? -1
        }
        XCTAssertEqual(orphanCount, 0, "localPlaylistSong rows must be deleted with the playlist")
    }

    func testClearLocalPlaylistResetsCountAndSongs() {
        let song = TestData.song(serverId: 1, id: "1", path: "a/1.mp3")
        _ = store.add(song: song)
        XCTAssertTrue(store.add(localPlaylist: LocalPlaylist(id: 5, name: "List")))
        XCTAssertTrue(store.add(song: song, localPlaylistId: 5))

        XCTAssertTrue(store.clear(localPlaylistId: 5))
        XCTAssertEqual(store.localPlaylist(id: 5)?.songCount, 0)
        XCTAssertEqual(store.songs(localPlaylistId: 5).count, 0)
        // The playlist row itself remains
        XCTAssertNotNil(store.localPlaylist(id: 5))
    }
}

// COV-03: CRUD tests for server playlists and the serverPlaylistSong snapshot table
final class ServerPlaylistStoreTests: StoreTestCase {
    private func makeServerPlaylist(serverId: Int = 1, id: Int = 17, name: String = "Road Trip", songCount: Int = 2) -> ServerPlaylist {
        let xml = "<playlist id=\"\(id)\" name=\"\(name)\" owner=\"bbaron\" public=\"false\" songCount=\"\(songCount)\" duration=\"500\"/>"
        return ServerPlaylist(serverId: serverId, element: try! XMLTestHelpers.element(tag: "playlist", xml: xml))
    }

    func testAddAndFetchServerPlaylist() throws {
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist()))
        let fetched = try XCTUnwrap(store.serverPlaylist(serverId: 1, id: 17))
        XCTAssertEqual(fetched.name, "Road Trip")
        XCTAssertEqual(fetched.songCount, 2)
        XCTAssertEqual(fetched.loadedSongCount, 0)
        XCTAssertNil(store.serverPlaylist(serverId: 2, id: 17))
    }

    func testServerPlaylistsAreScopedByServer() {
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(serverId: 1, id: 1)))
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(serverId: 1, id: 2)))
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(serverId: 2, id: 3)))

        XCTAssertEqual(store.serverPlaylists().count, 3)
        XCTAssertEqual(store.serverPlaylistsCount(), 3)
        XCTAssertEqual(store.serverPlaylists(serverId: 1).map(\.id).sorted(), [1, 2])
        XCTAssertEqual(store.serverPlaylistsCount(serverId: 1), 2)
        XCTAssertEqual(store.serverPlaylistsCount(serverId: 2), 1)
    }

    func testAddSongsTracksLoadedCountAndPositions() {
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(songCount: 2)))
        let songA = TestData.song(serverId: 1, id: "100", title: "First", path: "a/1.mp3")
        let songB = TestData.song(serverId: 1, id: "200", title: "Second", path: "a/2.mp3")
        _ = store.add(song: songA)
        _ = store.add(song: songB)

        XCTAssertFalse(store.isServerPlaylistSongsCached(serverId: 1, id: 17))
        XCTAssertTrue(store.add(song: songA, serverId: 1, serverPlaylistId: 17))
        XCTAssertTrue(store.add(song: songB, serverId: 1, serverPlaylistId: 17))

        XCTAssertEqual(store.serverPlaylist(serverId: 1, id: 17)?.loadedSongCount, 2)
        XCTAssertEqual(store.songIds(serverId: 1, serverPlaylistId: 17), ["100", "200"])
        XCTAssertEqual(store.song(serverId: 1, serverPlaylistId: 17, position: 0)?.id, "100")
        XCTAssertEqual(store.song(serverId: 1, serverPlaylistId: 17, position: 1)?.id, "200")
        XCTAssertNil(store.song(serverId: 1, serverPlaylistId: 17, position: 2))
        // Both loaded songs == songCount, so the playlist counts as fully cached
        XCTAssertTrue(store.isServerPlaylistSongsCached(serverId: 1, id: 17))
    }

    func testNonNumericSongIdsSurviveTheSnapshotJoin_BUG19() {
        // serverPlaylistSong.songId joins against the TEXT song.id; the column used to be
        // declared INTEGER, whose affinity coerces values like "0042" to 42 and breaks
        // the join (and truly non-numeric ids like UUIDs)
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(songCount: 2)))
        let leadingZero = TestData.song(serverId: 1, id: "0042", title: "Zero", path: "a/1.mp3")
        let uuidLike = TestData.song(serverId: 1, id: "al-9f2c", title: "UUID", path: "a/2.mp3")
        _ = store.add(song: leadingZero)
        _ = store.add(song: uuidLike)
        XCTAssertTrue(store.add(song: leadingZero, serverId: 1, serverPlaylistId: 17))
        XCTAssertTrue(store.add(song: uuidLike, serverId: 1, serverPlaylistId: 17))

        XCTAssertEqual(store.songIds(serverId: 1, serverPlaylistId: 17), ["0042", "al-9f2c"])
        XCTAssertEqual(store.song(serverId: 1, serverPlaylistId: 17, position: 0)?.id, "0042")
        XCTAssertEqual(store.song(serverId: 1, serverPlaylistId: 17, position: 1)?.id, "al-9f2c")
    }

    func testAddSongToMissingPlaylistFails() {
        let song = TestData.song(serverId: 1, id: "100", path: "a/1.mp3")
        _ = store.add(song: song)
        XCTAssertFalse(store.add(song: song, serverId: 1, serverPlaylistId: 999))
    }

    func testClearRemovesSongsAndResetsLoadedCount() {
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist()))
        let song = TestData.song(serverId: 1, id: "100", path: "a/1.mp3")
        _ = store.add(song: song)
        XCTAssertTrue(store.add(song: song, serverId: 1, serverPlaylistId: 17))

        XCTAssertTrue(store.clear(serverId: 1, serverPlaylistId: 17))
        XCTAssertEqual(store.serverPlaylist(serverId: 1, id: 17)?.loadedSongCount, 0)
        XCTAssertEqual(store.songIds(serverId: 1, serverPlaylistId: 17).count, 0)
        // The playlist row remains after a clear
        XCTAssertNotNil(store.serverPlaylist(serverId: 1, id: 17))
    }

    func testDeleteCascadesSongsAndOnlyAffectsThatPlaylist() throws {
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(id: 17)))
        XCTAssertTrue(store.add(serverPlaylist: makeServerPlaylist(id: 18, name: "Other")))
        let song = TestData.song(serverId: 1, id: "100", path: "a/1.mp3")
        _ = store.add(song: song)
        XCTAssertTrue(store.add(song: song, serverId: 1, serverPlaylistId: 17))
        XCTAssertTrue(store.add(song: song, serverId: 1, serverPlaylistId: 18))

        XCTAssertTrue(store.delete(serverId: 1, serverPlaylistId: 17))

        XCTAssertNil(store.serverPlaylist(serverId: 1, id: 17))
        let orphanCount = try store.pool.read { db in
            try SQLRequest<Int>(literal: "SELECT COUNT(*) FROM serverPlaylistSong WHERE serverId = 1 AND serverPlaylistId = 17").fetchOne(db) ?? -1
        }
        XCTAssertEqual(orphanCount, 0)
        XCTAssertNotNil(store.serverPlaylist(serverId: 1, id: 18))
        XCTAssertEqual(store.songIds(serverId: 1, serverPlaylistId: 18).count, 1)
    }
}
