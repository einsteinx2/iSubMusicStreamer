//
//  DownloadsStoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-03: CRUD tests for downloaded songs, path components, and the download queue.
// The BUG-06/07/08/09 regression cases assert the intended behavior inside strict
// XCTExpectFailure blocks; remove the markers when the bug fixes land.
final class DownloadsStoreTests: StoreTestCase {
    // Builds a small downloaded library:
    //   Artist A/Album X/01 Alpha.mp3   (songId 1)
    //   Artist A/Album X/02 Bravo.mp3   (songId 2)
    //   Artist A/Album Y/01 Charlie.mp3 (songId 3)
    //   Artist A/Direct.mp3             (songId 4, file directly in the artist folder)
    //   Artist B/Album Z/01 Delta.mp3   (songId 5)
    private let libraryPaths: [(id: String, path: String)] = [
        ("1", "Artist A/Album X/01 Alpha.mp3"),
        ("2", "Artist A/Album X/02 Bravo.mp3"),
        ("3", "Artist A/Album Y/01 Charlie.mp3"),
        ("4", "Artist A/Direct.mp3"),
        ("5", "Artist B/Album Z/01 Delta.mp3"),
    ]

    @discardableResult
    private func addFinishedDownload(serverId: Int = 1, songId: String, path: String, downloadedDate: Date? = nil, playedDate: Date? = nil, isPinned: Bool = false) -> DownloadedSong {
        let song = TestData.song(serverId: serverId, id: songId, title: "Song \(songId)", path: path)
        XCTAssertTrue(store.add(song: song))
        var downloadedSong = DownloadedSong(song: song)
        downloadedSong.isFinished = false
        downloadedSong.downloadedDate = downloadedDate
        downloadedSong.playedDate = playedDate
        downloadedSong.isPinned = isPinned
        XCTAssertTrue(store.add(downloadedSong: downloadedSong))
        // Marking the download finished also creates the path components
        XCTAssertTrue(store.update(downloadFinished: true, serverId: serverId, songId: songId))
        return downloadedSong
    }

    private func buildLibrary(serverId: Int = 1) {
        for entry in libraryPaths {
            addFinishedDownload(serverId: serverId, songId: entry.id, path: entry.path)
        }
    }

    private func pathComponents(serverId: Int, songId: String) throws -> [DownloadedSongPathComponent] {
        try store.pool.read { db in
            try DownloadedSongPathComponent
                .filter(literal: "serverId = \(serverId) AND songId = \(songId)")
                .order(DownloadedSongPathComponent.Column.level)
                .fetchAll(db)
        }
    }

    // MARK: DownloadedSong CRUD

    func testAddAndFetchDownloadedSong() throws {
        let song = TestData.song(serverId: 1, id: "10", path: "A/B/c.mp3")
        XCTAssertTrue(store.add(song: song))
        XCTAssertTrue(store.add(downloadedSong: DownloadedSong(song: song)))

        let fetched = try XCTUnwrap(store.downloadedSong(serverId: 1, songId: "10"))
        XCTAssertEqual(fetched.serverId, 1)
        XCTAssertEqual(fetched.songId, "10")
        XCTAssertEqual(fetched.path, "A/B/c.mp3")
        XCTAssertFalse(fetched.isFinished)
        XCTAssertFalse(fetched.isPinned)
        XCTAssertNil(store.downloadedSong(serverId: 2, songId: "10"), "downloadedSong must be scoped by serverId")
        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "11"))
    }

    func testUpdateDownloadFinishedCreatesPathComponents() throws {
        addFinishedDownload(songId: "1", path: "Artist A/Album X/01 Alpha.mp3")

        XCTAssertTrue(store.isDownloadFinished(serverId: 1, songId: "1"))

        let components = try pathComponents(serverId: 1, songId: "1")
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components.map(\.pathComponent), ["Artist A", "Album X", "01 Alpha.mp3"])
        XCTAssertEqual(components.map(\.level), [0, 1, 2])
        XCTAssertEqual(components.map(\.maxLevel), [2, 2, 2])
        XCTAssertEqual(components.map(\.parentPathComponent), [nil, "Artist A", "Album X"])
    }

    func testUpdatePlayedDateAndPinned() throws {
        addFinishedDownload(songId: "1", path: "Artist A/Album X/01 Alpha.mp3")

        let playedDate = Date(timeIntervalSince1970: 1_700_000_123)
        XCTAssertTrue(store.update(playedDate: playedDate, serverId: 1, songId: "1"))
        XCTAssertTrue(store.update(isPinned: true, serverId: 1, songId: "1"))

        let fetched = try XCTUnwrap(store.downloadedSong(serverId: 1, songId: "1"))
        XCTAssertEqual(fetched.playedDate?.timeIntervalSince1970 ?? 0, playedDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(fetched.isPinned)
    }

    func testIsDownloadFinishedFalseWhenMissingOrUnfinished() {
        XCTAssertFalse(store.isDownloadFinished(serverId: 1, songId: "404"))
        let song = TestData.song(serverId: 1, id: "10", path: "A/b.mp3")
        _ = store.add(song: song)
        _ = store.add(downloadedSong: DownloadedSong(song: song))
        XCTAssertFalse(store.isDownloadFinished(serverId: 1, songId: "10"))
    }

    func testDownloadedSongsCountOnlyCountsFinished() {
        buildLibrary()
        // An unfinished download shouldn't count
        let song = TestData.song(serverId: 1, id: "99", path: "Artist C/x.mp3")
        _ = store.add(song: song)
        _ = store.add(downloadedSong: DownloadedSong(song: song))

        XCTAssertEqual(store.downloadedSongsCount(), 5)
        XCTAssertEqual(store.downloadedSongsCount(serverId: 1), 5)
        XCTAssertEqual(store.downloadedSongsCount(serverId: 2), 0)
    }

    func testDeleteDownloadedSongCascadesPathComponents() throws {
        buildLibrary()
        XCTAssertTrue(store.deleteDownloadedSong(serverId: 1, songId: "1"))

        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "1"))
        XCTAssertEqual(try pathComponents(serverId: 1, songId: "1").count, 0)
        // Other songs untouched
        XCTAssertNotNil(store.downloadedSong(serverId: 1, songId: "2"))
        XCTAssertEqual(try pathComponents(serverId: 1, songId: "2").count, 3)
    }

    // MARK: Folder hierarchy queries

    func testDownloadedFolderArtists() {
        buildLibrary()
        let artists = store.downloadedFolderArtists(serverId: 1)
        XCTAssertEqual(artists.map(\.name), ["Artist A", "Artist B"])
        XCTAssertEqual(store.downloadedFolderArtists(serverId: 2).count, 0)
    }

    func testDownloadedFolderAlbums() {
        buildLibrary()
        // Albums inside "Artist A" are level-1 components that are not themselves files
        let albums = store.downloadedFolderAlbums(serverId: 1, level: 1, parentPathComponent: "Artist A")
        XCTAssertEqual(albums.map(\.name), ["Album X", "Album Y"])
        XCTAssertEqual(albums.map(\.level), [1, 1])
        XCTAssertEqual(store.downloadedFolderAlbumsCount(serverId: 1, level: 1, parentPathComponent: "Artist A"), 2)

        let artistB = store.downloadedFolderAlbums(serverId: 1, level: 1, parentPathComponent: "Artist B")
        XCTAssertEqual(artistB.map(\.name), ["Album Z"])
    }

    func testDownloadedFolderAlbumsCountForArtistModel() {
        buildLibrary()
        let artist = DownloadedFolderArtist(serverId: 1, name: "Artist A")
        XCTAssertEqual(store.downloadedFolderAlbumsCount(downloadedFolderArtist: artist), 2)
    }

    func testDownloadedSongsAtFolderLevel() {
        buildLibrary()
        // Songs directly inside "Artist A" (level 1 files): only Direct.mp3
        let directSongs = store.downloadedSongs(serverId: 1, level: 1, parentPathComponent: "Artist A")
        XCTAssertEqual(directSongs.map(\.songId), ["4"])
        XCTAssertEqual(store.downloadedSongsCount(serverId: 1, level: 1, parentPathComponent: "Artist A"), 1)

        // Songs inside "Album X" (level 2 files), ordered by path component
        let albumSongs = store.downloadedSongs(serverId: 1, level: 2, parentPathComponent: "Album X")
        XCTAssertEqual(albumSongs.map(\.songId), ["1", "2"])
    }

    // MARK: Tag-based queries

    private func buildTagLibrary() {
        let artist = TagArtist(serverId: 1, element: try! XMLTestHelpers.element(tag: "artist", xml: #"<artist id="ar1" name="Tag Artist" albumCount="2"/>"#))
        _ = store.add(tagArtist: artist, mediaFolderId: 0)
        let album1 = TagAlbum(serverId: 1, element: try! XMLTestHelpers.element(tag: "album", xml: #"<album id="al1" name="Tag Album One" artistId="ar1" songCount="2" duration="100" created="2024-02-24T15:31:22.978Z"/>"#))
        let album2 = TagAlbum(serverId: 1, element: try! XMLTestHelpers.element(tag: "album", xml: #"<album id="al2" name="Tag Album Two" artistId="ar1" songCount="1" duration="100" created="2024-02-24T15:31:22.978Z"/>"#))
        _ = store.add(tagAlbum: album1)
        _ = store.add(tagAlbum: album2)

        let songs = [
            TestData.song(serverId: 1, id: "t1", title: "Tag One", path: "TA/A1/t1.mp3", tagArtistId: "ar1", tagAlbumId: "al1", track: 1),
            TestData.song(serverId: 1, id: "t2", title: "Tag Two", path: "TA/A1/t2.mp3", tagArtistId: "ar1", tagAlbumId: "al1", track: 2),
            TestData.song(serverId: 1, id: "t3", title: "Tag Three", path: "TA/A2/t3.mp3", tagArtistId: "ar1", tagAlbumId: "al2", track: 1),
        ]
        for song in songs {
            XCTAssertTrue(store.add(song: song))
            var downloaded = DownloadedSong(song: song)
            downloaded.isFinished = true
            XCTAssertTrue(store.add(downloadedSong: downloaded))
        }
    }

    func testDownloadedTagArtistsAndAlbums() throws {
        buildTagLibrary()

        let artists = store.downloadedTagArtists(serverId: 1)
        XCTAssertEqual(artists.map(\.name), ["Tag Artist"])
        XCTAssertEqual(store.downloadedTagArtists(serverId: 2).count, 0)

        let artist = try XCTUnwrap(artists.first)
        let albums = store.downloadedTagAlbums(downloadedTagArtist: artist)
        XCTAssertEqual(albums.map(\.name), ["Tag Album One", "Tag Album Two"])
        XCTAssertEqual(store.downloadedTagAlbumsCount(downloadedTagArtist: artist), 2)
        XCTAssertEqual(store.downloadedTagAlbums(serverId: 1).count, 2)

        let album = try XCTUnwrap(albums.first)
        XCTAssertEqual(store.downloadedSongs(downloadedTagAlbum: album).map(\.songId), ["t1", "t2"])
        XCTAssertEqual(store.downloadedSongsCount(downloadedTagAlbum: album), 2)
        XCTAssertEqual(store.downloadedSongs(downloadedTagArtist: artist).count, 3)

        // Ordered by discNumber, track, title: t1 (track 1, "Tag One"), t3 (track 1,
        // "Tag Three"), t2 (track 2)
        XCTAssertEqual(store.songsRecursive(downloadedTagArtist: artist).map(\.id), ["t1", "t3", "t2"])
        XCTAssertEqual(store.songsRecursive(downloadedTagAlbum: album).map(\.id), ["t1", "t2"])
    }

    // MARK: Bulk deletion (BUG-18 regression: these used to nest reads inside writes)

    func testDeleteDownloadedSongsForTagArtist() throws {
        buildTagLibrary()
        let artist = try XCTUnwrap(store.downloadedTagArtists(serverId: 1).first)

        XCTAssertTrue(store.deleteDownloadedSongs(downloadedTagArtist: artist))

        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "t1"))
        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "t2"))
        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "t3"))
        XCTAssertEqual(store.downloadedTagArtists(serverId: 1).count, 0)
    }

    func testDeleteDownloadedSongsForTagAlbum() throws {
        buildTagLibrary()
        let artist = try XCTUnwrap(store.downloadedTagArtists(serverId: 1).first)
        let album = try XCTUnwrap(store.downloadedTagAlbums(downloadedTagArtist: artist).first)

        XCTAssertTrue(store.deleteDownloadedSongs(downloadedTagAlbum: album))

        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "t1"))
        XCTAssertNil(store.downloadedSong(serverId: 1, songId: "t2"))
        XCTAssertNotNil(store.downloadedSong(serverId: 1, songId: "t3"), "the artist's other album is untouched")
    }

    func testDeleteDownloadedSongsForTagAlbumRemovesFiles() throws {
        _ = store.add(server: TestData.server(id: 1))
        buildTagLibrary()
        let artist = try XCTUnwrap(store.downloadedTagArtists(serverId: 1).first)
        let album = try XCTUnwrap(store.downloadedTagAlbums(downloadedTagArtist: artist).first)

        // Put a real file at one of the album's song paths
        let song = try XCTUnwrap(store.song(serverId: 1, id: "t1"))
        try FileManager.default.createDirectory(atPath: (song.localPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: URL(fileURLWithPath: song.localPath))

        XCTAssertTrue(store.deleteDownloadedSongs(downloadedTagAlbum: album))

        XCTAssertFalse(FileManager.default.fileExists(atPath: song.localPath), "the downloaded file is removed with the record")
    }

    func testDeleteDownloadedSongsAtLevel() throws {
        buildLibrary(serverId: 1)
        addFinishedDownload(serverId: 2, songId: "other", path: "Other Artist/other.mp3")

        // Level 0 deletion removes every downloaded song for the server
        XCTAssertTrue(store.deleteDownloadedSongs(serverId: 1, level: 0))

        XCTAssertEqual(store.downloadedSongsCount(serverId: 1), 0)
        let remainingComponents = try store.pool.read { db in
            try DownloadedSongPathComponent.filter(literal: "serverId = 1").fetchCount(db)
        }
        XCTAssertEqual(remainingComponents, 0, "path components are removed with the songs")
        XCTAssertNotNil(store.downloadedSong(serverId: 2, songId: "other"), "other servers are untouched")
    }

    // MARK: Eviction queries

    func testOldestDownloadedSongByDownloadedDate() throws {
        addFinishedDownload(songId: "1", path: "A/1.mp3", downloadedDate: Date(timeIntervalSince1970: 3000))
        addFinishedDownload(songId: "2", path: "A/2.mp3", downloadedDate: Date(timeIntervalSince1970: 1000))
        addFinishedDownload(songId: "3", path: "A/3.mp3", downloadedDate: Date(timeIntervalSince1970: 2000))

        let oldest = try XCTUnwrap(store.oldestDownloadedSongByDownloadedDate())
        XCTAssertEqual(oldest.songId, "2")
    }

    func testOldestDownloadedSongByPlayedDate() throws {
        addFinishedDownload(songId: "1", path: "A/1.mp3", playedDate: Date(timeIntervalSince1970: 2000))
        addFinishedDownload(songId: "2", path: "A/2.mp3", playedDate: Date(timeIntervalSince1970: 5000))
        addFinishedDownload(songId: "3", path: "A/3.mp3", playedDate: Date(timeIntervalSince1970: 3000))

        let oldest = try XCTUnwrap(store.oldestDownloadedSongByPlayedDate())
        XCTAssertEqual(oldest.songId, "1")
    }

    func testEvictionQueriesExcludePinnedAndUnfinished() throws {
        addFinishedDownload(songId: "1", path: "A/1.mp3", downloadedDate: Date(timeIntervalSince1970: 1000), isPinned: true)
        addFinishedDownload(songId: "2", path: "A/2.mp3", downloadedDate: Date(timeIntervalSince1970: 2000))
        // Unfinished song with the oldest date
        let song = TestData.song(serverId: 1, id: "3", path: "A/3.mp3")
        _ = store.add(song: song)
        var unfinished = DownloadedSong(song: song)
        unfinished.downloadedDate = Date(timeIntervalSince1970: 1)
        _ = store.add(downloadedSong: unfinished)

        let oldest = try XCTUnwrap(store.oldestDownloadedSongByDownloadedDate())
        XCTAssertEqual(oldest.songId, "2", "pinned and unfinished songs must be excluded from eviction")
    }

    func testEvictionQueriesReturnNilWhenEmpty() {
        XCTAssertNil(store.oldestDownloadedSongByDownloadedDate())
        XCTAssertNil(store.oldestDownloadedSongByPlayedDate())
    }

    // MARK: Download queue

    func testAddToDownloadQueueAndOrdering() throws {
        let songA = TestData.song(serverId: 1, id: "1", title: "First", path: "A/1.mp3")
        let songB = TestData.song(serverId: 1, id: "2", title: "Second", path: "A/2.mp3")
        _ = store.add(song: songA)
        _ = store.add(song: songB)

        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "1"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "2"))

        XCTAssertEqual(store.downloadQueueCount(), 2)
        XCTAssertEqual(store.songFromDownloadQueue(position: 0)?.id, "1")
        XCTAssertEqual(store.songFromDownloadQueue(position: 1)?.id, "2")
        XCTAssertEqual(store.firstSongInDownloadQueue()?.id, "1")
        XCTAssertNil(store.songFromDownloadQueue(position: 2))
        XCTAssertNotNil(store.queuedDateForSongFromDownloadQueue(position: 0))
        XCTAssertTrue(store.isSongInDownloadQueue(song: songA))
    }

    func testAddToDownloadQueueIgnoresDuplicates() {
        _ = store.add(song: TestData.song(serverId: 1, id: "1", path: "A/1.mp3"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "1"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "1"))
        XCTAssertEqual(store.downloadQueueCount(), 1)
    }

    func testClearDownloadQueue() {
        _ = store.add(song: TestData.song(serverId: 1, id: "1", path: "A/1.mp3"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "1"))
        XCTAssertTrue(store.clearDownloadQueue())
        XCTAssertEqual(store.downloadQueueCount(), 0)
        XCTAssertNil(store.firstSongInDownloadQueue())
    }

    func testRemoveFromDownloadQueueForDefaultServer() {
        _ = store.add(song: TestData.song(serverId: 1, id: "1", path: "A/1.mp3"))
        _ = store.add(song: TestData.song(serverId: 1, id: "2", path: "A/2.mp3"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "1"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "2"))

        XCTAssertTrue(store.removeFromDownloadQueue(serverId: 1, songId: "1"))
        XCTAssertEqual(store.downloadQueueCount(), 1)
        XCTAssertEqual(store.firstSongInDownloadQueue()?.id, "2")
    }

    // MARK: Known-bug regression gates (BUG-06...BUG-09)

    func testBatchAddToDownloadQueue_BUG06() {
        // BUG-06 regression: the batch INSERT must insert (serverId, songId, queuedDate)
        // with balanced parentheses, mirroring the single-song variant
        _ = store.add(song: TestData.song(serverId: 1, id: "1", path: "A/1.mp3"))
        _ = store.add(song: TestData.song(serverId: 1, id: "2", path: "A/2.mp3"))
        _ = store.add(song: TestData.song(serverId: 1, id: "3", path: "A/3.mp3"))

        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songIds: ["1", "2", "3"]))
        XCTAssertEqual(store.downloadQueueCount(), 3)
        XCTAssertEqual(store.songFromDownloadQueue(position: 0)?.id, "1")
        XCTAssertNotNil(store.queuedDateForSongFromDownloadQueue(position: 2), "batch inserts must populate queuedDate")
    }

    func testRemoveFromDownloadQueueForOtherServer_BUG07() {
        // BUG-07 regression: the WHERE clause must match serverId AND songId directly
        // (the old parenthesization turned the right-hand side into a boolean, so
        // deletes only behaved for serverId == 1)
        _ = store.add(server: TestData.server(id: 1))
        _ = store.add(server: TestData.server(id: 2, urlString: "http://two.example.com"))
        _ = store.add(song: TestData.song(serverId: 1, id: "10", path: "A/10.mp3"))
        _ = store.add(song: TestData.song(serverId: 2, id: "10", path: "A/10.mp3"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 1, songId: "10"))
        XCTAssertTrue(store.addToDownloadQueue(serverId: 2, songId: "10"))

        store.removeFromDownloadQueue(serverId: 2, songId: "10")

        XCTAssertFalse(store.isSongInDownloadQueue(song: TestData.song(serverId: 2, id: "10", path: "A/10.mp3")), "server 2's row should be removed")
        XCTAssertTrue(store.isSongInDownloadQueue(song: TestData.song(serverId: 1, id: "10", path: "A/10.mp3")), "server 1's row should remain")
    }

    func testDownloadedSongsListIsScopedByServerId_BUG08() {
        // BUG-08 regression: downloadedSongs(serverId:) must only return the
        // requested server's downloads
        addFinishedDownload(serverId: 1, songId: "1", path: "A/1.mp3", downloadedDate: Date(timeIntervalSince1970: 1000))
        addFinishedDownload(serverId: 2, songId: "2", path: "B/2.mp3", downloadedDate: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(store.downloadedSongs(serverId: 1).map(\.songId), ["1"], "only server 1's downloads should be returned")
        XCTAssertEqual(store.downloadedSongs(serverId: 2).map(\.songId), ["2"], "only server 2's downloads should be returned")
        XCTAssertTrue(store.downloadedSongs(serverId: 3).isEmpty)
    }

    func testDownloadedSongsListOrdersByDownloadedDateDescending() {
        addFinishedDownload(serverId: 1, songId: "1", path: "A/1.mp3", downloadedDate: Date(timeIntervalSince1970: 1000))
        addFinishedDownload(serverId: 1, songId: "2", path: "A/2.mp3", downloadedDate: Date(timeIntervalSince1970: 3000))
        addFinishedDownload(serverId: 1, songId: "3", path: "A/3.mp3", downloadedDate: Date(timeIntervalSince1970: 2000))

        XCTAssertEqual(store.downloadedSongs(serverId: 1).map(\.songId), ["2", "3", "1"], "newest downloads come first")
    }

    func testSongsRecursiveIsScopedToParentPathComponent_BUG09() {
        // BUG-09 regression: songsRecursive must only return songs under the given
        // folder, not the whole library
        buildLibrary()

        // Recursing into "Artist A" should return its 4 songs, not Artist B's
        let artistSongs = store.songsRecursive(serverId: 1, level: 0, parentPathComponent: "Artist A")
        XCTAssertEqual(Set(artistSongs.map(\.id)), ["1", "2", "3", "4"], "songs under Artist B must be excluded")

        // Recursing into "Album X" should only return its 2 songs
        let albumSongs = store.songsRecursive(serverId: 1, level: 1, parentPathComponent: "Album X")
        XCTAssertEqual(Set(albumSongs.map(\.id)), ["1", "2"], "sibling folders must be excluded")

        // The typed helpers pass the folder's own level/name through
        let artist = DownloadedFolderArtist(serverId: 1, name: "Artist B")
        XCTAssertEqual(Set(store.songsRecursive(downloadedFolderArtist: artist).map(\.id)), ["5"])
        let album = DownloadedFolderAlbum(serverId: 1, level: 1, name: "Album Y", coverArtId: nil)
        XCTAssertEqual(Set(store.songsRecursive(downloadedFolderAlbum: album).map(\.id)), ["3"])
    }

    func testSongsRecursiveIsScopedByServerId() {
        buildLibrary(serverId: 1)
        XCTAssertEqual(store.songsRecursive(serverId: 2, level: 0, parentPathComponent: "Artist A").count, 0)
    }

    func testNonNumericSongIdsSurvivePathComponentJoins_BUG19() throws {
        // DownloadedSongPathComponent.songId (and DownloadedSong.path) join against TEXT
        // columns; they used to be declared INTEGER, whose affinity coerces values like
        // "0042" to 42 and breaks every join-based fetch (and truly non-numeric ids)
        addFinishedDownload(songId: "0042", path: "Artist A/Album X/03 Zulu.mp3")
        addFinishedDownload(songId: "tr-9f2c", path: "Artist A/Album X/04 Yankee.mp3")

        let fetched = try XCTUnwrap(store.downloadedSong(serverId: 1, songId: "0042"))
        XCTAssertEqual(fetched.path, "Artist A/Album X/03 Zulu.mp3", "the path column must store text losslessly")

        let albumSongs = store.songsRecursive(serverId: 1, level: 1, parentPathComponent: "Album X")
        XCTAssertEqual(Set(albumSongs.map(\.id)), ["0042", "tr-9f2c"], "join-based fetches must return non-numeric ids")

        // Songs directly inside the level-1 "Album X" folder are level-2 components
        let downloadedSongs = store.downloadedSongs(serverId: 1, level: 2, parentPathComponent: "Album X")
        XCTAssertEqual(Set(downloadedSongs.map(\.songId)), ["0042", "tr-9f2c"])
    }
}
