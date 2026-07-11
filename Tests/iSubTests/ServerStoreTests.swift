//
//  ServerStoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-03: CRUD tests for the server table
final class ServerStoreTests: StoreTestCase {
    func testNextServerIdOnEmptyTableIsOne() {
        XCTAssertEqual(store.nextServerId(), 1)
    }

    func testNextServerIdIsMaxPlusOne() {
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 7)))
        XCTAssertEqual(store.nextServerId(), 8)
    }

    func testAddAndFetchServerRoundTrip() throws {
        let server = TestData.server(id: 1, urlString: "https://music.example.com:8080/subsonic", username: "bbaron")
        XCTAssertTrue(store.add(server: server))

        let fetched = try XCTUnwrap(store.server(id: 1))
        XCTAssertEqual(fetched.id, 1)
        XCTAssertEqual(fetched.type, .subsonic)
        XCTAssertEqual(fetched.url.absoluteString, "https://music.example.com:8080/subsonic")
        XCTAssertEqual(fetched.username, "bbaron")
        XCTAssertEqual(fetched.password, "password")
        XCTAssertEqual(fetched.path, "https_music.example.com_8080_subsonic")
        XCTAssertTrue(fetched.isVideoSupported)
        XCTAssertTrue(fetched.isNewSearchSupported)
        XCTAssertTrue(fetched.isTagSearchSupported)
    }

    func testDetectedServerTypeRoundTrips() throws {
        // The new ServerType cases (Navidrome etc.) persist through the existing
        // Int-encoded type column with no migration
        let server = Server(id: 1, type: .navidrome, url: URL(string: "http://nd.example.com")!, username: "bbaron", password: "password")
        XCTAssertTrue(store.add(server: server))
        XCTAssertEqual(try XCTUnwrap(store.server(id: 1)).type, .navidrome)

        server.type = .openSubsonic
        XCTAssertTrue(store.add(server: server))
        XCTAssertEqual(try XCTUnwrap(store.server(id: 1)).type, .openSubsonic)
    }

    func testAddUpdatesExistingServer() throws {
        let server = TestData.server(id: 1)
        XCTAssertTrue(store.add(server: server))

        let updated = Server(id: 1, type: .subsonic, url: server.url, username: "other", password: "newpass",
                             path: server.path, isVideoSupported: false, isNewSearchSupported: false, isTagSearchSupported: false)
        XCTAssertTrue(store.add(server: updated))

        XCTAssertEqual(store.servers().count, 1)
        let fetched = try XCTUnwrap(store.server(id: 1))
        XCTAssertEqual(fetched.username, "other")
        XCTAssertFalse(fetched.isVideoSupported)
    }

    func testServersReturnsAllRows() {
        XCTAssertEqual(store.servers().count, 0)
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "http://other.example.com")))
        XCTAssertEqual(store.servers().map(\.id).sorted(), [1, 2])
    }

    func testFetchMissingServerReturnsNil() {
        XCTAssertNil(store.server(id: 99))
    }

    func testDeleteServerOnlyRemovesThatRow() {
        XCTAssertTrue(store.add(server: TestData.server(id: 1)))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "http://other.example.com")))

        XCTAssertTrue(store.deleteServer(id: 1))
        XCTAssertNil(store.server(id: 1))
        XCTAssertNotNil(store.server(id: 2))
    }

    // MARK: Cascade deletion (STUB-08)

    // Seeds representative serverId-scoped data for one server: song, downloads
    // (record + path components + queue row), server playlist with a song, play-queue
    // membership, bookmark with snapshot playlist, media folder, cover art, folder
    // artist, and a downloaded file on disk. Returns the seeded song.
    @discardableResult
    private func seedServerData(serverId: Int) throws -> Song {
        let song = TestData.song(serverId: serverId, id: "s\(serverId)", title: "Song \(serverId)", path: "Artist\(serverId)/Album/song.mp3")
        XCTAssertTrue(store.add(song: song))

        var downloadedSong = DownloadedSong(song: song)
        downloadedSong.downloadedDate = Date()
        XCTAssertTrue(store.add(downloadedSong: downloadedSong))
        try store.pool.write { db in
            try DownloadedSongPathComponent.addDownloadedSongPathComponents(db, downloadedSong: downloadedSong)
        }
        XCTAssertTrue(store.addToDownloadQueue(serverId: serverId, songId: song.id))

        let playlistXML = "<playlist id=\"77\" name=\"List\" owner=\"o\" public=\"false\" songCount=\"1\" duration=\"100\"/>"
        let serverPlaylist = ServerPlaylist(serverId: serverId, element: try XMLTestHelpers.element(tag: "playlist", xml: playlistXML))
        XCTAssertTrue(store.add(serverPlaylist: serverPlaylist))
        XCTAssertTrue(store.add(song: song, serverId: serverId, serverPlaylistId: 77))

        XCTAssertTrue(store.add(song: song, localPlaylistId: LocalPlaylist.Default.playQueueId))

        // Bookmark with its snapshot playlist (unique ids per server)
        try store.pool.write { db in
            let snapshot = LocalPlaylist(id: 100 + serverId, name: "Bookmark \(serverId)", isBookmark: true)
            try snapshot.save(db)
            try LocalPlaylist.insertSong(db, song: song, position: 0, playlistId: snapshot.id)
            try Bookmark(id: serverId, song: song, localPlaylist: snapshot, songIndex: 0, offsetInSeconds: 10, offsetInBytes: 100).save(db)
        }

        XCTAssertTrue(store.add(mediaFolders: [MediaFolder(serverId: serverId, id: 1, name: "Music")]))
        XCTAssertTrue(store.add(coverArt: CoverArt(serverId: serverId, id: "al-1", isLarge: false, data: Data([1, 2, 3]))))

        let folderArtist = FolderArtist(serverId: serverId, element: try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="9" name="Artist"/>"#))
        XCTAssertTrue(store.add(folderArtist: folderArtist, mediaFolderId: 1))

        // A downloaded file on disk under the server's downloads directory
        let fileURL = URL(fileURLWithPath: song.localPath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 10).write(to: fileURL)

        return song
    }

    private func count(table: String, where condition: String) throws -> Int {
        try store.pool.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table) WHERE \(condition)") ?? -1
        }
    }

    func testDeleteServerCascadesAllScopedDataAndFiles() throws {
        // Distinct URLs so each server gets its own downloads directory
        XCTAssertTrue(store.add(server: TestData.server(id: 1, urlString: "http://one.example.com")))
        XCTAssertTrue(store.add(server: TestData.server(id: 2, urlString: "http://two.example.com")))
        let song1 = try seedServerData(serverId: 1)
        let song2 = try seedServerData(serverId: 2)

        XCTAssertTrue(store.deleteServer(id: 1))

        // Every serverId-scoped table drops server 1 and keeps server 2
        let scopedTables = ["song", "downloadedSong", "downloadedSongPathComponent", "downloadQueue",
                            "serverPlaylist", "serverPlaylistSong", "localPlaylistSong",
                            "mediaFolder", "coverArt", "folderArtist", "folderArtistList"]
        for table in scopedTables {
            XCTAssertEqual(try count(table: table, where: "serverId = 1"), 0, "\(table) must drop server 1's rows")
            XCTAssertGreaterThan(try count(table: table, where: "serverId = 2"), 0, "\(table) must keep server 2's rows")
        }

        // Bookmarks and their snapshot playlists cascade too
        XCTAssertEqual(try count(table: "bookmark", where: "songServerId = 1"), 0)
        XCTAssertEqual(try count(table: "bookmark", where: "songServerId = 2"), 1)
        XCTAssertNil(store.localPlaylist(id: 101), "server 1's bookmark snapshot playlist must be deleted")
        XCTAssertNotNil(store.localPlaylist(id: 102), "server 2's bookmark snapshot playlist must remain")

        // The play queue closes the gap: server 2's song moves to position 0 and the count updates
        XCTAssertEqual(store.localPlaylist(id: LocalPlaylist.Default.playQueueId)?.songCount, 1)
        XCTAssertEqual(store.song(localPlaylistId: LocalPlaylist.Default.playQueueId, position: 0)?.id, song2.id)

        // Downloaded files: server 1's are gone, server 2's remain
        XCTAssertFalse(FileManager.default.fileExists(atPath: song1.localPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: song2.localPath))

        // And the server row itself
        XCTAssertNil(store.server(id: 1))
        XCTAssertNotNil(store.server(id: 2))
    }
}
