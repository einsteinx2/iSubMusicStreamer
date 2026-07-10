//
//  BrowseCacheStoreTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import GRDB
@testable import iSub_Beta

// COV-03: CRUD tests for the browse caches (media folders, folder artists/albums,
// tag artists/albums) and the blob stores (cover art, artist art, lyrics), plus the
// shared song table.
final class BrowseCacheStoreTests: StoreTestCase {
    // MARK: Song store

    func testSongRoundTripAndServerScoping() throws {
        let song = TestData.song(serverId: 1, id: "10", title: "Röund Trip — Song", path: "Ä/B/söng.mp3", transcodedSuffix: "opus", track: 3, discNumber: 2, starredDate: Date(timeIntervalSince1970: 1000))
        XCTAssertTrue(store.add(song: song))

        let fetched = try XCTUnwrap(store.song(serverId: 1, id: "10"))
        XCTAssertEqual(fetched.title, "Röund Trip — Song")
        XCTAssertEqual(fetched.path, "Ä/B/söng.mp3")
        XCTAssertEqual(fetched.transcodedSuffix, "opus")
        XCTAssertEqual(fetched.track, 3)
        XCTAssertEqual(fetched.discNumber, 2)
        XCTAssertNotNil(fetched.starredDate)

        XCTAssertNil(store.song(serverId: 2, id: "10"), "song lookups must be scoped by serverId")
        XCTAssertNil(store.song(serverId: 1, id: "11"))
    }

    func testSongAddIsUpsert() throws {
        _ = store.add(song: TestData.song(serverId: 1, id: "10", title: "Original", path: "a.mp3"))
        _ = store.add(song: TestData.song(serverId: 1, id: "10", title: "Updated", path: "a.mp3"))
        XCTAssertEqual(store.song(serverId: 1, id: "10")?.title, "Updated")
        let count = try store.pool.read { try Song.fetchCount($0) }
        XCTAssertEqual(count, 1)
    }

    // MARK: Media folders

    func testMediaFolderRoundTripAndDeletion() {
        XCTAssertEqual(store.mediaFolders(serverId: 1).count, 0)
        XCTAssertTrue(store.add(mediaFolders: [
            MediaFolder(serverId: 1, id: 0, name: "Music"),
            MediaFolder(serverId: 1, id: 1, name: "Podcasts"),
            MediaFolder(serverId: 2, id: 0, name: "Other Server"),
        ]))

        XCTAssertEqual(store.mediaFolders(serverId: 1).map(\.name).sorted(), ["Music", "Podcasts"])
        XCTAssertEqual(store.mediaFolders(serverId: 2).map(\.name), ["Other Server"])

        // deleteMediaFolders is global (used when reloading the list)
        XCTAssertTrue(store.deleteMediaFolders())
        XCTAssertEqual(store.mediaFolders(serverId: 1).count, 0)
        XCTAssertEqual(store.mediaFolders(serverId: 2).count, 0)
    }

    // MARK: Folder artists

    private func makeFolderArtist(serverId: Int = 1, id: String, name: String) -> FolderArtist {
        FolderArtist(serverId: serverId, element: try! XMLTestHelpers.element(tag: "artist", xml: "<artist id=\"\(id)\" name=\"\(name)\"/>"))
    }

    func testFolderArtistListRoundTrip() throws {
        XCTAssertTrue(store.add(folderArtist: makeFolderArtist(id: "1", name: "Beck"), mediaFolderId: 0))
        XCTAssertTrue(store.add(folderArtist: makeFolderArtist(id: "2", name: "Amtrac"), mediaFolderId: 0))
        XCTAssertTrue(store.add(folderArtist: makeFolderArtist(id: "3", name: "Elsewhere"), mediaFolderId: 5))

        // Insertion order is preserved (rowid order, not alphabetical)
        XCTAssertEqual(store.folderArtistIds(serverId: 1, mediaFolderId: 0), ["1", "2"])
        XCTAssertEqual(store.folderArtistIds(serverId: 1, mediaFolderId: 5), ["3"])
        XCTAssertEqual(store.folderArtistIds(serverId: 2, mediaFolderId: 0), [])

        let fetched = try XCTUnwrap(store.folderArtist(serverId: 1, id: "1"))
        XCTAssertEqual(fetched.name, "Beck")
        XCTAssertNil(store.folderArtist(serverId: 2, id: "1"))
    }

    func testFolderArtistSectionsAndMetadata() throws {
        let sections = [
            TableSection(serverId: 1, mediaFolderId: 0, name: "A", position: 0, itemCount: 2),
            TableSection(serverId: 1, mediaFolderId: 0, name: "B", position: 2, itemCount: 3),
        ]
        for section in sections {
            XCTAssertTrue(store.add(folderArtistSection: section))
        }
        XCTAssertEqual(store.folderArtistSections(serverId: 1, mediaFolderId: 0), sections)
        XCTAssertEqual(store.folderArtistSections(serverId: 1, mediaFolderId: 5).count, 0)

        let metadata = RootListMetadata(serverId: 1, mediaFolderId: 0, itemCount: 5, reloadDate: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertTrue(store.add(folderArtistListMetadata: metadata))
        let fetched = try XCTUnwrap(store.folderArtistMetadata(serverId: 1, mediaFolderId: 0))
        XCTAssertEqual(fetched.itemCount, 5)
        XCTAssertNil(store.folderArtistMetadata(serverId: 1, mediaFolderId: 5))
    }

    func testFolderArtistSearch() {
        _ = store.add(folderArtist: makeFolderArtist(id: "1", name: "The Beach Boys"), mediaFolderId: 0)
        _ = store.add(folderArtist: makeFolderArtist(id: "2", name: "Beck"), mediaFolderId: 0)
        _ = store.add(folderArtist: makeFolderArtist(id: "3", name: "Chromeo"), mediaFolderId: 0)

        XCTAssertEqual(store.search(folderArtistName: "bea", serverId: 1, mediaFolderId: 0, offset: 0, limit: 10), ["1"])
        XCTAssertEqual(store.search(folderArtistName: "b", serverId: 1, mediaFolderId: 0, offset: 0, limit: 10).count, 2)
        // Paging
        XCTAssertEqual(store.search(folderArtistName: "b", serverId: 1, mediaFolderId: 0, offset: 1, limit: 10).count, 1)
        XCTAssertEqual(store.search(folderArtistName: "zzz", serverId: 1, mediaFolderId: 0, offset: 0, limit: 10), [])
    }

    func testDeleteFolderArtistsClearsCachesForMediaFolder() {
        _ = store.add(folderArtist: makeFolderArtist(id: "1", name: "Beck"), mediaFolderId: 0)
        _ = store.add(folderArtist: makeFolderArtist(id: "2", name: "Other"), mediaFolderId: 5)
        _ = store.add(folderArtistSection: TableSection(serverId: 1, mediaFolderId: 0, name: "A", position: 0, itemCount: 1))
        _ = store.add(folderArtistListMetadata: RootListMetadata(serverId: 1, mediaFolderId: 0, itemCount: 1, reloadDate: Date()))

        XCTAssertTrue(store.deleteFolderArtists(serverId: 1, mediaFolderId: 0))

        XCTAssertEqual(store.folderArtistIds(serverId: 1, mediaFolderId: 0), [])
        XCTAssertEqual(store.folderArtistSections(serverId: 1, mediaFolderId: 0).count, 0)
        XCTAssertNil(store.folderArtistMetadata(serverId: 1, mediaFolderId: 0))
        // Other media folder untouched
        XCTAssertEqual(store.folderArtistIds(serverId: 1, mediaFolderId: 5), ["2"])
        // The shared artist record itself is not deleted
        XCTAssertNotNil(store.folderArtist(serverId: 1, id: "1"))
    }

    // MARK: Folder albums

    private func makeFolderAlbum(serverId: Int = 1, id: String, name: String, parentFolderId: String) -> FolderAlbum {
        FolderAlbum(serverId: serverId, element: try! XMLTestHelpers.element(tag: "child", xml: "<child id=\"\(id)\" title=\"\(name)\" parent=\"\(parentFolderId)\" created=\"2024-02-24T15:31:22.978Z\"/>"))
    }

    func testFolderAlbumListRoundTrip() throws {
        XCTAssertTrue(store.add(folderAlbum: makeFolderAlbum(id: "100", name: "Odelay", parentFolderId: "10")))
        XCTAssertTrue(store.add(folderAlbum: makeFolderAlbum(id: "101", name: "Midnite Vultures", parentFolderId: "10")))
        XCTAssertTrue(store.add(folderAlbum: makeFolderAlbum(id: "102", name: "Elsewhere", parentFolderId: "20")))

        XCTAssertEqual(store.folderAlbumIds(serverId: 1, parentFolderId: "10"), ["100", "101"])
        XCTAssertEqual(store.folderAlbumIds(serverId: 1, parentFolderId: "20"), ["102"])
        XCTAssertEqual(store.folderAlbumIds(serverId: 2, parentFolderId: "10"), [])

        let fetched = try XCTUnwrap(store.folderAlbum(serverId: 1, id: "100"))
        XCTAssertEqual(fetched.name, "Odelay")
    }

    func testFolderSongListRoundTrip() {
        let songA = TestData.song(serverId: 1, id: "1", title: "First", path: "a/1.mp3", parentFolderId: "10")
        let songB = TestData.song(serverId: 1, id: "2", title: "Second", path: "a/2.mp3", parentFolderId: "10")
        XCTAssertTrue(store.add(folderSong: songA))
        XCTAssertTrue(store.add(folderSong: songB))

        XCTAssertEqual(store.songIds(serverId: 1, parentFolderId: "10"), ["1", "2"])
        XCTAssertEqual(store.songIds(serverId: 1, parentFolderId: "20"), [])
        // The shared song row is saved too
        XCTAssertNotNil(store.song(serverId: 1, id: "1"))
    }

    func testAddFolderSongWithoutParentFolderIdFails() {
        let song = TestData.song(serverId: 1, id: "1", path: "a/1.mp3", parentFolderId: nil)
        XCTAssertFalse(store.add(folderSong: song))
    }

    func testResetFolderAlbumCache() {
        _ = store.add(folderAlbum: makeFolderAlbum(id: "100", name: "Odelay", parentFolderId: "10"))
        _ = store.add(folderSong: TestData.song(serverId: 1, id: "1", path: "a/1.mp3", parentFolderId: "10"))
        _ = store.add(folderAlbum: makeFolderAlbum(id: "102", name: "Elsewhere", parentFolderId: "20"))

        // Parent-scoped reset
        XCTAssertTrue(store.resetFolderAlbumCache(serverId: 1, parentFolderId: "10"))
        XCTAssertEqual(store.folderAlbumIds(serverId: 1, parentFolderId: "10"), [])
        XCTAssertEqual(store.songIds(serverId: 1, parentFolderId: "10"), [])
        XCTAssertEqual(store.folderAlbumIds(serverId: 1, parentFolderId: "20"), ["102"])

        // Server-wide reset
        XCTAssertTrue(store.resetFolderAlbumCache(serverId: 1))
        XCTAssertEqual(store.folderAlbumIds(serverId: 1, parentFolderId: "20"), [])
    }

    func testFolderMetadataRoundTrip() throws {
        let metadata = FolderMetadata(serverId: 1, parentFolderId: "10", folderCount: 2, songCount: 12, duration: 3600)
        XCTAssertFalse(store.isFolderMetadataCached(serverId: 1, parentFolderId: "10"))
        XCTAssertTrue(store.add(folderMetadata: metadata))
        XCTAssertTrue(store.isFolderMetadataCached(serverId: 1, parentFolderId: "10"))
        XCTAssertEqual(try XCTUnwrap(store.folderMetadata(serverId: 1, parentFolderId: "10")), metadata)
        XCTAssertNil(store.folderMetadata(serverId: 2, parentFolderId: "10"))
    }

    // MARK: Tag artists

    private func makeTagArtist(serverId: Int = 1, id: String, name: String, albumCount: Int = 1) -> TagArtist {
        TagArtist(serverId: serverId, element: try! XMLTestHelpers.element(tag: "artist", xml: "<artist id=\"\(id)\" name=\"\(name)\" albumCount=\"\(albumCount)\"/>"))
    }

    private func makeTagAlbum(serverId: Int = 1, id: String, name: String, tagArtistId: String, songCount: Int = 1) -> TagAlbum {
        TagAlbum(serverId: serverId, element: try! XMLTestHelpers.element(tag: "album", xml: "<album id=\"\(id)\" name=\"\(name)\" artistId=\"\(tagArtistId)\" songCount=\"\(songCount)\" duration=\"100\" created=\"2024-02-24T15:31:22.978Z\"/>"))
    }

    func testTagArtistListSectionsMetadataAndSearch() throws {
        XCTAssertTrue(store.add(tagArtist: makeTagArtist(id: "1", name: "Beck"), mediaFolderId: 0))
        XCTAssertTrue(store.add(tagArtist: makeTagArtist(id: "2", name: "The Beach Boys"), mediaFolderId: 0))

        XCTAssertTrue(store.isTagArtistCached(serverId: 1, id: "1"))
        XCTAssertFalse(store.isTagArtistCached(serverId: 2, id: "1"))
        XCTAssertEqual(store.tagArtistIds(serverId: 1, mediaFolderId: 0), ["1", "2"])
        XCTAssertEqual(try XCTUnwrap(store.tagArtist(serverId: 1, id: "2")).name, "The Beach Boys")

        XCTAssertTrue(store.add(tagArtistSection: TableSection(serverId: 1, mediaFolderId: 0, name: "B", position: 0, itemCount: 2)))
        XCTAssertEqual(store.tagArtistSections(serverId: 1, mediaFolderId: 0).count, 1)

        XCTAssertTrue(store.add(tagArtistListMetadata: RootListMetadata(serverId: 1, mediaFolderId: 0, itemCount: 2, reloadDate: Date())))
        XCTAssertEqual(store.tagArtistMetadata(serverId: 1, mediaFolderId: 0)?.itemCount, 2)

        XCTAssertEqual(store.search(tagArtistName: "beach", serverId: 1, mediaFolderId: 0, offset: 0, limit: 10), ["2"])
        XCTAssertEqual(store.search(tagArtistName: "b", serverId: 1, mediaFolderId: 0, offset: 0, limit: 10).count, 2)

        XCTAssertTrue(store.deleteTagArtists(serverId: 1, mediaFolderId: 0))
        XCTAssertEqual(store.tagArtistIds(serverId: 1, mediaFolderId: 0), [])
        XCTAssertNil(store.tagArtistMetadata(serverId: 1, mediaFolderId: 0))
        XCTAssertNotNil(store.tagArtist(serverId: 1, id: "1"), "shared artist record survives cache reset")
    }

    func testIsTagArtistAlbumsCached() {
        XCTAssertFalse(store.isTagArtistAlbumsCached(serverId: 1, id: "1"))
        _ = store.add(tagArtist: makeTagArtist(id: "1", name: "Beck", albumCount: 2), mediaFolderId: 0)
        XCTAssertFalse(store.isTagArtistAlbumsCached(serverId: 1, id: "1"))

        _ = store.add(tagAlbum: makeTagAlbum(id: "10", name: "One", tagArtistId: "1"))
        XCTAssertFalse(store.isTagArtistAlbumsCached(serverId: 1, id: "1"), "only 1 of 2 albums cached")
        _ = store.add(tagAlbum: makeTagAlbum(id: "11", name: "Two", tagArtistId: "1"))
        XCTAssertTrue(store.isTagArtistAlbumsCached(serverId: 1, id: "1"))
    }

    // MARK: Tag albums

    func testTagAlbumRoundTripAndOrdering() throws {
        XCTAssertTrue(store.add(tagAlbum: makeTagAlbum(id: "10", name: "Zebra", tagArtistId: "1")))
        XCTAssertTrue(store.add(tagAlbum: makeTagAlbum(id: "11", name: "Apple", tagArtistId: "1")))
        XCTAssertTrue(store.add(tagAlbum: makeTagAlbum(id: "12", name: "Other Artist", tagArtistId: "2")))

        XCTAssertTrue(store.isTagAlbumCached(serverId: 1, id: "10"))
        XCTAssertFalse(store.isTagAlbumCached(serverId: 2, id: "10"))
        XCTAssertEqual(try XCTUnwrap(store.tagAlbum(serverId: 1, id: "10")).name, "Zebra")

        // Ordered by name by default
        XCTAssertEqual(store.tagAlbumIds(serverId: 1, tagArtistId: "1"), ["11", "10"])
    }

    func testTagSongListRoundTrip() {
        _ = store.add(tagAlbum: makeTagAlbum(id: "10", name: "Album", tagArtistId: "1", songCount: 2))
        let songA = TestData.song(serverId: 1, id: "1", title: "First", path: "a/1.mp3", tagAlbumId: "10")
        let songB = TestData.song(serverId: 1, id: "2", title: "Second", path: "a/2.mp3", tagAlbumId: "10")

        XCTAssertFalse(store.isTagAlbumSongsCached(serverId: 1, id: "10"))
        XCTAssertTrue(store.add(tagSong: songA))
        XCTAssertFalse(store.isTagAlbumSongsCached(serverId: 1, id: "10"), "only 1 of 2 songs cached")
        XCTAssertTrue(store.add(tagSong: songB))
        XCTAssertTrue(store.isTagAlbumSongsCached(serverId: 1, id: "10"))

        XCTAssertEqual(store.songIds(serverId: 1, tagAlbumId: "10"), ["1", "2"])
        XCTAssertNotNil(store.song(serverId: 1, id: "1"))
    }

    func testTagSongListPreservesNonNumericSongIds_BUG19() {
        // tagSongList.songId used to be declared INTEGER, whose affinity coerces values
        // like "0042" to 42 (and non-numeric ids), losing the original song id
        _ = store.add(tagAlbum: makeTagAlbum(id: "10", name: "Album", tagArtistId: "1", songCount: 2))
        XCTAssertTrue(store.add(tagSong: TestData.song(serverId: 1, id: "0042", path: "a/1.mp3", tagAlbumId: "10")))
        XCTAssertTrue(store.add(tagSong: TestData.song(serverId: 1, id: "tr-9f2c", path: "a/2.mp3", tagAlbumId: "10")))

        XCTAssertEqual(store.songIds(serverId: 1, tagAlbumId: "10"), ["0042", "tr-9f2c"])
    }

    func testAddTagSongWithoutTagAlbumIdFails() {
        XCTAssertFalse(store.add(tagSong: TestData.song(serverId: 1, id: "1", path: "a/1.mp3", tagAlbumId: nil)))
    }

    func testDeleteTagAlbums() {
        _ = store.add(tagAlbum: makeTagAlbum(id: "10", name: "One", tagArtistId: "1"))
        _ = store.add(tagAlbum: makeTagAlbum(id: "11", name: "Two", tagArtistId: "2"))
        _ = store.add(tagAlbum: makeTagAlbum(serverId: 2, id: "10", name: "Other Server", tagArtistId: "1"))

        // Artist-scoped deletion
        XCTAssertTrue(store.deleteTagAlbums(serverId: 1, tagArtistId: "1"))
        XCTAssertFalse(store.isTagAlbumCached(serverId: 1, id: "10"))
        XCTAssertTrue(store.isTagAlbumCached(serverId: 1, id: "11"))

        // Server-scoped deletion leaves other servers alone
        XCTAssertTrue(store.deleteTagAlbums(serverId: 1))
        XCTAssertFalse(store.isTagAlbumCached(serverId: 1, id: "11"))
        XCTAssertTrue(store.isTagAlbumCached(serverId: 2, id: "10"))
    }

    // MARK: Cover art / artist art / lyrics blobs

    func testCoverArtRoundTrip() throws {
        let data = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03])
        let art = CoverArt(serverId: 1, id: "al-41", isLarge: false, data: data)
        XCTAssertFalse(store.isCoverArtCached(serverId: 1, id: "al-41", isLarge: false))
        XCTAssertTrue(store.add(coverArt: art))

        let fetched = try XCTUnwrap(store.coverArt(serverId: 1, id: "al-41", isLarge: false))
        XCTAssertEqual(fetched.data, data)
        XCTAssertTrue(store.isCoverArtCached(serverId: 1, id: "al-41", isLarge: false))
        // Size variants are cached separately
        XCTAssertNil(store.coverArt(serverId: 1, id: "al-41", isLarge: true))
        XCTAssertFalse(store.isCoverArtCached(serverId: 1, id: "al-41", isLarge: true))
        // Server scoping
        XCTAssertNil(store.coverArt(serverId: 2, id: "al-41", isLarge: false))

        XCTAssertTrue(store.resetCoverArtCache(serverId: 1))
        XCTAssertFalse(store.isCoverArtCached(serverId: 1, id: "al-41", isLarge: false))
    }

    func testArtistArtRoundTrip() throws {
        let data = Data("artist image bytes".utf8)
        let art = ArtistArt(serverId: 1, id: "ar-52", data: data)
        try store.pool.write { db in
            try art.save(db)
        }

        let fetched = try XCTUnwrap(store.artistArt(serverId: 1, id: "ar-52"))
        XCTAssertEqual(fetched.data, data)
        XCTAssertTrue(store.isArtistArtCached(serverId: 1, id: "ar-52"))
        XCTAssertNil(store.artistArt(serverId: 2, id: "ar-52"))

        XCTAssertTrue(store.resetArtistArtCache(serverId: 1))
        XCTAssertFalse(store.isArtistArtCached(serverId: 1, id: "ar-52"))
    }

    func testLyricsRoundTrip() throws {
        let element = try XMLTestHelpers.element(tag: "lyrics", xml: "<lyrics artist=\"Beck\" title=\"Loser\">Soy un perdedor</lyrics>")
        let lyrics = Lyrics(tagArtistName: "Beck", songTitle: "Loser", element: element)

        XCTAssertFalse(store.isLyricsCached(tagArtistName: "Beck", songTitle: "Loser"))
        XCTAssertTrue(store.add(lyrics: lyrics))
        XCTAssertTrue(store.isLyricsCached(tagArtistName: "Beck", songTitle: "Loser"))
        XCTAssertEqual(store.lyrics(tagArtistName: "Beck", songTitle: "Loser")?.lyricsText, "Soy un perdedor")
        XCTAssertEqual(store.lyricsText(tagArtistName: "Beck", songTitle: "Loser"), "Soy un perdedor")
        XCTAssertNil(store.lyrics(tagArtistName: "Beck", songTitle: "Other"))
    }

    func testIsLyricsCachedForSongRequiresArtistName() {
        let withArtist = TestData.song(serverId: 1, id: "1", title: "Loser", path: "a.mp3", tagArtistName: "Beck")
        let withoutArtist = TestData.song(serverId: 1, id: "2", title: "Loser", path: "b.mp3", tagArtistName: nil)
        _ = store.add(lyrics: Lyrics(tagArtistName: "Beck", songTitle: "Loser", element: try! XMLTestHelpers.element(tag: "lyrics", xml: "<lyrics>text</lyrics>")))

        XCTAssertTrue(store.isLyricsCached(song: withArtist))
        XCTAssertFalse(store.isLyricsCached(song: withoutArtist))
    }
}
