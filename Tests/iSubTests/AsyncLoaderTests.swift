//
//  AsyncLoaderTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
import UIKit
@testable import iSub_Beta

// COV-07: integration tests for every AsyncAPILoader subclass against the
// URLProtocol mock server and a real in-memory GRDB store — asserting both the
// returned values and the persisted rows, plus shared negative paths (Subsonic
// <error> bodies, non-XML responses, missing elements, and task cancellation)
// for all loaders. AsyncStatusLoader has its own suite (AsyncStatusLoaderTests).
class LoaderTestCase: StoreTestCase {
    let serverId = 1

    override func setUpWithError() throws {
        try super.setUpWithError()
        MockSubsonicServer.install()
        XCTAssertTrue(store.add(server: TestData.server(id: serverId, urlString: "https://mock.example.com")))
    }

    override func tearDownWithError() throws {
        MockSubsonicServer.uninstall()
        try super.tearDownWithError()
    }

    // A minimal valid empty response (no child elements)
    let emptyOkXML = #"<?xml version="1.0" encoding="UTF-8"?><subsonic-response xmlns="http://subsonic.org/restapi" status="ok" version="1.15.0"/>"#

    func stubEmptyOk(_ action: SubsonicAction) {
        MockSubsonicServer.stub(action, data: Data(emptyOkXML.utf8))
    }
}

final class AsyncLoaderTests: LoaderTestCase {
    // MARK: AsyncChatLoader

    func testChatLoaderParsesMessages() async throws {
        try MockSubsonicServer.stub(.getChatMessages, fixture: "XML/getChatMessages.xml")

        let messages = try await AsyncChatLoader(serverId: serverId).load()

        // The fixture is a real Subsonic response: newest message first, entities
        // decoded ("&amp;"), and a trailing space where the server stripped an emoji
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0].username, "bbaron")
        XCTAssertEqual(messages[0].message, "Hi there & welcome — enjoy the music ")
        XCTAssertEqual(messages[1].message, "Hello from iSub test suite")
    }

    func testChatLoaderAirsonicRemovedEndpointThrowsResponseNotXML() async throws {
        // Airsonic-Advanced removed the chat API entirely: it answers HTTP 410 with a
        // plain-text "No longer supported" body, which must surface as a graceful error
        let body = try Fixtures.data("XML/getChatMessages_airsonic_410.txt")
        MockSubsonicServer.stub(.getChatMessages, data: body, statusCode: 410, contentType: "text/plain;charset=UTF-8")

        do {
            _ = try await AsyncChatLoader(serverId: serverId).load()
            XCTFail("expected APIError.responseNotXML")
        } catch APIError.responseNotXML {
            // expected
        }
    }

    // MARK: AsyncChatSendLoader

    func testChatSendLoaderSendsMessageParameter() async throws {
        stubEmptyOk(.addChatMessage)

        try await AsyncChatSendLoader(serverId: serverId, message: "Hello there").load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .addChatMessage).first)
        XCTAssertEqual(received.parameter("message"), "Hello there")
    }

    func testChatSendLoaderAirsonicRemovedEndpointThrowsResponseNotXML() async throws {
        // Same Airsonic-Advanced HTTP 410 plain-text response as getChatMessages
        let body = try Fixtures.data("XML/getChatMessages_airsonic_410.txt")
        MockSubsonicServer.stub(.addChatMessage, data: body, statusCode: 410, contentType: "text/plain;charset=UTF-8")

        do {
            try await AsyncChatSendLoader(serverId: serverId, message: "Hello there").load()
            XCTFail("expected APIError.responseNotXML")
        } catch APIError.responseNotXML {
            // expected
        }
    }

    // MARK: AsyncServerPlaylistCreateLoader

    func testServerPlaylistCreateLoaderSendsNameAndOrderedSongIds() async throws {
        stubEmptyOk(.createPlaylist)

        try await AsyncServerPlaylistCreateLoader(serverId: serverId, name: "Road Trip", songIds: ["30", "10", "20"]).load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .createPlaylist).first)
        XCTAssertEqual(received.parameter("name"), "Road Trip")
        XCTAssertNil(received.parameter("playlistId"))
        XCTAssertEqual(received.parameters["songId"], ["30", "10", "20"], "songId order must match the playlist order")
    }

    func testServerPlaylistCreateLoaderOverwriteSendsPlaylistIdInsteadOfName() async throws {
        // Subsonic's createPlaylist duplicates when given an existing name, so an
        // overwrite must be keyed by playlistId only
        stubEmptyOk(.createPlaylist)

        try await AsyncServerPlaylistCreateLoader(serverId: serverId, name: "Road Trip", overwriteServerPlaylistId: 42, songIds: ["10"]).load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .createPlaylist).first)
        XCTAssertEqual(received.parameter("playlistId"), "42")
        XCTAssertNil(received.parameter("name"))
        XCTAssertEqual(received.parameters["songId"], ["10"])
    }

    func testServerPlaylistCreateLoaderSubsonicErrorThrows() async throws {
        try MockSubsonicServer.stub(.createPlaylist, fixture: "XML/error_data_not_found.xml")

        do {
            try await AsyncServerPlaylistCreateLoader(serverId: serverId, name: "Nope", songIds: ["10"]).load()
            XCTFail("expected SubsonicError")
        } catch is SubsonicError {
            // expected
        }
    }

    // MARK: AsyncServerPlaylistDeleteLoader

    func testServerPlaylistDeleteLoaderSendsId() async throws {
        stubEmptyOk(.deletePlaylist)

        try await AsyncServerPlaylistDeleteLoader(serverId: serverId, serverPlaylistId: 17).load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .deletePlaylist).first)
        XCTAssertEqual(received.parameter("id"), "17")
    }

    func testServerPlaylistDeleteLoaderSubsonicErrorThrows() async throws {
        // e.g. code 70 "Playlist not found"
        try MockSubsonicServer.stub(.deletePlaylist, fixture: "XML/error_data_not_found.xml")

        do {
            try await AsyncServerPlaylistDeleteLoader(serverId: serverId, serverPlaylistId: 9999).load()
            XCTFail("expected SubsonicError")
        } catch is SubsonicError {
            // expected
        }
    }

    // MARK: AsyncCoverArtLoader

    private func makePNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        return image.pngData()!
    }

    func testCoverArtLoaderReturnsImageData() async throws {
        let pngData = makePNGData()
        MockSubsonicServer.stub(.getCoverArt, data: pngData, contentType: "image/png")

        let coverArt = try await AsyncCoverArtLoader(serverId: serverId, coverArtId: "al-41", isLarge: false).load()

        XCTAssertEqual(coverArt.serverId, serverId)
        XCTAssertEqual(coverArt.id, "al-41")
        XCTAssertFalse(coverArt.isLarge)
        XCTAssertEqual(coverArt.data, pngData)
        XCTAssertNotNil(coverArt.image)

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getCoverArt).first)
        XCTAssertEqual(received.parameter("id"), "al-41")
        XCTAssertNotNil(received.parameter("size"))
    }

    func testCoverArtLoaderNonImageThrowsDataNotFound() async throws {
        // The cover art loader never parses XML, so even a Subsonic error body
        // surfaces as dataNotFound (the bytes aren't an image)
        try MockSubsonicServer.stub(.getCoverArt, fixture: "XML/error_data_not_found.xml")

        do {
            _ = try await AsyncCoverArtLoader(serverId: serverId, coverArtId: "nope", isLarge: true).load()
            XCTFail("expected APIError.dataNotFound")
        } catch APIError.dataNotFound {
            // expected
        }
    }

    // MARK: AsyncLyricsLoader

    func testLyricsLoaderParsesAndPersists() async throws {
        try MockSubsonicServer.stub(.getLyrics, fixture: "XML/getLyrics.xml")

        let lyrics = try await AsyncLyricsLoader(serverId: serverId, tagArtistName: "Beck", songTitle: "Loser").load()

        XCTAssertTrue(lyrics.lyricsText.contains("chimpanzees"))
        XCTAssertTrue(store.isLyricsCached(tagArtistName: "Beck", songTitle: "Loser"), "lyrics must be persisted")

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getLyrics).first)
        XCTAssertEqual(received.parameter("artist"), "Beck")
        XCTAssertEqual(received.parameter("title"), "Loser")
    }

    func testLyricsLoaderEmptyLyricsThrowsDataNotFound() async throws {
        try MockSubsonicServer.stub(.getLyrics, fixture: "XML/getLyrics_empty.xml")

        do {
            _ = try await AsyncLyricsLoader(serverId: serverId, tagArtistName: "a", songTitle: "t").load()
            XCTFail("expected APIError.dataNotFound")
        } catch APIError.dataNotFound {
            XCTAssertFalse(store.isLyricsCached(tagArtistName: "a", songTitle: "t"))
        }
    }

    func testLyricsLoaderSongInitializerRequiresArtistName() {
        XCTAssertNil(AsyncLyricsLoader(song: TestData.song(serverId: 1, id: "1", path: "a.mp3", tagArtistName: nil)))
        XCTAssertNotNil(AsyncLyricsLoader(song: TestData.song(serverId: 1, id: "1", path: "a.mp3", tagArtistName: "Beck")))
    }

    // MARK: AsyncMediaFoldersLoader

    func testMediaFoldersLoaderPrependsAllFoldersEntry() async throws {
        try MockSubsonicServer.stub(.getMusicFolders, fixture: "XML/getMusicFolders.xml")

        let mediaFolders = try await AsyncMediaFoldersLoader(serverId: serverId).load()

        XCTAssertEqual(mediaFolders.count, 3)
        XCTAssertEqual(mediaFolders[0].id, MediaFolder.allFoldersId)
        XCTAssertEqual(mediaFolders[0].name, "All Media Folders")
        XCTAssertEqual(mediaFolders[1].name, "Music")
        XCTAssertEqual(mediaFolders[2].name, "Podcasts")
    }

    // MARK: AsyncNowPlayingLoader

    func testNowPlayingLoaderParsesEntriesAndPersistsSongs() async throws {
        try MockSubsonicServer.stub(.getNowPlaying, fixture: "XML/getNowPlaying.xml")

        let nowPlaying = try await AsyncNowPlayingLoader(serverId: serverId).load()

        XCTAssertEqual(nowPlaying.count, 1)
        XCTAssertEqual(nowPlaying[0].songId, "376")
        XCTAssertEqual(nowPlaying[0].username, "bbaron")
        XCTAssertEqual(nowPlaying[0].playerName, "iSub")
        XCTAssertEqual(store.song(serverId: serverId, id: "376")?.title, "Going Crazy", "now playing songs must be persisted")
    }

    // MARK: AsyncQuickAlbumsLoader

    func testQuickAlbumsLoaderParsesAlbumsAndRequestParameters() async throws {
        try MockSubsonicServer.stub(.getAlbumList, fixture: "XML/getAlbumList_newest.xml")

        let albums = try await AsyncQuickAlbumsLoader(serverId: serverId, modifier: .newest, offset: 20).load()

        XCTAssertGreaterThan(albums.count, 0)
        XCTAssertEqual(albums[0].name, "[2011] Fear EP")

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getAlbumList).first)
        XCTAssertEqual(received.parameter("type"), "newest")
        XCTAssertEqual(received.parameter("size"), "20")
        XCTAssertEqual(received.parameter("offset"), "20")
    }

    func testQuickAlbumsLoaderSkipsAppleDoubleFolders() async throws {
        let xml = """
            <subsonic-response status="ok" version="1.15.0"><albumList>
            <album id="1" title="Real Album" created="2024-02-24T15:31:22.978Z"/>
            <album id="2" title=".AppleDouble" created="2024-02-24T15:31:22.978Z"/>
            </albumList></subsonic-response>
            """
        MockSubsonicServer.stub(.getAlbumList, data: Data(xml.utf8))

        let albums = try await AsyncQuickAlbumsLoader(serverId: serverId, modifier: .random).load()
        XCTAssertEqual(albums.map(\.name), ["Real Album"])
    }

    // MARK: AsyncRootFoldersLoader

    func testRootFoldersLoaderPersistsArtistsSectionsAndMetadata() async throws {
        try MockSubsonicServer.stub(.getIndexes, fixture: "XML/getIndexes.xml")

        let response = try await AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: 0).load()

        // The fixture contains 16 artists across 11 index sections
        XCTAssertEqual(response.artistIds.count, 16)
        XCTAssertEqual(response.tableSections.count, 11)
        XCTAssertEqual(response.metadata?.itemCount, 16)
        XCTAssertEqual(response.tableSections.map(\.itemCount).reduce(0, +), 16)

        // Rows actually landed in the store
        XCTAssertEqual(store.folderArtistIds(serverId: serverId, mediaFolderId: 0).count, 16)
        XCTAssertEqual(store.folderArtist(serverId: serverId, id: "219")?.name, "Beck")
        XCTAssertEqual(store.folderArtistSections(serverId: serverId, mediaFolderId: 0).count, 11)
        XCTAssertEqual(store.folderArtistMetadata(serverId: serverId, mediaFolderId: 0)?.itemCount, 16)
    }

    func testRootFoldersLoaderHandlesShortcutsAndSkipsAppleDouble() async throws {
        let xml = """
            <subsonic-response status="ok" version="1.15.0"><indexes>
            <shortcut id="s1" name="Podcasts"/>
            <index name="A"><artist id="1" name="Artist A"/><artist id="2" name=".AppleDouble"/></index>
            </indexes></subsonic-response>
            """
        MockSubsonicServer.stub(.getIndexes, data: Data(xml.utf8))

        let response = try await AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: 0).load()

        XCTAssertEqual(response.artistIds, ["s1", "1"], ".AppleDouble entries must be skipped")
        XCTAssertEqual(response.tableSections.map(\.name), ["*", "A"], "shortcuts get the * section")
        XCTAssertEqual(response.tableSections.map(\.itemCount), [1, 1])
        XCTAssertEqual(response.metadata?.itemCount, 2)
    }

    func testRootFoldersLoaderReplacesExistingCache() async throws {
        _ = store.add(folderArtist: FolderArtist(serverId: serverId, element: try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="old" name="Old"/>"#)), mediaFolderId: 0)
        try MockSubsonicServer.stub(.getIndexes, fixture: "XML/getIndexes.xml")

        _ = try await AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: 0).load()

        XCTAssertFalse(store.folderArtistIds(serverId: serverId, mediaFolderId: 0).contains("old"), "stale list rows must be deleted on reload")
    }

    func testRootFoldersLoaderSendsMusicFolderIdOnlyWhenSpecific() async throws {
        try MockSubsonicServer.stub(.getIndexes, fixture: "XML/getIndexes.xml")

        _ = try await AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: 5).load()
        _ = try await AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: MediaFolder.allFoldersId).load()

        let requests = MockSubsonicServer.receivedRequests(action: .getIndexes)
        XCTAssertEqual(requests[0].parameter("musicFolderId"), "5")
        XCTAssertNil(requests[1].parameter("musicFolderId"), "All Media Folders sends no musicFolderId")
    }

    // MARK: AsyncRootArtistsLoader

    func testRootArtistsLoaderPersistsTagArtistsSectionsAndMetadata() async throws {
        try MockSubsonicServer.stub(.getArtists, fixture: "XML/getArtists.xml")

        let response = try await AsyncRootArtistsLoader(serverId: serverId, mediaFolderId: 0).load()

        XCTAssertEqual(response.artistIds.count, 29)
        XCTAssertEqual(response.metadata?.itemCount, 29)
        XCTAssertEqual(response.tableSections.map(\.itemCount).reduce(0, +), 29)
        XCTAssertEqual(store.tagArtistIds(serverId: serverId, mediaFolderId: 0).count, 29)
        XCTAssertEqual(store.tagArtist(serverId: serverId, id: "52")?.name, "Amanda Blank")
        XCTAssertEqual(store.tagArtistMetadata(serverId: serverId, mediaFolderId: 0)?.itemCount, 29)
    }

    // MARK: AsyncSubfolderLoader

    func testSubfolderLoaderPersistsSubfoldersAndMetadata() async throws {
        // The album fixture contains two disc subfolders and no songs
        try MockSubsonicServer.stub(.getMusicDirectory, fixture: "XML/getMusicDirectory_album.xml")

        let response = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: "225").load()

        XCTAssertEqual(response.folderAlbumIds.count, 2)
        XCTAssertEqual(response.songIds.count, 0)
        XCTAssertEqual(response.folderMetadata?.folderCount, 2)
        XCTAssertEqual(response.folderMetadata?.songCount, 0)
        XCTAssertEqual(store.folderAlbumIds(serverId: serverId, parentFolderId: "225"), response.folderAlbumIds)
        XCTAssertTrue(store.isFolderMetadataCached(serverId: serverId, parentFolderId: "225"))

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getMusicDirectory).first)
        XCTAssertEqual(received.parameter("id"), "225")
    }

    func testSubfolderLoaderPersistsSongsAndMetadata() async throws {
        // The formats fixture contains two songs and no subfolders
        try MockSubsonicServer.stub(.getMusicDirectory, fixture: "XML/getMusicDirectory_formats.xml")

        let response = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: "900").load()

        XCTAssertEqual(response.songIds, ["9001", "9002"])
        XCTAssertEqual(response.folderAlbumIds.count, 0)
        XCTAssertEqual(response.folderMetadata?.songCount, 2)
        XCTAssertEqual(response.folderMetadata?.duration, 154)
        XCTAssertEqual(store.songIds(serverId: serverId, parentFolderId: "900"), ["9001", "9002"])
        XCTAssertEqual(store.song(serverId: serverId, id: "9001")?.suffix, "flac")
    }

    func testSubfolderLoaderSortsAlbumsAlphabetically() async throws {
        // Hack for Subsonic 4.7 breaking alphabetical order: albums re-sort by name
        let xml = """
            <subsonic-response status="ok" version="1.15.0"><directory id="1" name="Artist">
            <child id="10" parent="1" isDir="true" title="Zebra" created="2024-02-24T15:31:22.978Z"/>
            <child id="11" parent="1" isDir="true" title="apple" created="2024-02-24T15:31:22.978Z"/>
            <child id="12" parent="1" isDir="true" title="Mango" created="2024-02-24T15:31:22.978Z"/>
            </directory></subsonic-response>
            """
        MockSubsonicServer.stub(.getMusicDirectory, data: Data(xml.utf8))

        let response = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: "1").load()
        XCTAssertEqual(response.folderAlbumIds, ["11", "12", "10"], "albums must be sorted case-insensitively by name")
    }

    func testSubfolderLoaderFiltersVideosAndPDFs() async throws {
        let server = TestData.server(id: serverId, urlString: "https://mock.example.com")
        server.isVideoSupported = false
        XCTAssertTrue(store.add(server: server))

        let xml = """
            <subsonic-response status="ok" version="1.15.0"><directory id="1" name="Folder">
            <child id="10" parent="1" isDir="false" title="Song" path="a/song.mp3" suffix="mp3" duration="100"/>
            <child id="11" parent="1" isDir="false" title="Video" path="a/video.mkv" suffix="mkv" isVideo="true" duration="100"/>
            <child id="12" parent="1" isDir="false" title="Booklet" path="a/booklet.pdf" suffix="pdf"/>
            </directory></subsonic-response>
            """
        MockSubsonicServer.stub(.getMusicDirectory, data: Data(xml.utf8))

        let response = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: "1").load()

        XCTAssertEqual(response.songIds, ["10"], "videos (when unsupported) and PDFs must be filtered out")
        XCTAssertEqual(response.folderMetadata?.songCount, 1)
    }

    // MARK: AsyncTagArtistLoader

    func testTagArtistLoaderPersistsArtistAndAlbums() async throws {
        try MockSubsonicServer.stub(.getArtist, fixture: "XML/getArtist.xml")

        let albumIds = try await AsyncTagArtistLoader(serverId: serverId, tagArtistId: "52").load()

        XCTAssertGreaterThan(albumIds.count, 0)
        XCTAssertTrue(store.isTagArtistCached(serverId: serverId, id: "52"))
        for albumId in albumIds {
            XCTAssertTrue(store.isTagAlbumCached(serverId: serverId, id: albumId))
        }
        XCTAssertEqual(store.tagAlbumIds(serverId: serverId, tagArtistId: "52").sorted(), albumIds.sorted())

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getArtist).first)
        XCTAssertEqual(received.parameter("id"), "52")
    }

    // MARK: AsyncTagAlbumLoader

    func testTagAlbumLoaderPersistsAlbumAndSongs() async throws {
        try MockSubsonicServer.stub(.getAlbum, fixture: "XML/getAlbum.xml")

        let songIds = try await AsyncTagAlbumLoader(serverId: serverId, tagAlbumId: "41").load()

        XCTAssertEqual(songIds, ["353"])
        XCTAssertTrue(store.isTagAlbumCached(serverId: serverId, id: "41"))
        XCTAssertEqual(store.songIds(serverId: serverId, tagAlbumId: "41"), ["353"])
        XCTAssertEqual(store.song(serverId: serverId, id: "353")?.title, "Might Like You Better (Amtrac Remix)")
    }

    // MARK: AsyncSongLoader

    func testSongLoaderReturnsAndPersistsSong() async throws {
        let xml = """
            <subsonic-response status="ok" version="1.15.0">
            <song id="353" title="Might Like You Better" path="Amtrac/The Remixes/12.mp3" suffix="mp3" duration="206" bitRate="320" size="8484888"/>
            </subsonic-response>
            """
        MockSubsonicServer.stub(.getSong, data: Data(xml.utf8))

        let song = try await AsyncSongLoader(serverId: serverId, songId: "353").load()

        XCTAssertEqual(song.id, "353")
        XCTAssertEqual(song.title, "Might Like You Better")
        XCTAssertEqual(store.song(serverId: serverId, id: "353")?.title, "Might Like You Better")
    }

    // MARK: AsyncServerPlaylistsLoader

    func testServerPlaylistsLoaderPersistsPlaylists() async throws {
        try MockSubsonicServer.stub(.getPlaylists, fixture: "XML/getPlaylists.xml")

        let playlists = try await AsyncServerPlaylistsLoader(serverId: serverId).load()

        XCTAssertEqual(playlists.count, 1)
        XCTAssertEqual(playlists[0].name, "iSub Test Playlist")
        XCTAssertEqual(playlists[0].songCount, 2)
        XCTAssertEqual(store.serverPlaylist(serverId: serverId, id: 0)?.name, "iSub Test Playlist")
    }

    // MARK: AsyncServerPlaylistLoader

    func testServerPlaylistLoaderPersistsSongsAndLoadedCount() async throws {
        // The playlist row must exist (normally created by the playlists loader)
        try MockSubsonicServer.stub(.getPlaylists, fixture: "XML/getPlaylists.xml")
        _ = try await AsyncServerPlaylistsLoader(serverId: serverId).load()
        try MockSubsonicServer.stub(.getPlaylist, fixture: "XML/getPlaylist.xml")

        let playlist = try await AsyncServerPlaylistLoader(serverId: serverId, serverPlaylistId: 0).load()

        XCTAssertEqual(playlist.loadedSongCount, 2)
        XCTAssertTrue(playlist.isLoaded)
        XCTAssertEqual(store.songIds(serverId: serverId, serverPlaylistId: 0), ["376", "229"])
        XCTAssertEqual(store.song(serverId: serverId, serverPlaylistId: 0, position: 0)?.id, "376")
        XCTAssertEqual(store.song(serverId: serverId, id: "376")?.title, "Going Crazy")

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getPlaylist).first)
        XCTAssertEqual(received.parameter("id"), "0")
    }

    func testServerPlaylistLoaderReloadReplacesSongs() async throws {
        try MockSubsonicServer.stub(.getPlaylists, fixture: "XML/getPlaylists.xml")
        _ = try await AsyncServerPlaylistsLoader(serverId: serverId).load()
        try MockSubsonicServer.stub(.getPlaylist, fixture: "XML/getPlaylist.xml")

        _ = try await AsyncServerPlaylistLoader(serverId: serverId, serverPlaylistId: 0).load()
        let reloaded = try await AsyncServerPlaylistLoader(serverId: serverId, serverPlaylistId: 0).load()

        XCTAssertEqual(reloaded.loadedSongCount, 2, "reload must clear before inserting, not append")
        XCTAssertEqual(store.songIds(serverId: serverId, serverPlaylistId: 0).count, 2)
    }

    // MARK: AsyncServerShuffleLoader

    func testServerShuffleLoaderPersistsSongs() async throws {
        try MockSubsonicServer.stub(.getRandomSongs, fixture: "XML/getRandomSongs.xml")

        let songs = try await AsyncServerShuffleLoader(serverId: serverId, mediaFolderId: nil).load()

        XCTAssertGreaterThan(songs.count, 0)
        XCTAssertEqual(songs[0].id, "376")
        XCTAssertNotNil(store.song(serverId: serverId, id: "376"))

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getRandomSongs).first)
        XCTAssertEqual(received.parameter("size"), "100")
        XCTAssertNil(received.parameter("musicFolderId"))
    }

    func testServerShuffleLoaderSendsMediaFolderId() async throws {
        try MockSubsonicServer.stub(.getRandomSongs, fixture: "XML/getRandomSongs.xml")

        _ = try await AsyncServerShuffleLoader(serverId: serverId, mediaFolderId: 3).load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .getRandomSongs).first)
        XCTAssertEqual(received.parameter("musicFolderId"), "3")
    }

    // MARK: AsyncScrobbleLoader

    func testScrobbleLoaderSendsIdAndSubmission() async throws {
        stubEmptyOk(.scrobble)
        let song = TestData.song(serverId: serverId, id: "42", path: "a.mp3")

        try await AsyncScrobbleLoader(song: song, isSubmission: true).load()

        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .scrobble).first)
        XCTAssertEqual(received.parameter("id"), "42")
        XCTAssertEqual(received.parameter("submission"), "1")
    }
}

// MARK: - Search loader

final class AsyncSearchLoaderTests: LoaderTestCase {
    func testFolderSearchParsesAllResultTypes() async throws {
        try MockSubsonicServer.stub(.search2, fixture: "XML/search2.xml")

        let results = try await AsyncSearchLoader(serverId: serverId, searchType: .folder, searchItemType: .all, query: "beck").load()

        XCTAssertEqual(results.folderArtists.map(\.name), ["Beck"])
        XCTAssertGreaterThan(results.folderAlbums.count, 0)
        XCTAssertEqual(results.tagArtists.count, 0)
        XCTAssertEqual(results.tagAlbums.count, 0)
    }

    func testTagSearchParsesAllResultTypes() async throws {
        try MockSubsonicServer.stub(.search3, fixture: "XML/search3.xml")

        let results = try await AsyncSearchLoader(serverId: serverId, searchType: .tag, searchItemType: .all, query: "beck").load()

        XCTAssertEqual(results.tagArtists.map(\.name), ["Beck"])
        XCTAssertGreaterThan(results.tagAlbums.count, 0)
        XCTAssertGreaterThan(results.songs.count, 0)
        XCTAssertEqual(results.folderArtists.count, 0)
    }

    func testSearchAppendsWildcardForLatinQueries() async throws {
        try MockSubsonicServer.stub(.search2, fixture: "XML/search2.xml")

        _ = try await AsyncSearchLoader(serverId: serverId, searchType: .folder, query: "beck").load()
        _ = try await AsyncSearchLoader(serverId: serverId, searchType: .folder, query: "日本語").load()

        let requests = MockSubsonicServer.receivedRequests(action: .search2)
        XCTAssertEqual(requests[0].parameter("query"), "beck*", "Latin queries get a trailing wildcard")
        XCTAssertEqual(requests[1].parameter("query"), "日本語", "unicode queries must not get the wildcard")
    }

    func testSearchPagingParametersPerItemType() async throws {
        try MockSubsonicServer.stub(.search3, fixture: "XML/search3.xml")

        _ = try await AsyncSearchLoader(serverId: serverId, searchType: .tag, searchItemType: .all, query: "q", offset: 0).load()
        _ = try await AsyncSearchLoader(serverId: serverId, searchType: .tag, searchItemType: .songs, query: "q", offset: 40).load()
        _ = try await AsyncSearchLoader(serverId: serverId, searchType: .tag, searchItemType: .artists, query: "q", offset: 20).load()
        _ = try await AsyncSearchLoader(serverId: serverId, searchType: .tag, searchItemType: .albums, query: "q", offset: 60).load()

        let requests = MockSubsonicServer.receivedRequests(action: .search3)

        // .all pages every type together
        XCTAssertEqual(requests[0].parameter("artistCount"), "20")
        XCTAssertEqual(requests[0].parameter("albumCount"), "20")
        XCTAssertEqual(requests[0].parameter("songCount"), "20")

        // .songs pages only songs, zeroing the other counts
        XCTAssertEqual(requests[1].parameter("songCount"), "20")
        XCTAssertEqual(requests[1].parameter("songOffset"), "40")
        XCTAssertEqual(requests[1].parameter("artistCount"), "0")
        XCTAssertEqual(requests[1].parameter("albumCount"), "0")

        // .artists
        XCTAssertEqual(requests[2].parameter("artistCount"), "20")
        XCTAssertEqual(requests[2].parameter("artistOffset"), "20")
        XCTAssertEqual(requests[2].parameter("albumCount"), "0")

        // .albums
        XCTAssertEqual(requests[3].parameter("albumCount"), "20")
        XCTAssertEqual(requests[3].parameter("albumOffset"), "60")
        XCTAssertEqual(requests[3].parameter("songCount"), "0")
    }

    func testOldSearchUsesAnyKeyAndCountOffset() async throws {
        let xml = """
            <subsonic-response status="ok" version="1.15.0"><searchResult>
            <match id="1" title="Old Song" path="a/1.mp3" suffix="mp3"/>
            </searchResult></subsonic-response>
            """
        MockSubsonicServer.stub(.search, data: Data(xml.utf8))

        let results = try await AsyncSearchLoader(serverId: serverId, searchType: .old, searchItemType: .all, query: "old", offset: 20).load()

        XCTAssertEqual(results.songs.map(\.id), ["1"])
        let received = try XCTUnwrap(MockSubsonicServer.receivedRequests(action: .search).first)
        XCTAssertEqual(received.parameter("any"), "old", "old search uses the 'any' key with no wildcard")
        XCTAssertEqual(received.parameter("count"), "20")
        XCTAssertEqual(received.parameter("offset"), "20")
    }
}

// MARK: - Recursive song loader

final class AsyncRecursiveSongLoaderTests: LoaderTestCase {
    private var playQueue: PlayQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let freshSettings = SavedSettings()
        TestContainer.register { freshSettings }
        let freshPlayQueue = makeTestPlayQueue()
        TestContainer.register { freshPlayQueue }
        playQueue = freshPlayQueue
    }

    override func tearDownWithError() throws {
        playQueue = nil
        try super.tearDownWithError()
    }

    // Folder tree:
    //   root (id 100): song r1, subfolder 200
    //   sub  (id 200): songs s1, s2
    private func stubFolderTree() {
        MockSubsonicServer.stub(.getMusicDirectory) { received in
            switch received.parameter("id") {
            case "100":
                return MockSubsonicServer.xmlResponse("""
                    <subsonic-response status="ok" version="1.15.0"><directory id="100" name="Root">
                    <child id="200" parent="100" isDir="true" title="Sub" created="2024-02-24T15:31:22.978Z"/>
                    <child id="r1" parent="100" isDir="false" title="Root Song" path="Root/r1.mp3" suffix="mp3" duration="100"/>
                    </directory></subsonic-response>
                    """)
            case "200":
                return MockSubsonicServer.xmlResponse("""
                    <subsonic-response status="ok" version="1.15.0"><directory id="200" name="Sub">
                    <child id="s1" parent="200" isDir="false" title="Sub One" path="Root/Sub/s1.mp3" suffix="mp3" duration="100"/>
                    <child id="s2" parent="200" isDir="false" title="Sub Two" path="Root/Sub/s2.mp3" suffix="mp3" duration="100"/>
                    </directory></subsonic-response>
                    """)
            default:
                return MockSubsonicServer.xmlResponse(#"<subsonic-response status="failed" version="1.15.0"><error code="70" message="not found"/></subsonic-response>"#)
            }
        }
    }

    func testFolderRecursionQueuesAllSongsDepthFirst() async throws {
        stubFolderTree()

        try await AsyncRecursiveSongLoader.load(serverId: serverId, id: "100", idType: .folder, action: .queueAll)

        // Root's own songs queue first, then the subfolder's
        let queued = store.songs(localPlaylistId: LocalPlaylist.Default.playQueueId).map(\.id)
        XCTAssertEqual(queued, ["r1", "s1", "s2"])
    }

    func testTagArtistRecursionQueuesAllAlbumSongs() async throws {
        MockSubsonicServer.stub(.getArtist) { _ in
            MockSubsonicServer.xmlResponse("""
                <subsonic-response status="ok" version="1.15.0">
                <artist id="ar1" name="Artist" albumCount="2">
                <album id="al1" name="One" artistId="ar1" songCount="1" duration="100" created="2024-02-24T15:31:22.978Z"/>
                <album id="al2" name="Two" artistId="ar1" songCount="1" duration="100" created="2024-02-24T15:31:22.978Z"/>
                </artist></subsonic-response>
                """)
        }
        MockSubsonicServer.stub(.getAlbum) { received in
            let albumId = received.parameter("id") ?? ""
            return MockSubsonicServer.xmlResponse("""
                <subsonic-response status="ok" version="1.15.0">
                <album id="\(albumId)" name="Album \(albumId)" songCount="1" duration="100" created="2024-02-24T15:31:22.978Z">
                <song id="song-\(albumId)" title="Song" path="Artist/\(albumId)/song.mp3" suffix="mp3" duration="100" albumId="\(albumId)"/>
                </album></subsonic-response>
                """)
        }

        try await AsyncRecursiveSongLoader.load(serverId: serverId, id: "ar1", idType: .tagArtist, action: .queueAll)

        let queued = store.songs(localPlaylistId: LocalPlaylist.Default.playQueueId).map(\.id)
        XCTAssertEqual(queued, ["song-al1", "song-al2"], "albums must queue in order")
    }

    func testFolderRecursionDownloadAll_BUG06() async throws {
        // BUG-06 regression: downloadAll funnels into the batch addToDownloadQueue
        stubFolderTree()

        try await AsyncRecursiveSongLoader.load(serverId: serverId, id: "100", idType: .folder, action: .downloadAll)

        XCTAssertEqual(store.downloadQueueCount(), 3, "all recursively found songs should be queued for download")
    }

    func testFolderRecursionPropagatesErrors() async throws {
        MockSubsonicServer.stub(.getMusicDirectory) { _ in
            MockSubsonicServer.xmlResponse(#"<subsonic-response status="failed" version="1.15.0"><error code="0" message="boom"/></subsonic-response>"#)
        }

        do {
            try await AsyncRecursiveSongLoader.load(serverId: serverId, id: "100", idType: .folder, action: .queueAll)
            XCTFail("expected SubsonicError")
        } catch SubsonicError.generic {
            // expected
        }
    }
}

// MARK: - Shared negative paths for every loader

final class AsyncLoaderErrorTests: LoaderTestCase {
    private struct LoaderSpec {
        let name: String
        let action: SubsonicAction
        // Missing-element tag expected when the server returns an empty ok response,
        // or nil for loaders that only validate the root element
        let missingElementTag: String?
        let load: () async throws -> Void
    }

    private var specs = [LoaderSpec]()

    override func setUpWithError() throws {
        try super.setUpWithError()
        let serverId = self.serverId
        // The server playlist loader needs its playlist row to exist so that error
        // paths (which throw before touching the store) are what's actually tested
        _ = store.add(serverPlaylist: ServerPlaylist(serverId: serverId, element: try XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="0" name="p" songCount="1"/>"#)))

        specs = [
            LoaderSpec(name: "chat", action: .getChatMessages, missingElementTag: "chatMessages") { _ = try await AsyncChatLoader(serverId: serverId).load() },
            LoaderSpec(name: "chatSend", action: .addChatMessage, missingElementTag: nil) { try await AsyncChatSendLoader(serverId: serverId, message: "m").load() },
            LoaderSpec(name: "lyrics", action: .getLyrics, missingElementTag: "lyrics") { _ = try await AsyncLyricsLoader(serverId: serverId, tagArtistName: "a", songTitle: "t").load() },
            LoaderSpec(name: "mediaFolders", action: .getMusicFolders, missingElementTag: "musicFolders") { _ = try await AsyncMediaFoldersLoader(serverId: serverId).load() },
            LoaderSpec(name: "nowPlaying", action: .getNowPlaying, missingElementTag: "nowPlaying") { _ = try await AsyncNowPlayingLoader(serverId: serverId).load() },
            LoaderSpec(name: "quickAlbums", action: .getAlbumList, missingElementTag: "albumList") { _ = try await AsyncQuickAlbumsLoader(serverId: serverId, modifier: .newest).load() },
            LoaderSpec(name: "rootFolders", action: .getIndexes, missingElementTag: "indexes") { _ = try await AsyncRootFoldersLoader(serverId: serverId, mediaFolderId: 0).load() },
            LoaderSpec(name: "rootArtists", action: .getArtists, missingElementTag: "artists") { _ = try await AsyncRootArtistsLoader(serverId: serverId, mediaFolderId: 0).load() },
            LoaderSpec(name: "subfolder", action: .getMusicDirectory, missingElementTag: "directory") { _ = try await AsyncSubfolderLoader(serverId: serverId, parentFolderId: "1").load() },
            LoaderSpec(name: "tagArtist", action: .getArtist, missingElementTag: "artist") { _ = try await AsyncTagArtistLoader(serverId: serverId, tagArtistId: "1").load() },
            LoaderSpec(name: "tagAlbum", action: .getAlbum, missingElementTag: "album") { _ = try await AsyncTagAlbumLoader(serverId: serverId, tagAlbumId: "1").load() },
            LoaderSpec(name: "song", action: .getSong, missingElementTag: "song") { _ = try await AsyncSongLoader(serverId: serverId, songId: "1").load() },
            LoaderSpec(name: "serverPlaylists", action: .getPlaylists, missingElementTag: "playlists") { _ = try await AsyncServerPlaylistsLoader(serverId: serverId).load() },
            LoaderSpec(name: "serverPlaylist", action: .getPlaylist, missingElementTag: "playlist") { _ = try await AsyncServerPlaylistLoader(serverId: serverId, serverPlaylistId: 0).load() },
            LoaderSpec(name: "serverShuffle", action: .getRandomSongs, missingElementTag: nil) { _ = try await AsyncServerShuffleLoader(serverId: serverId).load() },
            LoaderSpec(name: "search", action: .search2, missingElementTag: nil) { _ = try await AsyncSearchLoader(serverId: serverId, searchType: .folder, query: "q").load() },
            LoaderSpec(name: "scrobble", action: .scrobble, missingElementTag: nil) { try await AsyncScrobbleLoader(song: TestData.song(serverId: serverId, id: "1", path: "a.mp3"), isSubmission: false).load() },
        ]
    }

    override func tearDownWithError() throws {
        specs = []
        try super.tearDownWithError()
    }

    func testSubsonicErrorBodyThrowsSubsonicError() async throws {
        for spec in specs {
            MockSubsonicServer.reset()
            try MockSubsonicServer.stub(spec.action, fixture: "XML/error_data_not_found.xml")
            do {
                try await spec.load()
                XCTFail("[\(spec.name)] expected SubsonicError.dataNotFound")
            } catch SubsonicError.dataNotFound {
                // expected
            } catch {
                XCTFail("[\(spec.name)] expected SubsonicError.dataNotFound, got \(error)")
            }
        }
    }

    func testNonXMLResponseThrowsResponseNotXML() async throws {
        for spec in specs {
            MockSubsonicServer.reset()
            try MockSubsonicServer.stub(spec.action, fixture: "XML/not_xml.txt")
            do {
                try await spec.load()
                XCTFail("[\(spec.name)] expected APIError.responseNotXML")
            } catch APIError.responseNotXML {
                // expected
            } catch {
                XCTFail("[\(spec.name)] expected APIError.responseNotXML, got \(error)")
            }
        }
    }

    func testMissingElementThrowsResponseMissingElement() async throws {
        for spec in specs where spec.missingElementTag != nil {
            MockSubsonicServer.reset()
            stubEmptyOk(spec.action)
            do {
                try await spec.load()
                XCTFail("[\(spec.name)] expected APIError.responseMissingElement")
            } catch APIError.responseMissingElement(_, let tag) {
                XCTAssertEqual(tag, spec.missingElementTag, "[\(spec.name)] wrong missing tag")
            } catch {
                XCTFail("[\(spec.name)] expected APIError.responseMissingElement, got \(error)")
            }
        }
    }

    func testCancellationThrowsBeforeWriting() async throws {
        for spec in specs {
            MockSubsonicServer.reset()
            stubEmptyOk(spec.action)
            let load = spec.load
            let task = Task { try await load() }
            task.cancel()
            do {
                _ = try await task.value
                XCTFail("[\(spec.name)] expected cancellation")
            } catch is CancellationError {
                // expected
            } catch let error as URLError where error.code == .cancelled {
                // also fine: cancelled inside URLSession
            } catch {
                XCTFail("[\(spec.name)] expected cancellation, got \(error)")
            }
        }
    }
}
