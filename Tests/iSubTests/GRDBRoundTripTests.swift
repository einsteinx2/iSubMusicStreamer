//
//  GRDBRoundTripTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-10: insert/fetch round-trips for every GRDB record with a real table, comparing
// the full JSON encoding (not just Equatable, which several models restrict to their
// ids) so any Codable/column mismatch that would silently lose persisted state is
// caught. Records without their own tables (TableSection, RootListMetadata, the
// Downloaded* browse hierarchy) are round-tripped through their store APIs in COV-03.
final class GRDBRoundTripTests: StoreTestCase {
    // Millisecond-precision dates survive GRDB's datetime string format
    private let date1 = Date(timeIntervalSince1970: 1_700_000_000.123)
    private let date2 = Date(timeIntervalSince1970: 1_710_000_000.456)

    private func json<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Encode dates as whole milliseconds: GRDB's datetime string format has
        // millisecond precision, and re-parsing can differ from the original double
        // by a ULP, which must not fail the comparison
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode((date.timeIntervalSince1970 * 1000).rounded())
        }
        return String(data: try encoder.encode(value), encoding: .utf8) ?? ""
    }

    // Saves the record, fetches it back, and compares the complete JSON encoding
    private func assertRoundTrip<T: Codable & FetchableRecord & MutablePersistableRecord>(_ record: T, fetch: @escaping (Database) throws -> T?, file: StaticString = #filePath, line: UInt = #line) throws {
        try store.pool.write { db in
            var record = record
            try record.save(db)
        }
        let fetched = try store.pool.read { db in
            try fetch(db)
        }
        let unwrapped = try XCTUnwrap(fetched, "record not found after insert", file: file, line: line)
        XCTAssertEqual(try json(record), try json(unwrapped), "fields lost or changed in the round trip", file: file, line: line)
    }

    func testServerRoundTrip() throws {
        let server = Server(id: 3, type: .subsonic, url: URL(string: "https://music.example.com:8080/subsonic")!,
                            username: "bbaron", password: "sécret", path: "https_music.example.com_8080_subsonic",
                            isVideoSupported: false, isNewSearchSupported: true, isTagSearchSupported: false)
        try assertRoundTrip(server) { try Server.fetchOne($0, key: 3) }
    }

    func testSongRoundTripAllFields() throws {
        let song = TestData.song(serverId: 2, id: "abc-42", title: "Sigur Rós — Song", path: "Ä/B/söng.mp3",
                                 tagArtistId: "ar1", tagAlbumId: "al1", tagArtistName: "Artist", tagAlbumName: "Album",
                                 parentFolderId: "p9", coverArtId: "ca7", suffix: "flac", transcodedSuffix: "opus",
                                 duration: 321, kiloBitrate: 999, track: 7, discNumber: 2, size: 123_456_789,
                                 isVideo: true, createdDate: date1, starredDate: date2)
        try assertRoundTrip(song) { try Song.filter(literal: "serverId = 2 AND id = 'abc-42'").fetchOne($0) }
    }

    func testSongRoundTripNilOptionals() throws {
        let song = TestData.song(serverId: 1, id: "1", tagArtistName: nil, tagAlbumName: nil)
        try assertRoundTrip(song) { try Song.filter(literal: "serverId = 1 AND id = '1'").fetchOne($0) }
    }

    func testTagArtistRoundTrip() throws {
        let artist = TagArtist(serverId: 1, element: try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="ar1" name="Ärtist" coverArt="ca1" artistImageUrl="http://x.com/img.jpg" albumCount="4" starred="2024-02-24T15:31:22.978Z"/>"#))
        try assertRoundTrip(artist) { try TagArtist.filter(literal: "serverId = 1 AND id = 'ar1'").fetchOne($0) }
    }

    func testTagAlbumRoundTrip() throws {
        let album = TagAlbum(serverId: 1, element: try XMLTestHelpers.element(tag: "album", xml: #"<album id="al1" name="Albüm" coverArt="ca2" artistId="ar1" artist="Ärtist" songCount="12" duration="3600" playCount="3" year="1996" genre="Rock" created="2024-02-24T15:31:22.978Z" starred="2024-03-01T10:00:00.000Z"/>"#))
        try assertRoundTrip(album) { try TagAlbum.filter(literal: "serverId = 1 AND id = 'al1'").fetchOne($0) }
    }

    func testFolderArtistRoundTrip() throws {
        let artist = FolderArtist(serverId: 1, element: try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="f1" name="Földer Artist" userRating="4" averageRating="3.5" starred="2024-02-24T15:31:22.978Z"/>"#))
        try assertRoundTrip(artist) { try FolderArtist.filter(literal: "serverId = 1 AND id = 'f1'").fetchOne($0) }
    }

    func testFolderAlbumRoundTrip() throws {
        let album = FolderAlbum(serverId: 1, element: try XMLTestHelpers.element(tag: "child", xml: #"<child id="fa1" parent="p1" title="Ölbum" artist="Ärtist" coverArt="ca3" playCount="9" year="2001" genre="Pop" userRating="5" averageRating="4.5" created="2024-02-24T15:31:22.978Z" starred="2024-03-01T10:00:00.000Z"/>"#))
        try assertRoundTrip(album) { try FolderAlbum.filter(literal: "serverId = 1 AND id = 'fa1'").fetchOne($0) }
    }

    func testMediaFolderRoundTrip() throws {
        let folder = MediaFolder(serverId: 4, id: 2, name: "Müsic")
        try assertRoundTrip(folder) { try MediaFolder.filter(literal: "serverId = 4 AND id = 2").fetchOne($0) }
    }

    func testLyricsRoundTrip() throws {
        let lyrics = Lyrics(tagArtistName: "Béck", songTitle: "Löser", element: try XMLTestHelpers.element(tag: "lyrics", xml: "<lyrics>Soy un perdedor\nI'm a loser baby 🎵</lyrics>"))
        try assertRoundTrip(lyrics) { try Lyrics.filter(literal: "tagArtistName = 'Béck'").fetchOne($0) }
    }

    func testCoverArtRoundTrip() throws {
        let art = CoverArt(serverId: 1, id: "al-1", isLarge: true, data: Data([0x00, 0x01, 0xFF, 0xFE, 0x7F]))
        try assertRoundTrip(art) { try CoverArt.filter(literal: "serverId = 1 AND id = 'al-1' AND isLarge = 1").fetchOne($0) }
    }

    func testArtistArtRoundTrip() throws {
        let art = ArtistArt(serverId: 1, id: "ar-1", data: Data("artist art bytes".utf8))
        try assertRoundTrip(art) { try ArtistArt.filter(literal: "serverId = 1 AND id = 'ar-1'").fetchOne($0) }
    }

    func testFolderMetadataRoundTrip() throws {
        let metadata = FolderMetadata(serverId: 1, parentFolderId: "pf1", folderCount: 3, songCount: 14, duration: 5000)
        try assertRoundTrip(metadata) { try FolderMetadata.filter(literal: "serverId = 1 AND parentFolderId = 'pf1'").fetchOne($0) }
    }

    func testDownloadedSongRoundTrip() throws {
        var downloadedSong = DownloadedSong(song: TestData.song(serverId: 1, id: "ds1", path: "Ärtist/Älbum/söng.mp3"))
        downloadedSong.isFinished = true
        downloadedSong.isPinned = true
        downloadedSong.size = 987_654
        downloadedSong.downloadedDate = date1
        downloadedSong.playedDate = date2
        try assertRoundTrip(downloadedSong) { try DownloadedSong.filter(literal: "serverId = 1 AND songId = 'ds1'").fetchOne($0) }
    }

    func testDownloadedSongRoundTripNilDates() throws {
        let downloadedSong = DownloadedSong(song: TestData.song(serverId: 1, id: "ds2", path: "A/b.mp3"))
        try assertRoundTrip(downloadedSong) { try DownloadedSong.filter(literal: "serverId = 1 AND songId = 'ds2'").fetchOne($0) }
    }

    func testDownloadedSongPathComponentRoundTrip() throws {
        let component = DownloadedSongPathComponent(level: 1, maxLevel: 2, pathComponent: "Älbum", parentPathComponent: "Ärtist", serverId: 1, songId: "ds1")
        try assertRoundTrip(component) { try DownloadedSongPathComponent.filter(literal: "serverId = 1 AND songId = 'ds1'").fetchOne($0) }
    }

    func testDownloadedSongPathComponentRoundTripNilParent() throws {
        let component = DownloadedSongPathComponent(level: 0, maxLevel: 2, pathComponent: "Ärtist", parentPathComponent: nil, serverId: 1, songId: "ds3")
        try assertRoundTrip(component) { try DownloadedSongPathComponent.filter(literal: "serverId = 1 AND songId = 'ds3'").fetchOne($0) }
    }

    func testLocalPlaylistRoundTrip() throws {
        let playlist = LocalPlaylist(id: 42, name: "Röad Trip 🎵", songCount: 7, isBookmark: true, createdDate: date1)
        try assertRoundTrip(playlist) { try LocalPlaylist.fetchOne($0, key: 42) }
    }

    func testServerPlaylistRoundTrip() throws {
        var playlist = ServerPlaylist(serverId: 1, element: try XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="17" name="Plàylist" comment="çomment" owner="öwner" public="true" songCount="25" duration="5000" coverArt="pl-17" created="2024-02-24T15:31:22.978Z" changed="2024-03-01T10:00:00.000Z"/>"#))
        playlist.loadedSongCount = 10
        try assertRoundTrip(playlist) { try ServerPlaylist.filter(literal: "serverId = 1 AND id = 17").fetchOne($0) }
    }

    func testServerPlaylistRoundTripNilOptionals() throws {
        let playlist = ServerPlaylist(serverId: 1, element: try XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="18" name="Bare"/>"#))
        try assertRoundTrip(playlist) { try ServerPlaylist.filter(literal: "serverId = 1 AND id = 18").fetchOne($0) }
    }

    func testBookmarkRoundTrip() throws {
        let song = TestData.song(serverId: 1, id: "bk-song", path: "a/b.mp3")
        let playlist = LocalPlaylist(id: 50, name: "Snapshot", isBookmark: true)
        let bookmark = Bookmark(id: 9, song: song, localPlaylist: playlist, songIndex: 3, offsetInSeconds: 123.456, offsetInBytes: 987_654_321)
        try assertRoundTrip(bookmark) { try Bookmark.fetchOne($0, key: 9) }
    }
}
