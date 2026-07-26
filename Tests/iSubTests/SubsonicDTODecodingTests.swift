//
//  SubsonicDTODecodingTests.swift
//  iSubTests
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// Decodes the JSON fixture corpus (Fixtures/JSON/, generated from the captured XML
// corpus — see Fixtures/README.md) into the Codable DTO layer and asserts key fields.
// The XML decoder's parity suite asserts that the XML fixtures produce equal DTOs.
final class SubsonicDTODecodingTests: XCTestCase {
    private func decode(_ fixture: String) throws -> SubsonicResponse {
        try SubsonicJSON.decode(SubsonicEnvelope.self, from: Fixtures.data("JSON/\(fixture).json")).response
    }

    // MARK: Ping

    func testPingSuccess() throws {
        let response = try decode("ping_success")
        XCTAssertEqual(response.status, "ok")
        XCTAssertEqual(response.version, "1.15.0")
        XCTAssertEqual(response.type, "Airsonic-Advanced")
        XCTAssertNil(response.error)
        XCTAssertNil(response.openSubsonic)
    }

    func testPingNavidrome() throws {
        let response = try decode("ping_navidrome")
        XCTAssertEqual(response.type, "navidrome")
        XCTAssertEqual(response.serverVersion, "0.52.5 (734eb30a)")
        XCTAssertEqual(response.openSubsonic, true)
    }

    func testPingWrongCredentialsError() throws {
        let response = try decode("ping_error_wrong_credentials")
        XCTAssertEqual(response.status, "failed")
        XCTAssertEqual(response.error?.code, 40)
        XCTAssertEqual(response.error?.message, "Wrong username or password.")
    }

    // MARK: Browsing (folder hierarchy)

    func testGetIndexes() throws {
        let indexes = try XCTUnwrap(decode("getIndexes").indexes)
        XCTAssertEqual(indexes.ignoredArticles, "The El La Los Las Le Les")
        XCTAssertEqual(indexes.index?.values.count, 11)
        XCTAssertEqual(indexes.index?.values.first?.name, "A")
        XCTAssertEqual(indexes.index?.values.first?.artist?.values.first?.id.value, "221")
        XCTAssertEqual(indexes.index?.values.first?.artist?.values.first?.name, "ALAC")
        // Loose media file at the music folder root
        XCTAssertEqual(indexes.child?.values.count, 1)
        XCTAssertEqual(indexes.child?.values.first?.title, "Me Against The World")
        XCTAssertNil(indexes.shortcut)
    }

    func testGetMusicDirectory() throws {
        let directory = try XCTUnwrap(decode("getMusicDirectory_album").directory)
        XCTAssertEqual(directory.id?.value, "225")
        XCTAssertEqual(directory.name, "Odeley")
        XCTAssertEqual(directory.child?.values.count, 2)
        let disc1 = try XCTUnwrap(directory.child?.values.first)
        XCTAssertEqual(disc1.isDir, true)
        XCTAssertEqual(disc1.title, "Disc 1")
        XCTAssertEqual(disc1.album, "Odelay (Deluxe Edition)")
        XCTAssertEqual(disc1.year, 2008)
        XCTAssertEqual(disc1.playCount, 18)
    }

    func testGetMusicDirectorySongFields() throws {
        let directory = try XCTUnwrap(decode("getMusicDirectory_formats").directory)
        let flac = try XCTUnwrap(directory.child?.values.first)
        XCTAssertEqual(flac.id.value, "9001")
        XCTAssertEqual(flac.parent?.value, "900")
        XCTAssertEqual(flac.isDir, false)
        XCTAssertEqual(flac.suffix, "flac")
        XCTAssertEqual(flac.size, 356827)
        XCTAssertEqual(flac.bitRate, 285)
        XCTAssertEqual(flac.duration, 10)
        XCTAssertEqual(flac.path, "Formats/tone.flac")
        XCTAssertEqual(flac.isVideo, false)
        XCTAssertEqual(flac.created, SubsonicDateParsing.date(from: "2026-07-09T00:00:00.000Z"))
    }

    // MARK: Browsing (ID3 hierarchy)

    func testGetArtists() throws {
        let artists = try XCTUnwrap(decode("getArtists").artists)
        XCTAssertEqual(artists.index?.values.count, 17)
        let amanda = try XCTUnwrap(artists.index?.values.first?.artist?.values.first)
        XCTAssertEqual(amanda.id.value, "52")
        XCTAssertEqual(amanda.name, "Amanda Blank")
        XCTAssertEqual(amanda.coverArt?.value, "ar-52")
        XCTAssertEqual(amanda.albumCount, 1)
    }

    func testGetArtist() throws {
        let artist = try XCTUnwrap(decode("getArtist").artist)
        XCTAssertEqual(artist.id.value, "52")
        XCTAssertEqual(artist.name, "Amanda Blank")
        XCTAssertEqual(artist.album?.values.count, 1)
        XCTAssertEqual(artist.album?.values.first?.id.value, "41")
        XCTAssertEqual(artist.album?.values.first?.songCount, 1)
    }

    func testGetAlbum() throws {
        let album = try XCTUnwrap(decode("getAlbum").album)
        XCTAssertEqual(album.id.value, "41")
        XCTAssertEqual(album.name, "The Remixes")
        XCTAssertEqual(album.artist, "Amanda Blank")
        XCTAssertEqual(album.artistId?.value, "52")
        XCTAssertEqual(album.song?.values.count, 1)
        XCTAssertEqual(album.song?.values.first?.title, "Might Like You Better (Amtrac Remix)")
        XCTAssertEqual(album.song?.values.first?.playCount, 19)
    }

    // Real f=json capture from a live Navidrome server (0.63.2): OpenSubsonic extras
    // (genres, artists, replayGain, ...) must be ignored, string ids pass through, and
    // nanosecond-precision created dates parse to the correct instant (truncated to
    // millisecond precision, not misread as a larger unit).
    func testGetAlbumNavidromeRealCapture() throws {
        let album = try XCTUnwrap(decode("getAlbum_navidrome").album)
        XCTAssertEqual(album.id.value, "7oli7U18zDNKQoRSCrQUVK")
        XCTAssertEqual(album.name, "Me Against The World")
        XCTAssertEqual(album.artist, "2Pac")
        XCTAssertEqual(album.artistId?.value, "1ZHez3tEDSdaETpth5Q8Lm")
        XCTAssertEqual(album.songCount, 7)
        XCTAssertEqual(album.year, 1995)
        XCTAssertEqual(album.genre, "Rap")
        // "2026-07-11T19:39:55.981744906Z"
        let created = try XCTUnwrap(album.created)
        XCTAssertEqual(created.timeIntervalSince1970, 1783798795.981, accuracy: 0.001)

        let song = try XCTUnwrap(album.song?.values.first)
        XCTAssertEqual(song.id.value, "bY6Zl0uULHVEFtIHmDBY5e")
        XCTAssertEqual(song.parent?.value, "7oli7U18zDNKQoRSCrQUVK")
        XCTAssertEqual(song.title, "Me Against The World")
        XCTAssertEqual(song.track, 3)
        XCTAssertEqual(song.size, 14929021)
        XCTAssertEqual(song.bitRate, 217)
        XCTAssertEqual(song.isDir, false)
    }

    // MARK: Lists

    func testGetAlbumList() throws {
        let albumList = try XCTUnwrap(decode("getAlbumList_newest").albumList)
        XCTAssertEqual(albumList.album?.values.count, 20)
        let first = try XCTUnwrap(albumList.album?.values.first)
        XCTAssertEqual(first.isDir, true)
        XCTAssertEqual(first.title, "[2011] Fear EP")
        XCTAssertEqual(first.album, "Fear - EP")
    }

    func testGetRandomSongs() throws {
        let randomSongs = try XCTUnwrap(decode("getRandomSongs").randomSongs)
        XCTAssertEqual(randomSongs.song?.values.count, 10)
        let wav = try XCTUnwrap(randomSongs.song?.values.first { $0.suffix == "wav" })
        XCTAssertEqual(wav.transcodedSuffix, "mp3")
        XCTAssertEqual(wav.bitRate, 1411)
    }

    func testSearch2() throws {
        let result = try XCTUnwrap(decode("search2").searchResult2)
        XCTAssertEqual(result.artist?.values.count, 1)
        XCTAssertEqual(result.artist?.values.first?.name, "Beck")
        XCTAssertEqual(result.album?.values.count, 3)
        XCTAssertEqual(result.song?.values.count, 3)
    }

    func testSearch3() throws {
        let result = try XCTUnwrap(decode("search3").searchResult3)
        XCTAssertEqual(result.artist?.values.first?.albumCount, 1)
        XCTAssertEqual(result.album?.values.first?.name, "Odelay (Deluxe Edition)")
        XCTAssertEqual(result.album?.values.first?.genre, "Alternative")
        XCTAssertEqual(result.song?.values.count, 3)
    }

    func testGetNowPlaying() throws {
        let nowPlaying = try XCTUnwrap(decode("getNowPlaying").nowPlaying)
        let entry = try XCTUnwrap(nowPlaying.entry?.values.first)
        XCTAssertEqual(entry.username, "bbaron")
        XCTAssertEqual(entry.minutesAgo, 0)
        XCTAssertEqual(entry.playerId?.value, "10")
        XCTAssertEqual(entry.playerName, "iSub")
    }

    // MARK: Playlists

    func testGetPlaylists() throws {
        let playlists = try XCTUnwrap(decode("getPlaylists").playlists)
        let playlist = try XCTUnwrap(playlists.playlist?.values.first)
        XCTAssertEqual(playlist.id.value, "0")
        XCTAssertEqual(playlist.name, "iSub Test Playlist")
        XCTAssertEqual(playlist.owner, "bbaron")
        XCTAssertEqual(playlist.isPublic, false)
        XCTAssertEqual(playlist.songCount, 2)
        XCTAssertEqual(playlist.duration, 521)
        XCTAssertEqual(playlist.coverArt?.value, "pl-0")
        XCTAssertNil(playlist.entry)
    }

    func testGetPlaylist() throws {
        let playlist = try XCTUnwrap(decode("getPlaylist").playlist)
        XCTAssertEqual(playlist.entry?.values.count, 2)
        XCTAssertEqual(playlist.entry?.values.first?.title, "Going Crazy")
        XCTAssertEqual(playlist.entry?.values.last?.artist, "Test ärtist")
        XCTAssertEqual(playlist.entry?.values.last?.discNumber, 1)
    }

    // MARK: Chat, lyrics, music folders, jukebox

    func testGetChatMessages() throws {
        let chat = try XCTUnwrap(decode("getChatMessages").chatMessages)
        XCTAssertEqual(chat.chatMessage?.values.count, 2)
        let first = try XCTUnwrap(chat.chatMessage?.values.first)
        XCTAssertEqual(first.username, "bbaron")
        XCTAssertEqual(first.time, 1783718935178)
        XCTAssertEqual(first.message, "Hi there & welcome — enjoy the music ")
    }

    func testGetLyrics() throws {
        let lyrics = try XCTUnwrap(decode("getLyrics").lyrics)
        XCTAssertEqual(lyrics.artist, "Beck")
        XCTAssertEqual(lyrics.title, "Loser")
        XCTAssertEqual(lyrics.value?.hasPrefix("In the time of chimpanzees"), true)
    }

    func testGetLyricsEmpty() throws {
        let lyrics = try XCTUnwrap(decode("getLyrics_empty").lyrics)
        XCTAssertNil(lyrics.artist)
        XCTAssertNil(lyrics.title)
        XCTAssertNil(lyrics.value)
    }

    func testGetMusicFolders() throws {
        let folders = try XCTUnwrap(decode("getMusicFolders").musicFolders)
        XCTAssertEqual(folders.musicFolder?.values.count, 2)
        XCTAssertEqual(folders.musicFolder?.values.first?.id.value, "0")
        XCTAssertEqual(folders.musicFolder?.values.first?.name, "Music")
    }

    func testJukeboxStatus() throws {
        let status = try XCTUnwrap(decode("jukeboxControl_status").jukeboxStatus)
        XCTAssertEqual(status.currentIndex, 1)
        XCTAssertEqual(status.playing, false)
        XCTAssertEqual(status.gain, 0.75)
        XCTAssertEqual(status.position, 0)
        XCTAssertNil(status.entry)
    }

    func testJukeboxPlaylist() throws {
        let playlist = try XCTUnwrap(decode("jukeboxControl_get").jukeboxPlaylist)
        XCTAssertEqual(playlist.currentIndex, 1)
        XCTAssertEqual(playlist.playing, true)
        XCTAssertEqual(playlist.entry?.values.count, 2)
        XCTAssertEqual(playlist.entry?.values.first?.title, "So Many Tears")
    }

    // MARK: Server variance (hand-written fixtures)

    func testNumericIDsNormalizeToStrings() throws {
        let directory = try XCTUnwrap(decode("getMusicDirectory_numeric_ids").directory)
        XCTAssertEqual(directory.id?.value, "900")
        let song = try XCTUnwrap(directory.child?.values.first)
        XCTAssertEqual(song.id.value, "9001")
        XCTAssertEqual(song.parent?.value, "900")
        XCTAssertEqual(song.albumId?.value, "1234")
        XCTAssertEqual(song.artistId?.value, "567")
    }

    func testLoneObjectsDecodeAsArrays() throws {
        let indexes = try XCTUnwrap(decode("getIndexes_single_objects").indexes)
        XCTAssertEqual(indexes.index?.values.count, 1)
        XCTAssertEqual(indexes.index?.values.first?.artist?.values.count, 1)
        XCTAssertEqual(indexes.index?.values.first?.artist?.values.first?.name, "Zebra Ensemble")
        XCTAssertEqual(indexes.child?.values.count, 1)
        XCTAssertEqual(indexes.child?.values.first?.id.value, "206")
    }

    // MARK: Bad responses

    func testMalformedJSONThrows() throws {
        let data = try Fixtures.data("JSON/malformed.json")
        XCTAssertThrowsError(try SubsonicJSON.decode(SubsonicEnvelope.self, from: data))
    }

    func testNonJSONThrows() throws {
        let data = try Fixtures.data("XML/ping_success.xml")
        XCTAssertThrowsError(try SubsonicJSON.decode(SubsonicEnvelope.self, from: data))
    }
}
