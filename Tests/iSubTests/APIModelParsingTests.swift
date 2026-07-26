//
//  APIModelParsingTests.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import XCTest
@testable import iSub_Beta

// COV-01: Unit tests for every API model's init(serverId:dto:), driven by inline
// XML payloads (decoded through SubsonicXMLDecoder, pinning the XML scalar
// defaults), inline JSON literals, and realistic fixture responses captured from
// an Airsonic server. The leniency contract is load-bearing: missing values must
// map to the "nil" string sentinel / 0 / false / .distantPast defaults so DB rows
// are byte-identical whichever wire format produced them.
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

    private func songDTO(payloadXML: String) throws -> ChildDTO {
        try XCTUnwrap(TestDTO.xmlResponse(payloadXML).song)
    }

    func testSongParsesAllFields() throws {
        let song = Song(serverId: serverId, dto: try songDTO(payloadXML: fullSongXML))

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
        let song = Song(serverId: serverId, dto: try songDTO(payloadXML: #"<song id="1" coverArt="99" parent="55" title="t" path="p" suffix="mp3"/>"#))
        XCTAssertEqual(song.coverArtId, "99")
        XCTAssertEqual(song.parentFolderId, "55")
    }

    private func assertSongMissingValueDefaults(_ song: Song, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(song.id, "10", file: file, line: line)
        // Non-optional strings fall back to the literal "nil" placeholder
        XCTAssertEqual(song.title, "nil", file: file, line: line)
        XCTAssertEqual(song.path, "nil", file: file, line: line)
        XCTAssertEqual(song.suffix, "nil", file: file, line: line)
        // Optional fields stay nil
        XCTAssertNil(song.coverArtId, file: file, line: line)
        XCTAssertNil(song.parentFolderId, file: file, line: line)
        XCTAssertNil(song.tagArtistName, file: file, line: line)
        XCTAssertNil(song.tagAlbumName, file: file, line: line)
        XCTAssertNil(song.playCount, file: file, line: line)
        XCTAssertNil(song.year, file: file, line: line)
        XCTAssertNil(song.tagArtistId, file: file, line: line)
        XCTAssertNil(song.tagAlbumId, file: file, line: line)
        XCTAssertNil(song.genre, file: file, line: line)
        XCTAssertNil(song.transcodedSuffix, file: file, line: line)
        XCTAssertNil(song.track, file: file, line: line)
        XCTAssertNil(song.discNumber, file: file, line: line)
        XCTAssertNil(song.starredDate, file: file, line: line)
        // Non-optional numerics default to 0, bools to false, dates to distantPast
        XCTAssertEqual(song.duration, 0, file: file, line: line)
        XCTAssertEqual(song.kiloBitrate, 0, file: file, line: line)
        XCTAssertEqual(song.size, 0, file: file, line: line)
        XCTAssertFalse(song.isVideo, file: file, line: line)
        XCTAssertEqual(song.createdDate, .distantPast, file: file, line: line)
    }

    func testSongMissingAttributeDefaultsFromXML() throws {
        let song = Song(serverId: serverId, dto: try songDTO(payloadXML: #"<song id="10"/>"#))
        assertSongMissingValueDefaults(song)
    }

    func testSongMissingKeyDefaultsFromJSON() throws {
        // Both wire formats must produce the identical defaults for missing values
        let song = Song(serverId: serverId, dto: try TestDTO.json(ChildDTO.self, #"{"id": "10"}"#))
        assertSongMissingValueDefaults(song)
    }

    func testSongParsesVideoEntry() throws {
        let payload = #"<directory id="1"><child id="900" title="Concert" path="videos/concert.mkv" suffix="mkv" isVideo="true" duration="5400" size="123456789"/></directory>"#
        let dto = try XCTUnwrap(TestDTO.xmlResponse(payload).directory?.child?.values.first)
        let song = Song(serverId: serverId, dto: dto)
        XCTAssertTrue(song.isVideo)
        XCTAssertEqual(song.suffix, "mkv")
    }

    func testSongParsesSpecialCharactersInAttributes() throws {
        let payload = #"<song id="5" title="Sigur R&#243;s &amp; friends &lt;live&gt; &quot;encore&quot;" artist="Bj&#246;rk" path="S/&#208;j&#243;&#240;/01.mp3" suffix="mp3"/>"#
        let song = Song(serverId: serverId, dto: try songDTO(payloadXML: payload))
        XCTAssertEqual(song.title, "Sigur Rós & friends <live> \"encore\"")
        XCTAssertEqual(song.tagArtistName, "Björk")
        XCTAssertEqual(song.path, "S/Ðjóð/01.mp3")
    }

    func testSongParsedFromRealFixture() throws {
        let dto = try XCTUnwrap(TestDTO.response(fixture: "XML/getAlbum.xml").album?.song?.values.first)
        let song = Song(serverId: serverId, dto: dto)
        XCTAssertEqual(song.id, "353")
        XCTAssertEqual(song.title, "Might Like You Better (Amtrac Remix)")
        XCTAssertEqual(song.tagAlbumName, "The Remixes")
        XCTAssertEqual(song.kiloBitrate, 320)
        XCTAssertNil(song.transcodedSuffix)
    }

    func testSongParsedFromRealSubsonicFixtureWithoutIsVideo() throws {
        // Real Subsonic servers omit the isVideo attribute on music entries (Airsonic
        // always sends isVideo="false"); parsing must default it to false
        let dto = try XCTUnwrap(TestDTO.response(fixture: "XML/jukeboxControl_get.xml").jukeboxPlaylist?.entry?.values.first)
        let song = Song(serverId: serverId, dto: dto)
        XCTAssertEqual(song.id, "189")
        XCTAssertEqual(song.title, "So Many Tears")
        XCTAssertEqual(song.suffix, "mp3")
        XCTAssertFalse(song.isVideo)
    }

    func testSongEqualityAndHashingUseOnlyServerIdAndId() throws {
        func makeSong(serverId: Int, json: String) throws -> Song {
            Song(serverId: serverId, dto: try TestDTO.json(ChildDTO.self, json))
        }
        let a = try makeSong(serverId: 1, json: #"{"id": "42", "title": "Title A", "path": "a.mp3", "suffix": "mp3"}"#)
        let b = try makeSong(serverId: 1, json: #"{"id": "42", "title": "Completely Different", "path": "b.flac", "suffix": "flac"}"#)
        let differentId = try makeSong(serverId: 1, json: #"{"id": "43", "title": "Title A", "path": "a.mp3", "suffix": "mp3"}"#)
        let differentServer = try makeSong(serverId: 2, json: #"{"id": "42", "title": "Title A", "path": "a.mp3", "suffix": "mp3"}"#)

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
        let payload = #"<artist id="52" name="Amanda Blank" coverArt="ar-52" artistImageUrl="http://example.com/a.jpg" albumCount="3" starred="2024-02-24T15:31:22.978Z"/>"#
        let dto = try XCTUnwrap(TestDTO.xmlResponse(payload).artist)
        let artist = TagArtist(serverId: serverId, dto: dto)

        XCTAssertEqual(artist.serverId, serverId)
        XCTAssertEqual(artist.id, "52")
        XCTAssertEqual(artist.name, "Amanda Blank")
        XCTAssertEqual(artist.coverArtId, "ar-52")
        XCTAssertEqual(artist.artistImageUrl, "http://example.com/a.jpg")
        XCTAssertEqual(artist.albumCount, 3)
        XCTAssertNotNil(artist.starredDate)
    }

    func testTagArtistMissingAttributeDefaults() throws {
        let dto = try XCTUnwrap(TestDTO.xmlResponse(#"<artist id="31" name="A Tribe Called Quest"/>"#).artist)
        let artist = TagArtist(serverId: serverId, dto: dto)
        XCTAssertNil(artist.coverArtId)
        XCTAssertNil(artist.artistImageUrl)
        XCTAssertEqual(artist.albumCount, 0)
        XCTAssertNil(artist.starredDate)
    }

    func testTagArtistParsedFromRealFixture() throws {
        let response = try TestDTO.response(fixture: "XML/getArtists.xml")
        let dto = try XCTUnwrap(response.artists?.index?.values.first?.artist?.values.first)
        let artist = TagArtist(serverId: serverId, dto: dto)
        XCTAssertEqual(artist.id, "52")
        XCTAssertEqual(artist.name, "Amanda Blank")
        XCTAssertEqual(artist.coverArtId, "ar-52")
        XCTAssertEqual(artist.albumCount, 1)
    }

    func testTagArtistEqualityUsesOnlyServerIdAndId() throws {
        let a = TagArtist(serverId: 1, dto: try TestDTO.json(ArtistID3DTO.self, #"{"id": "1", "name": "One"}"#))
        let b = TagArtist(serverId: 1, dto: try TestDTO.json(ArtistID3DTO.self, #"{"id": "1", "name": "Other Name"}"#))
        let c = TagArtist(serverId: 2, dto: try TestDTO.json(ArtistID3DTO.self, #"{"id": "1", "name": "One"}"#))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: TagAlbum

    func testTagAlbumParsesAllFields() throws {
        let payload = #"<album id="41" name="The Remixes" artist="Amanda Blank" artistId="52" coverArt="al-41" songCount="12" duration="2967" playCount="4" year="2010" genre="Electronic" created="2024-02-24T15:31:22.978Z" starred="2024-03-01T10:00:00.000Z"/>"#
        let dto = try XCTUnwrap(TestDTO.xmlResponse(payload).album)
        let album = TagAlbum(serverId: serverId, dto: dto)

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
        let dto = try XCTUnwrap(TestDTO.xmlResponse(#"<album id="9" name="Bare"/>"#).album)
        let album = TagAlbum(serverId: serverId, dto: dto)
        XCTAssertNil(album.coverArtId)
        XCTAssertNil(album.tagArtistId)
        XCTAssertNil(album.tagArtistName)
        XCTAssertEqual(album.songCount, 0)
        XCTAssertEqual(album.duration, 0)
        XCTAssertEqual(album.playCount, 0)
        XCTAssertEqual(album.year, 0)
        // genre keeps the non-optional accessor's behavior, so a missing value becomes "nil"
        XCTAssertEqual(album.genre, "nil")
        XCTAssertEqual(album.createdDate, .distantPast)
        XCTAssertNil(album.starredDate)
    }

    func testTagAlbumParsedFromRealFixture() throws {
        let dto = try XCTUnwrap(TestDTO.response(fixture: "XML/getAlbum.xml").album)
        let album = TagAlbum(serverId: serverId, dto: dto)
        XCTAssertEqual(album.id, "41")
        XCTAssertEqual(album.name, "The Remixes")
        XCTAssertEqual(album.tagArtistName, "Amanda Blank")
        XCTAssertEqual(album.songCount, 1)
        XCTAssertEqual(album.duration, 206)
    }

    // MARK: FolderArtist

    private func folderArtistDTO(payloadXML: String) throws -> FolderArtistDTO {
        let response = try TestDTO.xmlResponse("<indexes><index name=\"A\">\(payloadXML)</index></indexes>")
        return try XCTUnwrap(response.indexes?.index?.values.first?.artist?.values.first)
    }

    func testFolderArtistParsesAllFields() throws {
        let payload = #"<artist id="219" name="Beck" userRating="4" averageRating="3.5" starred="2024-02-24T15:31:22.978Z"/>"#
        let artist = FolderArtist(serverId: serverId, dto: try folderArtistDTO(payloadXML: payload))

        XCTAssertEqual(artist.serverId, serverId)
        XCTAssertEqual(artist.id, "219")
        XCTAssertEqual(artist.name, "Beck")
        XCTAssertEqual(artist.userRating, 4)
        XCTAssertEqual(artist.averageRating, 3.5)
        XCTAssertNotNil(artist.starredDate)
    }

    func testFolderArtistMissingAttributeDefaults() throws {
        let artist = FolderArtist(serverId: serverId, dto: try folderArtistDTO(payloadXML: #"<artist id="219" name="Beck"/>"#))
        XCTAssertNil(artist.userRating)
        XCTAssertNil(artist.averageRating)
        XCTAssertNil(artist.starredDate)
    }

    func testFolderArtistParsedFromRealFixture() throws {
        let response = try TestDTO.response(fixture: "XML/getIndexes.xml")
        let dto = try XCTUnwrap(response.indexes?.index?.values.first?.artist?.values.first)
        let artist = FolderArtist(serverId: serverId, dto: dto)
        // Exact fixture values: a missing/misnamed value maps to the literal string
        // "nil", which a non-empty assertion would happily accept
        XCTAssertEqual(artist.id, "221")
        XCTAssertEqual(artist.name, "ALAC")
    }

    // MARK: FolderAlbum

    private func folderAlbumDTO(payloadXML: String) throws -> ChildDTO {
        let response = try TestDTO.xmlResponse("<directory id=\"219\">\(payloadXML)</directory>")
        return try XCTUnwrap(response.directory?.child?.values.first)
    }

    func testFolderAlbumParsesAllFields() throws {
        let payload = #"<child id="225" parent="219" isDir="true" title="Odelay" artist="Beck" album="Odelay" playCount="7" year="1996" genre="Alternative" userRating="5" averageRating="4.5" coverArt="225" created="2024-02-24T15:30:02.799Z" starred="2024-03-01T10:00:00.000Z"/>"#
        let album = FolderAlbum(serverId: serverId, dto: try folderAlbumDTO(payloadXML: payload))

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
        // Regression for BUG-20: tagAlbumName used to be parsed from the "artist"
        // attribute (copy-paste of the tagArtistName line above it). The album title
        // lives in the "album" attribute on directory child elements, matching Song.
        let payload = #"<child id="225" parent="219" isDir="true" title="Odelay" album="Odelay" artist="Beck"/>"#
        let album = FolderAlbum(serverId: serverId, dto: try folderAlbumDTO(payloadXML: payload))
        XCTAssertEqual(album.tagAlbumName, "Odelay", "FolderAlbum.tagAlbumName should be the album title, not the artist name (BUG-20)")
    }

    func testFolderAlbumMissingAttributeDefaults() throws {
        let album = FolderAlbum(serverId: serverId, dto: try folderAlbumDTO(payloadXML: #"<child id="225" title="Odelay"/>"#))
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
        let response = try TestDTO.response(fixture: "XML/getMusicDirectory_artist.xml")
        let dto = try XCTUnwrap(response.directory?.child?.values.first)
        let album = FolderAlbum(serverId: serverId, dto: dto)
        XCTAssertEqual(album.id, "225")
        XCTAssertEqual(album.name, "Odeley")
        XCTAssertEqual(album.parentFolderId, "219")
    }

    // MARK: MediaFolder

    private func mediaFolderDTO(payloadXML: String) throws -> MusicFolderDTO {
        let response = try TestDTO.xmlResponse("<musicFolders>\(payloadXML)</musicFolders>")
        return try XCTUnwrap(response.musicFolders?.musicFolder?.values.first)
    }

    func testMediaFolderParsesElement() throws {
        let folder = MediaFolder(serverId: serverId, dto: try mediaFolderDTO(payloadXML: #"<musicFolder id="1" name="Music"/>"#))
        XCTAssertEqual(folder.serverId, serverId)
        XCTAssertEqual(folder.id, 1)
        XCTAssertEqual(folder.name, "Music")
    }

    func testMediaFolderMissingAttributeDefaults() throws {
        // The DTO layer requires an id (an id-less <musicFolder/> fails to decode),
        // but a non-numeric id still falls back to 0 and a missing name to "nil"
        let folder = MediaFolder(serverId: serverId, dto: try mediaFolderDTO(payloadXML: #"<musicFolder id="not-a-number"/>"#))
        XCTAssertEqual(folder.id, 0)
        XCTAssertEqual(folder.name, "nil")
    }

    func testMediaFolderParsedFromRealFixture() throws {
        let response = try TestDTO.response(fixture: "XML/getMusicFolders.xml")
        let dto = try XCTUnwrap(response.musicFolders?.musicFolder?.values.first)
        let folder = MediaFolder(serverId: serverId, dto: dto)
        // The first fixture folder's id (0) matches the fallback default, so the
        // name is the discriminating assertion here
        XCTAssertEqual(folder.id, 0)
        XCTAssertEqual(folder.name, "Music")
    }

    // MARK: ChatMessage

    private func chatMessageDTO(payloadXML: String) throws -> ChatMessageDTO {
        let response = try TestDTO.xmlResponse("<chatMessages>\(payloadXML)</chatMessages>")
        return try XCTUnwrap(response.chatMessages?.chatMessage?.values.first)
    }

    func testChatMessageParsesElementAndConvertsMillisecondTimestamp() throws {
        let payload = #"<chatMessage username="bbaron" time="1678318407778" message="Hello &amp; welcome!"/>"#
        let message = ChatMessage(serverId: serverId, dto: try chatMessageDTO(payloadXML: payload))

        XCTAssertEqual(message.serverId, serverId)
        XCTAssertEqual(message.username, "bbaron")
        XCTAssertEqual(message.message, "Hello & welcome!")
        // The server sends milliseconds; the model stores seconds
        XCTAssertEqual(message.timestamp, 1678318407.778, accuracy: 0.001)
    }

    func testChatMessageMissingAttributeDefaults() throws {
        let message = ChatMessage(serverId: serverId, dto: try chatMessageDTO(payloadXML: #"<chatMessage/>"#))
        XCTAssertEqual(message.username, "nil")
        XCTAssertEqual(message.message, "nil")
        XCTAssertEqual(message.timestamp, 0)
    }

    func testChatMessageParsedFromRealFixture() throws {
        let response = try TestDTO.response(fixture: "XML/getChatMessages.xml")
        let dto = try XCTUnwrap(response.chatMessages?.chatMessage?.values.first)
        let message = ChatMessage(serverId: serverId, dto: dto)
        // Exact fixture values ("nil" placeholders would pass a non-empty check)
        XCTAssertEqual(message.username, "bbaron")
        XCTAssertEqual(message.message, "Hi there & welcome — enjoy the music ")
        XCTAssertEqual(message.timestamp, 1783718935.178, accuracy: 0.001)
    }

    // MARK: Lyrics

    func testLyricsParsesElementText() throws {
        let payload = "<lyrics artist=\"Bob Dylan\" title=\"Blowin' in the Wind\">How many roads&#10;must a man walk down</lyrics>"
        let dto = try XCTUnwrap(TestDTO.xmlResponse(payload).lyrics)
        let lyrics = Lyrics(tagArtistName: "Bob Dylan", songTitle: "Blowin' in the Wind", dto: dto)

        XCTAssertEqual(lyrics.tagArtistName, "Bob Dylan")
        XCTAssertEqual(lyrics.songTitle, "Blowin' in the Wind")
        XCTAssertEqual(lyrics.lyricsText, "How many roads\nmust a man walk down")
    }

    func testLyricsEmptyElementProducesEmptyText() throws {
        let dto = try XCTUnwrap(TestDTO.response(fixture: "XML/getLyrics_empty.xml").lyrics)
        let lyrics = Lyrics(tagArtistName: "a", songTitle: "t", dto: dto)
        XCTAssertEqual(lyrics.lyricsText, "")
    }

    func testLyricsParsedFromPopulatedFixture() throws {
        // Note: the populated lyrics fixture is spec-derived — real Subsonic servers
        // can no longer return lyrics because their external lyrics provider is dead,
        // so every live response is the empty <lyrics/> covered above
        let dto = try XCTUnwrap(TestDTO.response(fixture: "XML/getLyrics.xml").lyrics)
        let lyrics = Lyrics(tagArtistName: "a", songTitle: "t", dto: dto)
        XCTAssertFalse(lyrics.lyricsText.isEmpty)
    }

    // MARK: NowPlayingSong

    private func nowPlayingDTO(payloadXML: String) throws -> ChildDTO {
        let response = try TestDTO.xmlResponse("<nowPlaying>\(payloadXML)</nowPlaying>")
        return try XCTUnwrap(response.nowPlaying?.entry?.values.first)
    }

    func testNowPlayingSongParsesEntryAttributes() throws {
        let payload = #"<entry id="353" username="bbaron" minutesAgo="3" playerId="2" playerName="iSub" title="Song"/>"#
        let nowPlaying = NowPlayingSong(serverId: serverId, dto: try nowPlayingDTO(payloadXML: payload))

        XCTAssertEqual(nowPlaying.serverId, serverId)
        XCTAssertEqual(nowPlaying.songId, "353")
        XCTAssertEqual(nowPlaying.username, "bbaron")
        XCTAssertEqual(nowPlaying.minutesAgo, 3)
        XCTAssertEqual(nowPlaying.playerId, 2)
        XCTAssertEqual(nowPlaying.playerName, "iSub")
    }

    func testNowPlayingSongMissingAttributeDefaults() throws {
        let nowPlaying = NowPlayingSong(serverId: serverId, dto: try nowPlayingDTO(payloadXML: #"<entry id="353"/>"#))
        XCTAssertEqual(nowPlaying.username, "nil")
        XCTAssertEqual(nowPlaying.minutesAgo, 0)
        XCTAssertEqual(nowPlaying.playerId, 0)
        XCTAssertEqual(nowPlaying.playerName, "nil")
    }

    func testNowPlayingSongParsedFromRealFixture() throws {
        let response = try TestDTO.response(fixture: "XML/getNowPlaying.xml")
        let dto = try XCTUnwrap(response.nowPlaying?.entry?.values.first)
        let nowPlaying = NowPlayingSong(serverId: serverId, dto: dto)
        // Exact fixture values ("nil" placeholders would pass a non-empty check);
        // minutesAgo (0) matches the missing-attribute default, so playerId and
        // playerName carry the attribute-mapping assertion
        XCTAssertEqual(nowPlaying.songId, "376")
        XCTAssertEqual(nowPlaying.username, "bbaron")
        XCTAssertEqual(nowPlaying.playerId, 10)
        XCTAssertEqual(nowPlaying.playerName, "iSub")
    }

    // MARK: ServerPlaylist

    func testServerPlaylistParsesAllFields() throws {
        let payload = #"<playlist id="17" name="Road Trip" comment="Best driving songs" owner="bbaron" public="true" songCount="25" duration="5000" created="2024-02-24T15:31:22.978Z" changed="2024-03-01T10:00:00.000Z" coverArt="pl-17"/>"#
        let dto = try XCTUnwrap(TestDTO.xmlResponse(payload).playlist)
        let playlist = ServerPlaylist(serverId: serverId, dto: dto)

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
        let dto = try XCTUnwrap(TestDTO.xmlResponse(#"<playlist id="17" name="Bare"/>"#).playlist)
        let playlist = ServerPlaylist(serverId: serverId, dto: dto)
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
        let response = try TestDTO.response(fixture: "XML/getPlaylists.xml")
        let dto = try XCTUnwrap(response.playlists?.playlist?.values.first)
        let playlist = ServerPlaylist(serverId: serverId, dto: dto)
        XCTAssertEqual(playlist.name, "iSub Test Playlist")
        XCTAssertEqual(playlist.songCount, 2)
        XCTAssertEqual(playlist.owner, "bbaron")
        XCTAssertFalse(playlist.isPublic)
    }

    func testServerPlaylistEqualityUsesOnlyServerIdAndId() throws {
        let a = ServerPlaylist(serverId: 1, dto: try TestDTO.json(PlaylistDTO.self, #"{"id": "1", "name": "One"}"#))
        let b = ServerPlaylist(serverId: 1, dto: try TestDTO.json(PlaylistDTO.self, #"{"id": "1", "name": "Different"}"#))
        let c = ServerPlaylist(serverId: 2, dto: try TestDTO.json(PlaylistDTO.self, #"{"id": "1", "name": "One"}"#))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
