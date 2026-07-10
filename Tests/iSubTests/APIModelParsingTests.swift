//
//  APIModelParsingTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-01: Unit tests for every API model's init(serverId:element:), driven by both
// inline XML (full control of attributes) and realistic fixture XML captured from
// an Airsonic server.
final class APIModelParsingTests: XCTestCase {
    private let serverId = 7

    // MARK: Song

    private let fullSongXML = """
        <song id="353" parent="256" title="Might Like You Better (Amtrac Remix)" album="The Remixes" \
        artist="Amanda Blank" track="12" coverArt="256" size="8484888" contentType="audio/mpeg" suffix="mp3" \
        transcodedSuffix="opus" duration="206" bitRate="320" path="Amtrac/The Remixes/12 Might Like You Better.mp3" \
        isVideo="false" playCount="19" discNumber="2" year="2010" genre="Electronic" created="2024-02-24T15:31:22.978Z" \
        starred="2024-03-01T10:00:00.000Z" albumId="41" artistId="52" type="music"/>
        """

    func testSongParsesAllFields() throws {
        let element = try XMLTestHelpers.element(tag: "song", xml: fullSongXML)
        let song = Song(serverId: serverId, element: element)

        XCTAssertEqual(song.serverId, serverId)
        XCTAssertEqual(song.id, "353")
        XCTAssertEqual(song.title, "Might Like You Better (Amtrac Remix)")
        XCTAssertEqual(song.coverArtId, "256")
        XCTAssertEqual(song.parentFolderId, "256")
        XCTAssertEqual(song.tagArtistName, "Amanda Blank")
        XCTAssertEqual(song.tagAlbumName, "The Remixes")
        XCTAssertEqual(song.playCount, 19)
        XCTAssertEqual(song.year, 2010)
        XCTAssertEqual(song.tagArtistId, "52")
        XCTAssertEqual(song.tagAlbumId, "41")
        XCTAssertEqual(song.genre, "Electronic")
        XCTAssertEqual(song.path, "Amtrac/The Remixes/12 Might Like You Better.mp3")
        XCTAssertEqual(song.suffix, "mp3")
        XCTAssertEqual(song.transcodedSuffix, "opus")
        XCTAssertEqual(song.duration, 206)
        XCTAssertEqual(song.kiloBitrate, 320)
        XCTAssertEqual(song.track, 12)
        XCTAssertEqual(song.discNumber, 2)
        XCTAssertEqual(song.size, 8484888)
        XCTAssertFalse(song.isVideo)
        XCTAssertEqual(song.createdDate.timeIntervalSince1970, 1708788682.978, accuracy: 0.001)
        let starredDate = try XCTUnwrap(song.starredDate)
        XCTAssertEqual(starredDate.timeIntervalSince1970, 1709287200.0, accuracy: 0.001)
    }

    func testSongParsesCoverArtIdIncorrectlyNamedParent() throws {
        // The song element uses the "coverArt" attribute for cover art and "parent"
        // for the parent folder; make sure they don't get crossed
        let element = try XMLTestHelpers.element(tag: "song", xml: #"<song id="1" coverArt="99" parent="55" title="t" path="p" suffix="mp3"/>"#)
        let song = Song(serverId: serverId, element: element)
        XCTAssertEqual(song.coverArtId, "99")
        XCTAssertEqual(song.parentFolderId, "55")
    }

    func testSongMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "song", xml: #"<song id="10"/>"#)
        let song = Song(serverId: serverId, element: element)

        XCTAssertEqual(song.id, "10")
        // Non-optional strings fall back to the literal "nil" placeholder
        XCTAssertEqual(song.title, "nil")
        XCTAssertEqual(song.path, "nil")
        XCTAssertEqual(song.suffix, "nil")
        // Optional fields stay nil
        XCTAssertNil(song.coverArtId)
        XCTAssertNil(song.parentFolderId)
        XCTAssertNil(song.tagArtistName)
        XCTAssertNil(song.tagAlbumName)
        XCTAssertNil(song.playCount)
        XCTAssertNil(song.year)
        XCTAssertNil(song.tagArtistId)
        XCTAssertNil(song.tagAlbumId)
        XCTAssertNil(song.genre)
        XCTAssertNil(song.transcodedSuffix)
        XCTAssertNil(song.track)
        XCTAssertNil(song.discNumber)
        XCTAssertNil(song.starredDate)
        // Non-optional numerics default to 0, bools to false, dates to distantPast
        XCTAssertEqual(song.duration, 0)
        XCTAssertEqual(song.kiloBitrate, 0)
        XCTAssertEqual(song.size, 0)
        XCTAssertFalse(song.isVideo)
        XCTAssertEqual(song.createdDate, .distantPast)
    }

    func testSongParsesVideoEntry() throws {
        let xml = #"<child id="900" title="Concert" path="videos/concert.mkv" suffix="mkv" isVideo="true" duration="5400" size="123456789"/>"#
        let element = try XMLTestHelpers.element(tag: "child", xml: xml)
        let song = Song(serverId: serverId, element: element)
        XCTAssertTrue(song.isVideo)
        XCTAssertEqual(song.suffix, "mkv")
    }

    func testSongParsesSpecialCharactersInAttributes() throws {
        let xml = #"<song id="5" title="Sigur R&#243;s &amp; friends &lt;live&gt; &quot;encore&quot;" artist="Bj&#246;rk" path="S/&#208;j&#243;&#240;/01.mp3" suffix="mp3"/>"#
        let element = try XMLTestHelpers.element(tag: "song", xml: xml)
        let song = Song(serverId: serverId, element: element)
        XCTAssertEqual(song.title, "Sigur Rós & friends <live> \"encore\"")
        XCTAssertEqual(song.tagArtistName, "Björk")
        XCTAssertEqual(song.path, "S/Ðjóð/01.mp3")
    }

    func testSongParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "song", fixture: "XML/getAlbum.xml")
        let song = Song(serverId: serverId, element: element)
        XCTAssertEqual(song.id, "353")
        XCTAssertEqual(song.title, "Might Like You Better (Amtrac Remix)")
        XCTAssertEqual(song.tagAlbumName, "The Remixes")
        XCTAssertEqual(song.kiloBitrate, 320)
        XCTAssertNil(song.transcodedSuffix)
    }

    func testSongEqualityAndHashingUseOnlyServerIdAndId() throws {
        let a = try Song(serverId: 1, element: XMLTestHelpers.element(tag: "song", xml: #"<song id="42" title="Title A" path="a.mp3" suffix="mp3"/>"#))
        let b = try Song(serverId: 1, element: XMLTestHelpers.element(tag: "song", xml: #"<song id="42" title="Completely Different" path="b.flac" suffix="flac"/>"#))
        let differentId = try Song(serverId: 1, element: XMLTestHelpers.element(tag: "song", xml: #"<song id="43" title="Title A" path="a.mp3" suffix="mp3"/>"#))
        let differentServer = try Song(serverId: 2, element: XMLTestHelpers.element(tag: "song", xml: #"<song id="42" title="Title A" path="a.mp3" suffix="mp3"/>"#))

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
        XCTAssertNotEqual(a, differentId)
        XCTAssertNotEqual(a, differentServer)

        var set = Set<Song>()
        set.insert(a)
        XCTAssertTrue(set.contains(b))
        XCTAssertFalse(set.contains(differentServer))
    }

    // MARK: TagArtist

    func testTagArtistParsesAllFields() throws {
        let xml = #"<artist id="52" name="Amanda Blank" coverArt="ar-52" artistImageUrl="http://example.com/a.jpg" albumCount="3" starred="2024-02-24T15:31:22.978Z"/>"#
        let element = try XMLTestHelpers.element(tag: "artist", xml: xml)
        let artist = TagArtist(serverId: serverId, element: element)

        XCTAssertEqual(artist.serverId, serverId)
        XCTAssertEqual(artist.id, "52")
        XCTAssertEqual(artist.name, "Amanda Blank")
        XCTAssertEqual(artist.coverArtId, "ar-52")
        XCTAssertEqual(artist.artistImageUrl, "http://example.com/a.jpg")
        XCTAssertEqual(artist.albumCount, 3)
        XCTAssertNotNil(artist.starredDate)
    }

    func testTagArtistMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="31" name="A Tribe Called Quest"/>"#)
        let artist = TagArtist(serverId: serverId, element: element)
        XCTAssertNil(artist.coverArtId)
        XCTAssertNil(artist.artistImageUrl)
        XCTAssertEqual(artist.albumCount, 0)
        XCTAssertNil(artist.starredDate)
    }

    func testTagArtistParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "artist", fixture: "XML/getArtists.xml")
        let artist = TagArtist(serverId: serverId, element: element)
        XCTAssertEqual(artist.id, "52")
        XCTAssertEqual(artist.name, "Amanda Blank")
        XCTAssertEqual(artist.coverArtId, "ar-52")
        XCTAssertEqual(artist.albumCount, 1)
    }

    func testTagArtistEqualityUsesOnlyServerIdAndId() throws {
        let a = try TagArtist(serverId: 1, element: XMLTestHelpers.element(tag: "artist", xml: #"<artist id="1" name="One"/>"#))
        let b = try TagArtist(serverId: 1, element: XMLTestHelpers.element(tag: "artist", xml: #"<artist id="1" name="Other Name"/>"#))
        let c = try TagArtist(serverId: 2, element: XMLTestHelpers.element(tag: "artist", xml: #"<artist id="1" name="One"/>"#))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: TagAlbum

    func testTagAlbumParsesAllFields() throws {
        let xml = #"<album id="41" name="The Remixes" artist="Amanda Blank" artistId="52" coverArt="al-41" songCount="12" duration="2967" playCount="4" year="2010" genre="Electronic" created="2024-02-24T15:31:22.978Z" starred="2024-03-01T10:00:00.000Z"/>"#
        let element = try XMLTestHelpers.element(tag: "album", xml: xml)
        let album = TagAlbum(serverId: serverId, element: element)

        XCTAssertEqual(album.serverId, serverId)
        XCTAssertEqual(album.id, "41")
        XCTAssertEqual(album.name, "The Remixes")
        XCTAssertEqual(album.coverArtId, "al-41")
        XCTAssertEqual(album.tagArtistId, "52")
        XCTAssertEqual(album.tagArtistName, "Amanda Blank")
        XCTAssertEqual(album.songCount, 12)
        XCTAssertEqual(album.duration, 2967)
        XCTAssertEqual(album.playCount, 4)
        XCTAssertEqual(album.year, 2010)
        XCTAssertEqual(album.genre, "Electronic")
        XCTAssertEqual(album.createdDate.timeIntervalSince1970, 1708788682.978, accuracy: 0.001)
        XCTAssertNotNil(album.starredDate)
    }

    func testTagAlbumMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "album", xml: #"<album id="9" name="Bare"/>"#)
        let album = TagAlbum(serverId: serverId, element: element)
        XCTAssertNil(album.coverArtId)
        XCTAssertNil(album.tagArtistId)
        XCTAssertNil(album.tagArtistName)
        XCTAssertEqual(album.songCount, 0)
        XCTAssertEqual(album.duration, 0)
        XCTAssertEqual(album.playCount, 0)
        XCTAssertEqual(album.year, 0)
        // genre uses the non-optional accessor, so a missing attribute becomes "nil"
        XCTAssertEqual(album.genre, "nil")
        XCTAssertEqual(album.createdDate, .distantPast)
        XCTAssertNil(album.starredDate)
    }

    func testTagAlbumParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "album", fixture: "XML/getAlbum.xml")
        let album = TagAlbum(serverId: serverId, element: element)
        XCTAssertEqual(album.id, "41")
        XCTAssertEqual(album.name, "The Remixes")
        XCTAssertEqual(album.tagArtistName, "Amanda Blank")
        XCTAssertEqual(album.songCount, 1)
        XCTAssertEqual(album.duration, 206)
    }

    // MARK: FolderArtist

    func testFolderArtistParsesAllFields() throws {
        let xml = #"<artist id="219" name="Beck" userRating="4" averageRating="3.5" starred="2024-02-24T15:31:22.978Z"/>"#
        let element = try XMLTestHelpers.element(tag: "artist", xml: xml)
        let artist = FolderArtist(serverId: serverId, element: element)

        XCTAssertEqual(artist.serverId, serverId)
        XCTAssertEqual(artist.id, "219")
        XCTAssertEqual(artist.name, "Beck")
        XCTAssertEqual(artist.userRating, 4)
        XCTAssertEqual(artist.averageRating, 3.5)
        XCTAssertNotNil(artist.starredDate)
    }

    func testFolderArtistMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "artist", xml: #"<artist id="219" name="Beck"/>"#)
        let artist = FolderArtist(serverId: serverId, element: element)
        XCTAssertNil(artist.userRating)
        XCTAssertNil(artist.averageRating)
        XCTAssertNil(artist.starredDate)
    }

    func testFolderArtistParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "artist", fixture: "XML/getIndexes.xml")
        let artist = FolderArtist(serverId: serverId, element: element)
        XCTAssertFalse(artist.id.isEmpty)
        XCTAssertFalse(artist.name.isEmpty)
    }

    // MARK: FolderAlbum

    func testFolderAlbumParsesAllFields() throws {
        let xml = #"<child id="225" parent="219" isDir="true" title="Odelay" artist="Beck" album="Odelay" playCount="7" year="1996" genre="Alternative" userRating="5" averageRating="4.5" coverArt="225" created="2024-02-24T15:30:02.799Z" starred="2024-03-01T10:00:00.000Z"/>"#
        let element = try XMLTestHelpers.element(tag: "child", xml: xml)
        let album = FolderAlbum(serverId: serverId, element: element)

        XCTAssertEqual(album.serverId, serverId)
        XCTAssertEqual(album.id, "225")
        XCTAssertEqual(album.name, "Odelay")
        XCTAssertEqual(album.coverArtId, "225")
        XCTAssertEqual(album.parentFolderId, "219")
        XCTAssertEqual(album.tagArtistName, "Beck")
        XCTAssertEqual(album.playCount, 7)
        XCTAssertEqual(album.year, 1996)
        XCTAssertEqual(album.genre, "Alternative")
        XCTAssertEqual(album.userRating, 5)
        XCTAssertEqual(album.averageRating, 4.5)
        XCTAssertEqual(album.createdDate.timeIntervalSince1970, 1708788602.799, accuracy: 0.001)
        XCTAssertNotNil(album.starredDate)
    }

    func testFolderAlbumTagAlbumNameIsTheAlbumTitleNotTheArtist() throws {
        // Regression for BUG-20: tagAlbumName is currently parsed from the "artist"
        // attribute (copy-paste of the tagArtistName line above it). The album title
        // lives in the "album" attribute on directory child elements.
        let xml = #"<child id="225" parent="219" isDir="true" title="Odelay" album="Odelay" artist="Beck"/>"#
        let element = try XMLTestHelpers.element(tag: "child", xml: xml)
        let album = FolderAlbum(serverId: serverId, element: element)
        XCTExpectFailure("BUG-20: tagAlbumName currently parses the artist attribute; remove this marker when fixing the bug") {
            XCTAssertEqual(album.tagAlbumName, "Odelay", "FolderAlbum.tagAlbumName should be the album title, not the artist name (BUG-20)")
        }
    }

    func testFolderAlbumMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "child", xml: #"<child id="225" title="Odelay"/>"#)
        let album = FolderAlbum(serverId: serverId, element: element)
        XCTAssertNil(album.coverArtId)
        XCTAssertNil(album.parentFolderId)
        XCTAssertNil(album.tagArtistName)
        XCTAssertEqual(album.playCount, 0)
        XCTAssertNil(album.year)
        XCTAssertNil(album.genre)
        XCTAssertNil(album.userRating)
        XCTAssertNil(album.averageRating)
        XCTAssertEqual(album.createdDate, .distantPast)
        XCTAssertNil(album.starredDate)
    }

    func testFolderAlbumParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "child", fixture: "XML/getMusicDirectory_artist.xml")
        let album = FolderAlbum(serverId: serverId, element: element)
        XCTAssertEqual(album.id, "225")
        XCTAssertEqual(album.name, "Odeley")
        XCTAssertEqual(album.parentFolderId, "219")
    }

    // MARK: MediaFolder

    func testMediaFolderParsesElement() throws {
        let element = try XMLTestHelpers.element(tag: "musicFolder", xml: #"<musicFolder id="1" name="Music"/>"#)
        let folder = MediaFolder(serverId: serverId, element: element)
        XCTAssertEqual(folder.serverId, serverId)
        XCTAssertEqual(folder.id, 1)
        XCTAssertEqual(folder.name, "Music")
    }

    func testMediaFolderMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "musicFolder", xml: #"<musicFolder/>"#)
        let folder = MediaFolder(serverId: serverId, element: element)
        XCTAssertEqual(folder.id, 0)
        XCTAssertEqual(folder.name, "nil")
    }

    func testMediaFolderParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "musicFolder", fixture: "XML/getMusicFolders.xml")
        let folder = MediaFolder(serverId: serverId, element: element)
        XCTAssertFalse(folder.name.isEmpty)
    }

    // MARK: ChatMessage

    func testChatMessageParsesElementAndConvertsMillisecondTimestamp() throws {
        let xml = #"<chatMessage username="bbaron" time="1678318407778" message="Hello &amp; welcome!"/>"#
        let element = try XMLTestHelpers.element(tag: "chatMessage", xml: xml)
        let message = ChatMessage(serverId: serverId, element: element)

        XCTAssertEqual(message.serverId, serverId)
        XCTAssertEqual(message.username, "bbaron")
        XCTAssertEqual(message.message, "Hello & welcome!")
        // The server sends milliseconds; the model stores seconds
        XCTAssertEqual(message.timestamp, 1678318407.778, accuracy: 0.001)
    }

    func testChatMessageMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "chatMessage", xml: #"<chatMessage/>"#)
        let message = ChatMessage(serverId: serverId, element: element)
        XCTAssertEqual(message.username, "nil")
        XCTAssertEqual(message.message, "nil")
        XCTAssertEqual(message.timestamp, 0)
    }

    func testChatMessageParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "chatMessage", fixture: "XML/getChatMessages.xml")
        let message = ChatMessage(serverId: serverId, element: element)
        XCTAssertFalse(message.username.isEmpty)
        XCTAssertGreaterThan(message.timestamp, 0)
    }

    // MARK: Lyrics

    func testLyricsParsesElementText() throws {
        let xml = "<lyrics artist=\"Bob Dylan\" title=\"Blowin' in the Wind\">How many roads&#10;must a man walk down</lyrics>"
        let element = try XMLTestHelpers.element(tag: "lyrics", xml: xml)
        let lyrics = Lyrics(tagArtistName: "Bob Dylan", songTitle: "Blowin' in the Wind", element: element)

        XCTAssertEqual(lyrics.tagArtistName, "Bob Dylan")
        XCTAssertEqual(lyrics.songTitle, "Blowin' in the Wind")
        XCTAssertEqual(lyrics.lyricsText, "How many roads\nmust a man walk down")
    }

    func testLyricsEmptyElementProducesEmptyText() throws {
        let element = try XMLTestHelpers.element(tag: "lyrics", fixture: "XML/getLyrics_empty.xml")
        let lyrics = Lyrics(tagArtistName: "a", songTitle: "t", element: element)
        XCTAssertEqual(lyrics.lyricsText, "")
    }

    func testLyricsParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "lyrics", fixture: "XML/getLyrics.xml")
        let lyrics = Lyrics(tagArtistName: "a", songTitle: "t", element: element)
        XCTAssertFalse(lyrics.lyricsText.isEmpty)
    }

    // MARK: NowPlayingSong

    func testNowPlayingSongParsesEntryAttributes() throws {
        let xml = #"<entry id="353" username="bbaron" minutesAgo="3" playerId="2" playerName="iSub" title="Song"/>"#
        let element = try XMLTestHelpers.element(tag: "entry", xml: xml)
        let nowPlaying = NowPlayingSong(serverId: serverId, element: element)

        XCTAssertEqual(nowPlaying.serverId, serverId)
        XCTAssertEqual(nowPlaying.songId, "353")
        XCTAssertEqual(nowPlaying.username, "bbaron")
        XCTAssertEqual(nowPlaying.minutesAgo, 3)
        XCTAssertEqual(nowPlaying.playerId, 2)
        XCTAssertEqual(nowPlaying.playerName, "iSub")
    }

    func testNowPlayingSongMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "entry", xml: #"<entry id="353"/>"#)
        let nowPlaying = NowPlayingSong(serverId: serverId, element: element)
        XCTAssertEqual(nowPlaying.username, "nil")
        XCTAssertEqual(nowPlaying.minutesAgo, 0)
        XCTAssertEqual(nowPlaying.playerId, 0)
        XCTAssertEqual(nowPlaying.playerName, "nil")
    }

    func testNowPlayingSongParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "entry", fixture: "XML/getNowPlaying.xml")
        let nowPlaying = NowPlayingSong(serverId: serverId, element: element)
        XCTAssertFalse(nowPlaying.songId.isEmpty)
        XCTAssertFalse(nowPlaying.username.isEmpty)
    }

    // MARK: ServerPlaylist

    func testServerPlaylistParsesAllFields() throws {
        let xml = #"<playlist id="17" name="Road Trip" comment="Best driving songs" owner="bbaron" public="true" songCount="25" duration="5000" created="2024-02-24T15:31:22.978Z" changed="2024-03-01T10:00:00.000Z" coverArt="pl-17"/>"#
        let element = try XMLTestHelpers.element(tag: "playlist", xml: xml)
        let playlist = ServerPlaylist(serverId: serverId, element: element)

        XCTAssertEqual(playlist.serverId, serverId)
        XCTAssertEqual(playlist.id, 17)
        XCTAssertEqual(playlist.name, "Road Trip")
        XCTAssertEqual(playlist.comment, "Best driving songs")
        XCTAssertEqual(playlist.owner, "bbaron")
        XCTAssertTrue(playlist.isPublic)
        XCTAssertEqual(playlist.songCount, 25)
        XCTAssertEqual(playlist.duration, 5000)
        XCTAssertEqual(playlist.coverArtId, "pl-17")
        XCTAssertNotNil(playlist.createdDate)
        XCTAssertNotNil(playlist.changedDate)
        // Loaded count always starts at zero; isLoaded only once all songs are loaded
        XCTAssertEqual(playlist.loadedSongCount, 0)
        XCTAssertFalse(playlist.isLoaded)
    }

    func testServerPlaylistMissingAttributeDefaults() throws {
        let element = try XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="17" name="Bare"/>"#)
        let playlist = ServerPlaylist(serverId: serverId, element: element)
        XCTAssertNil(playlist.coverArtId)
        XCTAssertNil(playlist.comment)
        XCTAssertEqual(playlist.songCount, 0)
        XCTAssertEqual(playlist.duration, 0)
        XCTAssertEqual(playlist.owner, "nil")
        XCTAssertFalse(playlist.isPublic)
        XCTAssertNil(playlist.createdDate)
        XCTAssertNil(playlist.changedDate)
        // With zero songs and zero loaded, the playlist counts as loaded
        XCTAssertTrue(playlist.isLoaded)
    }

    func testServerPlaylistParsedFromRealFixture() throws {
        let element = try XMLTestHelpers.element(tag: "playlist", fixture: "XML/getPlaylists.xml")
        let playlist = ServerPlaylist(serverId: serverId, element: element)
        XCTAssertEqual(playlist.name, "iSub Test Playlist")
        XCTAssertEqual(playlist.songCount, 2)
        XCTAssertEqual(playlist.owner, "bbaron")
        XCTAssertFalse(playlist.isPublic)
    }

    func testServerPlaylistEqualityUsesOnlyServerIdAndId() throws {
        let a = try ServerPlaylist(serverId: 1, element: XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="1" name="One"/>"#))
        let b = try ServerPlaylist(serverId: 1, element: XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="1" name="Different"/>"#))
        let c = try ServerPlaylist(serverId: 2, element: XMLTestHelpers.element(tag: "playlist", xml: #"<playlist id="1" name="One"/>"#))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
